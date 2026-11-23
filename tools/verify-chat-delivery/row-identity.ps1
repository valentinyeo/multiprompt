[void](Wait-For 'hosted identity provider ready' { (Read-Shared "$state/row-identity-agent.jsonl") -match '"event": "init"' } 60)
[void](Wait-For 'initial history loaded' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
Bind-Transcript
function Copy-IdentityRows([string]$Name) {
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x4B) 'Ctrl+K: select rendered conversation'
    [void](Wait-For 'identity copy palette ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    $query = 'chat view select all'
    foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
    [void](Wait-For 'identity select-all selected' { (Read-Shared "$settings/debug.log").Substring($offset) -match ('\[palette\] ready chars=' + $query.Length + ' count=\d+ target=6364(?:\s|$)') })
    Press @(0x0D) 'Enter: select rendered conversation'
    Press @(0x11, 0x43) 'Ctrl+C: copy ordered rendered rows'
    $copied = [Windows.Forms.Clipboard]::GetText()
    [IO.File]::WriteAllText("$caseDir/$Name.txt", $copied)
    Press @(0x1B) 'Esc: clear selection'
    Shot "identity-$Name"
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
    return $copied
}
function Refresh-IdentityRows {
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x4B) 'Ctrl+K: open chat menu for refresh'
    [void](Wait-For 'identity menu palette ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    $query = 'more menu'
    foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
    [void](Wait-For 'identity more menu selected' { (Read-Shared "$settings/debug.log").Substring($offset) -match ('\[palette\] ready chars=' + $query.Length + ' count=1 target=6466') })
    Press @(0x0D) 'Enter: open chat menu'
    $rect = Wait-For 'painted refresh row' {
        $rows = [regex]::Matches((Read-Shared "$settings/debug.log").Substring($offset), '\[chat\] menu resync rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)')
        if ($rows.Count) { $rows[$rows.Count - 1].Groups }
    }
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($main)
    $condition = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'MultiPromptMoreMenu')
    $menus = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen -and $_.Current.ProcessId -eq $app.Id })
    if ($menus.Count -ne 1) { throw 'Expected one owned visible chat menu' }
    $x = [int](([int]$rect[1].Value + [int]$rect[3].Value) / 2)
    $y = [int](([int]$rect[2].Value + [int]$rect[4].Value) / 2)
    Doctor
    $actions.Add(@{case=$plan.name; input='real mouse click Resync chat'; x=$x; y=$y})
    [ChatDeliveryDesktop]::PressClient([IntPtr]$menus[0].Current.NativeWindowHandle, $app.Id, $x, $y)
    [void](Wait-For 'identity refresh completed' { (Read-Shared "$settings/debug.log").Substring($offset).Contains('[chat] resync completed') } 30)
    $script:composer = [ChatDeliveryDesktop]::Composer($main)
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
}
foreach ($index in 1..2) {
    $text = "Identity prompt $index"
    Type-Composer $text
    if ([ChatDeliveryDesktop]::Text($composer) -cne $text) { throw 'Identity composer mismatch' }
    Press @(0x0D) 'Enter: send hosted identity prompt' $true
    [void](Wait-For 'provider received exactly this prompt' { (Read-Shared "$state/row-identity-agent.jsonl").Contains('"text": "' + $text + '"') } 60)
    [void](Copy-IdentityRows "pending-$index")
    [IO.File]::WriteAllText("$state/identity-release-$index", '')
    [void](Wait-For 'provider wrote reply' { (Read-Shared "$state/row-identity-agent.jsonl").Contains('"answer": "Identity answer ' + $index + '"') } 30)
    [void](Wait-For 'reply rendered in the owned chat' { (Copy-IdentityRows "reconciled-$index").Contains("Identity answer $index") } 30)
    Refresh-IdentityRows
    [void](Copy-IdentityRows "refreshed-$index")
}
$observation.endMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
