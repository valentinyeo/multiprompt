Add-Type -AssemblyName System.Runtime.WindowsRuntime
[void][Windows.Storage.StorageFile, Windows.Storage, ContentType=WindowsRuntime]
[void][Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType=WindowsRuntime]
[void][Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime]
[void][Windows.Globalization.Language, Windows.Globalization, ContentType=WindowsRuntime]
$script:ocrAwait = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
function Wait-OcrOperation($Operation, [Type]$ResultType) {
    $task = $script:ocrAwait.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
    $task.GetAwaiter().GetResult()
}
$script:ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage((New-Object Windows.Globalization.Language 'en-US'))
if ($null -eq $script:ocrEngine) { throw 'Windows English OCR is unavailable' }
function Read-Header([string]$Name) {
    Doctor
    Shot $Name
    $source = [Drawing.Bitmap]::new("$Evidence/$Name.png")
    $crop = $source.Clone([Drawing.Rectangle]::new(300, 0, $source.Width - 300, 100), $source.PixelFormat)
    $path = [IO.Path]::GetFullPath("$caseDir/$Name-header.png")
    try { $crop.Save($path, [Drawing.Imaging.ImageFormat]::Png) } finally { $crop.Dispose(); $source.Dispose() }
    $file = Wait-OcrOperation ([Windows.Storage.StorageFile]::GetFileFromPathAsync($path)) ([Windows.Storage.StorageFile])
    $stream = Wait-OcrOperation ($file.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
    try {
        $decoder = Wait-OcrOperation ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
        $bitmap = Wait-OcrOperation ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
        try { $result = Wait-OcrOperation ($script:ocrEngine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult]) } finally { $bitmap.Dispose() }
    } finally { $stream.Dispose() }
    $words = @($result.Lines | ForEach-Object { $_.Words } | ForEach-Object { @{text=$_.Text; x=$_.BoundingRect.X; y=$_.BoundingRect.Y; width=$_.BoundingRect.Width; height=$_.BoundingRect.Height} })
    Save $words "$caseDir/$Name-words.json"
    [IO.File]::WriteAllText("$caseDir/$Name-header.txt", $result.Text)
    return $result.Text
}
