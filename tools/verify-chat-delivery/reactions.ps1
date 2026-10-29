[void](Wait-For 'reaction transcript loaded' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
Press @(0x11, 0x4B) 'Ctrl+K: open theme picker'
foreach ($letter in 'themes'.ToCharArray()) { [ChatDeliveryDesktop]::Character($letter) }
Press @(0x0D) 'Enter: Themes'
foreach ($letter in 'amoled'.ToCharArray()) { [ChatDeliveryDesktop]::Character($letter) }
Press @(0x0D) 'Enter: AMOLED'
[void](Wait-For 'app saved AMOLED theme' { (Read-Shared "$settings/theme-mode.txt").Trim() -eq 'amoled' })
Press @(0x1B) 'Esc: close Themes'
Bind-Transcript
Type-Composer $plan.text
$bounds = $views[0].Current.BoundingRectangle
$frame = Wait-For 'painted transcript geometry' {
    $frames = [regex]::Matches((Read-Shared "$settings/debug.log"), '\[chat\] frame transcript (-?\d+),(-?\d+),(-?\d+),(-?\d+) edit ')
    if ($frames.Count) { $frames[$frames.Count - 1] }
}
$origin = [ChatDeliveryDesktop]::ScreenPoint($main, 0, 0)
$area = @{left=$origin.X + [int]$frame.Groups[1].Value; top=$origin.Y + [int]$frame.Groups[2].Value; right=$origin.X + [int]$frame.Groups[3].Value; bottom=$origin.Y + [int]$frame.Groups[4].Value}
if ($area.left -lt $bounds.Left -or $area.top -lt $bounds.Top -or $area.right -gt $bounds.Right -or $area.bottom -gt $bounds.Bottom -or $area.bottom -le $area.top) { throw 'Painted transcript escaped its owned view' }
Save $area "$caseDir/area.json"
$point = Wait-For 'two painted same-prefix replies' {
    Shot 'reactions-before'
    $ErrorActionPreference = 'Continue'
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
if ($menu -cne "React $up,React $down,React $heart,Reply,Copy,Copy request ID") { throw "IGSH975_REACTIONS_MISSING: $menu" }
$popup = Wait-For 'owned native reaction popup visible' { $h = [ChatDeliveryDesktop]::Menu($app.Id); if ($h -ne [IntPtr]::Zero) { $h } } 5
Shot 'reactions-menu'
for ($key = 0; $key -lt 6; $key++) { Press @(0x28) 'Down: select the next message action' }
Press @(0x0D) 'Enter: copy the original request ID'
[void](Wait-For 'original request ID reached the clipboard' { [Windows.Forms.Clipboard]::GetText() -ceq 'msg_first' })
$observation.copiedRequestId = [Windows.Forms.Clipboard]::GetText()
[ChatDeliveryDesktop]::HoverOwnedTranscript($main, $app.Id, [IntPtr]$views[0].Current.NativeWindowHandle, $point.x, $point.y)
$hover = Wait-For 'all three message hover controls are painted' {
    Shot 'reactions-hover'
    $ErrorActionPreference = 'Continue'
    $located = & node "$PSScriptRoot/../chat-reactions-proof.mjs" $Evidence --hover 2> "$caseDir/oracle-hover-stderr.log"
    if ($LASTEXITCODE -eq 0) { ($located -join "`n") | ConvertFrom-Json }
}
foreach ($entry in @('emoji', 'more')) {
    $menuStart = (Read-Shared "$settings/debug.log").Length
    $x = if ($entry -eq 'emoji') { $hover.emojiX } else { $hover.moreX }
    [ChatDeliveryDesktop]::PressOwnedTranscript($main, $app.Id, [IntPtr]$views[0].Current.NativeWindowHandle, ($x - [int]$bounds.Left), ($hover.y - [int]$bounds.Top))
    [void](Wait-For 'hover opens the same combined message menu' {
        $tail = (Read-Shared "$settings/debug.log").Substring($menuStart)
        $tail.Contains('[chat] message menu items=' + $menu)
    })
    $popup = Wait-For 'owned combined hover menu visible' { $h = [ChatDeliveryDesktop]::Menu($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    Shot ('reactions-menu-' + $entry)
    if ($entry -eq 'emoji') {
        Press @(0x1B) 'Esc: dismiss the emoji entry menu'
        [ChatDeliveryDesktop]::HoverOwnedTranscript($main, $app.Id, [IntPtr]$views[0].Current.NativeWindowHandle, $hover.insideX, $hover.insideY)
    }
}
$observation.hoverMenusMatch = $true
$firstItem = [ChatDeliveryDesktop]::FirstMenuItem($popup, $app.Id)
Save @{count=6; left=$firstItem.Left; top=$firstItem.Top; right=$firstItem.Right; bottom=$firstItem.Bottom} "$caseDir/menu-item.json"
$actions.Add(@{case=$plan.name; input='real mouse click first native reaction menu item'})
[ChatDeliveryDesktop]::PressOwnedMenu($main, $app.Id, $popup)
[void](Wait-For 'one reaction reached the real send queue' { @((Fake-State).queue).Count -eq 1 })
$observation.composerText = [ChatDeliveryDesktop]::Text($composer)
if ($observation.composerText -cne $plan.text) { throw 'Reaction cleared the composer draft' }
[void](Wait-For 'pending badge without another bubble' {
    Shot 'reactions-pending'
    $ErrorActionPreference = 'Continue'
    & node "$PSScriptRoot/../chat-reactions-proof.mjs" $Evidence --frame pending 2> "$caseDir/oracle-pending-stderr.log"
    $LASTEXITCODE -eq 0
})
Shell-Run @('idle')
[void](Wait-For 'delivered badge without another bubble' {
    Shot 'reactions-delivered'
    $ErrorActionPreference = 'Continue'
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
    $ErrorActionPreference = 'Continue'
    & node "$PSScriptRoot/../chat-reactions-proof.mjs" $Evidence --frame restart 2> "$caseDir/oracle-restart-stderr.log"
    $LASTEXITCODE -eq 0
})
Shell-Run @('reaction-fallback')
[void](Wait-For 'unmatched reaction stays an ordinary bubble' {
    Shot 'reactions-fallback'
    $ErrorActionPreference = 'Continue'
    & node "$PSScriptRoot/../chat-reactions-proof.mjs" $Evidence --frame fallback 2> "$caseDir/oracle-fallback-stderr.log"
    $LASTEXITCODE -eq 0
})
[void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)

$copyStart = (Read-Shared "$settings/debug.log").Length
Press @(0x11, 0x4B) 'Ctrl+K: select all messages'
$query = 'chat view select all'
foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
[void](Wait-For 'emoji select-all command ready' { (Read-Shared "$settings/debug.log").Substring($copyStart) -match ('\[palette\] ready chars=' + $query.Length + ' count=1 target=\d+') })
Press @(0x0D) 'Enter: select all messages'
Press @(0x11, 0x43) 'Ctrl+C: copy emoji source'
$copied = [Windows.Forms.Clipboard]::GetText()
$skin = $up + [char]::ConvertFromUtf32(0x1f3fd)
$family = [char]::ConvertFromUtf32(0x1f468) + [char]0x200d + [char]::ConvertFromUtf32(0x1f469) + [char]0x200d + [char]::ConvertFromUtf32(0x1f467)
$expectedEmoji = [string][char]0x2713 + ' ' + [char]0x26a0 + ' ' + $up + ' ' + $skin + ' ' + $family + ' ' + $heart
if (-not $copied.Contains($expectedEmoji) -or $copied.Contains([string][char]0x2705)) { throw 'Emoji copy changed the original source characters' }
[IO.File]::WriteAllText("$caseDir/emoji-copied.txt", $copied)
Shot 'reactions-selection'
Press @(0x1B) 'Esc: clear emoji selection'
[void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)

$scrollStart = (Read-Shared "$settings/debug.log").Length
Shell-Run @('messages', '200')
$cache = Wait-For 'long emoji transcript cached' { Get-ChildItem "$settings/chatcache/*.jsonl" | Where-Object { try { (Read-Shared $_.FullName).Contains('New message 199') } catch [IO.FileNotFoundException] { $false } } | Select-Object -First 1 }
[void](Wait-For 'long emoji transcript painted' {
    $painted = [regex]::Matches((Read-Shared "$settings/debug.log").Substring($scrollStart), 'PERF\[chat\]: receive to paint ms=\d+ size=(\d+)')
    $painted.Count -gt 0 -and [int]$painted[$painted.Count - 1].Groups[1].Value -ge 200
})
Bind-Transcript
$scrollView = [IntPtr]$views[0].Current.NativeWindowHandle
$measurements = @()
foreach ($round in 1..7) {
    $samples = @()
    foreach ($step in 1..20) {
        $samples += [ChatDeliveryDesktop]::TimedTranscriptWheel($main, $app.Id, $scrollView, 120)
    }
    if ($round -eq 1) { Shot 'reactions-scroll-before' }
    if ($round -gt 1) { $measurements += @{round=$round; milliseconds=$samples} }
}
Shot 'reactions-scroll-after'
$wheel = [regex]::Matches((Read-Shared "$settings/debug.log").Substring($scrollStart), '\[chat\] wheel delta=120 moved=(\d+) scale_px=\d+')
if ($wheel.Count -ne 140 -or @($wheel | Where-Object { [int]$_.Groups[1].Value -le 0 }).Count -gt 0) { throw 'Timed wheels did not all move the real transcript' }
Save @{method='synchronous WM_MOUSEWHEEL through production window procedure, RedrawWindow and GdiFlush'; messages=200; movedWheels=$wheel.Count; sourceBytes=(Get-Item $cache.FullName).Length; rounds=$measurements; cpuMs=$app.TotalProcessorTime.TotalMilliseconds} "$caseDir/emoji-scroll.json"
