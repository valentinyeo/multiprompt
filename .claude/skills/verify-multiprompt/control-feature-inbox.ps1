
            Press @(0x11, 0x10, 0x49) 'Ctrl+Shift+I: open Inbox'
            Wait-Until { [VerifyNative]::Title($script:window).StartsWith('Inbox - ') } 'Inbox window state'
            Press @(0x12, 0x49) 'Alt+I: select All split'
            Snapshot 'action'
            $prior = (Read-Inbox).shells[0].att
            Press @(0x55) 'u: toggle selected Inbox session unread'
            Wait-Until { (Read-Inbox).shells[0].att -ne $prior } 'published attention state toggled'
            Snapshot 'after'
            $result.checks += @{ name = 'inbox-toggle-read'; attentionBefore = $prior; attentionAfter = (Read-Inbox).shells[0].att; title = [VerifyNative]::Title($script:window) }
            Press @(0x1B) 'Esc: return from Inbox'
            Wait-Until { -not [VerifyNative]::Title($script:window).StartsWith('Inbox - ') } 'Inbox closed'
            Snapshot 'returned'
            Palette 'new cmd'
            Press @(0x0D) 'Enter: create a second CMD session to mute'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 2 -and $state.active_tab -eq 1 } 'second CMD session saved and selected'
            Wait-Until { $state = Read-Inbox; $null -ne $state -and @($state.shells).Count -eq 2 } 'both sessions published to the Inbox'
            $sid = (Read-Session).tabs[1].shell_id
            Wait-Until { $state = Read-Inbox; $null -ne $state -and @($state.shells | Where-Object { $_.sid -eq $sid }).Count -eq 1 } 'current session listed before muting'
            Wait-Until { $state = Read-Session; $null -ne $state -and $state.active_tab -ge 0 -and $state.tabs[$state.active_tab].shell_id -eq $sid } 'published session is the active saved tab'
            $baseline = Read-Session
            Palette 'mute tab'
            Press @(0x0D) 'Enter: mute the current tab'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and $state.active_tab -eq $baseline.active_tab -and
                    $state.tabs[$state.active_tab].shell_id -eq $sid -and
                    $state.tabs[$state.active_tab].PSObject.Properties['muted'] -and $state.tabs[$state.active_tab].muted -eq $true
            } 'active tab saved as muted'
            Wait-Until { $state = Read-Inbox; $null -ne $state -and @($state.shells | Where-Object { $_.sid -eq $sid }).Count -eq 0 } 'muted session absent from published Inbox'
            Press @(0x11, 0x10, 0x49) 'Ctrl+Shift+I: open Inbox with the session muted'
            Wait-Until { [VerifyNative]::Title($script:window).StartsWith('Inbox - ') } 'muted Inbox window state'
            Press @(0x12, 0x49) 'Alt+I: select All split with the session muted'
            Snapshot 'muted'
            $result.checks += @{ name = 'inbox-muted-hidden'; sid = $sid; listed = $false; title = [VerifyNative]::Title($script:window) }
            Press @(0x1B) 'Esc: return from Inbox with the session muted'
            Wait-Until { -not [VerifyNative]::Title($script:window).StartsWith('Inbox - ') } 'muted Inbox closed'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and @($state.tabs).Count -eq @($baseline.tabs).Count -and
                    @($state.tabs | Where-Object { $_.shell_id -eq $sid }).Count -eq 1
            } 'muted session still exists with unchanged tab count'
            Snapshot 'muted-returned'
            Palette 'unmute tab'
            Press @(0x0D) 'Enter: unmute the current tab'
            Wait-Until { $state = Read-Inbox; $null -ne $state -and @($state.shells | Where-Object { $_.sid -eq $sid }).Count -eq 1 } 'unmuted session listed in published Inbox'
            $result.checks += @{ name = 'inbox-unmuted-listed'; sid = $sid; listed = $true }
        