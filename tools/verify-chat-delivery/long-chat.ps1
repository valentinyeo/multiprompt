$sourceBytes = (Get-Item $transcript).Length
if ($sourceBytes -le 18MB) { throw 'Expected a transcript over 18 MB' }
Shell-Run @('detach-console')
[void](Wait-For 'console transport disconnect observed' { (Read-Shared "$settings/debug.log").Contains('markSshTabDisconnected: preserving SSH/tmux tab') })
Press @(0x11, 0x4B) 'Ctrl+K: cover disconnected long chat'
[void](Wait-For 'palette hides native chat' { [ChatDeliveryDesktop]::Composer($main) -eq [IntPtr]::Zero })
$restore = [Diagnostics.Stopwatch]::StartNew()
Press @(0x1B) 'Esc: return to disconnected long chat'
$composer = Wait-For 'composer restored without a console' { $h = [ChatDeliveryDesktop]::Composer($main); if ($h -ne [IntPtr]::Zero) { $h } } 2
Bind-Transcript
if ($restore.ElapsedMilliseconds -gt 2000) { throw 'Long chat restoration exceeded two seconds' }
Shot 'long-chat-restored'
$duration = if ($env:RELEASE_TAG) { 1800 } else { 5 }
$watch = [Diagnostics.Stopwatch]::StartNew()
$samples = [Collections.Generic.List[object]]::new()
do {
    Doctor
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($main)
    $condition = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
    $visible = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen -and $_.Current.ProcessId -eq $app.Id })
    if ($visible.Count -ne 1 -or [ChatDeliveryDesktop]::Composer($main) -eq [IntPtr]::Zero) { throw 'Long chat became hidden' }
    $rect = $visible[0].Current.BoundingRectangle
    if ($rect.Width -lt 200 -or $rect.Height -lt 100) { throw 'Long chat has empty geometry' }
    $bitmap = [Drawing.Bitmap]::new([int]$rect.Width, [int]$rect.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $ink = 0
    try {
        $graphics.CopyFromScreen([int]$rect.Left, [int]$rect.Top, 0, 0, $bitmap.Size)
        for ($y = 8; $y -lt $bitmap.Height; $y += 8) {
            for ($x = 8; $x -lt $bitmap.Width; $x += 8) {
                $pixel = $bitmap.GetPixel($x, $y)
                if ($pixel.R -gt 140 -and $pixel.G -gt 140 -and $pixel.B -gt 140) { $ink++ }
            }
        }
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
    if ($ink -lt 8) { throw 'Long chat has no painted message text' }
    if ($samples.Count -eq 0) {
        $restore.Stop()
        if ($restore.ElapsedMilliseconds -gt 2000) { throw 'Long chat pixels restored after two seconds' }
    }
    $samples.Add(@{ms=[int]$watch.ElapsedMilliseconds; width=$rect.Width; height=$rect.Height; ink=$ink})
    if ($watch.Elapsed.TotalSeconds -lt $duration) { Start-Sleep -Seconds 1 }
} while ($watch.Elapsed.TotalSeconds -lt $duration)
Assert-FullHistory 'sustained'
Shot 'long-chat-sustained'
Save @{sourceBytes=$sourceBytes; restoreMs=[int]$restore.ElapsedMilliseconds; sustainedMs=[int]$watch.ElapsedMilliseconds; samples=$samples.ToArray()} "$caseDir/long-chat.json"
