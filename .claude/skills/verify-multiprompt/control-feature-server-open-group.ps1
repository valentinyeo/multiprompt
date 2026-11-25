$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class ServerGroupWindow { [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow); }'
$Evidence = [IO.Path]::GetFullPath($Evidence)
New-Item -ItemType Directory -Force -Path $Evidence | Out-Null
if ((Get-FileHash -LiteralPath $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Executable checksum mismatch before server group journey' }
if (-not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable version mismatch before server group journey' }
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$workRoot = Join-Path $env:RUNNER_TEMP ('server-open-group-' + [guid]::NewGuid().ToString('N'))
$roaming = Join-Path $workRoot 'roaming'
$settings = Join-Path $roaming 'ZigShell'
$logPath = Join-Path $settings 'debug.log'
$statePath = Join-Path $workRoot 'state.json'
$accountHost = 'account.multiprompt.dev'
$appProcess = $null
$serviceProcess = $null
$cert = $null
$rootCertAdded = $false
$failure = $null
$stage = 'start'
$result = @{ verdict = 'fail'; status = 'failed'; step = $stage; error = 'Server group journey did not finish'; cleanup = 'pending' }
$hostsFile = Join-Path $env:SystemRoot 'System32/drivers/etc/hosts'
$hostsOriginal = [IO.File]::ReadAllBytes($hostsFile)
$savedEnv = @{}
foreach ($envName in @('APPDATA', 'LOCALAPPDATA', 'USERPROFILE', 'HOME', 'MULTIPROMPT_NO_LOGIN', 'ZIGSHELL_DEBUG', 'NODE_EXTRA_CA_CERTS', 'MULTIPROMPT_KEY', 'MULTIPROMPT_URL', 'MULTIPROMPT_HOST', 'MP_STATE', 'MP_URL')) {
    $savedEnv[$envName] = [Environment]::GetEnvironmentVariable($envName, 'Process')
}
function Read-ServerGroupText([string]$Path) {
    if (!(Test-Path -LiteralPath $Path)) { return '' }
    $share = [IO.FileShare]([int][IO.FileShare]::ReadWrite -bor [int][IO.FileShare]::Delete)
    $deadline = [DateTime]::UtcNow.AddSeconds(3)
    while ($true) {
        try {
            $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, $share)
            try { return (New-Object IO.StreamReader($stream)).ReadToEnd() } finally { $stream.Dispose() }
        } catch [IO.IOException] {
            if ([DateTime]::UtcNow -ge $deadline) { throw }
            Start-Sleep -Milliseconds 100
        }
    }
}
function Get-ServerGroupSession {
    $text = Read-ServerGroupText (Join-Path $settings 'session-server-group.json')
    if (!$text) { return $null }
    try { return $text | ConvertFrom-Json } catch { return $null }
}
function Get-ServerGroupProperty($item, [string]$Name) {
    if ($null -eq $item -or $null -eq $item.PSObject.Properties[$Name]) { return $null }
    return $item.$Name
}
function Test-ServerGroupReady($state) {
    if ($null -eq $state -or $null -eq $state.PSObject.Properties['groups'] -or $null -eq $state.PSObject.Properties['tabs']) { return $false }
    $groups = @($state.groups | Where-Object { (Get-ServerGroupProperty $_ 'name') -ceq 'Runners' -and (Get-ServerGroupProperty $_ 'id') -gt 0 })
    if ($groups.Count -ne 1) { return $false }
    return @($state.tabs | Where-Object { (Get-ServerGroupProperty $_ 'tmux_session') -ceq 'mp-runner-1' -and (Get-ServerGroupProperty $_ 'group_id') -eq (Get-ServerGroupProperty $groups[0] 'id') }).Count -eq 1
}
function Wait-ServerGroup([string]$Description, [scriptblock]$Check, [int]$Seconds = 90) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    do {
        if ($null -ne $appProcess) {
            $appProcess.Refresh()
            if ($appProcess.HasExited) { throw 'Desktop process exited during the server group journey' }
        }
        if (& $Check) { return }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Journey condition not met: $Description (checked for $Seconds seconds)"
}
function Save-ServerGroupShot([string]$Path) {
    if ($appProcess) {
        $appProcess.Refresh()
        if ($appProcess.MainWindowHandle -ne [IntPtr]::Zero) {
            [void][ServerGroupWindow]::ShowWindow($appProcess.MainWindowHandle, 9)
            [void][ServerGroupWindow]::SetForegroundWindow($appProcess.MainWindowHandle)
            Start-Sleep -Milliseconds 400
        }
    }
    $bounds = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.Size)
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Format-ServerGroupArgs([string[]]$Values) {
    return (($Values | ForEach-Object { if ($_ -notmatch '[\s"]') { $_ } else { '"' + ($_ -replace '"', '\"') + '"' } }) -join ' ')
}
function Invoke-ServerGroupNode([string[]]$NodeArgs) {
    $outputPath = Join-Path $workRoot 'node-out.txt'
    $errorPath = Join-Path $workRoot 'node-err.txt'
    $nodeProcess = Start-Process -FilePath 'node' -ArgumentList (Format-ServerGroupArgs $NodeArgs) -NoNewWindow -Wait -PassThru -RedirectStandardOutput $outputPath -RedirectStandardError $errorPath
    $combined = (Read-ServerGroupText $outputPath) + (Read-ServerGroupText $errorPath)
    Remove-Item -LiteralPath $outputPath, $errorPath -Force -ErrorAction SilentlyContinue
    $reported = ($combined -replace 'mpk_[A-Za-z0-9_-]+', '<redacted>').Trim()
    $commandText = 'mp-layout ' + (($NodeArgs | Select-Object -Skip 1) -join ' ')
    if ($nodeProcess.ExitCode -ne 0) { throw "$commandText exited $($nodeProcess.ExitCode): $reported" }
    if ($reported -ne $combined.Trim()) { throw "$commandText printed a service key: $reported" }
    return $combined
}
try {
    New-Item -ItemType Directory -Force -Path $settings, (Join-Path $workRoot 'local') | Out-Null
    $stage = 'account worker bundle'
    $worker = Join-Path $repoRoot 'service/.build/worker.js'
    if (!(Test-Path -LiteralPath $worker)) {
        Push-Location (Join-Path $repoRoot 'service')
        try {
            & npm ci --no-audit --no-fund
            if ($LASTEXITCODE -ne 0) { throw 'Account worker install failed' }
            & npx wrangler deploy --dry-run --outdir .build
            if ($LASTEXITCODE -ne 0) { throw 'Account worker bundle failed' }
        } finally { Pop-Location }
    }
    if (!(Test-Path -LiteralPath $worker)) { throw 'Account worker bundle missing' }
    $stage = 'local account certificate'
    $cert = New-SelfSignedCertificate -DnsName $accountHost -CertStoreLocation Cert:\LocalMachine\My -KeyAlgorithm RSA -KeyLength 2048 -NotAfter (Get-Date).AddDays(1)
    $secure = New-Object Security.SecureString
    foreach ($char in ([guid]::NewGuid().ToString('N')).ToCharArray()) { $secure.AppendChar($char) }
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringUni([Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($secure))
    $pfx = Join-Path $workRoot 'account.pfx'
    $pem = Join-Path $workRoot 'account.pem'
    Export-PfxCertificate -Cert $cert -FilePath $pfx -Password $secure | Out-Null
    Export-Certificate -Cert $cert -FilePath (Join-Path $workRoot 'account.cer') | Out-Null
    [IO.File]::WriteAllText($pem, ("-----BEGIN CERTIFICATE-----`n" + [Convert]::ToBase64String($cert.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert), 'InsertLineBreaks') + "`n-----END CERTIFICATE-----`n"))
    Import-Certificate -FilePath (Join-Path $workRoot 'account.cer') -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
    $rootCertAdded = $true
    [IO.File]::AppendAllText($hostsFile, "`r`n127.0.0.1 $accountHost`r`n")
    $stage = 'account service launch'
    $serviceProcess = Start-Process -FilePath 'node' -ArgumentList (Format-ServerGroupArgs @((Join-Path $repoRoot 'service/journey/server.mjs'), '--port=443', "--pfx=$pfx", "--pfxpass=$plain", "--state=$statePath")) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $workRoot 'service.log') -RedirectStandardError (Join-Path $workRoot 'service.err.log')
    $plain = $null
    $secure.Dispose()
    $ready = $false
    $healthError = 'no response'
    for ($attempt = 0; $attempt -lt 40 -and -not $ready; $attempt++) {
        try { Invoke-RestMethod -Uri "https://$accountHost/health" | Out-Null; $ready = $true } catch { $healthError = $_.Exception.Message; Start-Sleep -Milliseconds 250 }
    }
    if (-not $ready) { throw ('account service did not answer https://' + $accountHost + '/health: ' + $healthError) }
    $stage = 'account enrolment'
    $secrets = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $credential = [Text.Encoding]::UTF8.GetBytes((@{ refresh_token = $secrets.refresh_token } | ConvertTo-Json -Compress))
    [IO.File]::WriteAllBytes((Join-Path $settings 'account-device.dat'), [Security.Cryptography.ProtectedData]::Protect($credential, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser))
    $env:NODE_EXTRA_CA_CERTS = $pem
    $env:MULTIPROMPT_URL = "https://$accountHost"
    $env:MULTIPROMPT_KEY = [string]$secrets.admin_key
    $env:MULTIPROMPT_HOST = '0'
    $stage = 'first layout import'
    $layoutTool = Join-Path $repoRoot 'tools/mp-layout.mjs'
    [void](Invoke-ServerGroupNode @($layoutTool, 'create-section', 'Multiprompt'))
    $opened = Invoke-ServerGroupNode @($layoutTool, 'open', '--kind', 'shell', '--tmux', 'mp-runner-1', '--name', 'Runner shell', '--workspace', 'Multiprompt', '--group', 'Runners', '--host', '0', '--star', '--no-tmux')
    if ($opened -notmatch 'opened mp-runner-1') { throw 'shell runner was not published' }
    Remove-Item Env:\MULTIPROMPT_KEY -ErrorAction SilentlyContinue
    $env:APPDATA = $roaming
    $env:LOCALAPPDATA = Join-Path $workRoot 'local'
    [Environment]::SetEnvironmentVariable('USERPROFILE', $workRoot, 'Process')
    $env:HOME = $workRoot
    $env:ZIGSHELL_DEBUG = '1'
    Remove-Item Env:\MULTIPROMPT_NO_LOGIN -ErrorAction SilentlyContinue
    $stage = 'desktop launch'
    $appProcess = Start-Process -FilePath $Exe -ArgumentList @('--single-window', '--name', 'server-group', '--no-window-restore') -PassThru -RedirectStandardOutput (Join-Path $workRoot 'desktop.log') -RedirectStandardError (Join-Path $workRoot 'desktop.err.log')
    $stage = 'first grouped import'
    Wait-ServerGroup 'first grouped import' { Test-ServerGroupReady (Get-ServerGroupSession) }
    Wait-ServerGroup 'desktop window' { $appProcess.Refresh(); $appProcess.MainWindowHandle -ne [IntPtr]::Zero } 30
    $first = Get-ServerGroupSession
    $firstTabs = @($first.tabs).Count
    $firstGroups = @($first.groups).Count
    $runnerId = @($first.groups | Where-Object { $_.name -ceq 'Runners' })[0].id
    Save-ServerGroupShot (Join-Path $Evidence 'before.png')
    $env:MULTIPROMPT_KEY = [string]$secrets.admin_key
    $stage = 'second open keeps the tab'
    $again = Invoke-ServerGroupNode @($layoutTool, 'open', '--kind', 'shell', '--tmux', 'mp-runner-1', '--name', 'Runner shell', '--workspace', 'Multiprompt', '--group', 'Runners', '--host', '0', '--star', '--no-tmux')
    Remove-Item Env:\MULTIPROMPT_KEY -ErrorAction SilentlyContinue
    if ($again -notmatch 'already open mp-runner-1') { throw 'second open did not keep the same tab' }
    $env:MP_STATE = $statePath
    $env:MP_URL = "https://$accountHost"
    $bumpPath = Join-Path $workRoot 'bump.mjs'
    [IO.File]::WriteAllText($bumpPath, "import fs from 'node:fs';`nconst state = JSON.parse(fs.readFileSync(process.env.MP_STATE, 'utf8'));`nconst headers = { Authorization: 'Bearer ' + state.admin_key, 'X-Layout-Features': 'groups,favorite' };`nfor (let attempt = 1; ; attempt++) {`n  const current = await fetch(process.env.MP_URL + '/v1/layout', { headers });`n  if (!current.ok) throw new Error('read failed ' + current.status);`n  const body = await current.json();`n  const saved = await fetch(process.env.MP_URL + '/v1/layout', { method: 'PUT', headers: { ...headers, 'Content-Type': 'application/json' }, body: JSON.stringify({ base_revision: body.revision, layout: body.layout }) });`n  if (saved.ok) break;`n  if (saved.status !== 409 || attempt >= 5) throw new Error('write failed ' + saved.status);`n}`n")
    $stage = 'second grouped import'
    $appliedBefore = (Read-ServerGroupText $logPath).Length
    [void](Invoke-ServerGroupNode @($bumpPath))
    Remove-Item Env:\MP_STATE, Env:\MP_URL -ErrorAction SilentlyContinue
    Wait-ServerGroup 'second grouped import' { (Read-ServerGroupText $logPath).Length -gt $appliedBefore -and (Read-ServerGroupText $logPath).Substring($appliedBefore) -match 'account-sync: applied' }
    $second = Get-ServerGroupSession
    $stage = 'second import assertions'
    if (@($second.tabs).Count -ne $firstTabs) { throw 'second import added a tab' }
    if (@($second.groups).Count -ne $firstGroups) { throw 'second import added a group' }
    if (-not (Test-ServerGroupReady $second)) { throw 'second import lost the Runners group' }
    Save-ServerGroupShot (Join-Path $Evidence 'after.png')
    Copy-Item -LiteralPath (Join-Path $settings 'session-server-group.json') -Destination (Join-Path $Evidence 'session.json')
    $result = @{ verdict = 'pass'; status = 'passed'; group = 'Runners'; group_id = $runnerId; tabs = $firstTabs; groups = $firstGroups; second_import = 'unchanged'; version = $ExpectedVersion; cleanup = 'pending'; checks = @(
        @{ name = 'one-group-named-runners'; passed = $true },
        @{ name = 'imported-tab-group-id-matches-group'; passed = $true },
        @{ name = 'second-import-keeps-tab-and-group'; passed = $true },
        @{ name = 'second-import-lost-no-runners-group'; passed = $true }
    ) }
} catch {
    $failure = $_
    foreach ($name in @('service.log', 'service.err.log', 'state.json', 'desktop.err.log')) {
        $saved = Join-Path $workRoot $name
        if (Test-Path -LiteralPath $saved) { try { Copy-Item -LiteralPath $saved -Destination (Join-Path $Evidence ('failure-' + $name)) -ErrorAction Stop } catch { } }
    }
    Write-Host ('[server-open-group] failed at ' + $stage + ': ' + $_.Exception.Message)
    $result = @{ verdict = 'fail'; status = 'failed'; step = $stage; error = $_.Exception.Message; exception = $_.Exception.GetType().FullName; cleanup = 'pending' }
} finally {
    $remaining = 0
    foreach ($ownedProcess in @($appProcess, $serviceProcess)) {
        if ($ownedProcess) {
            try {
                $ownedProcess.Refresh()
                if (!$ownedProcess.HasExited) {
                    & taskkill.exe /PID $ownedProcess.Id /T /F 2>&1 | Out-Null
                    [void]$ownedProcess.WaitForExit(10000)
                }
                $ownedProcess.Refresh()
                if (!$ownedProcess.HasExited) { $remaining += 1 }
            } catch {}
        }
    }
    $result.cleanup = $remaining
    if ($remaining -ne 0 -and $result.status -eq 'passed') {
        $result.status = 'failed'
        $result.verdict = 'fail'
        $result.step = 'cleanup'
        $result.error = ('Owned processes survived cleanup: ' + $remaining)
        if (!$failure) { $failure = [InvalidOperationException]::new($result.error) }
    }
    try { [IO.File]::WriteAllBytes($hostsFile, $hostsOriginal) } catch { if (!$failure) { $failure = $_ } }
    foreach ($envName in @($savedEnv.Keys)) { [Environment]::SetEnvironmentVariable($envName, $savedEnv[$envName], 'Process') }
    if ($cert) {
        try {
            if ($rootCertAdded -and (Test-Path "Cert:\LocalMachine\Root\$($cert.Thumbprint)")) { Remove-Item "Cert:\LocalMachine\Root\$($cert.Thumbprint)" -ErrorAction Stop }
            if (Test-Path "Cert:\LocalMachine\My\$($cert.Thumbprint)") { Remove-Item "Cert:\LocalMachine\My\$($cert.Thumbprint)" -ErrorAction Stop }
        } catch { if (!$failure) { $failure = $_ } }
    }
    try { if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction Stop } } catch { if (!$failure) { $failure = $_ } }
    try { $result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $Evidence 'result.json') } catch { Write-Host ('[server-open-group] could not write result.json: ' + $_.Exception.Message) }
}
if ($failure) { throw ('Server group journey failed at ' + $stage + ': ' + $failure.Exception.Message) }
return
