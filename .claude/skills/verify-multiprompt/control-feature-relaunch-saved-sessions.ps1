
            $script:relaunchListeners = $null
            $openPorts = {
                if ($null -eq $script:relaunchListeners) {
                    $script:relaunchListeners = Open-NotifyPortListeners
                    Record "All $(@($script:relaunchListeners).Count) notification ports occupied by owned fixture sockets"
                }
            }
            try {
                $launches = @()
                $launchLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
                Wait-Until {
                    $trace = Read-SharedText $launchLog
                    $trace -match 'launch step=browser' -and $trace -match 'installHook: KEYBOARD_LL installed'
                } 'launch-1 restore finished and keyboard hook installed' 60
                $first = Assert-RelaunchSessions 'launch-1' $relaunchSeed
                if ($first.selected -cne $relaunchSeed.selected -or -not $first.starred_view) { throw "launch-1 did not restore the saved selection $($relaunchSeed.selected) in Starred, got $($first.selected)" }
                $launches += $first
                Snapshot 'launch-1'
                foreach ($launch in 2, 3) {
                    Press @(0x12, 0x32) 'Alt+2: home before quitting'
                    Wait-Until { $state = Read-Inbox; $null -ne $state -and -not $state.starred_view } 'home view before quitting'
                    [void](Assert-RelaunchSessions "home-before-launch-$launch" $relaunchSeed)
                    Press @(0x12, 0x31) 'Alt+1: Starred before quitting'
                    Wait-Until { $state = Read-Inbox; $null -ne $state -and $state.starred_view } 'Starred view before quitting'
                    $starred = Assert-RelaunchSessions "starred-before-launch-$launch" $relaunchSeed
                    Snapshot 'action'
                    Restart-SessionRestore "relaunch-$launch" $false $false $openPorts
                    $after = Assert-RelaunchSessions "launch-$launch" $relaunchSeed
                    if ($after.selected -cne $starred.selected) { throw "launch-$launch selected chat changed from $($starred.selected) to $($after.selected)" }
                    if (-not $after.starred_view) { throw "launch-$launch lost the Starred view" }
                    Snapshot "launch-$launch"
                    $launches += $after
                }
                Snapshot 'after'
                Save-Json $launches 'relaunch-launches.json'
                $result.checks += @{ name = 'relaunch-saved-sessions'; launches = 3; sessions = $relaunchSeed.live.Count; ghostsSeeded = $relaunchSeed.ghosts; groups = $relaunchSeed.groups.Count; occupiedPorts = @($script:relaunchListeners).Count }
            } finally {
                if ($null -ne $script:relaunchListeners) { foreach ($listener in $script:relaunchListeners) { $listener.Stop() } }
            }
        