Add-Type -Path (Join-Path $PSScriptRoot 'version-label-native.cs') -ReferencedAssemblies System.Drawing

function Assert-VersionLabel([string]$Name) {
    Doctor
    Snapshot $Name
    $client = New-Object VerifyNative+Rect
    $frame = New-Object VerifyNative+Rect
    $origin = New-Object VerifyNative+Point
    if (-not [VerifyNative]::GetClientRect($script:window, [ref]$client) -or -not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'Version label screenshot coordinates unavailable' }
    $scale = [VerifyNative]::GetDpiForWindow($script:window) / 96.0
    $geometry = & node (Join-Path $PSScriptRoot '../../../tools/usage-icon-geometry.js') | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw 'Telemetry icon geometry unavailable' }
    $left = $origin.X - $frame.Left + [int][Math]::Round(($geometry.icon.right + 8) * $scale)
    $top = $origin.Y - $frame.Top + $client.Bottom - [int][Math]::Round($geometry.icon.topInset * $scale)
    $width = [int][Math]::Round(82 * $scale)
    $height = [int][Math]::Round($geometry.icon.height * $scale)
    $fontHeight = [int][Math]::Round(12 * $scale)
    $fontPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../src/fonts/IBMPlexSans-Regular.ttf'))
    $ink = if ($Name -eq 'version-dark') { 138 } else { 105 }
    $reference = Join-Path $Evidence ($Name + '-expected-label.png')
    $screenshot = Join-Path $Evidence ($Name + '.png')
    $inkPixels = [VerifyVersionLabel]::Assert($screenshot, $left, $top, $width, $height, $fontHeight, $fontPath, "v$ExpectedVersion", $ink, $reference)
    Save-Json @{ expected = "v$ExpectedVersion"; matchingInkPixels = $inkPixels; differingPixels = 0; bounds = @($left, $top, $width, $height) } ($Name + '-label.json')
    $result.checks += @{ name = $Name; expected = "v$ExpectedVersion"; matchingInkPixels = $inkPixels; differingPixels = 0; screenshot = ($Name + '.png') }
}
