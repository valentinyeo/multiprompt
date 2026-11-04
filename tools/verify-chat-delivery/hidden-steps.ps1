[void](Wait-For 'hidden-step source transcript loaded' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
[void][LayoutCapture]::MoveWindow($main, 20, 20, 1200, 900, $true)
[void](Wait-For 'owned window resized for step disclosure' { [int]([System.Windows.Automation.AutomationElement]::FromHandle($main).Current.BoundingRectangle.Width) -eq 1200 })
Bind-Transcript
Type-Composer $plan.text
$cache = Wait-For 'all three tool outputs in the app cache' {
    @(Get-ChildItem "$settings/chatcache/*.jsonl" -ErrorAction SilentlyContinue | Where-Object { (Read-Shared $_.FullName).Contains('Output for step 2-0') }) | Select-Object -First 1
}
Copy-Item $cache.FullName "$caseDir/app-cache.jsonl"
$observation.frames = @()
function Steps-Palette([string]$Query) {
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
    $start = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x4B) 'Ctrl+K: open step disclosure palette'
    [void](Wait-For 'step palette ready' { (Read-Shared "$settings/debug.log").Substring($start) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    foreach ($letter in $Query.ToCharArray()) { [ChatDeliveryDesktop]::Character($letter) }
    [void](Wait-For 'step palette query ready' { (Read-Shared "$settings/debug.log").Substring($start) -match ('\[palette\] ready chars=' + $Query.Length + ' count=\d+ target=\d+') })
    Press @(0x0D) ('Enter: ' + $Query)
}
function Steps-Frame([string]$Name, [bool]$FirstOpen, [bool]$SecondOpen) {
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
    $start = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x30) 'Ctrl+0: repaint the step groups' $true
    $groups = Wait-For 'actual painted step disclosure state' {
        $matches = [regex]::Matches((Read-Shared "$settings/debug.log").Substring($start), '\[chat\] steps first=(\d+) count=(\d+) open=([01]) header=(-?\d+),(-?\d+),(-?\d+),(-?\d+)')
        $latest = @{}
        foreach ($match in $matches) {
            $g = $match.Groups
            $latest[[int]$g[1].Value] = @{first=[int]$g[1].Value; count=[int]$g[2].Value; open=([int]$g[3].Value -eq 1); left=[int]$g[4].Value; top=[int]$g[5].Value; right=[int]$g[6].Value; bottom=[int]$g[7].Value}
        }
        $rows = @($latest.Values | Sort-Object { $_['first'] })
        Save @{rows=$rows; expected=@($FirstOpen, $SecondOpen); offset=$start} "$caseDir/disclosure-probe.json"
        if ($rows.Count -eq 2 -and $rows[0]['count'] -eq 2 -and $rows[1]['count'] -eq 1 -and $rows[0].open -eq $FirstOpen -and $rows[1].open -eq $SecondOpen) { $rows }
    } 15
    if ([ChatDeliveryDesktop]::Text($composer) -cne $plan.text) { throw 'Step disclosure changed the composer draft' }
    $bounds = $views[0].Current.BoundingRectangle
    foreach ($row in $groups) {
        if ($row.left -lt 0 -or $row.top -lt 0 -or $row.right -gt $bounds.Width -or $row.bottom -gt $bounds.Height -or $row.bottom -le $row.top) { throw 'Step header is outside the owned visible transcript' }
    }
    $frame = @{name=$Name; theme=(Read-Shared "$settings/theme-mode.txt").Trim(); groups=@($groups); composerText=[ChatDeliveryDesktop]::Text($composer); transcript=@{left=[int]$bounds.Left; top=[int]$bounds.Top; width=[int]$bounds.Width; height=[int]$bounds.Height}}
    Shot "steps-$Name"
    Save $frame "$caseDir/frame-$Name.json"
    $observation.frames += $frame
    return $frame
}
function Steps-Click($Frame) {
    Doctor
    $row = @($Frame.groups)[0]
    $x = [int]$row.left + 20
    $y = [int](($row.top + $row.bottom) / 2)
    $actions.Add(@{case=$plan.name; input='click first step group disclosure'; x=$x; y=$y})
    [ChatDeliveryDesktop]::PressOwnedTranscript($main, $app.Id, [IntPtr]$views[0].Current.NativeWindowHandle, $x, $y)
}
foreach ($theme in @('light', 'amoled', 'mid')) {
    Steps-Palette 'themes'
    foreach ($letter in $theme.ToCharArray()) { [ChatDeliveryDesktop]::Character($letter) }
    Press @(0x0D) ('Enter: choose ' + $theme)
    [void](Wait-For 'selected step proof theme saved' { (Read-Shared "$settings/theme-mode.txt").Trim() -eq $theme })
    Press @(0x1B) 'Esc: leave the theme picker'
    $closed = Steps-Frame "$theme-closed" $false $false
    if ($theme -eq 'light') { Shot 'before' }
    Steps-Click $closed
    $opened = Steps-Frame "$theme-open" $true $false
    if ($theme -eq 'light') { Shot 'action' }
    Steps-Click $opened
    [void](Steps-Frame "$theme-folded" $false $false)
    Steps-Palette 'tool steps'
    [void](Steps-Frame "$theme-palette-open" $true $true)
    Steps-Palette 'tool steps'
    [void](Steps-Frame "$theme-palette-closed" $false $false)
    Press @(0x11, 0x10, 0x4A) 'Ctrl+Shift+J: open tool groups from the composer' $true
    [void](Steps-Frame "$theme-shortcut-open" $true $true)
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, [IntPtr]$views[0].Current.NativeWindowHandle)
    Press @(0x11, 0x10, 0x4A) 'Ctrl+Shift+J: fold tool groups from the transcript'
    [void](Steps-Frame "$theme-shortcut-closed" $false $false)
}
$observation.composerText = [ChatDeliveryDesktop]::Text($composer)
$observation.endMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
