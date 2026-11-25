param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)][string]$ExpectedHash,
    [Parameter(Mandatory)][string]$Evidence
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/native.ps1"
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Use a GitHub Windows runner' }
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
$profile = Join-Path $env:RUNNER_TEMP ('server-chat-' + [guid]::NewGuid().ToString('N'))
$settings = Join-Path $profile 'roaming/ZigShell'
$actions = [Collections.Generic.List[object]]::new()
$result = @{ feature = 'server-chat'; status = 'failed'; version = $ExpectedVersion; sha256 = $ExpectedHash; cases = @(); agentBoundary = 'Real Windows app, Windows OpenSSH, WSL Linux OpenSSH server, tmux and production host/reader. Only the paid Claude process is a deterministic stream-json provider. Clear proves a new provider conversation, an empty view after reload and a subsequent reply without Not sent; paid Claude internals are outside this fixture.' }
$job = $null
Start-Transcript "$Evidence/driver.log"
function Save($Value, [string]$Path) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 15), [Text.UTF8Encoding]::new($false)) }
function Wait-For([string]$Name, [scriptblock]$Check, [int]$Seconds = 90) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 200 } while ($timer.Elapsed.TotalSeconds -lt $Seconds)
    throw "Timed out: $Name"
}
function Log-Text {
    $path = "$settings/debug.log"
    if (-not (Test-Path $path)) { return '' }
    $stream = [IO.File]::Open($path, 'Open', 'Read', ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    try { $reader = [IO.StreamReader]::new($stream); try { $reader.ReadToEnd() } finally { $reader.Dispose() } } finally { $stream.Dispose() }
}
function Doctor {
    $app.Refresh()
    if ($app.HasExited -or $app.Path -ne $Exe -or [ChatDeliveryDesktop]::Owner($main) -ne $app.Id -or [ChatDeliveryDesktop]::Class($main) -ne 'ZigShell') { throw 'Doctor: owned app identity changed' }
    $element = [Windows.Automation.AutomationElement]::FromHandle($main)
    if ($element.Current.IsOffscreen -or $element.Current.ProcessId -ne $app.Id) { throw 'Doctor: app is not visible' }
}
function Shot([string]$Name) {
    $bitmap = [Drawing.Bitmap]::new([ChatDeliveryDesktop]::GetSystemMetrics(0), [ChatDeliveryDesktop]::GetSystemMetrics(1))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen(0, 0, 0, 0, $bitmap.Size); $bitmap.Save("$Evidence/$Name.png", [Drawing.Imaging.ImageFormat]::Png) } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Press([int[]]$Keys, [string]$Label) {
    Doctor
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $main) }
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Refusing input outside the owned app' }
    $actions.Add(@{ input = $Label; keys = $Keys; at = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() })
    [ChatDeliveryDesktop]::Chord($Keys)
    Start-Sleep -Milliseconds 150
}
function Type-Text([string]$Text) {
    $actions.Add(@{ input = 'type'; text = $Text; at = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() })
    foreach ($letter in $Text.ToCharArray()) { Doctor; [ChatDeliveryDesktop]::Character($letter); Start-Sleep -Milliseconds 20 }
}
function Copy-Chat([string]$Name) {
    $offset = (Log-Text).Length
    Press @(0x11, 0x4B) 'Ctrl+K: open command palette'
    [void](Wait-For 'palette ready' { (Log-Text).Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    Type-Text 'chat view select all'
    [void](Wait-For 'select all messages command' { (Log-Text).Substring($offset) -match '\[palette\] ready chars=20 count=\d+ target=6364(?:\s|$)' })
    Press @(0x0D) 'Enter: select rendered messages'
    [Windows.Forms.Clipboard]::Clear()
    Press @(0x11, 0x43) 'Ctrl+C: copy rendered messages'
    $text = [Windows.Forms.Clipboard]::GetText()
    [IO.File]::WriteAllText("$Evidence/$Name.txt", $text)
    Press @(0x1B) 'Escape: return to composer'
    return $text
}
function Send-Line([string]$Text) {
    $composer = Wait-For 'owned composer' { $h = [ChatDeliveryDesktop]::Composer($main); if ($h -ne [IntPtr]::Zero) { $h } }
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
    Type-Text $Text
    [void](Wait-For 'exact composer text' { [ChatDeliveryDesktop]::Text($composer) -ceq $Text })
    Press @(0x1B) 'Escape: dismiss completion without changing the text'
    Press @(0x0D) 'Enter: send to real server'
    [void](Wait-For 'composer cleared' { [ChatDeliveryDesktop]::Text($composer) -ceq '' })
}
function Server-Snapshot([string]$Name) {
    $raw = Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$settings/ssh-key/config", 'remote-1', "python3 $repo/tools/verify-server-chat/snapshot.py") -Evidence $Evidence -Name ($Name + '-' + [guid]::NewGuid().ToString('N'))
    $snapshot = ($raw -join "`n") | ConvertFrom-Json
    Save $snapshot "$Evidence/$Name.json"
    return $snapshot
}
try {
    $repo = (Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'wslpath', '-a', $env:GITHUB_WORKSPACE) -Evidence $Evidence -Name 'driver-repo-path').Trim()
    & "$PSScriptRoot/start.ps1" -Profile $profile -Evidence $Evidence
    $ssh = "$env:SystemRoot/System32/OpenSSH/ssh.exe"
    $env:APPDATA = "$profile/roaming"
    $env:LOCALAPPDATA = "$profile/local"
    $env:USERPROFILE = "$profile/home"
    $env:HOME = "$profile/home"
    $env:MULTIPROMPT_NO_LOGIN = '1'
    $env:ZIGSHELL_DEBUG = '1'
    $env:IGSH_246 = '0'
    $env:PATH = (Split-Path $ssh) + ';' + $env:PATH
    Save @{ active_tab = 0; single_window = $false; chat_active = $false; tabs = @(@{ kind = 'tmux'; name = 'Runner server chat'; manual = $true; tmux_host = 0; tmux_session = 'live-ci'; csid = 'a1b2c3d4-2567-4000-8000-000000002567'; cv = $false; pid = 0 }) } "$settings/session.json"
    if ((Get-FileHash $Exe -Algorithm SHA256).Hash -ine $ExpectedHash -or -not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable checksum/version mismatch' }
    Add-Type -AssemblyName System.Drawing, System.Windows.Forms, UIAutomationClient, UIAutomationTypes
    Add-Type -Path "$PSScriptRoot/../verify-chat-delivery/desktop.cs"
    Add-Type -Path "$PSScriptRoot/../verify-chat-delivery/job.cs"
    [void][ChatDeliveryDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $profile, "$Evidence/stdout.log", "$Evidence/stderr.log", '--no-window-restore')
    $main = Wait-For 'owned app window' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    Press @(0x11, 0x31) 'Ctrl+1: open server tab'
    Press @(0x12, 0x43) 'Alt+C: open server Chat View'
    [void](Wait-For 'server transcript loaded' { (Log-Text) -match '\[chat\] transcript load shell=\d+ ok' })
    $opened = Copy-Chat 'open-copied'
    if (-not $opened.Contains('Server received: server seed')) { throw 'Open did not show the real server reply' }
    Shot 'open'
    $result.cases += @{ name = 'open'; passed = $true; detail = 'Copied the host-persisted seed reply from the real UI' }
    foreach ($case in @(@{ name = 'send'; text = 'windows send proof' }, @{ name = 'clear'; text = '/clear' }, @{ name = 'after-clear'; text = 'windows after clear' })) {
        Send-Line $case.text
        if ($case.name -eq 'clear') {
            [void](Wait-For 'new empty server conversation' {
                $snapshot = Server-Snapshot 'clear-server'
                $snapshot.host.state.context_session -and $snapshot.host.state.context_session -ne 'a1b2c3d4-2567-4000-8000-000000002567' -and
                    $snapshot.host.state.native_session -eq $snapshot.host.state.context_session -and
                    @($snapshot.inputs | Where-Object { $_.text.Trim() -eq '/clear' }).Count -eq 0
            })
            [void](Wait-For 'empty Chat View after clear' { (Copy-Chat 'clear-copied').Trim() -eq '' } 30)
            Shot 'clear'
            $offset = (Log-Text).Length
            Press @(0x11, 0x4B) 'Ctrl+K: reload chat'
            [void](Wait-For 'reload palette ready' { (Log-Text).Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
            Type-Text 'resync'
            [void](Wait-For 'reload command ready' { (Log-Text).Substring($offset) -match '\[palette\] ready chars=6 count=\d+ target=6493(?:\s|$)' })
            Press @(0x0D) 'Enter: reload messages from the server'
            [void](Wait-For 'server reload requested' { (Log-Text).Substring($offset).Contains('[chat] resync requested') })
            [void](Wait-For 'empty Chat View after reload' { (Copy-Chat 'clear-reloaded-copied').Trim() -eq '' } 30)
            Shot 'clear-reloaded'
        } else {
            [void](Wait-For ('server receipt for ' + $case.name) { $snapshot = Server-Snapshot ($case.name + '-server'); @($snapshot.inputs | Where-Object { $_.text -ceq $case.text }).Count -eq 1 })
            [void](Wait-For ('painted reply for ' + $case.name) {
                $copied = Copy-Chat ($case.name + '-copied')
                $copied.Contains('Server received: ' + $case.text) -and -not $copied.Contains('Not sent')
            } 30)
            if ($case.name -eq 'after-clear' -and ((Copy-Chat 'after-clear-copied').Contains('server seed') -or (Copy-Chat 'after-clear-copied').Contains('windows send proof'))) { throw 'Old messages returned after clear' }
            Shot $case.name
        }
        $result.cases += @{ name = $case.name; passed = $true; detail = 'Clear leaves an empty view after reload; ordinary sends reach the provider once with no Not sent' }
    }
    Save @{ pid = $app.Id; hwnd = $main.ToInt64(); exe = $app.Path; sha256 = $ExpectedHash; visible = $true } "$Evidence/doctor.json"
    $result.status = 'passed'
} catch {
    $result.error = $_.ToString()
    if ($null -ne $job) { Shot 'failure' }
    throw
} finally {
    if ($null -ne $job) { $cleanup = $job.Stop(); $result.cleanup = @{ activeAfterStop = $cleanup.ActiveProcesses }; $job.Dispose() }
    if (Test-Path "$settings/debug.log") { Copy-Item "$settings/debug.log" "$Evidence/debug.log" }
    try {
        $linuxEvidence = (Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'wslpath', '-a', $Evidence) -Evidence $Evidence -Name 'evidence-path').Trim()
        [void](Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'bash', "$repo/tools/verify-server-chat/stop.sh", $linuxEvidence) -Evidence $Evidence -Name 'server-stop')
    } catch {
        $result.cleanupError = $_.ToString()
        $result.status = 'failed'
    }
    try {
        [void](Invoke-ServerNative -FilePath wsl.exe -Arguments @('--terminate', 'Ubuntu-24.04') -Evidence $Evidence -Name 'wsl-terminate')
    } catch {
        $result.cleanupError = ($result['cleanupError'], $_.ToString() -join "`n")
        $result.status = 'failed'
    }
    Remove-Item -LiteralPath $profile -Recurse -Force -ErrorAction SilentlyContinue
    $result.keyRemoved = -not (Test-Path "$settings/ssh-key/multibot_ed25519")
    if (-not $result.keyRemoved) { $result.status = 'failed'; $result.error = 'Private key cleanup failed' }
    Save $actions "$Evidence/actions.json"
    Save $result "$Evidence/result.json"
    Stop-Transcript
}
if ($result.status -ne 'passed') { throw ($result['error'], $result['cleanupError'] -join "`n") }
