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
            function Rename-WaitSaved([string]$Name) {
                Wait-Until { $state = Read-Session; $null -ne $state -and $state.tabs[$state.active_tab].name -ceq $Name } "saved session name $Name"
                Wait-Until { $inbox = Read-Inbox; $null -ne $inbox -and @($inbox.shells | Where-Object { $_.sid -eq $sid -and $_.name -ceq $Name }).Count -eq 1 } "published Inbox name $Name"
            }
            Press @(0x11, 0x41) 'Ctrl+A: select the previous focus-test draft'
            Press @(0x08) 'Backspace: clear the previous draft'
            $sid = (Read-Session).tabs[(Read-Session).active_tab].shell_id
            $current = (Read-Session).tabs[(Read-Session).active_tab].name
            Rename-WaitChatView
            $scale = [VerifyNative]::GetDpiForWindow($script:window) / 96.0
            Doctor
            Record 'Click the first sidebar session name in the isolated single-session workspace'
            [VerifyNative]::ClickClient($script:window, [int](100 * $scale), [int](120 * $scale))
            $sidePoint = Rename-EditPoint $current
            Press @(0x1B) 'Esc: cancel sidebar geometry probe'
            Rename-WaitChatView
            foreach ($theme in @('light', 'amoled')) {
                Select-Theme $theme "rename-$theme-theme"
                Press @(0x71) 'F2: locate the live title editor'
                $titlePoint = Rename-EditPoint $current
                Press @(0x1B) 'Esc: cancel title geometry probe'
                Rename-Snapshot "rename-$theme-title-before"
                Doctor
                [VerifyNative]::ClickClient($script:window, $titlePoint[0], $titlePoint[1])
                [void](Rename-EditPoint $current)
                Rename-Snapshot "rename-$theme-title-edit"
                $current = "Title $theme"
                Type-Text $current
                Press @(0x0D) 'Enter: save title rename'
                Rename-WaitSaved $current
                Rename-Snapshot "rename-$theme-title-after"
                Rename-Snapshot "rename-$theme-sidebar-before"
                Doctor
                [VerifyNative]::ClickClient($script:window, $sidePoint[0], $sidePoint[1])
                [void](Rename-EditPoint $current)
                Rename-Snapshot "rename-$theme-sidebar-edit"
                $current = "Side $theme"
                Type-Text $current
                Press @(0x0D) 'Enter: save sidebar rename'
                Rename-WaitSaved $current
                Rename-Snapshot "rename-$theme-sidebar-after"
            }
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
            [VerifyNative]::ClickClient($script:window, $sidePoint[0] - 50, $sidePoint[1])
            $current = 'Palette name'
            Rename-WaitSaved $current
            Press @(0x12, 0x51) 'Alt+Q: focus composer'
            Type-Text '/rename Command name'
            Press @(0x0D) 'Enter: consume local rename command'
            $current = 'Command name'
            Rename-WaitSaved $current
            Restart-ChatView 1
            Rename-WaitSaved $current
            Rename-Snapshot 'rename-restarted'
            $result.checks += @{ name = 'inline-rename'; themes = @('light', 'amoled'); title = $true; sidebar = $true; cancel = $true; blur = $true; palette = $true; slash = $true; restart = $true; graphite2 = 'unavailable in shipped themes'; remoteAgent = 'not exercised in offline CMD session' }
