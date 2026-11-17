$observation.positionPassed = $false
$phases = [Collections.Generic.List[object]]::new()
$catalog = (& node "$PSScriptRoot/../journey-commands.mjs" | ConvertFrom-Json)
function Invoke-PositionCommand([string]$Name) {
    $entry = $catalog.PSObject.Properties[$Name.ToLowerInvariant()].Value
    if (-not $entry) { throw "Unknown position journey command: $Name" }
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x4B) "Ctrl+K: $Name"
    foreach ($letter in $entry.query.ToCharArray()) { [ChatDeliveryDesktop]::Character($letter) }
    [void](Wait-For "palette selected $Name" { (Read-Shared "$settings/debug.log").Substring($offset) -match ('\[palette\] ready chars=' + $entry.query.Length + ' count=\d+ target=' + $entry.target + '(?:\s|$)') } 20)
    Press @(0x0D) "Enter: $Name"
}
function Copy-PositionTranscript([string]$Name, [string]$Expected) {
    Invoke-PositionCommand 'Chat View: Select All Text'
    [Windows.Forms.Clipboard]::Clear()
    Press @(0x11, 0x43) 'Copy the actual rendered long chat'
    $copied = Wait-For 'expected reply in native transcript copy' { $text=[Windows.Forms.Clipboard]::GetText(); if ($text.Contains($Expected)) { $text } } 30
    [IO.File]::WriteAllText("$caseDir/$Name-copied.txt", $copied)
    Press @(0x1B) 'Clear transcript selection'
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
    return $copied
}
function Observe-HostedPosition([string]$Name, [string]$Policy, [scriptblock]$Action, [int]$Seconds = 3) {
    Doctor $true
    $phase = @{name=$Name; policy=$Policy; requirePaint=($Name -notlike 'idle-*'); start=[ChatDeliveryDesktop]::GetTickCount64(); end=0; shell=$script:positionShell}
    $phases.Add($phase)
    Save $phases.ToArray() "$caseDir/position-phases.json"
    & $Action
    $until = [ChatDeliveryDesktop]::GetTickCount64() + $Seconds * 1000
    [void](Wait-For "observe all paints for $Name" { [ChatDeliveryDesktop]::GetTickCount64() -ge $until } ($Seconds + 10))
    Doctor $true
    $phase.end = [ChatDeliveryDesktop]::GetTickCount64()
    Save $phases.ToArray() "$caseDir/position-phases.json"
    Shot $Name
}
Bind-Transcript
$manifest = Get-Content "$caseDir/fixture-manifest.json" -Raw | ConvertFrom-Json
if ($manifest.sessions -ne 64 -or $manifest.messagesPerLongChat -ne 2400 -or $manifest.longChats -ne 8) { throw 'The PR 1070 real-size seed is required for the jump reproduction' }
$script:positionShell = (Get-Content "$settings/session.json" -Raw | ConvertFrom-Json).tabs[0].shell_id
$open = @{name='open-hosted'; policy='stable'; start=$observation.positionOpenStart; end=0; shell=$script:positionShell}
$phases.Add($open)
Save $phases.ToArray() "$caseDir/position-phases.json"
try {
    [void](Wait-For '2400 source messages seeded into the production live archive' { (Read-Shared "$state/working-host.jsonl") -match '"stage": "idle-history-ready"' } 90)
    $until = [ChatDeliveryDesktop]::GetTickCount64() + 3000
    [void](Wait-For 'first long-chat paints observed without waiting for content-ready' { [ChatDeliveryDesktop]::GetTickCount64() -ge $until } 10)
    $open.end = [ChatDeliveryDesktop]::GetTickCount64()
    [void](Copy-PositionTranscript 'loaded' 'Synthetic chat 00 answer 1199')
    Shot 'before'
    Observe-HostedPosition 'idle-long-open' 'stable' {} 12
    Observe-HostedPosition 'scroll-old-history' 'user-scroll' { [void](Scroll-Transcript 12000) }
    $frame = @((Read-Shared "$env:MULTIPROMPT_FRAME_PROBE/frames.tsv") -split "`n" | Where-Object { $_.StartsWith("frame`t") })[-1] -split "`t"
    if ($frame[14] -ne '1') { throw 'The long-chat reader did not actually leave the bottom' }
    Observe-HostedPosition 'idle-long-reading' 'stable' {} 15
    Observe-HostedPosition 'send-while-reading' 'send' {
        [IO.File]::WriteAllText("$state/working-initial-start", '')
        Type-Composer $plan.text
        Press @(0x0D) 'Send while keeping the long-chat reader position' $true
        [void](Wait-For 'production message dispatch accepted the send' { (Read-Shared "$state/working-host.jsonl") -match '"stage": "accepted"' } 30)
    }
    Shot 'action'
    Observe-HostedPosition 'resume-reading-after-send' 'user-scroll' { [void](Scroll-Transcript 12000) }
    $frame = @((Read-Shared "$env:MULTIPROMPT_FRAME_PROBE/frames.tsv") -split "`n" | Where-Object { $_.StartsWith("frame`t") })[-1] -split "`t"
    if ($frame[14] -ne '1') { throw 'Streaming requires the reader to be above the newest messages after sending' }
    Observe-HostedPosition 'stream-while-reading' 'stable' {
        [IO.File]::WriteAllText("$state/working-reply", '')
        [void](Wait-For 'first production text.delta' { (Read-Shared "$state/working-host.jsonl") -match '"stage": "text.delta"' } 30)
        [IO.File]::WriteAllText("$state/real-size-continue", '')
        [IO.File]::WriteAllText("$state/working-steady-stream", '')
        [void](Wait-For 'eight production deltas and the final reply' { (Read-Shared "$state/working-host.jsonl") -match '"stage": "real-size-complete"' } 30)
    }
    Observe-HostedPosition 'idle-after-stream' 'stable' {} 12
    Observe-HostedPosition 'jump-to-newest' 'user-scroll' { Invoke-PositionCommand 'Jump to newest message' }
    $copied = Copy-PositionTranscript 'completed' 'Streaming segment 7.'
    if (-not $copied.Contains($plan.text)) { throw 'Native transcript did not retain the real send' }
    Shot 'after'
    & node "$PSScriptRoot/position-replay.test.cjs" $env:MULTIPROMPT_FRAME_PROBE "$caseDir/position-phases.json" "$caseDir/position-replay.json"
    if ($LASTEXITCODE -ne 0) { throw 'Real-size hosted chat moved while opening or reading; inspect every recorded paint' }
    $observation.positionPassed = $true
} finally {
    Save $phases.ToArray() "$caseDir/position-phases.json"
}
