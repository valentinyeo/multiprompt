
            $script:browserShellId = (Read-Inbox).shells[0].sid
            if (Test-Path (Join-Path $env:USERPROFILE 'Documents/GitHub/zigshell/extension/manifest.json')) { throw 'Expected no browser extension in the isolated profile' }
            Press @(0x12, 0x43) 'Alt+C: open Chat View'
            Wait-Until { @((Read-Session).tabs | Where-Object { $_.cv -eq $true }).Count -eq 1 } 'Chat View saved for the initial session'
            $first = Open-BrowserPane 'initial-open'
            Snapshot 'action'
            Palette 'new cmd'
            Press @(0x0D) 'Enter: create terminal target for Chat View handoff'
            Wait-Until { $state = Read-Session; @($state.tabs).Count -eq 2 -and $state.active_tab -eq 1 } 'second CMD selected'
            if ((Read-Session).tabs[1].PSObject.Properties['cv'] -and (Read-Session).tabs[1].cv) {
                Press @(0x12, 0x43) 'Alt+C: keep target in terminal view'
                Wait-Until { -not (Read-Session).tabs[1].PSObject.Properties['cv'] -or -not (Read-Session).tabs[1].cv } 'target saved as terminal view'
            }
            $chatShellId = $script:browserShellId
            $script:browserShellId = (Read-Session).tabs[1].shell_id
            $terminalPane = Open-BrowserPane 'terminal-handoff-setup'
            $terminalBrowser = [VerifyNative]::DockedPaneWindow($script:window)
            if ($terminalBrowser -eq [IntPtr]::Zero) { throw 'Terminal handoff target has no docked browser' }
            Press @(0x11, 0x09) 'Ctrl+Tab: return to Chat View and park terminal browser'
            Wait-Until { $state = Read-Session; $state.active_tab -eq 0 -and $state.tabs[0].cv } 'initial Chat View selected'
            Wait-Until { [VerifyNative]::DockedPaneWindow($script:window) -ne $terminalBrowser } 'terminal browser parked behind Chat View'
            Assert-Foreground
            Record 'Ctrl+Tab: select terminal from Chat View without any later input'
            $handoff = [Diagnostics.Stopwatch]::StartNew()
            [VerifyNative]::Chord(@(0x11, 0x09))
            Wait-Until {
                $state = Read-Session
                $state.active_tab -eq 1 -and (-not $state.tabs[1].PSObject.Properties['cv'] -or -not $state.tabs[1].cv) -and
                    [VerifyNative]::DockedPaneWindow($script:window) -eq $terminalBrowser -and
                    [VerifyNative]::PaneVisible($script:window)
            } 'same connected terminal browser visible within three seconds' 3 -PollMilliseconds 20
            $handoff.Stop()
            if ($handoff.ElapsedMilliseconds -ge 3000) { throw 'Chat View to terminal browser took three seconds or longer' }
            $handoffPane = Read-BrowserPane
            if ($handoffPane.browser_connection_id -ne $terminalPane.browser_connection_id) { throw 'Handoff relaunched instead of revealing the connected browser' }
            Save-Json @{ elapsed_ms = $handoff.ElapsedMilliseconds; connection_id = $handoffPane.browser_connection_id; same_browser = $true; visible = $true } 'chat-terminal-browser-handoff.json'
            $result.checks += @{ name = 'chat-terminal-browser-handoff'; elapsed_ms = $handoff.ElapsedMilliseconds; visible = $true }
            Snapshot 'chat-terminal-browser-handoff'
            Press @(0x11, 0x09) 'Ctrl+Tab: restore initial Chat View for close and reopen checks'
            $script:browserShellId = $chatShellId
            Wait-Until { (Read-Session).active_tab -eq 0 -and (Read-BrowserPane).browser_connection_id -eq $first.browser_connection_id } 'initial connected pane restored'
            Press @(0x12, 0x41) 'Alt+A: close browser pane'
            $closed = Assert-BrowserPane 'closed' 'shortcut-close'
            $second = Open-BrowserPane 'reopen-after-shortcut' $first.browser_connection_id
            Palette 'close all browser panes'
            Press @(0x0D) 'Enter: Close All Browser Panes'
            $closed = Assert-BrowserPane 'closed' 'palette-close-all'
            if (@((Read-Inbox).shells | Where-Object { $_.browser_state -ne 'closed' }).Count -ne 0) { throw 'Close All left a browser pane open' }
            Doctor
            Assert-Foreground
            Record 'reopen-after-close-all: batch palette open then close before adoption timers'
            [VerifyNative]::OpenAndCloseBrowserPane()
            $closed = Assert-BrowserPane 'closed' 'palette-close-pane'
            $fourth = Open-BrowserPane 'reopen-after-close-pane' $second.browser_connection_id
            if ($fourth.browser_connection_id -le $second.browser_connection_id + 1) { throw 'Palette batch did not open and cancel an intermediate connection' }
            Assert-ConnectedPaneStaysVisible $fourth.browser_connection_id
            Press @(0x12, 0x10, 0x41) 'Alt+Shift+A: toggle working browser pane closed'
            $closed = Assert-BrowserPane 'closed' 'shift-a-toggle'
            Press @(0x12, 0x10, 0x42) 'Alt+Shift+B: toggle browser pane open'
            $fifth = Assert-BrowserPane 'open' 'shift-b-toggle' $fourth.browser_connection_id
            Focus-BrowserPaneOwner 'shift-b-toggle' $fifth.browser_connection_id
            Palette 'close all browser panes'
            Press @(0x0D) 'Enter: Close All Browser Panes'
            $closed = Assert-BrowserPane 'closed' 'final-close'
            Snapshot 'after'

            $helperJobs = @()
            try {
                $debug = Join-Path $scratch 'roaming/ZigShell/debug.log'
                $serverState = Join-Path $Evidence 'slow-server.json'
                $serverLog = Join-Path $Evidence 'slow-server.log'
                $python = (Get-Command python.exe -ErrorAction Stop).Source
                $serverScript = (Resolve-Path (Join-Path $PSScriptRoot '../../../tools/verify-browser-toggle-server.py')).Path
                $serverJob = New-Object VerifyJob
                $helperJobs += $serverJob
                $slowServer = $serverJob.Start($python, $scratch, $serverLog, (Join-Path $Evidence 'slow-server-error.log'), ('"' + $serverScript + '" "' + $serverState + '"'))
                Wait-Until { Test-Path $serverState } 'local slow-loading page ready'
                $port = (Get-Content $serverState -Raw | ConvertFrom-Json).port
                $ffmpeg = (Get-Command ffmpeg.exe -ErrorAction Stop).Source
                $video = Join-Path $Evidence 'immediate-toggle.mp4'
                $recordJob = New-Object VerifyJob
                $helperJobs += $recordJob
                $recorder = $recordJob.Start($ffmpeg, $scratch, (Join-Path $Evidence 'video-out.log'), (Join-Path $Evidence 'video-error.log'), ('-y -f gdigrab -framerate 10 -i desktop -t 90 -vf scale=960:-2 -c:v libx264 -preset ultrafast -pix_fmt yuv420p "' + $video + '"'))
                $script:immediatePairs = @()
                function Assert-ImmediateBrowserPairs([string]$Page) {
                    for ($i = 0; $i -lt 20; $i++) {
                        Doctor
                        Wait-Foreground
                        Record "IGSH-1126 $Page immediate Alt+A pair $i"
                        Assert-Foreground
                        $before = @(Select-String -Path $debug -Pattern 'shortcutToggle enabled=').Count
                        $gap = [VerifyNative]::ImmediateBrowserTogglePair((50 + ($i % 5) * 50))
                        Wait-Until { @(Select-String -Path $debug -Pattern 'shortcutToggle enabled=').Count -eq $before + 2 } 'both physical key presses handled' -Seconds 5 -PollMilliseconds 10
                        $states = @(Select-String -Path $debug -Pattern 'shortcutToggle enabled=' | Select-Object -Last 2 | ForEach-Object { $_.Line })
                        if ($states[0] -notmatch 'enabled= 1$' -or $states[1] -notmatch 'enabled= 0$') { throw 'Immediate pair did not open then close' }
                        $closed = Assert-BrowserPane 'closed' ("immediate-$Page-$i")
                        $script:immediatePairs += @{ page = $Page; pair = $i; gapMs = $gap; states = $states; closed = $closed.browser_state -eq 'closed' }
                        Save-Json $script:immediatePairs 'immediate-toggle.json'
                    }
                }
                Assert-ImmediateBrowserPairs 'blank'
                Press @(0x12, 0x41) 'Alt+A: open browser for slow navigation'
                $slowPane = Assert-BrowserPane 'open' 'slow-open'
                Focus-BrowserPaneOwner 'slow-open' $slowPane.browser_connection_id
                $slowUrl = "http://127.0.0.1:$port/slow"
                Palette 'browser url'
                Press @(0x0D) 'Enter: choose browser URL'
                Type-Text $slowUrl
                Press @(0x0D) 'Enter: retain slow URL through app navigation'
                Wait-Until { (Read-Session).tabs[0].burl -eq $slowUrl } 'slow URL saved through the real app UI'
                $browser = [VerifyNative]::DockedPaneWindow($script:window)
                [uint32]$browserPid = 0
                [void][VerifyNative]::GetWindowThreadProcessId($browser, [ref]$browserPid)
                Record 'Focus owned browser before native address-bar navigation'
                [VerifyNative]::FocusOwnedWindow($browser, $browserPid, $script:window)
                if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw 'Browser lost focus before Ctrl+L' }
                Press @(0x11, 0x4C) 'Ctrl+L: navigate browser pane'
                Wait-Until {
                    $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
                    $focused.Current.ClassName -eq 'OmniboxViewViews' -and $focused.Current.HasKeyboardFocus -and
                        [VerifyNative]::GetForegroundWindow() -eq $browser
                } 'verified browser address bar has keyboard focus'
                Type-Text "http://127.0.0.1:$port/slow"
                Press @(0x0D) 'Enter: start slow page'
                Wait-Until { (Test-Path $serverLog) -and (Get-Content $serverLog -Raw) -match 'SLOW_LOADING' } 'browser received unfinished page'
                if ((Get-Content $serverLog -Raw) -match 'SLOW_FINISHED') { throw 'Slow page already finished before close' }
                Snapshot 'slow-loading'
                Press @(0x12, 0x41) 'Alt+A: close while page still loads'
                $closed = Assert-BrowserPane 'closed' 'slow-loading-close'
                if ((Get-Content $serverLog -Raw) -match 'SLOW_FINISHED') { throw 'Close waited for page completion' }
                Save-Json @{ loadingObserved = $true; retainedUrl = $slowUrl; closed = $closed.browser_state -eq 'closed'; finishedBeforeClose = $false } 'slow-toggle.json'
                Assert-ImmediateBrowserPairs 'slow'
                Get-Content $debug | Where-Object { $_ -match 'shortcutToggle' } | Set-Content -Encoding UTF8 (Join-Path $Evidence 'toggle-keys.log')
                Snapshot 'immediate-after'
                if (-not $recorder.WaitForExit(60000) -or $recorder.ExitCode -ne 0 -or (Get-Item $video).Length -le 0) { throw 'Toggle screen recording failed' }
                $recorder.Dispose()
                $slowServer.Dispose()
            } finally {
                $helperStops = @()
                foreach ($helper in $helperJobs) {
                    try { $helperStops += @{ activeAfterStop = $helper.Stop().ActiveProcesses } } finally { $helper.Dispose() }
                }
                Save-Json $helperStops 'toggle-helper-process-tree.json'
            }
