function Picture-Window {
    Wait-For 'owned picture preview' {
        $candidate = [ChatDeliveryDesktop]::GetForegroundWindow()
        if ([ChatDeliveryDesktop]::Owner($candidate) -eq [uint32]$app.Id -and [ChatDeliveryDesktop]::Class($candidate) -eq 'MultiPromptBotPicture') { $candidate }
    }
}
function Picture-Click([IntPtr]$Window, [int]$Id) {
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $Window) { throw 'Picture preview lost foreground' }
    $child = [PhotoDialogOwner]::GetDlgItem($Window, $Id)
    if (-not [PhotoDialogOwner]::IsWindowVisible($child) -or -not [PhotoDialogOwner]::IsWindowEnabled($child)) { throw 'Picture control is not available' }
    $rect = [ChatDeliveryDesktop+Rect]::new()
    [void][ChatDeliveryDesktop]::GetClientRect($child, [ref]$rect)
    [ChatDeliveryDesktop]::PressClient($child, [uint32]$app.Id, [int]($rect.Right / 2), [int]($rect.Bottom / 2))
}
function Picture-Open {
    Look 'bot face' 'generate' 7170
    $window = Picture-Window
    Check 'picture-disables-main-owner' (-not [PhotoDialogOwner]::IsWindowEnabled($main))
    return $window
}
function Picture-Calls {
    $path = Join-Path $env:MP_PICTURE_FIXTURE 'calls.jsonl'
    if (Test-Path $path) { return @(Get-Content $path).Count }
    return 0
}
function Picture-Crop([IntPtr]$Window, [string]$Name, [bool]$Dots = $false) {
    $scale = $dpi / 96.0
    $origin = [ChatDeliveryDesktop+Point]::new()
    [void][ChatDeliveryDesktop]::ClientToScreen($Window, [ref]$origin)
    $x = if ($Dots) { 190 } else { 120 }
    $y = if ($Dots) { 190 } else { 112 }
    $width = if ($Dots) { 60 } else { 192 }
    $height = if ($Dots) { 30 } else { 192 }
    $bitmap = [Drawing.Bitmap]::new([int]($width * $scale), [int]($height * $scale))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($origin.X + [int]($x * $scale), $origin.Y + [int]($y * $scale), 0, 0, $bitmap.Size)
        $bitmap.Save((Join-Path $Evidence "$Name.png"))
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
    return (Get-FileHash (Join-Path $Evidence "$Name.png") -Algorithm SHA256).Hash
}
function Picture-Release([IntPtr]$Window, [int]$ExpectedCalls, [string]$Name) {
    [void](Wait-For 'one fake image call' { (Picture-Calls) -eq $ExpectedCalls })
    Check 'busy-has-no-keep-button' (-not [PhotoDialogOwner]::IsWindowVisible([PhotoDialogOwner]::GetDlgItem($Window, 4)))
    $firstDots = Picture-Crop $Window "$Name-dots-a" $true
    [void](Wait-For 'three ticking dots animate' { (Picture-Crop $Window "$Name-dots-b" $true) -ne $firstDots })
    Shot "$Name-busy"
    $endpoint = (Get-Content (Join-Path $env:MP_PICTURE_FIXTURE 'endpoint') -Raw).Trim()
    [void](Invoke-WebRequest -UseBasicParsing -Uri $endpoint -TimeoutSec 5)
    [void](Wait-For 'picture has Keep and Try again' {
        [PhotoDialogOwner]::IsWindowVisible([PhotoDialogOwner]::GetDlgItem($Window, 4)) -and [PhotoDialogOwner]::IsWindowVisible([PhotoDialogOwner]::GetDlgItem($Window, 3))
    })
    [void](Picture-Crop $Window "$Name-preview")
    Shot "$Name-preview-window"
    Check 'one-call-per-attempt' ((Picture-Calls) -eq $ExpectedCalls)
}
function Picture-Cancel([IntPtr]$Window) {
    [VerifyNative]::Chord(@(0x1b))
    [void](Wait-For 'picture preview closes' { -not [PhotoDialogOwner]::IsWindow($Window) })
    Check 'picture-cancel-reenables-main' ([PhotoDialogOwner]::IsWindowEnabled($main))
}
Copy-Item (Join-Path $Evidence 'normalized-wide.png') (Join-Path $env:MP_PICTURE_FIXTURE 'first.png')
Copy-Item (Join-Path $Evidence 'normalized-tall.png') (Join-Path $env:MP_PICTURE_FIXTURE 'second.png')
Focus; Press @(0x11, 0x4b); Query 'renamed alpha' (Index-For $firstId); Press @(0x0d)
$window = Picture-Open
[VerifyNative]::Text('orange fox with glasses')
$edit = [PhotoDialogOwner]::GetDlgItem($window, 11)
[void](Wait-For 'picture description typed exactly' { [ChatDeliveryDesktop]::Text($edit) -ceq 'orange fox with glasses' })
[VerifyNative]::Chord(@(0x0d))
Picture-Release $window 1 'picture-cancel'
Check 'preview-does-not-change-saved-photo' (-not (Test-Path $first.FullName))
Picture-Cancel $window
Check 'cancel-does-not-save-preview' (-not (Test-Path $first.FullName))
$window = Picture-Open
[VerifyNative]::Text('orange fox with glasses')
[VerifyNative]::Chord(@(0x0d))
Picture-Release $window 2 'picture-first'
$firstPreview = (Get-FileHash (Join-Path $Evidence 'picture-first-preview.png') -Algorithm SHA256).Hash
Picture-Click $window 3
Picture-Release $window 3 'picture-again'
Check 'try-again-replaces-preview' ((Get-FileHash (Join-Path $Evidence 'picture-again-preview.png') -Algorithm SHA256).Hash -ne $firstPreview)
Check 'try-again-does-not-save-preview' (-not (Test-Path $first.FullName))
Picture-Click $window 4
[void](Wait-For 'Keep saves and closes preview' { -not [PhotoDialogOwner]::IsWindow($window) -and (Test-Path $first.FullName) })
Assert-Normalized $first.FullName
Assert-AllFaces $firstId 'picture-kept'
$keptHash = (Get-FileHash $first.FullName -Algorithm SHA256).Hash
Stop-App
Start-App
Check 'generated-photo-survives-restart' ((Get-FileHash $first.FullName -Algorithm SHA256).Hash -eq $keptHash)
Focus; Press @(0x11, 0x4b); Query 'renamed alpha' (Index-For $firstId); Press @(0x0d)
[IO.File]::WriteAllText((Join-Path $env:MP_PICTURE_FIXTURE 'mode'), 'missing-key')
$window = Picture-Open
[VerifyNative]::Text('orange fox with glasses')
[VerifyNative]::Chord(@(0x0d))
[void](Wait-For 'missing server key is a plain failure' { [ChatDeliveryDesktop]::Text([PhotoDialogOwner]::GetDlgItem($window, 12)) -ceq 'picture service not set up' })
Shot 'picture-service-not-set-up'
Check 'missing-key-does-not-call-image-endpoint' ((Picture-Calls) -eq 3)
Picture-Cancel $window
Check 'failed-generation-keeps-current-photo' ((Get-FileHash $first.FullName -Algorithm SHA256).Hash -eq $keptHash)
Look 'bot face' 'reset to show' 7194
[void](Wait-For 'Reset removes generated picture' { -not (Test-Path $first.FullName) })
Assert-Generated (Index-For $firstId) 'picture-reset'
Check 'generated-picture-does-not-change-other-bot' ((Get-FileHash $second.FullName -Algorithm SHA256).Hash -eq $secondHash)
Copy-Item (Join-Path $env:MP_PICTURE_FIXTURE 'calls.jsonl') (Join-Path $Evidence 'picture-fake-calls.jsonl')
