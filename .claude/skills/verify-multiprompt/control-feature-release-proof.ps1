$result.seedBoundary = 'Two isolated saved tmux tabs seeded once before launch. Only SSH, tmux and agent transport are stand-ins. No account credentials, real server or paid agent are used.'
$result.releaseProof = @{
    soft3039 = 'Real saved server tabs, normal quit, real relaunch and real native terminal input'
    soft3046 = 'Real MPTerminal caret pixels in the focused console, before and after a session switch'
}

function Save-ReleaseCheck([string]$Name, [hashtable]$Values) {
    $check = [ordered]@{ name = $Name }
    foreach ($key in $Values.Keys) { $check[$key] = $Values[$key] }
    $result.checks += $check
}

function Find-ConsoleWindow {
    Wait-Until {
        $candidate = [IntPtr]::Zero
        foreach ($pane in [VerifyNative]::OwnedPaneWindows($script:window)) {
            $found = [VerifyNative]::FindWindowEx($pane, [IntPtr]::Zero, 'MPTerminal', $null)
            if ($found -ne [IntPtr]::Zero -and [VerifyNative]::IsWindowVisible($pane)) { $candidate = $found; break }
        }
        if ($candidate -eq [IntPtr]::Zero) { $candidate = [VerifyNative]::FindWindowEx($script:window, [IntPtr]::Zero, 'MPTerminal', $null) }
        if ($candidate -eq [IntPtr]::Zero) { $candidate = [VerifyNative]::FirstVisibleChild($script:window, 'MPTerminal') }
        if ($candidate -eq [IntPtr]::Zero) {
            foreach ($entry in [VerifyNative]::DesktopWindows()) {
                if ([int]$entry.pid -eq $process.Id -and $entry.class -ceq 'MPTerminal' -and $entry.visible) { $candidate = [IntPtr][long]$entry.handle; break }
            }
        }
        $candidate -ne [IntPtr]::Zero
    } 'hosted native terminal window' 60
    return $candidate
}

function Focus-Console([string]$Step) {
    $shell = Find-ConsoleWindow
    $client = New-Object VerifyNative+Rect
    Wait-Until {
        [void][VerifyNative]::GetClientRect($shell, [ref]$client)
        $client.Right -gt 0 -and $client.Bottom -gt 0
    } 'native terminal client area' 30
    [VerifyNative]::ClickClient($shell, [int]($client.Right / 2), [int]($client.Bottom - 40))
    Wait-Until { [VerifyNative]::GetFocusedWindow([VerifyNative]::GetAncestor($shell, 2)) -eq $shell -or [VerifyNative]::GetFocusedWindow($script:window) -eq $shell } ('native terminal holds keyboard focus: ' + $Step) 30
    return $shell
}

function Get-CaretFrame([IntPtr]$Caret, [int]$X, [int]$Y, [int]$Width, [int]$Height) {
    $bitmap = New-Object Drawing.Bitmap($Width, $Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($X, $Y, 0, 0, $bitmap.Size)
        $signature = 0
        for ($py = 0; $py -lt $Height; $py++) {
            for ($px = 0; $px -lt $Width; $px++) { $signature = ($signature * 31 + $bitmap.GetPixel($px, $py).ToArgb()) -band 0x7FFFFFFF }
        }
        return @{ Bitmap = $bitmap; Signature = $signature }
    } finally {
        $graphics.Dispose()
    }
}

