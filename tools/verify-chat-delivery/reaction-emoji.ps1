[void](Wait-For 'reaction transcript loaded' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
[void](Wait-For 'Claude detected for real reaction menu' {
    $published = (Read-Shared "$settings/inbox-default.json" | ConvertFrom-Json).shells
    @($published | Where-Object { $_.PSObject.Properties['ag'] -and $_.ag -eq 1 }).Count -eq 1
})
function Emoji-Theme([string]$Name) {
    Press @(0x11, 0x4B) 'Ctrl+K: open Themes'
    foreach ($letter in 'themes'.ToCharArray()) { [ChatDeliveryDesktop]::Character($letter) }
    Press @(0x0D) 'Enter: Themes'
    foreach ($letter in $Name.ToCharArray()) { [ChatDeliveryDesktop]::Character($letter) }
    Press @(0x0D) "Enter: $Name"
    [void](Wait-For "saved $Name theme" { (Read-Shared "$settings/theme-mode.txt").Trim() -eq $Name })
    Press @(0x1B) 'Esc: close Themes'
    Bind-Transcript
}
Emoji-Theme 'amoled'
Type-Composer $plan.text
$bounds = $views[0].Current.BoundingRectangle
$viewport = Transcript-Viewport
$area = @{left=$viewport.Left; top=$viewport.Top; right=$viewport.Right; bottom=$viewport.Bottom}
Save $area "$caseDir/area.json"
$point = Wait-For 'both native source replies painted' {
    Shot 'reactions-before'
    $ErrorActionPreference = 'Continue'
    $located = & node "$PSScriptRoot/../chat-reactions-proof.mjs" $Evidence --locate 2> "$caseDir/locate-stderr.log"
    if ($LASTEXITCODE -eq 0) { ($located -join "`n") | ConvertFrom-Json }
}
Doctor
$view = [IntPtr]$views[0].Current.NativeWindowHandle
$actions.Add(@{case=$plan.name; input='real right-click first reply for reaction'; x=$point.x; y=$point.y})
[ChatDeliveryDesktop]::RightClickOwnedTranscript($main, $app.Id, $view, $point.x, $point.y)
[void](Wait-For 'owned reaction menu' { [ChatDeliveryDesktop]::Menu($app.Id) -ne [IntPtr]::Zero })
Shot 'reactions-menu'
Press @(0x28) 'Down: thumbs-up reaction'
Press @(0x0D) 'Enter: add thumbs-up reaction'
[void](Wait-For 'real reaction enqueue' { @((Fake-State).queue).Count -eq 1 })
$observation.composerText = [ChatDeliveryDesktop]::Text($composer)
if ($observation.composerText -cne $plan.text) { throw 'Reaction changed the composer draft' }
$geometry = Wait-For 'reaction chip and source geometry' {
    Shot 'reactions-pending'
    $ErrorActionPreference = 'Continue'
    $located = & node "$PSScriptRoot/../reaction-emoji-pixels.mjs" $Evidence --geometry 2> "$caseDir/geometry-stderr.log"
    if ($LASTEXITCODE -eq 0) { ($located -join "`n") | ConvertFrom-Json }
}
foreach ($theme in @('dark', 'light')) {
    Emoji-Theme $theme
    Doctor
    $actions.Add(@{case=$plan.name; input="real hover first reply on $theme"; x=$geometry.point.x; y=$geometry.point.y})
    [ChatDeliveryDesktop]::HoverOwnedTranscript($main, $app.Id, $view, $geometry.point.x, $geometry.point.y)
    [void](Wait-For "full-size colour reaction and react button on $theme" {
        Shot "reactions-emoji-$theme"
        $ErrorActionPreference = 'Continue'
        & node "$PSScriptRoot/../reaction-emoji-pixels.mjs" $Evidence --frame $theme 2> "$caseDir/$theme-pixels-stderr.log"
        $LASTEXITCODE -eq 0
    } 5)
    Copy-Item "$settings/theme-mode.txt" "$caseDir/theme-$theme.txt"
}
[void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
Doctor $true
