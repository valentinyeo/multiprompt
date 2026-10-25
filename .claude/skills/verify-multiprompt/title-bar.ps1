$proofs = @()
$script:browserShellId = (Read-Inbox).shells[0].sid
$browserTheme = $env:CAPTION_BROWSER_THEME
$targetDpi = [int]$env:CAPTION_DPI
if ($browserTheme -notin @('light', 'dark') -or $targetDpi -notin @(96, 120, 144)) { throw 'Invalid title-bar matrix case' }
$previousConnection = 0
foreach ($mode in @('restored', 'maximized')) {
    if ($previousConnection -ne 0) {
        Press-CloseBrowserPane 'Alt+A: close the browser before the native caption reference'
        Wait-Until { -not [VerifyNative]::PaneVisible($script:window) } 'browser closed before caption reference'
    }
    [void][VerifyNative]::ShowWindow($script:window, 9)
    if ($mode -eq 'maximized') { Press @(0x5B, 0x26) 'Win+Up: maximize caption reference' }
    Wait-Until { [VerifyNative]::IsZoomed($script:window) -eq ($mode -eq 'maximized') } 'caption window mode'
    Select-Theme 'amoled' ('caption-' + $mode + '-reference-theme')
    [VerifyNative]::MoveMouseClient($script:window, 100, 200, $false)
    $reference = 'caption-' + $mode + '-reference'
    Assert-Foreground
    [VerifyNative]::BringToForeground($script:window)
    Wait-Until { [VerifyNative]::GetForegroundWindow() -eq $script:window } 'native reference caption active'
    Snapshot $reference
    $geometry = [CaptionProof]::Geometry($script:window)
    if ($geometry[8] -ne $targetDpi) { throw "Expected real Windows DPI $targetDpi, got $($geometry[8])" }
    $pane = Open-BrowserPane ('caption-' + $mode + '-open') $previousConnection
    $previousConnection = $pane.browser_connection_id
    $browser = [VerifyNative]::PaneWindow($script:window)
    Wait-Until { [PaneLayoutProof]::Masks([uint32]$process.Id).Count -eq 10 } 'caption browser masks visible' 10
    foreach ($theme in @('dark', 'light', 'amoled')) {
        Select-Theme $theme ('caption-' + $mode + '-' + $theme + '-theme')
        [VerifyNative]::MoveMouseClient($script:window, 100, 200, $false)
        Wait-Until { [PaneLayoutProof]::Masks([uint32]$process.Id).Count -eq 10 } 'caption masks refreshed after app theme change' 10
        if ([VerifyNative]::PaneWindow($script:window) -ne $browser) { throw 'Caption journey replaced the browser during app theme change' }
        $freshGeometry = [CaptionProof]::Geometry($script:window)
        if (($freshGeometry -join ',') -ne ($geometry -join ',')) { throw 'Caption reference geometry or real DPI changed' }
        $rect = New-Object VerifyNative+Rect
        if (-not [VerifyNative]::GetWindowRect($browser, [ref]$rect)) { throw 'Caption browser geometry unavailable' }
        $browserRect = [int[]]@($rect.Left, $rect.Top, $rect.Right, $rect.Bottom)
        $masks = [PaneLayoutProof]::Masks([uint32]$process.Id)
        $maskRects = [int[][]]@($masks | ForEach-Object { ,([int[]]$_['rect']) })
        $shot = 'caption-' + $mode + '-' + $theme
        Assert-Foreground
        [VerifyNative]::BringToForeground($script:window)
        Wait-Until { [VerifyNative]::GetForegroundWindow() -eq $script:window } 'docked caption active'
        Snapshot $shot
        $pixels = [CaptionProof]::Measure((Join-Path $Evidence ($reference + '.png')), (Join-Path $Evidence ($shot + '.png')), $geometry, $browserRect, $maskRects, $browserTheme)
        $proofs += @{ mode = $mode; appTheme = $theme; browserTheme = $browserTheme; dpi = $targetDpi; screenshot = $shot + '.png'; reference = $reference + '.png'; browserHwnd = $browser.ToInt64(); mainHwnd = $script:window.ToInt64(); pixels = $pixels }
        Save-Json $proofs 'caption-pixels.json'
        if ($theme -eq 'amoled') {
            [CaptionProof]::NegativeControls((Join-Path $Evidence ($shot + '.png')), $geometry, $Evidence)
            foreach ($defect in @('doubled', 'band')) {
                $negative = [CaptionProof]::Measure((Join-Path $Evidence ($reference + '.png')), (Join-Path $Evidence ('negative-' + $defect + '.png')), $geometry, $browserRect, $maskRects, $browserTheme)
                Save-Json $negative ('caption-' + $mode + '-negative-' + $defect + '.json')
                $rejected = $false
                try { [CaptionProof]::Check($negative) } catch {
                    if ($_.Exception.Message -notmatch 'caption doubled-pixel signature or non-black band') { throw }
                    $rejected = $true
                }
                if (-not $rejected) { throw "Caption oracle accepted $defect negative control" }
                Copy-Item (Join-Path $Evidence ('negative-' + $defect + '.png')) (Join-Path $Evidence ('caption-' + $mode + '-negative-' + $defect + '.png'))
            }
        }
    }
}
foreach ($proof in $proofs) {
    [CaptionProof]::CheckFrame($proof.pixels)
    if ($proof.appTheme -eq 'amoled') { [CaptionProof]::Check($proof.pixels) } elseif ($proof.appTheme -eq 'light') {
        $color = $proof.pixels['appMaskColor']
        if ($color[0] -lt 235 -or $color[1] -lt 235 -or $color[2] -lt 235) { throw 'IGSH-845 caption-facing mask did not refresh to app Light' }
    }
}
$result.checks += @{ name = 'title-bar'; dpi = $targetDpi; browserTheme = $browserTheme; measurements = $proofs.Count; negativeControls = @('doubled', 'band'); tolerance = 8 }
Snapshot 'action'
Snapshot 'after'
