[void](Wait-For 'reaction transcript loaded' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
Bind-Transcript
Type-Composer $plan.text
$bounds = $views[0].Current.BoundingRectangle
Save @{left=[int]$bounds.Left; top=[int]$bounds.Top; right=[int]$bounds.Right; bottom=[int]$bounds.Bottom} "$caseDir/area.json"
$point = Wait-For 'two painted same-prefix replies' {
    Shot 'reactions-before'
    $located = & node "$PSScriptRoot/../chat-reactions-proof.mjs" $Evidence --locate 2> "$caseDir/oracle-locate-stderr.log"
    if ($LASTEXITCODE -eq 0) { ($located -join "`n") | ConvertFrom-Json }
}
$menuStart = (Read-Shared "$settings/debug.log").Length
Doctor
$actions.Add(@{case=$plan.name; input='real right-click first same-prefix reply'; x=$point.x; y=$point.y})
[ChatDeliveryDesktop]::RightClickOwnedTranscript($main, $app.Id, [IntPtr]$views[0].Current.NativeWindowHandle, $point.x, $point.y)
$menu = Wait-For 'owned reaction menu logged' {
    $tail = (Read-Shared "$settings/debug.log").Substring($menuStart)
    $matches = [regex]::Matches($tail, '\[chat\] message menu items=([^\r\n]+)')
    if ($matches.Count) { $matches[$matches.Count - 1].Groups[1].Value }
} 5
$up = [char]::ConvertFromUtf32(0x1f44d)
$down = [char]::ConvertFromUtf32(0x1f44e)
$heart = [string][char]0x2764 + [char]0xfe0f
if ($menu -cne "React $up,React $down,React $heart,Reply,Copy") { throw "IGSH975_REACTIONS_MISSING: $menu" }
$popup = Wait-For 'owned native reaction popup visible' { $h = [ChatDeliveryDesktop]::Menu($app.Id); if ($h -ne [IntPtr]::Zero) { $h } } 5
Shot 'reactions-menu'
$firstItem = [ChatDeliveryDesktop]::FirstMenuItem($popup, $app.Id, 5)
Save @{count=5; left=$firstItem.Left; top=$firstItem.Top; right=$firstItem.Right; bottom=$firstItem.Bottom} "$caseDir/menu-item.json"
$actions.Add(@{case=$plan.name; input='real mouse click first native reaction menu item'})
[ChatDeliveryDesktop]::PressOwnedMenu($main, $app.Id, $popup, 5)
[void](Wait-For 'one reaction reached the real send queue' { @((Fake-State).queue).Count -eq 1 })
$observation.composerText = [ChatDeliveryDesktop]::Text($composer)
if ($observation.composerText -cne $plan.text) { throw 'Reaction cleared the composer draft' }
[void](Wait-For 'pending badge without another bubble' {
    Shot 'reactions-pending'
    & node "$PSScriptRoot/../chat-reactions-proof.mjs" $Evidence --frame pending 2> "$caseDir/oracle-pending-stderr.log"
    $LASTEXITCODE -eq 0
})
Shell-Run @('idle')
[void](Wait-For 'delivered badge without another bubble' {
    Shot 'reactions-delivered'
    & node "$PSScriptRoot/../chat-reactions-proof.mjs" $Evidence --frame delivered 2> "$caseDir/oracle-delivered-stderr.log"
    $LASTEXITCODE -eq 0
})
Restart-OwnedApp
$restoredComposer = [ChatDeliveryDesktop]::Composer($main)
if ($restoredComposer -eq [IntPtr]::Zero) {
    Press @(0x12, 0x43) 'Alt+C: restore Chat View'
} else {
    Doctor
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Restart composer click requires owned foreground app' }
    $actions.Add(@{case=$plan.name; input='real mouse click owned composer after restart'})
    [ChatDeliveryDesktop]::PressClient($restoredComposer, $app.Id, 8, 8)
}
Bind-Transcript
$observation.restartComposerText = [ChatDeliveryDesktop]::Text($composer)
if ($observation.restartComposerText -cne $plan.text) { throw 'Restart lost the untouched composer draft' }
[void](Wait-For 'restart badge on the same first reply' {
    Shot 'reactions-restart'
    & node "$PSScriptRoot/../chat-reactions-proof.mjs" $Evidence --frame restart 2> "$caseDir/oracle-restart-stderr.log"
    $LASTEXITCODE -eq 0
})
Shell-Run @('reaction-fallback')
[void](Wait-For 'unmatched reaction stays an ordinary bubble' {
    Shot 'reactions-fallback'
    & node "$PSScriptRoot/../chat-reactions-proof.mjs" $Evidence --frame fallback 2> "$caseDir/oracle-fallback-stderr.log"
    $LASTEXITCODE -eq 0
})
[void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
