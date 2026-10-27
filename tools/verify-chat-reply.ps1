[void][LayoutCapture]::MoveWindow($main, 50, 20, 1820, 1000, $true)
[void](Wait-For 'owned reply window resized' { [int]([System.Windows.Automation.AutomationElement]::FromHandle($main).Current.BoundingRectangle.Width) -eq 1820 })
Bind-Transcript
$cache = Wait-For 'quoted reply in the ordinary app cache' {
    @(Get-ChildItem "$settings/chatcache/*.jsonl" -ErrorAction SilentlyContinue | Where-Object { (Read-Shared $_.FullName).Contains('My compact answer') }) | Select-Object -First 1
}
Copy-Item $cache.FullName "$caseDir/app-cache.jsonl"
Press @(0x11, 0x30) 'Ctrl+0: measure compact replies' $true
$actions.Add(@{case=$plan.name; input='wheel to the newest quoted reply'})
[ChatDeliveryDesktop]::WheelOwnedTranscript($main, $app.Id, [IntPtr]$views[0].Current.NativeWindowHandle, -12000)
$bounds = $views[0].Current.BoundingRectangle
$frame = @{baseline=($env:CHAT_REPLY_BASELINE -eq '1'); scale=([LayoutCapture]::GetDpiForWindow($main) / 96.0); transcript=@{left=[int]$bounds.Left; top=[int]$bounds.Top; width=[int]$bounds.Width; height=[int]$bounds.Height}}
Save $frame "$caseDir/frame.json"
if ($env:CHAT_REPLY_BASELINE -eq '1') {
    Shot 'reply-after'
    & node "$PSScriptRoot/chat-reply-reference-proof.mjs" baseline $Evidence
    if ($LASTEXITCODE -ne 0) { throw 'Released baseline did not provide the expected red control' }
    $observation.baselineRejected = $true
    return
}
$probe = Wait-For 'one dim single-line reply reference' {
    Shot 'reply-after'
    & node "$PSScriptRoot/chat-reply-reference-proof.mjs" probe $Evidence
    if ($LASTEXITCODE -eq 0) { Get-Content "$caseDir/probe.json" -Raw | ConvertFrom-Json }
} 10
$x = [int]($probe.x - $bounds.Left)
$y = [int]($probe.y - $bounds.Top)
$actions.Add(@{case=$plan.name; input='click compact reply reference'; x=$x; y=$y})
$offset = (Read-Shared "$settings/debug.log").Length
[ChatDeliveryDesktop]::PressClient([IntPtr]$views[0].Current.NativeWindowHandle, $app.Id, $x, $y)
[void](Wait-For 'jump selects the original, not later messages' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[chat\] reply source index=2 offset=\d+' })
[void](Wait-For 'source highlight reaches the screen' {
    Shot 'reply-highlighted'
    & node "$PSScriptRoot/chat-reply-reference-proof.mjs" highlight $Evidence
    $LASTEXITCODE -eq 0
} 10)
$observation.referenceClicked = $true
$observation.originalHighlighted = $true
