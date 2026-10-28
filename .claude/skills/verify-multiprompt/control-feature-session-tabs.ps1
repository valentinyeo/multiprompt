
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 -and $state.active_workspace -ge 0 -and $state.active_tab -ge 0 } 'saved workspace and initial active tab'
            $initial = Read-Session
            $initialGroupIds = @()
            if ($initial.PSObject.Properties['groups']) { $initialGroupIds = @($initial.groups | ForEach-Object { $_.id }) }
            Palette 'move to group'
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text 'new group'
            Press @(0x0D) 'Enter: first group'
            Wait-Until {
                $state = Read-Session
                if ($null -eq $state -or -not $state.PSObject.Properties['groups']) { return $false }
                $newGroups = @($state.groups | Where-Object { $_.id -notin $initialGroupIds })
                $newGroups.Count -eq 1 -and $state.tabs[$initial.active_tab].group_id -eq $newGroups[0].id
            } 'first user-created group saved'
            $groupA = @((Read-Session).groups | Where-Object { $_.id -notin $initialGroupIds })[0]
            $script:zsbPort = 0
            Wait-Until {
                if (-not (Test-Path $log)) { return $false }
                $listener = [regex]::Match(((Get-Content $log -Raw) -join ''), 'notify-listener: tunnel-inbound listening port=(\d+) err=0')
                if (-not $listener.Success) { return $false }
                $script:zsbPort = [int]$listener.Groups[1].Value
                @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort $script:zsbPort | Where-Object { $_.OwningProcess -eq $process.Id }).Count -eq 1
            } 'app-owned loopback tunnel-inbound listener' 30
            $listed = Invoke-Zsb @('workspace-list') $script:zsbPort 'workspace-list-start'
            $baseline = Read-Session
            $workspaceName = $baseline.workspaces[$baseline.active_workspace].name
            if (-not $workspaceName) { $workspaceName = 'Workspace ' + ($baseline.active_workspace + 1) }
            if (@($listed.hosts).Count -lt 1 -or -not ($listed.hosts[0] -is [string]) -or -not $listed.hosts[0]) { throw 'workspace-list reported no usable host name' }
            $hostName = $listed.hosts[0]
            $tabIds = @{}
            foreach ($n in 1, 2, 3, 4) {
                $opened = Invoke-Zsb @('session-open', '--workspace', $workspaceName, '--group', $groupA.name, '--host', $hostName, '--tmux', "verify-$n", '--name', "Verify $n") $script:zsbPort "session-open-$n"
                if ($opened.created -ne $true -or $opened.tab -le 0) { throw "session-open did not create verify-$n" }
                $tabIds[$n] = [int]$opened.tab
            }
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -cmatch '^verify-[1-4]$' }).Count -eq 4 } 'four tmux tabs saved'
            Palette 'move to group'
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text 'new group'
            Press @(0x0D) 'Enter: second group'
            $knownGroupIds = @($initialGroupIds) + @($groupA.id)
            Wait-Until {
                $state = Read-Session
                if ($null -eq $state -or -not $state.PSObject.Properties['groups']) { return $false }
                @($state.groups | Where-Object { $_.id -notin $knownGroupIds }).Count -eq 1
            } 'second user-created group saved'
            $groupB = @((Read-Session).groups | Where-Object { $_.id -notin $knownGroupIds })[0]
            if ($groupB.name -ceq $groupA.name) { throw 'Both groups have the same name' }
            $before = Read-Session
            $activeTabBefore = $before.active_tab
            $activeWorkspaceBefore = $before.active_workspace
            $activeNameBefore = $before.tabs[$activeTabBefore].name
            $titleBefore = [VerifyNative]::Title($script:window)
            $foregroundBefore = [VerifyNative]::GetForegroundWindow()
            $foregroundTitleBefore = [VerifyNative]::Title($foregroundBefore)
            $listedBefore = Invoke-Zsb @('workspace-list') $script:zsbPort 'workspace-list-before'
            Save-Json $before 'session-tabs-before.session.json'
            Snapshot 'before'
            $assertQuiet = {
                param([string]$Step)
                $state = Read-Session
                if ($null -eq $state) { throw "session.json is not readable after $Step" }
                if ($state.active_workspace -ne $activeWorkspaceBefore -or $state.active_tab -ne $activeTabBefore -or $state.tabs[$state.active_tab].name -cne $activeNameBefore) { throw "$Step changed the active workspace or active tab" }
                if ([VerifyNative]::GetForegroundWindow() -ne $foregroundBefore -or [VerifyNative]::Title($foregroundBefore) -cne $foregroundTitleBefore -or [VerifyNative]::Title($script:window) -cne $titleBefore) { throw "$Step changed foreground window or title" }
            }
            $expectRefused = {
                param([string[]]$ZsbArgs, [string]$Code, [string]$Name)
                $refused = $false
                try { [void](Invoke-Zsb $ZsbArgs $script:zsbPort $Name) } catch { $refused = $_.Exception.Message.Contains('"error":"' + $Code + '"') }
                if (-not $refused) { throw "$Name was not refused with $Code" }
            }
            Snapshot 'action'
            $renamed = Invoke-Zsb @('session-rename', '--tab', [string]$tabIds[1], '--name', 'Renamed One') $script:zsbPort 'session-rename'
            if ($renamed.renamed -ne $true -or $renamed.tab -ne $tabIds[1]) { throw 'session-rename did not reply renamed for the tab' }
            Wait-Until { $state = Read-Session; @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'verify-1' -and $_.name -ceq 'Renamed One' }).Count -eq 1 } 'renamed tab saved with its session unchanged'
            & $assertQuiet 'session-rename'
            $rebound = Invoke-Zsb @('session-rebind', '--tab', [string]$tabIds[2], '--tmux', 'verify-9') $script:zsbPort 'session-rebind'
            if ($rebound.rebound -ne $true -or $rebound.tab -ne $tabIds[2] -or $rebound.state -cnotin @('connecting', 'connected', 'disconnected')) { throw 'session-rebind did not reply rebound with a state' }
            Wait-Until { $state = Read-Session; @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'verify-9' -and $_.name -ceq 'Verify 2' -and $_.group_id -eq $groupA.id }).Count -eq 1 -and @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'verify-2' }).Count -eq 0 } 'rebound tab saved on the new session with its title and group'
            & $assertQuiet 'session-rebind'
            $status = Invoke-Zsb @('session-status', '--tab', [string]$tabIds[2]) $script:zsbPort 'session-status-rebound'
            if ($status.tab -ne $tabIds[2]) { throw 'session-status lost the rebound tab' }
            & $expectRefused @('session-rebind', '--tab', [string]$tabIds[3], '--tmux', 'verify-9') 'duplicate_session' 'session-rebind-duplicate'
            $moved = Invoke-Zsb @('session-move', '--tab', [string]$tabIds[3], '--group', $groupB.name) $script:zsbPort 'session-move'
            if ($moved.moved -ne $true -or $moved.tab -ne $tabIds[3]) { throw 'session-move did not reply moved for the tab' }
            Wait-Until { $state = Read-Session; @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'verify-3' -and $_.group_id -eq $groupB.id }).Count -eq 1 } 'moved tab saved in the second group'
            & $assertQuiet 'session-move'
            $closed = Invoke-Zsb @('session-close', '--tab', [string]$tabIds[4]) $script:zsbPort 'session-close'
            if ($closed.closed -ne $true -or $closed.tab -ne $tabIds[4]) { throw 'session-close did not reply closed for the tab' }
            Wait-Until { $state = Read-Session; @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'verify-4' }).Count -eq 0 -and @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -cmatch '^verify-' }).Count -eq 3 } 'closed tab removed from the saved layout'
            & $assertQuiet 'session-close'
            $activeListed = $null
            $afterList = Invoke-Zsb @('workspace-list') $script:zsbPort 'workspace-list-after'
            foreach ($workspace in @($afterList.workspaces)) {
                foreach ($tab in @($workspace.tabs) + @($workspace.groups | ForEach-Object { @($_.tabs) })) { if ($tab.active -eq $true) { $activeListed = $tab } }
            }
            if ($null -eq $activeListed) { throw 'workspace-list reported no active tab' }
            & $expectRefused @('session-close', '--tab', [string]$activeListed.id) 'active_tab' 'session-close-active'
            & $expectRefused @('session-move', '--tab', [string]$activeListed.id, '--ungrouped') 'active_tab' 'session-move-active'
            & $expectRefused @('session-rebind', '--tab', [string]$activeListed.id, '--tmux', 'verify-8') 'active_tab' 'session-rebind-active'
            & $expectRefused @('session-close', '--tab', '2000000000') 'unknown_tab' 'session-close-unknown'
            & $assertQuiet 'refused commands'
            $layout = {
                param($state)
                $groupNames = @{}
                foreach ($g in @($state.groups)) { $groupNames[[int]$g.id] = $g.name }
                @($state.tabs | ForEach-Object {
                    $tabGroup = ''
                    if ($_.PSObject.Properties['group_id'] -and $_.group_id -and $groupNames.ContainsKey([int]$_.group_id)) { $tabGroup = $groupNames[[int]$_.group_id] }
                    $tabSession = ''
                    if ($_.PSObject.Properties['tmux_session']) { $tabSession = $_.tmux_session }
                    $tabWorkspace = 0
                    if ($_.PSObject.Properties['workspace']) { $tabWorkspace = $_.workspace }
                    '{0}|{1}|{2}|{3}' -f $_.name, $tabSession, $tabGroup, $tabWorkspace
                }) -join "`n"
            }
            $expectedLayout = & $layout (Read-Session)
            $expectedActive = (Read-Session).tabs[(Read-Session).active_tab].name
            Save-Json (Read-Session) 'session-tabs-layout.session.json'
            Save-Json $afterList 'session-tabs-layout.workspace-list.json'
            Snapshot 'after'
            Restart-SessionRestore 'tabs-restart' $false
            Wait-Until { $state = Read-Session; $null -ne $state -and (& $layout $state) -ceq $expectedLayout } 'saved layout survives the restart exactly' 60
            Save-Json (Read-Session) 'session-tabs-restarted.session.json'
            Snapshot 'restarted'
            $result.checks += @{ name = 'session-tabs-cli-repair'; tabIds = @($tabIds[1], $tabIds[2], $tabIds[3], $tabIds[4]); groupA = $groupA.name; groupB = $groupB.name; layout = $expectedLayout; activeTab = $expectedActive; listedStateBefore = @($listedBefore.workspaces).Count; foregroundBefore = $foregroundBefore.ToInt64(); windowTitle = $titleBefore; restart = $true }
        