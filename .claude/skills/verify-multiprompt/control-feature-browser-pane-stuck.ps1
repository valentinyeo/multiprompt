
            $script:browserShellId = (Read-Inbox).shells[0].sid
            if (Test-Path (Join-Path $env:USERPROFILE 'Documents/GitHub/zigshell/extension/manifest.json')) { throw 'Expected no browser extension in the isolated profile' }
            Press @(0x12, 0x43) 'Alt+C: open Chat View'
            Wait-Until { @((Read-Session).tabs | Where-Object { $_.cv -eq $true }).Count -eq 1 } 'Chat View saved for the initial session'
            $first = Open-BrowserPane 'initial-open'
            Snapshot 'action'
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
        