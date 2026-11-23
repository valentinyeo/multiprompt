$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class MbTabWindow { [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow); }'
$Evidence = [IO.Path]::GetFullPath($Evidence)
New-Item -ItemType Directory -Force -Path $Evidence | Out-Null
if ((Get-FileHash -LiteralPath $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Executable checksum mismatch before mb tab journey' }
if (-not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable version mismatch before mb tab journey' }
function Resolve-MbTabExecutable([string]$Name) {
    try { return (Get-Command $Name -ErrorAction Stop).Source }
    catch { throw "$Name is not installed or not on PATH" }
}
$MbTabNode = Resolve-MbTabExecutable 'node.exe'
$MbTabNpm = Resolve-MbTabExecutable 'npm.cmd'
$MbTabSession = 'mb-proof-1'
$MbTabTitle = 'MB proof tab'
$MbTabWork = 'Multiprompt'
$MbTabOther = 'Other'
$MbTabVerb = if ($Feature -match '^mb-tab-(.+)$') { $Matches[1] } else { throw "Unknown mb tab feature $Feature" }

function Read-MbTabSession {
    $path = Join-Path $settings 'session.json'
    if (!(Test-Path -LiteralPath $path)) { return $null }
    try { return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json } catch { return $null }
}

function Save-MbTabSession([string]$Label) {
    $state = Read-MbTabSession
    if ($null -ne $state) { $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Evidence "$Feature-$Label.session.json") }
}

function Get-MbTabProperty($item, [string]$Name) {
    if ($null -eq $item -or $null -eq $item.PSObject.Properties[$Name]) { return $null }
    return $item.$Name
}

function WorkspaceIndexByName($state, [string]$Name) {
    if ($null -eq $state -or $null -eq $state.PSObject.Properties['workspaces']) { return -1 }
    for ($i = 0; $i -lt @($state.workspaces).Count; $i++) {
        if ((Get-MbTabProperty $state.workspaces[$i] 'name') -ceq $Name) { return $i }
    }
    return -1
}

function Find-MbTab($state) {
    if ($null -eq $state) { return $null }
    return @($state.tabs | Where-Object { (Get-MbTabProperty $_ 'tmux_session') -ceq $MbTabSession })[0]
}

function Find-MbTabClosed($state) {
    if ($null -eq $state -or $null -eq $state.PSObject.Properties['closed_tmux']) { return $null }
    return @($state.closed_tmux | Where-Object { $_.session -ceq $MbTabSession })[0]
}

function Assert-MbTabVerbLine([string]$Verb, [string]$Line) {
    if ($Line -notmatch "^$Verb\s") { throw "$Verb output unexpected: $Line" }
}

function Read-MbTabText([string]$Path) {
    if (!(Test-Path -LiteralPath $Path)) { return '' }
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try { return (New-Object IO.StreamReader($stream)).ReadToEnd() } finally { $stream.Dispose() }
}

function Format-MbTabArgs([string[]]$Values) {
    return (($Values | ForEach-Object { if ($_ -notmatch '[\s"]') { $_ } else { '"' + ($_ -replace '"', '\"') + '"' } }) -join ' ')
}

function Invoke-MbLayoutNode([string[]]$NodeArgs) {
    $outputPath = Join-Path $workRoot 'layout-out.txt'
    $errorPath = Join-Path $workRoot 'layout-err.txt'
    $nodeProcess = Start-Process -FilePath $MbTabNode -ArgumentList (Format-MbTabArgs $NodeArgs) -NoNewWindow -Wait -PassThru -RedirectStandardOutput $outputPath -RedirectStandardError $errorPath
    $combined = (Read-MbTabText $outputPath) + (Read-MbTabText $errorPath)
    Remove-Item -LiteralPath $outputPath, $errorPath -Force -ErrorAction SilentlyContinue
    $reported = ($combined -replace 'mpk_[A-Za-z0-9_-]+', '<redacted>').Trim()
    $commandText = 'mp-layout ' + (($NodeArgs | Select-Object -Skip 1) -join ' ')
    if ($nodeProcess.ExitCode -ne 0) { throw "$commandText exited $($nodeProcess.ExitCode): $reported" }
    if ($reported -ne $combined.Trim()) { throw "$commandText printed a service key: $reported" }
    return $combined.Trim()
}

function Invoke-MbTabNode([string[]]$NodeArgs) {
    $mbTool = Join-Path $repoRoot 'tools/mb.mjs'
    $outputPath = Join-Path $workRoot 'mb-out.txt'
    $errorPath = Join-Path $workRoot 'mb-err.txt'
    $nodeProcess = Start-Process -FilePath $MbTabNode -ArgumentList (Format-MbTabArgs (@($mbTool) + $NodeArgs)) -NoNewWindow -Wait -PassThru -RedirectStandardOutput $outputPath -RedirectStandardError $errorPath
    $combined = (Read-MbTabText $outputPath) + (Read-MbTabText $errorPath)
    Remove-Item -LiteralPath $outputPath, $errorPath -Force -ErrorAction SilentlyContinue
    $reported = ($combined -replace 'mpk_[A-Za-z0-9_-]+', '<redacted>').Trim()
    if ($nodeProcess.ExitCode -ne 0) { throw ('mb ' + ($NodeArgs -join ' ') + " exited $($nodeProcess.ExitCode): $reported") }
    if ($reported -ne $combined.Trim()) { throw ('mb printed a service key: ' + $reported) }
    return $combined.Trim()
}

function Invoke-MbBumpModule([string]$BumpPath) {
    $outputPath = Join-Path $workRoot 'bump-out.txt'
    $errorPath = Join-Path $workRoot 'bump-err.txt'
    $nodeProcess = Start-Process -FilePath $MbTabNode -ArgumentList (Format-MbTabArgs @($BumpPath)) -NoNewWindow -Wait -PassThru -RedirectStandardOutput $outputPath -RedirectStandardError $errorPath
    $combined = (Read-MbTabText $outputPath) + (Read-MbTabText $errorPath)
    Remove-Item -LiteralPath $outputPath, $errorPath -Force -ErrorAction SilentlyContinue
    if ($nodeProcess.ExitCode -ne 0) { throw "layout bump exited $($nodeProcess.ExitCode): $($combined.Trim())" }
}

function Wait-MbTab([string]$Description, [scriptblock]$Check, [int]$Seconds = 90) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    do {
        if ($null -ne $appProcess) {
            $appProcess.Refresh()
            if ($appProcess.HasExited) { throw 'Desktop process exited during the mb tab journey' }
        }
        if (& $Check) { return }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Journey condition not met: $Description (checked for $Seconds seconds)"
}

function Assert-MbTabPresent([bool]$Present, [string]$Step) {
    Wait-MbTab $Step {
        $tab = Find-MbTab (Read-MbTabSession)
        if ($Present) { return $null -ne $tab } else { return $null -eq $tab }
    }
}

function Save-MbTabShot([string]$Path) {
    if ($appProcess) {
        $appProcess.Refresh()
        if ($appProcess.MainWindowHandle -ne [IntPtr]::Zero) {
            [void][MbTabWindow]::ShowWindow($appProcess.MainWindowHandle, 9)
            [void][MbTabWindow]::SetForegroundWindow($appProcess.MainWindowHandle)
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

$MbTabOpenArgs = @('open', '--kind', 'shell', '--tmux', $MbTabSession, '--title', $MbTabTitle, '--workspace', $MbTabWork, '--host', '0')

function Ensure-MbTabOpen() {
    $env:MULTIPROMPT_KEY = [string]$secrets.admin_key
    try {
        $line = Invoke-MbTabNode $MbTabOpenArgs
        Assert-MbTabVerbLine 'open' $line
    } finally { Remove-Item Env:\MULTIPROMPT_KEY -ErrorAction SilentlyContinue }
    Wait-MbTab 'imported tab' { $null -ne (Find-MbTab (Read-MbTabSession)) }
}

function Bump-MbTabLayout() {
    $env:MP_STATE = $statePath
    $env:MP_URL = "https://$accountHost"
    $bumpPath = Join-Path $workRoot 'bump.mjs'
    [IO.File]::WriteAllText($bumpPath, "import fs from 'node:fs';`nconst state = JSON.parse(fs.readFileSync(process.env.MP_STATE, 'utf8'));`nconst headers = { Authorization: 'Bearer ' + state.admin_key, 'X-Layout-Features': 'groups,favorite' };`nfor (let attempt = 1; ; attempt++) {`n  const current = await fetch(process.env.MP_URL + '/v1/layout', { headers });`n  if (!current.ok) throw new Error('read failed ' + current.status);`n  const body = await current.json();`n  const saved = await fetch(process.env.MP_URL + '/v1/layout', { method: 'PUT', headers: { ...headers, 'Content-Type': 'application/json' }, body: JSON.stringify({ base_revision: body.revision, layout: body.layout }) });`n  if (saved.ok) break;`n  if (saved.status !== 409 || attempt >= 5) throw new Error('write failed ' + saved.status);`n}`n")
    $appliedBefore = (Read-MbTabText $logPath).Length
    try { Invoke-MbBumpModule $bumpPath } finally { Remove-Item Env:\MP_STATE, Env:\MP_URL -ErrorAction SilentlyContinue }
    Wait-MbTab 'layout sync apply' { (Read-MbTabText $logPath).Length -gt $appliedBefore -and (Read-MbTabText $logPath).Substring($appliedBefore) -match 'account-sync: applied' }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$workRoot = Join-Path $env:RUNNER_TEMP ('mb-tab-' + $Feature + '-' + [guid]::NewGuid().ToString('N'))
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
$hostsFile = Join-Path $env:SystemRoot 'System32/drivers/etc/hosts'
$hostsOriginal = [IO.File]::ReadAllBytes($hostsFile)
$savedEnv = @{}
foreach ($envName in @('APPDATA', 'LOCALAPPDATA', 'USERPROFILE', 'HOME', 'MULTIPROMPT_NO_LOGIN', 'ZIGSHELL_DEBUG', 'NODE_EXTRA_CA_CERTS', 'MULTIPROMPT_KEY', 'MULTIPROMPT_URL', 'MULTIPROMPT_HOST', 'MP_STATE', 'MP_URL')) {
    $savedEnv[$envName] = [Environment]::GetEnvironmentVariable($envName, 'Process')
}
$result = @{ verdict = 'fail'; status = 'failed'; feature = $Feature; verb = $MbTabVerb; step = $stage; error = 'mb tab journey did not finish'; cleanup = 'pending' }
try {
    New-Item -ItemType Directory -Force -Path $settings, (Join-Path $workRoot 'local') | Out-Null
    $stage = 'account worker bundle'
    $worker = Join-Path $repoRoot 'service/.build/worker.js'
    if (!(Test-Path -LiteralPath $worker)) {
        Push-Location (Join-Path $repoRoot 'service')
        try {
            & $MbTabNpm ci --no-audit --no-fund
            if ($LASTEXITCODE -ne 0) { throw 'Account worker install failed' }
            & (Resolve-MbTabExecutable 'npx.cmd') wrangler deploy --dry-run --outdir .build
            if ($LASTEXITCODE -ne 0) { throw 'Account worker bundle failed' }
        } finally { Pop-Location }
    }
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
    $serviceProcess = Start-Process -FilePath $MbTabNode -ArgumentList (Format-MbTabArgs @((Join-Path $repoRoot 'service/journey/server.mjs'), '--port=443', "--pfx=$pfx", "--pfxpass=$plain", "--state=$statePath")) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $workRoot 'service.log') -RedirectStandardError (Join-Path $workRoot 'service.err.log')
    $plain = $null
    $secure.Dispose()
    $ready = $false
    for ($attempt = 0; $attempt -lt 40 -and -not $ready; $attempt++) {
        try { Invoke-RestMethod -Uri "https://$accountHost/health" | Out-Null; $ready = $true } catch { Start-Sleep -Milliseconds 250 }
    }
    if (-not $ready) { throw 'account service did not answer' }
    $secrets = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $credential = [Text.Encoding]::UTF8.GetBytes((@{ refresh_token = $secrets.refresh_token } | ConvertTo-Json -Compress))
    [IO.File]::WriteAllBytes((Join-Path $settings 'account-device.dat'), [Security.Cryptography.ProtectedData]::Protect($credential, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser))
    $env:NODE_EXTRA_CA_CERTS = $pem
    $env:MULTIPROMPT_URL = "https://$accountHost"
    $env:MULTIPROMPT_KEY = [string]$secrets.admin_key
    $env:MULTIPROMPT_HOST = '0'
    $layoutTool = Join-Path $repoRoot 'tools/mp-layout.mjs'
    [void](Invoke-MbLayoutNode @($layoutTool, 'create-section', $MbTabWork))
    [void](Invoke-MbLayoutNode @($layoutTool, 'create-section', $MbTabOther))
    Remove-Item Env:\MULTIPROMPT_KEY -ErrorAction SilentlyContinue
    $env:APPDATA = $roaming
    $env:LOCALAPPDATA = Join-Path $workRoot 'local'
    [Environment]::SetEnvironmentVariable('USERPROFILE', $workRoot, 'Process')
    $env:HOME = $workRoot
    $env:ZIGSHELL_DEBUG = '1'
    Remove-Item Env:\MULTIPROMPT_NO_LOGIN -ErrorAction SilentlyContinue
    $stage = 'desktop launch'
    $appProcess = Start-Process -FilePath $Exe -ArgumentList @('--single-window', '--name', 'mb-tab-verbs', '--no-window-restore') -PassThru -RedirectStandardOutput (Join-Path $workRoot 'desktop.log') -RedirectStandardError (Join-Path $workRoot 'desktop.err.log')
    Wait-MbTab 'desktop window' { $appProcess.Refresh(); $appProcess.MainWindowHandle -ne [IntPtr]::Zero } 60
    Save-MbTabSession 'before'
    Save-MbTabShot (Join-Path $Evidence 'before.png')
    $env:MULTIPROMPT_KEY = [string]$secrets.admin_key
    $stage = $MbTabVerb
    switch ($MbTabVerb) {
        'open' {
            $line = Invoke-MbTabNode $MbTabOpenArgs
            Assert-MbTabVerbLine 'open' $line
            Wait-MbTab 'open tab visible' {
                $state = Read-MbTabSession
                $tab = Find-MbTab $state
                $workIdx = WorkspaceIndexByName $state $MbTabWork
                return $null -ne $tab -and (Get-MbTabProperty $tab 'workspace') -eq $workIdx
            }
        }
        'close' {
            Ensure-MbTabOpen
            $line = Invoke-MbTabNode @('close', $MbTabSession, '--host', '0')
            Assert-MbTabVerbLine 'close' $line
            Assert-MbTabPresent $false 'closed tab absent'
        }
        'move' {
            Ensure-MbTabOpen
            $line = Invoke-MbTabNode @('move', $MbTabSession, '--workspace', $MbTabOther, '--host', '0')
            Assert-MbTabVerbLine 'move' $line
            Wait-MbTab 'moved workspace' {
                $state = Read-MbTabSession
                $tab = Find-MbTab $state
                $otherIdx = WorkspaceIndexByName $state $MbTabOther
                return $null -ne $tab -and (Get-MbTabProperty $tab 'workspace') -eq $otherIdx
            }
        }
        'pin' {
            Ensure-MbTabOpen
            $line = Invoke-MbTabNode @('pin', $MbTabSession, '--host', '0')
            Assert-MbTabVerbLine 'pin' $line
            Wait-MbTab 'pinned tab' {
                $t = Find-MbTab (Read-MbTabSession)
                return $null -ne $t -and (Get-MbTabProperty $t 'pinned_top') -eq $true
            }
        }
        'unpin' {
            Ensure-MbTabOpen
            Assert-MbTabVerbLine 'pin' (Invoke-MbTabNode @('pin', $MbTabSession, '--host', '0'))
            $line = Invoke-MbTabNode @('unpin', $MbTabSession, '--host', '0')
            Assert-MbTabVerbLine 'unpin' $line
            Wait-MbTab 'unpinned tab' {
                $t = Find-MbTab (Read-MbTabSession)
                return $null -ne $t -and (Get-MbTabProperty $t 'pinned_top') -ne $true
            }
        }
        'archive' {
            Ensure-MbTabOpen
            $line = Invoke-MbTabNode @('archive', $MbTabSession, '--host', '0')
            Assert-MbTabVerbLine 'archive' $line
            Assert-MbTabPresent $false 'archived tab absent from sidebar'
            Wait-MbTab 'archived tombstone' { $null -ne (Find-MbTabClosed (Read-MbTabSession)) }
        }
        'unarchive' {
            Ensure-MbTabOpen
            Assert-MbTabVerbLine 'archive' (Invoke-MbTabNode @('archive', $MbTabSession, '--host', '0'))
            Assert-MbTabPresent $false 'archived tab absent before unarchive'
            $line = Invoke-MbTabNode @('unarchive', $MbTabSession, '--host', '0')
            Assert-MbTabVerbLine 'unarchive' $line
            $line = Invoke-MbTabNode @('restore', $MbTabSession, '--host', '0')
            Assert-MbTabVerbLine 'restore' $line
            Wait-MbTab 'restored tab' { $null -ne (Find-MbTab (Read-MbTabSession)) }
        }
        'wait' {
            Ensure-MbTabOpen
            $line = Invoke-MbTabNode @('wait', $MbTabSession, '--host', '0')
            Assert-MbTabVerbLine 'wait' $line
            Wait-MbTab 'waiting tab' {
                $t = Find-MbTab (Read-MbTabSession)
                return $null -ne $t -and (Get-MbTabProperty $t 'inbox_archived') -eq $true -and (Get-MbTabProperty $t 'needs_attention') -ne $true
            }
        }
        'restore' {
            Ensure-MbTabOpen
            Assert-MbTabVerbLine 'wait' (Invoke-MbTabNode @('wait', $MbTabSession, '--host', '0'))
            $line = Invoke-MbTabNode @('restore', $MbTabSession, '--host', '0')
            Assert-MbTabVerbLine 'restore' $line
            Wait-MbTab 'restored tab' {
                $t = Find-MbTab (Read-MbTabSession)
                return $null -ne $t -and (Get-MbTabProperty $t 'inbox_archived') -ne $true
            }
        }
        'layout-sync' {
            Ensure-MbTabOpen
            Assert-MbTabVerbLine 'close' (Invoke-MbTabNode @('close', $MbTabSession, '--host', '0'))
            Assert-MbTabPresent $false 'closed before layout sync'
            Bump-MbTabLayout
            Assert-MbTabPresent $false 'still closed after layout sync'
        }
        'idempotent' {
            Ensure-MbTabOpen
            $first = Invoke-MbTabNode @('star', $MbTabSession, 'on', '--host', '0')
            $second = Invoke-MbTabNode @('star', $MbTabSession, 'on', '--host', '0')
            if ($second -notmatch 'already on') { throw "second star was not idempotent: $second" }
            if ($first -notmatch 'on') { throw "first star did not enable favorite: $first" }
            Wait-MbTab 'starred tab' {
                $t = Find-MbTab (Read-MbTabSession)
                return $null -ne $t -and (Get-MbTabProperty $t 'favorite') -eq $true
            }
        }
        Default { throw "Unsupported mb tab journey $MbTabVerb" }
    }
    Remove-Item Env:\MULTIPROMPT_KEY -ErrorAction SilentlyContinue
    Save-MbTabSession 'after'
    Save-MbTabShot (Join-Path $Evidence 'after.png')
    $result = @{ verdict = 'pass'; status = 'passed'; feature = $Feature; verb = $MbTabVerb; checks = @($MbTabVerb); cleanup = 'pending' }
} catch {
    $failure = $_
    $result.error = $_.Exception.Message
    $result.step = $stage
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
    try { [IO.File]::WriteAllBytes($hostsFile, $hostsOriginal) } catch { }
    foreach ($envName in @($savedEnv.Keys)) { [Environment]::SetEnvironmentVariable($envName, $savedEnv[$envName], 'Process') }
    if ($cert) {
        try {
            if ($rootCertAdded -and (Test-Path "Cert:\LocalMachine\Root\$($cert.Thumbprint)")) { Remove-Item "Cert:\LocalMachine\Root\$($cert.Thumbprint)" -ErrorAction SilentlyContinue }
            if (Test-Path "Cert:\LocalMachine\My\$($cert.Thumbprint)") { Remove-Item "Cert:\LocalMachine\My\$($cert.Thumbprint)" -ErrorAction SilentlyContinue }
        } catch {}
    }
    try { if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue } } catch {}
    try { $result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $Evidence 'result.json') } catch {}
}
if ($failure) { throw ("Mb tab journey failed at $stage : " + $failure.Exception.Message) }