function Save-CaretStrip([string]$Name, [string[]]$Frames, [int]$Scale = 6) {
    if ($Frames.Count -eq 0) { return }
    $first = [Drawing.Bitmap]::new($Frames[0])
    try {
        $cellWidth = $first.Width
        $cellHeight = $first.Height
    } finally { $first.Dispose() }
    $gap = 4
    $strip = New-Object Drawing.Bitmap(($cellWidth * $Scale + $gap) * $Frames.Count, $cellHeight * $Scale)
    $graphics = [Drawing.Graphics]::FromImage($strip)
    try {
        $graphics.Clear([Drawing.Color]::FromArgb(24, 24, 24))
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::Half
        for ($index = 0; $index -lt $Frames.Count; $index++) {
            $frame = [Drawing.Bitmap]::new($Frames[$index])
            try {
                $graphics.DrawImage($frame, ($cellWidth * $Scale + $gap) * $index, 0, $cellWidth * $Scale, $cellHeight * $Scale)
            } finally { $frame.Dispose() }
        }
        $strip.Save((Join-Path $Evidence ($Name + '.png')), [Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $strip.Dispose()
    }
}

function Measure-CaretBlink([string]$Label) {
    $shell = Focus-Console $Label
    $snapshot = $null
    Wait-Until {
        $candidate = [VerifyNative]::GuiCaretSnapshot($shell)
        if ($candidate.Caret -eq [IntPtr]::Zero -or $candidate.CaretRect.Right -le $candidate.CaretRect.Left -or $candidate.CaretRect.Bottom -le $candidate.CaretRect.Top) {
            $candidate = [VerifyNative]::GuiCaretSnapshot($script:window)
        }
        if ($candidate.Caret -eq [IntPtr]::Zero -or $candidate.CaretRect.Right -le $candidate.CaretRect.Left -or $candidate.CaretRect.Bottom -le $candidate.CaretRect.Top) { return $false }
        $script:caretCandidate = $candidate
        return $true
    } ("visible console caret: " + $Label) 20
    $snapshot = $script:caretCandidate
    $script:caretCandidate = $null
    $origin = New-Object VerifyNative+Point
    $origin.X = $snapshot.CaretRect.Left
    $origin.Y = $snapshot.CaretRect.Top
    if (-not [VerifyNative]::ClientToScreen($snapshot.Caret, [ref]$origin)) { throw "session-caret: cannot map the $Label caret to the screen" }
    $width = [Math]::Max(6, $snapshot.CaretRect.Right - $snapshot.CaretRect.Left) + 10
    $height = [Math]::Max(8, $snapshot.CaretRect.Bottom - $snapshot.CaretRect.Top) + 8
    $left = $origin.X - 5
    $top = $origin.Y - 4
    $frameDir = Join-Path $Evidence ('caret-frames-' + $Label)
    New-Item -ItemType Directory -Force $frameDir | Out-Null
    $frames = @()
    $signatures = @()
    $budget = [Diagnostics.Stopwatch]::StartNew()
    for ($index = 0; $index -lt 50; $index++) {
        $due = $index * 100
        while ($budget.ElapsedMilliseconds -lt $due) { Start-Sleep -Milliseconds 5 }
        $frame = Get-CaretFrame $snapshot.Caret $left $top $width $height
        $path = Join-Path $frameDir ('frame-{0:D2}.png' -f $index)
        try { $frame.Bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Png) } finally { $frame.Bitmap.Dispose() }
        $frames += $path
        $signatures += $frame.Signature
    }
    $budget.Stop()
    $transitions = @()
    $lastChange = 0
    for ($index = 1; $index -lt $signatures.Count; $index++) {
        if ($signatures[$index] -ne $signatures[$index - 1]) { $transitions += ($index * 100); $lastChange = $index * 100 }
    }
    $stripFrames = @($frames | Where-Object { ([int]([IO.Path]::GetFileNameWithoutExtension($_) -replace 'frame-', '')) % 5 -eq 0 })
    Save-CaretStrip ('caret-strip-' + $Label) $stripFrames
    Save-Json @{ label = $Label; frames = $frames.Count; elapsedMs = $budget.ElapsedMilliseconds; caret = $snapshot.Caret.ToInt64(); rect = @{ left = $snapshot.CaretRect.Left; top = $snapshot.CaretRect.Top; right = $snapshot.CaretRect.Right; bottom = $snapshot.CaretRect.Bottom }; width = $width; height = $height; transitions = $transitions.Count; transitionMs = $transitions; lastChangeMs = $lastChange; strip = ('caret-strip-' + $Label + '.png') } ('caret-' + $Label + '.json')
    if ($transitions.Count -lt 3 -or $lastChange -lt 2500) { throw "session-caret: caret did not keep blinking across the 5 second $Label sample" }
    return @{ label = $Label; transitions = $transitions.Count; lastChangeMs = $lastChange; strip = ('caret-strip-' + $Label + '.png'); frames = $frames.Count }
}

Press @(0x11, 0x31) 'Ctrl+1: select the first server shell tab'
Wait-Until {
    $saved = Read-Session
    $null -ne $saved -and $saved.tabs[$saved.active_tab].tmux_session -ceq 'verify-agent-1'
} 'first server shell tab selected'
$shell = Focus-Console 'caret-before-switch'
Save-Json @([VerifyNative]::OwnedPaneWindows($script:window) | ForEach-Object { [VerifyNative]::WindowIdentity($_) }) 'console-panes.json'
Save-Json ([VerifyNative]::WindowIdentity($shell)) 'console-terminal.json'
Snapshot 'caret-console-focused'
$beforeCaret = Measure-CaretBlink 'console-before-switch'
Press @(0x11, 0x32) 'Ctrl+2: switch to the other session'
Wait-Until {
    $saved = Read-Session
    $null -ne $saved -and $saved.tabs[$saved.active_tab].tmux_session -ceq 'live-slash'
} 'second session selected before returning'
Press @(0x11, 0x31) 'Ctrl+1: switch back to the caret session'
Wait-Until {
    $saved = Read-Session
    $null -ne $saved -and $saved.tabs[$saved.active_tab].tmux_session -ceq 'verify-agent-1'
} 'caret session selected again'
$afterCaret = Measure-CaretBlink 'console-after-switch'
Snapshot 'caret-after-switch'
Save-ReleaseCheck 'SOFT-3046' @{ passed = $true; sessions = 2; sampleFps = 10; sampleSeconds = 5; beforeSwitchTransitions = $beforeCaret.transitions; afterSwitchTransitions = $afterCaret.transitions; beforeStrip = $beforeCaret.strip; afterStrip = $afterCaret.strip }

function Get-RemoteTransports {
    $files = @(Get-ChildItem (Join-Path $remoteState 'transport-*.txt') -ErrorAction SilentlyContinue)
    $live = @{}
    foreach ($file in $files) {
        $transportPid = [int]($file.BaseName -replace '^transport-', '')
        $session = (Get-Content $file.FullName -Raw).Trim()
        $remoteProcess = Get-Process -Id $transportPid -ErrorAction SilentlyContinue
        if ($null -eq $remoteProcess) { continue }
        $live[$session] = $transportPid
    }
    return $live
}

Wait-Until {
    $live = Get-RemoteTransports
    @($live.Keys | Where-Object { $_ -ceq 'verify-agent-1' }).Count -eq 1 -and
        @($live.Keys | Where-Object { $_ -ceq 'soft3039-two' }).Count -eq 1
} 'both plain server shells attached to their saved sessions before restart' 60
$preRestartTransports = Get-RemoteTransports
Save-Json @{ step = 'before-restart'; verifyAgent1 = $preRestartTransports['verify-agent-1']; soft3039Two = $preRestartTransports['soft3039-two'] } 'server-shell-transports-before.json'
Press @(0x11, 0x31) 'Ctrl+1: first server shell selected before quitting'
Snapshot 'server-shell-before-restart'
$shellState = [ordered]@{ name = 'server-shell-input'; fake = $false; mode = 'idle'; suggestion = ''; box = ''; queue = @(); sessions = @('verify-agent-1', 'live-slash', 'soft3039-two') }
[IO.File]::WriteAllText((Join-Path $remoteState 'state.json'), (ConvertTo-Json -InputObject $shellState -Depth 5), (New-Object Text.UTF8Encoding($false)))
Remove-Item (Join-Path $remoteState 'interrupt.json') -ErrorAction SilentlyContinue
Restart-SessionRestore 'server-shell-restart' $false
Wait-Until {
    $state = Read-Session
    $null -ne $state -and @($state.tabs).Count -ge 2 -and
        @($state.tabs | Where-Object { $_.tmux_session -ceq 'verify-agent-1' }).Count -eq 1 -and
        @($state.tabs | Where-Object { $_.tmux_session -ceq 'soft3039-two' }).Count -eq 1
} 'both saved plain server shell tabs restored after restart' 60
Wait-Until {
    $live = Get-RemoteTransports
    @($live.Keys | Where-Object { $_ -ceq 'verify-agent-1' }).Count -eq 1 -and @($live.Keys | Where-Object { $_ -ceq 'soft3039-two' }).Count -eq 1
} 'both restored server shells attached to their saved sessions after restart' 90
$postRestartTransports = Get-RemoteTransports
if ($postRestartTransports['verify-agent-1'] -eq $preRestartTransports['verify-agent-1'] -or $postRestartTransports['soft3039-two'] -eq $preRestartTransports['soft3039-two']) { throw 'Restored server shells reused the pre-restart transports' }
Save-Json @{ step = 'after-restart'; verifyAgent1 = $postRestartTransports['verify-agent-1']; soft3039Two = $postRestartTransports['soft3039-two'] } 'server-shell-transports-after.json'
$interruptFile = Join-Path $remoteState 'interrupt.json'
$inputs = @()
foreach ($index in 1, 3) {
    $selectKeys = if ($index -eq 1) { @(0x11, 0x31) } else { @(0x11, 0x33) }
    Press $selectKeys ("Ctrl+$index" + ': select a restored server shell')
    $session = if ($index -eq 1) { 'verify-agent-1' } else { 'soft3039-two' }
    Wait-Until {
        $state = Read-Session
        $null -ne $state -and $state.tabs[$state.active_tab].tmux_session -ceq $session
    } ('restored server shell selected: ' + $session)
    $shell = Focus-Console ('restored-' + $session)
    $beforeInterrupt = if (Test-Path $interruptFile) { (Get-Item $interruptFile).LastWriteTimeUtc.Ticks } else { 0 }
    Press @(0x11, 0x43) ('Ctrl+C: send input to the restored ' + $session + ' transport')
    Wait-Until {
        (Test-Path $interruptFile) -and (Get-Item $interruptFile).LastWriteTimeUtc.Ticks -gt $beforeInterrupt
    } ('restored ' + $session + ' accepted keyboard input') 20
    $inputs += @{ session = $session; transport = (Get-RemoteTransports)[$session]; inputReceipt = 'interrupt.json' }
    Snapshot ('server-shell-input-' + $session)
}
Snapshot 'server-shell-after-restart'
Save-Json @($inputs) 'server-shell-input.json'
Save-ReleaseCheck 'SOFT-3039' @{ passed = $true; tabs = 2; beforeRestart = 'server-shell-transports-before.json'; afterRestart = 'server-shell-transports-after.json'; inputs = $inputs.Count; screenshot = 'server-shell-after-restart.png' }
Snapshot 'after'
