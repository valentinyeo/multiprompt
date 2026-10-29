
            $composerCheck = @{ name = 'IGSH-731 composer edges'; passed = $false; fontSmoothing = [VerifyNative]::FontSmoothing() }
            $result.checks += $composerCheck
            $typingCheck = @{ name = 'IGSH-760 typing frames steady'; passed = $false }
            $result.checks += $typingCheck
            $stripCheck = @{ name = 'IGSH-805 composer has no unpainted strip'; passed = $false }
            $result.checks += $stripCheck
            Select-Theme 'dark' 'composer-dark'
            Snapshot 'before'
            Press @(0x12, 0x43) 'Alt+C: open Chat View for the composer'
            Wait-Until {
                $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
                $script:composerElement = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
                $null -ne $script:composerElement -and -not $script:composerElement.Current.IsOffscreen
            } 'owned visible composer after Alt+C'
            $handle = [IntPtr]$script:composerElement.Current.NativeWindowHandle
            if ($script:composerElement.Current.ProcessId -ne $process.Id -or [VerifyNative]::GetAncestor($handle, 2) -ne $script:window) { throw 'Composer is not owned by this app' }
            [VerifyNative]::BringToForeground($script:window)
            Record 'Click the owned composer to recover typing focus from the hidden console'
            [VerifyNative]::ClickClient($handle, 8, 8)
            Wait-ChatFocus 'Edit' 'composer-open'
            $sentence = 'The message box should look as smooth as the chat text.'
            Assert-ChatTyping $sentence 'composer-typed'
            Snapshot 'action'
            Snapshot 'after'
            $composer = [System.Windows.Automation.AutomationElement]::FocusedElement
            $state = Read-Session
            $dpi = [VerifyNative]::GetDpiForWindow($script:window)
            $em = [int][Math]::Floor(16 * $dpi / 96)
            $row = [VerifyNative]::ComposerRow([IntPtr]$composer.Current.NativeWindowHandle, $sentence.Length, $em)
            $frame = New-Object VerifyNative+Rect
            if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame)) { throw 'Composer frame unavailable' }
            $rect = @{ left = $row[0] - $frame.Left; top = $row[1] - $frame.Top; right = $row[2] - $frame.Left; bottom = $row[3] - $frame.Top }
            $client = New-Object VerifyNative+Rect
            $origin = New-Object VerifyNative+Point
            if (-not [VerifyNative]::GetClientRect($handle, [ref]$client) -or -not [VerifyNative]::ClientToScreen($handle, [ref]$origin)) { throw 'Composer client rectangle unavailable' }
            $clientRect = @{ left = $origin.X + $client.Left - $frame.Left; top = $origin.Y + $client.Top - $frame.Top; right = $origin.X + $client.Right - $frame.Left; bottom = $origin.Y + $client.Bottom - $frame.Top }
            Save-Json @{ rect = $rect; clientRect = $clientRect; fontSmoothing = [VerifyNative]::FontSmoothing(); text = $sentence; dpi = $dpi } 'composer-live.json'
            [VerifyNative]::Bmp((Join-Path $Evidence 'after.png'), (Join-Path $Evidence 'composer-live.bmp'))
            & node (Join-Path $PSScriptRoot '../../../tools/chat-composer-text-proof.mjs') $Evidence --strip
            $stripExit = $LASTEXITCODE
            $stripSummary = Get-Content (Join-Path $Evidence 'composer-strip-summary.json') -Raw | ConvertFrom-Json
            foreach ($property in $stripSummary.PSObject.Properties) { $stripCheck[$property.Name] = $property.Value }
            if ($stripExit -ne 0 -or -not $stripCheck.passed) { throw 'IGSH-805 composer has no unpainted strip: full client contains a contrasting horizontal run' }
            $prefixRow = [VerifyNative]::ComposerRow($handle, 12, $em)
            $composerFrame = New-Object VerifyNative+Rect
            if (-not [VerifyNative]::GetWindowRect($handle, [ref]$composerFrame)) { throw 'Composer typing rectangle unavailable' }
            $typingCrop = New-Object VerifyNative+Rect
            $typingCrop.Left = $composerFrame.Left - 1
            $typingCrop.Top = $composerFrame.Top - 1
            $typingCrop.Right = [Math]::Min($composerFrame.Right - 1, $row[2] + 5 * $em)
            $typingCrop.Bottom = [Math]::Min($composerFrame.Bottom, $row[3] + 2)
            $inkRect = @{ left = [Math]::Max($prefixRow[0], $typingCrop.Left) - $typingCrop.Left; top = [Math]::Max($prefixRow[1], $typingCrop.Top) - $typingCrop.Top; right = [Math]::Min($prefixRow[2], $typingCrop.Right) - $typingCrop.Left; bottom = [Math]::Min($prefixRow[3], $typingCrop.Bottom) - $typingCrop.Top }
            $rowRect = @{ left = [Math]::Max($row[0], $typingCrop.Left) - $typingCrop.Left; top = [Math]::Max($row[1], $typingCrop.Top) - $typingCrop.Top; right = [Math]::Min($row[2], $typingCrop.Right) - $typingCrop.Left; bottom = [Math]::Min($row[3], $typingCrop.Bottom) - $typingCrop.Top }
            Press @(0x11, 0x41) 'Ctrl+A: select settled sentence before typing burst'
            Press @(0x08) 'Backspace: empty owned composer before typing burst'
            Assert-ChatTyping $sentence 'composer-typing-burst' {
                Doctor
                Assert-Foreground
                Record ('Type with concurrent composer-row BitBlt: ' + $sentence)
                $burst = [VerifyNative]::ComposerTypingFrames($script:window, $handle, $sentence, $typingCrop, $Evidence)
                $burst['inkRect'] = $inkRect
                $burst['rowRect'] = $rowRect
                Save-Json $burst 'composer-typing.json'
            }
            Snapshot 'composer-typing-after'
            & node (Join-Path $PSScriptRoot '../../../tools/chat-composer-text-proof.mjs') $Evidence --typing
            $typingSummary = Get-Content (Join-Path $Evidence 'composer-typing-summary.json') -Raw | ConvertFrom-Json
            foreach ($property in $typingSummary.PSObject.Properties) { $typingCheck[$property.Name] = $property.Value }
            & node (Join-Path $PSScriptRoot '../../../tools/chat-composer-text-proof.mjs') $Evidence
            $summary = Get-Content (Join-Path $Evidence 'composer-live-summary.json') -Raw | ConvertFrom-Json
            $composerCheck.measurement = $summary.measurement
            $composerCheck.passed = $summary.passed -eq $true
            $composerCheck.threshold = $summary.threshold
            if (-not $typingCheck.passed) { throw 'IGSH-760 typing frames steady: transient ink loss, changed background/border, or insufficient typing frames' }
            if (-not $composerCheck.passed) { throw 'IGSH-731 composer edges: hard-edge fraction must be below 0.18 with system font smoothing OFF' }
            if (-not $env:RELEASE_TAG) {
                $native = Get-Content (Join-Path $Evidence 'composer-native-summary.json') -Raw | ConvertFrom-Json
                $result.checks += @{ name = 'IGSH-731 composer native scale and DPI'; passed = $native.passed; checks = $native.checks }
                if (-not $native.passed) { throw 'IGSH-731 composer native painter proof failed' }
            }
            Add-Type -AssemblyName System.Windows.Forms
            $pasteCheck = @{ name = 'IGSH-895 exact composer paste'; passed = $false; cases = @() }
            $result.checks += $pasteCheck
            foreach ($trailing in @('', "`r`n")) {
                Press @(0x11, 0x41) 'Ctrl+A: select the owned draft'
                Press @(0x08) 'Backspace: clear before the paste check'
                $prefix = 'I cannot send '
                $pasted = 'screenshots https://example.invalid/image.png' + $trailing
                Assert-ChatTyping $prefix 'paste-prefix'
                [System.Windows.Forms.Clipboard]::SetText($pasted)
                Press @(0x11, 0x56) 'Ctrl+V: paste clipboard text at the caret'
                $expected = $prefix + $pasted
                Wait-Until { [VerifyNative]::EditText($handle) -ceq $expected } 'paste contains exactly typed plus clipboard text'
                $pasteCheck.cases += @{ clipboard = $pasted; expected = $expected; actual = [VerifyNative]::EditText($handle) }
                Snapshot ('paste-' + $trailing.Length)
            }
            $pasteCheck.passed = $true
            Save-Json $pasteCheck 'composer-paste.json'
        