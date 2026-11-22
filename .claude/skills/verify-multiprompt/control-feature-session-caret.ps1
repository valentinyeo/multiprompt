
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
            function Test-CaretMotion([VerifyNative+CaretSnapshot]$First, [VerifyNative+CaretSnapshot]$Second) {
                if ($First.Caret -ne $Second.Caret) { return $true }
                $firstEmpty = -not (CaretSampleNonEmpty $First)
                $secondEmpty = -not (CaretSampleNonEmpty $Second)
                if ($firstEmpty -ne $secondEmpty) { return $true }
                if ($firstEmpty) { return $false }
                if ($First.CaretRect.Left -ne $Second.CaretRect.Left -or $First.CaretRect.Top -ne $Second.CaretRect.Top -or $First.CaretRect.Right -ne $Second.CaretRect.Right -or $First.CaretRect.Bottom -ne $Second.CaretRect.Bottom) { return $true }
                return $false
            }
            function Assert-CaretBlink {
                if ([VerifyNative]::CaretBlinkTime() -eq [uint32]::MaxValue) { return }
                $deadline = [DateTime]::UtcNow.AddMilliseconds(2000)
                $sample = 0
                $previous = $null
                while ([DateTime]::UtcNow -lt $deadline) {
                    Doctor
                    Assert-Foreground
                    $current = [VerifyNative]::GuiCaretSnapshot($script:window)
                    Save-CaretSample ('blink-' + $sample) $current
                    if (-not (CaretSampleNonEmpty $current)) { throw ('session-caret: blink-' + $sample + ' caret rectangle is empty') }
                    if ($null -ne $previous -and (Test-CaretMotion $previous $current)) { return }
                    $previous = $current
                    $sample++
                    Start-Sleep -Milliseconds 100
                }
                throw 'session-caret: caret did not blink within 2000ms'
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