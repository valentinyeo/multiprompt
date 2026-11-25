param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)][string]$ExpectedHash,
    [Parameter(Mandatory)][string]$Evidence
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. "$PSScriptRoot/../../../tools/verify-server-chat/native.ps1"
$Exe = (Resolve-Path $Exe).Path
$Evidence = [IO.Path]::GetFullPath($Evidence)
New-Item -ItemType Directory -Force $Evidence | Out-Null
$profile = Join-Path $env:RUNNER_TEMP ('rooms-' + [guid]::NewGuid().ToString('N'))
$settings = "$profile/roaming/ZigShell"
$actions = [Collections.Generic.List[object]]::new()
$result = @{ feature = 'rooms'; status = 'failed'; cases = @(); driverErrors = @(); version = $ExpectedVersion; sha256 = $ExpectedHash; boundary = 'Runner-owned account Worker, real SSH/tmux and production room/host/reader. Only paid Claude is replaced by a deterministic stream-json process.' }
$app = $null
$job = $null
$serviceJob = $null
$cert = $null
$hostsFile = "$env:SystemRoot/System32/drivers/etc/hosts"
$hostsOriginal = [IO.File]::ReadAllBytes($hostsFile)
$watcher = $null
$clock = [Diagnostics.Stopwatch]::StartNew()
function Save($Value, [string]$Path) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false)) }
function Read-Shared([string]$Path) {
    if (-not (Test-Path $Path)) { return '' }
    $stream = [IO.File]::Open($Path, 'Open', 'Read', ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    try { $reader = [IO.StreamReader]::new($stream); try { $reader.ReadToEnd() } finally { $reader.Dispose() } } finally { $stream.Dispose() }
}
function Wait-For([string]$Name, [scriptblock]$Check, [int]$Seconds = 45) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        $value = & $Check
        if ($value) { return $value }
        if ($null -ne $app -and $app.HasExited) { throw 'Owned desktop exited' }
        [void]$watcher.WaitForChanged([IO.WatcherChangeTypes]::All, 200)
    } while ($timer.Elapsed.TotalSeconds -lt $Seconds)
    throw "Timed out: $Name"
}
function Doctor {
    $app.Refresh()
    if ($app.HasExited -or $app.Path -ne $Exe -or [ChatDeliveryDesktop]::Owner($main) -ne $app.Id -or [ChatDeliveryDesktop]::Class($main) -ne 'ZigShell') { throw 'Doctor: owned app identity changed' }
    $element = [Windows.Automation.AutomationElement]::FromHandle($main)
    if ($element.Current.IsOffscreen -or $element.Current.ProcessId -ne $app.Id) { throw 'Doctor: desktop not visible' }
    Save @{ pid = $app.Id; hwnd = $main.ToInt64(); exe = $app.Path; sha256 = $ExpectedHash; visible = $true } "$Evidence/doctor.json"
}
function Press([int[]]$Keys, [string]$Label) {
    Doctor
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $main) }
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Refusing input outside the owned app' }
    $actions.Add(@{ input = $Label; keys = $Keys; seconds = $clock.Elapsed.TotalSeconds })
    [ChatDeliveryDesktop]::Chord($Keys)
}
function Type-Text([string]$Text) {
    Doctor
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Refusing typing outside the owned app' }
    $actions.Add(@{ input = 'type'; text = $Text; seconds = $clock.Elapsed.TotalSeconds })
    foreach ($letter in $Text.ToCharArray()) { [ChatDeliveryDesktop]::Character($letter) }
}
function Palette([string]$Query) {
    Press @(0x1B) 'Escape: dismiss overlay'
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x4B) 'Ctrl+K: open palette'
    [void](Wait-For 'empty palette ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    Type-Text $Query
    [void](Wait-For "palette query $Query" { (Read-Shared "$settings/debug.log").Substring($offset) -match ("\[palette\] ready chars=" + $Query.Length + ' count=[1-9]\d* target=\d+') })
    Press @(0x0D) "Enter: $Query"
}
function Visible-Children([string]$Class, $Parent = $main) {
    $element = [Windows.Automation.AutomationElement]::FromHandle([IntPtr]$Parent)
    $condition = [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ClassNameProperty, $Class)
    @($element.FindAll([Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen } | ForEach-Object { [IntPtr]$_.Current.NativeWindowHandle })
}
function Room-Window { $windows = @(Visible-Children 'MultiPromptRoomView'); if ($windows.Count -eq 1) { $windows[0] } }
function Focus-Control([IntPtr]$Control) {
    Doctor
    if (-not [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $Control)) { throw 'Cannot focus owned control' }
}
function Snapshot([string]$Name) {
    $raw = Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$settings/ssh-key/config", 'remote-1', "python3 $repo/.claude/skills/verify-multiprompt/rooms-snapshot.py") -Evidence $Evidence -Name ($Name + '-snapshot')
    $state = ($raw -join "`n") | ConvertFrom-Json
    Save $state "$Evidence/$Name-state.json"
    return $state
}
function Room-Data($State) { ,@($State.rooms | ForEach-Object { $_.tables.rooms } | Where-Object { $_.name -ceq 'Rooms534' }) }
function Room-Events($State) { @($State.rooms | ForEach-Object { $_.tables.events } | ForEach-Object { $_.body | ConvertFrom-Json }) }
function Shot([string]$Name) {
    Doctor
    $bitmap = [Drawing.Bitmap]::new([ChatDeliveryDesktop]::GetSystemMetrics(0), [ChatDeliveryDesktop]::GetSystemMetrics(1))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen(0, 0, 0, 0, $bitmap.Size); $bitmap.Save("$Evidence/$Name.png", [Drawing.Imaging.ImageFormat]::Png) } finally { $graphics.Dispose(); $bitmap.Dispose() }
    $text = & $ocr "$Evidence/$Name.png" stdout --psm 11 2> "$Evidence/$Name-ocr.log"
    if ($LASTEXITCODE -ne 0) { throw 'Screenshot OCR failed' }
    $text = ($text -join ' ') -replace '\s+', ' '
    [IO.File]::WriteAllText("$Evidence/$Name-visible.txt", $text)
    return $text
}
function Case([int]$Step, [string]$Name, [string]$Missing, [scriptblock]$Body) {
    $case = @{ step = $Step; name = $Name; status = 'UNREACHABLE'; symptom = $Missing; seconds = $clock.Elapsed.TotalSeconds; screenshot = "step-$Step.png" }
    if (-not $Missing) {
        try { & $Body; $case.status = 'PASS'; $case.symptom = 'Visible UI and saved state agree' }
        catch { $case.status = 'FAIL'; $case.symptom = $_.Exception.Message }
    }
    try { [void](Shot "step-$Step"); [void](Snapshot "step-$Step") } catch { $result.driverErrors += $_.ToString() }
    $case.seconds = $clock.Elapsed.TotalSeconds
    $result.cases += $case
    Save $result "$Evidence/result.json"
    Write-Host ("STEP $Step $($case.status): $($case.symptom)")
}
function Copy-Chat([string]$Name) {
    [Windows.Forms.Clipboard]::Clear()
    Palette 'chat view select all'
    Press @(0x11, 0x43) 'Ctrl+C: copy visible chat messages'
    $text = Wait-For 'copied chat text' { $value = [Windows.Forms.Clipboard]::GetText(); if ($value) { $value } }
    [IO.File]::WriteAllText("$Evidence/$Name.txt", $text)
    Press @(0x1B) 'Escape: return to composer'
    return $text
}
function Open-Member([string]$Name) {
    Palette $Name
    if (-not @(Visible-Children 'ZigShellChatTranscript').Count) { Press @(0x12, 0x43) 'Alt+C: open member Chat View' }
    [void](Wait-For 'member composer' { $windows = @(Visible-Children 'Edit'); if ($windows.Count -eq 1) { $windows[0] } })
}
function Send-Text([string]$Text, [switch]$Room) {
    $parent = if ($Room) { Room-Window } else { $main }
    $edit = Wait-For 'one visible composer' { $windows = @(Visible-Children 'Edit' $parent); if ($windows.Count -eq 1) { $windows[0] } }
    Focus-Control $edit
    Type-Text $Text
    [void](Wait-For 'exact typed composer text' { [ChatDeliveryDesktop]::Text($edit) -ceq $Text })
    Press @(0x1B) 'Escape: dismiss mention suggestions'
    Press @(0x0D) 'Enter: send message'
    [void](Wait-For 'composer clears after send' { [ChatDeliveryDesktop]::Text($edit) -ceq '' } 15)
}
try {
    if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Use GitHub Windows only' }
    if ((Get-FileHash $Exe -Algorithm SHA256).Hash -ine $ExpectedHash -or -not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable checksum/version mismatch' }
    Add-Type -AssemblyName System.Drawing, System.Windows.Forms, System.Security, UIAutomationClient, UIAutomationTypes
    Add-Type -Path "$PSScriptRoot/../../../tools/verify-chat-delivery/desktop.cs"
    Add-Type -Path "$PSScriptRoot/../../../tools/verify-chat-delivery/job.cs"
    [void][ChatDeliveryDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
    $ocr = 'C:/Program Files/Tesseract-OCR/tesseract.exe'
    if (-not (Test-Path $ocr)) { throw 'Tesseract not installed' }
    $repo = (Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'wslpath', '-a', $env:GITHUB_WORKSPACE) -Evidence $Evidence -Name 'repo-path').Trim()
    & "$PSScriptRoot/../../../tools/verify-server-chat/start.ps1" -Profile $profile -Evidence $Evidence
    $ssh = "$env:SystemRoot/System32/OpenSSH/ssh.exe"
    [void](Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$settings/ssh-key/config", 'remote-1', "python3 $repo/.claude/skills/verify-multiprompt/rooms-seed.py $repo") -Evidence $Evidence -Name 'members-seed')
    $watcher = [IO.FileSystemWatcher]::new($profile)
    $watcher.IncludeSubdirectories = $true
    $accountHost = 'account.multiprompt.dev'
    $cert = New-SelfSignedCertificate -DnsName $accountHost -CertStoreLocation Cert:\LocalMachine\My -NotAfter (Get-Date).AddDays(1)
    $password = [guid]::NewGuid().ToString('N')
    $secure = ConvertTo-SecureString $password -AsPlainText -Force
    Export-PfxCertificate -Cert $cert -FilePath "$profile/account.pfx" -Password $secure | Out-Null
    Export-Certificate -Cert $cert -FilePath "$profile/account.cer" | Out-Null
    Import-Certificate -FilePath "$profile/account.cer" -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
    [IO.File]::AppendAllText($hostsFile, "`r`n127.0.0.1 $accountHost`r`n")
    $serviceJob = [VerifyJob]::new()
    $service = $serviceJob.Start((Get-Command node.exe).Source, $env:GITHUB_WORKSPACE, "$profile/service.log", "$profile/service.err.log", "service/journey/server.mjs --port=443 --pfx=$profile/account.pfx --pfxpass=$password --state=$profile/account-state.json")
    [void](Wait-For 'runner account Worker ready' { try { Invoke-RestMethod "https://$accountHost/health" | Out-Null; Test-Path "$profile/account-state.json" } catch { $false } } 90)
    $secrets = Get-Content "$profile/account-state.json" -Raw | ConvertFrom-Json
    $credential = [Text.Encoding]::UTF8.GetBytes((@{ refresh_token = $secrets.refresh_token } | ConvertTo-Json -Compress))
    [IO.File]::WriteAllBytes("$settings/account-device.dat", [Security.Cryptography.ProtectedData]::Protect($credential, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser))
    $keyLine = (Get-Content "$profile/home/.ssh/known_hosts" | Select-Object -First 1) -split ' '
    $tabs = @(@{ kind = 'tmux'; name = 'Alpha'; tmux_session = 'rooms-alpha'; csid = 'a1b2c3d4-0534-4000-8000-000000000001'; tmux_host = 0; workspace = 'Rooms check'; manual = $true }, @{ kind = 'tmux'; name = 'Bravo'; tmux_session = 'rooms-bravo'; csid = 'a1b2c3d4-0534-4000-8000-000000000002'; tmux_host = 0; workspace = 'Rooms check'; manual = $true })
    $layout = @{ schema = 1; revision = 1; workspaces = @(@{ name = 'Rooms check' }); tabs = $tabs; hosts = @(@{ slot = 0; name = 'Runner Linux'; hostname = '127.0.0.1'; port = 2222; user = 'mpverify'; host_keys = @($keyLine[1] + ' ' + $keyLine[2]) }) }
    $headers = @{ Authorization = 'Bearer ' + $secrets.admin_key; 'X-Layout-Features' = 'hosts,csid' }
    $current = Invoke-RestMethod "https://$accountHost/v1/layout" -Headers $headers
    Invoke-RestMethod "https://$accountHost/v1/layout" -Method Put -Headers $headers -ContentType 'application/json' -Body (@{ base_revision = $current.revision; layout = $layout } | ConvertTo-Json -Depth 15) | Out-Null
    Save $layout "$Evidence/fixture-layout.json"
    $env:APPDATA = "$profile/roaming"
    $env:LOCALAPPDATA = "$profile/local"
    $env:USERPROFILE = "$profile/home"
    $env:HOME = "$profile/home"
    $env:ZIGSHELL_DEBUG = '1'
    $env:IGSH_246 = '0'
    Remove-Item Env:\MULTIPROMPT_NO_LOGIN -ErrorAction SilentlyContinue
    $env:PATH = (Split-Path $ssh) + ';' + $env:PATH
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $profile, "$Evidence/stdout.log", "$Evidence/stderr.log", '--single-window --no-window-restore')
    $main = Wait-For 'owned desktop window' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    [void][ChatDeliveryDesktop]::MoveWindow($main, 0, 0, [ChatDeliveryDesktop]::GetSystemMetrics(0), [ChatDeliveryDesktop]::GetSystemMetrics(1), $true)
    [void](Wait-For 'two account-owned chats imported' { $saved = Read-Shared "$settings/session.json"; $saved.Contains('rooms-alpha') -and $saved.Contains('rooms-bravo') } 90)
    foreach ($name in @('Alpha', 'Bravo')) {
        Open-Member $name
        Send-Text 'PRIVATE534'
        [void](Wait-For "$name real private reply" { (Copy-Chat "$name-private").Contains("$name says PRIVATE534") })
        [void](Shot "$name-private")
    }
    Save @{ status = 'PASS'; detail = 'Both chats replied through the real desktop composer, SSH, host, provider and transcript before Rooms was touched' } "$Evidence/preflight.json"
    Case 1 'Create a room' '' {
        Palette 'New room'
        $room = Wait-For 'new room view' { Room-Window }
        $edit = [IntPtr]([ChatDeliveryDesktop]::Focus($main)[1])
        if ([ChatDeliveryDesktop]::Class($edit) -ne 'Edit') { throw 'New room did not focus its name field' }
        Type-Text 'Rooms534'
        [void](Wait-For 'room name typed' { [ChatDeliveryDesktop]::Text($edit) -ceq 'Rooms534' })
        [void](Shot 'create-before')
        Press @(0x0D) 'Enter: create empty room'
        [void](Wait-For 'room persisted' { (Room-Data (Snapshot 'create-poll')).Count -eq 1 })
        if ((Shot 'create-after') -notmatch 'Rooms534') { throw 'Saved room is not shown in its room view' }
    }
    $hasRoom = (Room-Data (Snapshot 'after-create')).Count -eq 1
    Case 2 'Add two member chats' $(if (-not $hasRoom) { 'No saved Rooms534 room was created' } else { '' }) {
        Palette 'Edit room'
        $room = Wait-For 'room editor' { Room-Window }
        Press @(0x09) 'Tab: search member chats'
        Type-Text 'Alpha'
        [void](Wait-For 'Alpha visible in member list' { (Shot 'members-alpha') -match 'Alpha' })
        Press @(0x0D) 'Enter: select Alpha'
        Press @(0x11, 0x41) 'Ctrl+A: replace member search'
        Type-Text 'Bravo'
        [void](Wait-For 'Bravo visible in member list' { (Shot 'members-bravo') -match 'Bravo' })
        Press @(0x0D) 'Enter: select Bravo'
        Press @(0x11, 0x0D) 'Ctrl+Enter: save room members'
        [void](Wait-For 'both saved members' { $s = Snapshot 'members-poll'; @($s.rooms | ForEach-Object { $_.tables.members } | Where-Object { $_.active -eq 1 }).Count -eq 2 })
        $visible = Shot 'members-after'
        if ($visible -notmatch 'Rooms534') { throw 'Room did not reopen after saving members' }
    }
    $hasMembers = @((Snapshot 'after-members').rooms | ForEach-Object { $_.tables.members } | Where-Object { $_.active -eq 1 }).Count -eq 2
    Case 3 'Send a room message' $(if (-not $hasRoom) { 'No saved room' } else { '' }) {
        Palette 'Rooms534'
        Send-Text 'BROADCAST534' -Room
        [void](Wait-For 'saved human room event' { @(Room-Events (Snapshot 'send-poll') | Where-Object { $_.type -eq 'human' -and $_.text -ceq 'BROADCAST534' }).Count -eq 1 })
        if ((Shot 'send-after') -notmatch 'BROADCAST534') { throw 'Saved room message is not visible in the room' }
    }
    $sent = @(Room-Events (Snapshot 'after-send') | Where-Object { $_.type -eq 'human' -and $_.text -ceq 'BROADCAST534' }).Count -eq 1
    Case 4 'Every member replies in the room' $(if (-not $sent) { 'No saved BROADCAST534 room message' } elseif (-not $hasMembers) { 'The room has fewer than two saved members' } else { '' }) {
        [void](Wait-For 'one room reply from each member' { $events = @(Room-Events (Snapshot 'replies-poll') | Where-Object { $_.type -eq 'agent_reply' -and $_.text -match 'BROADCAST534' }); $events.Count -eq 2 -and @($events.member_id | Select-Object -Unique).Count -eq 2 } 90)
        $visible = Shot 'replies-after'
        if ($visible -notmatch 'Alpha says BROADCAST534' -or $visible -notmatch 'Bravo says BROADCAST534') { throw 'Saved member replies are not both visible in the room' }
    }
    Case 5 'Mention only Alpha' $(if (-not $hasMembers) { 'The room has fewer than two saved members' } else { '' }) {
        Palette 'Rooms534'
        Send-Text '@Alpha TARGET534' -Room
        [void](Wait-For 'saved Alpha-only mention and reply' { $s = Snapshot 'mention-poll'; $event = @(Room-Events $s | Where-Object { $_.type -eq 'human' -and $_.text -ceq '@Alpha TARGET534' }); $replies = @(Room-Events $s | Where-Object { $_.type -eq 'agent_reply' -and $_.text -match 'TARGET534' }); $event.Count -eq 1 -and @($event[0].recipients).Count -eq 1 -and $replies.Count -eq 1 -and $replies[0].text -ceq 'Alpha says TARGET534' } 45)
        $s = Snapshot 'mention-after'
        $inputs = @($s.inputs | Where-Object { $_.text -match 'TARGET534' })
        if ($inputs.Count -ne 1 -or $inputs[0].sid -notlike '*0001') { throw 'Mention reached a member other than Alpha, or reached it more than once' }
        $visible = Shot 'mention-after'
        if ($visible -notmatch 'Alpha says TARGET534' -or $visible -match 'Bravo says TARGET534') { throw 'The room does not show only the mentioned member replying' }
    }
    Case 6 'Same replies in room and both member views' $(if (-not $sent) { 'No saved room message whose replies can be compared' } else { '' }) {
        $state = Snapshot 'order-before'
        $replies = @(Room-Events $state | Where-Object { $_.type -eq 'agent_reply' })
        if ($replies.Count -lt 2) { throw 'Saved room contains fewer than two member replies; there is no shared reply order' }
        $problems = @()
        foreach ($name in @('Alpha', 'Bravo')) {
            Open-Member $name
            $copied = Copy-Chat "$name-room-history"
            [void](Shot "$name-room-history")
            $position = -1
            foreach ($reply in $replies) {
                $next = $copied.IndexOf($reply.text, [Math]::Max(0, $position + 1), [StringComparison]::Ordinal)
                if ($next -lt 0) { $problems += "$name chat is missing or reorders '$($reply.text)'" } else { $position = $next }
            }
        }
        Palette 'Rooms534'
        $visible = Shot 'room-order'
        $position = -1
        foreach ($reply in $replies) {
            $next = $visible.IndexOf($reply.text, [Math]::Max(0, $position + 1), [StringComparison]::Ordinal)
            if ($next -lt 0) { $problems += "Room view is missing or reorders '$($reply.text)'" } else { $position = $next }
        }
        Save @{ roomSequence = $replies; differences = $problems } "$Evidence/order-comparison.json"
        if ($problems.Count) { throw ($problems -join '; ') }
    }
    if (@($result.cases | Where-Object { $_.status -ne 'PASS' }).Count -eq 0 -and $result.driverErrors.Count -eq 0) { $result.status = 'passed' }
} catch {
    $result.driverErrors += $_.ToString()
    if ($null -ne $app -and -not $app.HasExited) { try { [void](Shot 'driver-failure') } catch {} }
} finally {
    if ($null -ne $job) { $cleanup = $job.Stop(); $result.cleanup = @{ activeAfterStop = $cleanup.ActiveProcesses }; $job.Dispose() }
    if ($null -ne $serviceJob) { $cleanup = $serviceJob.Stop(); $result.serviceCleanup = @{ activeAfterStop = $cleanup.ActiveProcesses }; $serviceJob.Dispose() }
    if (Test-Path "$settings/debug.log") { Copy-Item "$settings/debug.log" "$Evidence/debug.log" }
    if (Test-Path $settings) {
        New-Item -ItemType Directory -Force "$Evidence/data" | Out-Null
        Get-ChildItem $settings -File | Where-Object { $_.Name -match '^(session.*\.json|room.*)$' } | Copy-Item -Destination "$Evidence/data"
    }
    foreach ($name in @('service.log', 'service.err.log')) { if (Test-Path "$profile/$name") { Copy-Item "$profile/$name" "$Evidence/$name" } }
    [IO.File]::WriteAllBytes($hostsFile, $hostsOriginal)
    if ($null -ne $cert) { Remove-Item "Cert:\LocalMachine\Root\$($cert.Thumbprint)" -Force -ErrorAction SilentlyContinue; Remove-Item "Cert:\LocalMachine\My\$($cert.Thumbprint)" -Force -ErrorAction SilentlyContinue }
    if ($null -ne $watcher) { $watcher.Dispose() }
    try {
        [void](Invoke-ServerNative -FilePath wsl.exe -Arguments @('--terminate', 'Ubuntu-24.04') -Evidence $Evidence -Name 'wsl-terminate')
        Remove-Item $profile -Recurse -Force
        $result.scratchRemoved = -not (Test-Path $profile)
    } catch { $result.driverErrors += $_.ToString(); $result.status = 'failed' }
    Save $actions "$Evidence/actions.json"
    Save $result "$Evidence/result.json"
}
if ($result.status -ne 'passed') { throw 'Rooms journey failed; inspect result.json for all six independent step results and driverErrors' }
