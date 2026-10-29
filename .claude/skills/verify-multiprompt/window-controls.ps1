Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -Path (Join-Path $PSScriptRoot 'window-controls-native.cs')
$proofs = @()
Select-Theme 'amoled' 'controls-amoled'
$geometry = [WindowControlsProof]::Geometry($script:window)
Save-Json @{ geometry = $geometry; screenshot = 'before.png' } 'window-controls-baseline.json'
if ($geometry[5] - $geometry[1] -gt 1) { throw 'IGSH-1000 native title bar still consumes chat height' }
$dpi = $geometry[8]
if ($dpi -ne [int]$env:CAPTION_DPI) { throw 'Window control journey did not reach the requested real monitor DPI' }
$buttonW = [int][Math]::Floor(44 * $dpi / 96)
$buttonH = [int][Math]::Floor(32 * $dpi / 96)
$snapshotPath = Join-Path $env:APPDATA 'ZigShell/session.json.launch.json'
Wait-Until { (Test-Path $snapshotPath) -and (Get-Content $snapshotPath -Raw | ConvertFrom-Json).sidebar_width -ge 100 } 'app publishes its actual sidebar width'
$sidebarLogical = [int](Get-Content $snapshotPath -Raw | ConvertFrom-Json).sidebar_width
if ($sidebarLogical -gt 1000) { throw 'Published sidebar width is outside the app range' }
$sidebar = [int][Math]::Floor($sidebarLogical * $dpi / 96)
$monitor = [VerifyNative]::MonitorFromWindow($script:window, 2)
$info = New-Object VerifyNative+MonitorInfo
$info.Size = [Runtime.InteropServices.Marshal]::SizeOf($info)
if (-not [VerifyNative]::GetMonitorInfoW($monitor, [ref]$info)) { throw 'Window control monitor work area unavailable' }
$work = $info.Work
[void][VerifyNative]::MoveWindow($script:window, ($work.Left + 50), ($work.Top + 50), ([Math]::Min(1000, $work.Right - $work.Left - 160)), ([Math]::Min(700, $work.Bottom - $work.Top - 160)), $true)
Press @(0x12, 0x43) 'Alt+C: show chat using the reclaimed native caption height'
Wait-Until {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
    $script:frameTranscript = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
    $null -ne $script:frameTranscript -and -not $script:frameTranscript.Current.IsOffscreen
} 'real chat transcript visible under the custom frame'
$geometry = [WindowControlsProof]::Geometry($script:window)
$chatTop = $script:frameTranscript.Current.BoundingRectangle.Top - $geometry[1]
$existingChatInset = [Math]::Floor(8 * $dpi / 96) + [Math]::Floor(6 * $dpi / 96) + [Math]::Floor(4 * $dpi / 96)
if ($chatTop -gt $existingChatInset + 1) { throw 'Window controls introduced a replacement full-width chat header' }
Save-Json @{ geometry = $geometry; chatTop = $chatTop; existingChatInset = $existingChatInset; recoveredTopPixels = $geometry[9] - ($geometry[5] - $geometry[1]) } 'window-controls-chat-height.json'
Snapshot 'action'
foreach ($mode in @('restored', 'maximized')) {
    if ($mode -eq 'maximized') {
        $geometry = [WindowControlsProof]::Geometry($script:window)
        [VerifyNative]::ClickClient($script:window, ($geometry[6] - [int](1.5 * $buttonW)), ([int]($buttonH / 2)))
        Wait-Until {
            $maximized = [WindowControlsProof]::Geometry($script:window)
            [VerifyNative]::IsZoomed($script:window) -and
                $maximized[4] -eq $maximized[10] -and $maximized[5] -eq $maximized[11] -and
                $maximized[4] + $maximized[6] -eq $maximized[12] -and $maximized[5] + $maximized[7] -eq $maximized[13]
        } 'custom maximize button maximizes'
    }
    foreach ($theme in @('dark', 'light', 'amoled')) {
        Select-Theme $theme ("controls-$mode-$theme-select")
        [VerifyNative]::BringToForeground($script:window)
        [VerifyNative]::MoveMouseClient($script:window, 100, 150, $false)
        $shot = "controls-$mode-$theme"
        Snapshot $shot
        $geometry = [WindowControlsProof]::Geometry($script:window)
        $pixels = [WindowControlsProof]::Pixels((Join-Path $Evidence ($shot + '.png')), $geometry, $sidebar, $buttonW, $buttonH, ($theme -eq 'light'))
        $hits = @(0..2 | ForEach-Object { [WindowControlsProof]::Hit($script:window, ($geometry[6] - (3 - $_) * $buttonW + [int]($buttonW / 2)), ([int]($buttonH / 2))) })
        $proofs += @{ mode = $mode; theme = $theme; dpi = $dpi; geometry = $geometry; pixels = $pixels; hits = $hits; screenshot = $shot + '.png' }
        Save-Json $proofs 'window-controls-pixels.json'
        if ($pixels.titleInkPixels -lt 8) { throw 'Live theme change made the selected chat title unreadable' }
        if ([Math]::Abs($pixels.captionInset) -gt 1 -or -not $pixels.clientInsideWorkArea -or $pixels.separatorTopPixels -ne 6 -or @($pixels.glyphPixels | Where-Object { $_ -lt 8 -or $_ -gt 150 }).Count -ne 0) { throw 'Custom frame screenshot lost a glyph, top separator or reclaimed caption' }
        if (($hits -join ',') -ne '8,9,20') { throw "Custom frame controls have wrong native hit areas: $hits" }
    }
}
$geometry = [WindowControlsProof]::Geometry($script:window)
[VerifyNative]::ClickClient($script:window, ($geometry[6] - [int](1.5 * $buttonW)), ([int]($buttonH / 2)))
Wait-Until { -not [VerifyNative]::IsZoomed($script:window) } 'same custom maximize button restores'
$geometry = [WindowControlsProof]::Geometry($script:window)
$dragX = [int]($geometry[6] / 2)
$dragY = [int][Math]::Floor(6 * $dpi / 96)
if ([WindowControlsProof]::Hit($script:window, $dragX, $dragY) -ne 2) { throw 'Thin top strip is not a native drag handle' }
[WindowControlsProof]::Drag($script:window, $dragX, $dragY, 40, 40)
Wait-Until { $moved = [WindowControlsProof]::Geometry($script:window); $moved[0] -ge $geometry[0] + 30 -and $moved[1] -ge $geometry[1] + 30 } 'real top-strip drag moves the window'
$dragged = [WindowControlsProof]::Geometry($script:window)
[WindowControlsProof]::DoubleClick($script:window, $dragX, $dragY)
Wait-Until {
    $maximized = [WindowControlsProof]::Geometry($script:window)
    [VerifyNative]::IsZoomed($script:window) -and
        $maximized[4] -eq $maximized[10] -and $maximized[5] -eq $maximized[11] -and
        $maximized[4] + $maximized[6] -eq $maximized[12] -and $maximized[5] + $maximized[7] -eq $maximized[13]
} 'double-clicking the top strip maximizes'
$geometry = [WindowControlsProof]::Geometry($script:window)
[VerifyNative]::ClickClient($script:window, ($geometry[6] - [int](1.5 * $buttonW)), ([int]($buttonH / 2)))
Wait-Until { -not [VerifyNative]::IsZoomed($script:window) } 'custom restore works after top-strip double-click'
Press @(0x5B, 0x25) 'Win+Left: snap the custom frame to the monitor edge'
Wait-Until {
    $snapped = [WindowControlsProof]::Geometry($script:window)
    [Math]::Abs($snapped[0] - $work.Left) -le 2 -and [Math]::Abs(($snapped[2] - $snapped[0]) - ($work.Right - $work.Left) / 2) -le 4
} 'Windows edge snapping preserves native work-area geometry'
$snapped = [WindowControlsProof]::Geometry($script:window)
Press @(0x1B) 'Esc: dismiss Windows snap suggestions'
Snapshot 'controls-snapped'
[void][VerifyNative]::ShowWindow($script:window, 9)
[void][VerifyNative]::MoveWindow($script:window, ($work.Left + 50), ($work.Top + 50), ([Math]::Min(1000, $work.Right - $work.Left - 160)), ([Math]::Min(700, $work.Bottom - $work.Top - 160)), $true)
$geometry = [WindowControlsProof]::Geometry($script:window)
if ([WindowControlsProof]::Hit($script:window, ($geometry[6] - 1), ([int]($geometry[7] / 2))) -ne 11) { throw 'Custom frame lost its native right resize edge' }
[WindowControlsProof]::Drag($script:window, ($geometry[6] - 1), ([int]($geometry[7] / 2)), -40, 0)
Wait-Until { $resized = [WindowControlsProof]::Geometry($script:window); $resized[6] -le $geometry[6] - 30 } 'real resize-edge drag changes the width'
$geometry = [WindowControlsProof]::Geometry($script:window)
[VerifyNative]::ClickClient($script:window, ($geometry[6] - [int](2.5 * $buttonW)), ([int]($buttonH / 2)))
Wait-Until { [WindowControlsProof]::IsIconic($script:window) } 'custom minimize button minimizes'
[void][VerifyNative]::ShowWindow($script:window, 9)
[VerifyNative]::BringToForeground($script:window)
Wait-Until { -not [WindowControlsProof]::IsIconic($script:window) -and [VerifyNative]::GetForegroundWindow() -eq $script:window } 'normal restore after minimizing'
[VerifyNative]::MoveMouseClient($script:window, 100, 150, $false)
Snapshot 'controls-before-browser'
$script:browserShellId = (Read-Inbox).shells[0].sid
$pane = Open-BrowserPane 'controls-browser-open'
$browser = [VerifyNative]::PaneWindow($script:window)
[VerifyNative]::BringToForeground($script:window)
[VerifyNative]::MoveMouseClient($script:window, 100, 150, $false)
Snapshot 'controls-with-browser'
$geometry = [WindowControlsProof]::Geometry($script:window)
$browserRect = New-Object VerifyNative+Rect
if (-not [VerifyNative]::GetWindowRect($browser, [ref]$browserRect) -or $browserRect.Top -lt $geometry[5] + $buttonH) { throw 'Docked browser covers the window controls' }
$reference = Join-Path $Evidence 'controls-before-browser.png'
$actual = Join-Path $Evidence 'controls-with-browser.png'
$differences = [WindowControlsProof]::CompareControls($reference, $actual, $geometry, $buttonW, $buttonH)
$negative = Join-Path $Evidence 'controls-negative.png'
[WindowControlsProof]::NegativeControl($actual, $negative, $geometry, $buttonW)
$negativeDifferences = [WindowControlsProof]::CompareControls($actual, $negative, $geometry, $buttonW, $buttonH)
Save-Json @{ differences = $differences; negativeDifferences = $negativeDifferences; browserRect = $browserRect } 'window-controls-browser.json'
if ($differences -ne 0 -or $negativeDifferences -eq 0) { throw 'Window control pixel signature changed after docking, or its negative control was accepted' }
Focus-LockedBrowser $browser
[VerifyNative]::ClickClient($script:window, ($geometry[6] - [int](1.5 * $buttonW)), ([int]($buttonH / 2)))
Wait-Until {
    $maximized = [WindowControlsProof]::Geometry($script:window)
    [VerifyNative]::IsZoomed($script:window) -and
        $maximized[4] -eq $maximized[10] -and $maximized[5] -eq $maximized[11] -and
        $maximized[4] + $maximized[6] -eq $maximized[12] -and $maximized[5] + $maximized[7] -eq $maximized[13]
} 'custom maximize works while the docked browser has focus'
$geometry = [WindowControlsProof]::Geometry($script:window)
[VerifyNative]::ClickClient($script:window, ($geometry[6] - [int](1.5 * $buttonW)), ([int]($buttonH / 2)))
Wait-Until { -not [VerifyNative]::IsZoomed($script:window) } 'custom restore with a docked browser'
Doctor
Snapshot 'after'
$geometry = [WindowControlsProof]::Geometry($script:window)
[VerifyNative]::ClickClient($script:window, ($geometry[6] - [int]($buttonW / 2)), ([int]($buttonH / 2)))
if (-not $process.WaitForExit(15000)) { throw 'Custom close button did not close the owned app normally' }
$result.windowControls = @{ closed = $true; minimize = $true; maximize = $true; restore = $true; drag = $true; doubleClick = $true; snap = $true; resize = $true; dpi = $dpi; dragged = $dragged; snapped = $snapped }
Save-Json $result.windowControls 'window-controls-actions.json'
$result.checks += @{ name = 'window-controls'; measurements = $proofs.Count; realInput = $true }
