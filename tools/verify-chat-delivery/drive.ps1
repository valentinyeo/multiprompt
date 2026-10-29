param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$Ssh,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)][string]$ExpectedHash,
    [Parameter(Mandatory)][string]$Evidence,
    [ValidateSet('chat-delivery', 'chat-messages-only', 'chat-full-history')][string]$Feature = 'chat-delivery'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Run only through verify.yml on GitHub Windows through the desktop workflow' }
$Exe = (Resolve-Path $Exe).Path
$Ssh = (Resolve-Path $Ssh).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
Start-Transcript "$Evidence/driver.log"
Add-Type -AssemblyName System.Drawing, System.Windows.Forms, UIAutomationClient, UIAutomationTypes
Add-Type -Path "$PSScriptRoot/desktop.cs"
Add-Type -Path "$PSScriptRoot/job.cs"
[void][ChatDeliveryDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
if ($env:CHAT_REPLY_PROOF -eq '1' -and $Feature -ne 'chat-delivery') { throw 'Reply proof requires chat-delivery' }
if ($env:CHAT_SKILLS_PROOF -eq '1' -and $Feature -ne 'chat-delivery') { throw 'Fresh skills proof requires chat-delivery' }
if ($env:CHAT_NOTES_PROOF -eq '1' -and $Feature -ne 'chat-delivery') { throw 'Session notes proof requires chat-delivery' }
if ($env:CHAT_REACTIONS_PROOF -eq '1' -and $Feature -ne 'chat-delivery') { throw 'Reactions proof requires chat-delivery' }
if ($env:CHAT_WIDTH_PROOF -eq '1' -and $Feature -ne 'chat-messages-only') { throw 'Width proof requires chat-messages-only' }
if ($env:CHAT_REPLY_PROOF -eq '1' -or $env:CHAT_WIDTH_PROOF -eq '1' -or $env:CHAT_REACTIONS_PROOF -eq '1' -or $env:CHAT_NOTES_PROOF -eq '1') {
    Add-Type -Path "$PSScriptRoot/layout-capture.cs"
    [LayoutCapture]::Display()
}
$plans = @(
    @{name='busy-send'; mode='busy'; text='busy delivery alpha'},
    @{name='idle-suggestion'; mode='idle'; text='idle delivery beta'},
    @{name='steer-chord'; mode='busy'; text='steer delivery gamma'},
    @{name='wrapped-leftover'; mode='busy'; text='wrapped delivery delta'; leftover='earlier long message about the weekly plan that keeps wrapping across rows'}
    @{name='queue-draft-sync'; mode='busy'; text='chat queued beta'},
    @{name='send-stays-gone'; mode='busy'; text='send stays gone'}
)
if ($Feature -eq 'chat-messages-only') { $plans = @(@{name='messages-only'; mode='idle'; text='composer stays usable'}) }
if ($Feature -eq 'chat-full-history') { $plans = @(@{name='full-history'; mode='busy'; text='all session messages'}) }
if ($env:CHAT_SKILLS_PROOF -eq '1') { $plans = @(@{name='fresh-skills'; mode='busy'; text='live skill discovery'}) }
if ($env:CHAT_ACCEPTED_PROOF -eq '1') { $plans = @(@{name='accepted-message'; mode='busy'; text='accepted message stays readable'}) }
if ($env:CHAT_SENDING_PROOF -eq '1') { $plans = @($plans[0]) }
if ($env:CHAT_LIVE_DELIVERY_PROOF -eq '1') { $plans = @(@{name='live-delivery'; mode='busy'; text='continuous busy-session delivery'}) }
if ($env:CHAT_SWITCH_PROOF -eq '1') { $plans = @(@{name='remote-switch'; mode='idle'; text='long remote conversation switching'}) }
if ($env:CHAT_REMOTE_PROOF -eq '1') { $plans = @(@{name='remote-sync'; mode='idle'; text='remote session follows live process'}) }
if ($env:CHAT_MISSING_PROOF -eq '1') { $plans = @(@{name='missing-transcript'; mode='idle'; text='no transcript behind this tab'}) }
if ($env:CHAT_NOTES_PROOF -eq '1') { $plans = @(@{name='session-notes'; mode='idle'; text='runner note disclosure'}) }
if ($env:CHAT_REACTIONS_PROOF -eq '1') { $plans = @(@{name='reactions'; mode='busy'; text='draft stays here'}) }
if ($env:CHAT_REPLY_PROOF -eq '1') { $plans = @(@{name='reply-reference'; mode='idle'; text='compact reply navigation'}) }
if ($env:CHAT_RESYNC_PROOF -eq '1') { $plans = @(@{name='resync'; mode='busy'; text='draft stays here'}) }
if ($env:CHAT_HAX_PROOF -eq '1') { $plans = @(@{name='hax-reader'; mode='idle'; text='saved runner replies'}, @{name='hax-close'; mode='idle'; text='close stays closed'}) }
$queueTexts = @{a='shell queued alpha'; b='chat queued beta'; a2='shell queued alpha edited'; shellDraft='shell draft gamma'; chatDraft='chat draft delta'; agentPaste="agent report line one`nagent report line two"; suggestion='Try asking about the next step'}
$results = @($plans | ForEach-Object { @{name=$_.name; passed=$false; detail='Case has not completed'} })
$actions = [Collections.Generic.List[object]]::new()
$env:MP_VERIFY_PYTHON = (Get-Command python.exe).Source
$env:MP_VERIFY_BOUNDARY = (Resolve-Path "$PSScriptRoot/boundary.py").Path
$env:PATH = (Split-Path $Ssh) + ';' + $env:PATH
$env:PYTHONUTF8 = '1'
$env:PYTHONIOENCODING = 'utf-8'
$env:MULTIPROMPT_NO_LOGIN = '1'
$env:ZIGSHELL_DEBUG = '1'
$env:IGSH_246 = '0'
foreach ($file in @('agent-buffer.jsonl', 'invocations.jsonl', 'debug.log')) { [IO.File]::WriteAllText("$Evidence/$file", '') }
function Save($Value, [string]$Path) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false)) }
function Wait-For([string]$Description, [scriptblock]$Check, [int]$Seconds = 60) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 100 } while ($timer.Elapsed.TotalSeconds -lt $Seconds)
    throw "Timed out: $Description"
}
function Shot([string]$Name) {
    if ($Name -eq 'new-messages-visible') {
        [void](Wait-For 'unread badge reaches the screen' {
            $bounds = Transcript-Viewport
            $probe = [Drawing.Bitmap]::new(60, 100)
            $draw = [Drawing.Graphics]::FromImage($probe)
            try {
                $draw.CopyFromScreen([int]$bounds.Right - 60, [int]$bounds.Bottom - 100, 0, 0, $probe.Size)
                $blue = 0
                for ($y = 0; $y -lt 100; $y += 2) {
                    for ($x = 0; $x -lt 60; $x += 2) {
                        $pixel = $probe.GetPixel($x, $y)
                        if ($pixel.R -lt 130 -and $pixel.G -gt 110 -and $pixel.B -gt 210) { $blue++ }
                    }
                }
                $blue -gt 5
            } finally { $draw.Dispose(); $probe.Dispose() }
        })
    }
    $bitmap = [Drawing.Bitmap]::new([ChatDeliveryDesktop]::GetSystemMetrics(0), [ChatDeliveryDesktop]::GetSystemMetrics(1))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen(0, 0, 0, 0, $bitmap.Size); $bitmap.Save("$Evidence/$Name.png", [Drawing.Imaging.ImageFormat]::Png); if ($Name.StartsWith('reply-') -or $Name.StartsWith('accepted-') -or $Name.StartsWith('reactions-') -or $Name.StartsWith('notes-') -or $Name -in @('sending-immediate', 'sending-delivered', 'messages-only-before-tools', 'messages-only-after-tools', 'clean-chat-on', 'clean-chat-off', 'unread-divider-reopened', 'unread-divider-gap', 'unread-divider-all-read', 'layout-wide', 'layout-narrow')) { $bitmap.Save("$Evidence/$Name.bmp", [Drawing.Imaging.ImageFormat]::Bmp) } }
    finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Doctor([bool]$Chat = $false) {
    $app.Refresh()
    if ($app.HasExited -or $app.Path -ne $Exe -or (Get-FileHash $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Doctor: executable identity mismatch' }
    if ([ChatDeliveryDesktop]::Owner($main) -ne $app.Id -or [ChatDeliveryDesktop]::Class($main) -ne 'ZigShell') { throw 'Doctor: owned main HWND missing' }
    $element = [System.Windows.Automation.AutomationElement]::FromHandle($main)
    $title = $element.Current.Name
    if ($element.Current.IsOffscreen -or $element.Current.ProcessId -ne $app.Id -or $title -notmatch ('multiprompt v' + [regex]::Escape($ExpectedVersion) + '(?:\s|$)')) {
        Save @{offscreen=$element.Current.IsOffscreen; pid=$element.Current.ProcessId; title=$title; hwnd=$main.ToInt64()} "$caseDir/doctor-window.json"
        throw 'Doctor: visible versioned UI Automation identity missing'
    }
    $session = Get-Content "$settings/session.json" -Raw | ConvertFrom-Json
    $expectedTmux = if ($env:CHAT_HAX_PROOF -eq '1') { $expectedShells } else { 1 }
    if (@($session.tabs).Count -ne $expectedShells -or @($session.tabs | Where-Object { $_.kind -eq 'tmux' }).Count -ne $expectedTmux -or
        ($expectedShells -eq 2 -and @($session.tabs | Where-Object { $_.kind -eq 'cmd' }).Count -ne 1)) { throw 'Doctor: expected owned tmux and local tabs were not saved' }
    if ($Chat) {
        $focus = [ChatDeliveryDesktop]::Focus($main)
        if ($focus[0] -ne $main.ToInt64() -or $focus[1] -ne $composer.ToInt64()) { throw 'Doctor: owned composer must have foreground typing focus' }
    }
    $identity = @{pid=$app.Id; exe=$app.Path; hwnd=$main.ToInt64(); title=$title; version=$ExpectedVersion; sha256=$ExpectedHash; tmux=$true; chat=$Chat; focus=$(if ($Chat) { $focus } else { @() }); composer=$(if ($Chat) { $composer.ToInt64() } else { 0 })}
    Save $identity "$caseDir/doctor.json"
}
function Press([int[]]$Keys, [string]$Label, [bool]$Chat = $false) {
    if ($Label.StartsWith('Alt+C:') -and (Get-Variable toggleReady -Scope Script -ErrorAction SilentlyContinue)) {
        [void](Wait-For 'existing Alt+C debounce elapsed' { [DateTime]::UtcNow -ge $script:toggleReady })
    }
    Doctor
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) {
        $target = if ($Chat) { $composer } else { $main }
        [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $target)
    }
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Refusing keyboard input: owned app is not foreground' }
    if ($Chat) { Doctor $true }
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Refusing keyboard input: owned app is not foreground' }
    $actions.Add(@{case=$plan.name; ms=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); input=$Label; keys=$Keys})
    if ($Label.StartsWith('Alt+C:')) {
        $script:toggleReady = [DateTime]::UtcNow.AddMilliseconds(1600)
    }
    [ChatDeliveryDesktop]::Chord($Keys)
    Start-Sleep -Milliseconds 100
}
function Read-Shared([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
        $reader = [IO.StreamReader]::new($stream)
        try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
    } finally { $stream.Dispose() }
}
function Step([string]$Name, [scriptblock]$Check, [int]$Seconds = 20) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $ok = $false
    do {
        try { $ok = [bool](& $Check) } catch { $ok = $false }
        if ($ok) { break }
        Start-Sleep -Milliseconds 200
    } while ($timer.Elapsed.TotalSeconds -lt $Seconds)
    $steps.Add(@{name=$Name; ok=$ok; ms=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); waitedMs=[int]$timer.ElapsedMilliseconds})
    $ok
}
function Shell-Run([string[]]$Arguments) {
    & $env:MP_VERIFY_PYTHON $env:MP_VERIFY_BOUNDARY shell @Arguments
    if ($LASTEXITCODE -ne 0) { throw ('Fake shell operation failed: ' + ($Arguments -join ' ')) }
}
function Shell-Input([string]$Kind, [string]$Value = '') {
    $actions.Add(@{case=$plan.name; ms=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); input='shell input'; kind=$Kind; value=$Value})
    if ($Value) { Shell-Run @($Kind, $Value) } else { Shell-Run @($Kind) }
}
function Fake-State {
    $text = & $env:MP_VERIFY_PYTHON $env:MP_VERIFY_BOUNDARY shell show
    if ($LASTEXITCODE -ne 0) { throw 'Fake shell state read failed' }
    ($text -join "`n") | ConvertFrom-Json
}
function Queue-View {
    $views = [regex]::Matches((Read-Shared "$settings/debug.log"), 'CHAT_QUEUE items=(\[[^\r\n]*\])')
    if ($views.Count -eq 0) { return $null }
    $parsed = ConvertFrom-Json $views[$views.Count - 1].Groups[1].Value
    $labels = New-Object System.Collections.Generic.List[string]
    foreach ($item in $parsed) { $labels.Add([string]$item.state + ':' + [string]$item.text) }
    $labels -join '|'
}
function Transcript-Viewport {
    $frames = [regex]::Matches((Read-Shared "$settings/debug.log"), '\[chat\] frame transcript (\d+),(\d+),(\d+),(\d+) edit')
    if ($frames.Count -eq 0) { throw 'App-reported transcript viewport is missing' }
    $frame = $frames[$frames.Count - 1].Groups
    $origin = [ChatDeliveryDesktop]::ScreenPoint($main, 0, 0)
    New-Object Drawing.Rectangle(($origin.X + [int]$frame[1].Value), ($origin.Y + [int]$frame[2].Value), ([int]$frame[3].Value - [int]$frame[1].Value), ([int]$frame[4].Value - [int]$frame[2].Value))
}
function New-MessageState([int]$LogStart = 0) {
    $log = Read-Shared "$settings/debug.log"
    if ($log.Length -le $LogStart) { return $null }
    $observedStates = [regex]::Matches($log.Substring($LogStart), '\[chat\] new messages count=(\d+) visible=(\d) up=(\d) rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)')
    if ($observedStates.Count -eq 0) { return $null }
    $g = $observedStates[$observedStates.Count - 1].Groups
    @{count=[int]$g[1].Value; visible=[int]$g[2].Value; up=[int]$g[3].Value; left=[int]$g[4].Value; top=[int]$g[5].Value; right=[int]$g[6].Value; bottom=[int]$g[7].Value}
}
function Require-NewMessages([int]$Count, [int]$Visible, [int]$Up, [string]$Name, [int]$LogStart = 0) {
    $current = Wait-For $Name { $v = New-MessageState $LogStart; if ($v -and $v.count -eq $Count -and $v.visible -eq $Visible -and $v.up -eq $Up) { $v } }
    $actions.Add(@{case=$plan.name; input=$Name; state=$current})
    $current
}
function Divider-State([int]$LogStart = 0) {
    $log = Read-Shared "$settings/debug.log"
    if ($log.Length -le $LogStart) { return $null }
    $frames = [regex]::Matches($log.Substring($LogStart), '\[chat\] unread divider count=(\d) marker=(\d+) index=(\d+) unknown=(\d) y=(-?\d+) message_y=(-?\d+) scroll=(-?\d+) message=(\d+) offset=(\d+) line_y=(-?\d+)')
    if ($frames.Count -eq 0) { return $null }
    $g = $frames[$frames.Count - 1].Groups
    @{count=[int]$g[1].Value; marker=$g[2].Value; index=[int]$g[3].Value; unknown=[int]$g[4].Value; y=[int]$g[5].Value; messageY=[int]$g[6].Value; scroll=[int]$g[7].Value; message=$g[8].Value; offset=[long]$g[9].Value; lineY=[int]$g[10].Value}
}
function Require-Divider([int]$Count, [int]$Unknown, [string]$Name, [int]$LogStart) {
    $frame = Wait-For $Name { $v = Divider-State $LogStart; if ($v -and $v.count -eq $Count -and $v.unknown -eq $Unknown) { $v } }
    $actions.Add(@{case=$plan.name; input=$Name; state=$frame})
    $frame
}
function Bind-Transcript {
    $script:composer = Wait-For 'native Chat View composer' { $h = [ChatDeliveryDesktop]::Composer($main); if ($h -ne [IntPtr]::Zero) { $h } }
    [void](Wait-For 'composer typing focus' { $f = [ChatDeliveryDesktop]::Focus($main); $f[0] -eq $main.ToInt64() -and $f[1] -eq $composer.ToInt64() })
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($main)
    $condition = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
    $script:views = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen -and $_.Current.ProcessId -eq $app.Id })
    if ($views.Count -ne 1) { throw 'Expected one owned visible transcript' }
    Doctor $true
}
function Restart-OwnedApp {
    Doctor
    [void]$app.CloseMainWindow()
    if (-not $app.WaitForExit(10000)) { throw 'Owned app did not close normally for restart' }
    $stopped = $job.Stop()
    Save $stopped "$caseDir/restart-process-tree.json"
    if ($stopped.ActiveProcesses -ne 0) { throw 'Restart left owned processes running' }
    $job.Dispose()
    $script:job = [VerifyJob]::new()
    $script:app = $job.Start($Exe, $profile, "$caseDir/restart-stdout.log", "$caseDir/restart-stderr.log", '--no-window-restore')
    $script:main = Wait-For 'restarted owned app window' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    [void](Wait-For 'restarted app published saved tmux tab' { Test-Path "$settings/inbox-default.json" })
    [void](Wait-For 'restarted owned app foreground' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $main) })
    Doctor
}
function Scroll-Transcript([int]$Delta) {
    Doctor
    $bounds = $views[0].Current.BoundingRectangle
    $view = [IntPtr]$views[0].Current.NativeWindowHandle
    $x = [int](($bounds.Left + $bounds.Right) / 2)
    $y = [int](($bounds.Top + $bounds.Bottom) / 2)
    $logStart = (Read-Shared "$settings/debug.log").Length
    $actions.Add(@{case=$plan.name; ms=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); input='wheel over transcript'; delta=$Delta; x=$x; y=$y; logStart=$logStart})
    [ChatDeliveryDesktop]::WheelTranscript($main, $app.Id, $view, $x, $y, $Delta)
    $logStart
}
function Click-NewMessages([bool]$Close) {
    Doctor
    $v = New-MessageState
    if (-not $v -or $v.visible -ne 1) { throw 'New-message pill is not visible' }
    $x = if ($Close) { [int]($v.right - ($v.bottom - $v.top) / 2) } else { [int](($v.left + $v.right) / 2) }
    $actions.Add(@{case=$plan.name; input='click new messages'; close=$Close; x=$x; y=[int](($v.top + $v.bottom) / 2)})
    [ChatDeliveryDesktop]::PressClient($main, $app.Id, $x, [int](($v.top + $v.bottom) / 2))
}
function Type-Composer([string]$Text) {
    [void](Wait-For 'composer typing focus' { $f = [ChatDeliveryDesktop]::Focus($main); $f[0] -eq $main.ToInt64() -and $f[1] -eq $composer.ToInt64() })
    $actions.Add(@{case=$plan.name; ms=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); input='type composer text'; text=$Text})
    foreach ($letter in $Text.ToCharArray()) {
        Doctor $true
        [ChatDeliveryDesktop]::Character($letter)
        Start-Sleep -Milliseconds 30
    }
}
function Clear-Composer {
    $length = ([ChatDeliveryDesktop]::Text($composer)).Length
    for ($i = 0; $i -lt $length; $i++) { Press @(0x08) 'Backspace: clear composer' $true }
}
function Assert-FullHistory([string]$Stage) {
    $rounds = if ($env:CHAT_LONG_PROOF -eq '1') { 320 } else { 24 }
    $blocks = 2 + 3 * $rounds
    $offset = (Read-Shared "$settings/debug.log").Length
    $complete = Step 'all session rows reach the renderer' {
        Press @(0x11, 0x30) 'Ctrl+0: measure every rendered session row'
        $log = (Read-Shared "$settings/debug.log").Substring($offset)
        $frames = [regex]::Matches($log, '\[chatfont\] pt=\d+ blocks=(\d+) content_h=\d+')
        $frames.Count -gt 0 -and [int]$frames[$frames.Count - 1].Groups[1].Value -eq $blocks
    }
    if (-not $complete) { throw "IGSH-815 incomplete session at $Stage" }
    $pollOffset = (Read-Shared "$settings/debug.log").Length
    Shell-Run @('history-refresh')
    [void](Wait-For 'changed transcript delivery completes after full history loads' {
        (Read-Shared "$settings/debug.log").Substring($pollOffset) -match '(?s)\[chat\] transcript request shell=(\d+) offset=\d+ before=0.*?\[chat\] transcript load shell=\1 ok'
    })
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x30) 'Ctrl+0: measure every session row after polling'
    $frames = [regex]::Matches((Read-Shared "$settings/debug.log").Substring($offset), '\[chatfont\] pt=\d+ blocks=(\d+) content_h=\d+')
    if ($frames.Count -eq 0 -or [int]$frames[$frames.Count - 1].Groups[1].Value -ne $blocks) { throw "IGSH-815 session rows lost after polling at $Stage" }
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($main)
    $condition = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
    $views = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen -and $_.Current.ProcessId -eq $app.Id })
    if ($views.Count -ne 1) { throw 'Expected one owned visible transcript' }
    Press @(0x11, 0x4B) 'Ctrl+K: select all transcript text through the palette'
    [void](Wait-For 'owned command palette ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    $query = 'chat view select all'
    $actions.Add(@{case=$plan.name; input='type palette query'; text=$query})
    foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
    [void](Wait-For 'select all transcript palette command selected' { (Read-Shared "$settings/debug.log").Substring($offset) -match ('\[palette\] ready chars=' + $query.Length + ' count=1 target=\d+') })
    Press @(0x0D) 'Enter: select every rendered message'
    Press @(0x11, 0x43) 'Ctrl+C: copy all rendered messages'
    $copied = [Windows.Forms.Clipboard]::GetText()
    [IO.File]::WriteAllText("$caseDir/$Stage-copied.txt", $copied)
    $actual = @([regex]::Matches($copied, 'IGSH815 (?:user|assistant) \d+') | ForEach-Object { $_.Value })
    $expected = @(0..($rounds - 1) | ForEach-Object { 'IGSH815 user {0:00}' -f $_; 'IGSH815 assistant {0:00}' -f $_ })
    if (($actual -join '|') -cne ($expected -join '|') -or -not $copied.Contains('start the fake session') -or -not $copied.Contains('The fake session is ready.')) { throw "IGSH-815 incomplete copied messages at $Stage" }
    Shot "full-history-$Stage"
    Press @(0x1B) 'Esc: clear transcript selection'
    $transcript = [IntPtr]$views[0].Current.NativeWindowHandle
    $actions.Add(@{case=$plan.name; input='wheel to first transcript message'})
    [ChatDeliveryDesktop]::WheelOwnedTranscript($main, $app.Id, $transcript, 12000)
    Start-Sleep -Milliseconds 100
    Shot "full-history-$Stage-first"
    $actions.Add(@{case=$plan.name; input='wheel to last transcript message'})
    [ChatDeliveryDesktop]::WheelOwnedTranscript($main, $app.Id, $transcript, -12000)
    Start-Sleep -Milliseconds 100
    Shot "full-history-$Stage-last"
    $scrollUi = Wait-For 'scroll ui at the newest message' {
        $m = [regex]::Matches((Read-Shared "$settings/debug.log"), '\[chat\] scroll ui thumb=(-?\d+),(-?\d+) button=(\d) box=(-?\d+),(-?\d+),(-?\d+),(-?\d+)')
        if ($m.Count -gt 0 -and $m[$m.Count - 1].Groups[3].Value -eq '0' -and [int]$m[$m.Count - 1].Groups[2].Value -gt 0) { $m[$m.Count - 1] }
    }
    $wheelStart = (Read-Shared "$settings/debug.log").Length
    $actions.Add(@{case=$plan.name; input='one wheel notch up'; delta=120})
    [ChatDeliveryDesktop]::WheelOwnedTranscript($main, $app.Id, $transcript, 120)
    $notch = Wait-For 'wheel notch distance logged' {
        $m = [regex]::Matches((Read-Shared "$settings/debug.log").Substring($wheelStart), '\[chat\] wheel delta=120 moved=(\d+) scale_px=(\d+)')
        if ($m.Count -gt 0) { $m[$m.Count - 1] }
    }
    $moved = [int]$notch.Groups[1].Value
    $browserNotch = [int]$notch.Groups[2].Value
    if ($moved -lt $browserNotch) { throw "IGSH-869 wheel notch moved $moved px, below the browser notch of $browserNotch px" }
    $up = Wait-For 'scroll to newest button visible after wheel up' {
        $m = [regex]::Matches((Read-Shared "$settings/debug.log").Substring($wheelStart), '\[chat\] scroll ui thumb=(-?\d+),(-?\d+) button=1 box=(-?\d+),(-?\d+),(-?\d+),(-?\d+)')
        if ($m.Count -gt 0) { $m[$m.Count - 1] }
    }
    Shot "full-history-$Stage-button"
    $clickX = [int](([int]$up.Groups[3].Value + [int]$up.Groups[5].Value) / 2)
    $clickY = [int](([int]$up.Groups[4].Value + [int]$up.Groups[6].Value) / 2)
    $jumpStart = (Read-Shared "$settings/debug.log").Length
    $actions.Add(@{case=$plan.name; input='click scroll to newest button'; x=$clickX; y=$clickY})
    [ChatDeliveryDesktop]::PressOwnedTranscript($main, $app.Id, $transcript, $clickX, $clickY)
    [void](Wait-For 'one click on the button returns to the newest message' {
        $m = [regex]::Matches((Read-Shared "$settings/debug.log").Substring($jumpStart), '\[chat\] scroll ui thumb=(-?\d+),(-?\d+) button=0')
        $m.Count -gt 0
    })
    Shot "full-history-$Stage-jumped"
    Save @{stage=$Stage; wheel_notch_px=$moved; browser_notch_px=$browserNotch; thumb_height=[int]$scrollUi.Groups[2].Value; button_click=@($clickX, $clickY)} "$caseDir/$Stage-scroll-ui.json"
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
    Doctor $true
    Save @{stage=$Stage; blocks=$blocks; polled=$true; messages=($actual.Count + 2); copied=$actual} "$caseDir/$Stage.json"
}
function Retention-Copy([string]$Stage, [int]$Count) {
    $offset = (Read-Shared "$settings/debug.log").Length
    $complete = Step "IGSH-934 $Stage keeps $Count messages" {
        Press @(0x11, 0x30) 'Ctrl+0: measure retained conversation'
        $frames = [regex]::Matches((Read-Shared "$settings/debug.log").Substring($offset), '\[chatfont\] pt=\d+ blocks=(\d+) content_h=\d+')
        $frames.Count -gt 0 -and [int]$frames[$frames.Count - 1].Groups[1].Value -eq $Count
    }
    if (-not $complete) { Shot "retention-$Stage-failed"; throw "IGSH-934 history lost at $Stage expected=$Count" }
    $script:retentionPosition = Divider-State
    if (Get-Variable retentionAnchor -Scope Script -ErrorAction SilentlyContinue) {
        if (-not $retentionPosition -or $retentionPosition.unknown -ne 0 -or $retentionPosition.scroll -ne $retentionAnchor.scroll) { throw "IGSH-934 reading position moved at $Stage" }
    }
    Press @(0x11, 0x4B) 'Ctrl+K: select retained conversation'
    $query = 'chat view select all'
    foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
    [void](Wait-For 'retained select-all palette command ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match ('\[palette\] ready chars=' + $query.Length + ' count=1 target=\d+') })
    Press @(0x0D) 'Enter: select retained conversation'
    Press @(0x11, 0x43) 'Ctrl+C: copy retained conversation'
    $copied = [Windows.Forms.Clipboard]::GetText()
    [IO.File]::WriteAllText("$caseDir/$Stage-copied.txt", $copied)
    $actual = @([regex]::Matches($copied, 'IGSH934 message \d{5}') | ForEach-Object { $_.Value })
    $expected = @(0..($Count - 3) | ForEach-Object { 'IGSH934 message {0:00000}' -f $_ })
    if (($actual -join '|') -cne ($expected -join '|') -or -not $copied.Contains('start the fake session') -or -not $copied.Contains('The fake session is ready.')) { throw "IGSH-934 retained copy missing or reordered at $Stage" }
    Press @(0x1B) 'Esc: clear retained selection'
    [void](Wait-For 'retained selection returns typing focus' { $f = [ChatDeliveryDesktop]::Focus($main); $f[0] -eq $main.ToInt64() -and $f[1] -eq $composer.ToInt64() })
    $frames = [regex]::Matches((Read-Shared "$settings/debug.log").Substring($offset), '\[chat\] unread divider count=\d marker=\d+ index=\d+ unknown=(\d)')
    if (@($frames | Where-Object { $_.Groups[1].Value -eq '1' }).Count -gt 0) { throw 'IGSH-934 retained read position became unknown' }
    if (Get-Variable retentionAnchor -Scope Script -ErrorAction SilentlyContinue) { Retention-Top }
}
function Retention-Top {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($main)
    $condition = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
    $rows = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen -and $_.Current.ProcessId -eq $app.Id })
    if ($rows.Count -ne 1) { throw 'Retained transcript ownership missing' }
    $transcript = [IntPtr]$rows[0].Current.NativeWindowHandle
    [void](Wait-For 'restore first message after the proof copy moved selection to the bottom' {
        $position = Divider-State
        if ($position -and $position.scroll -eq 0) { return $true }
        $actions.Add(@{case=$plan.name; ms=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); input='owned transcript HWND wheel'; hwnd=$transcript.ToInt64(); delta=30000})
        [ChatDeliveryDesktop]::WheelOwnedTranscriptMessage($main, $app.Id, $transcript, 30000)
        $false
    })
}
function Assert-Retention {
    Retention-Copy 'open' 2000
    Press @(0x11, 0x4B) 'Ctrl+K: open second tab for retained visit proof'
    foreach ($letter in 'new cmd'.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
    [void](Wait-For 'new cmd palette ready' { (Read-Shared "$settings/debug.log") -match '\[palette\] ready chars=7 count=\d+ target=\d+' })
    Press @(0x0D) 'Enter: create second tab'
    $script:expectedShells = 2
    [void](Wait-For 'second tab published' { @((Get-Content "$settings/inbox-default.json" -Raw | ConvertFrom-Json).shells).Count -eq 2 })
    Press @(0x11, 0x31) 'Ctrl+1: revisit known conversation'
    Bind-Transcript
    $marker = [string](Get-Content "$settings/session.json" -Raw | ConvertFrom-Json).tabs[0].last_read_message_id
    if (-not $marker -or $marker -eq '0') { throw 'Retained journey has no known read marker' }
    Retention-Top
    Shot 'retention-before'
    $script:retentionAnchor = Divider-State
    if (-not $retentionAnchor -or $retentionAnchor.marker -eq '0' -or $retentionAnchor.scroll -ne 0) { throw 'Retained reading anchor was not observed' }
    $arrivalStart = (Read-Shared "$settings/debug.log").Length
    $anchors = @()
    for ($burst = 1; $burst -le 10; $burst++) {
        if ($burst -eq 4) { Shell-Run @('retention-reset') }
        if ($burst -eq 7) {
            $offset = (Read-Shared "$settings/debug.log").Length
            Shell-Run @('retention-empty')
            [void](Wait-For 'empty refresh fails without losing retained messages' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[chat\] transcript load shell=\d+ fail' })
            Retention-Copy 'empty' (2000 + ($burst - 1) * 20)
            Shell-Run @('retention-restore')
        }
        $burstStart = (Read-Shared "$settings/debug.log").Length
        Shell-Run @('retention-burst', '20')
        [void](Wait-For "IGSH-981 burst $burst painted before text size is measured" { (Read-Shared "$settings/debug.log").Substring($burstStart) -match ('PERF\[chat\]: receive to paint ms=\d+ size=' + (2000 + $burst * 20) + '(?!\d)') })
        Retention-Copy "burst-$burst" (2000 + $burst * 20)
        $anchors += $retentionPosition
        Shot "retention-burst-$burst"
    }
    Shot 'retention-after'
    Save $anchors "$caseDir/retention-anchors.json"
    [IO.File]::WriteAllText("$caseDir/retention-arrival.log", (Read-Shared "$settings/debug.log").Substring($arrivalStart))
    Copy-Item "$state/retention-expected.jsonl" "$caseDir/retention-expected.jsonl"
    Remove-Variable retentionAnchor -Scope Script
    $offset = (Read-Shared "$settings/debug.log").Length
    for ($round = 0; $round -lt 5; $round++) {
        Press @(0x11, 0x31) 'Ctrl+1: return to retained chat'
        Press @(0x11, 0x32) 'Ctrl+2: switch away from retained chat'
    }
    Press @(0x11, 0x31) 'Ctrl+1: restore retained chat'
    [IO.File]::WriteAllText("$caseDir/retention-switch.log", (Read-Shared "$settings/debug.log").Substring($offset))
    Retention-Copy 'final' 2200
    Doctor $true
}
foreach ($plan in $plans) {
    $expectedShells = 1
    $caseDir = "$Evidence/$($plan.name)"
    New-Item -ItemType Directory -Force $caseDir | Out-Null
    $profile = Join-Path $env:RUNNER_TEMP ('chat-delivery-' + [guid]::NewGuid().ToString('N'))
    $state = "$profile/state"
    $settings = "$profile/roaming/ZigShell"
    $app = $null
    $job = $null
    $main = [IntPtr]::Zero
    $composer = [IntPtr]::Zero
    $isResync = $plan.name -eq 'resync'
    $isReaction = $plan.name -eq 'reactions'
    $isAccepted = $plan.name -eq 'accepted-message'
    $isSwitch = $plan.name -eq 'remote-switch'
    $isRemote = $plan.name -eq 'remote-sync' -or $isSwitch
    $isQueue = $plan.name -eq 'queue-draft-sync'
    $isHax = $env:CHAT_HAX_PROOF -eq '1'
    $isSendStays = $plan.name -eq 'send-stays-gone'
    $isMissing = $plan.name -eq 'missing-transcript'
    $isActivity = $plan.name -eq 'messages-only'
    $isHistory = $plan.name -eq 'full-history'
    $isReply = $plan.name -eq 'reply-reference'
    $isNotes = $plan.name -eq 'session-notes'
    $isSending = $env:CHAT_SENDING_PROOF -eq '1'
    $isLiveDelivery = $plan.name -eq 'live-delivery'
    $hasTranscript = $isResync -or $isLiveDelivery -or $isReply -or $isNotes -or $isReaction -or $isAccepted -or $isQueue -or $isSendStays -or $isActivity -or $isHistory -or $isSending -or $isRemote -or $isHax
    $steps = [Collections.Generic.List[object]]::new()
    $procDir = $null
    $transcript = $null
    $observation = @{name=$plan.name; text=$plan.text; mode=$plan.mode; suggestion='Try asking about the next step'; actionMs=0; endMs=0; error=$null}
    $cleanup = @{remaining_owned_processes=-1; evidence_preserved=$false; scratch_removed=$false}
    try {
        New-Item -ItemType Directory -Force $state, $settings, "$profile/local", "$profile/home" | Out-Null
        $env:APPDATA = "$profile/roaming"
        $env:LOCALAPPDATA = "$profile/local"
        $env:USERPROFILE = "$profile/home"
        $env:HOME = "$profile/home"
        $env:MP_VERIFY_STATE = $state
        [IO.File]::WriteAllText("$settings/ssh-path.txt", $Ssh)
        $seed = @{name=$plan.name; mode=$plan.mode; suggestion=$observation.suggestion}
        if ($plan.ContainsKey('leftover')) { $seed.leftover = $plan.leftover; $observation.leftover = $plan.leftover }
        if ($isSending) { $seed.sendingProof = $true }
        $standIn = $seed
        if ($env:CHAT_LONG_PROOF -eq '1') { $standIn.longChatProof = $true }
        if ($hasTranscript) {
            $sid = 'a1b2c3d4-0682-4000-8000-000000000682'
            $cwd = 'C:/verify/work'
            $procDir = [IO.Path]::GetPathRoot($profile) + 'proc\4242'
            $transcript = "$profile/home/.claude/projects/" + ($cwd -replace '[^A-Za-z0-9]', '-') + "/$sid.jsonl"
            $standIn.fake = $true
            $standIn.sid = $sid
            $standIn.cwd = $cwd
            $standIn.panePid = 4242
            $standIn.transcript = $transcript
            $standIn.meta = "$profile/home/.claude/sessions/4242.json"
            if ($isRemote) {
                $standIn.remoteHome = "$profile/secondary/home"
                $standIn.transcript = $transcript.Replace("$profile/home", $standIn.remoteHome)
                $standIn.meta = "$($standIn.remoteHome)/.claude/sessions/4242.json"
                $transcript = $standIn.transcript
                $observation.remoteHome = $standIn.remoteHome
                $observation.clientHome = "$profile/home"
                $observation.turns = [Collections.Generic.List[object]]::new()
            }
            $standIn.procDir = $procDir
            $observation.texts = $queueTexts
            $observation.steps = $steps
        }
        if ($isHax) {
            $standIn.hax = $true
            $standIn.sessions = @('runner-alpha', 'runner-beta', 'runner-gamma', 'runner-empty')
            $standIn.panes = @{'runner-alpha'=4242; 'runner-beta'=4243; 'runner-gamma'=4244; 'runner-empty'=4245}
            $standIn.procRoot = [IO.Path]::GetPathRoot($profile) + 'proc'
            $standIn.home = "$profile/home"
            $standIn.cwd = 'C:/verify/shared-runners'
        }
        Save $standIn "$state/state.json"
        if ($env:CHAT_SKILLS_PROOF -eq '1') {
            New-Item -ItemType Directory -Force "$profile/home/.claude/skills/verify-zebra" | Out-Null
            [IO.File]::WriteAllText("$profile/home/.claude/skills/verify-zebra/SKILL.md", "---`nname: verify-zebra`ndescription: Existing fixture skill`n---`nFixture")
            New-Item -ItemType Directory -Force "$profile/home/.claude/skills/verify-yak" | Out-Null
            [IO.File]::WriteAllText("$profile/home/.claude/skills/verify-yak/SKILL.md", "---`nname: verify-yak`ndescription: Cached selection fixture`n---`nFixture")
        }
        if ($hasTranscript) { Shell-Run @('init') }
        if ($isResync) { Shell-Run @('resync-init') }
        if ($isReply) { Shell-Run @('reply-reference') }
        if ($isNotes) { Shell-Run @('session-notes') }
        if ($isLiveDelivery -and $env:CHAT_LONG_PROOF -eq '1') { Shell-Run @('history') }
        if ($isHistory) { Shell-Run @($(if ($env:CHAT_RETENTION_PROOF -eq '1') { 'retention-init' } else { 'history' })) }
        if ($isSwitch) { Shell-Run @('switch-history') }
        [IO.File]::WriteAllText("$state/agent-buffer.jsonl", '')
        $savedSession = @{active_tab=0; single_window=$false; chat_active=$false; tabs=@(@{kind='tmux'; name='Verify agent'; manual=$true; tmux_host=0; tmux_session='verify-agent'; cv=$false; pid=0})}
        if ($env:CHAT_SKILLS_PROOF -eq '1') { $savedSession.tabs[0].csid = 'a1b2c3d4-0923-4000-8000-000000000923' }
        if ($isNotes) { $savedSession.tabs[0].name = 'Mini Boss CEO' }
        if ($isHax) {
            $savedSession.tabs = @($standIn.sessions | ForEach-Object { @{kind='tmux'; name=$_; manual=$true; tmux_host=0; tmux_session=$_; cv=$false; pid=0} })
            $expectedShells = 4
        }
        Save $savedSession "$settings/session.json"
        if ($isRemote) {
            $saved = Get-Content "$settings/session.json" -Raw | ConvertFrom-Json
            $saved.tabs[0].tmux_host = 2
            if ($isSwitch) { $saved.single_window = $true }
            Save $saved "$settings/session.json"
        }
        Copy-Item "$settings/session.json" "$caseDir/seed-session.json"
        if (-not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable embedded version mismatch' }
        $job = [VerifyJob]::new()
        $app = $job.Start($Exe, $profile, "$caseDir/stdout.log", "$caseDir/stderr.log", '--no-window-restore')
        $main = Wait-For 'owned app window' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
        [void](Wait-For 'stand-in console rendered and app published saved tmux tab' { (Test-Path "$state/ready.json") -and (Test-Path "$settings/inbox-default.json") })
        [void](Wait-For 'owned app foreground' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $main) })
        Press @(0x11, 0x31) 'Ctrl+1: select saved tmux tab'
        Shot "$($plan.name)-before"
        if ($plan.name -eq 'busy-send') { Shot 'before' }
        Press @(0x12, 0x43) 'Alt+C: open Chat View'
        $composer = Wait-For 'native Chat View composer' { $h = [ChatDeliveryDesktop]::Composer($main); if ($h -ne [IntPtr]::Zero) { $h } } 20
        [void](Wait-For 'composer typing focus' { $f = [ChatDeliveryDesktop]::Focus($main); $f[0] -eq $main.ToInt64() -and $f[1] -eq $composer.ToInt64() })
        Doctor $true
        if ($isResync) {
            . "$PSScriptRoot/resync.ps1"
        } elseif ($isHax) {
            . "$PSScriptRoot/hax-sessions.ps1"
        } elseif ($env:CHAT_SKILLS_PROOF -eq '1') {
            Type-Composer '/verify-zebra'
            if ([ChatDeliveryDesktop]::Text($composer) -cne '/verify-zebra') { throw 'Skill fixture did not type the slash and hyphen' }
            [void](Wait-For 'initial skill fetch applied' { (Read-Shared "$settings/debug.log") -match 'chat-ac: fetched host=0 bytes=[1-9]' } 20)
            Press @(0x09) 'Tab: accept existing skill' $true
            [void](Wait-For 'existing skill accepted' { [ChatDeliveryDesktop]::Text($composer) -ceq '/verify-zebra ' } 5)
            Press @(0x11, 0x41) 'Ctrl+A: select whole skill draft' $true
            Press @(0x08) 'Backspace: clear whole skill draft' $true
            New-Item -ItemType Directory -Force "$profile/home/.claude/skills/verify-alpha" | Out-Null
            [IO.File]::WriteAllText("$profile/home/.claude/skills/verify-alpha/SKILL.md", "---`nname: verify-alpha`ndescription: Added after warming cache`n---`nFixture")
            Copy-Item "$profile/home/.claude/skills" "$caseDir/skills" -Recurse
            $started = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            Type-Composer '/verify-'
            Press @(0x28) 'Down: select cached yak before background refresh' $true
            [void](Wait-For 'newly added skill discovered within five seconds' {
                (Test-Path "$state/completion.jsonl") -and (Read-Shared "$state/completion.jsonl").Contains('verify-alpha')
            } 4)
            [void](Wait-For 'refreshed rows applied' { [regex]::Matches((Read-Shared "$settings/debug.log"), 'chat-ac: fetched host=0 bytes=[1-9]').Count -ge 2 } 1)
            Shot 'fresh-skills-refreshed'
            Press @(0x09) 'Tab: keep selected cached skill after refresh' $true
            $selected = [ChatDeliveryDesktop]::Text($composer)
            if ($selected -cne '/verify-yak ') { throw "Selected row moved during refresh: $selected" }
            Press @(0x11, 0x41) 'Ctrl+A: select whole skill draft' $true
            Press @(0x08) 'Backspace: clear whole skill draft' $true
            Type-Composer '/verify-alpha'
            Press @(0x09) 'Tab: accept newly discovered skill' $true
            $accepted = [ChatDeliveryDesktop]::Text($composer)
            if ($accepted -cne '/verify-alpha ') { throw "New skill unavailable: $accepted" }
            $elapsed = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - $started
            if ($elapsed -gt 5000) { throw "New skill took $elapsed ms, longer than five seconds" }
            Press @(0x11, 0x41) 'Ctrl+A: select whole skill draft' $true
            Press @(0x08) 'Backspace: clear whole skill draft' $true
            $beforeReload = [regex]::Matches((Read-Shared "$settings/debug.log"), 'chat-ac: fetched host=0 bytes=[1-9]').Count
            Type-Composer '/reload-plugins'
            [void](Wait-For 'reload command opening fetch applied before adding beta' { [regex]::Matches((Read-Shared "$settings/debug.log"), 'chat-ac: fetched host=0 bytes=[1-9]').Count -gt $beforeReload } 5)
            New-Item -ItemType Directory -Force "$profile/home/.claude/skills/verify-beta" | Out-Null
            [IO.File]::WriteAllText("$profile/home/.claude/skills/verify-beta/SKILL.md", "---`nname: verify-beta`ndescription: Reload fixture`n---`nFixture")
            Press @(0x0D) 'Enter: send reload plugins' $true
            [void](Wait-For 'reload refresh without reopening list' { (Read-Shared "$state/completion.jsonl").Contains('verify-beta') } 5)
            $observation.skills = @{newSkillMs=$elapsed; selected=$selected; accepted=$accepted; reload=$true}
        } elseif ($isReaction) {
            . "$PSScriptRoot/reactions.ps1"
        } elseif ($isSwitch) {
            . "$PSScriptRoot/remote-switch.ps1"
        } elseif ($isLiveDelivery) {
            . "$PSScriptRoot/live-delivery.ps1"
        } elseif ($isRemote) {
            [void](Wait-For 'initial remote transcript read' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
            Bind-Transcript
            foreach ($turn in 1..3) {
                if ($turn -eq 3) { Shell-Run @('resume', 'live-resumed-session') }
                $timer = [Diagnostics.Stopwatch]::StartNew()
                Shell-Run @('turn', [string]$turn)
                $question = "Remote question $turn"
                $answer = "Remote answer $turn"
                [void](Wait-For 'newest rendered remote question and answer within two seconds' {
                    $paletteStart = (Read-Shared "$settings/debug.log").Length
                    Press @(0x11, 0x4B) 'Ctrl+K: select remote conversation'
                    [void](Wait-For 'remote palette ready' { (Read-Shared "$settings/debug.log").Substring($paletteStart) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
                    $query = 'chat view select all'
                    foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
                    [void](Wait-For 'remote select-all command ready' { (Read-Shared "$settings/debug.log").Substring($paletteStart) -match ('\[palette\] ready chars=' + $query.Length + ' count=1 target=\d+') })
                    Press @(0x0D) 'Enter: select remote conversation'
                    Press @(0x11, 0x43) 'Ctrl+C: copy rendered remote conversation'
                    $script:remoteCopied = [Windows.Forms.Clipboard]::GetText()
                    $script:remoteCopied.Contains($question) -and $script:remoteCopied.Contains($answer)
                } 2)
                $renderedMs = [int]$timer.ElapsedMilliseconds
                if ($renderedMs -gt 2000) { throw "Remote turn $turn exceeded two seconds: $renderedMs" }
                $copied = $script:remoteCopied
                [IO.File]::WriteAllText("$caseDir/turn-$turn-copied.txt", $copied)
                if (-not $copied.Contains($question) -or -not $copied.Contains($answer)) { throw "Remote turn $turn missing from rendered conversation" }
                if ($turn -eq 3 -and $copied.Contains('Remote answer 2')) { throw 'Resumed conversation still contains stale session rows' }
                Press @(0x1B) 'Esc: clear remote selection'
                $observation.turns.Add(@{turn=$turn; renderedMs=$renderedMs; question=$question; answer=$answer; session=(Get-Content "$state/state.json" -Raw | ConvertFrom-Json).sid})
                Shot "remote-turn-$turn-chat"
                Press @(0x12, 0x43) 'Alt+C: show remote terminal'
                [void](Wait-For 'remote terminal frame painted' { (Read-Shared "$state/frames.jsonl").Contains($answer) })
                Shot "remote-turn-$turn-terminal"
                Press @(0x12, 0x43) 'Alt+C: return to remote Chat View'
                Bind-Transcript
            }
        } elseif ($isMissing) {
            $noteLine = '[chat] note shown: Chat not available for this session, use the shell view'
            $observation.noteShown = $false
            try {
                [void](Wait-For 'plain not-available note painted' { (Read-Shared "$settings/debug.log").Contains($noteLine) } 20)
                $observation.noteShown = $true
            } catch { $observation.noteWait = $_.ToString() }
            Start-Sleep -Seconds 2
            Shot 'missing-transcript-note'
            [Windows.Forms.Clipboard]::SetText('IGSH-973 clipboard sentinel')
            $paletteStart = (Read-Shared "$settings/debug.log").Length
            Press @(0x11, 0x4B) 'Ctrl+K: select the whole Chat View'
            [void](Wait-For 'palette ready' { (Read-Shared "$settings/debug.log").Substring($paletteStart) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
            $query = 'chat view select all'
            foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
            [void](Wait-For 'select-all command ready' { (Read-Shared "$settings/debug.log").Substring($paletteStart) -match ('\[palette\] ready chars=' + $query.Length + ' count=1 target=\d+') })
            Press @(0x0D) 'Enter: select the whole Chat View'
            Press @(0x11, 0x43) 'Ctrl+C: copy what Chat View shows'
            Start-Sleep -Milliseconds 500
            $observation.copied = [Windows.Forms.Clipboard]::GetText()
            [IO.File]::WriteAllText("$caseDir/copied.txt", $observation.copied)
            Press @(0x1B) 'Esc: clear selection'
            $observation.endMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        } elseif ($isHistory -and $env:CHAT_RETENTION_PROOF -eq '1') {
            Assert-Retention
        } elseif ($isHistory) {
            Assert-FullHistory 'open'
            Copy-Item "$settings/chatcache" "$caseDir/cache-before-restart" -Recurse -Force
            $actions.Add(@{case=$plan.name; input='close and restart the owned app with the same profile'})
            if (-not $app.CloseMainWindow()) { throw 'Owned app refused normal close' }
            [void](Wait-For 'owned app closed normally' { $app.HasExited })
            $stopped = $job.Stop()
            Save $stopped "$caseDir/restart-process-tree.json"
            $job.Dispose()
            $job = [VerifyJob]::new()
            $app = $job.Start($Exe, $profile, "$caseDir/restart-stdout.log", "$caseDir/restart-stderr.log", '--no-window-restore')
            $main = Wait-For 'restarted owned app window' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
            [void](Wait-For 'restarted owned app foreground' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $main) })
            $composer = Wait-For 'restored native Chat View composer with owned typing focus' {
                $h = [ChatDeliveryDesktop]::Composer($main)
                if ($h -ne [IntPtr]::Zero -and [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $h)) { $h }
            }
            Assert-FullHistory 'restart'
            if ($env:CHAT_LONG_PROOF -eq '1') { . "$PSScriptRoot/long-chat.ps1" }
        } elseif ($isReply) {
            . "$PSScriptRoot/../verify-chat-reply.ps1"
        } elseif ($isNotes) {
            [void][LayoutCapture]::MoveWindow($main, 50, 20, 1820, 1000, $true)
            [void](Wait-For 'owned note window resized' { [int]([System.Windows.Automation.AutomationElement]::FromHandle($main).Current.BoundingRectangle.Width) -eq 1820 })
            Bind-Transcript
            $cache = Wait-For 'five source runner notes in the app cache' {
                @(Get-ChildItem "$settings/chatcache/*.jsonl" -ErrorAction SilentlyContinue | Where-Object { (Read-Shared $_.FullName).Contains('[from hax-runner-2]') }) | Select-Object -First 1
            }
            Copy-Item $cache.FullName "$caseDir/app-cache.jsonl"
            $rows = (Read-Shared $cache.FullName) -split "`n" | Select-Object -Skip 1 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json }
            $observation.sourceNotes = @($rows | Where-Object { $_.role -eq 'user' -and $_.text -like '[[]from *' }).Count
            $observation.normalUser = @($rows | Where-Object { $_.role -eq 'user' -and $_.text -eq 'start the fake session' }).Count -eq 1
            $observation.normalReply = @($rows | Where-Object { $_.role -eq 'assistant' -and $_.text -eq 'The fake session is ready.' }).Count -eq 1
            function Note-Frame([string]$Stage) {
                Doctor
                $bounds = $views[0].Current.BoundingRectangle
                $frame = @{theme=(Read-Shared "$settings/theme-mode.txt").Trim(); scale=([LayoutCapture]::GetDpiForWindow($main) / 96.0); transcript=@{left=[int]$bounds.Left; top=[int]$bounds.Top; width=[int]$bounds.Width; height=[int]$bounds.Height}}
                Save $frame "$caseDir/frame-$Stage.json"
                Wait-For 'IGSH-1030 expected five compact runner rows or a retained expanded body' {
                    Shot "notes-$Stage"
                    & node "$PSScriptRoot/../chat-notes-proof.mjs" probe $Evidence $Stage
                    if ($LASTEXITCODE -eq 0) { Get-Content "$caseDir/probe-$Stage.json" -Raw | ConvertFrom-Json }
                } 10
            }
            function Click-Note($Frame, [string]$Action) {
                $bounds = $views[0].Current.BoundingRectangle
                $row = @($Frame.rows)[0]
                $x = [int]($row.left - $bounds.Left + 5)
                $y = [int](($row.top + $row.bottom) / 2 - $bounds.Top)
                $actions.Add(@{case=$plan.name; input="click runner note $Action"; x=$x; y=$y})
                [ChatDeliveryDesktop]::PressOwnedTranscript($main, $app.Id, [IntPtr]$views[0].Current.NativeWindowHandle, $x, $y)
            }
            foreach ($theme in @('dark', 'light')) {
                Press @(0x11, 0x4B) 'Ctrl+K: choose the existing theme'
                foreach ($letter in 'themes'.ToCharArray()) { [ChatDeliveryDesktop]::Character($letter) }
                Press @(0x0D) 'Enter: Themes'
                foreach ($letter in $theme.ToCharArray()) { [ChatDeliveryDesktop]::Character($letter) }
                Press @(0x0D) "Enter: choose $theme"
                [void](Wait-For 'app saved the selected theme' { (Read-Shared "$settings/theme-mode.txt").Trim() -eq $theme })
                Press @(0x1B) 'Esc: close Themes'
                [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
                Press @(0x11, 0x30) 'Ctrl+0: measure runner rows' $true
                $collapsed = Note-Frame "$theme-collapsed"
                Click-Note $collapsed 'expand'
                $expanded = Note-Frame "$theme-expanded"
                $pollLogStart = (Read-Shared "$settings/debug.log").Length
                Shell-Run @('turn', "notes-$theme")
                [void](Wait-For 'new source turn passed through the ordinary transcript poll' { (Read-Shared $cache.FullName).Contains("Remote answer notes-$theme") })
                $expectedBlocks = if ($theme -eq 'dark') { 9 } else { 11 }
                [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
                [void](Wait-For 'app rendered the new source turn' {
                    Press @(0x11, 0x30) 'Ctrl+0: inspect synced note layout' $true
                    (Read-Shared "$settings/debug.log").Substring($pollLogStart) -match ("\[chatfont\] pt=\d+ blocks=" + $expectedBlocks + ' content_h=')
                })
                $polled = Note-Frame "$theme-polled"
                Click-Note $polled 'collapse'
                [void](Note-Frame "$theme-folded")
                [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
            }
        } elseif ($isActivity) {
            if (-not (Step 'initial-transcript-loaded' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' } 30)) { throw 'Initial transcript was not read' }
            $cache = Wait-For 'app-written message cache' {
                @(Get-ChildItem "$settings/chatcache/*.jsonl" -ErrorAction SilentlyContinue | Where-Object { (Read-Shared $_.FullName).Contains('The fake session is ready.') }) | Select-Object -First 1
            }
            Type-Composer $plan.text
            if ([ChatDeliveryDesktop]::Text($composer) -cne $plan.text) { throw 'Composer typing failed' }
            Shell-Input 'todo'
            [void](Wait-For 'todo task in app-written cache' { (Read-Shared $cache.FullName).Contains('TodoWrite') })
            $root = [System.Windows.Automation.AutomationElement]::FromHandle($main)
            $condition = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
            $todoStatus = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Static')
            [void](Wait-For 'owned status row inside the transcript host once the todo is read' {
                $viewRows = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen -and $_.Current.ProcessId -eq $app.Id })
                if ($viewRows.Count -ne 1) { return $false }
                $viewBounds = $viewRows[0].Current.BoundingRectangle
                @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $todoStatus) | Where-Object {
                    $r = $_.Current.BoundingRectangle
                    -not $_.Current.IsOffscreen -and $_.Current.ProcessId -eq $app.Id -and $r.Left -eq $viewBounds.Left -and $r.Width -eq $viewBounds.Width -and ($r.Bottom -eq $viewBounds.Top -or ($r.Top -ge $viewBounds.Top -and $r.Bottom -lt $viewBounds.Bottom)) -and $r.Height -gt 0
                }).Count -eq 1
            })
            $views = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen -and $_.Current.ProcessId -eq $app.Id })
            if ($views.Count -ne 1) { throw 'Expected one owned visible transcript' }
            $hostBounds = $views[0].Current.BoundingRectangle
            $statusRows = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $todoStatus) | Where-Object {
                $r = $_.Current.BoundingRectangle
                -not $_.Current.IsOffscreen -and $_.Current.ProcessId -eq $app.Id -and $r.Left -eq $hostBounds.Left -and $r.Width -eq $hostBounds.Width -and ($r.Bottom -eq $hostBounds.Top -or ($r.Top -ge $hostBounds.Top -and $r.Bottom -lt $hostBounds.Bottom)) -and $r.Height -gt 0
            })
            if ($statusRows.Count -ne 1) { throw 'CLEAN chat proof requires one owned status/footer control' }
            $statusBounds = $statusRows[0].Current.BoundingRectangle
            $composerBounds = [System.Windows.Automation.AutomationElement]::FromHandle($composer).Current.BoundingRectangle
            if ($statusBounds.Bottom -eq $hostBounds.Top) {
                $bounds = $hostBounds
                $observation.transcript = @{left=[int]$bounds.Left; top=[int]$bounds.Top; width=[int]$bounds.Width; height=[int]$bounds.Height}
            } else {
                $viewport = Transcript-Viewport
                Save @{
                    viewport=@{left=$viewport.Left; top=$viewport.Top; width=$viewport.Width; height=$viewport.Height}
                    host=@{left=[int]$hostBounds.Left; top=[int]$hostBounds.Top; width=[int]$hostBounds.Width; height=[int]$hostBounds.Height}
                    status=@{left=[int]$statusBounds.Left; top=[int]$statusBounds.Top; width=[int]$statusBounds.Width; height=[int]$statusBounds.Height}
                    composer=@{left=[int]$composerBounds.Left; top=[int]$composerBounds.Top; width=[int]$composerBounds.Width; height=[int]$composerBounds.Height}
                } "$caseDir/geometry-input.json"
                $geometry = & node "$PSScriptRoot/../chat-messages-only-proof.mjs" $Evidence --geometry
                if ($LASTEXITCODE -ne 0) { throw 'Owned transcript geometry was invalid' }
                $geometry = $geometry | ConvertFrom-Json
                $observation.transcript = $geometry.transcript
                $observation.cleanChat = @{rows=$geometry.rows; working=$geometry.working}
                $bounds = New-Object Drawing.Rectangle($geometry.transcript.left, $geometry.transcript.top, $geometry.transcript.width, $geometry.transcript.height)
            }
            Press @(0x11, 0x30) 'Ctrl+0: lay out the baseline transcript' $true
            Copy-Item $cache.FullName "$caseDir/app-cache-before.jsonl"
            Shot 'messages-only-before-tools'
            if ($env:CHAT_WIDTH_PROOF -eq '1') {
                $frames = @()
                foreach ($size in @(@{name='wide'; width=1920}, @{name='narrow'; width=818})) {
                    Doctor $true
                    [void][LayoutCapture]::ShowWindow($main, 9)
                    if (-not [LayoutCapture]::MoveWindow($main, 0, 0, $size.width, 1000, $true)) { throw 'Owned resize failed' }
                    Press @(0x11, 0x30) 'Ctrl+0: render resized transcript' $true
                    [void](Wait-For 'owned window reached requested width' {
                        $r = [System.Windows.Automation.AutomationElement]::FromHandle($main).Current.BoundingRectangle
                        [int]$r.Width -eq $size.width
                    })
                    Start-Sleep -Milliseconds 750
                    Doctor $true
                    $frame = @{name=$size.name; dpi=[LayoutCapture]::GetDpiForWindow($main); version=$ExpectedVersion; sha256=$ExpectedHash}
                    foreach ($pair in @(@{key='window'; handle=$main}, @{key='composer'; handle=$composer})) {
                        $r = [System.Windows.Automation.AutomationElement]::FromHandle($pair.handle).Current.BoundingRectangle
                        $frame[$pair.key] = @{left=[int]$r.Left; top=[int]$r.Top; width=[int]$r.Width; height=[int]$r.Height}
                    }
                    $r = $views[0].Current.BoundingRectangle
                    $frame.transcript = @{left=[int]$r.Left; top=[int]$r.Top; width=[int]$r.Width; height=[int]$r.Height}
                    Shot "layout-$($size.name)"
                    $frames += $frame
                }
                Save $frames "$Evidence/layout-frames.json"
                $observation.endMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
                continue
            }
            $observation.actionMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            Shell-Input 'activity'
            [void](Wait-For 'all twelve completed tool calls in app-written cache' {
                $completed = & node "$PSScriptRoot/../chat-messages-only-proof.mjs" $cache.FullName --tool-count
                $LASTEXITCODE -eq 0 -and [int]$completed -eq 12
            })
            Copy-Item $cache.FullName "$caseDir/app-cache.jsonl"
            if ([ChatDeliveryDesktop]::Text($composer) -cne $plan.text) { throw 'Tool updates changed the composer' }
            Press @(0x11, 0x30) 'Ctrl+0: lay out the tool-heavy transcript' $true
            [void](Wait-For 'tool-heavy transcript applied to the real renderer' { (Read-Shared "$settings/debug.log") -match '\[chatfont\] pt=\d+ blocks=14 content_h=\d+' })
            $observation.composerText = [ChatDeliveryDesktop]::Text($composer)
            Save $observation "$caseDir/observation.json"
            Shot 'messages-only-after-tools'
            & node "$PSScriptRoot/../chat-messages-only-proof.mjs" $Evidence --tools-only
            if ($LASTEXITCODE -ne 0) { throw ((Get-Content "$Evidence/messages-only-measurement.json" -Raw | ConvertFrom-Json).error) }
            if (-not $observation.Contains('cleanChat')) { throw 'Complete CLEAN proof requires current measured layout' }
            foreach ($mode in @('on', 'off')) {
                $paletteLogStart = (Read-Shared "$settings/debug.log").Length
                Press @(0x11, 0x4B) 'Ctrl+K: open CLEAN chat palette' $true
                foreach ($letter in 'clean chat'.ToCharArray()) { Press @([int][char]::ToUpperInvariant($letter)) 'Filter CLEAN chat palette' }
                $paletteLog = (Read-Shared "$settings/debug.log").Substring($paletteLogStart)
                if ($paletteLog -notmatch '\[palette\] ready chars=10 count=1 target=\d+') { throw 'CLEAN chat palette filter did not select exactly one entry' }
                Press @(0x0D) "Enter: toggle CLEAN chat $mode"
                Doctor $true
                $saved = Get-Content "$settings/session.json" -Raw | ConvertFrom-Json
                $setting = $saved.PSObject.Properties['clean_chat']
                $enabled = $null -ne $setting -and $setting.Value -eq $true
                if ($enabled -ne ($mode -eq 'on')) { throw "CLEAN chat $mode was not persisted by the palette" }
                if ([ChatDeliveryDesktop]::Text($composer) -cne $plan.text) { throw 'CLEAN chat toggle changed the composer' }
                Shot "clean-chat-$mode"
            }
            Save $observation "$caseDir/observation.json"
            & node "$PSScriptRoot/../chat-messages-only-proof.mjs" $Evidence
            if ($LASTEXITCODE -ne 0) { throw ((Get-Content "$Evidence/messages-only-measurement.json" -Raw | ConvertFrom-Json).error) }
            Shell-Input 'busy'
            $fillLogStart = (Read-Shared "$settings/debug.log").Length
            Shell-Input 'messages' '12'
            [void](Wait-For 'new transcript messages at bottom' { (Read-Shared $cache.FullName).Contains('New message 11') })
            [void](Wait-For 'app applied filled transcript at bottom' { $log = Read-Shared "$settings/debug.log"; $log.Length -gt $fillLogStart -and $log.Substring($fillLogStart).Contains('[chat] new messages count=0 visible=0 up=0') })
            [void](Require-NewMessages 0 0 0 'arrival at bottom stays clear' $fillLogStart)
            $layoutLogStart = (Read-Shared "$settings/debug.log").Length
            Press @(0x11, 0x30) 'Ctrl+0: measure filled transcript' $true
            [void](Wait-For 'filled transcript exceeds viewport' {
                $log = Read-Shared "$settings/debug.log"
                if ($log.Length -le $layoutLogStart) { return $false }
                $layouts = [regex]::Matches($log.Substring($layoutLogStart), '\[chatfont\] pt=\d+ blocks=\d+ content_h=(\d+)')
                $layouts.Count -gt 0 -and [int]$layouts[$layouts.Count - 1].Groups[1].Value -gt $views[0].Current.BoundingRectangle.Height
            })
            $scrollLogStart = Scroll-Transcript 2400
            [void](Require-NewMessages 0 0 1 'loaded messages do not count' $scrollLogStart)
            $arrivalLogStart = (Read-Shared "$settings/debug.log").Length
            Shell-Input 'messages' '2'
            $pill = Require-NewMessages 2 1 1 'two new arrivals while reading' $arrivalLogStart
            $bounds = Transcript-Viewport
            $pillOrigin = [ChatDeliveryDesktop]::ScreenPoint($main, $pill.left, $pill.top)
            $pillEnd = [ChatDeliveryDesktop]::ScreenPoint($main, $pill.right, $pill.bottom)
            if ($pill.bottom -le $pill.top -or $pill.left -ge $pill.right -or $pillOrigin.Y -lt $bounds.Bottom -or [math]::Abs(($pillOrigin.X + $pillEnd.X) / 2 - ($bounds.Left + $bounds.Right) / 2) -gt 2) { throw 'New-message pill overlaps the transcript or is not centered' }
            Shot 'new-messages-visible'
            $scrollLogStart = Scroll-Transcript -120
            [void](Require-NewMessages 2 1 1 'scrolling retains count' $scrollLogStart)
            $dismissLogStart = (Read-Shared "$settings/debug.log").Length
            Click-NewMessages $true
            [void](Require-NewMessages 2 0 1 'close hides and retains count' $dismissLogStart)
            Shot 'new-messages-dismissed'
            $arrivalLogStart = (Read-Shared "$settings/debug.log").Length
            Shell-Input 'messages' '1'
            [void](Require-NewMessages 3 0 1 'dismissed arrivals retain hidden count' $arrivalLogStart)
            $scrollLogStart = Scroll-Transcript -30000
            [void](Require-NewMessages 0 0 0 'reaching bottom resets count' $scrollLogStart)
            $scrollLogStart = Scroll-Transcript 2400
            [void](Require-NewMessages 0 0 1 'scrolling up alone does not count' $scrollLogStart)
            $arrivalLogStart = (Read-Shared "$settings/debug.log").Length
            Shell-Input 'messages' '1'
            [void](Require-NewMessages 1 1 1 'new arrival after reset shows pill' $arrivalLogStart)
            $jumpLogStart = (Read-Shared "$settings/debug.log").Length
            Click-NewMessages $false
            [void](Require-NewMessages 0 0 0 'pill jumps and clears count' $jumpLogStart)
            Shot 'new-messages-jumped'
            [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
            Doctor $true
            $observation.newMessages = @{passed=$true; transitions=@('arrival-up', 'arrival-bottom', 'scroll-retains', 'bottom-reset', 'pill-jump-clear', 'close-retains', 'hidden-arrival')}
            $longLogStart = (Read-Shared "$settings/debug.log").Length
            Shell-Input 'messages' '120'
            [void](Wait-For 'long chat holds 120 more messages' { (Read-Shared $cache.FullName).Contains('New message 119') })
            [void](Require-NewMessages 0 0 0 'long chat arrival stays at bottom' $longLogStart)
            $readSource = (Read-Shared $transcript) -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json } | Select-Object -Last 1
            $readId = [string]$readSource.message.id
            Press @(0x12, 0x43) 'Alt+C: leave the read chat' $true
            $savedMarker = [string](Get-Content "$settings/session.json" -Raw | ConvertFrom-Json).tabs[0].last_read_message_id
            if (-not $savedMarker -or $savedMarker -eq '0') { throw 'Leaving chat did not save its read message anchor' }
            Copy-Item "$settings/session.json" "$caseDir/session-read-anchor.json"
            $unreadOffset = (Get-Item -LiteralPath $transcript).Length
            Shell-Input 'messages' '2'
            $unreadSource = @((Read-Shared $transcript) -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
            $firstUnreadId = [string]$unreadSource[$unreadSource.Count - 2].message.id
            Restart-OwnedApp
            if ([string](Get-Content "$settings/session.json" -Raw | ConvertFrom-Json).tabs[0].last_read_message_id -cne $savedMarker) { throw 'Restart lost the saved read anchor' }
            Press @(0x11, 0x31) 'Ctrl+1: select the restarted chat'
            $dividerLogStart = (Read-Shared "$settings/debug.log").Length
            Press @(0x12, 0x43) 'Alt+C: reopen chat after offline arrivals'
            Bind-Transcript
            $divider = Require-Divider 1 0 'one divider on reopen' $dividerLogStart
            [void](Require-NewMessages 0 0 0 'reopened long chat lands at the newest message' $dividerLogStart)
            if ($divider.scroll -le 0) { throw 'Reopened long chat did not scroll to the newest message' }
            if ($divider.marker -cne $savedMarker -or $divider.offset -ne $unreadOffset -or $divider.y -ge $divider.messageY) { throw 'Divider is not above the first unread source message' }
            [void](Wait-For 'resynced app cache contains first unread source ID' { (Read-Shared $cache.FullName).Contains($firstUnreadId) })
            Copy-Item $cache.FullName "$caseDir/app-cache-reopened.jsonl"
            Copy-Item "$settings/session.json" "$caseDir/session-reopened.json"
            $bounds = $views[0].Current.BoundingRectangle
            $dividerProof = @{marker=$savedMarker; readId=$readId; firstUnreadId=$firstUnreadId; unreadOffset=$unreadOffset; reopened=$divider; transcript=@{left=[int]$bounds.Left; top=[int]$bounds.Top; width=[int]$bounds.Width; height=[int]$bounds.Height}}
            Shot 'reopened-newest'
            $pinLogStart = (Read-Shared "$settings/debug.log").Length
            Shell-Input 'messages' '3'
            $pinned = Wait-For 'arrival while at the bottom keeps the view pinned to the newest message' { $v = Divider-State $pinLogStart; if ($v -and $v.scroll -gt $divider.scroll) { $v } }
            [void](Require-NewMessages 0 0 0 'arrival at the bottom never shows the pill or scrolls up' $pinLogStart)
            $actions.Add(@{case=$plan.name; input='pinned arrival'; state=$pinned})
            Shot 'pinned-after-arrival'
            $upLogStart = (Read-Shared "$settings/debug.log").Length
            $visibleBounds = Transcript-Viewport
            $visibleTop = [int]($visibleBounds.Top - $bounds.Top)
            $viewH = [int]$visibleBounds.Height
            $dividerProof.reopened = Wait-For 'scroll up until the unread line is painted above the first unread message' {
                $f = Divider-State $upLogStart
                if ($f -and $f.count -eq 1 -and $f.y -ge $f.scroll + $visibleTop -and $f.y -lt $f.scroll + $visibleTop + $viewH - 40) { return $f }
                [void](Scroll-Transcript 120)
                $null
            }
            Shot 'unread-divider-reopened'
            $gapLogStart = (Read-Shared "$settings/debug.log").Length
            Shell-Input 'forget-message' $readId
            $dividerProof.gap = Require-Divider 1 0 'known anchor survives source removal' $gapLogStart
            if ($dividerProof.gap.marker -cne $savedMarker) { throw 'History gap overwrote the saved anchor' }
            [void](Wait-For 'resynced cache retains the saved source message' { $bytes = Read-Shared $cache.FullName; $bytes.Contains($firstUnreadId) -and $bytes.Contains($readId) })
            Copy-Item $cache.FullName "$caseDir/app-cache-gap.jsonl"
            Shot 'unread-divider-gap'
            $bottomLogStart = (Read-Shared "$settings/debug.log").Length
            [void](Wait-For 'scroll the full history gap to bottom' {
                $frame = New-MessageState $bottomLogStart
                if ($frame -and $frame.up -eq 0) { return $true }
                [void](Scroll-Transcript -30000)
                $false
            })
            $dividerProof.bottom = Require-Divider 1 0 'bottom retains the visit divider' $bottomLogStart
            [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
            Press @(0x11, 0x4B) 'Ctrl+K: open a second tab for visit proof' $true
            foreach ($letter in 'new cmd'.ToCharArray()) { Press @([int][char]::ToUpperInvariant($letter)) 'Filter New CMD Shell' }
            Press @(0x0D) 'Enter: create the second tab'
            [void](Wait-For 'second tab saved and published' {
                $tabs = @((Get-Content "$settings/session.json" -Raw | ConvertFrom-Json).tabs)
                $published = @((Get-Content "$settings/inbox-default.json" -Raw | ConvertFrom-Json).shells)
                $tabs.Count -eq 2 -and $published.Count -eq 2 -and @($published | Where-Object { $_.kind -eq 3 }).Count -eq 1 -and @($published | Where-Object { $_.kind -eq 0 }).Count -eq 1
            })
            $expectedShells = 2
            $sendOffset = (Get-Item -LiteralPath $transcript).Length
            Shell-Input 'messages' '1'
            $dividerLogStart = (Read-Shared "$settings/debug.log").Length
            Press @(0x11, 0x09) 'Ctrl+Tab: return to the unread tab'
            Bind-Transcript
            $beforeSend = Require-Divider 1 0 'divider exists before sending' $dividerLogStart
            $dividerProof.beforeSend = $beforeSend
            if ($beforeSend.offset -ne $sendOffset) { throw 'Second reopen picked the wrong unread message' }
            Clear-Composer
            Type-Composer 'read reply'
            $sendLogStart = (Read-Shared "$settings/debug.log").Length
            Press @(0x0D) 'Enter: sending retains the visit divider' $true
            $dividerProof.sent = Require-Divider 1 0 'sending retains the visit divider' $sendLogStart
            Press @(0x11, 0x09) 'Ctrl+Tab: leave after sending' $true
            $allReadLogStart = (Read-Shared "$settings/debug.log").Length
            Press @(0x11, 0x09) 'Ctrl+Tab: reopen with everything read'
            Bind-Transcript
            $dividerProof.allRead = Require-Divider 0 0 'all-read reopen has no divider' $allReadLogStart
            Shot 'unread-divider-all-read'
            Save $dividerProof "$caseDir/unread-divider.json"
            $observation.unreadDivider = @{passed=$true; transitions=@('leave-save', 'closed-arrivals', 'restart-anchor', 'reopen-first-unread', 'gap-retained', 'bottom-retain', 'send-retain', 'all-read-absent')}
            $observation.endMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        } elseif ($isAccepted) {
            [void](Wait-For 'initial transcript read' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
            Type-Composer $plan.text
            Press @(0x0D) 'Enter: send busy message' $true
            [void](Wait-For 'exact message queued' { (Queue-View) -ceq ('queued:' + $plan.text) })
            [void](Wait-For 'composer remains empty' { ([ChatDeliveryDesktop]::Text($composer)) -ceq '' })
            $root = [System.Windows.Automation.AutomationElement]::FromHandle($main)
            $condition = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
            $view = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen -and $_.Current.ProcessId -eq $app.Id })
            if ($view.Count -ne 1) { throw 'Expected one visible owned transcript' }
            $bounds = $view[0].Current.BoundingRectangle
            $observation.area = @{left=[int]$bounds.Left; top=[int]$bounds.Top; right=[int]$bounds.Right; bottom=[int]$bounds.Bottom}
            [void](Wait-For 'transport settled while message remains queued' {
                if (-not (Test-Path "$settings/chat-outbox.json")) { return $false }
                $outbox = Read-Shared "$settings/chat-outbox.json" | ConvertFrom-Json
                @($outbox.queues | ForEach-Object { $_.messages } | Where-Object { $_.t -ceq $plan.text -and $_.s -eq 3 }).Count -eq 1
            })
            Copy-Item "$settings/chat-outbox.json" "$caseDir/outbox-queued.json"
            Start-Sleep -Milliseconds 200
            Shot 'accepted-queued'
            Shell-Run @('accept')
            $frames = [Collections.Generic.List[object]]::new()
            for ($i = 0; $i -lt 16; $i++) {
                $name = 'accepted-frame-' + $i
                Shot $name
                $captureMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
                $frames.Add(@{name=$name; ms=$captureMs})
                Start-Sleep -Milliseconds 80
            }
            $observation.frames = $frames.ToArray()
            $observation.composerText = [ChatDeliveryDesktop]::Text($composer)
            $observation.endMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        } elseif ($isSendStays) {
            [void](Step 'chat-view-read-transcript' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' } 30)
            $observation.sends = [Collections.Generic.List[object]]::new()
            $draftsBlank = {
                $left = @(Get-ChildItem "$settings/drafts" -Filter '*.txt' -ErrorAction SilentlyContinue | Where-Object { (Read-Shared $_.FullName).Trim().Length -gt 0 })
                $left.Count -eq 0
            }
            [void](Step 'drafts-blank-before-sends' { (([ChatDeliveryDesktop]::Text($composer)) -ceq '') -and (& $draftsBlank) } 10)
            $gaps = @(0, 300, 500, 600, 900, 1500)
            foreach ($n in 1..20) {
                $text = if ($n % 4 -eq 0) { "send $n long message about the weekly plan that keeps wrapping across several rows of the composer box until the whole text needs more than one line" } else { "send $n short note" }
                Type-Composer $text
                Start-Sleep -Milliseconds $gaps[($n - 1) % $gaps.Count]
                if ($n -eq 1) { Shot "$($plan.name)-action"; $observation.actionMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }
                Press @(0x0D) 'Enter: send composer' $true
                $reached = $false
                $deliveryWatch = [Diagnostics.Stopwatch]::StartNew()
                while (-not $reached -and $deliveryWatch.Elapsed.TotalSeconds -lt 10) {
                    $reached = ((@((Fake-State).queue) | Select-Object -Last 1) -ceq $text)
                    if (-not $reached) { Start-Sleep -Milliseconds 200 }
                }
                $back = $null
                $watch = [Diagnostics.Stopwatch]::StartNew()
                while ($watch.Elapsed.TotalSeconds -lt 10) {
                    $now = [ChatDeliveryDesktop]::Text($composer)
                    if ($now -cne '') { $back = @{kind='composer'; text=$now; atMs=[int]$watch.ElapsedMilliseconds}; break }
                    if (-not (& $draftsBlank)) { $back = @{kind='draft-file'; atMs=[int]$watch.ElapsedMilliseconds}; break }
                    Start-Sleep -Milliseconds 250
                }
                [void](Step 'send-stays-gone' { $null -eq $back } 1)
                $sendRecord = @{n=$n; text=$text; reached=$reached; reappeared=$back; tookQueue=$null}
                $observation.sends.Add($sendRecord)
                if ($n % 4 -eq 0) {
                    Shell-Input 'idle'
                    $tookWatch = [Diagnostics.Stopwatch]::StartNew()
                    $took = $false
                    while (-not $took -and $tookWatch.Elapsed.TotalSeconds -lt 5) {
                        $f = Fake-State
                        $took = (@($f.queue).Count -eq 0) -and ($f.box -ceq '')
                        if (-not $took) { Start-Sleep -Milliseconds 200 }
                    }
                    $sendRecord.tookQueue = $took
                    Shell-Input 'busy'
                }
            }
            [void](Step 'outbox-snapshot' {
                if (Test-Path "$settings/chat-outbox.json") { Copy-Item "$settings/chat-outbox.json" "$caseDir/outbox-final.json" -Force } else { Set-Content -LiteralPath "$caseDir/outbox-final.json" -Value '{"queues":[]}' }
                Test-Path "$caseDir/outbox-final.json"
            } 5)
            Shot "$($plan.name)-done"
            $observation.endMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        } elseif ($isQueue) {
            $t = $queueTexts
            [void](Step 'chat-view-read-transcript' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' } 30)
            Shell-Input 'text' $t.a
            Shell-Input 'key' 'Enter'
            [void](Step 'chat-lists-shell-queued' { (Queue-View) -ceq ('queued:' + $t.a) })
            Type-Composer $t.b
            Shot "$($plan.name)-action"
            $observation.actionMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            Press @(0x0D) 'Enter: send composer' $true
            [void](Step 'chat-lists-both-in-order' { (Queue-View) -ceq ('queued:' + $t.a + '|queued:' + $t.b) })
            [void](Step 'shell-lists-both-in-order' { (@((Fake-State).queue) -join '|') -ceq ($t.a + '|' + $t.b) })
            Shell-Input 'key' 'Up'
            [void](Step 'queue-pulled-into-box' { $f = Fake-State; (@($f.queue).Count -eq 0) -and ($f.box -ceq ($t.a + "`n" + $t.b)) } 5)
            Shell-Input 'key' 'C-u'
            Shell-Input 'text' $t.a2
            Shell-Input 'key' 'Enter'
            Shell-Input 'text' $t.b
            Shell-Input 'key' 'Enter'
            [void](Step 'chat-lists-edited-in-order' { (Queue-View) -ceq ('queued:' + $t.a2 + '|queued:' + $t.b) })
            [void](Step 'shell-lists-edited-in-order' { (@((Fake-State).queue) -join '|') -ceq ($t.a2 + '|' + $t.b) })
            Shell-Input 'idle'
            [void](Step 'chat-marks-both-sent' { (Queue-View) -ceq ('sent:' + $t.a2 + '|sent:' + $t.b) })
            [void](Step 'shell-took-both' { $f = Fake-State; ($f.mode -ceq 'idle') -and (@($f.queue).Count -eq 0) -and ($f.box -ceq '') } 5)
            Start-Sleep -Seconds 6
            [void](Step 'suggestion-not-draft' { ([ChatDeliveryDesktop]::Text($composer)) -ceq '' } 5)
            Shell-Input 'text' $t.shellDraft
            Start-Sleep -Seconds 8
            Shot "$($plan.name)-agent-paste-empty"
            [void](Step 'composer-ignores-agent-paste' { ([ChatDeliveryDesktop]::Text($composer)) -ceq '' } 5)
            Shell-Input 'key' 'C-u'
            Clear-Composer
            Type-Composer $t.chatDraft
            [void](Step 'shell-box-shows-chat-draft' { (Fake-State).box -ceq $t.chatDraft })
            Shell-Input 'text' $t.agentPaste
            Start-Sleep -Seconds 8
            Shot "$($plan.name)-draft-kept"
            [void](Step 'draft-survives-agent-paste' { ([ChatDeliveryDesktop]::Text($composer)) -ceq $t.chatDraft } 5)
            $observation.endMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        } else {
            $actions.Add(@{case=$plan.name; ms=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); input='type composer text'; text=$plan.text})
            foreach ($letter in $plan.text.ToCharArray()) {
                Doctor $true
                [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter))
                Start-Sleep -Milliseconds 30
            }
            $observation.composerText = [ChatDeliveryDesktop]::Text($composer)
            if ($observation.composerText -cne $plan.text) { throw 'Real keyboard composer text mismatch' }
            Shot "$($plan.name)-action"
            $observation.actionMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            if ($plan.name -eq 'steer-chord') {
                Press @(0x11, 0x58) 'Ctrl+X: steer prefix' $true
                Press @(0x11, 0x53) 'Ctrl+S: steer send' $true
            } else { Press @(0x0D) 'Enter: send composer' $true }
            if ($isSending) {
                [void](Wait-For 'transport blocked while message is in flight' { Test-Path "$state/send-blocked" })
                [void](Wait-For 'composer cleared after sending' { ([ChatDeliveryDesktop]::Text($composer)) -ceq '' })
                $root = [System.Windows.Automation.AutomationElement]::FromHandle($main)
                $condition = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
                $views = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen -and $_.Current.ProcessId -eq $app.Id })
                if ($views.Count -ne 1) { throw 'Expected one owned visible transcript' }
                $bounds = $views[0].Current.BoundingRectangle
                $observation.transcript = @{left=[int]$bounds.Left; top=[int]$bounds.Top; width=[int]$bounds.Width; height=[int]$bounds.Height}
                Start-Sleep -Milliseconds 200
                Shot 'sending-immediate'
                $observation.blockedAtCapture = (Test-Path "$state/send-blocked") -and -not (Test-Path "$state/release-send")
                [IO.File]::WriteAllText("$state/release-send", '')
                [void](Wait-For 'exact message delivered to fake agent queue' { @((Fake-State).queue) -contains $plan.text })
            }
            $deadline = $observation.actionMs + 15000
            while ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() -lt $deadline) { Start-Sleep -Milliseconds 100 }
            $observation.endMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            if ($isSending) { Shot 'sending-delivered' }
        }
        Doctor $true
        Copy-Item "$settings/session.json" "$caseDir/session-chat.json"
        Shot "$($plan.name)-after"
    } catch {
        $observation.error = $_.ToString()
        $observation.error | Set-Content "$caseDir/error.txt"
    } finally {
        try { Shot "$($plan.name)-final"; Shot 'after' } catch { $observation.error = "Screenshot: $_" }
        try {
            if ($app -and -not $app.HasExited) { [void]$app.CloseMainWindow(); [void]$app.WaitForExit(3000) }
            if ($job) { $stopped = $job.Stop(); $cleanup.remaining_owned_processes = $stopped.ActiveProcesses; Save $stopped "$caseDir/process-tree.json" }
        } catch { $observation.error = "Owned cleanup: $_" } finally { if ($job) { $job.Dispose() } }
        try {
            if (Test-Path "$settings/debug.log") { Copy-Item "$settings/debug.log" "$caseDir/debug.log"; Get-Content "$caseDir/debug.log" | Add-Content "$Evidence/debug.log" }
            if (Test-Path $state) { Copy-Item $state "$caseDir/stand-in" -Recurse -Force }
            foreach ($file in @('agent-buffer.jsonl', 'invocations.jsonl')) {
                $source = "$caseDir/stand-in/$file"
                if (Test-Path $source) { Get-Content $source | Add-Content "$Evidence/$file" }
            }
            if (Test-Path "$settings/session.json") { Copy-Item "$settings/session.json" "$caseDir/session-after.json" }
            if (Test-Path "$settings/crashes") {
                New-Item -ItemType Directory -Force "$caseDir/crashes" | Out-Null
                Copy-Item "$settings/crashes/*.txt" "$caseDir/crashes/" -ErrorAction SilentlyContinue
            }
            if ($isActivity -and (Test-Path "$settings/chatcache")) { Copy-Item "$settings/chatcache" "$caseDir/chatcache" -Recurse -Force }
            if ($hasTranscript -and $transcript -and (Test-Path -LiteralPath $transcript)) { Copy-Item -LiteralPath $transcript "$caseDir/transcript.jsonl" }
            $cleanup.evidence_preserved = (Test-Path "$caseDir/debug.log") -and (Test-Path "$caseDir/stand-in/ready.json")
            if ($isHax) {
                Copy-Item "$profile/home/.local/state/hax/sessions" "$caseDir/hax-sessions" -Recurse -Force
                foreach ($pidValue in $standIn.panes.Values) { Remove-Item -LiteralPath "$($standIn.procRoot)/$pidValue" -Recurse -Force -ErrorAction SilentlyContinue }
            }
            if ($hasTranscript -and $procDir) {
                Remove-Item -LiteralPath $procDir -Recurse -Force -ErrorAction SilentlyContinue
                $procRoot = Split-Path $procDir
                if ((Test-Path -LiteralPath $procRoot) -and -not (Get-ChildItem -LiteralPath $procRoot -Force)) { Remove-Item -LiteralPath $procRoot -Force }
            }
            Remove-Item -LiteralPath $profile -Recurse -Force
            $cleanup.scratch_removed = -not (Test-Path -LiteralPath $profile)
        } catch { $observation.error = "Evidence/cleanup: $_" }
        Save $observation "$caseDir/observation.json"
        Save $cleanup "$caseDir/cleanup.json"
        ($results | Where-Object { $_.name -eq $plan.name }).detail = $(if ($observation.error) { $observation.error } else { 'Awaiting independent buffer evaluation' })
        Save @{feature=$Feature; status='failed'; agentBoundary='stand-in remote shell + fake tmux + scripted agent screen, not real Claude or a real server'; cases=$results} "$Evidence/result.json"
    }
}
Save $actions.ToArray() "$Evidence/actions.json"
$doctors = @($plans | ForEach-Object { $file = "$Evidence/$($_.name)/doctor.json"; if (Test-Path $file) { @{name=$_.name; identity=(Get-Content $file -Raw | ConvertFrom-Json)} } })
Save $doctors "$Evidence/doctor.json"
$cleanups = @($plans | ForEach-Object { Get-Content "$Evidence/$($_.name)/cleanup.json" -Raw | ConvertFrom-Json })
Save @{remaining_owned_processes=($cleanups | Measure-Object remaining_owned_processes -Sum).Sum; evidence_preserved=(@($cleanups | Where-Object { -not $_.evidence_preserved }).Count -eq 0); scratch_removed=(@($cleanups | Where-Object { -not $_.scratch_removed }).Count -eq 0)} "$Evidence/cleanup.json"
Stop-Transcript
if ($env:CHAT_RESYNC_PROOF -eq '1') {
    & node "$PSScriptRoot/../chat-resync-proof.mjs" $Evidence
    exit $LASTEXITCODE
}
if ($env:CHAT_LIVE_DELIVERY_PROOF -eq '1') {
    & node "$PSScriptRoot/../chat-delivery-live-proof.mjs" $Evidence
    exit $LASTEXITCODE
}
if ($env:CHAT_REPLY_PROOF -eq '1') {
    & node "$PSScriptRoot/../chat-reply-reference-proof.mjs" verify $Evidence
    exit $LASTEXITCODE
}
if ($env:CHAT_NOTES_PROOF -eq '1') {
    & node "$PSScriptRoot/../chat-notes-proof.mjs" verify $Evidence
    exit $LASTEXITCODE
}
if ($env:CHAT_HAX_PROOF -eq '1') {
    & node "$PSScriptRoot/../hax-sessions-proof.mjs" $Evidence
    exit $LASTEXITCODE
}
if ($env:CHAT_REACTIONS_PROOF -eq '1') {
    & node "$PSScriptRoot/../chat-reactions-proof.mjs" $Evidence
    exit $LASTEXITCODE
}
if ($env:CHAT_ACCEPTED_PROOF -eq '1') {
    & node "$PSScriptRoot/../chat-accepted-proof.mjs" $Evidence
    exit $LASTEXITCODE
}
if ($env:CHAT_SWITCH_PROOF -eq '1') {
    if ($env:CHAT_SWITCH_PAIRED -eq '1') {
        & node "$PSScriptRoot/../remote-switch-proof.mjs" $Evidence --measure
    } else {
        & node "$PSScriptRoot/../remote-switch-proof.mjs" $Evidence
    }
    exit $LASTEXITCODE
}
if ($env:CHAT_REMOTE_PROOF -eq '1') {
    & node "$PSScriptRoot/../chat-remote-sync-proof.mjs" $Evidence
    exit $LASTEXITCODE
}
if ($env:CHAT_MISSING_PROOF -eq '1') {
    & node "$PSScriptRoot/../chat-missing-note-proof.mjs" $Evidence
    exit $LASTEXITCODE
}
if ($env:CHAT_SENDING_PROOF -eq '1') {
    & node "$PSScriptRoot/../chat-sending-status-proof.mjs" $Evidence
    if ($LASTEXITCODE -ne 0) { exit 1 }
    exit 0
}
if ($env:CHAT_WIDTH_PROOF -eq '1') {
    $observed = Get-Content "$Evidence/messages-only/observation.json" -Raw | ConvertFrom-Json
    $clean = Get-Content "$Evidence/cleanup.json" -Raw | ConvertFrom-Json
    if ($observed.error -or $clean.remaining_owned_processes -ne 0 -or -not $clean.scratch_removed -or -not (Test-Path "$Evidence/layout-frames.json")) { throw "Layout capture failed: $($observed.error)" }
    & node "$PSScriptRoot/../chat-width-proof.mjs" $Evidence
    if ($LASTEXITCODE -ne 0) { throw 'IGSH-898 message width pixel proof failed' }
    exit 0
}
if ($env:CHAT_SKILLS_PROOF -eq '1') {
    & node "$PSScriptRoot/../chat-skills-proof.mjs" $Evidence
} elseif ($env:CHAT_RETENTION_PROOF -eq '1') {
    & node "$PSScriptRoot/../chat-history-retention-proof.mjs" $Evidence
} elseif ($Feature -eq 'chat-full-history') {
    & node "$PSScriptRoot/../chat-full-history-proof.mjs" $Evidence
} elseif ($Feature -eq 'chat-messages-only') {
    & node "$PSScriptRoot/../chat-messages-only-proof.mjs" $Evidence --complete
} else {
    & node "$PSScriptRoot/check-evidence.js" $Evidence
}
if ($LASTEXITCODE -ne 0) { exit 1 }
