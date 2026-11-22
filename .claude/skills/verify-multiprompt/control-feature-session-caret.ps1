
            function Get-CaretRect {
                param([string]$Label)
                Doctor
                Assert-Foreground
                $rect = [VerifyNative]::CaretRect($script:window)
                Save-Json @{ label = $Label; left = $rect.Left; top = $rect.Top; right = $rect.Right; bottom = $rect.Bottom } ("caret-$Label.json")
                if ($rect.Right -le $rect.Left -or $rect.Bottom -le $rect.Top) { throw "session-caret: $Label caret rectangle is empty" }
                return $rect
            }
            function Assert-CaretBlink {
                $first = Get-CaretRect 'blink-a'
                Start-Sleep -Milliseconds 500
                $second = Get-CaretRect 'blink-b'
                if ($first.Left -eq $second.Left -and $first.Top -eq $second.Top -and $first.Right -eq $second.Right -and $first.Bottom -eq $second.Bottom) {
                    throw 'session-caret: caret did not blink within 500ms'
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