
            Wait-Until { (Get-Content (Join-Path $scratch 'roaming/ZigShell/debug.log') -Raw) -match 'launch step=browser' } 'initial restore finished before keyboard creation' 60
            Focus-Palette 'tab order' 6217
            Press @(0x28) 'Down: Tab Order Manual'
            Press @(0x0D) 'Enter: keep creation order before grouping restore sessions'
            $before = (Read-Session).workspace_count
            Press @(0x11, 0x4E) 'Ctrl+N: create a different workspace with its first CMD session'
            Wait-Until { $script:createdSession = Read-Session; $null -ne $script:createdSession -and $script:createdSession.workspace_count -eq $before + 1 } 'new workspace persisted'
            $workspace = $script:createdSession.active_workspace
            $workspaceId = $script:createdSession.workspaces[$workspace].wid
            if ($workspace -eq 0 -or [string]::IsNullOrWhiteSpace($workspaceId)) { throw 'Expected a distinct named workspace identity' }
            $names = @('Restore first', 'Restore middle', 'Restore last')
            for ($i = 0; $i -lt $names.Count; $i++) {
                if ($i -gt 0) {
                    $tabsBefore = @((Read-Session).tabs).Count
                    Focus-Palette 'new cmd' 2000
                    Press @(0x0D) 'Enter: New CMD shell for restore'
                    Wait-Until { @((Read-Session).tabs).Count -eq $tabsBefore + 1 } 'new local CMD session saved'
                }
                Press @(0x71) 'F2: name the restore session'
                Press @(0x11, 0x41) 'Ctrl+A: replace restore session name'
                Type-Text $names[$i]
                Press @(0x0D) 'Enter: save restore session name'
                Wait-Until { @((Read-Session).tabs | Where-Object { $_.name -ceq $names[$i] -and $_.kind -ceq 'cmd' }).Count -eq 1 } 'unique local CMD name persisted'
                if ($i -lt 2) {
                    Focus-Palette 'move to group' 6301
                    Press @(0x0D) 'Enter: Move to Group submenu for the active restore session'
                    $groupQuery = if ($i -eq 0) { 'new group' } else { 'Group 1' }
                    $groupTarget = if ($i -eq 0) { 6303 } else { 6320 }
                    Type-Text $groupQuery
                    Wait-Until { (Get-Content (Join-Path $scratch 'roaming/ZigShell/debug.log') -Raw) -match ('\[palette\] ready chars=' + $groupQuery.Length + ' count=[1-9]\d* target=' + $groupTarget + '(?:\r?\n|$)') } 'group submenu query selects the existing UI action'
                    Press @(0x0D) 'Enter: assign the active restore session to its home sidebar group'
                    Wait-Until {
                        $saved = Read-Session
                        $saved.PSObject.Properties['groups'] -and @($saved.groups).Count -eq 1 -and $saved.groups[0].name -ceq 'Group 1' -and
                            @($saved.tabs | Where-Object { $_.name -ceq $names[$i] -and $_.PSObject.Properties['group_id'] -and $_.group_id -eq $saved.groups[0].id }).Count -eq 1
                    } 'home group membership persisted through real palette input'
                }
                if ($i -ne 1) {
                    Press @(0x12, 0x53) 'Alt+S: favorite the reorder companion session'
                    Wait-Until { @((Read-Session).tabs | Where-Object { $_.name -ceq $names[$i] -and $_.favorite -eq $true }).Count -eq 1 } 'reorder companion favorite persisted'
                }
            }
            $tabs = @((Read-Session).tabs)
            $middleIndex = -1
            for ($i = 0; $i -lt $tabs.Count; $i++) { if ($tabs[$i].name -ceq 'Restore middle') { $middleIndex = $i } }
            if ($middleIndex -lt 0) { throw 'Middle session missing from saved tabs' }
            Focus-Palette 'Restore middle' $middleIndex
            Press @(0x0D) 'Enter: select the middle session by name'
            Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId
            Press @(0x12, 0x53) 'Alt+S: favorite the middle restore session'
            Wait-Until { @((Read-Session).tabs | Where-Object { $_.name -ceq 'Restore middle' -and $_.favorite -eq $true }).Count -eq 1 } 'middle favorite persisted'
            Press @(0x12, 0x31) 'Alt+1: open the Starred workspace'
            Focus-Palette 'Restore middle' $middleIndex
            Press @(0x0D) 'Enter: select the favorite in Starred'
            Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true
            Snapshot 'action'
            Press @(0x12, 0x32) 'Alt+2: open workspace A before updater restart'
            Wait-Until {
                $state = Read-Inbox
                $saved = Read-Session
                $null -ne $state -and $null -ne $saved -and $state.active_workspace -eq 0 -and
                    $saved.active_workspace -eq 0 -and $state.starred_view -eq $false -and $saved.starred_view -eq $false
            } 'workspace A active before updater Starred selection'
            Press @(0x12, 0x31) 'Alt+1: open Starred from workspace A before updater restart'
            Focus-Palette 'Restore middle' $middleIndex
            Press @(0x0D) 'Enter: select the workspace B favorite by name before updater restart'
            Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true
            Prepare-SessionRestoreGroupOrder 'update-restart'
            Snapshot 'update-restart-action'
            Restart-SessionRestore 'update-restart' $false $true
            Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true
            Wait-Until { @((Read-Session).tabs | Where-Object { $_.name -ceq 'Restore middle' -and $_.workspace -eq $workspace -and $_.favorite -eq $true }).Count -eq 1 } 'updater favorite retains its original home and favorite flag'
            Save-Json (Read-Inbox) 'update-restart-after.inbox.json'
            Save-Json (Read-Session) 'update-restart-after.session.json'
            Snapshot 'update-restart-after'
            $result.checks += @{ name = 'update-restart-selection'; session = 'Restore middle'; workspace = $workspace; workspaceId = $workspaceId; starred_view = (Read-Inbox).starred_view; shellId = (Read-Inbox).active_shell_id }
            Prepare-SessionRestoreGroupOrder 'normal-close'
            Snapshot 'action'
            Restart-SessionRestore 'normal-close' $false
            Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true
            Wait-Until { @((Read-Session).tabs | Where-Object { $_.name -ceq 'Restore middle' -and $_.favorite -eq $true }).Count -eq 1 } 'favorite retained after Starred restore'
            Save-Json (Read-Inbox) 'normal-close-after.inbox.json'
            Save-Json (Read-Session) 'normal-close-after.session.json'
            Snapshot 'normal-close-after'
            $result.checks += @{ name = 'normal-close-selection'; session = 'Restore middle'; workspace = $workspace; workspaceId = $workspaceId; shellId = (Read-Inbox).active_shell_id }
            $result.checks += @{ name = 'starred-view-selection'; session = 'Restore middle'; starred_view = (Read-Inbox).starred_view }
            Wait-Until {
                Doctor
                [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window
            } 'normal-close hook-ready owned foreground before workspace input'
            Press @([byte]0x12, [byte](0x32 + $workspace)) 'Alt+workspace digit: return to the favorite home workspace'
            Wait-Until {
                $state = Read-Inbox
                $null -ne $state -and $state.active_workspace -eq $workspace -and $state.starred_view -eq $false
            } 'favorite home workspace active outside Starred before palette input'
            $tabs = @((Read-Session).tabs)
            $middleIndex = -1
            for ($i = 0; $i -lt $tabs.Count; $i++) { if ($tabs[$i].name -ceq 'Restore middle') { $middleIndex = $i } }
            if ($middleIndex -lt 0) { throw 'Favorite session missing after normal close' }
            Focus-Palette 'Restore middle' $middleIndex
            Press @(0x0D) 'Enter: select the same favorite in its home workspace'
            Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $false
            Snapshot 'favorite-home-action'
            Restart-SessionRestore 'favorite-home-kill' $true
            Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $false
            Wait-Until { @((Read-Session).tabs | Where-Object { $_.name -ceq 'Restore middle' -and $_.favorite -eq $true }).Count -eq 1 } 'same session remains a favorite at home after kill'
            Save-Json (Read-Inbox) 'favorite-home-kill-after.inbox.json'
            Save-Json (Read-Session) 'favorite-home-kill-after.session.json'
            Snapshot 'favorite-home-kill-after'
            $result.checks += @{ name = 'favorite-home-selection'; session = 'Restore middle'; workspace = $workspace; workspaceId = $workspaceId; starred_view = (Read-Inbox).starred_view }
            $tabs = @((Read-Session).tabs)
            $firstIndex = -1
            for ($i = 0; $i -lt $tabs.Count; $i++) { if ($tabs[$i].name -ceq 'Restore first') { $firstIndex = $i } }
            if ($firstIndex -lt 0) { throw 'First session missing from saved tabs' }
            Wait-Until {
                Doctor
                [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window
            } 'favorite-home-kill hook-ready owned foreground before palette input'
            Focus-Palette 'Restore first' $firstIndex
            Press @(0x0D) 'Enter: select a different named session before the kill'
            Assert-SessionRestoreSelection 'Restore first' $workspace $workspaceId
            Snapshot 'kill-action'
            Restart-SessionRestore 'process-kill' $true
            Assert-SessionRestoreSelection 'Restore first' $workspace $workspaceId
            Save-Json (Read-Inbox) 'process-kill-after.inbox.json'
            Save-Json (Read-Session) 'process-kill-after.session.json'
            $result.checks += @{ name = 'process-kill-selection'; session = 'Restore first'; workspace = $workspace; workspaceId = $workspaceId; shellId = (Read-Inbox).active_shell_id }
            foreach ($stage in @('favorite-cross-workspace-close', 'favorite-cross-workspace-kill')) {
                Wait-Until {
                    Doctor
                    [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window
                } "$stage hook-ready owned foreground before workspace input"
                Press @(0x12, 0x32) 'Alt+2: open workspace A, not the favorite home workspace B'
                Wait-Until {
                    $state = Read-Inbox
                    $saved = Read-Session
                    $null -ne $state -and $null -ne $saved -and $state.active_workspace -eq 0 -and
                        $saved.active_workspace -eq 0 -and $state.starred_view -eq $false -and $saved.starred_view -eq $false
                } 'workspace A active before opening Starred from outside the favorite home'
                Press @(0x12, 0x31) 'Alt+1: open Starred from workspace A'
                $tabs = @((Read-Session).tabs)
                $middleIndex = -1
                for ($i = 0; $i -lt $tabs.Count; $i++) { if ($tabs[$i].name -ceq 'Restore middle') { $middleIndex = $i } }
                if ($middleIndex -lt 0) { throw 'Cross-workspace favorite missing from saved tabs' }
                Focus-Palette 'Restore middle' $middleIndex
                Press @(0x0D) 'Enter: select the workspace B favorite by name in Starred'
                Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true
                Prepare-SessionRestoreGroupOrder $stage
                Restart-SessionRestore $stage ($stage -eq 'favorite-cross-workspace-kill')
                Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true
                Wait-Until { @((Read-Session).tabs | Where-Object { $_.name -ceq 'Restore middle' -and $_.workspace -eq $workspace -and $_.favorite -eq $true }).Count -eq 1 } 'cross-workspace favorite retains its original home and favorite flag'
                Save-Json (Read-Inbox) ($stage + '-after.inbox.json')
                Save-Json (Read-Session) ($stage + '-after.session.json')
                Snapshot ($stage + '-after')
            }
            $result.checks += @{ name = 'favorite-cross-workspace-selection'; session = 'Restore middle'; openedFromWorkspace = 0; workspace = $workspace; workspaceId = $workspaceId; starred_view = (Read-Inbox).starred_view }
            $requiredChecks = @('normal-close-selection', 'starred-view-selection', 'favorite-home-selection', 'process-kill-selection', 'favorite-cross-workspace-selection', 'update-restart-selection')
            foreach ($check in $requiredChecks) {
                if (@($result.checks | Where-Object { $_.name -ceq $check }).Count -ne 1) { throw "Required session restore check missing or duplicated: $check" }
            }
            if ($result.checks.Count -ne $requiredChecks.Count) { throw 'All selection and workspace-view restore checks are required' }
            Snapshot 'after'
        