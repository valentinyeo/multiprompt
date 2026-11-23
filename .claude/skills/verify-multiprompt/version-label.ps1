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
    $crop = New-Object Drawing.Bitmap ($width * 4), ($height * 4)
    $graphics = [Drawing.Graphics]::FromImage($crop)
    $path = Join-Path $Evidence ($Name + '-label.png')
    try {
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.DrawImage($image, (New-Object Drawing.Rectangle 0, 0, ($width * 4), ($height * 4)), (New-Object Drawing.Rectangle $left, $top, $width, $height), [Drawing.GraphicsUnit]::Pixel)
        $crop.Save($path, [Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $crop.Dispose(); $image.Dispose() }
    $recognized = & powershell.exe -NoProfile -File (Join-Path $PSScriptRoot 'read-image-text.ps1') -Path $path
    if ($LASTEXITCODE -ne 0) { throw 'Version label image text recognition failed' }
    $text = ($recognized -join ' ').Trim()
    Save-Json @{ expected = "v$ExpectedVersion"; text = $text; bounds = @($left, $top, $width, $height) } ($Name + '-label.json')
    if (($text -replace '\s', '') -cne "v$ExpectedVersion") { throw "Version beside telemetry icon is '$text', expected 'v$ExpectedVersion'" }
    $result.checks += @{ name = $Name; expected = "v$ExpectedVersion"; text = $text; screenshot = ($Name + '.png') }
}
