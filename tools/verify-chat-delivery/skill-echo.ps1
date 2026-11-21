[void](Wait-For 'initial transcript loaded' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
Type-Composer $plan.text
if ([ChatDeliveryDesktop]::Text($composer) -cne $plan.text) { throw 'Composer text differs from the message' }
Shot "$($plan.name)-action"
Press @(0x0D) 'Enter: send the message' $true
[void](Wait-For 'source queued the sent text' {
    @((Fake-State).queue | Where-Object { $_ -ceq $observation.sentText -or $_.StartsWith($observation.sentText + "`n[mp:") }).Count -eq 1
})
Copy-Item "$settings/chat-outbox.json" "$caseDir/outbox-queued.json"
Shot "$($plan.name)-queued"
Shell-Input 'idle'
[void](Wait-For 'pending copy retired after transcript confirmation' {
    $outbox = Read-Shared "$settings/chat-outbox.json" | ConvertFrom-Json
    @($outbox.queues | ForEach-Object { $_.messages } | Where-Object { $_.t -ceq $plan.text }).Count -eq 0
})
Copy-Item "$settings/chat-outbox.json" "$caseDir/outbox-final.json"
$copied = Wait-For 'native transcript contains exactly one message' {
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x4B) 'Ctrl+K: select transcript' $true
    [void](Wait-For 'select-all palette ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    $query = 'chat view select all'
    foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
    [void](Wait-For 'select-all command ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match ('\[palette\] ready chars=' + $query.Length + ' count=[1-9]\d* target=6364(?:\s|$)') })
    Press @(0x0D) 'Enter: select transcript'
    [Windows.Forms.Clipboard]::Clear()
    Press @(0x11, 0x43) 'Ctrl+C: copy transcript'
    $text = [Windows.Forms.Clipboard]::GetText()
    Press @(0x1B) 'Esc: clear selection'
    [IO.File]::WriteAllText("$caseDir/copied.txt", $text)
    if ([regex]::Matches($text, 'make it simpler|plain message confirms once').Count -eq 1 -and $text.Contains($observation.sentText)) { $text }
} 20
$observation.copied = $copied
$observation.composerText = [ChatDeliveryDesktop]::Text($composer)
$observation.endMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
