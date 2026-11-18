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
$observation.paintWindows = @{}
$steady = $plan.name -eq 'steady-live'
if ($steady) {
    [void](Wait-For 'completed server history seeded through the production archive' { (Read-Shared "$state/working-host.jsonl") -match '"stage": "idle-history-ready"' } 30)
    [void](Wait-For 'known server history painted' { (Read-Shared "$settings/debug.log") -match '\[switch\] chat content shown shell=\d+ blocks=(?:[5-9]\d|\d{3,})(?:\s|$)' } 30)
    $idleReady = [ChatDeliveryDesktop]::GetTickCount64() + 1500
    [void](Wait-For 'server history settled before idle observation' { [ChatDeliveryDesktop]::GetTickCount64() -ge $idleReady } 5)
    $observation.paintWindows.idleStart = [ChatDeliveryDesktop]::GetTickCount64()
    $observation.paintWindows.idleStartWallMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    [void](Wait-For 'five seconds of idle server chat' { [ChatDeliveryDesktop]::GetTickCount64() -ge $observation.paintWindows.idleStart + 5000 } 10)
    $observation.paintWindows.idleEnd = [ChatDeliveryDesktop]::GetTickCount64()
    $observation.paintWindows.idleEndWallMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    Shot 'working-idle'
    [IO.File]::WriteAllText("$state/working-initial-start", '')
}
$initialPush = Wait-For 'initial live turn subscription push' { Get-WorkingTurnPush 'standin-initial-turn' } 30
[void](Scroll-Transcript -12000)
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
if ($steady) { [void](Scroll-Transcript -12000) }
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
    $observation.paintWindows.busyStart = [ChatDeliveryDesktop]::GetTickCount64()
    for ($i = 0; $clock.ElapsedMilliseconds -lt 4000; $i++) {
        Capture-Working 'busy' $i
        Start-Sleep -Milliseconds 60
    }
    $observation.paintWindows.busyEnd = [ChatDeliveryDesktop]::GetTickCount64()
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
    $observation.paintWindows.streamStart = [ChatDeliveryDesktop]::GetTickCount64()
    $replyClock = [Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $replyClock.ElapsedMilliseconds -lt 4000; $i++) {
        Capture-Working 'reply' $i
        Start-Sleep -Milliseconds 100
    }
    $observation.paintWindows.streamEnd = [ChatDeliveryDesktop]::GetTickCount64()
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
    $observation.paintWindows.queuedStart = [ChatDeliveryDesktop]::GetTickCount64()
    $queuedClock = [Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $queuedClock.ElapsedMilliseconds -lt 1600; $i++) {
        Capture-Working 'queued' $i
        Start-Sleep -Milliseconds 100
    }
    $observation.paintWindows.queuedEnd = [ChatDeliveryDesktop]::GetTickCount64()
    if ($steady) {
        [void](Scroll-Transcript 1200)
        $readingReady = [ChatDeliveryDesktop]::GetTickCount64() + 1000
        [void](Wait-For 'reader scroll settled before streamed reply' { [ChatDeliveryDesktop]::GetTickCount64() -ge $readingReady } 5)
        $observation.paintWindows.readingStart = [ChatDeliveryDesktop]::GetTickCount64()
        [IO.File]::WriteAllText("$state/working-steady-stream", '')
        $readingClock = [Diagnostics.Stopwatch]::StartNew()
        for ($i = 0; $readingClock.ElapsedMilliseconds -lt 5000; $i++) {
            Capture-Working 'reading' $i
            Start-Sleep -Milliseconds 100
        }
        $observation.paintWindows.readingEnd = [ChatDeliveryDesktop]::GetTickCount64()
        Shot 'working-reading-stream'
    }
} finally {
    $observation.sendMs = $sendMs
    $observation.frames = $frames.ToArray()
    Save $observation "$caseDir/timing.json"
}
function Copy-WorkingConversation {
    Press @(0x11, 0x4B) 'Ctrl+K: select live conversation'
    $paletteStart = (Read-Shared "$settings/debug.log").Length
    $query = 'chat view select all'
    foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
    [void](Wait-For 'select-all command ready' { (Read-Shared "$settings/debug.log").Substring($paletteStart) -match ('\[palette\] ready chars=' + $query.Length + ' count=\d+ target=6364(?:\s|$)') })
    Press @(0x0D) 'Enter: select live conversation'
    [Windows.Forms.Clipboard]::Clear()
    Press @(0x11, 0x43) 'Ctrl+C: copy live conversation'
    $copied = [Windows.Forms.Clipboard]::GetText()
    Press @(0x1B) 'Esc: clear live selection'
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
    return $copied
}
$observation.copied = Copy-WorkingConversation
if (-not $steady) {
    $reply = 'The hosted stand-in reply is visible.'
    foreach ($stage in @(@{marker='working-final'; count=1}, @{marker='working-second'; count=2})) {
        [IO.File]::WriteAllText("$state/$($stage.marker)", '')
        [void](Wait-For 'provider saved the final reply' { (Read-Shared "$state/working-host.jsonl").Contains('"stage": "' + $stage.marker + '"') } 30)
        [void](Wait-For 'final reply reached the app history cache' {
            @(Get-ChildItem "$settings/chatcache" -Filter '*.jsonl' -ErrorAction SilentlyContinue | Where-Object {
                $content = Read-Shared $_.FullName
                $content.Contains('Final reply') -and ([regex]::Matches($content, [regex]::Escape($reply))).Count -eq $stage.count
            }).Count -gt 0
        } 60)
        $copied = Wait-For 'final reply is visible in the conversation' {
            $value = Copy-WorkingConversation
            if (([regex]::Matches($value, 'Final reply')).Count -ge $stage.count) { return $value }
        } 30
        $observation[$stage.marker] = $copied
        Shot $stage.marker
        if (([regex]::Matches($copied, [regex]::Escape($reply))).Count -ne $stage.count -or ([regex]::Matches($copied, 'Final reply')).Count -ne $stage.count) { throw 'Live and history copies must merge by identity without hiding identical real replies' }
    }
}
