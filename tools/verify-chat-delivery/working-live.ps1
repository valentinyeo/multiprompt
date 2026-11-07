[void](Wait-For 'production live subscription' { (Read-Shared "$state/working-host.jsonl") -match '"stage": "subscribed"' } 30)
Bind-Transcript
$bounds = $views[0].Current.BoundingRectangle
$area = @{left=0; top=0; right=[int]$bounds.Width; bottom=[int]$bounds.Height}
Save $area "$caseDir/area.json"
function Get-WorkingTurnPush([string]$turn) {
    foreach ($line in ((Read-Shared "$state/working-host.jsonl") -split "`n")) {
        if (-not $line.Trim()) { continue }
        $row = $line | ConvertFrom-Json
        if ($row.stage -ne 'pushed') { continue }
        foreach ($entry in $row.events) {
            if ($entry.event.PSObject.Properties['kind'] -and $entry.event.kind -eq 'turn.started' -and $entry.event.turn -eq $turn) { return $row }
        }
    }
}
$initialPush = Wait-For 'initial live turn subscription push' { Get-WorkingTurnPush 'standin-initial-turn' } 30
$precondition = Wait-For 'initial live turn paints working dots before sending' {
    $bitmap = [Drawing.Bitmap]::new($area.right, $area.bottom)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $startedMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $graphics.CopyFromScreen([int]$bounds.Left, [int]$bounds.Top, 0, 0, $bitmap.Size)
        $endedMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $bitmap.Save("$caseDir/pre-send-busy.bmp", [Drawing.Imaging.ImageFormat]::Bmp)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
    & node "$PSScriptRoot/../chat-working-proof.mjs" "$caseDir/pre-send-busy.bmp" "$caseDir/area.json" "$caseDir/pre-send-busy.json" busy 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0 -and $startedMs -ge $initialPush.ms) {
        return @{turn='standin-initial-turn'; pushedMs=$initialPush.ms; captureStartMs=$startedMs; captureEndMs=$endedMs; screenshot='pre-send-busy.bmp'}
    }
} 30
Save $precondition "$caseDir/pre-send-running.json"
$observation.preSendRunning = $precondition
Type-Composer $plan.text
if ([ChatDeliveryDesktop]::Text($composer) -cne $plan.text) { throw 'Composer text mismatch' }
Doctor $true
$frames = [Collections.Generic.List[object]]::new()
$clock = [Diagnostics.Stopwatch]::StartNew()
$sendMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$actions.Add(@{case=$plan.name; ms=$sendMs; input='Enter: send composer'; keys=@(13)})
[ChatDeliveryDesktop]::Chord(@(0x0D))
function Capture-Working([string]$phase, [int]$index) {
    $bitmap = [Drawing.Bitmap]::new($area.right, $area.bottom)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $start = $clock.ElapsedMilliseconds
        $startWall = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $graphics.CopyFromScreen([int]$bounds.Left, [int]$bounds.Top, 0, 0, $bitmap.Size)
        $end = $clock.ElapsedMilliseconds
        $name = '{0}-{1:D3}.bmp' -f $phase, $index
        $bitmap.Save("$caseDir/$name", [Drawing.Imaging.ImageFormat]::Bmp)
        $frames.Add(@{name=$name; phase=$phase; startMs=$start; endMs=$end; startWallMs=$startWall})
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
try {
    for ($i = 0; $clock.ElapsedMilliseconds -lt 4000; $i++) {
        Capture-Working 'busy' $i
        Start-Sleep -Milliseconds 60
    }
    $dispatchPush = Wait-For 'dispatched live turn subscription push' { Get-WorkingTurnPush 'standin-turn' } 20
    $animationClock = [Diagnostics.Stopwatch]::StartNew()
    for (; $animationClock.ElapsedMilliseconds -lt 1600; $i++) {
        Capture-Working 'busy' $i
        Start-Sleep -Milliseconds 100
    }
    $painted = [Collections.Generic.List[object]]::new()
    foreach ($frame in $frames) {
        if ($frame.phase -ne 'busy' -or $frame.startWallMs -lt $dispatchPush.ms) { continue }
        $probe = "$caseDir/$($frame.name).json"
        & node "$PSScriptRoot/../chat-working-proof.mjs" "$caseDir/$($frame.name)" "$caseDir/area.json" $probe busy 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { $painted.Add(@{frame=$frame; dots=(Get-Content $probe -Raw | ConvertFrom-Json).dots}) }
    }
    $animated = $null
    for ($a = 0; $a -lt $painted.Count -and -not $animated; $a++) {
        for ($b = $a + 1; $b -lt $painted.Count -and -not $animated; $b++) {
            $sameColumns = $true
            $moved = $false
            for ($d = 0; $d -lt 3; $d++) {
                $first = $painted[$a].dots[$d]
                $second = $painted[$b].dots[$d]
                if ($first.left -ne $second.left -or $first.right -ne $second.right -or [Math]::Abs($first.top - $second.top) -gt 4) { $sameColumns = $false }
                if ($first.top -ne $second.top -or $first.bottom -ne $second.bottom) { $moved = $true }
            }
            if ($sameColumns -and $moved) { $animated = @($painted[$a].frame.name, $painted[$b].frame.name) }
        }
    }
    if (-not $animated) { throw 'No animated dots after dispatched turn.started push' }
    $observation.dispatchAnimation = @{pushedMs=$dispatchPush.ms; frames=$animated}
    [IO.File]::WriteAllText("$state/working-reply", '')
    [void](Wait-For 'stand-in emitted live text delta' { (Read-Shared "$state/working-host.jsonl") -match '"stage": "text.delta"' } 20)
    $replyClock = [Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $replyClock.ElapsedMilliseconds -lt 4000; $i++) {
        Capture-Working 'reply' $i
        Start-Sleep -Milliseconds 100
    }
    $observation.followups = @('First queued follow-up', 'Second queued follow-up')
    foreach ($followup in $observation.followups) {
        Type-Composer $followup
        Press @(0x0D) 'Enter: queue follow-up while the reply is still working' $true
    }
    [void](Wait-For 'both follow-up messages retained by the real message store' {
        $rows = @((Read-Shared "$state/working-host.jsonl") -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
        foreach ($row in $rows) {
            if ($row.stage -ne 'queued-followup') { continue }
            $texts = @($row.events | Where-Object { $_.event.PSObject.Properties['state'] -and $_.event.state -eq 'queued' } | ForEach-Object { $_.event.text })
            if ($observation.followups[0] -in $texts -and $observation.followups[1] -in $texts) { return $true }
        }
    } 20)
    $observation.queuedMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $queuedClock = [Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $queuedClock.ElapsedMilliseconds -lt 1600; $i++) {
        Capture-Working 'queued' $i
        Start-Sleep -Milliseconds 100
    }
} finally {
    $observation.sendMs = $sendMs
    $observation.frames = $frames.ToArray()
    Save $observation "$caseDir/timing.json"
}
Press @(0x11, 0x4B) 'Ctrl+K: select live conversation'
$paletteStart = (Read-Shared "$settings/debug.log").Length
$query = 'chat view select all'
foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
[void](Wait-For 'select-all command ready' { (Read-Shared "$settings/debug.log").Substring($paletteStart) -match ('\[palette\] ready chars=' + $query.Length + ' count=\d+ target=6364(?:\s|$)') })
Press @(0x0D) 'Enter: select live conversation'
Press @(0x11, 0x43) 'Ctrl+C: copy live conversation'
$observation.copied = [Windows.Forms.Clipboard]::GetText()
Press @(0x1B) 'Esc: clear live selection'
[void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
