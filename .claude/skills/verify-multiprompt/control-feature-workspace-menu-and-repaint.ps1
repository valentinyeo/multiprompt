Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -Path (Join-Path $PSScriptRoot 'workspace-menu-native.cs')
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class MenuCardProof {
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
}
'@

function Test-SavedChatView($state, [int]$index) {
    if ($null -eq $state) { return $false }
    $tab = @($state.tabs)[$index]
    return [bool]($tab.PSObject.Properties['cv'] -and $tab.cv)
}

function Get-MenuCard {
    $card = [MenuCardProof]::FindWindowEx($script:window, [IntPtr]::Zero, 'MultiPromptWorkspaceSwitcher', 'Workspaces')
    if ($card -ne [IntPtr]::Zero -and [VerifyNative]::IsWindowVisible($card)) { return $card }
    return [IntPtr]::Zero
}

function Get-WorkspaceHeaderPoint {
    $state = Read-Session
    if ($null -eq $state) { throw 'Saved session state is not readable before the workspace menu proof' }
    if (($state.PSObject.Properties['hide_sidebar'] -and $state.hide_sidebar) -or ($state.PSObject.Properties['sidebar_collapsed'] -and $state.sidebar_collapsed)) { throw 'Workspace header must be expanded and visible' }
    $top = if ($state.hide_pills) { 0 } else { 34 }
    return @{ x = 80; y = ($top + 26) }
}

function Dismiss-MenuCard([string]$Label) {
    $card = Get-MenuCard
    if ($card -eq [IntPtr]::Zero) { return }
    if (-not [VerifyNative]::IsWindowVisible($card)) { return }
    Assert-Foreground
    Record $Label
    try { [VerifyNative]::ClickOwnedChildClient($card, $script:window, 50, 5) } catch { }
    if ((Get-MenuCard) -ne [IntPtr]::Zero) { Press @(0x1B) ($Label + ' with Escape') }
    Wait-Until { (Get-MenuCard) -eq [IntPtr]::Zero } 'workspace menu dismissed' 10
}

function Read-RowBands([string]$Name, [int]$CardLeft, [int]$CardTop, [int]$CardWidth, [int[]]$Rows) {
    $image = [Drawing.Bitmap]::FromFile((Join-Path $Evidence ($Name + '.png')))
    try {
        $bands = [ordered]@{}
        foreach ($row in $Rows) {
            $top = $CardTop + 6 + $row * 28
            $bottom = $top + 28
            $left = $CardLeft + 10
            $right = $CardLeft + [Math]::Min($CardWidth - 10, 270)
            $sum = 0.0
            $pixels = 0
            $distinct = [System.Collections.Generic.HashSet[int]]::new()
            for ($y = [Math]::Max(0, $top); $y -lt [Math]::Min($image.Height, $bottom); $y++) {
                for ($x = [Math]::Max(0, $left); $x -lt [Math]::Min($image.Width, $right); $x++) {
                    $pixel = $image.GetPixel($x, $y)
                    $sum += 0.299 * $pixel.R + 0.587 * $pixel.G + 0.114 * $pixel.B
                    [void]$distinct.Add($pixel.ToArgb())
                    $pixels++
                }
            }
            if ($pixels -eq 0) { throw "Hover row $row is outside the captured window" }
            $bands["row$row"] = @{ meanLuminance = [Math]::Round($sum / $pixels, 2); distinctColors = $distinct.Count; rect = @($left, $top, $right, $bottom) }
        }
        return $bands
    } finally { $image.Dispose() }
}

Wait-Until {
    $state = Read-Session
    $null -ne $state -and @($state.tabs).Count -eq 20 -and $state.workspace_count -ge 4 -and
        @($state.tabs | Where-Object { $_.PSObject.Properties['pid'] -and [int]$_.pid -gt 0 }).Count -eq 20
} 'twenty seeded CMD sessions live across four or more workspaces' 240
$state = Read-Session
Save-Json @{ tabs = @($state.tabs).Count; workspaces = $state.workspace_count; livePids = @($state.tabs | Where-Object { $_.PSObject.Properties['pid'] -and [int]$_.pid -gt 0 }).Count; names = @($state.workspaces | ForEach-Object { $_.name }) } 'seed-restored.json'
Snapshot 'before'

