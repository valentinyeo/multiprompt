
            $launchLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
            function Read-LaunchLog { try { return Read-SharedText -Path $launchLog } catch { return '' } }
            function Capture-Window([string]$Name) {
                [void][VerifyNative]::DwmFlush()
                $rect = New-Object VerifyNative+Rect
                if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$rect)) { throw 'Window rectangle unavailable' }
                $bitmap = New-Object Drawing.Bitmap(($rect.Right - $rect.Left), ($rect.Bottom - $rect.Top))
                $graphics = [Drawing.Graphics]::FromImage($bitmap)
                $file = Join-Path $Evidence "$Name.png"
                try {
                    $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
                    $bitmap.Save($file, [Drawing.Imaging.ImageFormat]::Png)
                } finally { $graphics.Dispose(); $bitmap.Dispose() }
            }
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq 1 -and $state.tabs[0].kind -eq 'cmd' } 'one real CMD session'
            $script:browserShellId = (Read-Inbox).shells[0].sid
            $pane = Open-BrowserPane 'chat-first-paint-open'
            Press @(0x12, 0x43) 'Alt+C: open Chat View beside the docked browser pane'
            Wait-Until {
                $state = Read-Session
                $tab = $state.tabs[$state.active_tab]
                $tab.PSObject.Properties['cv'] -and $tab.cv -eq $true -and $tab.PSObject.Properties['bon'] -and $tab.bon -eq $true
            } 'Chat View and browser pane both saved by the app'
            Wait-Until { (Read-LaunchLog) -match '\[chat\] composer card' } 'Chat View painted its composer card'
            Start-Sleep -Seconds 3
            Snapshot 'before-quit'
            Save-Json (Read-Session) 'session-before-quit.json'
            Doctor
            Record 'WM_CLOSE: close only the verified owned main window normally'
            if (-not $process.CloseMainWindow()) { throw 'Owned window refused WM_CLOSE' }
            if (-not $process.WaitForExit(20000)) { throw 'chat-first-paint launch 1 did not exit' }
            $stopped = $job.Stop()
            Save-Json @{ pid = $process.Id; activeAfterStop = $stopped.ActiveProcesses } 'launch-1-exit.json'
            $process.Dispose()
            $job.Dispose()
            $script:process = $null
            $script:job = $null
            $script:window = [IntPtr]::Zero
            $snapshotFiles = @(Get-ChildItem -LiteralPath (Join-Path $scratch 'roaming/ZigShell') -Filter '*.launch.json')
            if ($snapshotFiles.Count -ne 1) { throw "chat-first-paint seed invalid: expected one app-written launch snapshot, found $($snapshotFiles.Count)" }
            $snapshot = Get-Content -LiteralPath $snapshotFiles[0].FullName -Raw | ConvertFrom-Json
            if (-not $snapshot.chat) { throw 'chat-first-paint seed invalid: the launch snapshot did not record an open Chat View' }
            $snapshotRow = @($snapshot.rows | Where-Object { $_.id -eq $snapshot.active })[0]
            $snapshotBrowser = $snapshotRow.PSObject.Properties['browser'] -and $snapshotRow.browser -eq $true
            Save-Json @{ chat = $snapshot.chat; rows = @($snapshot.rows).Count; carriesBrowserPane = $snapshotBrowser; browserSplit = $(if ($snapshotRow.PSObject.Properties['browser_split']) { $snapshotRow.browser_split } else { $null }) } 'launch-snapshot-summary.json'
            $logOffset = (Read-LaunchLog).Length
            $script:job = New-Object VerifyJob
            $script:process = $job.Start($Exe, $scratch, (Join-Path $Evidence 'launch-2.stdout.log'), (Join-Path $Evidence 'launch-2.stderr.log'), '--single-window')
            $firstPaint = $false
            $deadline = [DateTime]::UtcNow.AddSeconds(60)
            while ([DateTime]::UtcNow -lt $deadline) {
                $process.Refresh()
                if ($process.MainWindowHandle -ne [IntPtr]::Zero) { $script:window = $process.MainWindowHandle }
                $all = Read-LaunchLog
                $trace = if ($all.Length -ge $logOffset) { $all.Substring($logOffset) } else { $all }
                if ($script:window -ne [IntPtr]::Zero -and $trace -match 'launch first-paint ms=') {
                    Capture-Window 'first-paint'
                    $firstPaint = $true
                    break
                }
                Start-Sleep -Milliseconds 10
            }
            if (-not $firstPaint) { throw 'chat-first-paint launch 2 never logged its first paint' }
            Wait-Until {
                $all = Read-LaunchLog
                $trace = if ($all.Length -ge $logOffset) { $all.Substring($logOffset) } else { $all }
                $trace -match 'launch step=browser'
            } 'launch 2 finished restoring sessions and browser panes' 60
            Start-Sleep -Seconds 6
            Capture-Window 'settled'
            $all = Read-LaunchLog
            $trace = if ($all.Length -ge $logOffset) { $all.Substring($logOffset) } else { $all }
            $trace | Out-File -LiteralPath (Join-Path $Evidence 'launch-2.debug.log') -Encoding utf8
            $client = ''
            $events = @()
            foreach ($line in ($trace -split "`n")) {
                if ($line -match '\[reposition\] client=(\d+x\d+)') { $client = $Matches[1]; continue }
                if ($line -match '\[chat\] frame transcript (-?\d+,-?\d+,-?\d+,-?\d+) edit (-?\d+,-?\d+,-?\d+,-?\d+) card (-?\d+,-?\d+,-?\d+,-?\d+)') {
                    $events += [pscustomobject]@{ client = $client; kind = 'transcript'; rect = $Matches[1]; line = $line.Trim() }
                    $events += [pscustomobject]@{ client = $client; kind = 'message box'; rect = $Matches[2]; line = $line.Trim() }
                    $events += [pscustomobject]@{ client = $client; kind = 'composer card'; rect = $Matches[3]; line = $line.Trim() }
                    continue
                }
                if ($line -match '\[chat\] composer card (-?\d+,-?\d+,-?\d+,-?\d+) size=') {
                    $events += [pscustomobject]@{ client = $client; kind = 'composer card'; rect = $Matches[1]; line = $line.Trim() }
                }
            }
            Save-Json @($events) 'chat-layout-events.json'
            foreach ($kind in 'transcript', 'message box', 'composer card') {
                if (@($events | Where-Object { $_.kind -eq $kind }).Count -eq 0) { throw "chat-first-paint: launch 2 never logged a $kind rectangle" }
            }
            $moved = @()
            foreach ($client in @($events | Select-Object -ExpandProperty client -Unique)) {
                foreach ($kind in 'transcript', 'message box', 'composer card') {
                    $rects = @($events | Where-Object { $_.client -eq $client -and $_.kind -eq $kind } | Select-Object -ExpandProperty rect -Unique)
                    if ($rects.Count -gt 1) { $moved += "$kind at window $client moved between $($rects -join ' and ')" }
                }
            }
            Save-Json @{ snapshotCarriesBrowserPane = $snapshotBrowser; moved = $moved; eventCount = $events.Count } 'chat-first-paint-verdict.json'
            if ($moved.Count -gt 0) { throw "chat-first-paint: chat layout moved after first paint: $($moved -join '; ')" }
            $result.checks += @{ name = 'chat-first-paint'; events = $events.Count; moved = 0; snapshotCarriesBrowserPane = $snapshotBrowser }
            Snapshot 'action'
            Snapshot 'after'
        