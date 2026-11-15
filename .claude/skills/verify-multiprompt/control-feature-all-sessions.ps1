$log = Join-Path $scratch 'roaming/ZigShell/debug.log'
$result.seedBoundary = 'Three saved remote tabs across two servers and one archive entry are seeded once; only SSH listings, transports and end requests are synthetic. Native rendering, input, filtering and persistence run unchanged.'
function All-Frame {
    $trace = Read-SharedText $log
    $frames = [regex]::Matches($trace, '(?s)\[all-sessions\] begin\r?\n.*?\[all-sessions\] view [^\r\n]*')
    if ($frames.Count) { return $frames[$frames.Count - 1].Value }
    return ''
}
function All-Step([string]$Name, [scriptblock]$InputAction, [string[]]$Expected) {
    $offset = (Read-SharedText $log).Length
    & $InputAction
    Wait-Until {
        $trace = Read-SharedText $log
        if ($trace.Length -le $offset) { return $false }
        $frame = All-Frame
        foreach ($pattern in $Expected) { if ($frame -notmatch $pattern) { return $false } }
        return $trace.Substring($offset) -match '\[all-sessions\] view '
    } "All sessions $Name"
    [IO.File]::WriteAllText((Join-Path $Evidence ($Name + '.txt')), (All-Frame))
    Snapshot $Name
}
function All-Click([string]$Pattern) {
    Doctor
    Wait-Foreground
    $match = [regex]::Match((All-Frame), $Pattern + ' rect=(\d+),(\d+),(\d+),(\d+)')
    if (!$match.Success) { throw "No painted target for $Pattern" }
    $x = [int](([int]$match.Groups[1].Value + [int]$match.Groups[3].Value) / 2)
    $y = [int](([int]$match.Groups[2].Value + [int]$match.Groups[4].Value) / 2)
    Record "Click All sessions $Pattern at $x,$y"
    [VerifyNative]::ClickClient($script:window, $x, $y)
}
function All-Row([string]$SessionName, [string]$Action) {
    Doctor
    Wait-Foreground
    $match = [regex]::Match((All-Frame), ('row session=' + [regex]::Escape($SessionName) + ' [^\r\n]* y=(\d+) open=(\d+) archive=(\d+) close=(\d+)'))
    if (!$match.Success) { throw "No painted row for $SessionName" }
    $y = [int]$match.Groups[1].Value
    $column = @{open=2; archive=3; close=4}[$Action]
    $x = [int]$match.Groups[$column].Value
    Record "Hover and click $Action on $SessionName at $x,$y"
    [VerifyNative]::MoveMouseClient($script:window, $x, $y, $false)
    [void][VerifyNative]::DwmFlush()
    [VerifyNative]::ClickClient($script:window, $x, $y)
}
[void][VerifyNative]::MoveWindow($script:window, 0, 0, 1280, 900, $true)
Wait-Until { $s = Read-Session; $s -and @($s.tabs | Where-Object { $_.kind -eq 'tmux' }).Count -eq 3 } 'three restored remote tabs'
All-Step 'before' { Palette 'show all sessions' '6290'; Press @(0x0D) 'Enter: Show all sessions' } @(
    'view tab=200 host=255 visible=6 selected=0 marks=0 running=3 servers=2 archived=1',
    'chip host=0 running=2 ram=224', 'chip host=1 running=0 ram=512', 'chip host=2 running=1 ram=256'
)
$result.checks += @{ name = 'summary'; passed = $true; evidence = 'before.txt'; running = 3; servers = 2; archived = 1 }
All-Step 'server-chip-on' { All-Click 'chip host=2 running=1 ram=256' } @('view tab=200 host=2 visible=1', 'row session=second state=Running')
All-Step 'server-chip-off' { All-Click 'chip host=2 running=1 ram=256' } @('view tab=200 host=255 visible=6')
$result.checks += @{ name = 'server-chips'; passed = $true; evidence = 'before.txt, server-chip-on.txt, server-chip-off.txt'; counts = @(2,0,1); memory = @(224,512,256) }
All-Step 'running-tab' { All-Click 'tab id=204 count=3' } @('view tab=204 host=255 visible=3')
All-Step 'no-window-tab' { All-Click 'tab id=205 count=2' } @('view tab=205 host=255 visible=2', 'row session=spare state=No window', 'row session=remote-one state=No window')
All-Step 'archived-tab' { Press @(0x41) 'A: Archived tab' } @('view tab=203 host=255 visible=1', 'row session=archived-example state=Archived')
All-Step 'all-tab' { All-Click 'tab id=200 count=6' } @('view tab=200 host=255 visible=6')
$result.checks += @{ name = 'state-tabs'; passed = $true; evidence = 'running-tab.txt, no-window-tab.txt, archived-tab.txt, all-tab.txt' }
$frame = All-Frame
foreach ($pattern in @('row session=first state=Running workspace=Other host=0 ram=128', 'row session=second state=Running workspace=Other host=2 ram=256', 'row session=terminal-owner state=Running workspace=Example host=0 ram=32', 'row session=remote-one state=No window workspace=\S+ host=1 ram=512', 'row session=archived-example state=Archived workspace=\S+ host=1 ram=0')) {
    if ($frame -notmatch $pattern) { throw "Missing painted row fields $pattern" }
}
$result.checks += @{ name = 'row-fields'; passed = $true; evidence = 'all-tab.txt' }
All-Step 'server-key-on' { Press @(0x53) 'S: selected server' } @('view tab=200 host=0 visible=3')
All-Step 'server-key-off' { Press @(0x53) 'S: clear server filter' } @('view tab=200 host=255 visible=6')
$result.checks += @{ name = 'server-key'; passed = $true; evidence = 'server-key-on.txt, server-key-off.txt' }
Press @(0x51) 'Q: close All sessions'
All-Step 'server-palette' { Palette 'all sessions filter server' '6315'; Press @(0x0D) 'Enter: selected chat server' } @('view tab=200 host=2 visible=1', 'row session=second state=Running')
$result.checks += @{ name = 'server-palette'; passed = $true; evidence = 'server-palette.txt' }
All-Step 'server-palette-clear' { Press @(0x53) 'S: clear palette server filter' } @('view tab=200 host=255 visible=6')
All-Step 'move-down' { Press @(0x4A) 'J: next row' } @('view tab=200 host=255 visible=6 selected=1')
All-Step 'move-up' { Press @(0x4B) 'K: previous row' } @('view tab=200 host=255 visible=6 selected=0')
All-Step 'tab-next' { Press @(0x4C) 'L: next tab' } @('view tab=204 host=255 visible=3')
All-Step 'tab-previous' { Press @(0x48) 'H: previous tab' } @('view tab=200 host=255 visible=6')
All-Step 'waiting' { Press @(0x57) 'W: Waiting tab' } @('view tab=202 host=255 visible=0')
All-Step 'unattached' { Press @(0x55) 'U: No window tab' } @('view tab=205 host=255 visible=2')
All-Step 'marked' { Press @(0x20) 'Space: mark unattached session' } @('view tab=205 host=255 visible=2 selected=0 marks=1')
All-Step 'clear-marks' {
    $match = [regex]::Match((All-Frame), 'footer_y=(\d+)')
    Doctor; Wait-Foreground; Record 'Click Clear marks'
    [VerifyNative]::ClickClient($script:window, 336, [int]$match.Groups[1].Value)
} @('view tab=205 host=255 visible=2 selected=0 marks=0')
Press @(0x58) 'X: close selected unattached session'
Wait-Until { (Read-SharedText $log) -match 'all-sessions close-confirm count=1' } 'close confirmation'
Snapshot 'close-confirm'
Press @(0x1B) 'Esc: cancel close'
Wait-Until { (Read-SharedText $log) -match 'all-sessions close-cancelled' } 'close canceled'
if (Test-Path (Join-Path $env:MP_VERIFY_STATE 'closed-spare')) { throw 'Canceled close ended spare' }
All-Step 'all-before-search' { All-Click 'tab id=200 count=6' } @('view tab=200 host=255 visible=6')
All-Step 'search' { Press @(0x11,0x46) 'Ctrl+F: search'; Type-Text 'Second' } @('view tab=200 host=255 visible=1', 'row session=second state=Running')
Press @(0x0D) 'Enter: open Second'
Wait-Until { $s = Read-Session; $s -and $s.tabs[$s.active_tab].tmux_session -eq 'second' } 'selected session opened'
Snapshot 'opened'
All-Step 'search-again' { Palette 'show all sessions' '6290'; Press @(0x0D) 'Enter: reopen list'; Press @(0x11,0x46) 'Ctrl+F'; Type-Text 'spare' } @('row session=spare state=No window', 'visible=1')
All-Step 'search-cancel' { Press @(0x1B) 'Esc: clear search' } @('view tab=200 host=255 visible=6')
All-Step 'archive-action' { All-Row 'spare' 'archive' } @('row session=spare state=Archived', 'archived=2')
Wait-Until {
    $archive = Get-Content (Join-Path $scratch 'roaming/ZigShell/archive.json') -Raw | ConvertFrom-Json
    @($archive | Where-Object { $_.tmux_session -eq 'spare' -and $_.host -eq 0 }).Count -eq 1 -and (Test-Path (Join-Path $env:MP_VERIFY_STATE 'closed-spare'))
} 'Archive action persisted identity and reached SSH end boundary'
All-Step 'unattached-after-archive' { Press @(0x55) 'U: remaining unattached session' } @('view tab=205 host=255 visible=1', 'row session=remote-one state=No window')
Press @(0x20) 'Space: mark remaining session'
All-Step 'close-marked-confirm' {
    $match = [regex]::Match((All-Frame), 'footer_y=(\d+)')
    Doctor; Wait-Foreground; Record 'Click Close marked'
    [VerifyNative]::ClickClient($script:window, 224, [int]$match.Groups[1].Value)
} @('marks=1')
Snapshot 'close-marked'
Press @(0x0D) 'Enter: confirm Close marked'
Wait-Until { Test-Path (Join-Path $env:MP_VERIFY_STATE 'closed-remote-one') } 'Close marked reached SSH end boundary'
All-Step 'after' { All-Click 'tab id=200 count=5' } @('view tab=200 host=255 visible=5', 'running=3 servers=2 archived=2')
$result.checks += @{ name = 'existing-actions'; passed = $true; evidence = 'move-down, move-up, tab-next, tab-previous, waiting, unattached, marked, clear-marks, close-confirm, search, opened, archive-action, close-marked, after'; persistedArchive = 'spare'; ended = 'remote-one' }
Press @(0x1B) 'Esc: close All sessions'
