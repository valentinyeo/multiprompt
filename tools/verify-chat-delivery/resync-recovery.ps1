. "$PSScriptRoot/recovery-palette.ps1"
. "$PSScriptRoot/recovery-palette-test.ps1"
[void](Wait-For 'initial transcript loaded' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
Bind-Transcript
Type-Composer $plan.text
$observation.draftBefore = [ChatDeliveryDesktop]::Text($composer)
function Recovery-Snapshot([string]$Name) {
    $output = & $env:MP_VERIFY_PYTHON $env:MP_VERIFY_BOUNDARY shell recovery-snapshot
    if ($LASTEXITCODE -ne 0) { throw "Recovery snapshot $Name failed" }
    [IO.File]::WriteAllText("$caseDir/$Name.json", ($output -join "`n"), [Text.UTF8Encoding]::new($false))
}
function Recovery-Click([string]$phase) {
$offset = (Read-Shared "$settings/debug.log").Length
Press @(0x11, 0x4B) 'Ctrl+K: open existing chat menu'
[void](Wait-For 'menu palette ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
$query = 'more menu'
foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
[void](Wait-For 'more menu command selected' { Test-RecoveryPaletteSelection ((Read-Shared "$settings/debug.log").Substring($offset)) $query.Length 6466 })
Press @(0x0D) 'Enter: open More Menu'
Shot "recovery-menu-$phase"
$menuRect = Wait-For 'actual painted Resync menu row' {
    $rows = [regex]::Matches((Read-Shared "$settings/debug.log").Substring($offset), '\[chat\] menu resync rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)')
    if ($rows.Count) { $rows[$rows.Count - 1].Groups }
}
$root = [System.Windows.Automation.AutomationElement]::FromHandle($main)
$condition = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'MultiPromptMoreMenu')
$menus = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen -and $_.Current.ProcessId -eq $app.Id })
if ($menus.Count -ne 1) { throw 'Expected one owned visible chat menu' }
$x = [int](([int]$menuRect[1].Value + [int]$menuRect[3].Value) / 2)
$y = [int](([int]$menuRect[2].Value + [int]$menuRect[4].Value) / 2)
Doctor
$actions.Add(@{case=$plan.name; input='real mouse click Resync chat'; x=$x; y=$y})
[ChatDeliveryDesktop]::PressClient([IntPtr]$menus[0].Current.NativeWindowHandle, $app.Id, $x, $y)
[void](Wait-For 'source reload completes successfully' { (Read-Shared "$settings/debug.log").Substring($offset).Contains('[chat] resync completed') } 30)

}
function Recovery-Copy([bool]$LoadOlder = $true) {
    if ($LoadOlder) { [void](Wait-For 'older recovered head reaches app cache' {
        $cache = @(Get-ChildItem "$settings/chatcache/*.jsonl" -ErrorAction SilentlyContinue | Where-Object { (Read-Shared $_.FullName).Contains('RECOVERY_HEAD_') })
        if ($cache.Count -gt 0) { return $true }
        [ChatDeliveryDesktop]::WheelOwnedTranscriptMessage($main, $app.Id, [IntPtr]$views[0].Current.NativeWindowHandle, 30000)
        $false
    } 60) }
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x4B) 'Ctrl+K: inspect recovered rendered text'
    [void](Wait-For 'copy palette ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    $query = 'chat view select all'
    foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
    [void](Wait-For 'select-all command ready' { Test-RecoveryPaletteSelection ((Read-Shared "$settings/debug.log").Substring($offset)) $query.Length 6364 })
    Press @(0x0D) 'Enter: select rendered messages'
    Press @(0x11, 0x43) 'Ctrl+C: copy rendered messages'
    [Windows.Forms.Clipboard]::GetText()
}
[void](Wait-For 'pending rows rendered before receipt append' { $q = [string](Queue-View); $q.Contains('queued:PENDING_ONE') -and $q.Contains('queued:PENDING_TWO') -and $q.Contains('queued:ACCEPTED_FOURTH') })
Recovery-Snapshot 'before'
Copy-Item "$settings/chat-outbox.json" "$caseDir/outbox-before.json" -Force
if ((Read-Shared "$caseDir/outbox-before.json") -ceq (Read-Shared "$caseDir/outbox-seed.json")) { throw 'App did not rewrite seeded outbox' }
$clientBefore = Get-Content "$caseDir/outbox-before.json" -Raw | ConvertFrom-Json
$serverBefore = Get-Content "$caseDir/before.json" -Raw | ConvertFrom-Json
$head = @($clientBefore.queues | Where-Object { $_.key -ceq 'tmux:0:verify-agent' } | ForEach-Object { $_.messages } | Where-Object { $_.qid -eq 0x101 })
$serverHead = @($serverBefore.rows | Where-Object { $_.key -ceq 'desktop-101' })
$observation.headUnconfirmedBefore = $head.Count -eq 1 -and $head[0].t -ceq ('RECOVERY_HEAD_'.PadRight(200, 'h') + ' ') -and $head[0].s -eq 3 -and $head[0].x -eq 1 -and $head[0].held -eq 1 -and $head[0].w -gt 0 -and $serverHead.Count -eq 1 -and $serverHead[0].state -ceq 'submitted'
if (-not $observation.headUnconfirmedBefore) { throw 'Actual desktop head is not bound to the unconfirmed server head' }
Shot 'recovery-before'
$observation.renderedBefore = Recovery-Copy $false
[IO.File]::WriteAllText("$caseDir/rendered-before.txt", $observation.renderedBefore, [Text.UTF8Encoding]::new($false))
$observation.queueBefore = [string](Queue-View)
$observation.sendStart = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
Shell-Run @('recovery-accept')
Recovery-Snapshot 'appended'
Recovery-Click 'after'
[void](Wait-For 'canonical reader claims both receipts' {
    Recovery-Snapshot 'after'
    $snap = Get-Content "$caseDir/after.json" -Raw | ConvertFrom-Json
    @($snap.rows | Where-Object { $_.state -eq 'delivered' }).Count -eq 2 -and @($snap.claims).Count -eq 2
} 60)
[void](Wait-For 'pending rows rendered after receipt recovery' { $q = [string](Queue-View); $q.Contains('queued:PENDING_ONE') -and $q.Contains('queued:PENDING_TWO') -and -not $q.Contains('queued:ACCEPTED_FOURTH') })
$observation.queueAfter = [string](Queue-View)
$observation.renderedAfter = Recovery-Copy
[void](Wait-For 'accepted desktop outbox entries settle after older history loads' {
    if (-not (Test-Path "$settings/chat-outbox.json")) { return $false }
    $box = Read-Shared "$settings/chat-outbox.json" | ConvertFrom-Json
    $ids = @($box.queues | Where-Object { $_.key -ceq 'tmux:0:verify-agent' } | ForEach-Object { $_.messages } | ForEach-Object { $_.qid })
    ($ids -notcontains 0x101) -and ($ids -notcontains 0x104) -and ($ids -contains 0x102) -and ($ids -contains 0x103)
} 60)
Copy-Item "$settings/chat-outbox.json" "$caseDir/outbox-after.json" -Force
Recovery-Snapshot 'after'
$observation.draftAfter = [ChatDeliveryDesktop]::Text($composer)
Shot 'recovery-after' 
Recovery-Click 'repeat'
$observation.renderedRepeat = Recovery-Copy
Recovery-Snapshot 'repeat'
Copy-Item "$settings/chat-outbox.json" "$caseDir/outbox-repeat.json" -Force
$observation.queueRepeat = [string](Queue-View)
$observation.draftRepeat = [ChatDeliveryDesktop]::Text($composer)
Shot 'recovery-repeat'
$observation.sendEnd = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
if ($observation.draftBefore -cne $plan.text -or $observation.draftAfter -cne $plan.text -or $observation.draftRepeat -cne $plan.text) { throw 'Recovery changed the unsent draft' }
