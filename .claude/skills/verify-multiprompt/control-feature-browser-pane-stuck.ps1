
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
            $closed = Assert-BrowserPane 'closed' 'shift-a-toggle'
            Press @(0x12, 0x10, 0x42) 'Alt+Shift+B: toggle browser pane open'
            $fifth = Assert-BrowserPane 'open' 'shift-b-toggle' $fourth.browser_connection_id
            Focus-BrowserPaneOwner 'shift-b-toggle' $fifth.browser_connection_id
            Palette 'close all browser panes'
            Press @(0x0D) 'Enter: Close All Browser Panes'
            $closed = Assert-BrowserPane 'closed' 'final-close'
            Snapshot 'after'

            $debug = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $serverState = Join-Path $Evidence 'slow-server.json'
            $serverLog = Join-Path $Evidence 'slow-server.log'
            $python = (Get-Command python.exe -ErrorAction Stop).Source
            $serverScript = (Resolve-Path (Join-Path $PSScriptRoot '../../../tools/verify-browser-toggle-server.py')).Path
            $slowServer = $job.Start($python, $scratch, $serverLog, (Join-Path $Evidence 'slow-server-error.log'), ('"' + $serverScript + '" "' + $serverState + '"'))
            Wait-Until { Test-Path $serverState } 'local slow-loading page ready'
            $port = (Get-Content $serverState -Raw | ConvertFrom-Json).port
            $ffmpeg = (Get-Command ffmpeg.exe -ErrorAction Stop).Source
            $video = Join-Path $Evidence 'immediate-toggle.mp4'
            $recorder = $job.Start($ffmpeg, $scratch, (Join-Path $Evidence 'video-out.log'), (Join-Path $Evidence 'video-error.log'), ('-y -f gdigrab -framerate 10 -i desktop -t 45 -vf scale=960:-2 -c:v libx264 -preset ultrafast -pix_fmt yuv420p "' + $video + '"'))
            $script:immediatePairs = @()
            function Assert-ImmediateBrowserPairs([string]$Page) {
            for ($i = 0; $i -lt 20; $i++) {
                Doctor
                Wait-Foreground
                Record "IGSH-1126 $Page immediate Alt+A pair $i"
                Assert-Foreground
                $before = @(Select-String -Path $debug -Pattern 'shortcutToggle enabled=').Count
                $gap = [VerifyNative]::ImmediateBrowserTogglePair()
                Wait-Until { @(Select-String -Path $debug -Pattern 'shortcutToggle enabled=').Count -eq $before + 2 } 'both physical key presses handled' -Seconds 5 -PollMilliseconds 10
                $states = @(Select-String -Path $debug -Pattern 'shortcutToggle enabled=' | Select-Object -Last 2 | ForEach-Object { $_.Line })
                if ($states[0] -notmatch 'enabled= 1$' -or $states[1] -notmatch 'enabled= 0$') { throw 'Immediate pair did not open then close' }
                $closed = Assert-BrowserPane 'closed' ("immediate-$Page-$i")
                $script:immediatePairs += @{ page = $Page; pair = $i; gapMs = $gap; states = $states; closed = $closed.browser_state -eq 'closed' }
                Save-Json $script:immediatePairs 'immediate-toggle.json'
            }
            }
            Assert-ImmediateBrowserPairs 'blank'
            $slowPane = Open-BrowserPane 'slow-open'
            Press @(0x12, 0x4C) 'Alt+L: navigate browser pane'
            Type-Text "http://127.0.0.1:$port/slow"
            Press @(0x0D) 'Enter: start slow page'
            Wait-Until { (Test-Path $serverLog) -and (Get-Content $serverLog -Raw) -match 'SLOW_LOADING' } 'browser received unfinished page'
            if ((Get-Content $serverLog -Raw) -match 'SLOW_FINISHED') { throw 'Slow page already finished before close' }
            Snapshot 'slow-loading'
            Press @(0x12, 0x41) 'Alt+A: close while page still loads'
            $closed = Assert-BrowserPane 'closed' 'slow-loading-close'
            if ((Get-Content $serverLog -Raw) -match 'SLOW_FINISHED') { throw 'Close waited for page completion' }
            Save-Json @{ loadingObserved = $true; closed = $closed.browser_state -eq 'closed'; finishedBeforeClose = $false } 'slow-toggle.json'
            Assert-ImmediateBrowserPairs 'slow'
            Get-Content $debug | Where-Object { $_ -match 'shortcutToggle' } | Set-Content -Encoding UTF8 (Join-Path $Evidence 'toggle-keys.log')
            Snapshot 'immediate-after'
            if (-not $recorder.WaitForExit(60000) -or $recorder.ExitCode -ne 0 -or (Get-Item $video).Length -le 0) { throw 'Toggle screen recording failed' }
            $recorder.Dispose()
            $slowServer.Dispose()
