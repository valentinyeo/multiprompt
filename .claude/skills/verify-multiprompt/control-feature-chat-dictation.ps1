
            Select-Theme 'dark' 'dictation-dark'
            Press @(0x12, 0x43) 'Alt+C: open Chat View for dictation'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and @($state.tabs).Count -eq 1 -and $state.tabs[0].PSObject.Properties['cv'] -and $state.tabs[0].cv
            } 'isolated CMD session saved in Chat View'
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
            Wait-ChatFocus 'Edit' 'dictation-composer'
            $composer = [System.Windows.Automation.AutomationElement]::FocusedElement
            $handle = [IntPtr]$composer.Current.NativeWindowHandle
            if ($composer.Current.ProcessId -ne $process.Id -or [VerifyNative]::GetAncestor($handle, 2) -ne $script:window) { throw 'Dictation requires the owned composer' }
            $mic = Get-DictationMic $handle
            Assert-DictationMic $mic $false 'dictation-idle'
            $micLive = @(($mic[0] - 84), $mic[1], $mic[2], $mic[3])
            if (($mic[2] - $mic[0]) -ne ($mic[3] - $mic[1])) { throw 'IGSH-887 the idle microphone must be a round button' }
            Snapshot 'before'
            $auditPath = Join-Path $scratch 'roaming/ZigShell/dictation-audit.log'
            $iteration = 0
            foreach ($stop in @('enter', 'ctrl-d', 'mic-click')) {
                if ([VerifyNative]::EditText($handle) -cne '') { throw 'Dictation case must start with an empty message box' }
                Press @(0x11, 0x44) 'Ctrl+D: start composer dictation'
                $iteration++
                if ($env:VERIFY_DICTATION_STALL -eq '1') {
                    Wait-Until { $false } 'deliberately stalled recorded PCM capture precondition' -Seconds 1 -PollMilliseconds 20
                }
                Wait-Until {
                    (Test-Path $auditPath) -and @((Read-DictationAudit $auditPath) | Where-Object { $_ -match '\tfixture-audio-bytes\t89160$' }).Count -eq $iteration
                } 'recorded PCM reached the real capture worker' -Seconds 2 -PollMilliseconds 20
                Assert-DictationMic $micLive $true ($stop + '-listening')
                if ($stop -ceq 'enter') {
                    $pillTimer = @(($micLive[0] + 26), $micLive[1], ($micLive[0] + 64), $micLive[3])
                    $pillWave = @(($micLive[0] + 68), ($micLive[1] + 6), ($micLive[2] - 16), ($micLive[3] - 6))
                    WindowShot 'recording-0'
                    $script:pillShot = 0
                    $script:timerDiff = 0
                    $script:waveDiff = 0
                    Wait-Until {
                        $script:pillShot++
                        WindowShot ('recording-' + $script:pillShot)
                        $first = Join-Path $Evidence 'recording-0.png'
                        $later = Join-Path $Evidence ('recording-' + $script:pillShot + '.png')
                        $script:timerDiff = [VerifyNative]::RegionDiff($first, $later, $script:window, $pillTimer[0], $pillTimer[1], $pillTimer[2], $pillTimer[3])
                        $script:waveDiff = [VerifyNative]::RegionDiff($first, $later, $script:window, $pillWave[0], $pillWave[1], $pillWave[2], $pillWave[3])
                        $script:timerDiff -gt 20 -and $script:waveDiff -gt 20
                    } 'IGSH-887 the recording pill timer counts up and the wave moves' -Seconds 6 -PollMilliseconds 250
                    Copy-Item (Join-Path $Evidence ('recording-' + $script:pillShot + '.png')) (Join-Path $Evidence 'recording-pill.png')
                    $result.micPill = @{ passed = $true; timerDiffPixels = $script:timerDiff; waveDiffPixels = $script:waveDiff; pillRect = $micLive }
                }
                $typed = 'typing-' + $stop
                Type-Text $typed
                Wait-Until { [VerifyNative]::EditText($handle) -ceq $typed } 'IGSH-812 typing is accepted while listening' -Seconds 1 -PollMilliseconds 10
                if ([VerifyNative]::GetFocusedWindow($script:window) -ne $handle) { throw 'Dictation stole native composer typing focus' }
                Assert-DictationMic $micLive $true ($stop + '-typed-listening')
                Snapshot ($stop + '-listening')
                if ($stop -ceq 'enter') { Snapshot 'action' }
                Doctor
                Assert-Foreground
                Record ('Stop dictation with ' + $stop)
                $immediate = [Diagnostics.Stopwatch]::StartNew()
                switch ($stop) {
                    'enter' { [VerifyNative]::Chord(@(0x0D)) }
                    'ctrl-d' { [VerifyNative]::Chord(@(0x11, 0x44)) }
                    'mic-click' { [VerifyNative]::ClickClient($script:window, [int](($mic[0] + $mic[2]) / 2), [int](($mic[1] + $mic[3]) / 2)) }
                }
                $expected = $typed + ' Go forward ten meters.'
                Wait-Until { [VerifyNative]::EditText($handle) -ceq $expected } 'IGSH-812 transcript appears immediately without another input' -Seconds 1 -PollMilliseconds 10
                $elapsed = $immediate.ElapsedMilliseconds
                if ($elapsed -gt 1000) { throw "IGSH-812 transcript was not immediate: $elapsed ms" }
                Save-Json @{ WM_GETTEXT = [VerifyNative]::EditText($handle); expected = $expected; elapsedMilliseconds = $elapsed; handle = $handle.ToInt64(); pid = $process.Id } ($stop + '.text.json')
                Assert-DictationMic $mic $false ($stop + '-stopped')
                $audit = @((Read-DictationAudit $auditPath))
                foreach ($stage in @('audio-bytes\t89160', 'fixture-response-bytes\t101', 'http-status\t200', 'target-chat-composer\t22')) {
                    if (@($audit | Where-Object { $_ -match ('\t' + $stage + '$') }).Count -ne $iteration) { throw "IGSH-812 missing production transcription stage $stage" }
                }
                Snapshot ($stop + '-delivered')
                $result.checks += @{ name = ('dictation-' + $stop); passed = $true; typedWhileListening = $typed; WM_GETTEXT = [VerifyNative]::EditText($handle); elapsedMilliseconds = $elapsed; activeMicPixels = $true; idleMicPixels = $true }
                if ($stop -cne 'mic-click') {
                    Press @(0x11, 0x41) 'Ctrl+A: select the verified dictation draft'
                    Press @(0x08) 'Backspace: clear the draft through normal keyboard input'
                    Wait-Until { [VerifyNative]::EditText($handle) -ceq '' } 'composer cleared for next independent stop case'
                }
            }
            if ($result.checks.Count -ne 3) { throw 'IGSH-812 requires all three dictation stop cases' }
            $draft = [VerifyNative]::EditText($handle)
            Press @(0x11, 0x44) 'Ctrl+D: start dictation over the existing draft'
            $iteration++
            Wait-Until {
                @((Read-DictationAudit $auditPath) | Where-Object { $_ -match '\tfixture-audio-bytes\t89160$' }).Count -eq $iteration
            } 'IGSH-846 cancellation recording reached the real capture worker' -Seconds 2 -PollMilliseconds 20
            Assert-DictationMic $micLive $true 'escape-listening'
            Type-Text ' keep this'
            $draft += ' keep this'
            Wait-Until { [VerifyNative]::EditText($handle) -ceq $draft } 'IGSH-846 draft includes typing during recording'
            Press @(0x1B, 0x1B) 'Escape with a repeated keydown: discard the recording once'
            Wait-Until {
                $audit = @((Read-DictationAudit $auditPath))
                @($audit | Where-Object { $_ -match '\tcancel\t0$' }).Count -eq 1 -and
                    @($audit | Where-Object { $_ -match '\taudio-bytes\t89160$' }).Count -eq $iteration
            } 'IGSH-846 cancellation stopped the capture worker' -Seconds 2 -PollMilliseconds 20
            Assert-DictationMic $mic $false 'escape-cancelled'
            if ([VerifyNative]::EditText($handle) -cne $draft) { throw 'IGSH-846 Escape changed the existing draft' }
            Snapshot 'escape-cancelled'
            $result.checks += @{ name = 'dictation-escape'; passed = $true; WM_GETTEXT = $draft; idleMicPixels = $true }
            $delivered = $iteration - 1
            Press @(0x11, 0x44) 'Ctrl+D: restart dictation after cancellation'
            $iteration++
            Wait-Until {
                @((Read-DictationAudit $auditPath) | Where-Object { $_ -match '\tfixture-audio-bytes\t89160$' }).Count -eq $iteration
            } 'IGSH-846 a new recording starts after cancellation' -Seconds 2 -PollMilliseconds 20
            Assert-DictationMic $micLive $true 'escape-restarted'
            if ([VerifyNative]::EditText($handle) -cne $draft) { throw 'IGSH-846 cancelled transcript arrived late' }
            $audit = @((Read-DictationAudit $auditPath))
            foreach ($stage in @('fixture-response-bytes\t101', 'http-status\t200', 'target-chat-composer\t22')) {
                if (@($audit | Where-Object { $_ -match ('\t' + $stage + '$') }).Count -ne $delivered) { throw "IGSH-846 cancelled recording reached transcription or delivery: $stage" }
            }
            Press @(0x0D) 'Enter: transcribe only the restarted recording'
            $expected = $draft + ' Go forward ten meters.'
            Wait-Until { [VerifyNative]::EditText($handle) -ceq $expected } 'IGSH-846 restarted recording delivers exactly once' -Seconds 1 -PollMilliseconds 10
            Assert-DictationMic $mic $false 'escape-restart-stopped'
            $audit = @((Read-DictationAudit $auditPath))
            foreach ($stage in @('fixture-response-bytes\t101', 'http-status\t200', 'target-chat-composer\t22')) {
                if (@($audit | Where-Object { $_ -match ('\t' + $stage + '$') }).Count -ne ($delivered + 1)) { throw "IGSH-846 restarted recording did not deliver exactly once: $stage" }
            }
            Save-Json @{ preservedDraft = $draft; WM_GETTEXT = [VerifyNative]::EditText($handle); audit = $audit } 'escape-restart.text.json'
            $result.checks += @{ name = 'dictation-escape-restart'; passed = $true; WM_GETTEXT = [VerifyNative]::EditText($handle); idleMicPixels = $true }
            Press @(0x11, 0x41) 'Ctrl+A: select the restarted dictation draft before the send cases'
            Press @(0x08) 'Backspace: clear the draft before the send cases'
            Wait-Until { [VerifyNative]::EditText($handle) -ceq '' } 'IGSH-965 composer empty before the send cases'
            $send = Get-DictationSend $mic
            Save-Json @{ mic = $mic; send = $send } 'send-geometry.json'
            $deliveries = @((Read-DictationAudit $auditPath) | Where-Object { $_ -match '\ttarget-chat-composer\t22$' }).Count
            foreach ($way in @('send-click', 'ctrl-enter')) {
                $outbox = Join-Path $scratch 'roaming/ZigShell/chat-outbox.json'
                [VerifyNative]::BringToForeground($script:window)
                Record 'Click the owned composer to recover typing focus from the hidden console'
                [VerifyNative]::ClickClient($handle, 8, 8)
                Wait-ChatFocus 'Edit' ($way + '-composer')
                Press @(0x11, 0x44) 'Ctrl+D: start composer dictation for the send case'
                $iteration++
                Wait-Until {
                    @((Read-DictationAudit $auditPath) | Where-Object { $_ -match '\tfixture-audio-bytes\t89160$' }).Count -eq $iteration
                } 'IGSH-965 recorded PCM reached the real capture worker' -Seconds 2 -PollMilliseconds 20
                Assert-DictationMic $micLive $true ($way + '-listening')
                $typed = 'typing-' + $way
                Type-Text $typed
                Wait-Until { [VerifyNative]::EditText($handle) -ceq $typed } 'IGSH-965 typing is accepted while listening' -Seconds 1 -PollMilliseconds 10
                Snapshot ($way + '-listening')
                Record ('Send once with ' + $way + ' while dictating')
                $immediate = [Diagnostics.Stopwatch]::StartNew()
                switch ($way) {
                    'send-click' { [VerifyNative]::ClickClient($script:window, [int](($send[0] + $send[2]) / 2), [int](($send[1] + $send[3]) / 2)) }
                    'ctrl-enter' { [VerifyNative]::Chord(@(0x11, 0x0D)) }
                }
                Wait-Until { [VerifyNative]::EditText($handle) -ceq '' } 'IGSH-965 one press ended dictation and sent the typed and spoken words' -Seconds 3 -PollMilliseconds 20
                $elapsed = $immediate.ElapsedMilliseconds
                Snapshot ($way + '-sent-box')
                $expected = $typed + ' Go forward ten meters.'
                Wait-Until {
                    (Test-Path $outbox) -and @((Get-Content $outbox -Raw | ConvertFrom-Json).queues | ForEach-Object { $_.messages } | Where-Object { $_.t -ceq $expected }).Count -eq 1
                } 'IGSH-965 the sent message holds the typed and spoken words exactly once' -Seconds 5 -PollMilliseconds 50
                Assert-DictationMic $mic $false ($way + '-stopped')
                $audit = @((Read-DictationAudit $auditPath))
                $deliveries++
                if (@($audit | Where-Object { $_ -match '\ttarget-chat-composer\t22$' }).Count -ne $deliveries) { throw 'IGSH-965 spoken words did not reach the message box before sending' }
                Snapshot ($way + '-sent')
                $result.checks += @{ name = ('dictation-' + $way); passed = $true; delivered = $expected; elapsedMilliseconds = $elapsed; sendRect = $send; micRect = $mic }
            }
            $stallMarker = Join-Path $scratch 'roaming/ZigShell/dictation-stall'
            $stallRound = 0
            foreach ($way in @('stop-click', 'send-click')) {
                if ([VerifyNative]::EditText($handle) -cne '') {
                    Press @(0x11, 0x41) 'Ctrl+A: select the draft left by the previous stalled case'
                    Press @(0x08) 'Backspace: clear the draft before the stalled case'
                    Wait-Until { [VerifyNative]::EditText($handle) -ceq '' } 'MUBO-290 composer empty before the stalled provider case'
                }
                New-Item -ItemType File -Force $stallMarker | Out-Null
                [VerifyNative]::BringToForeground($script:window)
                Record 'Click the owned composer to recover typing focus from the hidden console'
                [VerifyNative]::ClickClient($handle, 8, 8)
                Wait-ChatFocus 'Edit' ('mubo-290-' + $way + '-composer')
                Press @(0x11, 0x44) 'Ctrl+D: start dictation while the provider will not answer'
                $iteration++
                Wait-Until {
                    @((Read-DictationAudit $auditPath) | Where-Object { $_ -match '\tfixture-audio-bytes\t89160$' }).Count -eq $iteration
                } 'MUBO-290 recorded PCM reached the real capture worker' -Seconds 2 -PollMilliseconds 20
                Assert-DictationMic $micLive $true ($way + '-stall-listening')
                $typed = 'typing-' + $way
                Type-Text $typed
                Wait-Until { [VerifyNative]::EditText($handle) -ceq $typed } 'MUBO-290 typing is accepted while the provider stalls' -Seconds 1 -PollMilliseconds 10
                $sendRect = Get-DictationSend $mic
                Record ('End the recording with ' + $way + ' while the provider is still stalled')
                $immediate = [Diagnostics.Stopwatch]::StartNew()
                if ($way -ceq 'stop-click') {
                    [VerifyNative]::ClickClient($script:window, [int](($mic[0] + $mic[2]) / 2), [int](($mic[1] + $mic[3]) / 2))
                } else {
                    [VerifyNative]::ClickClient($script:window, [int](($sendRect[0] + $sendRect[2]) / 2), [int](($sendRect[1] + $sendRect[3]) / 2))
                }
                Wait-Until {
                    [void][VerifyNative]::DwmFlush()
                    $idlePixels = [VerifyNative]::DictationMicPixels($script:window, $mic, $false, (Join-Path $Evidence ($way + '-stall-idle-mic.png')))
                    $idlePixels[0] -eq 0 -and $idlePixels[1] -ge 3
                } ('MUBO-290 the microphone must be idle within a moment of the ' + $way) -Seconds 1 -PollMilliseconds 20
                $elapsed = $immediate.ElapsedMilliseconds
                if ($elapsed -gt 1000) { throw "MUBO-290 the microphone was still recording $elapsed ms after the $way" }
                Save-Json @{ WM_GETTEXT = [VerifyNative]::EditText($handle); micRect = $mic; sendRect = $sendRect; elapsedMilliseconds = $elapsed } ('mubo-290-' + $way + '.json')
                Wait-Until {
                    @((Read-DictationAudit $auditPath) | Where-Object { $_ -match '\tfixture-provider-stall\t0$' }).Count -eq ($stallRound + 1)
                } 'MUBO-290 the background transcription reached the stalled provider' -Seconds 3 -PollMilliseconds 20
                $audit = @((Read-DictationAudit $auditPath))
                if (@($audit | Where-Object { $_ -match '\tfixture-provider-stall-end\t0$' }).Count -ne $stallRound) { throw 'MUBO-290 the button waited for the background transcription' }
                if ([VerifyNative]::EditText($handle) -cne $typed) { throw 'MUBO-290 the stalled recording lost the typed draft' }
                $stallRound++
                Wait-Until {
                    @((Read-DictationAudit $auditPath) | Where-Object { $_ -match '\tempty-transcript\t' }).Count -eq $stallRound
                } 'MUBO-290 the stalled background transcription finished on its own' -Seconds 10 -PollMilliseconds 50
                Remove-Item $stallMarker -Force
                if ($way -ceq 'send-click') {
                    Wait-Until { [VerifyNative]::EditText($handle) -ceq '' } 'MUBO-290 the armed send leaves once the words are known' -Seconds 6 -PollMilliseconds 50
                    $expected = $typed
                    Wait-Until {
                        (Test-Path $outbox) -and @((Get-Content $outbox -Raw | ConvertFrom-Json).queues | ForEach-Object { $_.messages } | Where-Object { $_.t -ceq $expected }).Count -eq 1
                    } 'MUBO-290 the stalled send delivers the typed words exactly once' -Seconds 5 -PollMilliseconds 50
                }
                Snapshot ($way + '-stall-released')
                $result.checks += @{ name = ('mubo-290-' + $way); passed = $true; elapsedMilliseconds = $elapsed; micRect = $mic; sendRect = $sendRect }
            }
            Snapshot 'after'
        