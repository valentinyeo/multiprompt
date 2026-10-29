
            $shapeResult = $null
            if ($shapeProof) {
                Add-Type -AssemblyName System.Windows.Forms
                Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -Path (Join-Path $PSScriptRoot '../../../tools/verify-chat-delivery/chat-switch-observer.cs')
                [ChatSwitchObserver]::SidebarHeaderHeight = if ($env:RELEASE_TAG -eq 'v0.28.946') { 0 } else { 52 }
                $shapeResult = [ordered]@{ schema = 1; source = 'GitHub Windows native desktop'; setup_passed = $false; errors = @(); app = @{ tag = $env:RELEASE_TAG; sha256 = $ExpectedHash; optimization = $env:VERIFY_OPTIMIZATION }; fixture = (Get-Content (Join-Path $Evidence 'chat-shape-manifest.json') -Raw | ConvertFrom-Json); session_shells = @(); modes = [ordered]@{ browser_closed = @(); browser_open = @() }; idle = @{} }
            }
            function Save-ShapeLatest([string]$Expected, [string]$Marker, [string]$Name) {
                Doctor
                Assert-Foreground
                Record 'Copy the actual transcript through owned app commands outside timed and image windows'
                [Windows.Forms.Clipboard]::Clear()
                [ChatSwitchObserver]::CopyTranscript($process.Id, $script:window)
                Wait-Until { [Windows.Forms.Clipboard]::ContainsText() } 'owned transcript copy completed' 10
                $copied = [Windows.Forms.Clipboard]::GetText()
                $latest = [regex]::Match($copied, [regex]::Escape($Expected))
                $last = [regex]::Match($copied, [regex]::Escape($Marker))
                if (-not $latest.Success -or -not $last.Success) {
                    Save-Json @{ expected = $Expected; marker = $Marker; latest_found = $latest.Success; marker_found = $last.Success; copied_characters = $copied.Length; session = (Read-Session) } 'receipt-failure.json'
                    [IO.File]::WriteAllText((Join-Path $Evidence 'receipt-failure.txt'), $copied, (New-Object Text.UTF8Encoding($false)))
                    if (-not $last.Success) { throw 'Copied target transcript belongs to a different seeded session' }
                }
                [IO.File]::WriteAllText((Join-Path $Evidence $Name), ($latest.Value + "`n" + $last.Value), (New-Object Text.UTF8Encoding($false)))
                Press @(0x1B) 'Esc: clear the copied transcript selection'
                return $latest.Success
            }
            function Wait-SwitchForeground {
                if ($shapeProof) {
                    $state = Read-Session
                    if ([VerifyNative]::GetDpiForWindow($script:window) -ne 96 -or
                        ($state.single_window -and -not $state.hide_pills) -or
                        ($state.PSObject.Properties['groups'] -and @($state.groups).Count -gt 0) -or
                        ($state.PSObject.Properties['ui_scale'] -and $state.ui_scale -ne 100) -or
                        ($state.PSObject.Properties['hide_sidebar'] -and $state.hide_sidebar) -or
                        ($state.PSObject.Properties['sidebar_collapsed'] -and $state.sidebar_collapsed) -or
                        @($state.tabs | Where-Object { $_.PSObject.Properties['pinned_top'] -and $_.pinned_top }).Count -gt 0) { throw 'Sidebar timing requires the default ungrouped five-row fixture at 96 DPI' }
                }
                Doctor
                Wait-Until {
                    if ([VerifyNative]::GetForegroundWindow() -ne $script:window) {
                        [VerifyNative]::BringToForeground($script:window)
                    }
                    [VerifyNative]::GetForegroundWindow() -eq $script:window
                } 'owned main window foreground before switch observation' 10
            }
            function Test-TabChat($tab) { return [bool]($tab.PSObject.Properties['cv'] -and $tab.cv) }
            $sessionCount = 5
            $switchCount = 20
            $chatLimitMs = $releaseGatePolicy.checks.'chat-switch'.limit
            $hangLimitMs = $releaseGatePolicy.checks.'ui-hang'.limit
            $settleMs = 1200
            $modes = @('browser_closed', 'browser_open')
            $timings = [ordered]@{ session_count = $sessionCount; switches_per_mode = $switchCount; click_to_chat_limit_ms = $chatLimitMs; hang_limit_ms = $hangLimitMs }
            foreach ($mode in $modes) { $timings[$mode] = @{ samples_ms = @(); app_ms = @(); hang_ms = @(); missing = 0; median_ms = $null; max_ms = $null; max_hang_ms = $null; first_frame_layout_w = @(); first_frame_client_w = @(); first_frame_wrong_width = 0; moved_after_first_frame = 0; moved_lines = @() } }
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $gapCase = @{ name = 'chat-switch-speed'; status = 'failed'; detail = 'Chat switch measurement did not complete'; phase = 'initial-console' }
            function Read-SharedLog([string]$Path, [long]$ByteOffset = 0) {
                $stream = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
                try {
                    if ($ByteOffset -gt $stream.Length) { throw 'Switch log was truncated' }
                    [void]$stream.Seek($ByteOffset, [IO.SeekOrigin]::Begin)
                    $reader = New-Object System.IO.StreamReader($stream)
                    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
                } finally { $stream.Dispose() }
            }
            function Add-SeedTurn([string]$SessionName, [int]$Round) {
                $seed = Get-Content (Join-Path $remoteState 'state.json') -Raw | ConvertFrom-Json
                $sid = $seed.sids.PSObject.Properties[$SessionName].Value
                $index = [Array]::IndexOf(@($seed.sessions), $SessionName)
                if (-not $sid -or $index -lt 0) { throw 'Selected session has no seeded transcript identity' }
                $folder = ('C:/verify/work{0}' -f $index) -replace '[^A-Za-z0-9]', '-'
                $path = Join-Path $scratch ("profile/.claude/projects/$folder/$sid.jsonl")
                $text = "Session $index live answer $Round`n`n" + ('This paragraph stands in for a running agent adding a new answer to the conversation while another session is in front. ' * 3)
                $row = [ordered]@{ type = 'assistant'; timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'); sessionId = $sid; uuid = [guid]::NewGuid().ToString(); isSidechain = $false; message = [ordered]@{ role = 'assistant'; id = ('msg_live_' + [guid]::NewGuid().ToString('N').Substring(0, 12)); model = 'claude-opus-5-5'; content = @(@{ type = 'text'; text = $text }) } }
                [IO.File]::AppendAllText($path, (($row | ConvertTo-Json -Depth 6 -Compress) + "`n"), (New-Object System.Text.UTF8Encoding($false)))
                return @{ session_id = $sid; expected_latest = "Session $index live answer $Round"; last_marker = "IGSH1040_LAST_$($index + 1)" }
            }
            $result.checks += $gapCase
            $shellIds = @()
            $toggleReady = $null
            $probeStarted = $false
            try {
                Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq $sessionCount -and @($state.tabs | Where-Object { $_.kind -eq 'tmux' }).Count -eq $sessionCount } 'five seeded remote sessions restored'
                $gapCase.phase = 'idle-close-fixture'
                Focus-Palette 'browser auto suspend' 6240
                Press @(0x0D) 'Enter: disable timed browser closing while measuring'
                Wait-Until { $state = Read-Session; $state.PSObject.Properties['browser_suspend_min'] -and $state.browser_suspend_min -eq 0 } 'app saved idle browser closing disabled'
                $gapCase.phase = 'manual-tab-order'
                Focus-Palette 'tab order' 6217
                Press @(0x28) 'Down: Tab Order Manual'
                Press @(0x0D) 'Enter: keep saved order for Ctrl+1 to Ctrl+5'
                Wait-Until {
                    $path = Join-Path $scratch 'roaming/ZigShell/session.json.launch.json'
                    if (-not (Test-Path $path)) { return $false }
                    $launch = Get-Content $path -Raw | ConvertFrom-Json
                    $launch.PSObject.Properties['sort_auto'] -and -not $launch.sort_auto
                } 'manual tab order saved before creating sessions'
                for ($tab = 0; $tab -lt $sessionCount; $tab++) {
                    $gapCase.phase = "session-setup-$tab"
                    Press @(0x11, (0x31 + $tab)) "Ctrl+$($tab + 1): select remote session $tab"
                    Wait-Until { $state = Read-Session; $state.active_tab -eq $tab } "remote session $tab selected" 30
                    if ($null -ne $toggleReady) { Wait-Until { [DateTime]::UtcNow -ge $toggleReady } "Alt+C debounce elapsed before session $tab" }
                    Press @(0x12, 0x43) "Alt+C: open Chat View for session $tab"
                    $toggleReady = [DateTime]::UtcNow.AddMilliseconds(1600)
                    Wait-Until { Test-TabChat (Read-Session).tabs[$tab] } "Chat View saved for session $tab" 30
                    $shownId = (Read-Session).tabs[$tab].shell_id
                    Wait-Until { ((Get-Content $log -Raw) -join '') -match ('\[switch\] chat content shown shell=' + $shownId + ' blocks=[1-9]') } "seeded transcript shown for session $tab" 60
                    $shellIds += $shownId
                }
                $state = Read-Session
                if (@($state.tabs).Count -ne $sessionCount -or @($state.tabs | Where-Object { -not (Test-TabChat $_) }).Count -ne 0) { throw 'Not every session is in Chat View' }
                Save-Json @{ shellIds = $shellIds; tabs = @($state.tabs) } 'chat-switch-sessions.json'
                if ($null -ne $warmupJob) {
                    $warmupStopped = $warmupJob.Stop()
                    Save-Json @{ activeAfterStop = $warmupStopped.ActiveProcesses } 'browser-setup-process-tree.json'
                    $warmupJob.Dispose()
                    $warmupJob = $null
                }
                Snapshot 'before'
                [VerifyNative]::StartHangProbe($script:window)
                $probeStarted = $true
                if ($shapeProof) {
                    $shapeResult.session_shells = $shellIds
                    $shapeResult.setup_passed = $true
                    Wait-SwitchForeground
                    $shapeResult.idle.before = [ChatSwitchObserver]::Measure($process.Id, $script:window, -1, $log, 0, '', $settleMs, $null)
                }
                foreach ($mode in $modes) {
                    $open = $mode -eq 'browser_open'
                    if ($open) {
                        for ($tab = 0; $tab -lt $sessionCount; $tab++) {
                            $gapCase.phase = "$mode-setup-$tab"
                            Press @(0x11, (0x31 + $tab)) "Ctrl+$($tab + 1): select session to open its browser"
                            Wait-Until { (Read-Session).active_tab -eq $tab } "session $tab selected"
                            $script:browserShellId = $shellIds[$tab]
                            $null = Open-BrowserPane ("$mode-$tab")
                            Wait-SwitchNativeHost
                            Wait-Until { $pane = Read-BrowserPane; $null -ne $pane -and $pane.browser_state -eq 'connected' -and $pane.browser_window_id -gt 0 -and [VerifyNative]::DockedPaneWindow($script:window) -ne [IntPtr]::Zero } "session $tab browser connected and docked" 30
                        }
                    }
                    $gapCase.phase = "$mode-start"
                    Press @(0x11, 0x31) 'Ctrl+1: start timing from the first session'
                    Wait-Until { (Read-Session).active_tab -eq 0 } 'first session selected'
                    Start-Sleep -Milliseconds 1500
                    foreach ($warm in 1..($sessionCount - 1)) {
                        Press @(0x11, (0x31 + $warm)) "Ctrl+$($warm + 1): first visit warm-up"
                        Wait-Until { (Read-Session).active_tab -eq $warm } "warm-up session $warm selected"
                        Start-Sleep -Milliseconds 800
                    }
                    Press @(0x11, 0x31) 'Ctrl+1: return to the first session after warm-up'
                    Wait-Until { (Read-Session).active_tab -eq 0 } 'first session selected after warm-up'
                    Start-Sleep -Milliseconds 1500
                    $current = 0
                    for ($sample = 0; $sample -lt $switchCount; $sample++) {
                        $gapCase.phase = "$mode-sample-$sample"
                        $target = ($current + 1) % $sessionCount
                        Doctor
                        Wait-Until { [VerifyNative]::GetForegroundWindow() -eq $script:window } 'main window foreground before the switch' 10
                        $turn = if ($shapeProof -and $open) { $sample + $switchCount } else { $sample }
                        $seedTurn = Add-SeedTurn (Read-Session).tabs[$target].tmux_session $turn
                        Start-Sleep -Milliseconds 300
                        $offset = (Get-Item -LiteralPath $log).Length
                        $needle = '[switch] chat content shown shell=' + $shellIds[$target] + ' '
                        Record "Ctrl+$($target + 1): switch to Chat View session $target ($mode sample $sample)"
                        $shapeSample = $null
                        if ($shapeProof) {
                            $jobClock = [Diagnostics.Stopwatch]::StartNew()
                            $jobBefore = $job.ReadAccounting()
                            Wait-SwitchForeground
                            [VerifyNative]::ResetHangProbe()
                            $shapeSample = [ChatSwitchObserver]::Measure($process.Id, $script:window, $target, $log, $offset, $needle, $settleMs, $null)
                            $jobAfter = $job.ReadAccounting()
                            $jobClock.Stop()
                            $jobCpu = ([double]$jobAfter.UserTime + $jobAfter.KernelTime - $jobBefore.UserTime - $jobBefore.KernelTime) / 10000
                            $shapeSample.owned_job = @{ cpu_ms = $jobCpu; elapsed_ms = $jobClock.Elapsed.TotalMilliseconds; cpu_one_core_percent = 100 * $jobCpu / $jobClock.Elapsed.TotalMilliseconds; active_before = $jobBefore.ActiveProcesses; active_after = $jobAfter.ActiveProcesses }
                            $shapeSample.hang_ms = [VerifyNative]::HangProbeMax()
                            $measured = @($shapeSample.shown_ms, $shapeSample.hang_ms)
                        } else {
                            $measured = [VerifyNative]::SwitchToSession($target, $log, $offset, $needle, $settleMs)
                        }
                        if ((Read-Session).active_tab -ne $target) { throw "Switch $sample did not select session $target" }
                        $text = Read-SharedLog $log
                        $range = if ($shapeProof) { Read-SharedLog $log $offset } elseif ($offset -le $text.Length) { $text.Substring($offset) } else { '' }
                        $appMs = $null
                        $found = [regex]::Match($range, [regex]::Escape($needle) + 'blocks=\d+ ms=(\d+)')
                        if ($found.Success) { $appMs = [int]$found.Groups[1].Value }
                        if ($open -and -not [VerifyNative]::PaneVisible($script:window)) { throw "Browser pane not visible after switch $sample" }
                        $widths = [regex]::Match($range, [regex]::Escape($needle) + 'blocks=\d+ ms=\d+ layout_w=(-?\d+) client_w=(-?\d+)')
                        if ($widths.Success) {
                            $timings[$mode].first_frame_layout_w += [int]$widths.Groups[1].Value
                            $timings[$mode].first_frame_client_w += [int]$widths.Groups[2].Value
                            if ($widths.Groups[1].Value -ne $widths.Groups[2].Value) { $timings[$mode].first_frame_wrong_width++ }
                            $afterShown = $range.Substring($widths.Index + $widths.Length)
                            $laterMoves = @($afterShown -split "`n" | Where-Object { $_ -match '\[chat\] frame transcript|\[reposition\] client=' })
                            if ($laterMoves.Count -gt 0) { $timings[$mode].moved_after_first_frame++; $timings[$mode].moved_lines += $laterMoves[0].Trim() }
                        }
                        if ($measured[0] -lt 0) { $timings[$mode].missing++ }
                        $timings[$mode].samples_ms += $(if ($measured[0] -lt 0) { $settleMs } else { [Math]::Round($measured[0], 1) })
                        $timings[$mode].app_ms += $appMs
                        $timings[$mode].hang_ms += [Math]::Round($measured[1], 1)
                        $range | Set-Content -Encoding UTF8 (Join-Path $Evidence ("{0}-{1}-debug.log" -f $mode, $sample))
                        if ($shapeProof) {
                            if (-not $widths.Success -or $shapeSample.shown_ms -lt 0) { throw 'Shape sample needs a completed target paint with geometry' }
                            $shapeSample.index = $sample
                            $shapeSample.browser_mode = $mode
                            $shapeSample.source_shell = $shellIds[$current]
                            $shapeSample.target_shell = $shellIds[$target]
                            $shapeSample.layout_width = [int]$widths.Groups[1].Value
                            $shapeSample.client_width = [int]$widths.Groups[2].Value
                            $shapeSample.post_paint_moves = $laterMoves.Count -gt 0
                            $shapeSample.session_id = $seedTurn.session_id
                            $shapeSample.expected_latest = $seedTurn.expected_latest
                            $shapeSample.last_marker = $seedTurn.last_marker
                            $shapeSample.latest_receipt = "$mode-$sample-latest.txt"
                            $sourceOffset = (Get-Item -LiteralPath $log).Length
                            Press @(0x11, (0x31 + $current)) 'Return to the identical source for a separate image replay'
                            Wait-Until { (Read-Session).active_tab -eq $current -and (Read-SharedLog $log $sourceOffset).Contains('[switch] chat content shown shell=' + $shellIds[$current] + ' ') } 'same source painted before image replay' 30
                            $imageOffset = (Get-Item -LiteralPath $log).Length
                            $imagePrefix = "$mode-$sample"
                            Wait-SwitchForeground
                            $image = [ChatSwitchObserver]::Measure($process.Id, $script:window, $target, $log, $imageOffset, $needle, $settleMs, (Join-Path $Evidence $imagePrefix))
                            $image.source_shell = $shellIds[$current]
                            $image.target_shell = $shellIds[$target]
                            $image.image_prefix = $imagePrefix
                            $shapeSample.frame_probe = $image
                            $shapeSample.latest_message_verified = Save-ShapeLatest $shapeSample.expected_latest $shapeSample.last_marker $shapeSample.latest_receipt
                            $shapeResult.modes[$mode] += $shapeSample
                        }
                        $current = $target
                    }
                    $timings[$mode].median_ms = Get-SwitchMedian $timings[$mode].samples_ms
                    $timings[$mode].max_ms = ($timings[$mode].samples_ms | Measure-Object -Maximum).Maximum
                    $timings[$mode].max_hang_ms = ($timings[$mode].hang_ms | Measure-Object -Maximum).Maximum
                    if (-not $open) { Snapshot 'action' }
                }
                if ($shapeProof) {
                    Wait-SwitchForeground
                    $shapeResult.idle.after = [ChatSwitchObserver]::Measure($process.Id, $script:window, -1, $log, 0, '', $settleMs, $null)
                    if ($shapeProfile) {
                        $gapCase.phase = 'separate-profile'
                        $allSamples = @($shapeResult.modes.browser_closed) + @($shapeResult.modes.browser_open)
                        $slow = $allSamples | Sort-Object -Property @{ Expression = { [double]$_.shown_ms } } -Descending | Select-Object -First 1
                        $profileClosed = $slow.browser_mode -eq 'browser_closed'
                        if ($profileClosed) {
                            for ($tab = 0; $tab -lt $sessionCount; $tab++) {
                                Press @(0x11, (0x31 + $tab)) 'Select a session to restore the browser-closed profile mode'
                                Wait-Until { (Read-Session).active_tab -eq $tab } 'profile browser-close target selected'
                                $script:browserShellId = $shellIds[$tab]
                                Press-CloseBrowserPane 'Close this owned pane before the separate baseline profile'
                            }
                        }
                        $profileSource = [Array]::IndexOf($shellIds, $slow.source_shell)
                        $profileTarget = [Array]::IndexOf($shellIds, $slow.target_shell)
                        if ((Read-Session).active_tab -eq $profileSource) {
                            Press @(0x11, (0x31 + $profileTarget)) 'Leave the source so the profile setup must perform a real switch'
                            Wait-Until { (Read-Session).active_tab -eq $profileTarget } 'profile setup reached a distinct session'
                        }
                        $profileOffset = (Get-Item -LiteralPath $log).Length
                        Press @(0x11, (0x31 + $profileSource)) 'Restore the slowest measured source before profiling'
                        Wait-Until { (Read-Session).active_tab -eq $profileSource -and (Read-SharedLog $log $profileOffset).Contains('[switch] chat content shown shell=' + $slow.source_shell + ' ') } 'profile source painted' 30
                        $profileOffset = (Get-Item -LiteralPath $log).Length
                        . (Join-Path $PSScriptRoot '../../../tools/verify-chat-delivery/chat-switch-profile.ps1')
                        Invoke-ChatSwitchProfile -TargetProcessId $process.Id -Directory (Join-Path $Evidence 'switch-profile') -Route @{ source_shell = $slow.source_shell; target_shell = $slow.target_shell; original_shown_ms = $slow.shown_ms; browser_closed = $profileClosed } -Switch {
                            Wait-SwitchForeground
                            [ChatSwitchObserver]::Measure($process.Id, $script:window, $profileTarget, $log, $profileOffset, ('[switch] chat content shown shell=' + $slow.target_shell + ' '), $settleMs, $null)
                        }
                        $profileRange = (Read-SharedLog $log $profileOffset)
                        $profileRange | Set-Content -Encoding UTF8 (Join-Path $Evidence 'switch-profile/app-stages.log')
                    }
                    [IO.File]::WriteAllText((Join-Path $Evidence 'shape-switch.json'), ($shapeResult | ConvertTo-Json -Depth 18), (New-Object Text.UTF8Encoding($false)))
                    $gapCase.phase = 'verdict'
                    $baseline = @()
                    if ($env:CHAT_SHAPE_BASELINE -eq '1') {
                        if ($env:RELEASE_TAG -ne 'v0.28.946') { throw 'Baseline recording requires published v0.28.946' }
                        $baseline = @('--expect-regression')
                    }
                    & $env:MP_VERIFY_PYTHON (Join-Path $PSScriptRoot '../../../tools/verify-chat-delivery/chat-switch-evidence.py') (Join-Path $Evidence 'shape-switch.json') @baseline
                    if ($LASTEXITCODE -ne 0) { throw 'Real-shape switch evidence failed; inspect shape-switch-verdict.json' }
                }
                $gapCase.phase = 'verdict'
                $summary = foreach ($mode in $modes) { "$mode median $($timings[$mode].median_ms) ms (limit $chatLimitMs), worst $($timings[$mode].max_ms) ms, worst window hang $($timings[$mode].max_hang_ms) ms (limit $hangLimitMs), switches without chat shown: $($timings[$mode].missing), first frame at wrong width: $($timings[$mode].first_frame_wrong_width), layout moved after first frame: $($timings[$mode].moved_after_first_frame)" }
                $gapCase.detail = $summary -join '; '
                foreach ($mode in $modes) {
                    if ($timings[$mode].missing -gt 0 -or $timings[$mode].first_frame_wrong_width -gt 0 -or $timings[$mode].moved_after_first_frame -gt 0) { throw $gapCase.detail }
                    Assert-ReleaseTiming 'chat-switch' $timings[$mode].median_ms $mode
                    Assert-ReleaseTiming 'chat-window-response' $timings[$mode].max_hang_ms $mode
                    Assert-ReleaseTiming 'ui-hang' $timings[$mode].max_hang_ms $mode
                    Assert-ReleaseTiming 'ui-hang' $timings[$mode].max_ms ($mode + ' longest switch')
                }
                Snapshot 'after'
                $gapCase.status = 'passed'
            } catch {
                $gapCase.detail = $gapCase.phase + ': ' + $_.Exception.Message
                throw
            } finally {
                if ($probeStarted) { [VerifyNative]::StopHangProbe() }
                Save-Json $timings 'switch-timings.json'
                if ($shapeProof -and $null -ne $shapeResult) {
                    if ($gapCase.status -ne 'passed' -and $gapCase.phase -ne 'verdict') { $shapeResult.errors += $gapCase.detail }
                    [IO.File]::WriteAllText((Join-Path $Evidence 'shape-switch.json'), ($shapeResult | ConvertTo-Json -Depth 18), (New-Object Text.UTF8Encoding($false)))
                }
                Save-Json (Read-Session) 'switch-final-session.json'
                if (Test-Path -LiteralPath $log) { Copy-Item -LiteralPath $log (Join-Path $Evidence 'chat-switch-debug.log') -ErrorAction SilentlyContinue }
            }
        