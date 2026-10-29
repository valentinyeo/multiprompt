
            $modes = @('browser_off', 'browser_on', 'frozen_browser_on', 'chat_browser_off', 'chat_browser_on', 'chat_frozen_browser_on')
            $timings = [ordered]@{ steps = @{} }
            $traces = @{}
            foreach ($mode in $modes) {
                $sampleCount = if ($mode.Contains('frozen_')) { 5 } else { 20 }
                $timings[$mode] = @{ samples_ms = @($null) * $sampleCount; median_ms = $null; window_visible_ms = @($null) * $sampleCount; window_visible_median_ms = $null }
                $timings.steps[$mode] = $null
                $traces[$mode] = @()
            }
            $traceLines = New-Object System.Collections.ArrayList
            $frozenSwitches = New-Object System.Collections.ArrayList
            $frozenLogStart = $null
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $colors = @('#db2855', '#26b8d4')
            $rgb = @(0xDB2855, 0x26B8D4)
            $drafts = @('Wswitch-paint-0', '.switch-paint-1')
            $consoleCodes = @('1F', '2F')
            $consoleRgb = @(-1, -1)
            $regions = @{}
            $patches = @($null, $null)
            $composerHandle = [IntPtr]::Zero
            $gapCase = @{ name = 'switch-gap'; status = 'failed'; detail = 'Switch measurement did not complete'; phase = 'initial-console' }
            $result.checks += $gapCase
            try {
                Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 1 -and $state.tabs[0].kind -eq 'cmd' } 'one initial CMD for switch timing'
                $initial = Read-Session
                Wait-WorkspaceSurface $initial.active_workspace 0 $false
                $gapCase.phase = 'idle-close-fixture'
                Focus-Palette 'browser auto suspend' 6240
                Press @(0x0D) 'Enter: disable timed browser closing while measuring fresh tier-two freezes'
                Wait-Until { $state = Read-Session; $state.PSObject.Properties['browser_suspend_min'] -and $state.browser_suspend_min -eq 0 } 'app saved idle browser closing disabled; automatic freezing remains enabled'
                Save-Json (Read-Session) 'switch-idle-close-fixture.json'
                $gapCase.phase = 'group-setup'
                Focus-Palette 'move to group' 6301
                Press @(0x0D) 'Enter: Move to Group submenu'
                Type-Text 'new group'
                Press @(0x0D) 'Enter: New group containing timing CMD'
                Wait-Until {
                    $state = Read-Session
                    $null -ne $state -and $state.PSObject.Properties['groups'] -and @($state.groups).Count -eq 1 -and $state.tabs[0].group_id -eq $state.groups[0].id
                } 'timing CMD membership in the user-created group'
                Press @(0x1B) 'Esc: leave inline group rename using the saved default name'
                $gapCase.phase = 'second-console'
                Palette 'new cmd'
                Press @(0x0D) 'Enter: create second CMD for Ctrl+Tab timing'
                Wait-Until {
                    $state = Read-Session
                    @($state.tabs).Count -eq 2 -and $state.active_tab -eq 1 -and $state.tabs[1].kind -eq 'cmd' -and
                        (-not $state.tabs[1].PSObject.Properties['group_id'] -or $state.tabs[1].group_id -eq 0)
                } 'second ungrouped timing CMD saved and selected'
                $consoleTab = (Read-Session).active_tab
                Wait-WorkspaceSurface $initial.active_workspace $consoleTab $false
                $state = Read-Session
                $consoles = @{}
                $browsers = @{}
                $docks = @{}
                $shellIds = @($state.tabs[0].shell_id, $state.tabs[1].shell_id)
                foreach ($tab in @(0, 1)) {
                    $gapCase.phase = "console-identification-$tab"
                    Press @(0x11, (0x31 + $tab)) ('Ctrl+' + ($tab + 1) + ': identify timing console')
                    Wait-WorkspaceSurface $initial.active_workspace $tab $false
                    $consoles[$tab] = [VerifyNative]::GetForegroundWindow()
                    $browsers[$tab] = [IntPtr]::Zero
                    $docks[$tab] = New-Object VerifyNative+Rect
                    $consoleArea = New-Object VerifyNative+Rect
                    if (-not [VerifyNative]::GetWindowRect($consoles[$tab], [ref]$consoleArea)) { throw 'Timing console rectangle unavailable' }
                    $plainRgb = [VerifyNative]::SolidPatch($consoleArea)
                    Type-Text ('color ' + $consoleCodes[$tab])
                    Press @(0x0D) 'Enter: give this timing CMD its own solid color'
                    Wait-Until { $solidRgb = [VerifyNative]::SolidPatch($consoleArea); $solidRgb -ge 0 -and $solidRgb -ne $plainRgb } 'timing CMD shows its own solid color'
                    $consoleRgb[$tab] = [VerifyNative]::SolidPatch($consoleArea)
                    $docks[$tab] = $consoleArea
                }
                $consoleGap = 0
                foreach ($shift in @(16, 8, 0)) { $consoleGap = [Math]::Max($consoleGap, [Math]::Abs((($consoleRgb[0] -shr $shift) -band 255) - (($consoleRgb[1] -shr $shift) -band 255))) }
                if ($consoleGap -le 8) { throw 'Timing console colors are not distinct' }
                $gapCase.phase = 'browser-off-baseline'
                if (@((Read-Inbox).shells | Where-Object { $_.browser_state -ne 'closed' }).Count -ne 0) { throw 'Browser-off baseline already has a pane' }
                $warmupStopped = $warmupJob.Stop()
                Save-Json @{ activeAfterStop = $warmupStopped.ActiveProcesses } 'browser-setup-process-tree.json'
                $warmupJob.Dispose()
                $warmupJob = $null
                foreach ($mode in $modes) {
                    $chat = $mode.StartsWith('chat_')
                    $browserOn = $mode.EndsWith('browser_on')
                    $frozen = $mode.Contains('frozen_')
                    $sampleCount = $timings[$mode].samples_ms.Count
                    $paintRgb = if ($browserOn) { $rgb } else { $consoleRgb }
                    if ($mode -eq 'chat_browser_off') {
                        $gapCase.phase = 'chat-setup'
                        Focus-Palette 'chat view off everywhere' 6347
                        Press @(0x0D) 'Enter: reset both switch test sessions to shell'
                        Wait-Until {
                            $state = Read-Session
                            $null -ne $state -and @($state.tabs).Count -eq 2 -and -not $state.PSObject.Properties['chat_view_mode'] -and
                                @($state.tabs | Where-Object { ($_.PSObject.Properties['cv'] -and $_.cv) -or $_.PSObject.Properties['chat_view_lock'] }).Count -eq 0
                        } 'both switch test sessions saved in shell view without removed locks'
                        foreach ($tab in @(0, 1)) {
                            Press @(0x11, (0x31 + $tab)) 'Select session to enable Chat View'
                            Wait-WorkspaceSurface $initial.active_workspace $tab $false
                            $script:browserShellId = $shellIds[$tab]
                            Press-CloseBrowserPane 'Alt+A: close browser pane for Chat View baseline'
                            $null = Assert-BrowserPane 'closed' ('chat-baseline-' + $tab)
                            $browsers[$tab] = [IntPtr]::Zero
                            Press @(0x12, 0x43) 'Alt+C: enable Chat View for this session'
                            Wait-Until { (Read-Session).tabs[$tab].cv } 'Chat View saved for this session'
                            $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                            $editCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
                            Wait-Until {
                                $candidate = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $editCondition)
                                $null -ne $candidate -and $candidate.Current.ProcessId -eq $process.Id -and -not $candidate.Current.IsOffscreen
                            } 'owned Chat View composer visible'
                            $composerHandle = [IntPtr]($root.FindFirst([System.Windows.Automation.TreeScope]::Children, $editCondition).Current.NativeWindowHandle)
                            Wait-WorkspaceSurface $initial.active_workspace $tab $true ($composerHandle.ToInt32())
                            Type-Text $drafts[$tab]
                            Wait-Until { [VerifyNative]::EditText($composerHandle) -ceq $drafts[$tab] } 'distinct unsent synthetic session draft'
                            $regions[$tab] = [VerifyNative]::CaptureComposerStart($composerHandle)
                        }
                        $patches = [VerifyNative]::CalibratePatches($regions[0], $regions[1])
                        Save-Json @{ session0 = @($patches[0]); session1 = @($patches[1]) } 'chat-browser-off-patches.json'
                    }
                    if ($browserOn -and -not $frozen) {
                        foreach ($tab in @(0, 1)) {
                            $gapCase.phase = "$mode-setup-$tab"
                            Press @(0x11, (0x31 + $tab)) ('Ctrl+' + ($tab + 1) + ': open this session browser')
                            Wait-WorkspaceSurface $initial.active_workspace $tab $chat ($composerHandle.ToInt32())
                            $script:browserShellId = $shellIds[$tab]
                            $pane = Open-BrowserPane ($mode + '-' + $tab)
                            Wait-SwitchNativeHost
                            Wait-Until { $pane = Read-BrowserPane; $null -ne $pane -and $pane.browser_state -eq 'connected' -and $pane.browser_window_id -gt 0 -and [VerifyNative]::DockedPaneWindow($script:window) -ne [IntPtr]::Zero } 'connected timing browser with app-published CDP binding in its session' 30
                            $browser = [VerifyNative]::DockedPaneWindow($script:window)
                            $dock = New-Object VerifyNative+Rect
                            if (-not [VerifyNative]::GetWindowRect($browser, [ref]$dock)) { throw 'Timing browser dock rectangle unavailable' }
                            Palette 'jump browser'
                            Press @(0x0D) 'Enter: focus the session browser through the palette'
                            Wait-Until { [VerifyNative]::GetForegroundWindow() -eq $browser } 'target browser foreground for real address-bar navigation'
                            Doctor
                            if ([VerifyNative]::GetProp($browser, 'ZigShellPaneOwner') -ne $script:window -or [VerifyNative]::DockedPaneWindow($script:window) -ne $browser) { throw 'Navigation browser ownership changed' }
                            [uint32]$browserPid = 0
                            [void][VerifyNative]::GetWindowThreadProcessId($browser, [ref]$browserPid)
                            Record 'Focus verified session browser HWND before address-bar input'
                            [VerifyNative]::FocusOwnedWindow($browser, $browserPid, $script:window)
                            if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw 'Browser lost focus before Ctrl+L' }
                            Record 'Ctrl+L: navigate through the native browser address bar'
                            [VerifyNative]::Chord(@(0x11, 0x4C))
                            $browserRoot = [System.Windows.Automation.AutomationElement]::FromHandle($browser)
                            $omniboxCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'OmniboxViewViews')
                            Wait-Until {
                                $omnibox = $browserRoot.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $omniboxCondition)
                                $null -ne $omnibox -and $omnibox.Current.HasKeyboardFocus -and
                                    [System.Windows.Automation.Automation]::Compare($omnibox, [System.Windows.Automation.AutomationElement]::FocusedElement) -and
                                    [VerifyNative]::GetForegroundWindow() -eq $browser
                            } 'verified pane native address bar has keyboard focus'
                            $pageTitle = 'Switch paint ' + $tab
                            $html = '<title>' + $pageTitle + '</title><style>html,body{margin:0;width:100%;height:100%;background:' + $colors[$tab] + '}</style><script>let keys=0;addEventListener("keydown",e=>{if([" ","ArrowDown","j","k"].includes(e.key)){e.preventDefault();document.title="' + $pageTitle + ' keys "+(++keys)}})</script>'
                            $pageUrl = 'data:text/html,' + [Uri]::EscapeDataString($html)
                            if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw 'Browser lost address-bar focus' }
                            [VerifyNative]::Text($pageUrl)
                            Wait-Until {
                                $omnibox = $browserRoot.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $omniboxCondition)
                                $null -ne $omnibox -and $omnibox.Current.HasKeyboardFocus -and
                                    $omnibox.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value -ceq $pageUrl -and
                                    [VerifyNative]::GetForegroundWindow() -eq $browser
                            } 'complete color URL is in the focused pane address bar'
                            if ([VerifyNative]::GetProp($browser, 'ZigShellPaneOwner') -ne $script:window -or [VerifyNative]::DockedPaneWindow($script:window) -ne $browser) { throw 'Navigation browser ownership changed before Enter' }
                            if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw 'Browser lost focus before navigation' }
                            Record 'Enter: show the synthetic full-viewport session color'
                            [VerifyNative]::Chord(@(0x0D))
                            Wait-Until {
                                [VerifyNative]::DockedPaneWindow($script:window) -eq $browser -and
                                    [VerifyNative]::Title($browser).StartsWith($pageTitle + ' ', [StringComparison]::Ordinal) -and
                                    [VerifyNative]::PagePainted($dock, $rgb[$tab])
                            } 'active pane tab is the color page and target session color visibly painted below the browser toolbar' -Tight
                            Record 'IGSH-724: leave the omnibox focused before Alt+Q returns to the page'
                            [VerifyNative]::Chord(@(0x11, 0x4C))
                            if ([System.Windows.Automation.AutomationElement]::FocusedElement.Current.ClassName -ne 'OmniboxViewViews') { throw 'Ctrl+L did not focus the browser address bar' }
                            [VerifyNative]::Chord(@(0x12, 0x51))
                            Wait-Until { [VerifyNative]::SwitchReady($script:window, $consoles[$tab], ('ZigShell-' + $shellIds[$tab]), $browser, $dock, $composerHandle, $drafts[$tab]) } 'IGSH-724 Alt+Q did not restore the session input'
                            [VerifyNative]::Chord(@(0x12, 0x51))
                            $pageKeys = 0
                            foreach ($key in @(0x20, 0x28, 0x4A, 0x4B)) {
                                if ([VerifyNative]::GetForegroundWindow() -ne $browser -or [VerifyNative]::GetProp($browser, 'ZigShellPaneOwner') -ne $script:window) { throw 'Refusing page key outside the owned browser' }
                                [VerifyNative]::Chord(@($key))
                                $pageKeys++
                                if (-not [VerifyNative]::Title($browser).StartsWith(($pageTitle + ' keys ' + $pageKeys + ' '), [StringComparison]::Ordinal)) { throw 'IGSH-724 Alt+Q sent a page key to browser chrome' }
                            }
                            Record 'IGSH-972: repeated Alt+Q round trips deliver every page key'
                            foreach ($round in 1..5) {
                                [VerifyNative]::Chord(@(0x12, 0x51))
                                Wait-Until { [VerifyNative]::SwitchReady($script:window, $consoles[$tab], ('ZigShell-' + $shellIds[$tab]), $browser, $dock, $composerHandle, $drafts[$tab]) } ('IGSH-972 round ' + $round + ' Alt+Q did not restore the session input')
                                [VerifyNative]::Chord(@(0x12, 0x51))
                                foreach ($key in @(0x20, 0x28, 0x4A, 0x4B)) {
                                    if ([VerifyNative]::GetForegroundWindow() -ne $browser -or [VerifyNative]::GetProp($browser, 'ZigShellPaneOwner') -ne $script:window) { throw ('IGSH-972 round ' + $round + ' refusing page key outside the owned browser') }
                                    [VerifyNative]::Chord(@($key))
                                    $pageKeys++
                                    if (-not [VerifyNative]::Title($browser).StartsWith(($pageTitle + ' keys ' + $pageKeys + ' '), [StringComparison]::Ordinal)) { throw ('IGSH-972 round ' + $round + ' Alt+Q sent a page key to the browser menu') }
                                }
                            }
                            Record 'IGSH-724: F6 still reaches browser chrome'
                            [VerifyNative]::Chord(@(0x75))
                            if ([System.Windows.Automation.AutomationElement]::FocusedElement.Current.ClassName -ne 'OmniboxViewViews') { throw 'F6 did not reach the browser address bar' }
                            [VerifyNative]::Chord(@(0x12, 0x51))
                            Palette 'open browser'
                            $hopLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
                            $hopStart = (Read-SharedText $hopLog).Length
                            Press @(0x0D) 'IGSH-724: opening an existing pane focuses its page'
                            Wait-Until { (Read-SharedText $hopLog).Substring($hopStart) -match 'pane_hop result bh_fg=true' } 'IGSH-998 app finished the open-pane hop to its browser'
                            if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw 'Opening the pane did not focus its browser' }
                            [VerifyNative]::Chord(@(0x20))
                            $pageKeys++
                            if (-not [VerifyNative]::Title($browser).StartsWith(($pageTitle + ' keys ' + $pageKeys + ' '), [StringComparison]::Ordinal)) { throw 'IGSH-724 opening a pane sent Space to browser chrome' }
                            [VerifyNative]::Chord(@(0x12, 0x51))
                            Wait-Until { [VerifyNative]::SwitchReady($script:window, $consoles[$tab], ('ZigShell-' + $shellIds[$tab]), $browser, $dock, $composerHandle, $drafts[$tab]) } 'IGSH-724 page-to-input return lost session typing focus'
                            $result.checks += @{ name = 'IGSH-724 browser-page-focus'; mode = $mode; tab = $tab; pageKeys = $pageKeys; ctrlL = $true; f6 = $true; inputReturn = $true }
                            $browsers[$tab] = $browser
                            $docks[$tab] = $dock
                        }
                        if ($browsers[0] -eq $browsers[1]) { throw 'Timing sessions do not have distinct browser HWNDs' }
                        $identities = foreach ($tab in @(0, 1)) {
                            @{ tab = $tab; shellId = $shellIds[$tab]; consoleHwnd = $consoles[$tab].ToInt64(); browserHwnd = $browsers[$tab].ToInt64(); dock = $docks[$tab]; color = $colors[$tab] }
                        }
                        Save-Json @($identities) ("$mode-window-identities.json")
                    }
                    if ($frozen) {
                        foreach ($tab in @(1, 0)) {
                            $gapCase.phase = "$mode-reset-$tab"
                            Press @(0x11, (0x31 + $tab)) 'Select session to verify its freeze marker is cleared before fresh sampling'
                            Wait-WorkspaceSurface $initial.active_workspace $tab $chat ($composerHandle.ToInt32())
                            Wait-Until { $false -eq (Read-BrowserFrozen $shellIds[$tab]) } 'active browser freeze marker cleared'
                        }
                        Wait-Until {
                            $panes = @((Read-Inbox).shells | Where-Object { $_.sid -in $shellIds -and $_.browser_state -eq 'connected' -and $_.browser_window_id -gt 0 })
                            $panes.Count -eq 2
                        } 'both timing browsers have app-published CDP window bindings' 30
                    }
                    $paintPatch = if ($mode -eq 'chat_browser_off') { $patches } else { @($null, $null) }
                    $gapCase.phase = "$mode-start"
                    Press @(0x11, 0x31) 'Ctrl+1: start timing from first session'
                    Wait-WorkspaceSurface $initial.active_workspace 0 $chat ($composerHandle.ToInt32())
                    Wait-Until { [VerifyNative]::PagePainted($docks[0], $paintRgb[0], $paintPatch[0]) } 'first session color before measurement' -Tight
                    Snapshot $(if ($mode -eq 'browser_off') { 'before' } elseif ($mode -eq 'browser_on') { 'action' } else { $mode + '-action' })
                    for ($sample = 0; $sample -lt $sampleCount; $sample++) {
                        $gapCase.phase = "$mode-sample-$sample"
                        $target = ($sample + 1) % 2
                        Doctor
                        if ($frozen) {
                            $frozenLogStart = ((Get-Content $log -Raw) -join '').Length
                            $freeze = @{ mode = $mode; sample = $sample; target = $target; shellId = $shellIds[$target]; marker = "panehib-zss-$($shellIds[$target]).flag"; status = 'waiting'; wait_ms = $null; marker_cleared = $false; window_visible_ms = $null; wake_flag_cleared_ms = $null; target_color_painted_ms = $null; log_start = $frozenLogStart; log_end = $null }
                            [void]$frozenSwitches.Add($freeze)
                            if ($false -ne (Read-BrowserFrozen $shellIds[$target])) { throw 'Target already frozen; expected a fresh freeze after its last activation' }
                            $parked = [Diagnostics.Stopwatch]::StartNew()
                            Wait-Until {
                                $state = Read-Session
                                $null -ne $state -and $state.active_tab -eq (1 - $target) -and $state.tabs[$target].shell_id -eq $shellIds[$target] -and
                                    ($true -eq (Read-BrowserFrozen $shellIds[$target]))
                            } "fresh app-published freeze marker for parked target $target" 150
                            $freeze.wait_ms = $parked.Elapsed.TotalMilliseconds
                            $freeze.status = 'frozen'
                            $freeze.observed_utc = [DateTime]::UtcNow.ToString('o')
                            $bridgePath = Join-Path (Split-Path $Exe) 'zigshell-bridge.exe'
                            $freezeWindow = @((Read-Inbox).shells | Where-Object { $_.sid -eq $shellIds[$target] })[0].browser_window_id
                            Wait-Until {
                                $workers = @(Get-CimInstance Win32_Process -Filter "Name = 'zigshell-bridge.exe'" | Where-Object {
                                    $_.ExecutablePath -ceq $bridgePath -and $_.CommandLine -match ('--window\s+' + $freezeWindow + '\s+cdp\s+Page\.setWebLifecycleState\s+') -and $_.CommandLine.Contains('frozen')
                                })
                                $workers.Count -eq 0
                            } 'app freeze helper exited before timed input; dispatch-only markers cannot race wake'
                            $freeze.worker_finished_utc = [DateTime]::UtcNow.ToString('o')
                            Doctor
                            Assert-Foreground
                        }
                        $source = 1 - $target
                        [VerifyNative]::RequireSwitchStart($script:window, $composerHandle, $consoles[$source], ('ZigShell-' + $shellIds[$source]), $browsers[$source], $docks[$source], $drafts[$source], $consoles[$target], ('ZigShell-' + $shellIds[$target]), $browsers[$target], $docks[$target], $drafts[$target], $paintRgb[$source], $paintRgb[$target], $paintPatch[$source], $paintPatch[$target])
                        Record ("Ctrl+Tab timing $mode sample=$sample target=$target shellId=" + $shellIds[$target])
                        $logStart = ((Get-Content $log -Raw) -join '').Length
                        $frozenMarker = if ($frozen) { Join-Path $scratch ("roaming/ZigShell/panehib-zss-$($shellIds[$target]).flag") } else { $null }
                        $measurement = [VerifyNative]::MeasureSessionSwitch($script:window, $consoles[$target], ('ZigShell-' + $shellIds[$target]), $browsers[$target], $docks[$target], $composerHandle, $drafts[$target], $paintRgb[$target], $frozenMarker, $paintPatch[$target])
                        $timings[$mode].samples_ms[$sample] = $measurement[0]
                        $timings[$mode].window_visible_ms[$sample] = $measurement[1]
                        if ($frozen) {
                            $freeze.window_visible_ms = $measurement[1]
                            $freeze.wake_flag_cleared_ms = $measurement[2]
                            $freeze.target_color_painted_ms = $measurement[0]
                        }
                        Wait-WorkspaceSurface $initial.active_workspace $target $chat ($composerHandle.ToInt32())
                        $pattern = 'switch-timing: to=(\d+) total_us=\d+[^\r\n]*'
                        $debugAfter = (Get-Content $log -Raw) -join ''
                        $traceMatches = @()
                        if ($debugAfter.Length -ge $logStart) { $traceMatches = [regex]::Matches($debugAfter.Substring($logStart), $pattern) }
                        Save-Json @{ mode = $mode; sample = $sample; start = $logStart; end = $debugAfter.Length; complete = $debugAfter.Length -ge $logStart } ("$mode-$sample-log-range.json")
                        if ($traceMatches.Count -ne 1 -or [int]$traceMatches[0].Groups[1].Value -ne $target) { throw "Sample was not exactly one app switch to session $target; switch-timing lines in its log range: $($traceMatches.Count)" }
                        $line = $traceMatches[0].Value
                        [void]$traceLines.Add($line)
                        $steps = @{}
                        foreach ($field in [regex]::Matches($line, '(\w+_us)=(\d+)')) { $steps[$field.Groups[1].Value] = [double]$field.Groups[2].Value }
                        $traces[$mode] += $steps
                        if ($frozen) {
                            $frozenText = $debugAfter.Substring($freeze.log_start)
                            $idPattern = 'shell=' + $shellIds[$target] + ' '
                            if ($frozenText -notmatch ('(?s)browser freeze confirmed: ' + $idPattern + '.*hook: Ctrl\+Tab shift=0 -> NEXT_TAB.*browser wake sent: ' + $idPattern + '.*switchToShell: ' + (1 - $target) + ' -> ' + $target + ' ')) { throw "Frozen target $target was not frozen before Ctrl+Tab and woken by it in the app log" }
                            Wait-Until { $false -eq (Read-BrowserFrozen $shellIds[$target]) } 'target freeze marker removed by app wake'
                            $freeze.marker_cleared = $true
                            $freeze.status = 'painted-and-awake'
                            $freeze.log_end = ((Get-Content $log -Raw) -join '').Length
                        }
                    }
                    if ($mode -eq 'browser_on') {
                        $offMedian = Get-SwitchMedian $timings.browser_off.samples_ms
                        $onMedian = Get-SwitchMedian $timings.browser_on.samples_ms
                        if ($onMedian - $offMedian -gt 50) {
                            $gapCase.phase = 'switch-gap'
                            $gapCase.detail = "browser_on minus browser_off = $($onMedian - $offMedian) ms; required <= 50 ms"
                            throw $gapCase.detail
                        }
                    }
                }
                foreach ($mode in $modes) { $timings[$mode].median_ms = Get-SwitchMedian $timings[$mode].samples_ms }
                $gapCase.phase = 'switch-gap'
                $gaps = foreach ($pair in @(@('browser_off', 'browser_on'), @('chat_browser_off', 'chat_browser_on'), @('browser_off', 'frozen_browser_on'), @('chat_browser_off', 'chat_frozen_browser_on'))) {
                    $gap = $timings[$pair[1]].median_ms - $timings[$pair[0]].median_ms
                    @{ off = $pair[0]; on = $pair[1]; gap_ms = $gap }
                }
                $gapCase.detail = ($gaps | ForEach-Object { "$($_.on) minus $($_.off) = $($_.gap_ms) ms; required <= 50 ms" }) -join '; '
                foreach ($pair in $gaps) { if ($pair.gap_ms -gt 50) { throw $gapCase.detail } }
                $gapCase.phase = 'after-snapshot'
                Snapshot 'after'
                $gapCase.status = 'passed'
            } catch {
                $gapCase.detail = $gapCase.phase + ': ' + $_.Exception.Message
                throw
            } finally {
                foreach ($mode in $modes) {
                    $timings[$mode].median_ms = Get-SwitchMedian $timings[$mode].samples_ms
                    $timings[$mode].window_visible_median_ms = Get-SwitchMedian $timings[$mode].window_visible_ms
                    if ($traces[$mode].Count -eq $timings[$mode].samples_ms.Count -and @($traces[$mode] | Where-Object { $null -eq $_ }).Count -eq 0) {
                        $timings.steps[$mode] = @{}
                        foreach ($step in $traces[$mode][0].Keys) {
                            $values = @($traces[$mode] | ForEach-Object { $_[$step] })
                            $timings.steps[$mode][$step] = Get-SwitchMedian $values
                        }
                    }
                }
                Save-Json (Read-Inbox) 'switch-final-inbox.json'
                Save-Json (Read-Session) 'switch-final-session.json'
                Save-Json $timings 'switch-timings.json'
                Save-Json $traces 'switch-traces.json'
                if ($null -ne $frozenLogStart -and (Test-Path $log)) {
                    $debug = (Get-Content $log -Raw) -join ''
                    foreach ($freeze in $frozenSwitches) {
                        $end = if ($null -eq $freeze.log_end) { $debug.Length } else { $freeze.log_end }
                        $lines = if ($freeze.log_start -le $end -and $end -le $debug.Length) { $debug.Substring($freeze.log_start, $end - $freeze.log_start) } else { $debug }
                        $lines | Set-Content -Encoding UTF8 (Join-Path $Evidence ("{0}-{1}-debug.log" -f $freeze.mode, $freeze.sample))
                    }
                }
                Save-Json @($frozenSwitches.ToArray()) 'frozen-switches.json'
                if ($gapCase.status -ne 'passed' -and $gapCase.phase -like '*sample-*') {
                    try {
                        Save-Json @{ expected = $paintRgb[$target]; patch = @($paintPatch[$target]); normal = @([VerifyNative]::ReadSwitchScreenPatch($docks[$target], $false)); layered = @([VerifyNative]::ReadSwitchScreenPatch($docks[$target], $true)); dock = $docks[$target] } 'switch-failure-screen-patch.json'
                        $diagnosticPane = @((Read-Inbox).shells | Where-Object { $_.sid -eq $shellIds[$target] })[0]
                        $expression = 'JSON.stringify({url:location.href,visibility:document.visibilityState,focused:document.hasFocus(),html:document.documentElement.outerHTML,rect:document.documentElement.getBoundingClientRect().toJSON(),bodyRect:document.body.getBoundingClientRect().toJSON(),htmlBg:getComputedStyle(document.documentElement).backgroundColor,bodyBg:getComputedStyle(document.body).backgroundColor})'
                        $probes = @(
                            @{ name = 'tabs'; method = $null; params = $null },
                            @{ name = 'dom'; method = 'Runtime.evaluate'; params = @{ expression = $expression; returnByValue = $true } },
                            @{ name = 'capture'; method = 'Page.captureScreenshot'; params = @{ format = 'png' } }
                        )
                        $probeResults = @()
                        foreach ($probe in $probes) {
                            $arguments = '--window ' + $diagnosticPane.browser_window_id
                            if ($null -eq $probe.method) { $arguments += ' tabs' } else {
                                $params = $probe.params | ConvertTo-Json -Compress
                                $arguments += ' cdp ' + $probe.method + ' "' + $params.Replace('"', '\"') + '"'
                            }
                            $prefix = Join-Path $Evidence ('switch-failure-' + $probe.name)
                            $probeJob = New-Object VerifyJob
                            $probeProcess = $null
                            try {
                                $probeProcess = $probeJob.Start((Join-Path (Split-Path $Exe) 'zigshell-bridge.exe'), $scratch, ($prefix + '.stdout.json'), ($prefix + '.stderr.log'), $arguments)
                                $exited = $probeProcess.WaitForExit(30000)
                            } finally {
                                try { $probeStopped = $probeJob.Stop() } finally {
                                    if ($null -ne $probeProcess) { $probeProcess.Dispose() }
                                    $probeJob.Dispose()
                                }
                            }
                            $probeResults += @{ name = $probe.name; exited = $exited; windowId = $diagnosticPane.browser_window_id; activeAfterStop = $probeStopped.ActiveProcesses }
                            if (-not $exited) { break }
                        }
                        Save-Json $probeResults 'switch-failure-browser-diagnostics.json'
                    } catch { Save-Json @{ error = $_.Exception.Message } 'switch-failure-browser-diagnostics.json' }
                }
                $traceLines | Set-Content -Encoding UTF8 (Join-Path $Evidence 'switch-timing-debug.log')
            }
        