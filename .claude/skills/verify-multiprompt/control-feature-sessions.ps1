
            Wait-Until {
                $state = Read-Session
                $inbox = Read-Inbox
                $null -ne $state -and $null -ne $inbox -and $state.active_workspace -eq 0 -and @($state.tabs).Count -eq 2 -and $state.active_tab -eq 1 -and $state.tabs[1].kind -eq 'tmux' -and $state.tabs[1].tmux_session -eq 'second' -and $state.tabs[1].tmux_host -eq 2 -and $inbox.active_workspace -eq 0 -and $inbox.active_shell_id -eq $state.tabs[1].shell_id -and @($inbox.shells | Where-Object { $_.sid -eq $inbox.active_shell_id -and $_.name -eq 'Second' }).Count -eq 1
            } 'second seeded remote tab active in Other' 60
            Save-Json @{ session = (Read-Session); inbox = (Read-Inbox) } 'sessions-initial.json'
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
            Palette 'hide from sidebar'
            Press @(0x0D) 'Enter: hide notes-only chat'
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
            Palette 'hide from sidebar'
            Press @(0x0D) 'Enter: hide zz-last-folder chat'
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
            Palette 'hide from sidebar'
            Press @(0x0D) 'Enter: hide beta terminal'
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
        