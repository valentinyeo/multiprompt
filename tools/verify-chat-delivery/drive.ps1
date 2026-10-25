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
$plans = @(
    @{name='busy-send'; mode='busy'; text='busy delivery alpha'},
    @{name='idle-suggestion'; mode='idle'; text='idle delivery beta'},
    @{name='steer-chord'; mode='busy'; text='steer delivery gamma'},
    @{name='wrapped-leftover'; mode='busy'; text='wrapped delivery delta'; leftover='earlier long message about the weekly plan that keeps wrapping across rows'}
    @{name='queue-draft-sync'; mode='busy'; text='chat queued beta'}
)
if ($Feature -eq 'chat-messages-only') { $plans = @(@{name='messages-only'; mode='busy'; text='composer stays usable'}) }
if ($Feature -eq 'chat-full-history') { $plans = @(@{name='full-history'; mode='busy'; text='all session messages'}) }
$queueTexts = @{a='shell queued alpha'; b='chat queued beta'; a2='shell queued alpha edited'; shellDraft='shell draft gamma'; chatDraft='chat draft delta'; suggestion='Try asking about the next step'}
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
    $bitmap = [Drawing.Bitmap]::new([ChatDeliveryDesktop]::GetSystemMetrics(0), [ChatDeliveryDesktop]::GetSystemMetrics(1))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen(0, 0, 0, 0, $bitmap.Size); $bitmap.Save("$Evidence/$Name.png", [Drawing.Imaging.ImageFormat]::Png); if ($Name -in @('messages-only-before-tools', 'messages-only-after-tools', 'clean-chat-on', 'clean-chat-off', 'unread-divider-reopened', 'unread-divider-gap', 'unread-divider-all-read')) { $bitmap.Save("$Evidence/$Name.bmp", [Drawing.Imaging.ImageFormat]::Bmp) } }
    finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Doctor([bool]$Chat = $false) {
    $app.Refresh()
    if ($app.HasExited -or $app.Path -ne $Exe -or (Get-FileHash $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Doctor: executable identity mismatch' }
    if ([ChatDeliveryDesktop]::Owner($main) -ne $app.Id -or [ChatDeliveryDesktop]::Class($main) -ne 'ZigShell') { throw 'Doctor: owned main HWND missing' }
    $element = [System.Windows.Automation.AutomationElement]::FromHandle($main)
    $title = $element.Current.Name
    if ($element.Current.IsOffscreen -or $element.Current.ProcessId -ne $app.Id -or $title -notmatch ('multiprompt v' + [regex]::Escape($ExpectedVersion) + '(?:\s|$)')) { throw 'Doctor: visible versioned UI Automation identity missing' }
    $published = Get-Content "$settings/inbox-default.json" -Raw | ConvertFrom-Json
    if (@($published.shells).Count -ne 1 -or $published.shells[0].kind -ne 3) { throw 'Doctor: saved tmux shell was not published' }
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
        [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter))
        Start-Sleep -Milliseconds 30
    }
}
function Clear-Composer {
    $length = ([ChatDeliveryDesktop]::Text($composer)).Length
    for ($i = 0; $i -lt $length; $i++) { Press @(0x08) 'Backspace: clear composer' $true }
}
function Assert-FullHistory([string]$Stage) {
    $offset = (Read-Shared "$settings/debug.log").Length
    $complete = Step 'all session rows reach the renderer' {
        Press @(0x11, 0x30) 'Ctrl+0: measure every rendered session row'
        $log = (Read-Shared "$settings/debug.log").Substring($offset)
        $frames = [regex]::Matches($log, '\[chatfont\] pt=\d+ blocks=(\d+) content_h=\d+')
        $frames.Count -gt 0 -and [int]$frames[$frames.Count - 1].Groups[1].Value -eq 74
    }
    if (-not $complete) { throw "IGSH-815 incomplete session at $Stage" }
    $pollOffset = (Read-Shared "$settings/debug.log").Length
    [void](Wait-For 'normal transcript poll completes after full history loads' {
        (Read-Shared "$settings/debug.log").Substring($pollOffset) -match '(?s)\[chat\] transcript request shell=(\d+) offset=\d+ before=0.*?\[chat\] transcript load shell=\1 ok'
    })
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x30) 'Ctrl+0: measure every session row after polling'
    $frames = [regex]::Matches((Read-Shared "$settings/debug.log").Substring($offset), '\[chatfont\] pt=\d+ blocks=(\d+) content_h=\d+')
    if ($frames.Count -eq 0 -or [int]$frames[$frames.Count - 1].Groups[1].Value -ne 74) { throw "IGSH-815 session rows lost after polling at $Stage" }
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
    $expected = @(0..23 | ForEach-Object { 'IGSH815 user {0:00}' -f $_; 'IGSH815 assistant {0:00}' -f $_ })
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
    Save @{stage=$Stage; blocks=74; polled=$true; messages=($actual.Count + 2); copied=$actual} "$caseDir/$Stage.json"
}
foreach ($plan in $plans) {
    $caseDir = "$Evidence/$($plan.name)"
    New-Item -ItemType Directory -Force $caseDir | Out-Null
    $profile = Join-Path $env:RUNNER_TEMP ('chat-delivery-' + [guid]::NewGuid().ToString('N'))
    $state = "$profile/state"
    $settings = "$profile/roaming/ZigShell"
    $app = $null
    $job = $null
    $main = [IntPtr]::Zero
    $composer = [IntPtr]::Zero
    $isQueue = $plan.name -eq 'queue-draft-sync'
    $isActivity = $plan.name -eq 'messages-only'
    $isHistory = $plan.name -eq 'full-history'
    $hasTranscript = $isQueue -or $isActivity -or $isHistory
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
        $standIn = $seed
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
            $standIn.procDir = $procDir
            $observation.texts = $queueTexts
            $observation.steps = $steps
        }
        Save $standIn "$state/state.json"
        if ($hasTranscript) { Shell-Run @('init') }
        if ($isHistory) { Shell-Run @('history') }
        [IO.File]::WriteAllText("$state/agent-buffer.jsonl", '')
        Save @{active_tab=0; single_window=$false; chat_active=$false; tabs=@(@{kind='tmux'; name='Verify agent'; manual=$true; tmux_host=0; tmux_session='verify-agent'; cv=$false; pid=0})} "$settings/session.json"
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
        if ($isHistory) {
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
        } elseif ($isActivity) {
            if (-not (Step 'initial-transcript-loaded' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' } 30)) { throw 'Initial transcript was not read' }
            $cache = Wait-For 'app-written message cache' {
                @(Get-ChildItem "$settings/chatcache/*.jsonl" -ErrorAction SilentlyContinue | Where-Object { (Read-Shared $_.FullName).Contains('The fake session is ready.') }) | Select-Object -First 1
            }
            Type-Composer $plan.text
            if ([ChatDeliveryDesktop]::Text($composer) -cne $plan.text) { throw 'Composer typing failed' }
            $root = [System.Windows.Automation.AutomationElement]::FromHandle($main)
            $condition = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
            $views = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen -and $_.Current.ProcessId -eq $app.Id })
            if ($views.Count -ne 1) { throw 'Expected one owned visible transcript' }
            $bounds = $views[0].Current.BoundingRectangle
            $observation.transcript = @{left=[int]$bounds.Left; top=[int]$bounds.Top; width=[int]$bounds.Width; height=[int]$bounds.Height}
            Press @(0x11, 0x30) 'Ctrl+0: lay out the baseline transcript' $true
            Copy-Item $cache.FullName "$caseDir/app-cache-before.jsonl"
            Shot 'messages-only-before-tools'
            $observation.actionMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            Shell-Input 'activity'
            [void](Wait-For 'all twelve completed tool calls in app-written cache' {
                $rows = (Read-Shared $cache.FullName) -split "`n" | Select-Object -Skip 1 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json }
                @($rows | Where-Object { $_.role -eq 'tool' -and $_.status -eq 'ok' -and $_.detail.Contains('verified') }).Count -eq 12
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
            $statusCondition = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Static')
            $statusRows = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $statusCondition) | Where-Object {
                $r = $_.Current.BoundingRectangle
                -not $_.Current.IsOffscreen -and $_.Current.ProcessId -eq $app.Id -and $r.Left -eq $bounds.Left -and $r.Width -eq $bounds.Width -and $r.Bottom -eq $bounds.Top -and $r.Height -gt 0
            })
            if ($statusRows.Count -ne 1) { throw 'CLEAN chat proof requires one owned painted status/footer row' }
            $statusBounds = $statusRows[0].Current.BoundingRectangle
            $composerBounds = [System.Windows.Automation.AutomationElement]::FromHandle($composer).Current.BoundingRectangle
            $composerTopPad = [int][math]::Floor(12 * $statusBounds.Height / 28)
            $workingHeight = [int]($composerBounds.Top - $composerTopPad - $bounds.Bottom)
            $expectedGapHeight = [int][math]::Floor(14 * $statusBounds.Height / 28)
            if ($workingHeight -ne $expectedGapHeight) { throw 'IGSH-849 removed working strip still reserves space' }
            $observation.cleanChat = @{
                rows=@{left=[int]$statusBounds.Left; top=[int]$statusBounds.Top; width=[int]$statusBounds.Width; height=[int]$statusBounds.Height}
                working=@{left=[int]$bounds.Left; top=[int]$bounds.Bottom; width=[int]$bounds.Width; height=$workingHeight}
            }
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
            $bounds = $views[0].Current.BoundingRectangle
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
            $viewH = [int]$bounds.Height
            $dividerProof.reopened = Wait-For 'scroll up until the unread line is painted above the first unread message' {
                $f = Divider-State $upLogStart
                if ($f -and $f.count -eq 1 -and $f.y -ge $f.scroll -and $f.y -lt $f.scroll + $viewH - 40) { return $f }
                [void](Scroll-Transcript 300)
                $null
            }
            Shot 'unread-divider-reopened'
            $gapLogStart = (Read-Shared "$settings/debug.log").Length
            Shell-Input 'forget-message' $readId
            $dividerProof.gap = Require-Divider 1 1 'missing anchor renders an unknown-position line' $gapLogStart
            if ($dividerProof.gap.marker -cne $savedMarker) { throw 'History gap overwrote the saved anchor' }
            [void](Wait-For 'resynced cache no longer contains the saved source message' { $bytes = Read-Shared $cache.FullName; $bytes.Contains($firstUnreadId) -and -not $bytes.Contains($readId) })
            Copy-Item $cache.FullName "$caseDir/app-cache-gap.jsonl"
            Shot 'unread-divider-gap'
            $bottomLogStart = (Read-Shared "$settings/debug.log").Length
            [void](Wait-For 'scroll the full history gap to bottom' {
                $frame = Divider-State $bottomLogStart
                if ($frame -and $frame.count -eq 0 -and $frame.unknown -eq 0) { return $true }
                [void](Scroll-Transcript -30000)
                $false
            })
            $dividerProof.bottom = Require-Divider 0 0 'bottom clears the divider' $bottomLogStart
            [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
            Press @(0x12, 0x43) 'Alt+C: close the fully read chat' $true
            $sendOffset = (Get-Item -LiteralPath $transcript).Length
            Shell-Input 'messages' '1'
            $dividerLogStart = (Read-Shared "$settings/debug.log").Length
            Press @(0x12, 0x43) 'Alt+C: reopen before sending'
            Bind-Transcript
            $beforeSend = Require-Divider 1 0 'divider exists before sending' $dividerLogStart
            if ($beforeSend.offset -ne $sendOffset) { throw 'Second reopen picked the wrong unread message' }
            Clear-Composer
            Type-Composer 'read reply'
            $sendLogStart = (Read-Shared "$settings/debug.log").Length
            Press @(0x0D) 'Enter: sending clears the unread divider' $true
            $dividerProof.sent = Require-Divider 0 0 'sending clears the divider' $sendLogStart
            Press @(0x12, 0x43) 'Alt+C: leave after sending' $true
            $allReadLogStart = (Read-Shared "$settings/debug.log").Length
            Press @(0x12, 0x43) 'Alt+C: reopen with everything read'
            Bind-Transcript
            $dividerProof.allRead = Require-Divider 0 0 'all-read reopen has no divider' $allReadLogStart
            Shot 'unread-divider-all-read'
            Save $dividerProof "$caseDir/unread-divider.json"
            $observation.unreadDivider = @{passed=$true; transitions=@('leave-save', 'closed-arrivals', 'restart-anchor', 'reopen-first-unread', 'gap-unknown', 'bottom-clear', 'send-clear', 'all-read-absent')}
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
            [void](Step 'composer-shows-shell-draft' { ([ChatDeliveryDesktop]::Text($composer)) -ceq $t.shellDraft })
            Shell-Input 'key' 'C-u'
            [void](Step 'composer-clears-with-shell' { ([ChatDeliveryDesktop]::Text($composer)) -ceq '' } 10)
            Clear-Composer
            Type-Composer $t.chatDraft
            [void](Step 'shell-box-shows-chat-draft' { (Fake-State).box -ceq $t.chatDraft })
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
            $deadline = $observation.actionMs + 15000
            while ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() -lt $deadline) { Start-Sleep -Milliseconds 100 }
            $observation.endMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
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
            if ($isActivity -and (Test-Path "$settings/chatcache")) { Copy-Item "$settings/chatcache" "$caseDir/chatcache" -Recurse -Force }
            if ($hasTranscript -and $transcript -and (Test-Path -LiteralPath $transcript)) { Copy-Item -LiteralPath $transcript "$caseDir/transcript.jsonl" }
            $cleanup.evidence_preserved = (Test-Path "$caseDir/debug.log") -and (Test-Path "$caseDir/stand-in/ready.json")
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
if ($Feature -eq 'chat-full-history') {
    & node "$PSScriptRoot/../chat-full-history-proof.mjs" $Evidence
} elseif ($Feature -eq 'chat-messages-only') {
    & node "$PSScriptRoot/../chat-messages-only-proof.mjs" $Evidence --complete
} else {
    & node "$PSScriptRoot/check-evidence.js" $Evidence
}
if ($LASTEXITCODE -ne 0) { exit 1 }