Write-Host 'SOFT-2374: workspace menu open, five measured samples'
$header = Get-WorkspaceHeaderPoint
$cardTop = $header.y + 14
$cardBottom = [Math]::Min($cardTop + 230, 600)
$openSamples = @()
$warmups = @()
$pumpStopped = $false
function Invoke-MenuOpen([string]$Label) {
    if ((Get-MenuCard) -ne [IntPtr]::Zero) { Dismiss-MenuCard 'Dismiss the open workspace menu before the next open' }
    Assert-Foreground
    $probe = [PaintProbe]::new($script:window, 8, $cardTop, 300, $cardBottom)
    [VerifyNative]::ResetHangProbe()
    Record $Label
    $clock = [Diagnostics.Stopwatch]::StartNew()
    [VerifyNative]::ClickClient($script:window, $header.x, $header.y)
    $paint = $probe.WaitForChange($clock, 5000, 100)
    $paintMs = [double]$paint.paintMs
    Wait-Until { (Get-MenuCard) -ne [IntPtr]::Zero } 'workspace menu window visible' 10
    $visibleMs = [Math]::Round($clock.Elapsed.TotalMilliseconds, 1)
    Start-Sleep -Milliseconds 250
    $pumpMs = [Math]::Round([VerifyNative]::HangProbeMax(), 1)
    return @{ paintMs = $paintMs; cardVisibleMs = $visibleMs; pumpStallMs = $pumpMs; changedSamples = $paint.changedSamples }
}
try {
    [VerifyNative]::StartHangProbe($script:window)
    for ($warm = 1; $warm -le 3; $warm++) {
        $sample = Invoke-MenuOpen "Click the workspace name: unmetered warm-up $warm"
        $warmups += $sample
        Write-Host ("SOFT-2374 warm-up {0}: paint {1} ms, card window {2} ms" -f $warm, $sample.paintMs, $sample.cardVisibleMs)
        Dismiss-MenuCard "Dismiss workspace menu after warm-up $warm"
        if ($sample.paintMs -lt 1000) { break }
        Start-Sleep -Seconds 3
    }
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        $sample = Invoke-MenuOpen "Click the workspace name: menu open sample $attempt of 5"
        $openSamples += @{ sample = $attempt; paintMs = $sample.paintMs; cardVisibleMs = $sample.cardVisibleMs; pumpStallMs = $sample.pumpStallMs; changedSamples = $sample.changedSamples }
        Write-Host ("SOFT-2374 open {0}: paint {1} ms, card window {2} ms, worst message-pump round trip {3} ms" -f $attempt, $sample.paintMs, $sample.cardVisibleMs, $sample.pumpStallMs)
        if ($attempt -eq 5) { Snapshot 'workspace-menu-open' }
        Dismiss-MenuCard "Dismiss workspace menu after open $attempt"
    }
} finally {
    if (-not $pumpStopped) { [VerifyNative]::StopHangProbe(); $pumpStopped = $true }
}
Save-Json @{ samples = $openSamples; warmups = $warmups; budgetMs = 300; region = @(8, $cardTop, 300, $cardBottom); sessions = 20 } 'workspace-menu-open.json'
$slowPaint = @($openSamples | Where-Object { $_.paintMs -gt 300 })
$slowPump = @($openSamples | Where-Object { $_.pumpStallMs -gt 300 })
$result.checks += @{ name = 'workspace-menu-open'; opens = 5; budgetMs = 300; sessions = 20; warmups = @($warmups | ForEach-Object { $_.paintMs }); paintMs = @($openSamples | ForEach-Object { $_.paintMs }); cardVisibleMs = @($openSamples | ForEach-Object { $_.cardVisibleMs }); pumpStallMs = @($openSamples | ForEach-Object { $_.pumpStallMs }); overPaint = $slowPaint.Count; overPump = $slowPump.Count }
if ($slowPaint.Count -gt 0) { throw "SOFT-2374: $($slowPaint.Count) of 5 workspace menu opens painted later than 300 ms: $($slowPaint | ForEach-Object { $_.paintMs }) ms" }
if ($slowPump.Count -gt 0) { throw "SOFT-2374: the window message pump stalled longer than 300 ms during $($slowPump.Count) opens: $($slowPump | ForEach-Object { $_.pumpStallMs }) ms" }

