
            $result.sshBoundary = @{ verified = $false; expected = 'No remote credentials or tmux server are supplied; background tab creation, idempotency and failed connection status are verified'; observed = 'pending'; tabRemoved = $null }
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 -and $state.active_workspace -ge 0 -and $state.active_tab -ge 0 } 'saved workspace and initial active tab'
            $initial = Read-Session
            if (@($initial.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'verify-1' }).Count -ne 0) { throw 'verify-1 already exists before the journey' }
            $initialGroupIds = @()
            if ($initial.PSObject.Properties['groups']) { $initialGroupIds = @($initial.groups | ForEach-Object { $_.id }) }
            $groupCount = $initialGroupIds.Count
            Palette 'move to group'
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text 'new group'
            Snapshot 'group-action'
            Press @(0x0D) 'Enter: New group'
            Wait-Until {
                $state = Read-Session
                if ($null -eq $state -or -not $state.PSObject.Properties['groups'] -or @($state.groups).Count -ne $groupCount + 1) { return $false }
                $newGroups = @($state.groups | Where-Object { $_.id -notin $initialGroupIds })
                $newGroups.Count -eq 1 -and -not [string]::IsNullOrWhiteSpace($newGroups[0].name) -and $state.tabs[$initial.active_tab].group_id -eq $newGroups[0].id
            } 'user-created group name and original tab membership saved'
            $baseline = Read-Session
            $group = @($baseline.groups | Where-Object { $_.id -notin $initialGroupIds })[0]
            $result.groupSetup = @{ name = $group.name; id = $group.id; customNameExercised = $false; reason = 'Palette creation does not reliably focus an inline rename editor; using the default name read from session.json' }
            Record ('Use persisted group ' + $group.name + '; custom name path not exercised')
            $workspaceBefore = $baseline.active_workspace
            $activeTabBefore = $baseline.active_tab
            $activeBefore = $baseline.tabs[$activeTabBefore]
            if ($activeBefore.group_id -ne $group.id) { throw 'New group does not contain the original active tab' }
            $titleBefore = [VerifyNative]::Title($script:window)
            $foregroundBefore = [VerifyNative]::GetForegroundWindow()
            $foregroundTitleBefore = [VerifyNative]::Title($foregroundBefore)
            Save-Json $baseline 'session-before.json'
            Snapshot 'before'
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $script:zsbPort = 0
            Wait-Until {
                if (-not (Test-Path $log)) { return $false }
                $listener = [regex]::Match(((Get-Content $log -Raw) -join ''), 'notify-listener: tunnel-inbound listening port=(\d+) err=0')
                if (-not $listener.Success) { return $false }
                $script:zsbPort = [int]$listener.Groups[1].Value
                @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort $script:zsbPort | Where-Object { $_.OwningProcess -eq $process.Id }).Count -eq 1
            } 'app-owned loopback tunnel-inbound listener' 30
            $listed = Invoke-Zsb @('workspace-list') $script:zsbPort 'workspace-list'
            $workspaceName = $baseline.workspaces[$workspaceBefore].name
            if (-not $workspaceName) { $workspaceName = 'Workspace ' + ($workspaceBefore + 1) }
            $workspaces = @($listed.workspaces | Where-Object { $_.id -eq $workspaceBefore -and $_.name -ceq $workspaceName -and $_.active -eq $true })
            if ($workspaces.Count -ne 1) { throw 'workspace-list did not report the saved active workspace' }
            $listedGroups = @($workspaces[0].groups | Where-Object { $_.id -eq $group.id -and $_.name -ceq $group.name })
            if ($listedGroups.Count -ne 1) { throw 'workspace-list did not report the user-created group' }
            if (@($listed.hosts).Count -lt 1 -or -not ($listed.hosts[0] -is [string]) -or -not $listed.hosts[0]) { throw 'workspace-list reported no usable host name' }
            $hostName = $listed.hosts[0]
            $openArgs = @('session-open', '--workspace', $workspaceName, '--group', $group.name, '--host', $hostName, '--tmux', 'verify-1', '--name', 'Verify 1')
            $assertSaved = {
                $state = Read-Session
                if ($null -eq $state) { throw 'session.json is not readable' }
                $tabs = @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'verify-1' })
                if ($tabs.Count -ne 1 -or @($state.tabs).Count -ne @($baseline.tabs).Count + 1) { throw 'Expected exactly one new verify-1 tab' }
                $tab = $tabs[0]
                $tabWorkspace = 0
                if ($tab.PSObject.Properties['workspace']) { $tabWorkspace = $tab.workspace }
                if ($tab.kind -cne 'tmux' -or $tab.name -cne 'Verify 1' -or $tab.group_id -ne $group.id -or $tabWorkspace -ne $workspaceBefore) { throw 'Saved tmux tab title, group or workspace mismatch' }
                if (@($state.groups).Count -ne $groupCount + 1 -or @($state.groups | Where-Object { $_.id -eq $group.id -and $_.name -ceq $group.name }).Count -ne 1) { throw 'Saved group changed' }
                if ($state.active_workspace -ne $workspaceBefore -or $state.active_tab -ne $activeTabBefore -or $state.tabs[$activeTabBefore].name -cne $activeBefore.name -or $state.tabs[$activeTabBefore].kind -cne $activeBefore.kind) { throw 'Background request changed the active workspace or active tab' }
                if ([VerifyNative]::GetForegroundWindow() -ne $foregroundBefore -or [VerifyNative]::Title($foregroundBefore) -cne $foregroundTitleBefore -or [VerifyNative]::Title($script:window) -cne $titleBefore) { throw 'Background request changed foreground window or title' }
                $script:sessionOpenSaved = $state
                return $true
            }
            Snapshot 'action'
            $created = Invoke-Zsb $openArgs $script:zsbPort 'session-open-created'
            if ($created.created -ne $true -or $created.tab -le 0) { throw 'session-open did not reply ok/created with a tab ID' }
            Wait-Until $assertSaved 'exact saved background tab and unchanged selection after creation'
            Save-Json $script:sessionOpenSaved 'session-created.json'
            $repeated = Invoke-Zsb $openArgs $script:zsbPort 'session-open-repeated'
            if ($repeated.existing -ne $true -or $repeated.tab -ne $created.tab -or $repeated.workspace -cne $workspaceName) { throw 'Repeated session-open was not an existing:true no-op for the same tab and workspace' }
            Wait-Until $assertSaved 'repeat no-op with exactly one saved tab and unchanged selection'
            Save-Json $script:sessionOpenSaved 'session-repeated.json'
            $script:sshFailure = $null
            Wait-Until {
                $failure = [regex]::Match(((Get-Content $log -Raw) -join ''), ('ssh-reconnect disconnect id=' + $created.tab + ' reason=(process-exit-event|process-exit-poll|startup-console-missing) exit_code=(\d+) known=true'))
                if (-not $failure.Success -or [uint64]$failure.Groups[2].Value -in @(0, 259)) { return $false }
                $script:sshFailure = @{ reason = $failure.Groups[1].Value; exitCode = [uint64]$failure.Groups[2].Value; logLine = $failure.Value }
                return $true
            } 'observed failed SSH attach for the created tab' 60
            $result.sshBoundary.observed = $script:sshFailure
            $status = Invoke-Zsb @('session-status', '--tab', [string]$created.tab) $script:zsbPort 'session-status-failed'
            if ($status.tab -ne $created.tab -or $status.state -cne 'disconnected' -or -not $status.PSObject.Properties['exit_code'] -or $status.exit_code -ne $script:sshFailure.exitCode) { throw 'session-status did not report disconnected with the logged SSH exit code' }
            $result.checks += @{ name = 'session-status-failed-attach'; tab = $created.tab; status = $status; loggedExitCode = $script:sshFailure.exitCode }
            Wait-Until $assertSaved 'failed SSH tab preserved in saved state with unchanged active tab and foreground'
            $result.sshBoundary.tabRemoved = $false
            Save-Json $script:sessionOpenSaved 'session-after.json'
            $result.checks += @{ name = 'session-open-background-idempotent'; workspace = $workspaceName; group = $group.name; groupId = $group.id; host = $hostName; port = $script:zsbPort; created = $created; repeated = $repeated; tmux = 'verify-1'; title = 'Verify 1'; matchingTabs = 1; tabsBefore = @($baseline.tabs).Count; tabsAfter = @($script:sessionOpenSaved.tabs).Count; activeWorkspaceBefore = $workspaceBefore; activeWorkspaceAfter = $script:sessionOpenSaved.active_workspace; activeTabBefore = $activeTabBefore; activeTabAfter = $script:sessionOpenSaved.active_tab; foregroundBefore = $foregroundBefore.ToInt64(); foregroundAfter = [VerifyNative]::GetForegroundWindow().ToInt64(); windowTitleBefore = $titleBefore; windowTitleAfter = [VerifyNative]::Title($script:window) }
            Snapshot 'after'
        