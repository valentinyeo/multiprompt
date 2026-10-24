param([ValidateSet('Check', 'Apply', 'Library')][string]$Mode = 'Check', [string]$Exe, [string]$Current, [string]$Arch = 'x64', [string]$WaitPids = '', [string]$AcceptedEvent = '', [string]$LaunchArguments = '')
$ErrorActionPreference = 'Stop'
$launch = if ($LaunchArguments) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($LaunchArguments)) } else { '' }

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

function Assert-Manifest([string]$Installed, [string]$Directory) {
    $sums = Join-Path $Directory 'SHA256SUMS.txt'
    $signature = Join-Path $Directory 'SHA256SUMS.txt.sig'
    if (-not (Test-Path -LiteralPath $sums) -or -not (Test-Path -LiteralPath $signature)) { throw 'Missing signed checksum manifest' }
    $verifier = Start-Process -FilePath $Installed -ArgumentList "--verify-release-manifest `"$sums`" `"$signature`"" -PassThru
    if (-not $verifier.WaitForExit(15000)) { $verifier.Kill(); $verifier.WaitForExit(); throw 'Manifest verification timed out' }
    if ($verifier.ExitCode -ne 0) { throw 'Release manifest signature verification failed' }
}

function Assert-Update([string]$File, [string]$Sums, [string]$Name, [string]$Installed) {
    $lines = @(Get-Content -LiteralPath $Sums | Where-Object { $_ -cmatch ('^[a-fA-F0-9]{64} [ *]' + [regex]::Escape($Name) + '$') })
    if ($lines.Count -ne 1) { throw 'Missing or duplicate checksum' }
    $expected = $lines[0].Substring(0, 64)
    if ((Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash -ine $expected) { throw 'Update checksum mismatch' }
    if (-not $Name.EndsWith('.exe')) { return }
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
    $names = @("multiprompt-$Architecture.exe", "zigshell-bridge-$Architecture.exe", 'multiprompt-extension.zip', 'SHA256SUMS.txt', 'SHA256SUMS.txt.sig')
    $assets = @($names | ForEach-Object { Get-ReleaseAsset $release $_ })
    if ((Get-ReleaseVersion $release.tag_name) -le (Get-ReleaseVersion $Version)) { return $false }
    $dir = "$Target.update"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    if ((Test-Path -LiteralPath "$dir/rejected.txt") -and (Get-Content -LiteralPath "$dir/rejected.txt" -Raw).Trim() -ceq $release.tag_name) { return $false }
    Remove-Item -LiteralPath "$dir/ready.txt" -Force -ErrorAction SilentlyContinue
    for ($i = 3; $i -lt 5; $i++) { Invoke-WebRequest $assets[$i].browser_download_url -Headers $headers -UseBasicParsing -TimeoutSec 15 -OutFile "$dir/$($names[$i])" }
    Assert-Manifest $Target $dir
    $files = @('download.exe', 'download-bridge.exe', 'multiprompt-extension.zip')
    for ($i = 0; $i -lt 3; $i++) {
        Invoke-WebRequest $assets[$i].browser_download_url -Headers $headers -UseBasicParsing -TimeoutSec 30 -OutFile "$dir/$($files[$i])"
        Assert-Update "$dir/$($files[$i])" "$dir/SHA256SUMS.txt" $names[$i] $Target
    }
    Remove-Item -LiteralPath "$dir/release-notes.json" -Force -ErrorAction SilentlyContinue
    if (@($release.assets | Where-Object { $_.name -ceq 'release-notes.json' }).Count -gt 0) {
        $notesAsset = Get-ReleaseAsset $release 'release-notes.json'
        Invoke-WebRequest $notesAsset.browser_download_url -Headers $headers -UseBasicParsing -TimeoutSec 15 -OutFile "$dir/notes.tmp"
        Assert-Update "$dir/notes.tmp" "$dir/SHA256SUMS.txt" 'release-notes.json' $Target
        if ((Get-Item -LiteralPath "$dir/notes.tmp").Length -gt 1048576) { throw 'Release notes too large' }
        $notes = Get-Content -LiteralPath "$dir/notes.tmp" -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($notes.version -cne $release.tag_name.TrimStart('v')) { throw 'Release notes version mismatch' }
        Move-Item -LiteralPath "$dir/notes.tmp" -Destination "$dir/release-notes.json" -Force
    }
    $marker = "MPVERSION=$($release.tag_name.TrimStart('v'));"
    if (-not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes("$dir/download.exe")).Contains($marker)) { throw 'Release executable version mismatch' }
    Move-Item -LiteralPath "$dir/download.exe" -Destination "$dir/next.exe" -Force
    Move-Item -LiteralPath "$dir/download-bridge.exe" -Destination "$dir/next-bridge.exe" -Force
    [IO.File]::WriteAllText("$dir/ready.tmp", "$marker$($names[0])")
    Move-Item -LiteralPath "$dir/ready.tmp" -Destination "$dir/ready.txt" -Force
    return $true
}

