
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
            function Test-ChatViewOpen {
                $state = Read-Session
                if ($null -eq $state -or -not $state.PSObject.Properties['tabs'] -or -not $state.PSObject.Properties['active_tab']) { return $false }
                $tabs = @($state.tabs)
                if ($null -eq $state.active_tab -or $state.active_tab -lt 0 -or $state.active_tab -ge $tabs.Count) { return $false }
                $tab = $tabs[$state.active_tab]
                if ($null -eq $tab -or -not $tab.PSObject.Properties['cv']) { return $false }
                return $tab.cv -eq $true
            }
            function Open-ChatView {
                $toggleReady = [DateTime]::UtcNow
                for ($attempt = 1; $attempt -le 3; $attempt++) {
                    Wait-Until { [DateTime]::UtcNow -ge $toggleReady } 'Alt+C debounce elapsed before opening Chat View'
                    Press @(0x12, 0x43) "Alt+C: open Chat View attempt $attempt"
                    $toggleReady = [DateTime]::UtcNow.AddMilliseconds(1600)
                    try {
                        Wait-Until { Test-ChatViewOpen } 'Chat View on the CMD session' 6
                        return
                    } catch {
                        Save-Json @{ attempt = $attempt; error = $_.Exception.Message } "chat-view-attempt-$attempt.json"
                        if ($attempt -eq 3) { throw }
                    }
                }
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
                [void]$notepad.WaitForExit(5000)
            }
            Wait-Until { [VerifyNative]::GetForegroundWindow() -eq $script:window } 'owned app stays foreground after Notepad closed' 10
            Get-CaretRect 'after-alt-tab'
            Open-ChatView
            Wait-Until { [VerifyNative]::GetFocusedWindow($script:window) -ne [IntPtr]::Zero } 'composer focused after Chat View'
            Type-Text 'abc'
            Get-CaretRect 'composer-typing'
            Snapshot 'after'
            $result.checks += @{ name = 'session-caret'; consoleBlink = $true; afterReturn = $true; composerCaret = $true }