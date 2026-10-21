param([ValidateSet('Check', 'Apply', 'Library')][string]$Mode = 'Check', [string]$Exe, [string]$Current, [string]$Arch = 'x64', [string]$WaitPids = '', [string]$AcceptedEvent = '')
$ErrorActionPreference = 'Stop'

function Get-ReleaseVersion([string]$Text) {
    if ($Text -notmatch '^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') { throw 'Invalid release version' }
    return [version]($Text.TrimStart('v'))
}

function Get-ReleaseAsset($Release, [string]$Name) {
    if ($Release.draft -or $Release.prerelease -or $Release.author.login -cne 'github-actions[bot]') { throw 'Untrusted release author or channel' }
    $null = Get-ReleaseVersion $Release.tag_name
    $assets = @($Release.assets | Where-Object { $_.name -ceq $Name })
    if ($assets.Count -ne 1) { throw 'Missing or duplicate release asset' }
    $expected = "https://github.com/valentinyeo/multiprompt/releases/download/$($Release.tag_name)/$Name"
    if ($assets[0].browser_download_url -cne $expected) { throw 'Untrusted asset URL' }
    return $assets[0]
}

function Assert-Update([string]$File, [string]$Sums, [string]$Name, [string]$Installed) {
    $lines = @(Get-Content -LiteralPath $Sums | Where-Object { $_ -cmatch ('^[a-fA-F0-9]{64} [ *]' + [regex]::Escape($Name) + '$') })
    if ($lines.Count -ne 1) { throw 'Missing or duplicate checksum' }
    $expected = $lines[0].Substring(0, 64)
    if ((Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash -ine $expected) { throw 'Update checksum mismatch' }
    $signature = Get-AuthenticodeSignature -LiteralPath $File
    $old = Get-AuthenticodeSignature -LiteralPath $Installed
    if ($signature.Status -ne 'NotSigned' -and $signature.Status -ne 'Valid') { throw 'Invalid update signature' }
    if ($old.Status -ne 'NotSigned' -and $signature.Status -ne 'Valid') { throw 'Signed installation requires a signed update' }
    if ($old.Status -eq 'Valid' -and $old.SignerCertificate.Subject -cne $signature.SignerCertificate.Subject) { throw 'Update signer changed' }
}

function Save-Update([string]$Target, [string]$Version, [string]$Architecture) {
    if ($Architecture -notin @('x64', 'arm64')) { throw 'Unsupported architecture' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $headers = @{ 'User-Agent' = 'multiprompt-updater'; Accept = 'application/vnd.github+json' }
    $release = Invoke-RestMethod 'https://api.github.com/repos/valentinyeo/multiprompt/releases/latest' -Headers $headers -TimeoutSec 15
    $name = "multiprompt-$Architecture.exe"
    $asset = Get-ReleaseAsset $release $name
    $sums = Get-ReleaseAsset $release 'SHA256SUMS.txt'
    if ((Get-ReleaseVersion $release.tag_name) -le (Get-ReleaseVersion $Version)) { return $false }
    $dir = "$Target.update"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    if ((Test-Path -LiteralPath "$dir/rejected.txt") -and (Get-Content -LiteralPath "$dir/rejected.txt" -Raw).Trim() -ceq $release.tag_name) { return $false }
    Remove-Item -LiteralPath "$dir/ready.txt" -Force -ErrorAction SilentlyContinue
    Invoke-WebRequest $asset.browser_download_url -Headers $headers -UseBasicParsing -TimeoutSec 30 -OutFile "$dir/download.exe"
    Invoke-WebRequest $sums.browser_download_url -Headers $headers -UseBasicParsing -TimeoutSec 15 -OutFile "$dir/SHA256SUMS.txt"
    Assert-Update "$dir/download.exe" "$dir/SHA256SUMS.txt" $name $Target
    Move-Item -LiteralPath "$dir/download.exe" -Destination "$dir/next.exe" -Force
    [IO.File]::WriteAllText("$dir/ready.txt", "MPVERSION=$($release.tag_name.TrimStart('v'));$name")
    return $true
}

function Start-UpdatedApp([string]$Target) {
    $eventName = 'Local\MultipromptUpdate-' + [guid]::NewGuid().ToString('N')
    $event = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::ManualReset, $eventName)
    $process = $null
    try {
        $process = Start-Process -FilePath $Target -ArgumentList @('--update-ready', $eventName) -PassThru
        $deadline = [DateTime]::UtcNow.AddSeconds(60)
        while ([DateTime]::UtcNow -lt $deadline) {
            if ($process.HasExited) { return $false }
            if ($event.WaitOne(200)) {
                if ($process.WaitForExit(2000)) { return $false }
                return $true
            }
        }
        return $false
    } catch {
        return $false
    } finally {
        if ($process -and -not $process.HasExited -and -not $event.WaitOne(0)) { $process.Kill(); $process.WaitForExit() }
        $event.Dispose()
    }
}

function Install-Update([string]$Target, [string]$Architecture, [string]$Pids, [string]$Version) {
    $dir = "$Target.update"
    $ready = Get-Content -LiteralPath "$dir/ready.txt" -Raw
    if ($ready -notmatch '^MPVERSION=(\d+\.\d+\.\d+);(multiprompt-(x64|arm64)\.exe)$' -or $Matches[3] -cne $Architecture) { throw 'Invalid staged update' }
    $tag = 'v' + $Matches[1]
    $name = $Matches[2]
    if ((Get-ReleaseVersion $tag) -le (Get-ReleaseVersion $Version)) { throw 'Staged update is not newer' }
    Assert-Update "$dir/next.exe" "$dir/SHA256SUMS.txt" $name $Target
    $processes = @($Pids.Split(',') | Where-Object { $_ -match '^\d+$' } | ForEach-Object { Get-Process -Id ([int]$_) -ErrorAction SilentlyContinue })
    if ($AcceptedEvent) {
        $accepted = [Threading.EventWaitHandle]::OpenExisting($AcceptedEvent)
        try { $null = $accepted.Set() } finally { $accepted.Dispose() }
    }
    foreach ($process in $processes) { if (-not $process.WaitForExit(60000)) { throw 'App is still running; update cancelled' } }
    $backup = "$Target.previous.exe"
    Move-Item -LiteralPath $Target -Destination $backup -Force
    try {
        Move-Item -LiteralPath "$dir/next.exe" -Destination $Target
        if (-not (Start-UpdatedApp $Target)) { throw 'Updated app failed readiness' }
        Remove-Item -LiteralPath "$dir/ready.txt" -Force
    } catch {
        [IO.File]::WriteAllText("$dir/rejected.txt", $tag)
        if (Test-Path -LiteralPath $Target) { Move-Item -LiteralPath $Target -Destination "$dir/failed.exe" -Force }
        Copy-Item -LiteralPath $backup -Destination $Target
        Remove-Item -LiteralPath "$dir/ready.txt" -Force -ErrorAction SilentlyContinue
        $null = Start-UpdatedApp $Target
        throw
    }
}

if ($Mode -eq 'Library') { return }
$mutexName = 'Local\MultipromptUpdate-' + ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::Unicode.GetBytes($Exe.ToLowerInvariant())))).Replace('-', '')
$mutex = New-Object Threading.Mutex($false, $mutexName)
$locked = $false
try {
    $locked = $mutex.WaitOne($(if ($Mode -eq 'Apply') { 65000 } else { 0 }))
    if (-not $locked) { exit 0 }
    if ($Mode -eq 'Check') {
        if (Save-Update $Exe $Current $Arch) { exit 42 }
    } else {
        Install-Update $Exe $Arch $WaitPids $Current
    }
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
} finally {
    if ($locked) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