Write-Host 'SOFT-2580: pointer-following row fill on three rows'
$hoverRows = @(1, 2, 3)
$hoverShots = @()
$card = [IntPtr]::Zero
try {
    Assert-Foreground
    Record 'Click the workspace name: one menu open for the pointer proof'
    [VerifyNative]::ClickClient($script:window, $header.x, $header.y)
    Wait-Until { (Get-MenuCard) -ne [IntPtr]::Zero } 'workspace menu window visible for the pointer proof' 10
    $card = Get-MenuCard
    Start-Sleep -Milliseconds 350
    $windowRect = New-Object VerifyNative+Rect
    if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$windowRect)) { throw 'Window rectangle unavailable' }
    $cardRect = New-Object VerifyNative+Rect
    if (-not [VerifyNative]::GetWindowRect($card, [ref]$cardRect)) { throw 'Menu rectangle unavailable' }
    $cardX = $cardRect.Left - $windowRect.Left
    $cardY = $cardRect.Top - $windowRect.Top
    $cardWidth = $cardRect.Right - $cardRect.Left
    $cardHeight = $cardRect.Bottom - $cardRect.Top
    if ($cardWidth -lt 120 -or $cardHeight -lt 80) { throw "Workspace menu is too small to hold three rows: $cardWidth x $cardHeight" }
    foreach ($row in $hoverRows) {
        $pointerY = 6 + $row * 28 + 14
        Record "Move the real pointer onto workspace menu row $row"
        [VerifyNative]::MoveMouseClient($card, 60, $pointerY, $false)
        Start-Sleep -Milliseconds 350
        $pointer = [VerifyNative]::ObserveUsageHover($script:window, [uint32]$process.Id, 60, $pointerY)
        $shotName = "workspace-menu-hover-$row"
        WindowShot $shotName
        if ($row -eq 2) { Snapshot 'workspace-menu-hover' }
        $hoverShots += @{ row = $row; pointer = $pointer; shot = ($shotName + '.png') }
        Write-Host ("SOFT-2580 row {0}: pointer screen {1},{2} client {3},{4} owned {5} hit {6}" -f $row, $pointer.actualScreen[0], $pointer.actualScreen[1], $pointer.actualClient[0], $pointer.actualClient[1], $pointer.hitOwned, $pointer.hitHandle)
    }
    $bands = [ordered]@{}
    foreach ($shot in $hoverShots) { $bands["row$($shot.row)"] = (Read-RowBands $shot.shot.Replace('.png', '') $cardX $cardY $cardWidth $hoverRows) }
    $verdicts = @()
    foreach ($shot in $hoverShots) {
        $capture = "row$($shot.row)"
        $scores = [ordered]@{}
        foreach ($band in $hoverRows) {
            $values = @()
            foreach ($other in $hoverShots) {
                if ($other.row -eq $shot.row) { continue }
                $values += [Math]::Abs($bands[$capture]["row$band"].meanLuminance - $bands["row$($other.row)"]["row$band"].meanLuminance)
            }
            $scores["row$band"] = [Math]::Round((($values | Measure-Object -Average).Average), 2)
        }
        $best = $scores.Keys | Sort-Object { $scores[$_] } -Descending | Select-Object -First 1
        $verdicts += @{ capture = $capture; pointerRow = $shot.row; highlightRow = $best; bandLuminance = $bands[$capture]; deviations = $scores; pointerScreen = $shot.pointer.actualScreen; pointerOwned = $shot.pointer.hitOwned }
        if ($best -ne $capture) { throw "SOFT-2580: pointer on row $($shot.row) left the highlight on $best (mean-luminance deviations $($scores | ConvertTo-Json -Compress))" }
        if ($scores[$best] -lt 1) { throw "SOFT-2580: pointer on row $($shot.row) produced no measurable row fill ($($scores[$best]) luminance)" }
    }
    foreach ($shot in $hoverShots) { if (-not $shot.pointer.hitOwned) { throw "SOFT-2580: the pointer was not over the owned menu on row $($shot.row)" } }
    Save-Json @{ card = @{ left = $cardRect.Left; top = $cardRect.Top; width = $cardWidth; height = $cardHeight; rows = $hoverRows; rowHeight = 28; rowTopPadding = 6 }; verdicts = $verdicts; shots = @($hoverShots | ForEach-Object { $_.shot }) } 'workspace-menu-hover.json'
    $result.checks += @{ name = 'workspace-menu-hover'; rows = $hoverRows; highlightFollowsPointer = @($verdicts | ForEach-Object { $_.highlightRow }); screenshots = @('workspace-menu-hover-1.png', 'workspace-menu-hover-2.png', 'workspace-menu-hover-3.png') }
} finally {
    if ((Get-MenuCard) -ne [IntPtr]::Zero) { Dismiss-MenuCard 'Dismiss workspace menu after the pointer proof' }
}

