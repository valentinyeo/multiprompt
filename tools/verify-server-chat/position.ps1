$phases = [Collections.Generic.List[object]]::new()
function Read-PositionFrame {
    $stream = [IO.File]::Open("$env:MULTIPROMPT_FRAME_PROBE/frames.tsv", 'Open', 'Read', ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    try {
        $reader = [IO.StreamReader]::new($stream)
        try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
    } finally { $stream.Dispose() }
    return @($text -split "`n" | Where-Object { $_.StartsWith("frame`t") })[-1] -split "`t"
}
$frame = Read-PositionFrame
$positionShell = [long]$frame[3]
function Observe-ServerPosition([string]$Name, [string]$Policy, [scriptblock]$Action, [int]$Seconds = 3) {
    Doctor
    $phase = @{name=$Name; policy=$Policy; requirePaint=($Policy -ne 'stable'); repro=$true; start=[ChatDeliveryDesktop]::GetTickCount64(); end=0; shell=$positionShell}
    $phases.Add($phase)
    Save $phases.ToArray() "$Evidence/position-phases.json"
    try {
        & $Action
        $until = [ChatDeliveryDesktop]::GetTickCount64() + $Seconds * 1000
        [void](Wait-For "observe the loaded long chat during $Name" {
            [Windows.Forms.Application]::DoEvents()
            [ChatDeliveryDesktop]::GetTickCount64() -ge $until
        } ($Seconds + 10))
        Doctor
        Shot $Name
    } finally {
        $phase.end = [ChatDeliveryDesktop]::GetTickCount64()
        Save $phases.ToArray() "$Evidence/position-phases.json"
    }
}
function Switch-ServerPosition([string]$Name, [IntPtr]$Peer) {
    Observe-ServerPosition $Name 'stable' {
        Press @(0x12, 0x09) 'Alt+Tab: leave the loaded long chat'
        [void](Wait-For 'the isolated peer window is foreground' {
            [Windows.Forms.Application]::DoEvents()
            [ChatDeliveryDesktop]::GetForegroundWindow() -eq $Peer -and [ChatDeliveryDesktop]::Owner($Peer) -eq $PID
        } 10)
        Shot "$Name-away"
        $until = [ChatDeliveryDesktop]::GetTickCount64() + 1000
        [void](Wait-For 'remain in the other window before returning' {
            [Windows.Forms.Application]::DoEvents()
            if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $Peer -or [ChatDeliveryDesktop]::Owner($Peer) -ne $PID) { throw 'The isolated peer lost foreground ownership' }
            [ChatDeliveryDesktop]::GetTickCount64() -ge $until
        } 10)
        $actions.Add(@{input='Alt+Tab: return to the loaded long chat'; keys=@(0x12, 0x09); at=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); from=$Peer.ToInt64(); to=$main.ToInt64()})
        [ChatDeliveryDesktop]::Chord(@(0x12, 0x09))
        [void](Wait-For 'Alt+Tab returned to the owned app without focus repair' {
            [Windows.Forms.Application]::DoEvents()
            [ChatDeliveryDesktop]::GetForegroundWindow() -eq $main
        } 10)
    }
}
$peer = [Windows.Forms.Form]::new()
try {
    $peer.Text = 'Replay peer window'
    $peer.Size = [Drawing.Size]::new(600, 400)
    $peer.StartPosition = 'Manual'
    $peer.Location = [Drawing.Point]::new(40, 80)
    $peer.Show()
    [Windows.Forms.Application]::DoEvents()
    $composer = [ChatDeliveryDesktop]::Composer($main)
    if (-not [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)) { throw 'Could not prepare the two owned windows for Alt+Tab' }
    Observe-ServerPosition 'idle-long-open' 'stable' {} 12
    Switch-ServerPosition 'activate-long-open' $peer.Handle
    Observe-ServerPosition 'scroll-old-history' 'user-scroll' {
        $handle = Transcript-Window
        $rect = [ChatDeliveryDesktop+Rect]::new()
        if (-not [ChatDeliveryDesktop]::GetWindowRect($handle, [ref]$rect)) { throw 'The transcript viewport has no native rectangle' }
        [ChatDeliveryDesktop]::WheelTranscript($main, $app.Id, $handle, [int](($rect.Left + $rect.Right) / 2), [int](($rect.Top + $rect.Bottom) / 2), 12000)
    }
    $frame = Read-PositionFrame
    if ($frame[14] -ne '1') { throw 'The real server long chat did not leave the bottom' }
    Observe-ServerPosition 'idle-long-reading' 'stable' {} 12
    Switch-ServerPosition 'activate-long-reading-1' $peer.Handle
    Switch-ServerPosition 'activate-long-reading-2' $peer.Handle
} finally {
    $peer.Dispose()
}