function Start-UpdatedApp([string]$Target) {
    $eventName = 'Local\MultipromptUpdate-' + [guid]::NewGuid().ToString('N')
    $event = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::ManualReset, $eventName)
    $process = $null
    $ready = $false
    try {
        $process = Start-Process -FilePath $Target -ArgumentList ($launch + ' --update-ready ' + $eventName) -WindowStyle Maximized -PassThru
        $deadline = [DateTime]::UtcNow.AddSeconds(60)
        while ([DateTime]::UtcNow -lt $deadline) {
            if ($process.HasExited) { return $false }
            if ($event.WaitOne(200)) {
                if ($process.WaitForExit(2000)) { return $false }
                $ready = $true
                return $true
            }
        }
        return $false
    } catch {
        return $false
    } finally {
        if ($process -and -not $process.HasExited -and -not $ready) { $process.Kill(); $process.WaitForExit() }
        $event.Dispose()
    }
}

function Start-RestoredApp([string]$Target) {
    if (Get-Process | Where-Object { $_.Path -ieq $Target }) { return }
    $null = Start-Process -FilePath $Target -ArgumentList ($launch + ' ') -WindowStyle Maximized
}

function Get-WaitingProcesses([string]$Pids) {
    return @($Pids.Split(',') | Where-Object { $_ -match '^\d+$' } | ForEach-Object { Get-Process -Id ([int]$_) -ErrorAction SilentlyContinue })
}

