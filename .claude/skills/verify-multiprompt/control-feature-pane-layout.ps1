            $snapshotPath = Join-Path $scratch 'roaming/ZigShell/session.json.launch.json'
            Wait-Until { (Test-Path $snapshotPath) -and (Get-Content $snapshotPath -Raw | ConvertFrom-Json).sidebar_width -ge 100 } 'app publishes its actual sidebar width'
            $sidebarLogical = [int](Get-Content $snapshotPath -Raw | ConvertFrom-Json).sidebar_width

            Select-Theme 'dark' 'pane-layout-dark'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 1 -and $state.tabs[0].kind -eq 'cmd' } 'one real CMD session'
            $initial = Read-Session
            if ($initial.tabs[0].PSObject.Properties['cv'] -and $initial.tabs[0].cv) { throw 'pane-layout requires the console, not Chat View' }
            $script:browserShellId = (Read-Inbox).shells[0].sid
            Focus-Palette 'move to group' 6301
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text 'new group'
            Press @(0x0D) 'Enter: New group containing CMD'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and $state.PSObject.Properties['groups'] -and @($state.groups).Count -eq 1 -and $state.tabs[0].group_id -eq $state.groups[0].id
            } 'CMD membership in the user-created gray group'
            Press @(0x1B) 'Esc: leave inline group rename using the saved default name'
            Palette 'new cmd'
            Press @(0x0D) 'Enter: create ungrouped foreground console'
            Wait-Until {
                $state = Read-Session
                @($state.tabs).Count -eq 2 -and $state.active_tab -eq 1 -and $state.tabs[1].kind -eq 'cmd' -and
                    (-not $state.tabs[1].PSObject.Properties['group_id'] -or $state.tabs[1].group_id -eq 0)
            } 'second CMD selected while grouped member stays fully visible'
            $consoleTab = (Read-Session).active_tab
            $consoleShellId = (Read-Session).tabs[$consoleTab].shell_id
            $script:browserShellId = $consoleShellId
            $pane = Open-BrowserPane 'pane-layout-open'
            Press @(0x5B, 0x26) 'Win+Up: maximize main window'
            Wait-Until { [VerifyNative]::IsZoomed($script:window) } 'maximized main window'
            Press @(0x11, 0x32) 'Ctrl+2: return to the ungrouped CMD console'
            Wait-WorkspaceSurface $initial.active_workspace $consoleTab $false
            $console = [VerifyNative]::GetForegroundWindow()
            $browser = [VerifyNative]::PaneWindow($script:window)
            if ($browser -eq [IntPtr]::Zero) { throw 'No visible owned docked browser HWND' }
            $consoleElement = [System.Windows.Automation.AutomationElement]::FromHandle($console)
            if ($consoleElement.Current.IsOffscreen -or $consoleElement.Current.ClassName -ne 'ConsoleWindowClass' -or
                -not [VerifyNative]::Title($console).EndsWith(('ZigShell-' + $consoleShellId), [StringComparison]::Ordinal)) { throw 'UIA cannot see the owned CMD console' }
            Snapshot 'action'
            Snapshot 'pane-layout'
            $frame = New-Object VerifyNative+Rect
            $client = New-Object VerifyNative+Rect
            $consoleRect = New-Object VerifyNative+Rect
            $browserRect = New-Object VerifyNative+Rect
            $origin = New-Object VerifyNative+Point
            if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::GetClientRect($script:window, [ref]$client) -or
                -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin) -or -not [VerifyNative]::GetWindowRect($console, [ref]$consoleRect) -or
                -not [VerifyNative]::GetWindowRect($browser, [ref]$browserRect)) { throw 'pane-layout HWND rectangles unavailable' }
            $client.Left += $origin.X; $client.Right += $origin.X; $client.Top += $origin.Y; $client.Bottom += $origin.Y
            $uiaRect = $consoleElement.Current.BoundingRectangle
            if ([Math]::Abs($uiaRect.Left - $consoleRect.Left) -gt 1 -or [Math]::Abs($uiaRect.Top - $consoleRect.Top) -gt 1 -or
                [Math]::Abs($uiaRect.Right - $consoleRect.Right) -gt 1 -or [Math]::Abs($uiaRect.Bottom - $consoleRect.Bottom) -gt 1) { throw 'Console UIA and HWND bounds disagree' }
            Write-Host 'pane-layout console-uia-hwnd PASS'
            $state = Read-Session
            if ($state.tabs[$consoleTab].PSObject.Properties['cv'] -and $state.tabs[$consoleTab].cv) { throw 'Journey accidentally entered Chat View' }
            $scale = 100
            if ($state.PSObject.Properties['ui_scale']) { $scale = [int]$state.ui_scale }
            $dpi = [VerifyNative]::GetDpiForWindow($script:window)
            Save-Json @{ frame = $frame; client = $client; console = $consoleRect; browser = $browserRect; consoleHwnd = $console.ToInt64(); browserHwnd = $browser.ToInt64(); dpi = $dpi; scale = $scale; session = $state } 'pane-layout-rects.json'
            $hidePills = $state.PSObject.Properties['hide_pills'] -and $state.hide_pills
            $focusProofs = @()
            [uint32]$browserPid = 0
            [void][VerifyNative]::GetWindowThreadProcessId($browser, [ref]$browserPid)
            Record 'Ctrl+L: load a local keyboard probe through the owned browser address bar'
            [VerifyNative]::FocusOwnedWindow($browser, $browserPid, $script:window)
            if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw 'Browser lost focus before Ctrl+L' }
            Assert-Foreground
            [VerifyNative]::Chord(@(0x11, 0x4C))
            $browserRoot = [System.Windows.Automation.AutomationElement]::FromHandle($browser)
            $omniboxCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'OmniboxViewViews')
            Wait-Until {
                $omnibox = $browserRoot.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $omniboxCondition)
                $null -ne $omnibox -and $omnibox.Current.HasKeyboardFocus -and
                    [System.Windows.Automation.Automation]::Compare($omnibox, [System.Windows.Automation.AutomationElement]::FocusedElement) -and
                    [VerifyNative]::GetForegroundWindow() -eq $browser
            } 'verified pane native address bar has keyboard focus'
            $probeHtml = '<title>IGSH807 keys 0 </title><script>let n=0;addEventListener("keydown",e=>{if(e.key==="j"){e.preventDefault();document.title="IGSH807 keys "+(++n)+" "}})</script>'
            Assert-Foreground
            [VerifyNative]::Text(('data:text/html,' + [Uri]::EscapeDataString($probeHtml)))
            Assert-Foreground
            [VerifyNative]::Chord(@(0x0D))
            Wait-Until { [VerifyNative]::Title($browser).StartsWith('IGSH807 keys 0 ', [StringComparison]::Ordinal) } 'local keyboard probe loaded'
            foreach ($theme in @('dark', 'multiprompt', 'light', 'amoled', 'mid', 'edgegray', 'system')) {
                $query = if ($theme -eq 'edgegray') { 'edge grey' } else { $theme }
                Select-Theme $query ("focus-$theme-theme") $theme
                Press @(0x11, 0x32) 'Ctrl+2: start focus journey on the owned console'
                Wait-WorkspaceSurface $initial.active_workspace $consoleTab $false
                foreach ($view in @('shell', 'chat')) {
                    if ($view -eq 'chat') {
                        $chatFocused = $false
                        for ($attempt = 1; $attempt -le 3 -and -not $chatFocused; $attempt++) {
                            $chatState = Read-Session
                            $inChat = $chatState.tabs[$consoleTab].PSObject.Properties['cv'] -and $chatState.tabs[$consoleTab].cv
                            if (-not $inChat) { Press @(0x12, 0x43) 'Alt+C: enter Chat View without changing Alt+Q behavior' }
                            try { Wait-ChatFocus 'Edit' ("focus-$theme-chat-start"); $chatFocused = $true }
                            catch { Record ('Chat View composer attempt ' + $attempt + ' for ' + $theme + ' returned: ' + $_) }
                        }
                        if (-not $chatFocused) { throw ('Chat View composer never took focus in theme ' + $theme) }
                    }
                    foreach ($cycle in @(1, 2)) {
                        $step = "focus-$theme-$view-$cycle"
                        if ($view -eq 'chat') {
                            Assert-ChatTyping "draft-$theme-$cycle" ($step + '-input')
                            $composer = [IntPtr][System.Windows.Automation.AutomationElement]::FocusedElement.Current.NativeWindowHandle
                            $draft = [VerifyNative]::EditText($composer)
                        } else {
                            $marker = Join-Path $scratch ($step + '.txt')
                            if (Test-Path $marker) { throw 'Focus marker already exists before shell input' }
                            $command = 'echo ' + $step + '>"' + $marker + '"'
                            Type-Text $command
                            Wait-ConsoleText $command
                            Doctor
                            Record 'Enter: execute focus marker in the Alt+Q-selected shell'
                            Assert-Foreground
                            [VerifyNative]::Chord(@(0x0D))
                            Wait-Until { (Test-Path $marker) -and (Get-Content $marker -Raw).Trim() -ceq $step } 'shell focus marker content'
                        }
                        Snapshot ($step + '-input')
                        Doctor
                        Record 'Alt+Q: switch from input to browser without foreground repair'
                        Assert-Foreground
                        [VerifyNative]::Chord(@(0x12, 0x51))
                        Wait-Until { [VerifyNative]::GetForegroundWindow() -eq $browser -and [VerifyNative]::GetProp($browser, 'ZigShellPaneOwner') -eq $script:window } 'Alt+Q selected the owned browser'
                        Doctor
                        if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw 'Refusing browser probe outside the Alt+Q-selected pane' }
                        $probeTitle = [VerifyNative]::Title($browser)
                        if ($probeTitle -notmatch '^IGSH807 keys (\d+) ') { throw ('Browser probe page is not loaded: ' + $probeTitle) }
                        [int]$pageKeys = [int]$Matches[1] + 1
                        Record 'j: prove keyboard input reaches browser content'
                        Assert-Foreground
                        [VerifyNative]::Chord(@(0x4A))
                        Wait-Until { [VerifyNative]::Title($browser).StartsWith(('IGSH807 keys ' + $pageKeys + ' '), [StringComparison]::Ordinal) } 'browser page received the exact next key'
                        if ($view -eq 'chat' -and [VerifyNative]::EditText($composer) -cne $draft) { throw 'Browser input changed the chat draft' }
                        Snapshot ($step + '-browser')
                        Doctor
                        Record 'Alt+Q: return to input without foreground repair'
                        Assert-Foreground
                        [VerifyNative]::Chord(@(0x12, 0x51))
                        if ($view -eq 'chat') {
                            Wait-ChatFocus 'Edit' ($step + '-returned')
                            if ([VerifyNative]::EditText($composer) -cne $draft) { throw 'Alt+Q lost the chat draft' }
                            Type-Text '-returned'
                            Wait-Until { [VerifyNative]::EditText($composer) -ceq ($draft + '-returned') } 'typing reaches the returned composer'
                        } else {
                            Wait-WorkspaceSurface $initial.active_workspace $consoleTab $false
                            $returnMarker = Join-Path $scratch ($step + '-returned.txt')
                            if (Test-Path $returnMarker) { throw 'Return marker already exists' }
                            $command = 'echo returned>"' + $returnMarker + '"'
                            Type-Text $command
                            Wait-ConsoleText $command
                            Doctor
                            Record 'Enter: execute in returned shell without focus repair'
                            Assert-Foreground
                            [VerifyNative]::Chord(@(0x0D))
                            Wait-Until { (Test-Path $returnMarker) -and (Get-Content $returnMarker -Raw).Trim() -ceq 'returned' } 'returned shell received input'
                        }
                        Snapshot ($step + '-returned')
                        $pixels = [PaneLayoutProof]::FocusMargins((Join-Path $Evidence ($step + '-input.png')), (Join-Path $Evidence ($step + '-browser.png')), $frame, $client, $consoleRect, $browserRect, $dpi, $scale, $sidebarLogical)
                        Save-Json $pixels ($step + '-pixels.json')
                        $focusProofs += @{ theme = $theme; view = $view; cycle = $cycle; pageKeys = $pageKeys; pixels = $pixels }
                        if ($view -eq 'chat') {
                            Doctor
                            Record 'Clear the unsent draft in the still-focused composer'
                            $cleared = $false
                            for ($attempt = 1; $attempt -le 4 -and -not $cleared; $attempt++) {
                                Assert-Foreground
                                [VerifyNative]::Chord(@(0x11, 0x41))
                                Assert-Foreground
                                [VerifyNative]::Chord(@(0x2E))
                                Assert-Foreground
                                [VerifyNative]::Chord(@(0x08))
                                try { Wait-Until { [VerifyNative]::EditText($composer) -ceq '' } 'empty composer for next cycle' 4; $cleared = $true } catch { Record ('Composer clear attempt ' + $attempt + ' left: ' + [VerifyNative]::EditText($composer)) }
                            }
                            if (-not $cleared) { throw ('Composer not empty before next cycle: ' + [VerifyNative]::EditText($composer)) }
                        }
                    }
                }
                $restored = $false
                for ($attempt = 1; $attempt -le 3 -and -not $restored; $attempt++) {
                    $restoreState = Read-Session
                    $stillChat = $restoreState.tabs[$consoleTab].PSObject.Properties['cv'] -and $restoreState.tabs[$consoleTab].cv
                    if ($stillChat) { Press @(0x12, 0x43) 'Alt+C: restore shell view for the next theme' }
                    try { Wait-WorkspaceSurface $initial.active_workspace $consoleTab $false; $restored = $true }
                    catch { Record ('Shell view restore attempt ' + $attempt + ' returned: ' + $_) }
                }
                if (-not $restored) { throw 'Shell view never returned after Chat View' }
            }
            Save-Json $focusProofs 'focus-ring-proof.json'
            $result.checks += @{ name = 'IGSH-807 focus-input'; proofs = $focusProofs }
            if (@($focusProofs | Where-Object { $_.pixels.mismatches -ne 0 }).Count -ne 0) { throw 'IGSH-807 focus ring pixels differ from the unfocused surface' }
            Select-Theme 'dark' 'pane-layout-final-dark'
            Press @(0x11, 0x32) 'Ctrl+2: restore console for layout evidence'
            Wait-WorkspaceSurface $initial.active_workspace $consoleTab $false
            if ([VerifyNative]::GetForegroundWindow() -ne $console -or [VerifyNative]::PaneWindow($script:window) -ne $browser -or
                [VerifyNative]::GetProp($browser, 'ZigShellPaneOwner') -ne $script:window -or -not [VerifyNative]::IsZoomed($script:window)) { throw 'pane-layout lost original maximized console/browser HWNDs' }
            $frame = New-Object VerifyNative+Rect
            $client = New-Object VerifyNative+Rect
            $consoleRect = New-Object VerifyNative+Rect
            $browserRect = New-Object VerifyNative+Rect
            $origin = New-Object VerifyNative+Point
            if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::GetClientRect($script:window, [ref]$client) -or
                -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin) -or -not [VerifyNative]::GetWindowRect($console, [ref]$consoleRect) -or
                -not [VerifyNative]::GetWindowRect($browser, [ref]$browserRect)) { throw 'pane-layout fresh HWND rectangles unavailable' }
            $client.Left += $origin.X; $client.Right += $origin.X; $client.Top += $origin.Y; $client.Bottom += $origin.Y
            $state = Read-Session
            if ($state.tabs[$consoleTab].shell_id -ne $consoleShellId -or ($state.tabs[$consoleTab].PSObject.Properties['cv'] -and $state.tabs[$consoleTab].cv)) { throw 'pane-layout original shell view changed' }
            $scale = 100
            if ($state.PSObject.Properties['ui_scale']) { $scale = [int]$state.ui_scale }
            $dpi = [VerifyNative]::GetDpiForWindow($script:window)
            $hidePills = $state.PSObject.Properties['hide_pills'] -and $state.hide_pills
            $consoleElement = [System.Windows.Automation.AutomationElement]::FromHandle($console)
            $uiaRect = $consoleElement.Current.BoundingRectangle
            if ($consoleElement.Current.IsOffscreen -or $consoleElement.Current.ClassName -ne 'ConsoleWindowClass' -or
                -not [VerifyNative]::Title($console).EndsWith(('ZigShell-' + $consoleShellId), [StringComparison]::Ordinal) -or
                [Math]::Abs($uiaRect.Left - $consoleRect.Left) -gt 1 -or [Math]::Abs($uiaRect.Top - $consoleRect.Top) -gt 1 -or
                [Math]::Abs($uiaRect.Right - $consoleRect.Right) -gt 1 -or [Math]::Abs($uiaRect.Bottom - $consoleRect.Bottom) -gt 1) { throw 'Fresh console UIA and HWND identity/bounds disagree' }
            Save-Json @{ frame = $frame; client = $client; console = $consoleRect; browser = $browserRect; consoleHwnd = $console.ToInt64(); browserHwnd = $browser.ToInt64(); dpi = $dpi; scale = $scale; session = $state } 'pane-layout-rects.json'
            Snapshot 'pane-layout'
            $proof = [PaneLayoutProof]::Check((Join-Path $Evidence 'pane-layout.png'), $frame, $client, $consoleRect, $browserRect, $dpi, $scale, $hidePills, $sidebarLogical)
            Save-Json $proof 'pane-layout-pixels.json'
            $maskColors = [ordered]@{ themes = [ordered]@{}; dpi = $dpi; scale = $scale }
            foreach ($theme in @('dark', 'light', 'amoled')) {
                Select-Theme $theme ("pane-layout-mask-$theme-action")
                Wait-Until { [PaneLayoutProof]::Masks([uint32]$process.Id).Count -eq 10 } ("ten visible owned browser masks for $theme") 10
                Write-Host "pane-layout mask-windows-$theme PASS"
                $paintReady = [DateTime]::UtcNow.AddMilliseconds(1000)
                Wait-Until { [DateTime]::UtcNow -ge $paintReady } ("theme repaint settled for $theme") 3
                Press @(0x11, 0x32) 'Ctrl+2: restore original console before mask geometry'
                Wait-WorkspaceSurface $initial.active_workspace $consoleTab $false
                if ([VerifyNative]::GetForegroundWindow() -ne $console -or [VerifyNative]::PaneWindow($script:window) -ne $browser -or
                    [VerifyNative]::GetProp($browser, 'ZigShellPaneOwner') -ne $script:window -or -not [VerifyNative]::IsZoomed($script:window)) { throw 'pane-layout lost original maximized console/browser HWNDs' }
                $frame = New-Object VerifyNative+Rect
                $client = New-Object VerifyNative+Rect
                $consoleRect = New-Object VerifyNative+Rect
                $browserRect = New-Object VerifyNative+Rect
                $origin = New-Object VerifyNative+Point
                if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::GetClientRect($script:window, [ref]$client) -or
                    -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin) -or -not [VerifyNative]::GetWindowRect($console, [ref]$consoleRect) -or
                    -not [VerifyNative]::GetWindowRect($browser, [ref]$browserRect)) { throw 'pane-layout fresh HWND rectangles unavailable' }
                $client.Left += $origin.X; $client.Right += $origin.X; $client.Top += $origin.Y; $client.Bottom += $origin.Y
                $state = Read-Session
                if ($state.tabs[$consoleTab].shell_id -ne $consoleShellId -or ($state.tabs[$consoleTab].PSObject.Properties['cv'] -and $state.tabs[$consoleTab].cv)) { throw 'pane-layout original shell view changed' }
                $scale = 100
                if ($state.PSObject.Properties['ui_scale']) { $scale = [int]$state.ui_scale }
                $dpi = [VerifyNative]::GetDpiForWindow($script:window)
                $hidePills = $state.PSObject.Properties['hide_pills'] -and $state.hide_pills
                $masks = [PaneLayoutProof]::Masks([uint32]$process.Id)
                $maskColors.themes[$theme] = @{ masks = $masks; screenshot = "pane-layout-mask-$theme.png"; frame = $frame; client = $client; console = $consoleRect; browser = $browserRect; dpi = $dpi; scale = $scale; hidePills = $hidePills; consoleHwnd = $console.ToInt64(); browserHwnd = $browser.ToInt64() }
                Save-Json $maskColors 'pane-layout-mask-colours.json'
                if ($masks.Count -ne 10) { throw "pane-layout mask-windows-$theme FAIL: masks disappeared before capture" }
                Snapshot ("pane-layout-mask-$theme")
                if ([PaneLayoutProof]::Masks([uint32]$process.Id).Count -ne 10) { throw "pane-layout mask-windows-$theme FAIL: masks disappeared during capture" }
                $maskColors.themes[$theme].pixels = [PaneLayoutProof]::MeasureMasks((Join-Path $Evidence "pane-layout-mask-$theme.png"), $theme, $frame, $client, $browserRect, $masks, $dpi, $scale)
                Save-Json $maskColors 'pane-layout-mask-colours.json'
            }
            foreach ($theme in @('dark', 'light', 'amoled')) {
                [PaneLayoutProof]::CheckMasks($maskColors.themes[$theme].pixels, $theme)
            }
            $result.checks += @{ name = 'pane-layout'; assertions = @('console-uia-hwnd', 'clean-gap', 'group-line-absent', 'row-icon-found', 'group-content-inset', 'mask-windows-dark', 'mask-top-right-dark', 'mask-reference-dark', 'mask-not-black-dark', 'mask-chrome-dark', 'mask-follows-chrome-dark', 'mask-windows-light', 'mask-top-right-light', 'mask-reference-light', 'mask-not-black-light', 'mask-chrome-light', 'mask-windows-amoled', 'mask-top-right-amoled', 'mask-reference-amoled', 'mask-not-black-amoled', 'mask-chrome-amoled', 'mask-follows-chrome-amoled'); pixels = $proof; maskColours = $maskColors }
            Snapshot 'after'
        