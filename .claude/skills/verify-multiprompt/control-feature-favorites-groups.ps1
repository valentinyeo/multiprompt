
            Wait-Until { $state = Read-Session; $null -ne $state -and $state.single_window -and $state.active_workspace -eq 0 -and @($state.tabs).Count -eq 1 -and $state.tabs[0].kind -ceq 'cmd' } 'initial CMD session saved in first workspace'
            $initial = Read-Session
            $tabIndex = $initial.active_tab
            if ($tabIndex -ne 0 -or ($initial.tabs[$tabIndex].PSObject.Properties['favorite'] -and $initial.tabs[$tabIndex].favorite)) { throw 'Favorites journey requires the fresh unstarred CMD session' }
            $initialGroupIds = @()
            if ($initial.PSObject.Properties['groups']) { $initialGroupIds = @($initial.groups | ForEach-Object { $_.id }) }
            Press @(0x12, 0x53) 'Alt+S: favorite initial CMD session'
            Wait-Until { $state = Read-Session; $null -ne $state -and $state.tabs[$tabIndex].favorite -eq $true } 'favorite true saved in session.json'
            Palette 'move to group'
            Press @(0x0D) 'Enter: Move to Group submenu in home workspace'
            Type-Text 'new group'
            Snapshot 'action'
            Press @(0x0D) 'Enter: New home group'
            Wait-Until {
                $state = Read-Session
                if ($null -eq $state -or -not $state.PSObject.Properties['groups']) { return $false }
                $newGroups = @($state.groups | Where-Object { $_.id -notin $initialGroupIds })
                $newGroups.Count -eq 1 -and $newGroups[0].id -gt 0 -and $state.tabs[$tabIndex].group_id -eq $newGroups[0].id
            } 'new home group H persisted on original tab'
            $homeState = Read-Session
            $homeGroupId = $homeState.tabs[$tabIndex].group_id
            $homeGroupIds = @($homeState.groups | ForEach-Object { $_.id })
            Press @(0x1B) 'Escape: finish home group inline rename without changing its name'
            Press @(0x12, 0x31) 'Alt+1: Starred workspace'
            Palette 'move to group'
            Press @(0x0D) 'Enter: Move to Group submenu in Starred workspace'
            Type-Text 'new group'
            Press @(0x0D) 'Enter: New Favorites group'
            Wait-Until {
                $state = Read-Session
                if ($null -eq $state -or -not $state.tabs[$tabIndex].PSObject.Properties['starred_group_id']) { return $false }
                $newGroups = @($state.groups | Where-Object { $_.id -notin $homeGroupIds })
                $newGroups.Count -eq 1 -and $newGroups[0].id -gt 0 -and $newGroups[0].id -ne $homeGroupId -and $state.tabs[$tabIndex].group_id -eq $homeGroupId -and $state.tabs[$tabIndex].starred_group_id -eq $newGroups[0].id
            } 'independent Favorites group F saved while home group stays H'
            $starred = Read-Session
            $favoritesGroupId = $starred.tabs[$tabIndex].starred_group_id
            Save-Json $starred 'session-starred-grouped.json'
            Press @(0x1B) 'Escape: finish Favorites group inline rename without changing its name'
            Snapshot 'starred-grouped'
            Snapshot 'starred-pins-before'
            Focus-Palette 'pin to top' 6293
            Press @(0x0D) 'Enter: pin this session in Starred only'
            Wait-Until { $state = Read-Session; $state.tabs[$tabIndex].starred_pinned_top -eq $true -and (-not $state.tabs[$tabIndex].PSObject.Properties['pinned_top'] -or -not $state.tabs[$tabIndex].pinned_top) } 'Starred pin saved independently from home pin'
            Save-Json (Read-Session) 'starred-pins-after.json'
            Snapshot 'starred-pins-after'

            Press @(0x12, 0x32) 'Alt+2: return to home workspace'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and $state.active_workspace -eq 0 -and $state.active_tab -eq $tabIndex -and $state.tabs[$tabIndex].group_id -eq $homeGroupId -and $state.tabs[$tabIndex].starred_group_id -eq $favoritesGroupId -and $state.tabs[$tabIndex].favorite -eq $true
            } 'home return retains H and independent Favorites F'
            Save-Json (Read-Session) 'session-home-returned.json'
            Snapshot 'after'
            $result.checks += @{ name = 'favorites-groups-independent'; group_id = $homeGroupId; starred_group_id = $favoritesGroupId; tab = $tabIndex }
            $tabsBefore = @((Read-Session).tabs).Count
            Palette 'new cmd'
            Press @(0x0D) 'Enter: New CMD shell so the Inbox keeps one unmuted session'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq $tabsBefore + 1 -and $state.active_tab -ne $tabIndex } 'second unmuted CMD tab saved and active'
            Press @(0x12, 0x31) 'Alt+1: Favorites with the starred session'
            Wait-Until { $state = Read-Session; $null -ne $state -and $state.PSObject.Properties['starred_view'] -and $state.starred_view -and $state.active_tab -eq $tabIndex } 'starred session selected in Favorites'
            Palette 'mute tab'
            Press @(0x0D) 'Enter: Mute Tab on the starred session'
            Wait-Until { $state = Read-Session; $null -ne $state -and $state.tabs[$tabIndex].PSObject.Properties['muted'] -and $state.tabs[$tabIndex].muted -eq $true } 'muted true saved on the starred session'
            Press @(0x12, 0x32) 'Alt+2: leave Favorites before reopening it'
            Wait-Until { $state = Read-Session; $null -ne $state -and $state.PSObject.Properties['starred_view'] -and -not $state.starred_view } 'home workspace before reopening Favorites'
            Press @(0x12, 0x31) 'Alt+1: reopen Favorites with the muted starred session'
            Wait-Until { $state = Read-Session; $null -ne $state -and $state.PSObject.Properties['starred_view'] -and $state.starred_view -and $state.active_tab -eq $tabIndex -and $state.tabs[$tabIndex].starred_group_id -eq $favoritesGroupId -and $state.tabs[$tabIndex].muted -eq $true } 'muted starred session still listed and selected in Favorites group F'
            Save-Json (Read-Session) 'session-starred-muted.json'
            Snapshot 'starred-muted'
            $result.checks += @{ name = 'favorites-keeps-muted-starred'; starred_group_id = $favoritesGroupId; tab = $tabIndex; muted = $true }
            $expectedTabs = @((Read-Session).tabs).Count
            $listeners = @()
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $logStart = (Read-SharedText $log).Length
            Doctor
            Record 'Close only the owned app before occupying notification ports'
            if (-not $process.CloseMainWindow() -or -not $process.WaitForExit(10000)) { throw 'Favorites app refused normal close' }
            $stopped = $job.Stop()
            Save-Json $stopped 'favorites-before-restart-process-tree.json'
            if ($stopped.ActiveProcesses -ne 0) { throw 'Favorites restart left owned descendants' }
            $job.Dispose()
            try {
                $portSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../../../src/notify_ports.zig'))
                $firstPort = [regex]::Match($portSource, 'pub const FIRST_PORT: u16 = (\d+);')
                $portCount = [regex]::Match($portSource, 'pub const PORT_COUNT: usize = (\d+);')
                if (-not $firstPort.Success -or -not $portCount.Success) { throw 'Notification port range missing' }
                for ($offset = 0; $offset -lt [int]$portCount.Groups[1].Value; $offset++) {
                    $port = [int]$firstPort.Groups[1].Value + $offset
                    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $port)
                    $listener.Start()
                    $listeners += $listener
                }
                Record 'All notification ports occupied by owned fixture sockets'
                $script:job = New-Object VerifyJob
                $script:process = $job.Start($Exe, $scratch, (Join-Path $Evidence 'favorites-restart-stdout.log'), (Join-Path $Evidence 'favorites-restart-stderr.log'), '--single-window')
                $script:window = [IntPtr]::Zero
                Wait-Until {
                    $process.Refresh()
                    $script:window = $process.MainWindowHandle
                    $state = Read-Inbox
                    $trace = (Read-SharedText $log).Substring($logStart)
                    $script:window -ne [IntPtr]::Zero -and $null -ne $state -and
                        $state.hwnd -eq $script:window.ToInt64().ToString() -and
                        $trace -match 'no free notify port' -and $trace -match 'launch step=browser'
                } 'IGSH-890 sessions finish restoring despite occupied notification ports' 60
                [void][VerifyNative]::ShowWindow($script:window, 9)
                [void][VerifyNative]::MoveWindow($script:window, 10, 10, 1000, 650, $true)
                Wait-Until { [VerifyNative]::BringToForeground($script:window); [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window } 'Favorites restarted owned foreground'
                Doctor
                foreach ($round in 1..4) {
                    Press @(0x12, 0x32) 'Alt+2: home during repeated Favorites refresh'
                    Wait-Until { $state = Read-Session; $null -ne $state -and -not $state.starred_view -and @($state.tabs).Count -eq $expectedTabs } 'home retains exactly the original sessions'
                    Press @(0x12, 0x31) 'Alt+1: Favorites during repeated refresh'
                    Wait-Until {
                        $state = Read-Session
                        $null -ne $state -and $state.starred_view -and @($state.tabs).Count -eq $expectedTabs -and
                            $state.tabs[$state.active_tab].favorite -and $state.tabs[$state.active_tab].starred_group_id -eq $favoritesGroupId
                    } 'Favorites has one selected original grouped session'
                    $published = (Get-Item (Join-Path $scratch 'roaming/ZigShell/inbox-default.json')).LastWriteTimeUtc
                    Wait-Until { (Get-Item (Join-Path $scratch 'roaming/ZigShell/inbox-default.json')).LastWriteTimeUtc -gt $published } 'fresh Inbox refresh does not append sessions'
                    $state = Read-Session
                    if (@($state.tabs).Count -ne $expectedTabs -or @($state.tabs | Where-Object { -not $_.PSObject.Properties['pid'] -or $_.pid -eq 0 }).Count -ne 0) { throw 'Favorites refresh retained cached ghosts or duplicated sessions' }
                    Save-Json $state ("favorites-refresh-$round.json")
                }
                Restart-SessionRestore 'favorites-second-restart' $false
                Press @(0x12, 0x31) 'Alt+1: verify Favorites after another occupied-port relaunch'
                Wait-Until { $state = Read-Session; $null -ne $state -and $state.starred_view -and @($state.tabs).Count -eq $expectedTabs -and $state.tabs[$state.active_tab].starred_group_id -eq $favoritesGroupId } 'second restart keeps one grouped favorite without growth'
                Save-Json (Read-Session) 'favorites-no-duplicates.json'
                Snapshot 'favorites-no-duplicates'
                Wait-Until { $state = Read-Session; $state.tabs[$state.active_tab].starred_pinned_top -eq $true -and (-not $state.tabs[$state.active_tab].PSObject.Properties['pinned_top'] -or -not $state.tabs[$state.active_tab].pinned_top) } 'Starred pin survives two app restarts without pinning home'
                Save-Json (Read-Session) 'starred-pins-restarted.json'
                Snapshot 'starred-pins-restarted'
                Focus-Palette 'unpin from top' 6293
                Press @(0x0D) 'Enter: unpin from Starred back into its group'
                Wait-Until { $state = Read-Session; (-not $state.tabs[$state.active_tab].PSObject.Properties['starred_pinned_top'] -or -not $state.tabs[$state.active_tab].starred_pinned_top) -and (-not $state.tabs[$state.active_tab].PSObject.Properties['pinned_top'] -or -not $state.tabs[$state.active_tab].pinned_top) -and $state.tabs[$state.active_tab].starred_group_id -eq $favoritesGroupId } 'Unpin returns session to its unchanged Starred group'
                Save-Json (Read-Session) 'starred-pins-unpinned.json'
                Snapshot 'starred-pins-unpinned'
                $result.checks += @{ name = 'IGSH-1185 independent-pins-restart-unpin'; restarts = 2; homePinned = $false }

                $result.checks += @{ name = 'IGSH-890 favorites-refresh-restart'; tabs = $expectedTabs; refreshes = 4; restarts = 2; occupiedPorts = $listeners.Count; starred_group_id = $favoritesGroupId }
            } finally {
                foreach ($listener in $listeners) { $listener.Stop() }
            }
        