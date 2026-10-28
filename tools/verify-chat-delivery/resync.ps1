[void](Wait-For 'initial transcript loaded' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
Bind-Transcript
[void](Wait-For 'waiting message visible before repair' { ([string](Queue-View)).Contains('queued:stale waiting message') })
Type-Composer $plan.text
$observation.draftBefore = [ChatDeliveryDesktop]::Text($composer)
Shot 'resync-before'
Shell-Run @('resync-rewrite')
$observation.waitingBefore = [string](Queue-View)
$observation.sendStart = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$offset = (Read-Shared "$settings/debug.log").Length
Press @(0x11, 0x4B) 'Ctrl+K: open existing chat menu'
[void](Wait-For 'menu palette ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
$query = 'more menu'
foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
[void](Wait-For 'more menu command selected' { (Read-Shared "$settings/debug.log").Substring($offset) -match ('\[palette\] ready chars=' + $query.Length + ' count=1 target=6466') })
Press @(0x0D) 'Enter: open More Menu'
Shot 'resync-menu'
foreach ($index in 1..6) { Press @(0x28) 'Down: choose Resync chat' $true }
Press @(0x0D) 'Enter: Resync chat' $true
[void](Wait-For 'source reload completes successfully' { (Read-Shared "$settings/debug.log").Substring($offset).Contains('[chat] resync completed') } 30)
[void](Wait-For 'stale waiting label removed' { -not ([string](Queue-View)).Contains('queued:stale waiting message') } 10)
$observation.waitingAfter = [string](Queue-View)
$observation.draftAfter = [ChatDeliveryDesktop]::Text($composer)
if ($observation.draftAfter -cne $observation.draftBefore -or $observation.draftAfter -cne $plan.text) { throw 'Resync changed the unsent draft' }
Shot 'resync-after'
$offset = (Read-Shared "$settings/debug.log").Length
Press @(0x11, 0x4B) 'Ctrl+K: inspect reloaded rendered text'
[void](Wait-For 'copy palette ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
$query = 'chat view select all'
foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
[void](Wait-For 'select-all command ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match ('\[palette\] ready chars=' + $query.Length + ' count=1 target=6364') })
Press @(0x0D) 'Enter: select rendered messages'
Press @(0x11, 0x43) 'Ctrl+C: copy rendered messages'
$observation.copied = [Windows.Forms.Clipboard]::GetText()
if (-not $observation.copied.Contains('After  resync') -or $observation.copied.Contains('Before resync')) { throw 'Resync did not reload the corrected source' }
$observation.sendEnd = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
