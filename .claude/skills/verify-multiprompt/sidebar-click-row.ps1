Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Runtime.InteropServices;
public static class SidebarRowProof {
    [StructLayout(LayoutKind.Sequential)]
    public struct CursorPoint { public int X; public int Y; }
    [DllImport("user32.dll")]
    static extern bool GetCursorPos(out CursorPoint point);
    public static int[] Cursor() {
        CursorPoint point;
        if (!GetCursorPos(out point)) return new int[] { -1, -1 };
        return new int[] { point.X, point.Y };
    }
    static bool Ink(Bitmap image, int x, int y) {
        Color color = image.GetPixel(x, y);
        return color.R > 200 && color.G > 200 && color.B > 200;
    }
    public static int[][] Bands(string path, int dx, int top, int bottom) {
        var bands = new List<int[]>();
        int openTop = -1, openBottom = -1;
        using (var image = new Bitmap(path)) {
            if (bottom > image.Height - 1) bottom = image.Height - 1;
            for (int y = top; y < bottom; y++) {
                bool ink = false;
                for (int x = dx + 20; x < dx + 170 && x < image.Width; x++) {
                    if (Ink(image, x, y)) { ink = true; break; }
                }
                if (ink) {
                    if (openTop < 0) openTop = y;
                    openBottom = y;
                } else if (openTop >= 0) {
                    if (openBottom - openTop >= 6) bands.Add(new int[] { openTop, openBottom });
                    openTop = -1;
                }
            }
            if (openTop >= 0 && openBottom - openTop >= 6) bands.Add(new int[] { openTop, openBottom });
        }
        return bands.ToArray();
    }
    public static double Overlap(string pathBefore, string pathAfter, int dx, int top, int bottom) {
        using (var before = new Bitmap(pathBefore))
        using (var after = new Bitmap(pathAfter)) {
            int both = 0, either = 0, beforeInk = 0;
            for (int y = top; y < bottom; y++) {
                for (int x = dx + 20; x < dx + 170; x++) {
                    bool a = Ink(before, x, y);
                    bool b = Ink(after, x, y);
                    if (a) beforeInk++;
                    if (a && b) both++;
                    if (a || b) either++;
                }
            }
            if (beforeInk < 60) throw new InvalidOperationException("Row band under the pointer has too little text to compare: " + beforeInk);
            if (either == 0) return 0.0;
            return 100.0 * both / either;
        }
    }
}
'@

$check = @{ name = 'sidebar-click-row'; passed = $false; boundary = 'Two stand-in tmux tabs on the replaced SSH boundary; real sidebar, real click, real chat reopen.' }
$result.checks += $check
Wait-Until {
    $state = Read-Session
    $null -ne $state -and @($state.tabs).Count -eq 2 -and $state.active_tab -eq 0 -and $state.tabs[0].name -ceq 'Quiet chat' -and $state.tabs[1].name -ceq 'Loud chat'
} 'two saved sessions restored with the first one active' 180
[void][VerifyNative]::DwmFlush()
[VerifyNative]::MoveMouseClient($script:window, 900, 420, $false)
Activate-OwnedFrame
Wait-Until {
    $foreground = [VerifyNative]::GetForegroundWindow()
    $foreground -ne [IntPtr]::Zero -and ($foreground -eq $script:window -or [VerifyNative]::GetAncestor($foreground, 2) -eq $script:window)
} 'owned app is the foreground window before the sidebar click' 30
Start-Sleep -Milliseconds 400
$frame = New-Object VerifyNative+Rect
$origin = New-Object VerifyNative+Point
if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'Sidebar row geometry unavailable' }
$dx = $origin.X - $frame.Left
$dy = $origin.Y - $frame.Top
WindowShot 'sidebar-row-locate'
$bands = [SidebarRowProof]::Bands((Join-Path $Evidence 'sidebar-row-locate.png'), $dx, ($dy + 90), ($dy + 340))
if ($null -eq $bands -or $bands.Count -lt 2) { throw ('Sidebar session rows not found above the status card: ' + $(if ($null -eq $bands) { 0 } else { $bands.Count })) }
$row = $bands[$bands.Count - 1]
$clickX = $dx + 85
$clickY = [int](($row[0] + $row[1]) / 2)
Record ("Pointer target: sidebar row at client $clickX,$clickY spanning $($row[0])..$($row[1])")
[VerifyNative]::MoveMouseClient($script:window, $clickX, $clickY, $false)
Start-Sleep -Milliseconds 500
WindowShot 'sidebar-row-before'
$pointerBefore = [SidebarRowProof]::Cursor()
Record ('Pointer before click: ' + ($pointerBefore -join ',') + ' client ' + $clickX + ',' + $clickY)
$activeBefore = (Read-Session).active_tab
[VerifyNative]::ClickClient($script:window, $clickX, $clickY)
Snapshot 'action'
$pointerAfterClick = [SidebarRowProof]::Cursor()
Record ('Pointer after click: ' + ($pointerAfterClick -join ','))
Wait-Until { (Read-Session).active_tab -eq 1 } 'clicked sidebar session became the selected chat' 60
Start-Sleep -Milliseconds 2000
WindowShot 'sidebar-row-after'
$pointerAfter = [SidebarRowProof]::Cursor()
if ($pointerAfter[0] -ne $pointerBefore[0] -or $pointerAfter[1] -ne $pointerBefore[1]) { throw ('Pointer moved during the click proof: ' + ($pointerBefore -join ',') + ' to ' + ($pointerAfter -join ',')) }
$overlap = [Math]::Round([SidebarRowProof]::Overlap((Join-Path $Evidence 'sidebar-row-before.png'), (Join-Path $Evidence 'sidebar-row-after.png'), $dx, $row[0], $row[1]), 1)
$activeAfter = (Read-Session).active_tab
$log = Join-Path $scratch 'roaming/ZigShell/debug.log'
$trace = if (Test-Path $log) { Read-SharedText $log } else { '' }
$reopens = ([regex]::Matches($trace, 'respawnShellInPlace ok kind=')).Count + ([regex]::Matches($trace, 'ssh-reconnect|reconnect-ok')).Count
Snapshot 'after'
Save-Json @{
    pointerBefore = $pointerBefore
    pointerAfterClick = $pointerAfterClick
    pointerAfter = $pointerAfter
    clickClient = @($clickX, $clickY)
    clickScreen = @(($clickX + $dx), ($clickY + $dy))
    band = @($row[0], $row[1])
    inkOverlap = $overlap
    activeBefore = $activeBefore
    activeAfter = $activeAfter
    reopenLogLines = $reopens
    screenshots = @('sidebar-row-before.png', 'sidebar-row-after.png')
} 'sidebar-row.json'
$check.pointer = $pointerAfter
$check.inkOverlap = $overlap
$check.activeBefore = $activeBefore
$check.activeAfter = $activeAfter
$check.screenshots = @('sidebar-row-before.png', 'sidebar-row-after.png')
if ($overlap -lt 70) { throw ('The clicked sidebar row no longer sits under the pointer: row ink overlap ' + $overlap + '%') }
$check.passed = $true
Save-Json $check 'sidebar-row-check.json'
