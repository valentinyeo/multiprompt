
            $result.agentBoundary = @{ liveDeliveryVerified = $false; reason = 'A PowerShell console titled claude with an idle prompt stands in for a local coding agent; it proves how fast the sent message is drawn, not agent delivery' }
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $agentScript = Join-Path $scratch 'latency-agent.ps1'
            [IO.File]::WriteAllLines($agentScript, [string[]]@("function prompt { [string][char]0x276F + ' ' }", "`$Host.UI.RawUI.WindowTitle = 'claude agent'"))
            Type-Text ('powershell -NoLogo -NoProfile -NoExit -ExecutionPolicy Bypass -File "' + $agentScript + '"')
            Press @(0x0D) 'Enter: start the stand-in coding agent prompt'
            Wait-Until {
                $foreground = [VerifyNative]::GetForegroundWindow()
                if ([VerifyNative]::GetAncestor($foreground, 2) -ne $script:window -or [VerifyNative]::Class($foreground) -ne 'ConsoleWindowClass') { return $false }
                $console = [System.Windows.Automation.AutomationElement]::FromHandle($foreground)
                $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Document)
                $document = $console.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
                if ($null -eq $document) { return $false }
                $pattern = $document.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern)
                $consoleText = $pattern.DocumentRange.GetText(-1) -replace '[\r\n]', ''
                $consoleText.TrimEnd().EndsWith([string][char]0x276F, [StringComparison]::Ordinal)
            } 'stand-in coding agent prompt is visible in the console' 60
            Snapshot 'agent-prompt'
            Press @(0x12, 0x43) 'Alt+C: enable Chat View for the isolated CMD session'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and @($state.tabs).Count -eq 1 -and $state.tabs[0].cv -and
                    -not ($state.tabs[0].PSObject.Properties['bon'] -and $state.tabs[0].bon)
            } 'one saved Chat View session without a browser pane'
            Wait-ChatFocus 'Edit' 'send-latency-ready'
            $composer = [System.Windows.Automation.AutomationElement]::FocusedElement
            $handle = [IntPtr]$composer.Current.NativeWindowHandle
            if ($composer.Current.ProcessId -ne $process.Id -or [VerifyNative]::Class($handle) -cne 'Edit' -or
                [VerifyNative]::GetAncestor($handle, 2) -ne $script:window) { throw 'Expected the owned composer Edit before the send loop' }
            $pattern = 'send-latency id=(\d+) enqueue_us=(\d+) painted_us=(\d+)'
            $samples = @()
            for ($n = 1; $n -le 20; $n++) {
                $text = "latency probe $n"
                $logText = Read-SharedText $log; $before = ([regex]::Matches($logText, $pattern)).Count
                Type-Text $text
                Wait-Until { [VerifyNative]::EditText($handle) -ceq $text } "send $n typed"
                if ($n -eq 1) { Snapshot 'action' }
                Press @(0x0D) "Enter: send message $n"
                Wait-Until { $current = Read-SharedText $log; ([regex]::Matches($current, $pattern)).Count -gt $before } "send $n bubble painted" 10 50
                Wait-Until { [VerifyNative]::EditText($handle) -ceq '' } "send $n composer cleared" 10 50
                Start-Sleep -Milliseconds 1500
            }
            $finalText = Read-SharedText $log; $timed = [regex]::Matches($finalText, $pattern)
            $samples = @($timed | ForEach-Object { @{ id = [uint64]$_.Groups[1].Value; enqueueMs = [math]::Round([int64]$_.Groups[2].Value / 1000.0, 2); paintedMs = [math]::Round([int64]$_.Groups[3].Value / 1000.0, 2) } })
            if ($samples.Count -ne 20) { throw "chat-send-latency: expected 20 timed sends, found $($samples.Count)" }
            $painted = @($samples | ForEach-Object { $_.paintedMs } | Sort-Object)
            $summary = @{ budgetMs = 100; count = $samples.Count; medianMs = $painted[10]; maxMs = $painted[-1]; samples = $samples }
            Save-Json $summary 'chat-send-latency.json'
            Snapshot 'after'
            $late = @($samples | Where-Object { $_.paintedMs -gt 100 })
            $result.checks += @{ name = 'chat-send-latency'; budgetMs = 100; count = $samples.Count; medianMs = $summary.medianMs; maxMs = $summary.maxMs; over = $late.Count }
            foreach ($sample in $samples) { Assert-ReleaseTiming 'chat-send-paint' $sample.paintedMs ('send ' + $sample.id) }
        