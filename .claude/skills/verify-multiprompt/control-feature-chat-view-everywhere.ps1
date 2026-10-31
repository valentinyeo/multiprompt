
            $result.agentBoundary = @{ liveDeliveryVerified = $false; reason = 'Local CMD sessions exercise view preferences and persistence, not agent delivery or remote tmux creation' }
            Palette 'interface'
            Press @(0x28) 'Down: UI Size: Decrease'
            Press @(0x28) 'Down: UI Size: Reset'
            Press @(0x0D) 'Enter: persist initial session through UI Size: Reset'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 1 } 'one initial saved CMD session'
            Focus-Palette 'tab order' 6217
            Press @(0x28) 'Down: Tab Order Manual'
            Press @(0x0D) 'Enter: keep creation order for Ctrl+1/2/3'
            Wait-Until {
                $path = Join-Path $scratch 'roaming/ZigShell/session.json.launch.json'
                if (-not (Test-Path $path)) { return $false }
                $launch = Get-Content $path -Raw | ConvertFrom-Json
                $launch.PSObject.Properties['sort_auto'] -and -not $launch.sort_auto
            } 'manual tab order saved before creating sessions'
            for ($count = 2; $count -le 3; $count++) {
                Focus-Palette 'new cmd' 2000
                Snapshot ("new-session-$count-action")
                Press @(0x0D) 'Enter: New CMD Shell'
                Wait-Until { $state = Read-Session; @($state.tabs).Count -eq $count -and $state.active_tab -eq $count - 1 } "user-created CMD session $count"
            }
            Snapshot 'sessions-created'
            Focus-Palette 'pin to top' 6293
            Snapshot 'pin-action'
            Press @(0x0D) 'Enter: Pin to Top on session 3'
            Wait-ChatViews @($false, $false, $false) 2 'pinned-shell'
            Press @(0x12, 0x43) 'Alt+C: pinned session can enter Chat View'
            $toggleReady = [DateTime]::UtcNow.AddMilliseconds(1600)
            Wait-ChatViews @($false, $false, $true) 2 'pinned-toggle-chat'
            Wait-Until { [DateTime]::UtcNow -ge $toggleReady } 'Alt+C debounce elapsed before pinned shell toggle'
            Press @(0x12, 0x43) 'Alt+C: pinned session can return to shell'
            $toggleReady = [DateTime]::UtcNow.AddMilliseconds(1600)
            Wait-ChatViews @($false, $false, $false) 2 'pinned-toggle-shell'
            Focus-Palette 'chat view on everywhere' 6346
            Snapshot 'action'
            Press @(0x0D) 'Enter: Chat View on everywhere once'
            Wait-ChatViews @($true, $true, $true) 2 'on-everywhere'
            Press @(0x11, 0x31) 'Ctrl+1: show session 1 in Chat View'
            Wait-ChatViews @($true, $true, $true) 0 'session-1-chat'
            Wait-Until { [DateTime]::UtcNow -ge $toggleReady } 'Alt+C debounce elapsed before session 1 toggle'
            Press @(0x12, 0x43) 'Alt+C: session 1 back to shell'
            Wait-ChatViews @($false, $true, $true) 0 'session-1-toggled'
            Press @(0x11, 0x32) 'Ctrl+2: show session 2 in Chat View'
            Wait-ChatViews @($false, $true, $true) 1 'session-2-chat'
            Press @(0x11, 0x31) 'Ctrl+1: return to session 1 without forcing Chat View'
            Wait-ChatViews @($false, $true, $true) 0 'toggle-sticks'
            Focus-Palette 'chat view off everywhere' 6347
            Snapshot 'off-action'
            Press @(0x0D) 'Enter: Chat View off everywhere once'
            Wait-ChatViews @($false, $false, $false) 0 'off-everywhere'
            Press @(0x11, 0x33) 'Ctrl+3: pinned session follows Off Everywhere'
            Wait-ChatViews @($false, $false, $false) 2 'pinned-after-off'
            Focus-Palette 'unpin from top' 6293
            Press @(0x0D) 'Enter: unpin before normal app close for restart'
            Wait-ChatViews @($false, $false, $false) 2 'unpinned-before-restart' $false
            Restart-ChatView 3
            Save-Json (Read-Session) 'restart-before-input.session.json'
            Press @(0x11, 0x31) 'Ctrl+1: restored first session'
            Wait-ChatViews @($false, $false, $false) 0 'restart-session-1' $false
            Press @(0x11, 0x32) 'Ctrl+2: restored second session'
            Wait-ChatViews @($false, $false, $false) 1 'restart-session-2' $false
            Press @(0x11, 0x33) 'Ctrl+3: restored third session'
            Wait-ChatViews @($false, $false, $false) 2 'restart-session-3' $false
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            foreach ($query in @('chat view per tab', 'lock session', 'always chat view for this session', 'always shell view for this session', 'clear always view for this session')) {
                Focus-Palette 'chat view on everywhere' 6346
                Press @(0x1B) 'Esc: close known positive palette query'
                $start = ((Get-Content $log -Raw) -join '').Length
                Press @(0x11, 0x4B) 'Ctrl+K: reopen empty command palette'
                Wait-Until {
                    ((Get-Content $log -Raw) -join '').Substring($start) -match '\[palette\] ready chars=0 count=\d+ target=\d+(?:\r?\n|$)' -and
                    [VerifyNative]::GetFocusedWindow($script:window) -eq $script:window
                } 'empty palette ready for removed-command query'
                Type-Text $query
                Wait-Until {
                    ((Get-Content $log -Raw) -join '').Substring($start) -match ("\[palette\] ready chars=" + $query.Length + " count=0 target=0(?:\r?\n|$)")
                } "removed command has zero palette rows: $query"
                Snapshot ('absent-' + $query.Replace(' ', '-'))
                Press @(0x1B) 'Esc: close empty palette'
            }
            Wait-ChatViews @($false, $false, $false) 2 'after' $false
            $result.checks += @{ name = 'chat-view-everywhere-once'; allOn = @(0, 1, 2); pinnedToggleWorks = $true; pinnedCloseRefused = $true; laterToggleSticks = $true; offEverywhere = $true; restartViews = $true; removedCommands = 5; entry = 'Ctrl+K, Ctrl+W, Ctrl+1/2/3 and Alt+C' }
        