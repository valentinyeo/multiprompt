
            Wait-Until {
                $state = Read-Session
                $inbox = Read-Inbox
                $null -ne $state -and $null -ne $inbox -and $state.active_workspace -eq 0 -and @($state.tabs).Count -eq 2 -and $state.active_tab -eq 1 -and $state.tabs[1].kind -eq 'tmux' -and $state.tabs[1].tmux_session -eq 'second' -and $state.tabs[1].tmux_host -eq 2 -and $inbox.active_workspace -eq 0 -and $inbox.active_shell_id -eq $state.tabs[1].shell_id -and @($inbox.shells | Where-Object { $_.sid -eq $inbox.active_shell_id -and $_.name -eq 'Second' }).Count -eq 1
            } 'second seeded remote tab active in Other' 60
            Save-Json @{ session = (Read-Session); inbox = (Read-Inbox) } 'sessions-initial.json'
            $repoLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $initial = Read-Session
            $firstIndices = @(for ($i = 0; $i -lt @($initial.tabs).Count; $i++) { if ($initial.tabs[$i].tmux_session -ceq 'first') { $i } })
            if ($firstIndices.Count -ne 1) { throw 'First target is not unique' }
            $firstIndex = [int]$firstIndices[0]
            $first = $initial.tabs[$firstIndex]
            $firstHost = if ($first.PSObject.Properties['tmux_host']) { [int]$first.tmux_host } else { 0 }
            if ($firstIndex -eq $initial.active_tab -or $first.group_id -ne 17 -or $firstHost -ne 0 -or $first.cwd -cne '/home/owner/projects/sample') { throw 'Inactive First target identity changed before input' }
            Snapshot 'group-target-before'
            Wait-Until { @(Get-Content $repoLog | Where-Object { $_ -match ('\[photo-proof\] expanded target=' + $firstIndex + ' rect=') }).Count -gt 0 } 'First target paint geometry published'
            $geometry = @(Get-Content $repoLog | Where-Object { $_ -match ('\[photo-proof\] expanded target=' + $firstIndex + ' rect=') })[-1]
            if ($geometry -notmatch '\[photo-proof\] expanded target=\d+ rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)$') { throw 'First target geometry malformed' }
            $left = [int]$Matches[1]; $top = [int]$Matches[2]; $right = [int]$Matches[3]; $bottom = [int]$Matches[4]
            $client = New-Object VerifyNative+Rect
            if (-not [VerifyNative]::GetClientRect($script:window, [ref]$client) -or $left -lt 0 -or $top -lt 0 -or $right -le $left -or $bottom -le $top -or $right -gt $client.Right -or $bottom -gt $client.Bottom) { throw 'First target geometry outside client' }
            $x = [int][Math]::Floor(($left + $right) / 2.0)
            $y = [int][Math]::Floor(($top + $bottom) / 2.0)
            Save-Json @{ shellId = $first.shell_id; index = $firstIndex; group = $first.group_id; host = $firstHost; cwd = $first.cwd; activeShellId = $initial.tabs[$initial.active_tab].shell_id; geometry = $geometry; center = @($x, $y) } 'group-target.json'
            $rowsBefore = @(Get-Content $repoLog | Where-Object { $_ -match '\[palette\] rows chars=' }).Count
            Doctor
            Assert-Foreground
            $current = Read-Session
            $currentFirst = $current.tabs[$firstIndex]
            $currentHost = if ($currentFirst.PSObject.Properties['tmux_host']) { [int]$currentFirst.tmux_host } else { 0 }
            if ($currentFirst.shell_id -ne $first.shell_id -or $current.active_tab -ne $initial.active_tab -or $current.tabs[$current.active_tab].shell_id -ne $initial.tabs[$initial.active_tab].shell_id -or $currentFirst.group_id -ne 17 -or $currentHost -ne 0 -or $currentFirst.cwd -cne $first.cwd) { throw 'First target changed before right-click' }
            Record 'Right-click the inactive grouped First tab'
            [VerifyNative]::RightClickClient($script:window, $x, $y)
            Wait-Until { @(Get-Content $repoLog | Where-Object { $_ -match '\[palette\] rows chars=' }).Count -gt $rowsBefore } 'tab context opened'
            $readyBefore = @(Get-Content $repoLog | Where-Object { $_ -match '\[palette\] ready chars=22 count=\d+ target=7107$' }).Count
            Type-Text 'new chat in this group'
            Wait-Until { @(Get-Content $repoLog | Where-Object { $_ -match '\[palette\] ready chars=22 count=\d+ target=7107$' }).Count -gt $readyBefore } 'group action selected on target tab'
            Snapshot 'group-new-action'
            Press @(0x0D) 'Enter: new chat in this group'
            Wait-Until {
                $state = Read-Session
                $new = @($state.tabs | Where-Object { $_.PSObject.Properties['group_id'] -and $_.group_id -eq 17 -and $_.tmux_session -ne 'first' })
                if (@($state.tabs).Count -ne 3 -or $new.Count -ne 1) { return $false }
                $newHost = if ($new[0].PSObject.Properties['tmux_host']) { [int]$new[0].tmux_host } else { 0 }
                $newHost -eq 0 -and $new[0].PSObject.Properties['cwd'] -and $new[0].cwd -ceq '/home/owner/projects/sample' -and $new[0].PSObject.Properties['cv'] -and $new[0].cv -eq $true
            } 'new group chat saved with target host and owner folder' 60
            Wait-Until {
                $script:groupLaunch = @(Get-ChildItem -LiteralPath $env:MP_VERIFY_STATE -Filter 'invocation-*.txt' | Where-Object { (Get-Content $_.FullName -Raw) -match 'host enable claude.*--cwd /home/owner/projects/sample' })
                $script:groupLaunch.Count -eq 1
            } 'actual SSH invocation contains hosted owner cwd' 60
            Copy-Item $script:groupLaunch[0].FullName (Join-Path $Evidence 'group-hosted-launch.txt')
            $groupState = Read-Session
            Save-Json $groupState 'group-new-session.json'
            $groupTab = @($groupState.tabs | Where-Object { $_.PSObject.Properties['group_id'] -and $_.group_id -eq 17 -and $_.tmux_session -ne 'first' })[0]
            $groupHost = if ($groupTab.PSObject.Properties['tmux_host']) { [int]$groupTab.tmux_host } else { 0 }
            if ($groupHost -ne 0 -or $groupTab.cwd -cne '/home/owner/projects/sample') { throw 'Saved group launch identity changed before evidence' }
            Snapshot 'group-new-chat'
            $result.checks += @{ name = 'group-new-target'; group = $groupTab.group_id; host = $groupHost; cwd = $groupTab.cwd; boundary = 'SSH stand-in; no real provider or server' }
            Press @(0x11, 0x57) 'Ctrl+W: close group chat'
            Wait-Until { @((Read-Session).tabs).Count -eq 2 } 'group chat closed'
            Palette 'Second'
            Press @(0x0D) 'Enter: return to second server'
            Wait-Until { $state = Read-Session; $state.tabs[$state.active_tab].tmux_host -eq 2 } 'second server active after group action'
            $beforeClaude = @((Read-Session).tabs).Count
            Press @(0x11, 0x54) 'Ctrl+T: new Claude chat'
            Wait-Until { @(Get-ChildItem -LiteralPath $env:MP_VERIFY_STATE -Filter 'listing-*.txt').Count -gt 0 } 'repository discovery response'
            $repoLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
            Wait-Until { (Get-Content -LiteralPath $repoLog -Raw) -match '\[palette\] rows chars=0 count=101 ids=6702 6710 6711' } 'picker shows all 100 project folders'
            Snapshot 'repo-picker-rows'
            Type-Text 'notes-only'
            Snapshot 'ctrl-t-notes-only-picker'
            Press @(0x0D) 'Enter: select notes-only'
            Wait-Until {
                $state = Read-Session
                if ($null -eq $state -or @($state.tabs).Count -ne $beforeClaude + 1) { return $false }
                $tab = @($state.tabs)[$state.active_tab]
                $tab.cwd -eq '/work/projects/notes-only' -and $tab.cv -eq $true -and $tab.tmux_host -eq 2
            } 'Ctrl+T notes-only chat saved'
            Snapshot 'ctrl-t-notes-only-chat'
            $result.checks += @{ name = 'ctrl-t-notes-only-chat'; cwd = '/work/projects/notes-only'; cv = $true; host = 2 }
            Press @(0x11, 0x57) 'Ctrl+W: close notes-only chat'
            Wait-Until { @((Read-Session).tabs).Count -eq $beforeClaude } 'notes-only chat closed'
            Palette 'Second'
            Press @(0x0D) 'Enter: return to the seeded third-server session'
            Wait-Until { $state = Read-Session; $state.tabs[$state.active_tab].tmux_host -eq 2 } 'host 2 active before terminal choice'

            foreach ($query in @('soft', 'factory soft')) {
                Press @(0x11, 0x54) 'Ctrl+T: search repository by partial name'
                Type-Text $query
                $searchProof = if ($query -eq 'soft') { 'ctrl-t-soft' } else { 'ctrl-t-reversed-words' }
                Snapshot ($searchProof + '-picker')
                Press @(0x0D) 'Enter: select software-factory before path-only matches'
                Wait-Until {
                    $state = Read-Session
                    if ($null -eq $state -or @($state.tabs).Count -ne $beforeClaude + 1) { return $false }
                    $tab = @($state.tabs)[$state.active_tab]
                    $tab.cwd -eq '/work/projects/software-factory' -and $tab.cv -eq $true -and $tab.tmux_host -eq 2
                } 'partial repository query opens software-factory on the selected host'
                Save-Json (Read-Session) ($searchProof + '-session.json')
                Snapshot ($searchProof + '-chat')
                $result.checks += @{ name = $searchProof; query = $query; cwd = '/work/projects/software-factory'; cv = $true; host = 2 }
                Press @(0x11, 0x57) 'Ctrl+W: close software-factory chat'
                Wait-Until { @((Read-Session).tabs).Count -eq $beforeClaude } 'software-factory chat closed'
                Palette 'Second'
                Press @(0x0D) 'Enter: return to the seeded third-server session'
                Wait-Until { $state = Read-Session; $state.tabs[$state.active_tab].tmux_host -eq 2 } 'host 2 active after search proof'
            }

            Palette 'new claude in terminal'
            Press @(0x0D) 'Enter: New Claude in terminal'
            Snapshot 'terminal-picker-cancel'
            Press @(0x1B) 'Esc: cancel repository picker'
            Press @(0x1B) 'Esc: close palette'
            $cancelled = Read-Session
            if (@($cancelled.tabs).Count -ne $beforeClaude -or $cancelled.tabs[$cancelled.active_tab].tmux_host -ne 2) { throw 'Cancelling the picker changed tabs or the active host' }
            Press @(0x11, 0x54) 'Ctrl+T: new Claude chat after cancel'
            Type-Text 'zz-last-folder'
            Snapshot 'ctrl-t-zz-last-folder-picker'
            Press @(0x0D) 'Enter: select zz-last-folder'
            Wait-Until {
                $state = Read-Session
                if ($null -eq $state -or @($state.tabs).Count -ne $beforeClaude + 1) { return $false }
                $tab = @($state.tabs)[$state.active_tab]
                $tab.cwd -eq '/work/projects/zz-last-folder' -and $tab.cv -eq $true -and $tab.tmux_host -eq 2
            } 'Ctrl+T zz-last-folder chat after cancel saved'
            Snapshot 'ctrl-t-zz-last-folder-chat'
            $result.checks += @{ name = 'cancel-then-ctrl-t-zz-last-folder'; cwd = '/work/projects/zz-last-folder'; cv = $true; host = 2 }
            Press @(0x11, 0x57) 'Ctrl+W: close zz-last-folder chat'
            Wait-Until { @((Read-Session).tabs).Count -eq $beforeClaude } 'zz-last-folder chat closed'
            Palette 'Second'
            Press @(0x0D) 'Enter: return to the seeded third-server session'
            Wait-Until { $state = Read-Session; $state.tabs[$state.active_tab].tmux_host -eq 2 } 'host 2 active before terminal session'

            Palette 'new claude in terminal'
            Press @(0x0D) 'Enter: New Claude in terminal'
            Type-Text 'beta'
            Snapshot 'terminal-beta-picker'
            Press @(0x0D) 'Enter: select beta terminal'
            Wait-Until {
                $state = Read-Session
                if ($null -eq $state -or @($state.tabs).Count -ne $beforeClaude + 1) { return $false }
                $tab = @($state.tabs)[$state.active_tab]
                $tab.cwd -eq '/work/projects/beta' -and (-not $tab.PSObject.Properties['cv'] -or $tab.cv -eq $false) -and $tab.tmux_host -eq 2
            } 'beta terminal saved'
            Snapshot 'terminal-beta'
            $result.checks += @{ name = 'terminal-beta'; cwd = '/work/projects/beta'; cv = $false; host = 2 }
            Press @(0x11, 0x57) 'Ctrl+W: close beta terminal'
            Wait-Until { @((Read-Session).tabs).Count -eq $beforeClaude } 'beta terminal closed'

            $before = @( (Read-Session).tabs ).Count
            Palette 'new cmd'
            Snapshot 'action'
            Press @(0x0D) 'Enter: New CMD shell'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq $before + 1 } 'new CMD tab saved'
            Press @(0x71) 'F2: rename active tab'
            Press @(0x11, 0x41) 'Ctrl+A: replace tab name'
            Type-Text 'Verification session'
            Press @(0x0D) 'Enter: save tab name'
            Wait-Until { @((Read-Session).tabs | Where-Object { $_.name -eq 'Verification session' }).Count -eq 1 } 'renamed tab persisted'
            $marker = Join-Path $scratch 'user-created.txt'
            Type-Text ('echo verified-from-real-cmd>"' + $marker + '"')
            Press @(0x0D) 'Enter: execute shell command'
            Wait-Until { (Test-Path $marker) -and (Get-Content $marker -Raw).Trim() -eq 'verified-from-real-cmd' } 'real console command wrote file'
            $result.checks += @{ name = 'create-rename-execute'; tabsBefore = $before; tabsAfter = @((Read-Session).tabs).Count; marker = (Get-Content $marker -Raw).Trim() }
            Snapshot 'after'
        