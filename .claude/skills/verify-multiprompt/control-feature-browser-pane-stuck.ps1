
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
            $shiftToggleCooldown = [Diagnostics.Stopwatch]::StartNew()
            $closed = Assert-BrowserPane 'closed' 'shift-a-toggle'
            Wait-Until { $shiftToggleCooldown.ElapsedMilliseconds -ge 1600 } 'browser shortcut debounce elapsed' 5
            Press @(0x12, 0x10, 0x42) 'Alt+Shift+B: toggle browser pane open'
            $fifth = Assert-BrowserPane 'open' 'shift-b-toggle' $fourth.browser_connection_id
            Focus-BrowserPaneOwner 'shift-b-toggle' $fifth.browser_connection_id
            Palette 'close all browser panes'
            Press @(0x0D) 'Enter: Close All Browser Panes'
            $closed = Assert-BrowserPane 'closed' 'final-close'
            Snapshot 'after'
        