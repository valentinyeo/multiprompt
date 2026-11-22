
            function Save-CaretSample([string]$Label, [VerifyNative+CaretSnapshot]$Sample) {
                Save-Json @{ label = $Label; left = $Sample.CaretRect.Left; top = $Sample.CaretRect.Top; right = $Sample.CaretRect.Right; bottom = $Sample.CaretRect.Bottom; caret = $Sample.Caret.ToInt64() } ("caret-$Label.json")
            }
            function CaretSampleNonEmpty([VerifyNative+CaretSnapshot]$Sample) {
                return $Sample.CaretRect.Right -gt $Sample.CaretRect.Left -and $Sample.CaretRect.Bottom -gt $Sample.CaretRect.Top
            }
            function Get-CaretRect {
                param([string]$Label)
                Doctor
                Assert-Foreground
                $sample = [VerifyNative]::GuiCaretSnapshot($script:window)
                Save-CaretSample $Label $sample
                if (-not (CaretSampleNonEmpty $sample)) { throw "session-caret: $Label caret rectangle is empty" }
                return $sample.CaretRect
            }
            function Assert-CaretBlink {
                if ([VerifyNative]::CaretBlinkTime() -eq [uint32]::MaxValue) { return }
                Doctor
                Assert-Foreground
                $motion = [VerifyNative]::CaretPixelMotionMs($script:window, 2000, 50)
                Save-Json @{ motionMs = $motion } 'caret-blink-motion.json'
                if ($motion -lt 0) { throw 'session-caret: caret did not blink within 2000ms' }
            }
            Wait-Until { $null -ne (Read-Session) -and @((Read-Session).tabs).Count -ge 1 } 'initial CMD session'
            Type-Text 'abc'
            Snapshot 'console-typing'
            Assert-CaretBlink
            $notepad = Start-Process notepad -PassThru
            try {
                Wait-Until { [VerifyNative]::GetForegroundWindow() -ne $script:window } 'focus left the owned app' 5
                [VerifyNative]::BringToForeground($script:window)
                Wait-Until { [VerifyNative]::GetForegroundWindow() -eq $script:window } 'owned app foreground restored' 10
            } finally {
                if (-not $notepad.HasExited) { Stop-Process -Id $notepad.Id -Force -ErrorAction SilentlyContinue }
            }
            Get-CaretRect 'after-alt-tab'
            Press @(0x12, 0x43) 'Alt+C: open Chat View'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and $state.tabs[$state.active_tab].cv -eq $true
            } 'Chat View on the CMD session'
            Wait-Until { [VerifyNative]::GetFocusedWindow($script:window) -ne [IntPtr]::Zero } 'composer focused after Chat View'
            Type-Text 'abc'
            Get-CaretRect 'composer-typing'
            Snapshot 'after'
            $result.checks += @{ name = 'session-caret'; consoleBlink = $true; afterReturn = $true; composerCaret = $true }