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
$hostsFile = Join-Path $env:SystemRoot 'System32/drivers/etc/hosts'
$hostsOriginal = [IO.File]::ReadAllBytes($hostsFile)
$savedEnv = @{}
foreach ($envName in @('APPDATA', 'LOCALAPPDATA', 'USERPROFILE', 'HOME', 'MULTIPROMPT_NO_LOGIN', 'ZIGSHELL_DEBUG', 'NODE_EXTRA_CA_CERTS', 'MULTIPROMPT_KEY', 'MULTIPROMPT_URL', 'MULTIPROMPT_HOST', 'MP_STATE', 'MP_URL')) {
    $savedEnv[$envName] = [Environment]::GetEnvironmentVariable($envName, 'Process')
}
function Read-ServerGroupText([string]$Path) {
    if (!(Test-Path -LiteralPath $Path)) { return '' }
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try { return (New-Object IO.StreamReader($stream)).ReadToEnd() } finally { $stream.Dispose() }
}
function Get-ServerGroupSession {
    $text = Read-ServerGroupText (Join-Path $settings 'session-server-group.json')
    if (!$text) { return $null }
    try { return $text | ConvertFrom-Json } catch { return $null }
}
function Test-ServerGroupReady($state) {
    if ($null -eq $state -or $null -eq $state.PSObject.Properties['groups'] -or $null -eq $state.PSObject.Properties['tabs']) { return $false }
    $groups = @($state.groups | Where-Object { $_.name -ceq 'Runners' -and $_.id -gt 0 })
    if ($groups.Count -ne 1) { return $false }
    return @($state.tabs | Where-Object { $_.tmux_session -ceq 'mp-runner-1' -and $_.group_id -eq $groups[0].id }).Count -eq 1
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
    throw "Timed out: $Description"
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
    if ($nodeProcess.ExitCode -ne 0 -or $combined -match 'mpk_') { throw 'server group command failed' }
    return $combined
}
try {
    New-Item -ItemType Directory -Force -Path $settings, (Join-Path $workRoot 'local') | Out-Null
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
    $serviceProcess = Start-Process -FilePath 'node' -ArgumentList (Format-ServerGroupArgs @((Join-Path $repoRoot 'service/journey/server.mjs'), '--port=443', "--pfx=$pfx", "--pfxpass=$plain", "--state=$statePath")) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $workRoot 'service.log') -RedirectStandardError (Join-Path $workRoot 'service.err.log')
    $plain = $null
    $secure.Dispose()
    $ready = $false
    for ($attempt = 0; $attempt -lt 40 -and -not $ready; $attempt++) {
        try { Invoke-RestMethod -Uri "https://$accountHost/health" | Out-Null; $ready = $true } catch { Start-Sleep -Milliseconds 250 }
    }
    if (-not $ready) { throw 'account service did not start' }
    $secrets = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $credential = [Text.Encoding]::UTF8.GetBytes((@{ refresh_token = $secrets.refresh_token } | ConvertTo-Json -Compress))
    [IO.File]::WriteAllBytes((Join-Path $settings 'account-device.dat'), [Security.Cryptography.ProtectedData]::Protect($credential, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser))
    $env:NODE_EXTRA_CA_CERTS = $pem
    $env:MULTIPROMPT_URL = "https://$accountHost"
    $env:MULTIPROMPT_KEY = [string]$secrets.admin_key
    $env:MULTIPROMPT_HOST = '0'
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
    $appProcess = Start-Process -FilePath $Exe -ArgumentList @('--single-window', '--name', 'server-group', '--no-window-restore') -PassThru -RedirectStandardOutput (Join-Path $workRoot 'desktop.log') -RedirectStandardError (Join-Path $workRoot 'desktop.err.log')
    Wait-ServerGroup 'first grouped import' { Test-ServerGroupReady (Get-ServerGroupSession) }
    Wait-ServerGroup 'desktop window' { $appProcess.Refresh(); $appProcess.MainWindowHandle -ne [IntPtr]::Zero } 30
    $first = Get-ServerGroupSession
    $firstTabs = @($first.tabs).Count
    $firstGroups = @($first.groups).Count
    $runnerId = @($first.groups | Where-Object { $_.name -ceq 'Runners' })[0].id
    Save-ServerGroupShot (Join-Path $Evidence 'before.png')
    $env:MULTIPROMPT_KEY = [string]$secrets.admin_key
    $again = Invoke-ServerGroupNode @($layoutTool, 'open', '--kind', 'shell', '--tmux', 'mp-runner-1', '--name', 'Runner shell', '--workspace', 'Multiprompt', '--group', 'Runners', '--host', '0', '--star', '--no-tmux')
    Remove-Item Env:\MULTIPROMPT_KEY -ErrorAction SilentlyContinue
    if ($again -notmatch 'already open mp-runner-1') { throw 'second open did not keep the same tab' }
    $env:MP_STATE = $statePath
    $env:MP_URL = "https://$accountHost"
    $bumpPath = Join-Path $workRoot 'bump.mjs'
    [IO.File]::WriteAllText($bumpPath, "const fs = require('node:fs');`nconst state = JSON.parse(fs.readFileSync(process.env.MP_STATE, 'utf8'));`nconst headers = { Authorization: 'Bearer ' + state.admin_key, 'X-Layout-Features': 'groups,favorite' };`nconst current = await fetch(process.env.MP_URL + '/v1/layout', { headers });`nif (!current.ok) throw new Error('read failed');`nconst body = await current.json();`nconst saved = await fetch(process.env.MP_URL + '/v1/layout', { method: 'PUT', headers: { ...headers, 'Content-Type': 'application/json' }, body: JSON.stringify({ base_revision: body.revision, layout: body.layout }) });`nif (!saved.ok) throw new Error('write failed');`n")
    $appliedBefore = (Read-ServerGroupText $logPath).Length
    [void](Invoke-ServerGroupNode @('--input-type=module', $bumpPath))
    Remove-Item Env:\MP_STATE, Env:\MP_URL -ErrorAction SilentlyContinue
    Wait-ServerGroup 'second grouped import' { (Read-ServerGroupText $logPath).Length -gt $appliedBefore -and (Read-ServerGroupText $logPath).Substring($appliedBefore) -match 'account-sync: applied' }
    $second = Get-ServerGroupSession
    if (@($second.tabs).Count -ne $firstTabs) { throw 'second import added a tab' }
    if (@($second.groups).Count -ne $firstGroups) { throw 'second import added a group' }
    if (-not (Test-ServerGroupReady $second)) { throw 'second import lost the Runners group' }
    Save-ServerGroupShot (Join-Path $Evidence 'after.png')
    Copy-Item -LiteralPath (Join-Path $settings 'session-server-group.json') -Destination (Join-Path $Evidence 'session.json')
    @{ verdict = 'pass'; group = 'Runners'; group_id = $runnerId; tabs = $firstTabs; groups = $firstGroups; second_import = 'unchanged'; version = $ExpectedVersion } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Evidence 'result.json')
} catch {
    $failure = $_
    @{ verdict = 'fail'; error = 'server group journey failed' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Evidence 'result.json')
} finally {
    foreach ($ownedProcess in @($appProcess, $serviceProcess)) {
        if ($ownedProcess) {
            try {
                $ownedProcess.Refresh()
                if (!$ownedProcess.HasExited) {
                    & taskkill.exe /PID $ownedProcess.Id /T /F 2>&1 | Out-Null
                    [void]$ownedProcess.WaitForExit(10000)
                }
            } catch {}
        }
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
}
if ($failure) { throw 'Server group journey failed' }
return