function Install-Update([string]$Target, [string]$Architecture, [string]$Pids, [string]$Version) {
    $dir = "$Target.update"
    $backup = "$Target.previous.exe"
    $bridge = Join-Path (Split-Path $Target) 'zigshell-bridge.exe'
    $bridgeBackup = "$dir/previous-bridge.exe"
    $moved = $false
    $bridgeMoved = $false
    $bridgeInstalled = $false
    $extension = $null
    $extensionSaved = $false
    try {
        $processes = @(Get-WaitingProcesses $Pids)
        foreach ($process in $processes) {
            if (-not $process.WaitForExit(60000)) {
                foreach ($remaining in $processes) { $remaining.WaitForExit() }
                Remove-Item -LiteralPath "$dir/ready.txt" -Force -ErrorAction SilentlyContinue
                Start-RestoredApp $Target
                return
            }
        }
        $ready = Get-Content -LiteralPath "$dir/ready.txt" -Raw
        if ($ready -notmatch '^MPVERSION=(\d+\.\d+\.\d+);(multiprompt-(x64|arm64)\.exe)$' -or $Matches[3] -cne $Architecture) { throw 'Invalid staged update' }
        $tag = 'v' + $Matches[1]
        $name = $Matches[2]
        if ((Get-ReleaseVersion $tag) -le (Get-ReleaseVersion $Version)) { throw 'Staged update is not newer' }
        Assert-Manifest $Target $dir
        Assert-Update "$dir/next.exe" "$dir/SHA256SUMS.txt" $name $Target
        Assert-Update "$dir/next-bridge.exe" "$dir/SHA256SUMS.txt" "zigshell-bridge-$Architecture.exe" $Target
        Assert-Update "$dir/multiprompt-extension.zip" "$dir/SHA256SUMS.txt" 'multiprompt-extension.zip' $Target
        $helper = Start-Process -FilePath $Target -ArgumentList '--stop-update-helpers' -PassThru
        if (-not $helper.WaitForExit(15000)) { $helper.Kill(); $helper.WaitForExit(); throw 'Old helper shutdown timed out' }
        if ($helper.ExitCode -ne 0) { throw 'Could not stop old update helpers' }
        Assert-Manifest $Target $dir
        Assert-Update "$dir/next.exe" "$dir/SHA256SUMS.txt" $name $Target
        Assert-Update "$dir/next-bridge.exe" "$dir/SHA256SUMS.txt" "zigshell-bridge-$Architecture.exe" $Target
        $extensionConfig = Join-Path $env:APPDATA 'ZigShell/edge-extension-path.txt'
        if (Test-Path -LiteralPath $extensionConfig) { $extension = (Get-Content -LiteralPath $extensionConfig -Raw).Trim() }
        if (-not $extension) { $extension = Join-Path $env:USERPROFILE 'Documents/GitHub/zigshell/extension' }
        if (Test-Path -LiteralPath $extension -PathType Container) {
            Remove-Item -LiteralPath "$dir/extension", "$dir/previous-extension" -Recurse -Force -ErrorAction SilentlyContinue
            Expand-Archive -LiteralPath "$dir/multiprompt-extension.zip" -DestinationPath "$dir/extension"
            Copy-Item -LiteralPath $extension -Destination "$dir/previous-extension" -Recurse
            $extensionSaved = $true
        }
        Move-Item -LiteralPath $Target -Destination $backup -Force
        $moved = $true
        if (Test-Path -LiteralPath $bridge) {
            Move-Item -LiteralPath $bridge -Destination $bridgeBackup -Force
            $bridgeMoved = $true
        }
        Move-Item -LiteralPath "$dir/next-bridge.exe" -Destination $bridge
        $bridgeInstalled = $true
        Move-Item -LiteralPath "$dir/next.exe" -Destination $Target
        if ($extensionSaved) {
            Get-ChildItem -LiteralPath "$dir/extension" -Recurse -File | Where-Object { $_.FullName -notlike '*\themes\current\*' } | ForEach-Object {
                $destination = Join-Path $extension $_.FullName.Substring(("$dir/extension").Length + 1)
                New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
                Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
            }
        }
        if (-not (Start-UpdatedApp $Target)) { throw 'Updated app failed readiness' }
        Remove-Item -LiteralPath "$dir/ready.txt" -Force
    } catch {
        try {
            if ($moved) {
                [IO.File]::WriteAllText("$dir/rejected.txt", $tag)
                if (Test-Path -LiteralPath $Target) { Move-Item -LiteralPath $Target -Destination "$dir/failed.exe" -Force }
                Copy-Item -LiteralPath $backup -Destination $Target
                if ($bridgeInstalled) { Remove-Item -LiteralPath $bridge -Force }
                if ($bridgeMoved) { Copy-Item -LiteralPath $bridgeBackup -Destination $bridge -Force }
                if ($extensionSaved) {
                    Remove-Item -LiteralPath $extension -Recurse -Force
                    Copy-Item -LiteralPath "$dir/previous-extension" -Destination $extension -Recurse
                }
                Remove-Item -LiteralPath "$dir/ready.txt" -Force -ErrorAction SilentlyContinue
            }
        } finally {
            Remove-Item -LiteralPath "$dir/ready.txt" -Force -ErrorAction SilentlyContinue
            if (Test-Path -LiteralPath $Target) { Start-RestoredApp $Target } elseif (Test-Path -LiteralPath $backup) { Start-RestoredApp $backup }
        }
        throw
    }
}

if ($Mode -eq 'Library') { return }
if ($Mode -eq 'Apply' -and $AcceptedEvent) {
    $accepted = [Threading.EventWaitHandle]::OpenExisting($AcceptedEvent)
    try { $null = $accepted.Set() } finally { $accepted.Dispose() }
}
$mutexName = 'Local\MultipromptUpdate-' + ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::Unicode.GetBytes($Exe.ToLowerInvariant())))).Replace('-', '')
$mutex = New-Object Threading.Mutex($false, $mutexName)
$locked = $false
try {
    try { $locked = $mutex.WaitOne($(if ($Mode -eq 'Apply') { -1 } else { 0 })) } catch [Threading.AbandonedMutexException] { $locked = $true }
    if (-not $locked) { exit 0 }
    if ($Mode -eq 'Check') {
        if (Save-Update $Exe $Current $Arch) { exit 42 }
    } else {
        Install-Update $Exe $Arch $WaitPids $Current
    }
} catch {
    if ($Mode -eq 'Apply') { Start-RestoredApp $Exe }
    Write-Error $_ -ErrorAction Continue
    exit 1
} finally {
    if ($locked) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
