
            Press @(0x11, 0x10, 0x49) 'Ctrl+Shift+I: open Inbox'
            Wait-Until { (($state = Read-Inbox) -and $state.PSObject.Properties['inbox_active'] -and $state.inbox_active -eq $true) -or ([VerifyNative]::Title($script:window).StartsWith('Inbox - ')) } 'Inbox window state'
            Press @(0x12, 0x49) 'Alt+I: select All split'
            Snapshot 'action'
            $prior = (Read-Inbox).shells[0].att
            Press @(0x55) 'u: toggle selected Inbox session unread'
            Wait-Until { (Read-Inbox).shells[0].att -ne $prior } 'published attention state toggled'
            Snapshot 'after'
            $result.checks += @{ name = 'inbox-toggle-read'; attentionBefore = $prior; attentionAfter = (Read-Inbox).shells[0].att; title = [VerifyNative]::Title($script:window) }
            Press @(0x1B) 'Esc: return from Inbox'
            Wait-Until { (($state = Read-Inbox) -and $state.PSObject.Properties['inbox_active'] -and $state.inbox_active -eq $false) -or (-not [VerifyNative]::Title($script:window).StartsWith('Inbox - ') -and [VerifyNative]::Title($script:window) -cne 'Multi Bot') } 'Inbox closed'
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
            Wait-Until { (($state = Read-Inbox) -and $state.PSObject.Properties['inbox_active'] -and $state.inbox_active -eq $true) -or [VerifyNative]::Title($script:window).StartsWith('Inbox - ') } 'muted Inbox window state'
            Press @(0x12, 0x49) 'Alt+I: select All split with the session muted'
            Snapshot 'muted'
            $result.checks += @{ name = 'inbox-muted-hidden'; sid = $sid; listed = $false; title = [VerifyNative]::Title($script:window) }
            Press @(0x1B) 'Esc: return from Inbox with the session muted'
            Wait-Until { (($state = Read-Inbox) -and $state.PSObject.Properties['inbox_active'] -and $state.inbox_active -eq $false) -or (-not [VerifyNative]::Title($script:window).StartsWith('Inbox - ') -and [VerifyNative]::Title($script:window) -cne 'Multi Bot') } 'muted Inbox closed'
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
            $snapshotPath = Join-Path $scratch 'roaming/ZigShell/session.json.launch.json'
            Wait-Until { (Test-Path $snapshotPath) -and (Get-Content $snapshotPath -Raw | ConvertFrom-Json).sidebar_width -ge 100 } 'app publishes sidebar width'
            $sidebarLogical = [int](Get-Content $snapshotPath -Raw | ConvertFrom-Json).sidebar_width
            $session = Read-Session
            $uiScale = if ($session.PSObject.Properties['ui_scale']) { [int]$session.ui_scale } else { 100 }
            $dpi = [VerifyNative]::GetDpiForWindow($script:window)
            if ($dpi -eq 0) { throw 'Inbox button DPI unavailable' }
            $scale = $dpi * $uiScale / 9600.0
            $closedX = [int][Math]::Floor($sidebarLogical * $scale) - [int][Math]::Floor(24 * $scale) - [int][Math]::Floor(6 * $scale)
            $openX = [int][Math]::Floor(8 * $scale)
            $buttonWidth = [int][Math]::Floor(24 * $scale)
            $frame = New-Object VerifyNative+Rect
            $origin = New-Object VerifyNative+Point
            if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'Inbox button geometry unavailable' }
            $dx = $origin.X - $frame.Left
            $dy = $origin.Y - $frame.Top
            foreach ($theme in @('light', 'amoled')) {
                Select-Theme $theme ("inbox-button-$theme-theme")
                Wait-Until { $state = Read-Inbox; $null -ne $state -and $state.inbox_active -eq $false } 'Inbox closed before button check'
                [VerifyNative]::MoveMouseClient($script:window, 50, 100, $false)
                Snapshot "inbox-button-$theme-closed"
                Press @(0x11, 0x10, 0x49) 'Ctrl+Shift+I: open Inbox for button check'
                Wait-Until { $state = Read-Inbox; $null -ne $state -and $state.inbox_active -eq $true } 'Inbox opened for button check'
                [VerifyNative]::MoveMouseClient($script:window, 50, 100, $false)
                Snapshot "inbox-button-$theme-open"
                $counts = @{}
                foreach ($mode in @('closed', 'open')) {
                    $x = if ($mode -eq 'open') { $openX } else { $closedX }
                    $image = [Drawing.Bitmap]::FromFile((Join-Path $Evidence "inbox-button-$theme-$mode.png"))
                    try {
                        $bg = $image.GetPixel($dx + $x + 2, $dy + 17)
                        $different = 0
                        for ($py = 10; $py -lt 24; $py++) {
                            for ($px = $x + 3; $px -lt $x + $buttonWidth - 3; $px++) {
                                $pixel = $image.GetPixel($dx + $px, $dy + $py)
                                if ([Math]::Abs([int]$pixel.R - [int]$bg.R) -gt 35 -or [Math]::Abs([int]$pixel.G - [int]$bg.G) -gt 35 -or [Math]::Abs([int]$pixel.B - [int]$bg.B) -gt 35) { $different++ }
                            }
                        }
                        $counts[$mode] = $different
                    } finally { $image.Dispose() }
                }
                if ($counts.open -ne 0 -or $counts.closed -lt 4) { throw "Inbox button pixels failed for $theme`: open=$($counts.open), closed=$($counts.closed)" }
                [VerifyNative]::ClickClient($script:window, ($openX + [int][Math]::Floor($buttonWidth / 2)), 17)
                Wait-Until { $state = Read-Inbox; $null -ne $state -and $state.inbox_active -eq $true } 'former button does not close Inbox'
                Press @(0x1B) 'Esc: close Inbox for restored button check'
                Wait-Until { $state = Read-Inbox; $null -ne $state -and $state.inbox_active -eq $false } 'Inbox closed for restored button check'
                [VerifyNative]::ClickClient($script:window, ($closedX + [int][Math]::Floor($buttonWidth / 2)), 17)
                Wait-Until { $state = Read-Inbox; $null -ne $state -and $state.inbox_active -eq $true } 'restored button reopens Inbox'
                Press @(0x1B) 'Esc: return from Inbox button check'
                Wait-Until { $state = Read-Inbox; $null -ne $state -and $state.inbox_active -eq $false } 'Inbox returned after button check'
                [VerifyNative]::MoveMouseClient($script:window, 50, 100, $false)
                Snapshot "inbox-button-$theme-returned"
                $result.checks += @{ name = "inbox-button-$theme"; openPixels = $counts.open; closedPixels = $counts.closed; sidebarWidth = $sidebarLogical; dpi = $dpi; uiScale = $uiScale; reopened = $true; returned = $true }
            }
            $result.checks += @{ name = 'inbox-button-unavailable-theme'; theme = 'Graphite 2'; reason = 'not shipped' }
        