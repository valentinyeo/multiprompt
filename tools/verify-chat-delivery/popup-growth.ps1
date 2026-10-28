[void](Wait-For 'popup growth transcript loaded' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
Bind-Transcript
Type-Composer $plan.text
$bounds = $views[0].Current.BoundingRectangle
Save @{left=[int]$bounds.Left; top=[int]$bounds.Top; right=[int]$bounds.Right; bottom=[int]$bounds.Bottom} "$caseDir/area.json"
$point = Wait-For 'two painted popup growth replies' {
    Shot 'popup-growth-before'
    $ErrorActionPreference = 'Continue'
    $located = & node "$PSScriptRoot/../chat-popup-growth-proof.mjs" $Evidence --locate 2> "$caseDir/oracle-locate-stderr.log"
    if ($LASTEXITCODE -eq 0) { ($located -join "`n") | ConvertFrom-Json }
}
Doctor $true
Copy-Item "$caseDir/doctor.json" "$caseDir/menu-doctor.json"
$menuStart = (Read-Shared "$settings/debug.log").Length
$actions.Add(@{case=$plan.name; input='real right-click second same-prefix reply'; x=$point.x; y=$point.y})
[ChatDeliveryDesktop]::RightClickOwnedTranscript($main, $app.Id, [IntPtr]$views[0].Current.NativeWindowHandle, $point.x, $point.y)
$menu = Wait-For 'popup growth reaction menu logged' {
    $tail = (Read-Shared "$settings/debug.log").Substring($menuStart)
    $rows = [regex]::Matches($tail, '\[chat\] message menu items=([^\r\n]+)')
    if ($rows.Count) { $rows[$rows.Count - 1].Groups[1].Value }
} 5
$up = [char]::ConvertFromUtf32(0x1f44d)
$down = [char]::ConvertFromUtf32(0x1f44e)
$heart = [string][char]0x2764 + [char]0xfe0f
if ($menu -cne "React $up,React $down,React $heart,Reply,Copy") { throw "IGSH975_REACTIONS_MISSING: $menu" }
$popup = Wait-For 'owned popup remains visible before growth' {
    $h = [ChatDeliveryDesktop]::CombinedMenu($app.Id)
    if ($h -eq [IntPtr]::Zero) { $h = [ChatDeliveryDesktop]::Menu($app.Id) }
    if ($h -ne [IntPtr]::Zero) { $h }
} 5
$combinedPopup = [ChatDeliveryDesktop]::Class($popup) -eq 'MultipromptMessageMenu'
if ($combinedPopup) { [void][ChatDeliveryDesktop]::CombinedMenuRect($popup, $app.Id) } else { [void][ChatDeliveryDesktop]::FirstMenuItem($popup, $app.Id, 5) }
$popupElement = [System.Windows.Automation.AutomationElement]::FromHandle($popup)
$popupBounds = $popupElement.Current.BoundingRectangle
Save @{left=[int]$popupBounds.Left; top=[int]$popupBounds.Top; right=[int]$popupBounds.Right; bottom=[int]$popupBounds.Bottom} "$caseDir/menu.json"
$observation.popupBefore = $popup.ToInt64()
$observation.menuOwnerPid = $app.Id
$observation.menuOpenedMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
Shot 'popup-growth-menu'
$actions.Add(@{case=$plan.name; input='earlier reply gains fenced code while owned native popup stays open'; hwnd=$popup.ToInt64()})
Shell-Run @('reaction-grow')
[void](Wait-For 'earlier reply repainted while the same popup stays open' {
    $currentPopup = if ($combinedPopup) { [ChatDeliveryDesktop]::CombinedMenu($app.Id) } else { [ChatDeliveryDesktop]::Menu($app.Id) }
    if ($currentPopup -ne $popup) { throw 'Original popup closed before the history update' }
    Shot 'popup-growth-grown'
    $ErrorActionPreference = 'Continue'
    & node "$PSScriptRoot/../chat-popup-growth-proof.mjs" $Evidence --growth 2> "$caseDir/oracle-growth-stderr.log"
    $LASTEXITCODE -eq 0
})
$afterPopup = if ($combinedPopup) { [ChatDeliveryDesktop]::CombinedMenu($app.Id) } else { [ChatDeliveryDesktop]::Menu($app.Id) }
$observation.popupAfter = $afterPopup.ToInt64()
if ($observation.popupAfter -ne $observation.popupBefore) { throw 'Original popup changed during history growth' }
$observation.growthPaintedMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$observation.menuClickMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$actions.Add(@{case=$plan.name; input='real click original popup reaction after earlier reply repainted'; hwnd=$popup.ToInt64()})
if ($combinedPopup) { [ChatDeliveryDesktop]::PressCombinedMenu($main, $app.Id, $popup, 28, 28) } else { [ChatDeliveryDesktop]::PressOwnedMenu($main, $app.Id, $popup, 5) }
[void](Wait-For 'one popup reaction reached the real queue' { @((Fake-State).queue).Count -eq 1 })
$prefix = 'Same first words ' + ('for this example ' * 8)
$expected = "$up to: " + $prefix.Trim().Substring(0, 80) + ' [mp:983056b4a6c7ffef]'
$actual = @((Fake-State).queue)[0]
$observation.reactionText = $actual
if ($actual -cne $expected) { throw "IGSH975_POPUP_TARGET_MOVED: $actual" }
$observation.composerText = [ChatDeliveryDesktop]::Text($composer)
if ($observation.composerText -cne $plan.text) { throw 'Popup reaction cleared the draft' }
[void](Wait-For 'pending badge stays on the second reply after earlier code growth' {
    Shot 'popup-growth-pending'
    $ErrorActionPreference = 'Continue'
    & node "$PSScriptRoot/../chat-popup-growth-proof.mjs" $Evidence --frame pending 2> "$caseDir/oracle-pending-stderr.log"
    $LASTEXITCODE -eq 0
})
Shell-Run @('idle')
[void](Wait-For 'delivered badge stays on the second reply' {
    Shot 'popup-growth-delivered'
    $ErrorActionPreference = 'Continue'
    & node "$PSScriptRoot/../chat-popup-growth-proof.mjs" $Evidence --frame delivered 2> "$caseDir/oracle-delivered-stderr.log"
    $LASTEXITCODE -eq 0
})
Restart-OwnedApp
$restoredComposer = [ChatDeliveryDesktop]::Composer($main)
if ($restoredComposer -eq [IntPtr]::Zero) {
    Press @(0x12, 0x43) 'Alt+C: restore Chat View'
} else {
    Doctor
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Restart composer click requires owned foreground app' }
    $actions.Add(@{case=$plan.name; input='real mouse click owned composer after popup restart'})
    [ChatDeliveryDesktop]::PressClient($restoredComposer, $app.Id, 8, 8)
}
Bind-Transcript
$observation.restartComposerText = [ChatDeliveryDesktop]::Text($composer)
if ($observation.restartComposerText -cne $plan.text) { throw 'Popup restart lost the untouched draft' }
[void](Wait-For 'restarted badge remains on the same second reply' {
    Shot 'popup-growth-restart'
    $ErrorActionPreference = 'Continue'
    & node "$PSScriptRoot/../chat-popup-growth-proof.mjs" $Evidence --frame restart 2> "$caseDir/oracle-restart-stderr.log"
    $LASTEXITCODE -eq 0
})
[void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
