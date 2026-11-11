function Recall-Events {
    @(Read-Shared "$state/recall-agent.jsonl" -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
}
function Recall-Count([string]$Event, [string]$Text, [bool]$Cancelled = $false) {
    $rows = @(Recall-Events | Where-Object { $_.event -eq $Event -and $_.text -eq $Text })
    if ($Event -eq 'cancel') { @($rows | Where-Object { $_.cancelled -eq $Cancelled -and $_.subtype -eq 'cancel_async_message' }).Count } else { $rows.Count }
}
[void](Wait-For 'hosted recall stand-in is up' { (Read-Shared "$state/recall-agent.jsonl") -match '"event":"init"' } 60)
[void](Wait-For 'initial history loaded' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
Bind-Transcript
$keep = 'recall keep one'
$menuText = 'recall menu two'
$keyText = 'recall key three'
foreach ($text in @($keep, $menuText, $keyText)) {
    Type-Composer $text
    if ([ChatDeliveryDesktop]::Text($composer) -cne $text) { throw "Composer did not take $text" }
    Press @(0x0D) 'Enter: send to the busy bot' $true
    [void](Wait-For 'composer cleared after send' { ([ChatDeliveryDesktop]::Text($composer)) -ceq '' } 15)
}
[void](Wait-For 'three messages are waiting in the outbox' {
    $raw = Read-Shared "$settings/chat-outbox.json"
    $raw.Contains($keep) -and $raw.Contains($menuText) -and $raw.Contains($keyText)
} 45)
[void](Wait-For 'bot received three messages and has not answered' {
    (Recall-Count 'user' $keep) -eq 1 -and (Recall-Count 'user' $menuText) -eq 1 -and (Recall-Count 'user' $keyText) -eq 1 -and
    @(Recall-Events | Where-Object { $_.event -eq 'answer' }).Count -eq 0
} 60)
Shot 'recall-handed-waiting'
$menu = Find-CancelMenu { param($items, $echo) $items -match 'Cancel message' -and $echo -eq 2 }
if ($null -eq $menu) { throw 'Middle handed message has no Cancel action' }
Shot 'recall-handed-menu'
[ChatDeliveryDesktop]::Type(0x4E)
[void](Wait-For 'bot confirmed the menu recall' { (Recall-Count 'cancel' $menuText $true) -eq 1 -and (Recall-Count 'answer' $menuText) -eq 0 } 20)
Copy-Item "$settings/chat-outbox.json" "$caseDir/outbox-menu.json"
[void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
[void](Wait-For 'composer focus before Up' { $f = [ChatDeliveryDesktop]::Focus($main); $f[0] -eq $main.ToInt64() -and $f[1] -eq $composer.ToInt64() } 10)
Press @(0x26) 'Up: focus the last waiting message' $true
Press @(0x2E) 'Delete: take back the focused message' $true
[void](Wait-For 'bot confirmed the keyboard recall' {
    (Recall-Count 'cancel' $keyText $true) -eq 1 -and (Recall-Count 'cancel' $keep $true) -eq 0 -and (Recall-Count 'answer' $keyText) -eq 0
} 20)
Copy-Item "$settings/chat-outbox.json" "$caseDir/outbox-keyboard.json"
Shot 'recall-handed-cancelled'
[IO.File]::WriteAllText("$state/recall-release", '1')
[void](Wait-For 'bot answered only the remaining message' {
    (Recall-Count 'answer' $keep) -eq 1 -and (Recall-Count 'answer' $menuText) -eq 0 -and (Recall-Count 'answer' $keyText) -eq 0
} 30)
Shot 'recall-handed-delivered'
$kept = Find-CancelMenu { param($items, $echo) $echo -eq 0 -and $items -notmatch 'Cancel message|React' }
if ($null -eq $kept) { throw 'Answered message still offers Cancel or could not be opened' }
[ChatDeliveryDesktop]::Type(0x1B)
Shot 'recall-handed-kept'
Copy-Item "$state/recall-agent.jsonl" "$caseDir/recall-agent.jsonl"
$observation.endMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
