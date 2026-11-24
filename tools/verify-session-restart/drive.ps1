param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)][string]$ExpectedHash,
    [Parameter(Mandatory)][string]$Evidence
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../verify-server-chat/native.ps1"
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Use a GitHub Windows runner' }
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
$profile = Join-Path $env:RUNNER_TEMP ('session-restart-' + [guid]::NewGuid().ToString('N'))
$settings = Join-Path $profile 'roaming/ZigShell'
$workspaceName = 'Restart Desk'
$groupName = 'Restart Group'
$chatName = 'Restart chat'
$script:chatTmux = ''
$actions = [Collections.Generic.List[object]]::new()
$result = @{
    feature = 'session-restart'
    status = 'failed'
    version = $ExpectedVersion
    sha256 = $ExpectedHash
    workspace = $workspaceName
    group = $groupName
    chat = $chatName
    tmux = $script:chatTmux
    cases = @()
}
$job = $null
$app = $null
$main = [IntPtr]::Zero
Start-Transcript "$Evidence/driver.log"
function Save($Value, [string]$Path) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false)) }
function Read-SavedSession {
    $path = "$settings/session.json"
    if (-not (Test-Path $path)) { return $null }
    try { return (Get-Content $path -Raw | ConvertFrom-Json) } catch { return $null }
}
function Wait-For([string]$Name, [scriptblock]$Check, [int]$Seconds = 120) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 250 } while ($timer.Elapsed.TotalSeconds -lt $Seconds)
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
function Rename-Text([string]$Text) {
    $edit = Wait-For 'focused rename field' {
        $h = [IntPtr]([ChatDeliveryDesktop]::Focus($main)[1])
        if ([ChatDeliveryDesktop]::Owner($h) -eq $app.Id -and [ChatDeliveryDesktop]::Class($h) -ieq 'Edit') { $h }
    }
    Press @(0x11, 0x41) 'Ctrl+A: select rename text'
    Type-Text $Text
    [void](Wait-For 'exact rename text' { [ChatDeliveryDesktop]::Text($edit) -ceq $Text })
    Press @(0x0D) 'Enter: save name'
}
function Send-Line([string]$Text) {
    $composer = Wait-For 'owned composer' { $h = [ChatDeliveryDesktop]::Composer($main); if ($h -ne [IntPtr]::Zero) { $h } }
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
    Type-Text $Text
    [void](Wait-For 'exact composer text' { [ChatDeliveryDesktop]::Text($composer) -ceq $Text })
    Press @(0x1B) 'Escape: dismiss completion'
    Press @(0x0D) 'Enter: send to real server'
    [void](Wait-For 'composer cleared' { [ChatDeliveryDesktop]::Text($composer) -eq '' })
}
function Copy-Chat([string]$Name) {
    $offset = (Log-Text).Length
    Press @(0x11, 0x4B) 'Ctrl+K: open command palette'
    [void](Wait-For 'palette ready' { (Log-Text).Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    Type-Text 'chat view select all'
    [void](Wait-For 'select all' { (Log-Text).Substring($offset) -match '\[palette\] ready chars=20 count=\d+ target=6364(?:\s|$)' })
    Press @(0x0D) 'Enter: select rendered messages'
    Press @(0x11, 0x43) 'Ctrl+C: copy rendered messages'
    $text = [Windows.Forms.Clipboard]::GetText()
    [IO.File]::WriteAllText("$Evidence/$Name.txt", $text)
    Press @(0x1B) 'Escape: return to composer'
    return $text
}
function Server-Snapshot([string]$Name) {
    $raw = Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$settings/ssh-key/config", 'remote-1', "python3 $repo/tools/verify-server-chat/snapshot.py") -Evidence $Evidence -Name ($Name + '-' + [guid]::NewGuid().ToString('N'))
    $snapshot = ($raw -join "`n") | ConvertFrom-Json
    Save $snapshot "$Evidence/$Name.json"
    return $snapshot
}
function Invoke-LinuxMpSessions([string[]]$CliArgs, [string]$Label) {
    $safe = ($CliArgs | ForEach-Object { "'" + ($_ -replace "'", "'\\''") + "'" }) -join ' '
    $socket = Wait-For 'owned server relay' {
        $links = [regex]::Matches((Log-Text), 'alert-link ready host=unix (/tmp/mp-notify-\d+/[A-Za-z0-9_.-]+\.sock)')
        if ($links.Count) { $links[$links.Count - 1].Groups[1].Value }
    }
    $remote = "export MULTIPROMPT_HOST=0 ZSB_SOCKET='$socket'; ~/.multiprompt-runtime/mp-sessions " + $safe
    $out = Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$settings/ssh-key/config", 'remote-1', $remote) -Evidence $Evidence -Name $Label
    $out.Trim()
}
function Find-ChatTab($state) {
    if ($null -eq $state -or -not $script:chatTmux) { return $null }
    return $state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq $script:chatTmux } | Select-Object -First 1
}
function Assert-ChatTab([string]$Stage) {
    $state = Read-SavedSession
    Save $state "$Evidence/$Stage.layout.json"
    $tab = Find-ChatTab $state
    if ($null -eq $tab) { throw "$Stage : saved chat tab $chatTmux missing" }
    if (-not ($tab.PSObject.Properties['cv'] -and $tab.cv -eq $true)) { throw "$Stage : tab reopened as shell (cv=false), not a chat tab" }
    $ws = $null
    if ($state.PSObject.Properties['workspaces'] -and @($state.workspaces).Count -gt $tab.workspace) {
        $ws = $state.workspaces[$tab.workspace].name
    }
    if ([string]::IsNullOrWhiteSpace($ws)) { $ws = 'Workspace ' + ($tab.workspace + 1) }
    if ($ws -cne $workspaceName) { throw "$Stage : workspace is $ws not $workspaceName" }
    $gid = $null
    if ($tab.PSObject.Properties['group_id']) { $gid = $tab.group_id }
    if ($null -eq $gid -or $gid -le 0) { throw "$Stage : chat is not in a group" }
    $group = @($state.groups | Where-Object { $_.id -eq $gid })[0]
    if ($null -eq $group -or $group.name -cne $groupName) { throw "$Stage : group name mismatch" }
    if ($tab.name -cne $chatName) { throw "$Stage : tab title is $($tab.name)" }
    Save @{ stage = $Stage; tab = $tab; workspace = $ws; group = $group.name } "$Evidence/$Stage.session.json"
    return $tab
}
function Restart-DesktopApp {
    if ($null -eq $app -or $app.HasExited) { throw 'No owned app to restart' }
    Doctor
    [void]$app.CloseMainWindow()
    if (-not $app.WaitForExit(20000)) { $app.Kill(); $app.WaitForExit() }
    $stopped = $job.Stop()
    if ($stopped.ActiveProcesses -ne 0) { throw 'Owned job still has processes before desktop relaunch' }
    $job.Dispose()
    $relaunchLogOffset = (Log-Text).Length
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $profile, "$Evidence/relaunch-stdout.log", "$Evidence/relaunch-stderr.log", '--single-window')
    $main = Wait-For 'relaunched window' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    [void](Wait-For 'relaunched restore' {
        $log = Log-Text
        $tail = if ($log.Length -ge $relaunchLogOffset) { $log.Substring($relaunchLogOffset) } else { $log }
        $tail -match 'launch step=browser'
    })
    [void](Wait-For 'restored shells' { @((Read-SavedSession).tabs).Count -gt 0 })
}
try {
    $repo = (Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'wslpath', '-a', $env:GITHUB_WORKSPACE) -Evidence $Evidence -Name 'driver-repo-path').Trim()
    & "$PSScriptRoot/../verify-server-chat/start.ps1" -Profile $profile -Evidence $Evidence
    [void](Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'bash', "$repo/tools/verify-session-restart/prepare-server.sh", $repo) -Evidence $Evidence -Name 'prepare-mp-talk')
    $ssh = "$env:SystemRoot/System32/OpenSSH/ssh.exe"
    $env:APPDATA = "$profile/roaming"
    $env:LOCALAPPDATA = "$profile/local"
    $env:USERPROFILE = "$profile/home"
    $env:HOME = "$profile/home"
    $env:MULTIPROMPT_NO_LOGIN = '1'
    $env:ZIGSHELL_DEBUG = '1'
    $env:IGSH_246 = '0'
    $env:PATH = (Split-Path $ssh) + ';' + $env:PATH
    Save @{
        active_tab = 0
        single_window = $false
        shared_server_connection = $true
        chat_active = $false
        tabs = @(@{ kind = 'tmux'; name = 'Anchor server'; manual = $true; tmux_host = 0; tmux_session = 'live-ci'; csid = 'a1b2c3d4-2567-4000-8000-000000002567'; cv = $true; pid = 0 })
    } "$settings/session.json"
    if ((Get-FileHash $Exe -Algorithm SHA256).Hash -ine $ExpectedHash -or -not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable checksum/version mismatch' }
    Add-Type -AssemblyName System.Drawing, System.Windows.Forms, UIAutomationClient, UIAutomationTypes
    Add-Type -Path "$PSScriptRoot/../verify-chat-delivery/desktop.cs"
    Add-Type -Path "$PSScriptRoot/../verify-chat-delivery/job.cs"
    [void][ChatDeliveryDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $profile, "$Evidence/stdout.log", "$Evidence/stderr.log", '--single-window', '--no-window-restore')
    $main = Wait-For 'owned app window' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    Press @(0x11, 0x31) 'Ctrl+1: open anchor server tab'
    [void](Wait-For 'anchor transcript' { (Log-Text) -match '\[chat\] transcript load shell=\d+ ok' })
    [void](Wait-For 'shared connection saved' { (Read-SavedSession).shared_server_connection -eq $true } 60)
    [void](Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$settings/ssh-key/config", 'remote-1', 'test -f ~/.local/state/multiprompt/relay-v1 && test -x ~/.multiprompt-runtime/mp-sessions && test -x ~/.multiprompt-runtime/mp-zsb') -Evidence $Evidence -Name 'relay-ready')
    Press @(0x11, 0x4E) 'Ctrl+N: new workspace'
    [void](Wait-For 'extra workspace' { @((Read-SavedSession).workspaces).Count -ge 2 })
    Press @(0x11, 0x4B) 'Ctrl+K: rename workspace'
  [void](Wait-For 'rename workspace' { (Log-Text) -match '\[palette\]' })
    Type-Text 'rename workspace'
    Press @(0x0D) 'Enter: Rename workspace'
    Rename-Text $workspaceName
    [void](Wait-For 'named workspace saved' { (Read-SavedSession).workspaces[(Read-SavedSession).active_workspace].name -ceq $workspaceName })
    Press @(0x71) 'F2: rename active tab for grouping'
    Rename-Text 'Group anchor'
    Press @(0x11, 0x4B) 'Ctrl+K: Move to Group'
    [void](Wait-For 'move to group menu' { (Log-Text) -match '\[palette\]' })
    Type-Text 'move to group'
    Press @(0x0D) 'Enter: Move to Group'
    Type-Text 'new group'
    Press @(0x0D) 'Enter: New group'
    Rename-Text $groupName
    [void](Wait-For 'named group saved' {
        $s = Read-SavedSession
        @($s.groups | Where-Object { $_.name -ceq $groupName }).Count -eq 1
    })
    $layout = Read-SavedSession
    $groupRow = @($layout.groups | Where-Object { $_.name -ceq $groupName })[0]
    if ($null -eq $groupRow) { throw 'Named group was not created' }
    $wsIndex = $layout.active_workspace
    if ($layout.workspaces[$wsIndex].name -cne $workspaceName) { throw 'Named workspace was not created' }
    $result.workspace = $workspaceName
    $result.group = $groupName
    $folder = (Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$settings/ssh-key/config", 'remote-1', 'pwd') -Evidence $Evidence -Name 'remote-cwd').Trim()
    $startJson = Invoke-LinuxMpSessions @('start', '--name', $chatName, '--workspace', $workspaceName, '--group', $groupName, '--folder', $folder) 'mp-sessions-start'
    $started = $startJson | ConvertFrom-Json
    if ($started.ok -ne $true) { throw 'mp-sessions start failed: ' + $startJson }
    $script:chatTmux = [string]$started.tmux
    $result.tmux = $script:chatTmux
    if (-not $script:chatTmux) { throw 'mp-sessions start returned no tmux session' }
    [void](Wait-For 'chat tab visible' { $null -ne (Find-ChatTab (Read-SavedSession)) } 90)
    Press @(0x11, 0x4B) 'Ctrl+K: select chat tab'
    Type-Text $chatName
    Press @(0x0D) 'Enter: focus restart chat'
    Press @(0x11, 0x4B) 'Ctrl+K: initial Chat View'
    Type-Text 'Chat View on everywhere'
    Press @(0x0D) 'Enter: initial Chat View on everywhere'
    Send-Line 'restart journey proof one'
    [void](Wait-For 'first server reply' {
        $snapshot = Server-Snapshot 'first-send'
        @($snapshot.inputs | Where-Object { $_.text -ceq 'restart journey proof one' }).Count -eq 1
    })
    [void](Wait-For 'first painted reply' { (Copy-Chat 'first-send-copied').Contains('Server received: restart journey proof one') } 45)
    Assert-ChatTab 'before-restart'
    Shot 'before-restart'
    $result.cases += @{ name = 'before-restart'; passed = $true; detail = 'Hosted chat with reply in named workspace and group' }
    Press @(0x11, 0x4B) 'Ctrl+K: leave the chat tab in the background'
    Type-Text 'Group anchor'
    Press @(0x0D) 'Enter: focus the group anchor tab'
    [void](Wait-For 'chat tab in the background' {
        $state = Read-SavedSession
        $tab = Find-ChatTab $state
        if ($null -eq $tab) { return $false }
        if (-not $state.PSObject.Properties['active_shell_id']) { return $false }
        if (-not $tab.PSObject.Properties['shell_id']) { return $false }
        return $state.active_shell_id -ne $tab.shell_id
    } 60)
    $closeJson = Invoke-LinuxMpSessions @('close', $chatName) 'mp-sessions-close'
    $closed = $closeJson | ConvertFrom-Json
    if ($closed.status -cne 'closed') { throw 'mp-sessions close failed: ' + $closeJson }
    [void](Wait-For 'chat tab closed' { $null -eq (Find-ChatTab (Read-SavedSession)) } 60)
    $restartJson = Invoke-LinuxMpSessions @('restart', $chatName) 'mp-sessions-restart'
    $restarted = $restartJson | ConvertFrom-Json
    if ($restarted.status -cne 'restarted' -and $restarted.status -cne 'already') { throw 'mp-sessions restart failed: ' + $restartJson }
    [void](Wait-For 'chat tab reopened' { $null -ne (Find-ChatTab (Read-SavedSession)) } 90)
    Assert-ChatTab 'after-mp-sessions-restart'
    Press @(0x11, 0x4B) 'Ctrl+K: show restarted chat'
    Type-Text $chatName
    Press @(0x0D) 'Enter: show restarted chat'
    [void](Wait-For 'restarted chat composer' { [ChatDeliveryDesktop]::Composer($main) -ne [IntPtr]::Zero })
    Shot 'after-mp-sessions-restart'
    $result.cases += @{ name = 'mp-sessions-close-restart'; passed = $true; detail = 'close then restart restored a chat tab with cv=true in the same workspace and group' }
    . Restart-DesktopApp
    [void](Wait-For 'chat after app restart' { $null -ne (Find-ChatTab (Read-SavedSession)) } 120)
    Assert-ChatTab 'after-app-restart'
    Shot 'after-app-restart'
    Press @(0x11, 0x4B) 'Ctrl+K: select chat after relaunch'
    Type-Text $chatName
    Press @(0x0D) 'Enter: focus restart chat after relaunch'
    [void](Wait-For 'relaunched chat transcript' {
        $log = Log-Text
        $tail = if ($log.Length -ge $relaunchLogOffset) { $log.Substring($relaunchLogOffset) } else { $log }
        $tab = Find-ChatTab (Read-SavedSession)
        $hasSid = $null -ne $tab -and $tab.PSObject.Properties['csid'] -and -not [string]::IsNullOrWhiteSpace([string]$tab.csid) -and $tab.PSObject.Properties['shell_id']
        $hasSid -and ($tail -match ('\[chat\] transcript load shell=' + [regex]::Escape([string]$tab.shell_id) + ' ok'))
    } 60)
    Send-Line 'restart journey proof two'
    [void](Wait-For 'second server reply' {
        $snapshot = Server-Snapshot 'second-send'
        @($snapshot.inputs | Where-Object { $_.text -ceq 'restart journey proof two' }).Count -eq 1
    })
    [void](Wait-For 'second painted reply' { (Copy-Chat 'second-send-copied').Contains('Server received: restart journey proof two') } 45)
    Shot 'after-restart'
    $result.cases += @{ name = 'after-app-restart'; passed = $true; detail = 'App restart kept chat tab; second message got a visible reply' }
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
    if (Test-Path "$settings/session.json") { Copy-Item "$settings/session.json" "$Evidence/final-session.json" }
    Remove-Item -LiteralPath $profile -Recurse -Force -ErrorAction SilentlyContinue
    $result.keyRemoved = -not (Test-Path "$settings/ssh-key/multibot_ed25519")
    if (-not $result.keyRemoved) { $result.status = 'failed'; $result.error = 'Private key cleanup failed' }
    Save $actions "$Evidence/actions.json"
    Save $result "$Evidence/result.json"
    Stop-Transcript
}
if ($result.status -ne 'passed') { throw ($result['error'], $result['cleanupError'] -join "`n") }