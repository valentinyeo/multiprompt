            function Rename-WaitChatView {
                Wait-Until {
                    $state = Read-Session
                    if ($null -eq $state -or $state.tabs[$state.active_tab].shell_id -ne $sid -or -not $state.tabs[$state.active_tab].cv -or [VerifyNative]::GetForegroundWindow() -ne $script:window) { return $false }
                    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                    $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
                    $transcript = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
                    if ($null -eq $transcript -or $transcript.Current.ProcessId -ne $process.Id -or $transcript.Current.IsOffscreen -or $transcript.Current.NativeWindowHandle -eq 0) { return $false }
                    [VerifyNative]::GetAncestor([IntPtr]$transcript.Current.NativeWindowHandle, 2) -eq $script:window
                } 'saved Chat View and visible owned native transcript'
            }
            function Rename-Snapshot([string]$Name) {
                Rename-WaitChatView
                Snapshot $Name
            }
            function Rename-EditPoint([string]$Expected) {
                Wait-Until {
                    $h = [VerifyNative]::GetFocusedWindow($script:window)
                    $h -ne [IntPtr]::Zero -and [VerifyNative]::Class($h) -ceq 'Edit' -and
                        [VerifyNative]::GetAncestor($h, 2) -eq $script:window -and [VerifyNative]::EditText($h) -ceq $Expected
                } 'focused owned rename Edit with the current name'
                $h = [VerifyNative]::GetFocusedWindow($script:window)
                $rect = New-Object VerifyNative+Rect
                $origin = New-Object VerifyNative+Point
                if (-not [VerifyNative]::GetWindowRect($h, [ref]$rect) -or -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'Rename Edit geometry unavailable' }
                return @([int](($rect.Left + $rect.Right) / 2 - $origin.X), [int](($rect.Top + $rect.Bottom) / 2 - $origin.Y))
            }
            function Rename-ClickNoEdit([int]$X, [int]$Y, [string]$Label) {
                Record "Click $Label once and twice: no rename editor"
                [VerifyNative]::ClickClient($script:window, $X, $Y)
                Start-Sleep -Milliseconds 120
                [VerifyNative]::ClickClient($script:window, $X, $Y)
                Start-Sleep -Milliseconds 600
                $h = [VerifyNative]::GetFocusedWindow($script:window)
                if ($h -ne [IntPtr]::Zero -and [VerifyNative]::Class($h) -ceq 'Edit' -and [VerifyNative]::EditText($h) -ceq $current) { throw "Clicking $Label opened the rename editor" }
            }
            function Rename-WaitSaved([string]$Name) {
                Wait-Until { $state = Read-Session; $null -ne $state -and $state.tabs[$state.active_tab].name -ceq $Name } "saved session name $Name"
                Wait-Until { $inbox = Read-Inbox; $null -ne $inbox -and @($inbox.shells | Where-Object { $_.sid -eq $sid -and $_.name -ceq $Name }).Count -eq 1 } "published Inbox name $Name"
            }
            function Rename-Sidebar([bool]$Hidden) {
                Palette $(if ($Hidden) { 'hide sidebar' } else { 'show sidebar' })
                Press @(0x0D) 'Enter: change sidebar visibility'
                Wait-Until { $state = Read-Session; $null -ne $state -and [bool]($state.PSObject.Properties['hide_sidebar'] -and $state.hide_sidebar) -eq $Hidden -and ($Hidden -or -not ($state.PSObject.Properties['sidebar_collapsed'] -and $state.sidebar_collapsed)) } 'published sidebar visibility'
                Rename-WaitChatView
            }
            Press @(0x11, 0x41) 'Ctrl+A: select the previous focus-test draft'
            Press @(0x08) 'Backspace: clear the previous draft'
            $sid = (Read-Session).tabs[(Read-Session).active_tab].shell_id
            $current = (Read-Session).tabs[(Read-Session).active_tab].name
            Rename-WaitChatView
            $scale = [VerifyNative]::GetDpiForWindow($script:window) / 96.0
            Doctor
            Rename-ClickNoEdit ([int](100 * $scale)) ([int](120 * $scale)) 'the first sidebar session name'
            Press @(0x71) 'F2: locate the sidebar editor'
            $sidePoint = Rename-EditPoint $current
            Press @(0x1B) 'Esc: cancel sidebar geometry probe'
            Rename-WaitChatView
            foreach ($theme in @('light', 'amoled')) {
                Select-Theme $theme "rename-$theme-theme"
                Rename-Sidebar $true
                Press @(0x71) 'F2: locate the live title editor with sidebar hidden'
                $titlePoint = Rename-EditPoint $current
                Press @(0x1B) 'Esc: cancel title geometry probe'
                Rename-Snapshot "rename-$theme-title-before"
                Doctor
                Rename-ClickNoEdit $titlePoint[0] $titlePoint[1] 'the chat title'
                Press @(0x71) 'F2: edit title with sidebar hidden'
                [void](Rename-EditPoint $current)
                Rename-Snapshot "rename-$theme-title-edit"
                $current = "Title $theme"
                Type-Text $current
                Press @(0x0D) 'Enter: save title rename'
                Rename-WaitSaved $current
                Rename-Snapshot "rename-$theme-title-after"
                Rename-Sidebar $false
                Rename-Snapshot "rename-$theme-sidebar-before"
                Press @(0x71) 'F2: edit sidebar name with sidebar open'
                $f2SidePoint = Rename-EditPoint $current
                if ([Math]::Abs($f2SidePoint[0] - $sidePoint[0]) -gt 10 -or [Math]::Abs($f2SidePoint[1] - $sidePoint[1]) -gt 10) { throw 'F2 did not open the sidebar editor' }
                Press @(0x1B) 'Esc: cancel sidebar F2 probe'
                Doctor
                Rename-ClickNoEdit $sidePoint[0] $sidePoint[1] 'the sidebar session name'
                Press @(0x71) 'F2: edit sidebar name'
                [void](Rename-EditPoint $current)
                Rename-Snapshot "rename-$theme-sidebar-edit"
                $current = "Side $theme"
                Type-Text $current
                Press @(0x0D) 'Enter: save sidebar rename'
                Rename-WaitSaved $current
                Rename-Snapshot "rename-$theme-sidebar-after"
            }
            Rename-Sidebar $true
            Press @(0x71) 'F2: edit the active name'
            [void](Rename-EditPoint $current)
            Press @(0x08) 'Backspace: clear selected title name'
            Press @(0x0D) 'Enter: retain name after empty title'
            Press @(0x71) 'F2: verify empty title retained the name'
            [void](Rename-EditPoint $current)
            Press @(0x1B) 'Esc: close verification editor'
            Rename-WaitSaved $current
            Rename-Sidebar $false
            Doctor
            Press @(0x71) 'F2: edit sidebar name for whitespace check'
            [void](Rename-EditPoint $current)
            Type-Text '   '
            Press @(0x0D) 'Enter: retain name after whitespace sidebar name'
            Press @(0x71) 'F2: verify whitespace retained the name'
            [void](Rename-EditPoint $current)
            Press @(0x1B) 'Esc: close verification editor'
            Rename-WaitSaved $current
            Press @(0x71) 'F2: enter padded name'
            [void](Rename-EditPoint $current)
            Type-Text '  Trimmed name  '
            Press @(0x0D) 'Enter: trim surrounding spaces'
            $current = 'Trimmed name'
            Rename-WaitSaved $current
            Press @(0x71) 'F2: verify trimmed name'
            [void](Rename-EditPoint $current)
            Press @(0x11, 0x41) 'Ctrl+A: select the trimmed name'
            Press @(0x11, 0x43) 'Ctrl+C: copy the native selection'
            Type-Text 'Editable draft'
            Press @(0x11, 0x5A) 'Ctrl+Z: undo the replacement'
            [void](Rename-EditPoint $current)
            Press @(0x11, 0x41) 'Ctrl+A: select the restored name'
            Press @(0x11, 0x56) 'Ctrl+V: paste the copied name'
            [void](Rename-EditPoint $current)
            Press @(0x1B) 'Esc: close verification editor'
            Press @(0x71) 'F2: edit the active name'
            [void](Rename-EditPoint $current)
            Type-Text 'Discard this name'
            Press @(0x1B) 'Esc: cancel rename'
            Rename-WaitSaved $current
            Palette 'rename session'
            Press @(0x0D) 'Enter: open the same inline editor'
            [void](Rename-EditPoint $current)
            Type-Text 'Palette name'
            Doctor
            Record 'Click the session avatar outside the sidebar editor to save'
            [VerifyNative]::ClickClient($script:window, [int](30 * $scale), $sidePoint[1])
            $current = 'Palette name'
            Rename-WaitSaved $current
            Press @(0x11, 0x10, 0x49) 'Ctrl+Shift+I: open Inbox'
            Wait-Until { $state = Read-Inbox; $null -ne $state -and $state.inbox_active } 'Inbox opened'
            Press @(0x71) 'F2: edit selected Inbox row'
            [void](Rename-EditPoint $current)
            Snapshot 'rename-inbox-edit'
            Type-Text 'Inbox name'
            Press @(0x0D) 'Enter: save Inbox rename'
            $current = 'Inbox name'
            Rename-WaitSaved $current
            Press @(0x1B) 'Esc: close Inbox'
            Rename-WaitChatView
            Press @(0x12, 0x51) 'Alt+Q: focus composer'
            Type-Text '/rename Command name'
            Press @(0x0D) 'Enter: consume local rename command'
            $current = 'Command name'
            Rename-WaitSaved $current
            Restart-ChatView 1
            $restored = Read-Session
            if (@($restored.tabs).Count -ne 1 -or $restored.tabs[$restored.active_tab].name -cne $current) { throw 'Restart did not retain the renamed session' }
            $sid = $restored.tabs[$restored.active_tab].shell_id
            Rename-WaitSaved $current
            Rename-Snapshot 'rename-restarted'
            $result.checks += @{ name = 'inline-rename'; themes = @('light', 'amoled'); title = $true; sidebar = $true; inbox = $true; cancel = $true; blur = $true; palette = $true; slash = $true; restart = $true; graphite2 = 'unavailable in shipped themes'; remoteAgent = 'not exercised in offline CMD session' }
