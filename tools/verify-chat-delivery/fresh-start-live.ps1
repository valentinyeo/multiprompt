function Working-Rows {
    if (-not (Test-Path "$state/working-host.jsonl")) { return @() }
    @((Read-Shared "$state/working-host.jsonl") -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
}
function Working-Stage([string]$Stage) {
    @(Working-Rows | Where-Object { $_.stage -eq $Stage })
}
function Copy-Rendered([string]$Name) {
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x4B) 'Ctrl+K: select the rendered conversation'
    [void](Wait-For 'select-all palette ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    $query = 'chat view select all'
    foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
    [void](Wait-For 'select-all command ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match ('\[palette\] ready chars=' + $query.Length + ' count=[1-9]\d* target=\d+') })
    Press @(0x0D) 'Enter: select the rendered conversation'
    [void](Wait-For 'the rendered conversation is selected' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[confirm\] sel=0 count=1 target=\d+' })
    $settle = [ChatDeliveryDesktop]::GetTickCount64() + 400
    [void](Wait-For 'the rendered selection settles before the copy' { [ChatDeliveryDesktop]::GetTickCount64() -ge $settle } 5)
    [Windows.Forms.Clipboard]::Clear()
    Press @(0x11, 0x43) 'Ctrl+C: copy the rendered conversation'
    $copied = [Windows.Forms.Clipboard]::GetText()
    [IO.File]::WriteAllText("$caseDir/$Name-copied.txt", $copied)
    Press @(0x1B) 'Esc: clear the selection'
    [void](Wait-For 'the selection returns typing focus' { $f = [ChatDeliveryDesktop]::Focus($main); $f[0] -eq $main.ToInt64() -and $f[1] -eq $composer.ToInt64() })
    return $copied
}
[void](Wait-For 'production live subscription' { (Read-Shared "$state/working-host.jsonl") -match '"stage": "subscribed"' } 30)
[void](Wait-For 'saved history served as the chat display' { (Read-Shared "$state/working-host.jsonl") -match '"stage": "fresh-history-ready"' } 30)
Bind-Transcript
[void](Scroll-Transcript -12000)
$bounds = $views[0].Current.BoundingRectangle
Save @{left=0; top=0; right=[int]$bounds.Width; bottom=[int]$bounds.Height} "$caseDir/area.json"
$freshQuery = 'fresh start'
$freshOffset = (Read-Shared "$settings/debug.log").Length
Press @(0x11, 0x4B) 'Ctrl+K: open the command palette'
[void](Wait-For 'palette ready for the fresh start row' { (Read-Shared "$settings/debug.log").Substring($freshOffset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
foreach ($letter in $freshQuery.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
[void](Wait-For 'fresh start offered by the real palette' { (Read-Shared "$settings/debug.log").Substring($freshOffset) -match ('\[palette\] ready chars=' + $freshQuery.Length + ' count=[1-9]\d* target=6498(?:\s|$)') })
Press @(0x0D) 'Enter: press Fresh start'
[void](Wait-For 'fresh start requested from the real menu' { @(Working-Stage 'fresh-start-requested').Count -ge 1 } 20)
[void](Wait-For 'fresh start reload is pending' { @(Working-Stage 'fresh-start-pending').Count -ge 1 } 20)
$observation.dots = $null
for ($i = 0; $i -lt 20 -and -not $observation.dots; $i++) {
    $name = 'fresh-busy-{0:D2}' -f $i
    $bitmap = [Drawing.Bitmap]::new([int]$bounds.Width, [int]$bounds.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen([int]$bounds.Left, [int]$bounds.Top, 0, 0, $bitmap.Size); $bitmap.Save("$caseDir/$name.bmp", [Drawing.Imaging.ImageFormat]::Bmp) } finally { $graphics.Dispose(); $bitmap.Dispose() }
    & node "$PSScriptRoot/../chat-working-proof.mjs" "$caseDir/$name.bmp" "$caseDir/area.json" "$caseDir/$name.json" busy 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { $observation.dots = $name }
    Start-Sleep -Milliseconds 100
}
if (-not $observation.dots) { throw 'Fresh start never showed the reloading dots' }
Shot 'fresh-start-pending'
[void](Wait-For 'the reloading reply reaches the live subscription' {
    foreach ($line in ((Read-Shared "$state/working-host.jsonl") -split "`n")) {
        if (-not $line.Trim()) { continue }
        $row = $line | ConvertFrom-Json
        if ($row.stage -ne 'pushed') { continue }
        foreach ($entry in $row.events) {
            if ($entry.event.PSObject.Properties['kind'] -and $entry.event.kind -eq 'text.delta') { return $true }
        }
    }
} 30)
[void](Scroll-Transcript -12000)
$liveCopy = $null
for ($liveTry = 0; $liveTry -lt 6 -and -not $liveCopy; $liveTry++) {
    if (@(Working-Stage 'fresh-start-finished').Count -gt 0) { throw 'The reloading reply only appeared after the reload finished' }
    $copy = Copy-Rendered 'fresh-live'
    if ($copy -and $copy.Contains('The handover is reloaded')) { $liveCopy = $copy }
}
if (-not $liveCopy) { throw 'The reloading reply was not painted live' }
$observation.liveReply = $true
Type-Composer $plan.text
if ([ChatDeliveryDesktop]::Text($composer) -cne $plan.text) { throw 'Composer text mismatch during the reload' }
Press @(0x0D) 'Enter: send during the reload' $true
[void](Wait-For 'the chat held the message instead of refusing it' { @(Working-Stage 'deliver-held' | Where-Object { $_.text -ceq $plan.text }).Count -ge 1 } 20)
[void](Wait-For 'the message is waiting, not failed' {
    if (-not (Test-Path "$settings/chat-outbox.json")) { return $false }
    $outbox = Read-Shared "$settings/chat-outbox.json" | ConvertFrom-Json
    $held = @($outbox.queues | ForEach-Object { $_.messages } | Where-Object { $_.t -ceq $plan.text })
    return $held.Count -eq 1 -and $held[0].v1 -eq 1 -and $held[0].s -ne 2 -and $held[0].phase -cne 'failed'
} 20)
Copy-Item "$settings/chat-outbox.json" "$caseDir/outbox-held.json"
Shot 'fresh-message-waiting'
$observation.held = $true
$sentAt = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
[void](Wait-For 'the message waits out a watchdog-length reload' {
    if (@(Working-Stage 'fresh-start-finished').Count -gt 0) { throw 'The reload finished before the waiting window elapsed' }
    if (-not (Test-Path "$settings/chat-outbox.json")) { return $false }
    $outbox = Read-Shared "$settings/chat-outbox.json" | ConvertFrom-Json
    $waiting = @($outbox.queues | ForEach-Object { $_.messages } | Where-Object { $_.t -ceq $plan.text })
    if ($waiting.Count -ne 1 -or $waiting[0].s -eq 2 -or $waiting[0].phase -ceq 'failed') { throw 'The waiting message was marked Not sent during the reload' }
    return ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - $sentAt) -ge 105000
} 140)
$observation.pendingMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - $sentAt
[IO.File]::WriteAllText("$state/working-resume-done", '')
[void](Wait-For 'the reload finished' { @(Working-Stage 'fresh-start-finished').Count -ge 1 } 60)
[void](Wait-For 'the waiting message reached the chat exactly once' {
    $delivered = @(Working-Stage 'deliver' | Where-Object { $_.text -ceq $plan.text })
    return $delivered.Count -eq 1
} 60)
Start-Sleep -Milliseconds 500
if (@(Working-Stage 'deliver' | Where-Object { $_.text -ceq $plan.text }).Count -ne 1) { throw 'The message was delivered more than once' }
[IO.File]::WriteAllText("$state/working-reply", '')
[void](Wait-For 'the chat answered the waiting message' { (Read-Shared "$state/working-host.jsonl") -match '"stage": "text.delta"' } 30)
[void](Wait-For 'the accepted message left the waiting list' {
    if (-not (Test-Path "$settings/chat-outbox.json")) { return $true }
    $outbox = Read-Shared "$settings/chat-outbox.json" | ConvertFrom-Json
    return @($outbox.queues | ForEach-Object { $_.messages } | Where-Object { $_.t -ceq $plan.text }).Count -eq 0
} 30)
Start-Sleep -Milliseconds 800
[void](Scroll-Transcript -12000)
$finalCopy = $null
for ($finalTry = 0; $finalTry -lt 4 -and -not $finalCopy; $finalTry++) {
    $copy = Copy-Rendered 'fresh-final'
    if ($copy -and $copy.Contains($plan.text)) { $finalCopy = $copy }
}
if (-not $finalCopy) { throw 'The message sent during the reload must appear exactly once' }
if ([regex]::Matches($finalCopy, [regex]::Escape($plan.text)).Count -ne 1) { throw 'The message sent during the reload must appear exactly once' }
if (-not $finalCopy.Contains('The handover is reloaded')) { throw 'The reloading reply left the conversation' }
Shot 'fresh-message-arrived'
$observation.sent = $plan.text
$observation.deliveredOnce = $true
$observation.endMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
