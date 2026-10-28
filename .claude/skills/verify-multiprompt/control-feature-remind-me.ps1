
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $presetBase = [int][regex]::Match((Get-Content (Join-Path $PSScriptRoot '../../../src/app_state.zig') -Raw), 'SEARCH_REMIND_PRESET_OFFSET: usize = (\d+);').Groups[1].Value
            if ($presetBase -le 0) { throw 'remind-me: SEARCH_REMIND_PRESET_OFFSET not found' }
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 -and $state.active_workspace -ge 0 -and $state.active_tab -ge 0 } 'saved workspace and initial active tab'
            $initial = Read-Session
            $initialGroupIds = @()
            if ($initial.PSObject.Properties['groups']) { $initialGroupIds = @($initial.groups | ForEach-Object { $_.id }) }
            $groupCount = $initialGroupIds.Count
            Palette 'move to group'
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text 'new group'
            Press @(0x0D) 'Enter: New group'
            Wait-Until {
                $state = Read-Session
                if ($null -eq $state -or -not $state.PSObject.Properties['groups'] -or @($state.groups).Count -ne $groupCount + 1) { return $false }
                $newGroups = @($state.groups | Where-Object { $_.id -notin $initialGroupIds })
                $newGroups.Count -eq 1 -and -not [string]::IsNullOrWhiteSpace($newGroups[0].name) -and $state.tabs[$initial.active_tab].group_id -eq $newGroups[0].id
            } 'user-created group saved with the initial session'
            $baseline = Read-Session
            $group = @($baseline.groups | Where-Object { $_.id -notin $initialGroupIds })[0]
            $script:zsbPort = 0
            Wait-Until {
                if (-not (Test-Path $log)) { return $false }
                $listener = [regex]::Match(((Get-Content $log -Raw) -join ''), 'notify-listener: tunnel-inbound listening port=(\d+) err=0')
                if (-not $listener.Success) { return $false }
                $script:zsbPort = [int]$listener.Groups[1].Value
                @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort $script:zsbPort | Where-Object { $_.OwningProcess -eq $process.Id }).Count -eq 1
            } 'app-owned loopback tunnel-inbound listener' 30
            $listed = Invoke-Zsb @('workspace-list') $script:zsbPort 'workspace-list'
            $workspaceName = $baseline.workspaces[$baseline.active_workspace].name
            if (-not $workspaceName) { $workspaceName = 'Workspace ' + ($baseline.active_workspace + 1) }
            if (@($listed.hosts).Count -lt 1 -or -not ($listed.hosts[0] -is [string]) -or -not $listed.hosts[0]) { throw 'remind-me: workspace-list reported no usable host name' }
            $created = Invoke-Zsb @('session-open', '--workspace', $workspaceName, '--group', $group.name, '--host', $listed.hosts[0], '--tmux', 'verify-1', '--name', 'Verify 1') $script:zsbPort 'session-open-created'
            if ($created.created -ne $true) { throw 'remind-me: session-open did not create the tmux tab' }
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'verify-1' }).Count -eq 1 } 'tmux tab verify-1 saved'
            Press @(0x11, 0x32) 'Ctrl+2: focus the tmux session'
            Wait-Until { $state = Read-Session; $null -ne $state -and $state.tabs[$state.active_tab].PSObject.Properties['tmux_session'] -and $state.tabs[$state.active_tab].tmux_session -ceq 'verify-1' } 'tmux session is the active tab'
            $start = ((Get-Content $log -Raw) -join '').Length
            Press @(0x11, 0x48) 'Ctrl+H: open Remind Me presets'
            $expectedIds = @(0..4 + 6..12 | ForEach-Object { [string]($presetBase + $_) })
            Wait-Until {
                $trace = ((Get-Content $log -Raw) -join '').Substring($start)
                $rows = [regex]::Matches($trace, '\[palette\] rows chars=0 count=\d+ ids=([^\r\n]*)')
                if ($rows.Count -eq 0) { return $false }
                $ids = @($rows[$rows.Count - 1].Groups[1].Value -split ' ')
                @($expectedIds | Where-Object { $_ -notin $ids }).Count -eq 0
            } 'Remind Me preset rows published after Ctrl+H'
            Snapshot 'action'
            $trace = ((Get-Content $log -Raw) -join '').Substring($start)
            $pickerRows = @([regex]::Matches($trace, '\[palette\] rows chars=0 count=\d+ ids=([^\r\n]*)'))
            $pickerIds = @($pickerRows[$pickerRows.Count - 1].Groups[1].Value -split ' ')
            $stateAfter = Read-Session
            if ($stateAfter.tabs[$stateAfter.active_tab].tmux_session -cne 'verify-1' -or @($stateAfter.tabs).Count -ne @($baseline.tabs).Count + 1) { throw 'remind-me: a session was hidden or changed' }
            Snapshot 'after'
            $result.checks += @{ name = 'remind-me-ctrl-h'; entry = 'Ctrl+H'; presetBase = $presetBase; pickerRowIds = $pickerIds; sessionsBefore = @($baseline.tabs).Count; sessionsAfter = @($stateAfter.tabs).Count }
        