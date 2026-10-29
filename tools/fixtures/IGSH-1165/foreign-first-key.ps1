Doctor
                        Record "IGSH-1126 $Page immediate Alt+A pair $i"
                        [VerifyNative]::BringToForeground($script:window)
                        Wait-Foreground
                        $before = @(Select-String -Path $debug -Pattern 'shortcutToggle enabled=').Count
                        $completion = [Diagnostics.Stopwatch]::StartNew()
                        $gap = [VerifyNative]::ImmediateBrowserTogglePair(50)
