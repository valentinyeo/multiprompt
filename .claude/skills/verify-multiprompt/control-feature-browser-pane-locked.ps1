
            Write-Host "browser-pane-locked verified release tag=$env:RELEASE_TAG version=$ExpectedVersion"
            $script:browserShellId = (Read-Inbox).shells[0].sid
            if ($null -ne $warmupJob -and $warmupJob.ReadAccounting().ActiveProcesses -gt 0) {
                $warmupStopped = $warmupJob.Stop()
                Save-Json $warmupStopped 'browser-pane-locked-warmup-initial-stopped.json'
            }
            $pane = Open-BrowserPane 'locked-open'
            $initialLaunch = Assert-BrowserLaunchOnOwnMonitor 'initial'
            Doctor
            Record 'Close owned app normally and relaunch with its saved browser pane'
            if (-not $process.CloseMainWindow() -or -not $process.WaitForExit(10000)) { throw 'Owned app did not close normally for relaunch' }
            $relaunchStopped = $job.Stop()
            Save-Json $relaunchStopped 'browser-pane-locked-relaunch-stopped.json'
            if ($null -ne $warmupJob -and $warmupJob.ReadAccounting().ActiveProcesses -gt 0) {
                $warmupStopped = $warmupJob.Stop()
                Save-Json $warmupStopped 'browser-pane-locked-warmup-restored-stopped.json'
            }
            $job.Dispose()
            $job = New-Object VerifyJob
            $process = $job.Start($Exe, $scratch, (Join-Path $Evidence 'relaunch.stdout.log'), (Join-Path $Evidence 'relaunch.stderr.log'))
            $script:window = [IntPtr]::Zero
            Wait-Until {
                $process.Refresh()
                $script:window = $process.MainWindowHandle
                $script:window -ne [IntPtr]::Zero
            } 'relaunch main window ready for Shortcuts' 60 20
            if (-not [VerifyNative]::PostMessage($script:window, 0x8035, [UIntPtr]::Zero, [IntPtr]::Zero)) { throw 'Could not open Shortcuts before the restored browser launch' }
            $overlayPostedAt = [DateTime]::UtcNow
            $monitor = [VerifyNative]::MonitorFromWindow($script:window, 1)
            $info = New-Object VerifyNative+MonitorInfo
            $info.Size = [Runtime.InteropServices.Marshal]::SizeOf($info)
            if (-not [VerifyNative]::GetMonitorInfoW($monitor, [ref]$info)) { throw 'Owner monitor rectangle unavailable' }
            $profile = (Join-Path $env:LOCALAPPDATA 'ZigShell') -replace '\\', '/'
            $profileArgument = '(?:^|\s)--user-data-dir="?' + [regex]::Escape($profile) + '/(?:ChromeUserData|EdgeUserData)"?(?=\s|$)'
            Wait-Until {
                $script:overlayLaunches = @(Get-CimInstance Win32_Process -Filter "Name = 'chrome.exe' OR Name = 'msedge.exe'" | Where-Object {
                    ($_.CommandLine -replace '\\', '/') -match $profileArgument -and $_.CommandLine.Contains('--window-position=')
                } | ForEach-Object {
                    $point = [regex]::Match($_.CommandLine, '(?:^|\s)--window-position=(-?\d+),(-?\d+)(?:\s|$)')
                    $x = $null; $y = $null; $inside = $false
                    if ($point.Success) {
                        $x = [int]$point.Groups[1].Value; $y = [int]$point.Groups[2].Value
                        $inside = $x -ge $info.Monitor.Left -and $x -lt $info.Monitor.Right -and
                            $y -ge $info.Monitor.Top -and $y -lt $info.Monitor.Bottom
                    }
                    @{ pid = $_.ProcessId; commandLine = $_.CommandLine; parsed = $point.Success; x = $x; y = $y; inside = $inside }
                })
                $parkedPanes = @([VerifyNative]::OwnedPaneWindows($script:window) | Where-Object {
                    $rect = New-Object VerifyNative+Rect
                    [VerifyNative]::GetWindowRect($_, [ref]$rect) -and
                        [VerifyNative]::MonitorFromRect([ref]$rect, 0) -eq [IntPtr]::Zero
                })
                $script:overlayLaunches.Count -gt 0 -and $parkedPanes.Count -gt 0
            } 'positioned isolated browser launched while Shortcuts is open' 60
            $launchObservedAt = [DateTime]::UtcNow
            $overlayLaunch = @{ launches = $script:overlayLaunches; monitor = $info.Monitor; mainHwnd = $script:window.ToInt64(); overlayPostedAt = $overlayPostedAt; launchObservedAt = $launchObservedAt; overlayAtLaunch = $overlayPostedAt -lt $launchObservedAt }
            Save-Json $overlayLaunch 'browser-pane-locked-launch-restored-overlay.json'
            if (-not $overlayLaunch.overlayAtLaunch) { throw 'Shortcuts was not posted before the restored launch appeared' }
            if (@($overlayLaunch.launches | Where-Object { -not $_.parsed -or -not $_.inside }).Count -ne 0) { throw 'Browser launch point is outside the owner monitor while Shortcuts is open' }
            $parkedMonitors = Assert-BrowserPaneMonitors 'restored-overlay' -RequireParked
            if (-not [VerifyNative]::PostMessage($script:window, 0x8036, [UIntPtr]::Zero, [IntPtr]::Zero)) { throw 'Could not close Shortcuts after the restored browser launch' }
            Wait-Until {
                [VerifyNative]::PaneVisible($script:window) -and
                    $null -ne (Read-Inbox) -and @((Read-Inbox).shells).Count -gt 0
            } 'startup restored the owned browser pane without an open command' 60
            $script:browserShellId = (Read-Inbox).shells[0].sid
            $restoredLaunch = Assert-BrowserLaunchOnOwnMonitor 'restored'
            if (@($restoredLaunch.launches | Where-Object { $_.pid -in @($initialLaunch.launches | ForEach-Object { $_.pid }) }).Count -ne 0) { throw 'Relaunch reused an initial browser process instead of launching at startup' }
            $result.checks += @{ name = 'browser-pane-locked launch-on-own-monitor'; initial = $initialLaunch; restored = $restoredLaunch; restoredOverlay = $overlayLaunch; parkedMonitors = $parkedMonitors }
            Write-Host 'browser-pane-locked launch-on-own-monitor PASS'
            $browser = [VerifyNative]::PaneWindow($script:window)
            if ($browser -eq [IntPtr]::Zero) { throw 'No visible owned docked browser HWND' }
            $dockRect = New-Object VerifyNative+Rect
            if (-not [VerifyNative]::GetWindowRect($browser, [ref]$dockRect) -or [VerifyNative]::IsZoomed($browser)) { throw 'Initial browser dock rect unavailable or zoomed' }
            Save-Json @{ hwnd = $browser.ToInt64(); rect = $dockRect; tag = $env:RELEASE_TAG; version = $ExpectedVersion } 'browser-pane-locked-dock.json'
            Focus-LockedBrowser $browser
            $strip = Get-LockedBrowserStrip $browser $dockRect
            Snapshot 'action'
            Doctor
            Record 'Real SendInput drag: empty browser top strip 300px left and 200px down'
            [VerifyNative]::DragBrowserStrip($browser, $script:window, $strip)
            Assert-LockedBrowserRect $browser $dockRect 'drag-blocked'
            Snapshot 'drag-blocked'
            Focus-LockedBrowser $browser
            Doctor
            if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw 'Browser lost focus before Win+Up' }
            Record 'Real SendInput Win+Up with the docked browser focused'
            [VerifyNative]::Chord(@(0x5B, 0x26))
            Assert-LockedBrowserRect $browser $dockRect 'win-up-blocked'
            Focus-LockedBrowser $browser
            $strip = Get-LockedBrowserStrip $browser $dockRect
            Doctor
            Record 'Real SendInput double-click on the same empty browser top strip'
            [VerifyNative]::DoubleClickBrowserStrip($browser, $script:window, $strip)
            Assert-LockedBrowserRect $browser $dockRect 'maximize-blocked'
            Snapshot 'after'
        