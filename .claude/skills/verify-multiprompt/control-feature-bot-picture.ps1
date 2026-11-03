
            $script:botPaletteRows = @()
            $script:botPicker = [IntPtr]::Zero
            $script:botPickerSelector = ''
            $script:botPickerInput = ''
            $result.subFeatures = @('upload-picture', 'picture-survives-restart', 'cancel-keeps-picture', 'unreadable-keeps-look', 'reset-restores-face')
            function Wait-BotPaletteRows([string]$Query, [long]$From) {
                $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
                $pattern = '\[palette\] (?:rows|ready) chars=' + $Query.Length + ' count=[1-9]\d*'
                Wait-Until {
                    $text = Read-SharedText $log
                    $text.Substring([Math]::Min($From, $text.Length)) -match $pattern
                } "command palette rows for the query '$Query'" 20
                $text = Read-SharedText $log
                $matched = [regex]::Match($text.Substring([Math]::Min($From, $text.Length)), $pattern)
                $script:botPaletteRows += @($Query + ' => ' + $matched.Value)
            }
            function Invoke-BotPictureMenu([string]$Row, [string]$EnterLabel, [string]$ActionShot = '') {
                $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
                $text = Read-SharedText $log
                $from = $text.Length
                Palette 'bot face'
                Wait-BotPaletteRows 'bot face' $from
                Press @(0x0D) 'Enter: Bot face submenu'
                if ($ActionShot) { Snapshot $ActionShot }
                $text = Read-SharedText $log
                $from = $text.Length
                Type-Text $Row
                Wait-BotPaletteRows $Row $from
                Press @(0x0D) $EnterLabel
            }
            function Wait-BotFilePicker {
                Wait-Until {
                    $script:botPicker = [IntPtr]::Zero
                    foreach ($window in [VerifyNative]::DesktopWindows()) {
                        if ($window['class'] -ceq '#32770' -and [IntPtr]([long]($window['rootOwner'])) -eq $script:window -and $window['visible'] -eq $true) { $script:botPicker = [IntPtr]([long]($window['handle'])) }
                    }
                    $script:botPicker -ne [IntPtr]::Zero
                } 'real Windows picture picker owned by the main window' 30
            }
            function Get-BotPickerWindows {
                return @([VerifyNative]::DesktopWindows() | Where-Object { $_['class'] -ceq '#32770' -and [IntPtr]([long]($_['rootOwner'])) -eq $script:window })
            }
            function Wait-BotPickerClosed {
                Wait-Until { @(Get-BotPickerWindows).Count -eq 0 } 'picture picker closed' 30
            }
            function Assert-BotFilePickerForeground {
                $deadline = [DateTime]::UtcNow.AddSeconds(20)
                while ([DateTime]::UtcNow -lt $deadline) {
                    if ([VerifyNative]::GetForegroundWindow() -eq $script:botPicker) { return }
                    [void][VerifyNative]::AllowSetForegroundWindow([uint32]$process.Id)
                    [void][VerifyNative]::SetForegroundWindow($script:botPicker)
                    Start-Sleep -Milliseconds 150
                }
                throw 'The picture picker did not take the foreground; refusing to type into another window'
            }
            function Get-BotPickerChildren {
                $dialog = [System.Windows.Automation.AutomationElement]::FromHandle($script:botPicker)
                $all = @($dialog.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition))
                return @(foreach ($item in $all) { @{ name = $item.Current.Name; class = $item.Current.ClassName; automationId = $item.Current.AutomationId; type = $item.Current.ControlType.ProgrammaticName } })
            }
            function Get-BotPickerEditHandle {
                $combo_ex = [VerifyNative]::FindWindowEx($script:botPicker, [IntPtr]::Zero, 'ComboBoxEx32', $null)
                if ($combo_ex -ne [IntPtr]::Zero) {
                    $combo = [VerifyNative]::FindWindowEx($combo_ex, [IntPtr]::Zero, 'ComboBox', $null)
                    if ($combo -ne [IntPtr]::Zero) {
                        $inner = [VerifyNative]::FindWindowEx($combo, [IntPtr]::Zero, 'Edit', $null)
                        if ($inner -ne [IntPtr]::Zero) { $script:botPickerSelector = 'Edit inside the ComboBoxEx32 file name box'; return $inner }
                    }
                    $nested = [VerifyNative]::FindWindowEx($combo_ex, [IntPtr]::Zero, 'Edit', $null)
                    if ($nested -ne [IntPtr]::Zero) { $script:botPickerSelector = 'Edit child of the ComboBoxEx32 file name box'; return $nested }
                }
                $direct = [VerifyNative]::FindWindowEx($script:botPicker, [IntPtr]::Zero, 'Edit', $null)
                if ($direct -ne [IntPtr]::Zero) { $script:botPickerSelector = 'Edit child of the picker'; return $direct }
                return [IntPtr]::Zero
            }
            function Set-BotPickerText([IntPtr]$Edit, [string]$Text) {
                [void][VerifyNative]::PostMessage($Edit, 0x00B1, [UIntPtr]::Zero, [IntPtr](-1))
                Start-Sleep -Milliseconds 100
                foreach ($character in $Text.ToCharArray()) {
                    [void][VerifyNative]::PostMessage($Edit, 0x0102, [UIntPtr][uint32][char]$character, [IntPtr]1)
                    Start-Sleep -Milliseconds 15
                }
                Start-Sleep -Milliseconds 300
            }
            function Enter-BotPicturePath([string]$Path) {
                Assert-BotFilePickerForeground
                $edit = Get-BotPickerEditHandle
                if ($edit -eq [IntPtr]::Zero) {
                    Save-Json (Get-BotPickerChildren) 'picture-picker-children.json'
                    throw 'The picture picker exposes no Edit inside its ComboBoxEx32 file name box'
                }
                Set-BotPickerText $edit $Path
                $script:botPickerInput = 'selected all then posted characters into the file name Edit'
                Press @(0x0D) 'Enter: pick the picture'
                try {
                    Wait-BotPickerClosed
                } catch {
                    if (@(Get-BotPickerWindows).Count -eq 0) { return }
                    Record 'The picker stayed open; set the file name field once more'
                    Assert-BotFilePickerForeground
                    $again = Get-BotPickerEditHandle
                    if ($again -eq [IntPtr]::Zero) { throw 'The picture picker file name field disappeared before the retry' }
                    Set-BotPickerText $again $Path
                    Press @(0x0D) 'Enter: pick the picture again'
                    Wait-BotPickerClosed
                }
            }
            function Get-BotSavedPicture {
                $path = Join-Path $scratch 'roaming/ZigShell/session.json'
                if (-not (Test-Path -LiteralPath $path)) { return [uint64]0 }
                $raw = Read-SharedText $path
                $found = [regex]::Matches($raw, '"picture"\s*:\s*(\d+)')
                if ($found.Count -eq 0) { return [uint64]0 }
                if ($found.Count -gt 1) { throw "The saved session carries $($found.Count) picture numbers; this journey drives one saved tab" }
                return [uint64]($found[0].Groups[1].Value)
            }
            function Get-BotPictureStore([uint64]$Picture) {
                $directory = Join-Path $scratch 'roaming/ZigShell/bot-pictures'
                $expected = Join-Path $directory (('{0:x16}' -f $Picture) + '.img')
                $files = @(Get-ChildItem -LiteralPath $directory -Filter '*.img' -ErrorAction SilentlyContinue)
                if (-not (Test-Path -LiteralPath $expected)) {
                    $listing = @($files | ForEach-Object { $_.Name }) -join ', '
                    throw "No $($Picture.ToString('x16')).img copy for the saved picture number $Picture; the store holds $listing"
                }
                return @{ directory = $directory; file = $expected; match = 'hex-name'; count = $files.Count }
            }
            function Get-BotPicturePixels([string]$Name) {
                WindowShot $Name
                $image = [Drawing.Bitmap]::FromFile((Join-Path $Evidence ($Name + '.png')))
                try {
                    $count = 0
                    $left = -1
                    $top = -1
                    $right = -1
                    $bottom = -1
                    $columns = [Math]::Min(60, $image.Width)
                    $rows = [Math]::Min(300, $image.Height)
                    for ($x = 0; $x -lt $columns; $x++) {
                        for ($y = 0; $y -lt $rows; $y++) {
                            $pixel = $image.GetPixel($x, $y)
                            if ([Math]::Abs($pixel.R - 255) -le 24 -and [Math]::Abs($pixel.G - 0) -le 24 -and [Math]::Abs($pixel.B - 160) -le 24) {
                                $count++
                                if ($left -lt 0 -or $x -lt $left) { $left = $x }
                                if ($x -gt $right) { $right = $x }
                                if ($top -lt 0 -or $y -lt $top) { $top = $y }
                                if ($y -gt $bottom) { $bottom = $y }
                            }
                        }
                    }
                    $width = 0
                    $height = 0
                    if ($left -ge 0) {
                        $width = $right - $left + 1
                        $height = $bottom - $top + 1
                    }
                    return @{ shot = $Name; count = $count; left = $left; top = $top; width = $width; height = $height }
                } finally { $image.Dispose() }
            }
            function Assert-BotPictureDrawn([string]$Name, [int]$Minimum) {
                $shot = Get-BotPicturePixels $Name
                if ($shot.count -lt $Minimum) { throw "The bot face area drew $($shot.count) picture pixels in $Name.png; expected at least $Minimum" }
                $skew = [Math]::Abs($shot.width - $shot.height)
                if ($skew -gt 4) { throw "The drawn picture is not the round bot face: $($shot.width)x$($shot.height) pixels in $Name.png" }
                return $shot
            }
            Doctor
            Snapshot 'before'
            $pictureBefore = Get-BotPicturePixels 'picture-before'
            if ($pictureBefore.count -gt 2) { throw "The baseline bot face already draws $($pictureBefore.count) picture pixels" }
            $fixture = Join-Path $scratch 'bot-picture.png'
            $fixtureImage = New-Object Drawing.Bitmap(96, 72)
            $fixtureGraphics = [Drawing.Graphics]::FromImage($fixtureImage)
            try {
                $fixtureGraphics.Clear([Drawing.Color]::FromArgb(255, 255, 0, 160))
                $fixturePen = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::White), ([single]6)
                try {
                    $fixtureGraphics.DrawLine($fixturePen, 0, 0, 95, 71)
                    $fixtureGraphics.DrawLine($fixturePen, 95, 0, 0, 71)
                } finally { $fixturePen.Dispose() }
                $fixtureImage.Save($fixture, [Drawing.Imaging.ImageFormat]::Png)
            } finally { $fixtureGraphics.Dispose(); $fixtureImage.Dispose() }
            $result.pictureFixture = $fixture
            Record "Fixture: 96x72 PNG, solid 255,0,160 with a white cross at $fixture"
            $uploadCheck = @{ name = 'upload-picture'; passed = $false; baselinePixels = $pictureBefore.count }
            $result.checks += $uploadCheck
            Invoke-BotPictureMenu 'upload image' 'Enter: Upload image' 'action'
            Wait-BotFilePicker
            Enter-BotPicturePath $fixture
            $result.fileDialog = @{ windowClass = '#32770'; owner = 'main window root owner'; selector = $script:botPickerSelector; input = $script:botPickerInput; path = $fixture }
            Wait-Until { (Get-BotSavedPicture) -gt 0 } 'saved active tab carries a copied picture number' 30
            Press @(0x1B) 'Esc: close the bot-look palette after picking'
            $uploadedPicture = Get-BotSavedPicture
            $uploadedStore = Get-BotPictureStore $uploadedPicture
            Snapshot 'uploaded'
            $uploaded = Assert-BotPictureDrawn 'picture-uploaded' 100
            $uploadCheck.picture = $uploadedPicture
            $uploadCheck.storeFile = $uploadedStore.match
            $uploadCheck.storeCount = $uploadedStore.count
            $uploadCheck.pixels = $uploaded.count
            $uploadCheck.boundingBox = @{ left = $uploaded.left; top = $uploaded.top; width = $uploaded.width; height = $uploaded.height }
            $uploadCheck.passed = $true
            $cancelCheck = @{ name = 'cancel-keeps-picture'; passed = $false }
            $result.checks += $cancelCheck
            Invoke-BotPictureMenu 'upload image' 'Enter: Upload image'
            Wait-BotFilePicker
            Press @(0x1B) 'Esc: cancel the picture picker'
            Wait-BotPickerClosed
            Press @(0x1B) 'Esc: close the bot-look palette after cancelling'
            $cancelPicture = Get-BotSavedPicture
            if ($cancelPicture -ne $uploadedPicture) { throw "Cancelling the picker changed the saved picture: $uploadedPicture -> $cancelPicture" }
            $cancelled = Get-BotPicturePixels 'picture-cancel'
            if ($cancelled.count -ne $uploaded.count) { throw "Cancelling the picker changed the drawn picture: $($uploaded.count) -> $($cancelled.count) picture pixels" }
            $cancelCheck.picture = $cancelPicture
            $cancelCheck.pixels = $cancelled.count
            $cancelCheck.passed = $true
            $unreadableCheck = @{ name = 'unreadable-keeps-look'; passed = $false }
            $result.checks += $unreadableCheck
            $broken = Join-Path $scratch 'broken.png'
            Set-Content -LiteralPath $broken -Value 'This file is text, not a picture.' -Encoding ASCII
            Invoke-BotPictureMenu 'upload image' 'Enter: Upload image'
            Wait-BotFilePicker
            Enter-BotPicturePath $broken
            $noticeLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
            Wait-Until {
                $noticeText = Read-SharedText $noticeLog
                $noticeText -match 'Could not read that picture'
            } 'header notice for the unreadable picture' 30
            Press @(0x1B) 'Esc: close the bot-look palette after the unreadable pick'
            $unreadablePicture = Get-BotSavedPicture
            if ($unreadablePicture -ne $uploadedPicture) { throw "An unreadable picture changed the saved picture: $uploadedPicture -> $unreadablePicture" }
            $unreadable = Get-BotPicturePixels 'picture-unreadable'
            if ($unreadable.count -ne $uploaded.count) { throw "An unreadable picture changed the drawn look: $($uploaded.count) -> $($unreadable.count) picture pixels" }
            Snapshot 'unreadable'
            $unreadableCheck.picture = $unreadablePicture
            $unreadableCheck.pixels = $unreadable.count
            $unreadableCheck.notice = 'Could not read that picture'
            $unreadableCheck.passed = $true
            $restartCheck = @{ name = 'picture-survives-restart'; passed = $false }
            $result.checks += $restartCheck
            Restart-SessionRestore 'restart' $false
            $restartPicture = Get-BotSavedPicture
            if ($restartPicture -ne $uploadedPicture) { throw "The restored tab lost its picture number: $uploadedPicture -> $restartPicture" }
            $restartStore = Get-BotPictureStore $restartPicture
            Snapshot 'restart'
            $restarted = Assert-BotPictureDrawn 'picture-restart' 100
            $restartCheck.picture = $restartPicture
            $restartCheck.storeFile = $restartStore.match
            $restartCheck.pixels = $restarted.count
            $restartCheck.boundingBox = @{ left = $restarted.left; top = $restarted.top; width = $restarted.width; height = $restarted.height }
            $restartCheck.passed = $true
            $resetCheck = @{ name = 'reset-restores-face'; passed = $false; baselinePixels = $pictureBefore.count }
            $result.checks += $resetCheck
            Invoke-BotPictureMenu 'reset picture' 'Enter: Reset picture'
            Wait-Until { (Get-BotSavedPicture) -eq 0 } 'saved active tab carries no picture number after Reset picture' 30
            Press @(0x1B) 'Esc: close the bot-look palette after resetting'
            $reset = Get-BotPicturePixels 'picture-reset'
            if ($reset.count -ne $pictureBefore.count) { throw "Reset picture left $($reset.count) picture pixels; the baseline drew $($pictureBefore.count)" }
            Snapshot 'reset'
            $resetCheck.picture = 0
            $resetCheck.pixels = $reset.count
            $resetCheck.passed = $true
            $result.paletteRows = $script:botPaletteRows
            foreach ($name in $result.subFeatures) {
                if (@($result.checks | Where-Object { $_.name -ceq $name }).Count -ne 1) { throw "Required bot picture check missing or duplicated: $name" }
            }
            if ($result.checks.Count -ne $result.subFeatures.Count) { throw 'Every bot picture sub-feature needs exactly one check' }
            Snapshot 'after'
