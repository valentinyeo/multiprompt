param([Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string]$Output)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $Output | Out-Null
$Output = (Resolve-Path $Output).Path
$Exe = (Resolve-Path $Exe).Path
$repo = (Resolve-Path "$PSScriptRoot/../..").Path
Start-Transcript "$Output/driver.log"
Add-Type -AssemblyName System.Drawing
try { Add-Type -AssemblyName System.Security } catch {}
Add-Type -Path "$repo/tools/verify-reconnect/desktop.cs"
[void][ReconnectDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
$work = Join-Path $env:RUNNER_TEMP ('account-journey-' + [guid]::NewGuid().ToString('N'))
$settings = "$work/roaming/ZigShell"
$log = "$settings/debug.log"
$hostName = 'account.multiprompt.dev'
$app = $null
$server = $null
$failure = $null
$results = [ordered]@{}
function Read-Log {
    if (!(Test-Path $log)) { return '' }
    for ($retry = 0; $retry -lt 100; $retry++) {
        $stream = $null
        $reader = $null
        try {
            $stream = [IO.File]::Open($log, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
            $reader = [IO.StreamReader]::new($stream)
            return $reader.ReadToEnd()
        } catch [IO.IOException] {
            if ($retry -eq 99) { throw }
            Start-Sleep -Milliseconds 10
        } finally {
            if ($reader) { $reader.Dispose() } elseif ($stream) { $stream.Dispose() }
        }
    }
}
function Wait-For([string]$Description, [scriptblock]$Check, [int]$Seconds = 90) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 100 } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out: $Description"
}
function Shot([string]$Name) {
    $bitmap = [Drawing.Bitmap]::new([ReconnectDesktop]::GetSystemMetrics(0), [ReconnectDesktop]::GetSystemMetrics(1))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen(0, 0, 0, 0, $bitmap.Size); $bitmap.Save("$Output/$Name.png", [Drawing.Imaging.ImageFormat]::Png) }
    finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Cli([string]$Key, [string[]]$Arguments) {
    $env:MULTIPROMPT_KEY = $Key
    $text = (& node "$repo/tools/mp-layout.mjs" @Arguments 2>&1 | Out-String).Trim()
    $code = $LASTEXITCODE
    Remove-Item Env:MULTIPROMPT_KEY
    @{code=$code; text=$text}
}
try {
    New-Item -ItemType Directory -Force $settings, "$work/local" | Out-Null
    $password = ConvertTo-SecureString -String ([guid]::NewGuid().ToString('N')) -AsPlainText -Force
    $cert = New-SelfSignedCertificate -DnsName $hostName -CertStoreLocation Cert:\LocalMachine\My -NotAfter (Get-Date).AddDays(2)
    $pfx = "$work/service.pfx"
    $cer = "$work/service.cer"
    [void](Export-PfxCertificate -Cert $cert -FilePath $pfx -Password $password)
    [void](Export-Certificate -Cert $cert -FilePath $cer)
    [void](Import-Certificate -FilePath $cer -CertStoreLocation Cert:\LocalMachine\Root)
    $pem = "$work/service.pem"
    $b64 = [Convert]::ToBase64String($cert.RawData, 'InsertLineBreaks')
    [IO.File]::WriteAllText($pem, "-----BEGIN CERTIFICATE-----`n$b64`n-----END CERTIFICATE-----`n")
    Add-Content -Path "$env:SystemRoot/System32/drivers/etc/hosts" -Value "127.0.0.1 $hostName"
    $env:NODE_EXTRA_CA_CERTS = $pem
    $state = "$work/service-state.json"
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
    $server = Start-Process node -ArgumentList "`"$repo/service/journey/server.mjs`"", '--port=443', "--pfx=`"$pfx`"", "--pfxpass=$plain", "--state=`"$state`"" -PassThru -RedirectStandardOutput "$Output/service.log" -RedirectStandardError "$Output/service.err.log"
    [void](Wait-For 'test account service' { Test-Path $state } 60)
    $secrets = Get-Content $state -Raw | ConvertFrom-Json
    $probe = & curl.exe -s "https://$hostName/v1/layout"
    if ($probe -notmatch 'device_required') { throw "Service not reachable under the real hostname: $probe" }
    $results.service_probe = 'device_required over https with the real hostname'

    $credential = [Text.Encoding]::UTF8.GetBytes((@{refresh_token=$secrets.refresh_token} | ConvertTo-Json -Compress))
    $protected = [Security.Cryptography.ProtectedData]::Protect($credential, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    [IO.File]::WriteAllBytes("$settings/account-device.dat", $protected)
    $env:APPDATA = "$work/roaming"
    $env:LOCALAPPDATA = "$work/local"
    $env:ZIGSHELL_DEBUG = '1'
    Remove-Item Env:MULTIPROMPT_NO_LOGIN -ErrorAction SilentlyContinue
    $app = Start-Process $Exe -ArgumentList '--no-window-restore' -PassThru
    $main = Wait-For 'app window' { $h = [ReconnectDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    [void][ReconnectDesktop]::SetForegroundWindow($main)
    [void](Wait-For 'first layout from the account service' { (Read-Log) -match 'account-sync: applied workspaces=2 tabs=5' } 60)
    Start-Sleep -Seconds 3
    Shot 'desktop-before'
    $results.before = 'desktop applied workspaces=2 tabs=5'

    $listed = Cli $secrets.admin_key @('list')
    $listed.text | Set-Content "$Output/cli-list.txt"
    if ($listed.code -ne 0 -or $listed.text -notmatch 'runner-3') { throw "admin list failed: $($listed.text)" }

    $offset = (Read-Log).Length
    $start = [DateTime]::UtcNow
    $moved = Cli $secrets.admin_key @('move', '--to', 'Runners', '--create', '--match', 'runner-*')
    $moved.text | Set-Content "$Output/cli-move.txt"
    if ($moved.code -ne 0 -or $moved.text -notmatch 'moved 3 sessions to Runners') { throw "admin move failed: $($moved.text)" }
    [void](Wait-For 'desktop shows the new section' { (Read-Log).Substring($offset) -match 'account-sync: applied workspaces=3 tabs=5' } 30)
    $seen = [DateTime]::UtcNow
    Shot 'desktop-after'
    $elapsed = ($seen - $start).TotalSeconds
    $results.admin_move = $moved.text
    $results.desktop_seconds_to_show_new_section = [Math]::Round($elapsed, 2)
    if ($elapsed -gt 10) { throw "Desktop took $elapsed seconds to show the new section" }

    $scoped = Cli $secrets.workspace_key @('list')
    $scoped.text | Set-Content "$Output/cli-workspace-list.txt"
    if ($scoped.code -ne 0 -or $scoped.text -match 'runner-' -or $scoped.text -notmatch 'notes-a') { throw "workspace key list is wrong: $($scoped.text)" }
    $own = Cli $secrets.workspace_key @('open', 'notes-new', '--no-tmux')
    $own.text | Set-Content "$Output/cli-workspace-open.txt"
    if ($own.code -ne 0) { throw "workspace key could not open in its own workspace: $($own.text)" }
    $refused = Cli $secrets.workspace_key @('move', '--to', 'Work', 'notes-a')
    $refused.text | Set-Content "$Output/cli-workspace-refused.txt"
    if ($refused.code -eq 0 -or $refused.text -notmatch 'refused|not found') { throw "workspace key was not refused: $($refused.text)" }
    $other = Cli $secrets.other_key @('list')
    $other.text | Set-Content "$Output/cli-other-workspace.txt"
    if ($other.code -eq 0) { throw 'a key for another workspace was accepted' }
    $results.workspace_list = $scoped.text
    $results.workspace_refusal = $refused.text
    $results.other_workspace = $other.text

    $offset = (Read-Log).Length
    $start = [DateTime]::UtcNow
    $opened = Cli $secrets.admin_key @('open', 'fresh-session', '--workspace', 'Runners', '--title', 'Fresh session', '--no-tmux')
    $opened.text | Set-Content "$Output/cli-open.txt"
    if ($opened.code -ne 0) { throw "open failed: $($opened.text)" }
    [void](Wait-For 'desktop shows the opened session' { (Read-Log).Substring($offset) -match 'account-sync: applied workspaces=3 tabs=7' } 30)
    $openSeconds = ([DateTime]::UtcNow - $start).TotalSeconds
    Shot 'desktop-opened'
    $results.open = $opened.text
    $results.desktop_seconds_to_show_opened_session = [Math]::Round($openSeconds, 2)
    if ($openSeconds -gt 10) { throw "Desktop took $openSeconds seconds to show the opened session" }
    $results.verdict = 'pass'
} catch {
    $failure = $_
    $results.verdict = 'fail'
    $results.error = "$_"
    try { Shot 'desktop-failure' } catch {}
} finally {
    $results | ConvertTo-Json -Depth 5 | Set-Content "$Output/result.json"
    if (Test-Path $log) { Copy-Item $log "$Output/debug.log" }
    if ($app -and !$app.HasExited) { Stop-Process -Id $app.Id -Force }
    if ($server -and !$server.HasExited) { Stop-Process -Id $server.Id -Force }
    Stop-Transcript | Out-Null
}
if ($failure) { throw $failure }
