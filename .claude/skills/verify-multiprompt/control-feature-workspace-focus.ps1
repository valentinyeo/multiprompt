
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and @($state.tabs).Count -gt 0 -and $state.tabs[$state.active_tab].kind -eq 'cmd'
            } 'initial CMD session saved' 60
            $initial = Read-Session
            if ($initial.active_workspace -ne 0 -or $initial.workspace_count -ne 1) { throw 'Expected one initial stored workspace' }
            $initialTab = $initial.active_tab
            Wait-WorkspaceSurface 0 $initialTab $false
            if ($initial.hide_pills) {
                Focus-Palette 'workspace switcher' 6213
                Press @(0x0D) 'Enter: show workspace switcher'
            }
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and $state.PSObject.Properties['hide_pills'] -and -not $state.hide_pills -and -not ($state.PSObject.Properties['hide_sidebar'] -and $state.hide_sidebar) -and -not ($state.PSObject.Properties['sidebar_collapsed'] -and $state.sidebar_collapsed)
            } 'workspace switcher shown and saved'
            Wait-WorkspaceSurface 0 $initialTab $false
            Snapshot 'pills-ready'
            Focus-Palette 'chat view off everywhere' 6347
            Press @(0x0D) 'Enter: reset Chat View to shell for the test session'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and -not $state.PSObject.Properties['chat_view_mode'] -and -not $state.tabs[$initialTab].PSObject.Properties['chat_view_lock'] -and
                    -not ($state.tabs[$initialTab].PSObject.Properties['cv'] -and $state.tabs[$initialTab].cv)
            } 'shell baseline without removed Chat View state saved'
            Wait-WorkspaceSurface 0 $initialTab $false
            $tab = (Read-Session).tabs[$initialTab]
            if (-not ($tab.PSObject.Properties.Name -contains 'cv' -and $tab.cv)) {
                Press @(0x12, 0x43) 'Alt+C: enable Chat View for the test session'
            }
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and $state.tabs[$initialTab].PSObject.Properties['cv'] -and $state.tabs[$initialTab].cv
            } 'test session Chat View enabled'
            $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
            $editCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
            Wait-Until {
                $candidate = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $editCondition)
                $null -ne $candidate -and $candidate.Current.ProcessId -eq $process.Id -and -not $candidate.Current.IsOffscreen -and $candidate.Current.NativeWindowHandle -ne 0
            } 'owned Chat View typing box visible' 30
            $composer = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $editCondition)
            $composerHandle = $composer.Current.NativeWindowHandle
            if ([VerifyNative]::GetAncestor([IntPtr]$composerHandle, 2) -ne $script:window) { throw 'Chat View typing box is not in the owned window' }
            Record 'Setup: foreground owned Chat View before focus regression'
            [void][VerifyNative]::ShowWindow($script:window, 9)
            [void][VerifyNative]::SetForegroundWindow($script:window)
            Wait-Until { [VerifyNative]::GetForegroundWindow() -eq $script:window } 'foreground Chat View frame'
            Wait-Until {
                $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
                $focused.Current.ProcessId -eq $process.Id -and $focused.Current.NativeWindowHandle -eq $composerHandle
            } 'owned Chat View typing box focused'
            Type-Text 'before-'
            Wait-Until {
                [VerifyNative]::EditText([IntPtr]$composerHandle) -ceq 'before-'
            } 'initial text landed in Chat View typing box'
            Snapshot 'action'
            Press @(0x11, 0x4E) 'Ctrl+N: create second workspace'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and $state.workspace_count -eq $initial.workspace_count + 1 -and $state.active_workspace -eq 1 -and $state.active_tab -ne $initialTab -and $state.tabs[$state.active_tab].workspace -eq 1 -and $state.tabs[$state.active_tab].kind -eq 'cmd'
            } 'second workspace and distinct CMD session saved'
            $second = (Read-Session).active_workspace
            $secondTab = (Read-Session).active_tab
            Wait-WorkspaceSurface $second $secondTab $false
            Press @(0x12, 0x32) 'Alt+2: return to first workspace'
            Wait-WorkspaceSurface 0 $initialTab $true $composerHandle
            Press @(0x12, 0x27) 'Alt+Right: leave Chat View workspace'
            Wait-WorkspaceSurface $second $secondTab $false
            Press @(0x12, 0x25) 'Alt+Left: return to Chat View workspace'
            Wait-WorkspaceSurface 0 $initialTab $true $composerHandle
            Type-Text 'workspace-focus-chat'
            $expectedText = 'before-workspace-focus-chat'
            Wait-Until {
                [VerifyNative]::EditText([IntPtr]$composerHandle) -ceq $expectedText
            } 'text landed in Chat View typing box without a click'
            $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
            if ($focused.Current.NativeWindowHandle -ne $composerHandle) { throw 'Chat View typing box did not retain keyboard focus' }
            $chatState = Read-Session
            if ($chatState.active_tab -ne $initialTab -or $chatState.workspaces[0].focus -ne 'chat') { throw 'Chat focus or selected session was not persisted' }
            $result.checks += @{ name = 'workspace-focus-chat'; text = $expectedText; composer = $composerHandle; activeTab = $chatState.active_tab; savedFocus = $chatState.workspaces[0].focus }
            Write-Output 'workspace-focus chat PASS'
            Snapshot 'chat-returned'
            Click-WorkspacePill $second
            Wait-WorkspaceSurface $second $secondTab $false
            Click-WorkspacePill 0
            Wait-WorkspaceSurface 0 $initialTab $true $composerHandle
            Type-Text '-pill'
            Wait-Until {
                [VerifyNative]::EditText([IntPtr]$composerHandle) -ceq ($expectedText + '-pill')
            } 'pill return restored Chat View input without a composer click'
            $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
            $pillState = Read-Session
            if ($focused.Current.NativeWindowHandle -ne $composerHandle -or $pillState.active_tab -ne $initialTab -or $pillState.workspaces[0].focus -ne 'chat') { throw 'Pill return lost Chat View focus or selected session' }
            $result.checks += @{ name = 'workspace-focus-chat-pill'; text = ($expectedText + '-pill'); composer = $composerHandle; activeTab = $pillState.active_tab; savedFocus = $pillState.workspaces[0].focus }
            Write-Output 'workspace-focus chat pill PASS'
            Press @(0x12, 0x43) 'Alt+C: switch to shell console'
            Wait-WorkspaceSurface 0 $initialTab $false
            $pillMarker = Join-Path $scratch 'workspace-focus-shell-pill.txt'
            if (Test-Path $pillMarker) { throw 'Pill shell marker must not exist before input' }
            Type-Text 'echo workspace-focus-shell-pill'
            Wait-ConsoleText 'echo workspace-focus-shell-pill'
            Click-WorkspacePill $second
            Wait-WorkspaceSurface $second $secondTab $false
            if ((Read-Session).workspaces[0].focus -ne 'shell') { throw 'Pill mouse-down did not capture the newly selected shell surface' }
            Click-WorkspacePill 0
            Wait-WorkspaceSurface 0 $initialTab $false
            Type-Text ('>"' + $pillMarker + '"')
            Wait-ConsoleText ('echo workspace-focus-shell-pill>"' + $pillMarker + '"')
            Press @(0x0D) 'Enter: execute in pill-restored shell without a console click'
            Wait-Until { (Test-Path $pillMarker) -and (Get-Content $pillMarker -Raw).Trim() -ceq 'workspace-focus-shell-pill' } 'pill-restored console executed typed command'
            $pillState = Read-Session
            if ($pillState.active_tab -ne $initialTab -or $pillState.workspaces[0].focus -ne 'shell') { throw 'Pill return lost shell focus or selected session' }
            $result.checks += @{ name = 'workspace-focus-shell-pill'; marker = (Get-Content $pillMarker -Raw).Trim(); activeTab = $pillState.active_tab; savedFocus = $pillState.workspaces[0].focus }
            Write-Output 'workspace-focus shell pill PASS'
            Wait-WorkspaceSurface 0 $initialTab $false
            $marker = Join-Path $scratch 'workspace-focus-shell.txt'
            if (Test-Path $marker) { throw 'Shell focus marker must not exist before input' }
            Type-Text 'echo workspace-focus-shell'
            Wait-ConsoleText 'echo workspace-focus-shell'
            Press @(0x12, 0x27) 'Alt+Right: leave shell workspace'
            Wait-WorkspaceSurface $second $secondTab $false
            Press @(0x12, 0x25) 'Alt+Left: return to shell workspace'
            Wait-WorkspaceSurface 0 $initialTab $false
            Type-Text ('>"' + $marker + '"')
            Wait-ConsoleText ('echo workspace-focus-shell>"' + $marker + '"')
            Press @(0x0D) 'Enter: execute in restored shell without a click'
            Wait-Until { (Test-Path $marker) -and (Get-Content $marker -Raw).Trim() -ceq 'workspace-focus-shell' } 'restored console executed the typed command'
            $shellState = Read-Session
            if ($shellState.active_tab -ne $initialTab -or $shellState.workspaces[0].focus -ne 'shell') { throw 'Shell focus or selected session was not persisted' }
            $result.checks += @{ name = 'workspace-focus-shell'; marker = (Get-Content $marker -Raw).Trim(); activeTab = $shellState.active_tab; savedFocus = $shellState.workspaces[0].focus }
            Write-Output 'workspace-focus shell PASS'
            Snapshot 'after'
        