Write-Host 'SOFT-2373: 30 s presented-frame capture over three streaming chats'
$launchPath = Join-Path $scratch 'roaming/ZigShell/session.json.launch.json'
$sidebarWidth = 300
if (Test-Path $launchPath) {
    $published = Get-Content $launchPath -Raw | ConvertFrom-Json
    if ($published.PSObject.Properties['sidebar_width'] -and [int]$published.sidebar_width -ge 100) { $sidebarWidth = [int]$published.sidebar_width }
}
$client = New-Object VerifyNative+Rect
if (-not [VerifyNative]::GetClientRect($script:window, [ref]$client)) { throw 'Window client rectangle unavailable' }
$streaming = @{}
try {
    for ($tab = 1; $tab -le 3; $tab++) {
        Press @(0x11, (0x30 + $tab)) "Ctrl+${tab}: select streamed session ${tab}"
        Wait-Until { $state = Read-Session; $null -ne $state -and $state.active_tab -eq ($tab - 1) } "session $tab active before its stream starts" 20
        Wait-Until { [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window } "owned window foreground before typing into session $tab" 20
        Type-Text ('for /l %i in (1,1,60) do @(echo churn-line-%i & ping -n 2 127.0.0.1 >nul)')
        Press @(0x0D) "Enter: start continuous console output in session $tab"
        Start-Sleep -Milliseconds 800
        Press @(0x12, 0x43) 'Alt+C: Chat View for the streaming session'
        Wait-Until { $state = Read-Session; $null -ne $state -and (Test-SavedChatView $state ($tab - 1)) } "Chat View saved for streaming session $tab" 25
        $streaming["session$tab"] = $state.tabs[$tab - 1].name
    }
    Press @(0x11, 0x31) 'Ctrl+1: return to the first streaming chat'
    Wait-Until { $state = Read-Session; $state.active_tab -eq 0 -and (Test-SavedChatView $state 0) } 'first streaming chat visible in Chat View' 25
    Start-Sleep -Milliseconds 1500
    Snapshot 'action'
    $sidebarRegion = [int[]]@(6, 40, [Math]::Min(($sidebarWidth - 10), 290), ($client.Bottom - 10))
    $chatRegion = [int[]]@([Math]::Min(($sidebarWidth + 20), ($client.Right - 120)), 90, ($client.Right - 20), ($client.Bottom - 75))
    Write-Host "SOFT-2373: 30 s frame capture, sidebar $($sidebarRegion -join ','), chat $($chatRegion -join ',')"
    $churn = [SessionPaintProof]::SampleChurn($script:window, $sidebarRegion, $chatRegion, 10, 30, $Evidence)
    Save-Json $churn 'session-repaint-churn.json'
    $stripDir = Join-Path $Evidence 'strip'
    $stripFiles = [SessionPaintProof]::SaveStrip($script:window, $sidebarRegion, 6, $stripDir, 'session-repaint')
    $frameWidth = $sidebarRegion[2] - $sidebarRegion[0]
    $frameHeight = $sidebarRegion[3] - $sidebarRegion[1]
    $sheet = New-Object Drawing.Bitmap(($frameWidth * $stripFiles.Count), $frameHeight)
    $graphics = [Drawing.Graphics]::FromImage($sheet)
    try {
        for ($index = 0; $index -lt $stripFiles.Count; $index++) {
            $crop = [Drawing.Bitmap]::FromFile($stripFiles[$index])
            try { $graphics.DrawImage($crop, ($index * $frameWidth), 0) } finally { $crop.Dispose() }
        }
        $sheet.Save((Join-Path $Evidence 'session-repaint-strip.png'), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $sheet.Dispose() }
    Snapshot 'after'
    $rate = [Math]::Round([double]$churn.sidebarChangedFrames / 30.0, 2)
    $result.checks += @{ name = 'session-repaint-churn'; seconds = 30; fps = 10; capturedFrames = $churn.capturedFrames; sidebarChangedFrames = $churn.sidebarChangedFrames; sidebarChangesPerSecond = $rate; chatChangedFrames = $churn.chatChangedFrames; blankSidebarFrames = $churn.sidebarBlankFrames; blankChatFrames = $churn.chatBlankFrames; streamingSessions = @($streaming.Values); frameStrip = 'session-repaint-strip.png' }
    if ($churn.capturedFrames -lt 270) { throw "SOFT-2373: only $($churn.capturedFrames) of 300 requested frames were captured" }
    if ($churn.chatChangedFrames -lt 10) { throw "SOFT-2373: the streaming chat pane changed on only $($churn.chatChangedFrames) frames; output did not reach the screen" }
    if ($churn.sidebarBlankFrames -gt 0) { throw "SOFT-2373: $($churn.sidebarBlankFrames) of $($churn.capturedFrames) frames showed a blank sidebar" }
    if ($rate -gt 3) { throw "SOFT-2373: the sidebar changed on $($churn.sidebarChangedFrames) of $($churn.capturedFrames) frames ($rate per second), a repaint storm" }
} finally {
    foreach ($tab in 1, 2, 3) {
        try {
            Press @(0x11, (0x30 + $tab)) "Ctrl+${tab}: select streamed session ${tab}"
            if (Test-SavedChatView (Read-Session) ($tab - 1)) { Press @(0x12, 0x43) 'Alt+C: leave Chat View for the streaming session' }
        } catch { Write-Host "Stream cleanup for session ${tab}: $($_.Exception.Message)" }
    }
}
