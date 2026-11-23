Add-Type -Path (Join-Path $PSScriptRoot 'version-label-native.cs') -ReferencedAssemblies System.Drawing

function Assert-VersionLabel([string]$Name) {
    Doctor
    $snapshotPath = Join-Path $env:APPDATA 'ZigShell/session.json.launch.json'
    Wait-Until { (Test-Path $snapshotPath) -and (Get-Content $snapshotPath -Raw | ConvertFrom-Json).sidebar_width -ge 100 } 'app publishes its actual sidebar width'
    $sidebar = Get-Content $snapshotPath -Raw | ConvertFrom-Json
    Snapshot $Name
    $client = New-Object VerifyNative+Rect
    $frame = New-Object VerifyNative+Rect
    $origin = New-Object VerifyNative+Point
    if (-not [VerifyNative]::GetClientRect($script:window, [ref]$client) -or -not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'Version label screenshot coordinates unavailable' }
    $uiScale = 100
    $state = Read-Session
    if ($state.PSObject.Properties['ui_scale']) { $uiScale = [int]$state.ui_scale }
    $scale = [VerifyNative]::GetDpiForWindow($script:window) * $uiScale / 9600.0
    $geometry = & node (Join-Path $PSScriptRoot '../../../tools/usage-icon-geometry.js') | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw 'Telemetry icon geometry unavailable' }
    $offsetX = $origin.X - $frame.Left
    $offsetY = $origin.Y - $frame.Top
    $left = $offsetX + [int][Math]::Floor($geometry.icon.right * $scale)
    $top = $offsetY + $client.Bottom - [int][Math]::Floor($geometry.icon.topInset * $scale)
    $sidebarRight = $offsetX + [int][Math]::Floor($sidebar.sidebar_width * $scale)
    $width = $sidebarRight - $left
    $height = [int][Math]::Floor($geometry.icon.height * $scale)
    $paddingLeft = [int][Math]::Floor(8 * $scale)
    $paddingRight = [int][Math]::Floor(12 * $scale)
    $fontHeight = [int][Math]::Floor(12 * $scale)
    $fontPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../src/fonts/IBMPlexSans-Regular.ttf'))
    $ink = if ($Name -eq 'version-dark') { 138 } else { 105 }
    $reference = Join-Path $Evidence ($Name + '-expected-label.png')
    $screenshot = Join-Path $Evidence ($Name + '.png')
    $pixels = [VerifyVersionLabel]::Assert($screenshot, $left, $top, $width, $height, $fontHeight, $fontPath, "v$ExpectedVersion", $ink, $reference, $paddingLeft, $paddingRight)
    $label = New-Object Drawing.Rectangle($pixels[1], $pixels[2], $pixels[3], $pixels[4])
    $allowed = New-Object Drawing.Rectangle(($left + $paddingLeft), $top, ($width - $paddingLeft - $paddingRight), $height)
    if (-not $allowed.Contains($label)) { throw 'Version ink extends outside its sidebar label bounds' }
    $controls = @(
        @{ name = 'telemetry'; bounds = New-Object Drawing.Rectangle(($offsetX + [int][Math]::Floor($geometry.icon.left * $scale)), $top, ([int][Math]::Floor($geometry.icon.width * $scale)), $height) }
        @{ name = 'sidebar-controls'; bounds = New-Object Drawing.Rectangle($offsetX, $offsetY, ($sidebarRight - $offsetX), ($top - $offsetY)) }
        @{ name = 'content-pane'; bounds = New-Object Drawing.Rectangle($sidebarRight, $offsetY, ($client.Right - $sidebarRight + $offsetX), $client.Bottom) }
    )
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    foreach ($node in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
        if ($node.Current.IsOffscreen -or $node.Current.ControlType.ProgrammaticName -notin @('ControlType.Button', 'ControlType.Edit', 'ControlType.Text', 'ControlType.Document', 'ControlType.TabItem')) { continue }
        $rect = $node.Current.BoundingRectangle
        if ($rect.IsEmpty -or $rect.Width -le 0 -or $rect.Height -le 0) { continue }
        $controls += @{ name = $node.Current.ClassName; bounds = [Drawing.Rectangle]::FromLTRB([int][Math]::Floor($rect.Left - $frame.Left), [int][Math]::Floor($rect.Top - $frame.Top), [int][Math]::Ceiling($rect.Right - $frame.Left), [int][Math]::Ceiling($rect.Bottom - $frame.Top)) }
    }
    foreach ($control in $controls) {
        if ($label.IntersectsWith($control.bounds)) { throw "Version label overlaps $($control.name)" }
    }
    Save-Json @{ expected = "v$ExpectedVersion"; matchingInkPixels = $pixels[0]; differingPixels = 0; bounds = $label; allowedBounds = $allowed; controls = $controls; sidebarWidth = $sidebar.sidebar_width } ($Name + '-label.json')
    $result.checks += @{ name = $Name; expected = "v$ExpectedVersion"; matchingInkPixels = $pixels[0]; differingPixels = 0; overlaps = 0; sidebarWidth = $sidebar.sidebar_width; screenshot = ($Name + '.png') }
}

function Assert-NarrowVersionLabel {
    $snapshotPath = Join-Path $env:APPDATA 'ZigShell/session.json.launch.json'
    $sidebar = Get-Content $snapshotPath -Raw | ConvertFrom-Json
    $source = Get-Content (Join-Path $PSScriptRoot '../../../src/app_state.zig') -Raw
    if ($source -notmatch 'pub const SIDEBAR_W_MIN: i32 = (\d+);') { throw 'Minimum sidebar width unavailable' }
    $minimum = [int]$Matches[1]
    $uiScale = 100
    $state = Read-Session
    if ($state.PSObject.Properties['ui_scale']) { $uiScale = [int]$state.ui_scale }
    $scale = [VerifyNative]::GetDpiForWindow($script:window) * $uiScale / 9600.0
    $client = New-Object VerifyNative+Rect
    if (-not [VerifyNative]::GetClientRect($script:window, [ref]$client)) { throw 'Sidebar drag coordinates unavailable' }
    [VerifyNative]::BringToForeground($script:window)
    Record 'Drag the sidebar divider below its minimum expanded width'
    [VerifyNative]::DragSelectClient($script:window, ([int][Math]::Floor($sidebar.sidebar_width * $scale)), ($client.Bottom - [int][Math]::Floor(70 * $scale)), ([int][Math]::Floor(($minimum - 20) * $scale)), ($client.Bottom - [int][Math]::Floor(70 * $scale)))
    Wait-Until {
        $published = Get-Content $snapshotPath -Raw | ConvertFrom-Json
        $published.sidebar_width -eq $minimum -and -not $published.sidebar_collapsed
    } 'sidebar reaches its minimum expanded width'
    Assert-VersionLabel 'version-narrow'
}
