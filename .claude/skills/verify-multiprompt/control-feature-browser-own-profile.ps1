
            if ((Get-OwnProfileToken 'ws-own-test') -cne 'own-adee37bbc9fa6013ec24ccfd') { throw 'Journey token derivation differs from the app test vector' }
            Wait-Until { (Get-Content (Join-Path $scratch 'roaming/ZigShell/debug.log') -Raw) -match 'launch step=browser' } 'initial restore finished before keyboard input' 60
            $sharedRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'ZigShell/ChromeUserData')).TrimEnd('\')
            $ownBase = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'ZigShell/BrowserWorkspaces')).TrimEnd('\')
            $optIn = Join-Path $env:APPDATA 'ZigShell/browser-own-profile.txt'
            if ((Test-Path -LiteralPath $ownBase) -or (Test-Path -LiteralPath $optIn)) { throw 'Own browser profile state existed before the journey' }
            $warmupJob = New-Object VerifyJob
            $arguments = '--user-data-dir="' + $sharedRoot + '" --profile-directory=Default --no-first-run --no-default-browser-check --disable-notifications --disable-background-mode --load-extension="' + $extension + '" --disable-extensions-except="' + $extension + '" --silent-debugger-extension-api --app="data:text/html,<title>Multiprompt verification browser ready</title>"'
            $warmup = $warmupJob.Start($chrome, $scratch, (Join-Path $Evidence 'browser-setup.stdout.log'), (Join-Path $Evidence 'browser-setup.stderr.log'), $arguments)
            Wait-Until {
                $warmup.Refresh()
                if ($warmup.HasExited) { throw 'Browser setup process exited before readiness' }
                $warmup.MainWindowHandle -ne [IntPtr]::Zero -and $warmup.MainWindowTitle -match '^Multiprompt verification browser ready'
            } 'shared browser profile rendered setup page' 60
            Wait-SwitchNativeHost
            [void][VerifyNative]::ShowWindow($warmup.MainWindowHandle, 0)
            $warmupStopped = $warmupJob.Stop()
            Save-Json @{ activeAfterStop = $warmupStopped.ActiveProcesses } 'browser-setup-process-tree.json'
            $warmupJob.Dispose()
            $warmupJob = $null
            Wait-Until {
                [void][VerifyNative]::SetForegroundWindow($script:window)
                [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window
            } 'main window foreground after shared browser setup'
            $script:browserShellId = (Read-Inbox).active_shell_id
            $sharedProof = Open-WorkspaceBrowser 'shared'
            if ($sharedProof.userDataDir -ine $sharedRoot) { throw 'Workspace without opt-in left the shared browser profile' }
            Wait-Until { $pane = Read-BrowserPane; $null -ne $pane -and $pane.browser_window_id -gt 0 } 'shared pane bound through the shared native host' 60
            $sharedBefore = Get-SharedProfileListing $sharedRoot
            $coreBefore = Get-SharedProfileCore $sharedRoot
            if ('Default' -notin $coreBefore -or 'Local State' -notin $coreBefore) { throw 'Shared browser profile was not warmed' }
            $before = (Read-Session).workspace_count
            Press @(0x11, 0x4E) 'Ctrl+N: create the workspace that gets its own browser profile'
            Wait-Until { $script:ownSession = Read-Session; $null -ne $script:ownSession -and $script:ownSession.workspace_count -eq $before + 1 -and $script:ownSession.active_workspace -ne 0 } 'new workspace persisted'
            $ownWorkspace = $script:ownSession.active_workspace
            $ownWorkspaceId = $script:ownSession.workspaces[$ownWorkspace].wid
            $ownWorkspaceName = 'Own profile 989'
            if ($ownWorkspaceName -ceq $script:ownSession.workspaces[0].name) { throw 'Expected a distinct workspace name' }
            if ([string]::IsNullOrWhiteSpace($ownWorkspaceId) -or $ownWorkspaceId -ceq $script:ownSession.workspaces[0].wid) { throw 'Expected a distinct workspace identity' }
            $ownToken = Get-OwnProfileToken $ownWorkspaceId
            $ownRoot = [IO.Path]::GetFullPath((Join-Path $ownBase ('chrome/' + $ownToken))).TrimEnd('\')
            if (Test-Path -LiteralPath $ownBase) { throw 'Own browser profile folder appeared before opt-in' }
            Record 'Opt the new workspace into its own browser profile with browser-own-profile.txt'
            [IO.File]::WriteAllText($optIn, $ownWorkspaceId + "`n")
            Wait-Until {
                $state = Read-Inbox
                $selected = @($state.shells | Where-Object { $_.sid -eq $state.active_shell_id })
                $selected.Count -eq 1 -and $selected[0].ws -eq $ownWorkspace
            } 'new workspace CMD selected'
            $script:browserShellId = (Read-Inbox).active_shell_id
            Snapshot 'action'
            $ownProof = Open-WorkspaceBrowser 'opted-in'
            if ($ownProof.userDataDir -ine $ownRoot) { throw ('Opted-in workspace has no own browser profile: ' + $ownProof.userDataDir) }
            if ($ownProof.pid -eq $sharedProof.pid) { throw 'Opted-in pane reused the shared browser process' }
            Wait-OwnProfilePipe $ownToken 'opted-in'
            Wait-Until { $pane = Read-BrowserPane; $null -ne $pane -and $pane.browser_window_id -gt 0 } 'opted-in pane bound through its own native host' 60
            if ($null -eq (Get-Process -Id $sharedProof.pid -ErrorAction SilentlyContinue)) { throw 'Shared browser closed when the opted-in pane opened' }
            $sharedAfter = Get-SharedProfileListing $sharedRoot
            $coreAfter = Get-SharedProfileCore $sharedRoot
            $missing = @($coreBefore | Where-Object { $_ -notin $coreAfter })
            $foreign = @($sharedAfter | Where-Object { $_ -match '(?i)own-[0-9a-f]{24}|BrowserWorkspaces|workspace-owner' })
            if ($missing.Count -ne 0 -or $foreign.Count -ne 0) { throw ('Shared browser profile changed: missing ' + ($missing -join ', ') + '; foreign ' + ($foreign -join ', ')) }
            $engines = @(Get-ChildItem -LiteralPath $ownBase -Force | ForEach-Object { $_.Name })
            $leaves = @(Get-ChildItem -LiteralPath (Join-Path $ownBase 'chrome') -Force | ForEach-Object { $_.Name })
            if ($engines.Count -ne 1 -or $engines[0] -cne 'chrome' -or $leaves.Count -ne 1 -or $leaves[0] -cne $ownToken) { throw 'Own browser profile folder is not exactly one own-<hash> leaf' }
            Press @(0x12, 0x32) 'Alt+2: switch to stored workspace 0'
            $null = Assert-WorkspaceBrowser 'shared-return' $sharedRoot 0
            Press @(0x12, 0x51) 'Alt+Q: focus the shared-profile browser'
            $null = Assert-WorkspaceBrowser 'shared-altq' $sharedRoot 0
            Send-ProfileScreenshot 'shared' '' 1
            Press @(0x12, (0x32 + $ownWorkspace)) ("Alt+" + (2 + $ownWorkspace) + ": switch to stored workspace " + $ownWorkspace)
            $null = Assert-WorkspaceBrowser 'own-return' $ownRoot $ownWorkspace
            Press @(0x12, 0x51) 'Alt+Q: focus the own-profile browser'
            $null = Assert-WorkspaceBrowser 'own-altq' $ownRoot $ownWorkspace
            Send-ProfileScreenshot 'own' $ownToken 2
            Restart-SessionRestore 'own-profile-restart' $false $false {
                Record 'Regenerate the opted-in workspace id in session.json and key the opt-in by workspace name, as after an account layout sync'
                $sessionPath = Join-Path $scratch 'roaming/ZigShell/session.json'
                $sessionText = [IO.File]::ReadAllText($sessionPath)
                $idPattern = '"name":"[^"]*","wid":"' + [regex]::Escape($ownWorkspaceId) + '"'
                if (-not [regex]::IsMatch($sessionText, $idPattern)) { throw 'Opted-in workspace id missing from session.json before regeneration' }
                [IO.File]::WriteAllText($sessionPath, [regex]::Replace($sessionText, $idPattern, ('"name":"' + $ownWorkspaceName + '","wid":"ws-regenerated-989"')))
                [IO.File]::WriteAllText($optIn, $ownWorkspaceName + '=' + $ownWorkspaceId + "`n")
            }
            Wait-Until {
                $state = Read-Inbox
                $selected = @($state.shells | Where-Object { $_.sid -eq $state.active_shell_id })
                $selected.Count -eq 1 -and $selected[0].ws -eq $ownWorkspace
            } 'restored selection is the opted-in workspace'
            $regenerated = (Read-Session).workspaces[$ownWorkspace].wid
            if ($regenerated -cne 'ws-regenerated-989') { throw ('Workspace id did not stay regenerated: ' + $regenerated) }
            $script:browserShellId = (Read-Inbox).active_shell_id
            Wait-Until {
                $pane = Read-BrowserPane
                $null -ne $pane -and $pane.browser_state -eq 'connected' -and [VerifyNative]::DockedPaneWindow($script:window) -ne [IntPtr]::Zero
            } 'restored opted-in pane docked without an open command' 90
            $restoredProof = Get-PaneUserDataDir ([VerifyNative]::DockedPaneWindow($script:window))
            if ($restoredProof.userDataDir -ine $ownRoot) { throw ('Restored opted-in workspace lost its own browser profile after its workspace id changed: ' + $restoredProof.userDataDir) }
            Wait-OwnProfilePipe $ownToken 'restored'
            Wait-Until { $pane = Read-BrowserPane; $null -ne $pane -and $pane.browser_window_id -gt 0 } 'restored opted-in pane bound through its own native host' 60
            Press @(0x12, 0x32) 'Alt+2: switch to stored workspace 0'
            $null = Assert-WorkspaceBrowser 'shared-restored-return' $sharedRoot 0
            Press @(0x12, (0x32 + $ownWorkspace)) ("Alt+" + (2 + $ownWorkspace) + ": switch to stored workspace " + $ownWorkspace)
            $null = Assert-WorkspaceBrowser 'own-restored-return' $ownRoot $ownWorkspace
            Save-Json @{ token = $ownToken; workspaceId = $ownWorkspaceId; ownRoot = $ownRoot; sharedRoot = $sharedRoot; shared = $sharedProof; opted = $ownProof; restored = $restoredProof; sharedBefore = $sharedBefore; sharedAfter = $sharedAfter; coreBefore = $coreBefore; coreAfter = $coreAfter } 'browser-own-profile.json'
            $result.checks += @{ name = 'browser-own-profile shared'; userDataDir = $sharedProof.userDataDir }
            $result.checks += @{ name = 'browser-own-profile opted-in'; userDataDir = $ownProof.userDataDir; token = $ownToken }
            $result.checks += @{ name = 'browser-own-profile shared-untouched'; entries = $sharedAfter.Count }
            $result.checks += @{ name = 'browser-own-profile restored'; userDataDir = $restoredProof.userDataDir }
            $stableChrome = @(
                (Join-Path $env:ProgramFiles 'Google/Chrome/Application/chrome.exe'),
                (Join-Path ${env:ProgramFiles(x86)} 'Google/Chrome/Application/chrome.exe')
            ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
            if (-not $stableChrome) { throw 'Branded Chrome stable is required for own-profile verification' }
            $stableVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($stableChrome)
            if ($stableVersion.ProductName -cne 'Google Chrome' -or $stableVersion.ProductMajorPart -lt 137) { throw 'Own-profile regression requires branded Google Chrome 137 or newer' }
            Record 'Switch the app to branded Chrome stable; Chrome for Testing cannot prove the extension bootstrap regression'
            [IO.File]::WriteAllText((Join-Path $config 'chrome-exe.txt'), $stableChrome)
            Press @(0x12, 0x32) 'Alt+2: keep the own workspace inactive during stable warm-up'
            $null = Assert-WorkspaceBrowser 'shared-stable-warmup' $sharedRoot 0
            $existingOwn = Get-Process -Id $restoredProof.pid
            & taskkill.exe /PID $existingOwn.Id /T /F
            if (-not $existingOwn.WaitForExit(10000)) { throw 'Existing own-profile browser did not exit before stable warm-up' }
            $existingOwn.Dispose()
            $stableWarmupLog = Join-Path $config 'bridge-launch.log'
            $stableWarmupLogStart = if (Test-Path -LiteralPath $stableWarmupLog) { @(Get-Content -LiteralPath $stableWarmupLog).Count } else { 0 }
            $stableWarmupClock = [Diagnostics.Stopwatch]::StartNew()
            $stableWarmup = Start-Process -FilePath (Join-Path (Split-Path $Exe) 'zigshell-bridge.exe') -ArgumentList ('chrome-launch "' + $stableChrome + '" "' + $extension + '" "' + (Join-Path $extension 'themes/dark') + '" "--user-data-dir=' + $ownRoot + '" "--no-first-run" "--no-default-browser-check" "--new-window" "data:text/html,<title>ZSPANE-WARM</title>"') -PassThru
            try {
                Wait-Until {
                    if ($stableWarmup.HasExited) { throw 'Stable warm-up bridge exited before loading the extension' }
                    (Test-Path -LiteralPath $stableWarmupLog) -and
                        @(Get-Content -LiteralPath $stableWarmupLog | Select-Object -Skip $stableWarmupLogStart | Where-Object { $_ -ceq 'extension loaded' }).Count -gt 0
                } 'branded Chrome own-profile warm-up loaded the extension' 60
                Wait-Until {
                    [VerifyNative]::BringToForeground($script:window)
                    [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window
                } 'main window foreground after stable warm-up'
                Press @(0x12, (0x32 + $ownWorkspace)) 'Return to the own workspace before the stable restart'
                $null = Assert-WorkspaceBrowser 'own-stable-warmup-return' $ownRoot $ownWorkspace
            } finally {
                $stableWarmupChrome = @(Get-CimInstance Win32_Process -Filter ("ParentProcessId = " + $stableWarmup.Id) | Where-Object { $_.ExecutablePath -ieq $stableChrome } | ForEach-Object { Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue })
                if (-not $stableWarmup.HasExited) {
                    & taskkill.exe /PID $stableWarmup.Id /T /F
                }
                foreach ($browser in $stableWarmupChrome) {
                    if (-not $browser.WaitForExit(10000)) { throw 'Stable warm-up Chrome did not exit' }
                    $browser.Dispose()
                }
                if (-not $stableWarmup.WaitForExit(10000)) { throw 'Stable warm-up bridge did not exit' }
                $stableWarmup.Dispose()
                $stableWarmupClock.Stop()
            }
            $result.checks += @{ name = 'browser-own-profile stable-warmup'; seconds = $stableWarmupClock.Elapsed.TotalSeconds }
            Restart-SessionRestore 'stable-chrome-switch' $false
            $null = Assert-WorkspaceBrowser 'stable-existing-own' $ownRoot $ownWorkspace
            Press @(0x11, 0x4E) 'Ctrl+N: create a cold branded Chrome workspace'
            Wait-Until {
                $script:stableSession = Read-Session
                $state = Read-Inbox
                if ($null -eq $script:stableSession -or $null -eq $state) { return $false }
                $selected = @($state.shells | Where-Object { $_.sid -eq $state.active_shell_id })
                $script:stableSession.workspace_count -eq $before + 2 -and $selected.Count -eq 1 -and
                    $selected[0].ws -eq $script:stableSession.active_workspace -and $selected[0].ws -ne $ownWorkspace
            } 'branded Chrome workspace persisted'
            $stableWorkspace = $script:stableSession.active_workspace
            $stableWorkspaceId = $script:stableSession.workspaces[$stableWorkspace].wid
            $stableToken = Get-OwnProfileToken $stableWorkspaceId
            $stableRoot = [IO.Path]::GetFullPath((Join-Path $ownBase ('chrome/' + $stableToken))).TrimEnd('\')
            if (Test-Path -LiteralPath $stableRoot) { throw 'Branded Chrome own profile must start empty' }
            [IO.File]::AppendAllText($optIn, $stableWorkspaceId + "`n")
            Wait-Until {
                [VerifyNative]::BringToForeground($script:window)
                [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window
            } 'main window foreground before the cold branded Chrome workspace browser opens'
            $script:browserShellId = (Read-Inbox).active_shell_id
            $stableProof = Open-WorkspaceBrowser 'stable-cold-own'
            if ($stableProof.userDataDir -ine $stableRoot) { throw 'Branded Chrome pane used the wrong own profile' }
            $stableProcess = Get-CimInstance Win32_Process -Filter ("ProcessId = " + $stableProof.pid)
            if ($stableProcess.ExecutablePath -ine $stableChrome) { throw 'Cold own pane is not branded Chrome stable' }
            $holder = Get-CimInstance Win32_Process -Filter ("ProcessId = " + $stableProcess.ParentProcessId)
            if ([IO.Path]::GetFileName($holder.ExecutablePath) -ine 'zigshell-bridge.exe' -or $holder.CommandLine -notmatch 'chrome-launch') { throw 'Branded Chrome has no persistent bridge pipe holder' }
            Wait-OwnProfilePipe $stableToken 'stable-cold-own'
            $stablePane = Read-BrowserPane
            if ($stablePane.browser_window_id -le 0) { throw 'Branded Chrome own pane did not resolve a window id' }
            Save-Json @{ executable = $stableChrome; product = $stableVersion.ProductName; version = $stableVersion.ProductVersion; browser = $stableProof; holderPid = $holder.ProcessId; token = $stableToken; windowId = $stablePane.browser_window_id } 'browser-own-profile-stable.json'
            Restart-SessionRestore 'stable-own-restart' $false
            Wait-OwnProfilePipe $stableToken 'stable-restored-own'
            $null = Assert-WorkspaceBrowser 'stable-restored-own' $stableRoot $stableWorkspace
            $result.checks += @{ name = 'browser-own-profile branded Chrome stable cold and restored'; executable = $stableChrome; token = $stableToken; windowId = $stablePane.browser_window_id }
            Snapshot 'after'
        