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
    $image = [Drawing.Bitmap]::FromFile((Join-Path $Evidence ($Name + '.png')))
    $normalized = New-Object Drawing.Bitmap $width, $height
    $crop = New-Object Drawing.Bitmap ($width * 4 + 32), ($height * 4 + 32)
    $graphics = [Drawing.Graphics]::FromImage($crop)
    $path = Join-Path $Evidence ($Name + '-label.png')
    try {
        $background = $image.GetPixel($left, $top).GetBrightness()
        $contrast = 0.0
        for ($y = 0; $y -lt $height; $y++) {
            for ($x = 0; $x -lt $width; $x++) {
                $contrast = [Math]::Max($contrast, [Math]::Abs($image.GetPixel($left + $x, $top + $y).GetBrightness() - $background))
            }
        }
        if ($contrast -lt 0.1) { throw 'No readable version ink beside the telemetry icon' }
        for ($y = 0; $y -lt $height; $y++) {
            for ($x = 0; $x -lt $width; $x++) {
                $ink = [Math]::Abs($image.GetPixel($left + $x, $top + $y).GetBrightness() - $background)
                $gray = [int][Math]::Round(255 * (1 - $ink / $contrast))
                $normalized.SetPixel($x, $y, [Drawing.Color]::FromArgb($gray, $gray, $gray))
            }
        }
        $graphics.Clear([Drawing.Color]::White)
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::Half
        $graphics.DrawImage($normalized, (New-Object Drawing.Rectangle 16, 16, ($width * 4), ($height * 4)), (New-Object Drawing.Rectangle 0, 0, $width, $height), [Drawing.GraphicsUnit]::Pixel)
        $crop.Save($path, [Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $crop.Dispose(); $normalized.Dispose(); $image.Dispose() }
    $recognized = & powershell.exe -NoProfile -File (Join-Path $PSScriptRoot 'read-image-text.ps1') -Path $path
    if ($LASTEXITCODE -ne 0) { throw 'Version label image text recognition failed' }
    $text = ($recognized -join ' ').Trim()
    Save-Json @{ expected = "v$ExpectedVersion"; text = $text; bounds = @($left, $top, $width, $height) } ($Name + '-label.json')
    if (($text -replace '\s', '') -cne "v$ExpectedVersion") { throw "Version beside telemetry icon is '$text', expected 'v$ExpectedVersion'" }
    $result.checks += @{ name = $Name; expected = "v$ExpectedVersion"; text = $text; screenshot = ($Name + '.png') }
}
