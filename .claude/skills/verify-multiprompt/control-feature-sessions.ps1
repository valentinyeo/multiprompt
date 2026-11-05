
            Wait-Until {
                $state = Read-Session
                $inbox = Read-Inbox
                $null -ne $state -and $null -ne $inbox -and $state.active_workspace -eq 0 -and @($state.tabs).Count -eq 3 -and $state.active_tab -eq 1 -and $state.tabs[1].kind -eq 'tmux' -and $state.tabs[1].tmux_session -eq 'second' -and $state.tabs[1].tmux_host -eq 2 -and $inbox.active_workspace -eq 0 -and $inbox.active_shell_id -eq $state.tabs[1].shell_id -and @($inbox.shells | Where-Object { $_.sid -eq $inbox.active_shell_id -and $_.name -eq 'Second' }).Count -eq 1
            } 'second seeded remote tab active in Other' 60
            Save-Json @{ session = (Read-Session); inbox = (Read-Inbox) } 'sessions-initial.json'
            Press @(0x12, 0x33) 'Alt+3: switch to Example workspace'
            Wait-Until {
                $state = Read-Session
                $tab = $state.tabs[$state.active_tab]
                $state.active_workspace -eq 1 -and $tab.tmux_session -ceq 'terminal-owner' -and (-not $tab.PSObject.Properties['cwd'] -or -not $tab.cwd) -and $tab.ccwd -ceq '/home/owner/projects/sample' -and @($state.tabs | Where-Object { $_.PSObject.Properties['workspace'] -and $_.workspace -eq 1 }).Count -eq 1
            } 'Example workspace has only the owner terminal' 60
            $cachePath = Join-Path $scratch 'roaming/ZigShell/poll-cache-vps.json'
            Wait-Until {
                if (-not (Test-Path $cachePath)) { return $false }
                try { $cache = Get-Content $cachePath -Raw | ConvertFrom-Json } catch { return $false }
                @($cache.sessions | Where-Object { $_.name -ceq 'terminal-owner' -and $_.host -eq 0 -and $_.path -ceq '/home/login' }).Count -eq 1
            } 'app-published tmux cache contains the login-home carrier' 90
            Copy-Item $cachePath (Join-Path $Evidence 'workspace-carrier-cache.json')
            Save-Json (Read-Session) 'workspace-owner-before.json'
            Snapshot 'workspace-owner-before'
            $priorInvocations = @(Get-ChildItem -LiteralPath $env:MP_VERIFY_STATE -Filter 'invocation-*.txt' | ForEach-Object { $_.Name })
            Press @(0x11, 0x54) 'Ctrl+T: new chat in Example workspace'
            Wait-Until {
                $state = Read-Session
                if (@($state.tabs).Count -ne 4 -or $state.active_workspace -ne 1) { return $false }
                $tab = $state.tabs[$state.active_tab]
                $hostId = if ($tab.PSObject.Properties['tmux_host']) { [int]$tab.tmux_host } else { 0 }
                $tab.PSObject.Properties['workspace'] -and $tab.workspace -eq 1 -and $hostId -eq 0 -and $tab.PSObject.Properties['cwd'] -and $tab.cwd -ceq '/home/owner/projects/sample' -and $tab.PSObject.Properties['cv'] -and $tab.cv -eq $true
            } 'workspace new chat saved with reported owner folder' 60
            Wait-Until {
                $script:workspaceLaunch = @(Get-ChildItem -LiteralPath $env:MP_VERIFY_STATE -Filter 'invocation-*.txt' | Where-Object { $_.Name -notin $priorInvocations -and (Get-Content $_.FullName -Raw) -match 'host enable claude.*--cwd /home/owner/projects/sample' })
                $script:workspaceLaunch.Count -ge 1
            } 'workspace hosted launch uses absolute owner folder' 60
            Copy-Item $script:workspaceLaunch[0].FullName (Join-Path $Evidence 'workspace-hosted-launch.txt')
            Save-Json (Read-Session) 'workspace-owner-new-session.json'
            Snapshot 'workspace-owner-new-chat'
            $result.checks += @{ name = 'workspace-reported-owner'; workspace = 'Example'; host = 0; cwd = '/home/owner/projects/sample'; boundary = 'Seeded provider-reported cwd and SSH stand-in; no real provider or server' }
            Palette 'hide from sidebar'
            Press @(0x0D) 'Enter: hide Example workspace chat'
            Wait-Until { @((Read-Session).tabs).Count -eq 3 } 'Example workspace chat hidden'
            Press @(0x12, 0x32) 'Alt+2: return to Other workspace'
            Wait-Until { $state = Read-Session; $state.active_workspace -eq 0 -and $state.tabs[$state.active_tab].tmux_session -ceq 'second' } 'Other workspace and second server restored'
            $beforeClaude = @((Read-Session).tabs).Count
            Press @(0x11, 0x54) 'Ctrl+T: new Claude chat'
            Wait-Until { @(0, 1, 2 | Where-Object { @(Get-ChildItem -LiteralPath $env:MP_VERIFY_STATE -Filter ("listing-$_-*.txt")).Count -gt 0 }).Count -eq 3 } 'all host discovery responses'
            $repoLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
            Wait-Until { (Get-Content -LiteralPath $repoLog -Raw) -match '\[palette\] rows chars=0 count=104 ids=6702 6710 6711' } 'picker shows 102 discovered folders and the owner terminal carrier folder'
            Snapshot 'repo-picker-rows'
            $logBefore = (Get-Content -LiteralPath $repoLog -Raw).Length
            Type-Text 'ar'
            Wait-Until { $log = Get-Content -LiteralPath $repoLog -Raw; $log.Length -gt $logBefore -and $log.Substring($logBefore) -match '\[palette\] rows chars=2 count=4 ' } 'combined search shows three matching folders'
            Snapshot 'repo-picker-all-servers'
            Press @(0x1B) 'Esc: leave initial picker'
            Press @(0x1B) 'Esc: close palette'
            foreach ($case in @(
                @{ query = 'remote-2 cedar'; host = 1; alias = 'remote-2'; cwd = '/work/secondary/cedar'; proof = 'host1' },
                @{ query = 'atlas'; host = 0; alias = 'remote-1'; cwd = '/work/primary/atlas'; proof = 'host0' }
            )) {
                if ($case.host -eq 1 -and @((Read-Session).tabs | Where-Object { $tab = $_; $hostId = if ($tab.PSObject.Properties['tmux_host']) { [int]$tab.tmux_host } else { 0 }; $hostId -eq 1 }).Count -ne 0) { throw 'Host 1 already has a seeded tab' }
                Press @(0x11, 0x54) 'Ctrl+T: choose another server'
                $logBefore = (Get-Content -LiteralPath $repoLog -Raw).Length
                Type-Text $case.query
                Wait-Until { $log = Get-Content -LiteralPath $repoLog -Raw; $log.Length -gt $logBefore -and $log.Substring($logBefore) -match ('\[palette\] rows chars=' + $case.query.Length + ' count=2 ') } 'one matching remote row'
                Snapshot ('ctrl-t-' + $case.proof + '-picker')
                Press @(0x0D) 'Enter: select the matching server and folder'
                Wait-Until {
                    $state = Read-Session
                    if ($null -eq $state -or @($state.tabs).Count -ne $beforeClaude + 1) { return $false }
                    $tab = $state.tabs[$state.active_tab]
                    $hostId = if ($tab.PSObject.Properties['tmux_host']) { [int]$tab.tmux_host } else { 0 }
                    $tab.cwd -eq $case.cwd -and $hostId -eq $case.host -and $tab.cv -eq $true
                } 'selected remote folder and host saved'
                Wait-Until { @(Get-ChildItem -LiteralPath $env:MP_VERIFY_STATE -Filter 'invocation-*.txt' | Where-Object { $text = Get-Content -LiteralPath $_.FullName -Raw; $text.Contains($case.alias) -and $text.Contains($case.cwd) -and -not $text.Contains('tmux new-session') -and -not $text.Contains('tmux attach') -and -not $text.Contains('sleep infinity') -and $text.Contains('host enable claude') -and $text.Contains('host start claude') -and $text.Contains('--cwd ' + $case.cwd) }).Count -gt 0 } 'SSH command starts Claude on selected host and path'
                Wait-Until { $state = Read-Session; $tab = $state.tabs[$state.active_tab]; $tab.pid -eq 0 -and $tab.cv -eq $true } 'live chat stays open after its finite startup command exits'
                Save-Json (Read-Session) ('ctrl-t-' + $case.proof + '-session.json')
                Snapshot ('ctrl-t-' + $case.proof + '-chat')
                $result.checks += @{ name = ('cross-host-' + $case.proof); host = $case.host; cwd = $case.cwd; alias = $case.alias }
                Palette 'hide from sidebar'
                Press @(0x0D) 'Enter: hide cross-host chat'
                Wait-Until { @((Read-Session).tabs).Count -eq $beforeClaude } 'cross-host chat closed'
                Palette 'Second'
                Press @(0x0D) 'Enter: return to host 2'
                Wait-Until { $state = Read-Session; $state.tabs[$state.active_tab].tmux_host -eq 2 } 'host 2 active before next choice'
            }
            $offlineFile = Join-Path $env:MP_VERIFY_STATE 'offline-1'
            [IO.File]::WriteAllText($offlineFile, 'offline')
            $logBefore = (Get-Content -LiteralPath $repoLog -Raw).Length
            Press @(0x11, 0x54) 'Ctrl+T: reopen after host 1 fails'
            Wait-Until { $log = Get-Content -LiteralPath $repoLog -Raw; $log.Length -gt $logBefore -and $log.Substring($logBefore).Contains('[repo] offline host=1') } 'production publishes host 1 offline'
            Type-Text 'remote-2 cedar'
            Snapshot 'ctrl-t-offline-picker'
            $launches = @(Get-ChildItem -LiteralPath $env:MP_VERIFY_STATE -Filter 'invocation-*.txt' | Where-Object { (Get-Content -LiteralPath $_.FullName -Raw).Contains('host enable claude') }).Count
            $logBefore = (Get-Content -LiteralPath $repoLog -Raw).Length
            Press @(0x0D) 'Enter: reject offline folder'
            Wait-Until { $log = Get-Content -LiteralPath $repoLog -Raw; $log.Length -gt $logBefore -and $log.Substring($logBefore).Contains('[repo] selection rejected') } 'offline selection rejected'
            if (@((Read-Session).tabs).Count -ne $beforeClaude) { throw 'Offline selection saved a tab' }
            $afterLaunches = @(Get-ChildItem -LiteralPath $env:MP_VERIFY_STATE -Filter 'invocation-*.txt' | Where-Object { (Get-Content -LiteralPath $_.FullName -Raw).Contains('host enable claude') }).Count
            if ($afterLaunches -ne $launches) { throw 'Offline selection launched SSH' }
            Press @(0x11, 0x54) 'Ctrl+T: use host 0 while host 1 is offline'
            Type-Text 'atlas'
            Snapshot 'ctrl-t-other-host-online-picker'
            Press @(0x0D) 'Enter: select available folder'
            Wait-Until {
                $state = Read-Session
                if ($null -eq $state -or @($state.tabs).Count -ne $beforeClaude + 1) { return $false }
                $tab = $state.tabs[$state.active_tab]
                $hostId = if ($tab.PSObject.Properties['tmux_host']) { [int]$tab.tmux_host } else { 0 }
                $hostId -eq 0 -and $tab.cwd -eq '/work/primary/atlas' -and $tab.cv -eq $true
            } 'other host stays usable'
            Palette 'hide from sidebar'
            Press @(0x0D) 'Enter: hide available host chat'
            Wait-Until { @((Read-Session).tabs).Count -eq $beforeClaude } 'available host chat closed'
            Palette 'Second'
            Press @(0x0D) 'Enter: return to host 2'
            Wait-Until { $state = Read-Session; $state.tabs[$state.active_tab].tmux_host -eq 2 } 'host 2 active after offline check'
            Remove-Item -LiteralPath $offlineFile
            $result.checks += @{ name = 'offline-enter-rejected'; tabs = $beforeClaude; launches = $launches }
            $logBefore = (Get-Content -LiteralPath $repoLog -Raw).Length
            Press @(0x11, 0x54) 'Ctrl+T: recover host 1'
            Wait-Until { $log = Get-Content -LiteralPath $repoLog -Raw; $log.Length -gt $logBefore -and $log.Substring($logBefore).Contains('[repo] online host=1') } 'host 1 discovery recovers'
            Snapshot 'ctrl-t-recovered-picker'
            Press @(0x1B) 'Esc: leave recovered picker'
            Press @(0x1B) 'Esc: close palette'
            Press @(0x11, 0x54) 'Ctrl+T: select an available server after offline rejection'
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
                Palette 'hide from sidebar'
                Press @(0x0D) 'Enter: hide software-factory chat'
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

            Palette 'Second'
            Press @(0x0D) 'Enter: return to Other on the third server'
            Wait-Until { $state = Read-Session; $state.active_workspace -eq 0 -and $state.tabs[$state.active_tab].tmux_host -eq 2 } 'Other active before saving its folder'
            $commandsFile = Join-Path $scratch 'roaming/ZigShell/commands.json'
            Palette 'set workspace folder'
            Press @(0x0D) 'Enter: set a saved folder for Other'
            Type-Text 'notes-only'
            Press @(0x0D) 'Enter: save notes-only as the Other default'
            Wait-Until {
                $commands = Get-Content -LiteralPath $commandsFile -Raw | ConvertFrom-Json
                @($commands.commands | Where-Object { $_.PSObject.Properties['workspace'] -and $_.workspace -eq 'Other' -and $_.cwd -eq '/work/projects/notes-only' -and $_.default }).Count -gt 0
            } 'Other saved default persisted through the palette'
            foreach ($repo in @('beta', 'zz-last-folder')) {
                Palette 'Second'
                Press @(0x0D) 'Enter: select Other before its next new session'
                Wait-Until { $state = Read-Session; $state.active_workspace -eq 0 -and $state.tabs[$state.active_tab].tmux_host -eq 2 } 'Other active for repeated picker proof'
                $beforeOther = @((Read-Session).tabs).Count
                Press @(0x11, 0x54) 'Ctrl+T: Other must ask despite its saved default'
                Type-Text $repo
                Snapshot ('other-saved-default-' + $repo + '-picker')
                Press @(0x0D) 'Enter: choose a different repo in Other'
                Wait-Until {
                    $state = Read-Session
                    if ($null -eq $state -or @($state.tabs).Count -ne $beforeOther + 1) { return $false }
                    $tab = @($state.tabs)[$state.active_tab]
                    $tab.cwd -eq ('/work/projects/' + $repo) -and $tab.cv -eq $true -and $tab.tmux_host -eq 2
                } 'Other starts in the chosen repo rather than its saved default'
                Save-Json (Read-Session) ('other-saved-default-' + $repo + '-session.json')
                Snapshot ('other-saved-default-' + $repo + '-chat')
                $result.checks += @{ name = 'other-saved-default-picker'; repo = $repo; ignoredDefault = '/work/projects/notes-only'; host = 2 }
                Palette 'hide from sidebar'
                Press @(0x0D) 'Enter: hide the Other proof chat'
                Wait-Until { @((Read-Session).tabs).Count -eq $beforeOther } 'Other proof chat closed'
            }
            $workspaceCount = @((Read-Session).workspaces).Count
            Press @(0x11, 0x4E) 'Ctrl+N: create a named workspace for the default-folder comparison'
            Wait-Until { $state = Read-Session; @($state.workspaces).Count -eq $workspaceCount + 1 -and $state.active_workspace -ne 0 } 'new comparison workspace saved'
            $namedState = Read-Session
            $namedSlot = [int]$namedState.active_workspace
            $namedWorkspace = [string]$namedState.workspaces[$namedSlot].name
            if ([string]::IsNullOrWhiteSpace($namedWorkspace)) { $namedWorkspace = 'Workspace ' + ($namedSlot + 1) }
            if ($namedWorkspace -eq 'Other') { throw 'Comparison workspace must not be Other' }
            $namedPickerLogStart = (Get-Content -LiteralPath $repoLog -Raw).Length
            Palette 'set workspace folder'
            Press @(0x0D) 'Enter: set the named workspace folder'
            Type-Text 'notes-only'
            Wait-Until {
                $text = Get-Content -LiteralPath $repoLog -Raw
                $text.Length -gt $namedPickerLogStart -and $text.Substring($namedPickerLogStart) -match '\[palette\] rows chars=10 count=2 ids=6702 6710'
            } 'named workspace folder row is ready on its selected host'
            Press @(0x0D) 'Enter: save the named workspace default'
            Wait-Until {
                $commands = Get-Content -LiteralPath $commandsFile -Raw | ConvertFrom-Json
                @($commands.commands | Where-Object { $_.PSObject.Properties['workspace'] -and $_.workspace -eq $namedWorkspace -and $_.cwd -eq '/work/projects/notes-only' -and $_.default }).Count -gt 0
            } 'named workspace default persisted through the palette'
            Snapshot 'named-workspace-saved-default-before'
            $beforeNamed = @((Read-Session).tabs).Count
            Press @(0x11, 0x54) 'Ctrl+T: named workspace starts directly in its saved folder'
            Wait-Until {
                $state = Read-Session
                if ($null -eq $state -or @($state.tabs).Count -ne $beforeNamed + 1 -or $state.active_workspace -ne $namedSlot) { return $false }
                $tab = @($state.tabs)[$state.active_tab]
                $tab.cwd -eq '/work/projects/notes-only' -and $tab.cv -eq $true
            } 'named workspace starts a chat without selecting a repo'
            Save-Json (Read-Session) 'named-workspace-saved-default-session.json'
            Snapshot 'named-workspace-saved-default-chat'
            $result.checks += @{ name = 'named-workspace-skips-picker'; workspace = $namedWorkspace; cwd = '/work/projects/notes-only'; cv = $true }
            Palette 'hide from sidebar'
            Press @(0x0D) 'Enter: hide the named workspace proof chat'
            Wait-Until { @((Read-Session).tabs).Count -eq $beforeNamed } 'named workspace proof chat closed'

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
        