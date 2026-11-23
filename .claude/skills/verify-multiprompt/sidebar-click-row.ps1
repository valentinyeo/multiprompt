Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class SidebarRowCursor {
    [StructLayout(LayoutKind.Sequential)]
    public struct Point { public int X; public int Y; }
    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out Point point);
    public static int[] Now() {
        Point point;
        if (!GetCursorPos(out point)) return new int[] { -1, -1 };
        return new int[] { point.X, point.Y };
    }
}
'@

function Get-SidebarBands([string]$Path, [int]$Dx, [int]$Dy, [int]$Top, [int]$Bottom) {
    $bitmap = [Drawing.Bitmap]::new($Path)
    try {
        $bands = @()
        $open = $null
        for ($y = $Top; $y -lt $Bottom -and $y -lt $bitmap.Height; $y++) {
            $min = 255
            $max = 0
            for ($x = $Dx + 20; $x -lt $Dx + 170 -and $x -lt $bitmap.Width; $x++) {
                $color = $bitmap.GetPixel($x, $y)
                $lum = [int](($color.R + $color.G + $color.B) / 3)
                if ($lum -lt $min) { $min = $lum }
                if ($lum -gt $max) { $max = $lum }
            }
            $ink = ($max - $min) -gt 60
            if ($ink) {
                if ($null -eq $open) { $open = @{ top = $y; bottom = $y } } else { $open.bottom = $y }
            } elseif ($null -ne $open) {
                if (($open.bottom - $open.top) -ge 9) { $bands += , $open }
                $open = $null
            }
        }
        if ($null -ne $open -and ($open.bottom - $open.top) -ge 9) { $bands += , $open }
        return $bands
    } finally { $bitmap.Dispose() }
}

function Get-BandMask([string]$Path, [int]$Dx, [int]$Dy, [int]$Top, [int]$Bottom) {
    $bitmap = [Drawing.Bitmap]::new($Path)
    try {
        $min = 255
        $max = 0
        for ($y = $Top; $y -lt $Bottom; $y++) {
            for ($x = $Dx + 20; $x -lt $Dx + 170; $x++) {
                $color = $bitmap.GetPixel($x, $y)
                $lum = [int](($color.R + $color.G + $color.B) / 3)
                if ($lum -lt $min) { $min = $lum }
                if ($lum -gt $max) { $max = $lum }
            }
        }
        $threshold = $min + [int](($max - $min) * 0.55)
        $count = 0
        $mask = New-Object 'bool[,]' (($Dx + 170) - ($Dx + 20)), ($Bottom - $Top)
        for ($y = $Top; $y -lt $Bottom; $y++) {
            for ($x = $Dx + 20; $x -lt $Dx + 170; $x++) {
                $color = $bitmap.GetPixel($x, $y)
                $lum = [int](($color.R + $color.G + $color.B) / 3)
                if ($lum -ge $threshold) { $mask[$x - ($Dx + 20), $y - $Top] = $true; $count++ }
            }
        }
        return @{ mask = $mask; ink = $count; width = ($Dx + 170) - ($Dx + 20); height = ($Bottom - $Top) }
    } finally { $bitmap.Dispose() }
}

$check = @{ name = 'sidebar-click-row'; passed = $false; boundary = 'Two stand-in tmux tabs on the replaced SSH boundary; real sidebar, real click, real chat reopen.' }
$result.checks += $check
Wait-Until {
    $state = Read-Session
    $null -ne $state -and @($state.tabs).Count -eq 2 -and $state.active_tab -eq 1 -and $state.tabs[0].name -ceq 'Quiet chat' -and $state.tabs[1].name -ceq 'Loud chat'
} 'two saved sessions restored with the newer one active' 180
[void][VerifyNative]::DwmFlush()
[VerifyNative]::MoveMouseClient($script:window, 900, 420, $true)
Start-Sleep -Milliseconds 400
$frame = New-Object VerifyNative+Rect
$origin = New-Object VerifyNative+Point
if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'Sidebar row geometry unavailable' }
$dx = $origin.X - $frame.Left
$dy = $origin.Y - $frame.Top
WindowShot 'sidebar-row-locate'
$bands = Get-SidebarBands (Join-Path $Evidence 'sidebar-row-locate.png') $dx $dy ($dy + 90) ([Math]::Min($dy + 430, $frame.Bottom - $frame.Top - 110))
if ($bands.Count -lt 2) { throw ('Sidebar shows fewer than two session rows: ' + $bands.Count) }
$row = $bands[$bands.Count - 1]
$clickX = $dx + 85
$clickY = [int](($row.top + $row.bottom) / 2)
Record ("Pointer target: sidebar row at client $clickX,$clickY spanning $($row.top)..$($row.bottom)")
[VerifyNative]::MoveMouseClient($script:window, $clickX, $clickY, $true)
Start-Sleep -Milliseconds 500
WindowShot 'sidebar-row-before'
$pointerBefore = [SidebarRowCursor]::Now()
Record ('Pointer before click: ' + ($pointerBefore -join ',') + ' client ' + $clickX + ',' + $clickY)
$stateBefore = Read-Session
[VerifyNative]::ClickClient($script:window, $clickX, $clickY)
$pointerAfterClick = [SidebarRowCursor]::Now()
Record ('Pointer after click: ' + ($pointerAfterClick -join ','))
Wait-Until {
    $state = Read-Session
    $null -ne $state -and $state.active_tab -eq 0
} 'clicked sidebar session became the selected chat' 60
Start-Sleep -Milliseconds 1500
WindowShot 'sidebar-row-after'
$pointerAfter = [SidebarRowCursor]::Now()
if ($pointerAfter[0] -ne $pointerBefore[0] -or $pointerAfter[1] -ne $pointerBefore[1]) { throw ('Pointer moved during the click proof: ' + ($pointerBefore -join ',') + ' to ' + ($pointerAfter -join ',')) }
$bandTop = $row.top
$bandBottom = $row.bottom
$before = Get-BandMask (Join-Path $Evidence 'sidebar-row-before.png') $dx $dy $bandTop $bandBottom
$after = Get-BandMask (Join-Path $Evidence 'sidebar-row-after.png') $dx $dy $bandTop $bandBottom
if ($before.ink -lt 60) { throw ('The row band under the pointer has too little text to compare: ' + $before.ink) }
$both = 0
$any = 0
for ($x = 0; $x -lt $before.width; $x++) {
    for ($y = 0; $y -lt $before.height; $y++) {
        $a = $before.mask[$x, $y]
        $b = $after.mask[$x, $y]
        if ($a -and $b) { $both++ }
        if ($a -or $b) { $any++ }
    }
}
$overlap = if ($any -eq 0) { 0 } else { [Math]::Round(100.0 * $both / $any, 1) }
$log = Join-Path $scratch 'roaming/ZigShell/debug.log'
$trace = if (Test-Path $log) { Read-SharedText $log } else { '' }
$reopens = ([regex]::Matches($trace, 'respawnShellInPlace ok kind=')).Count + ([regex]::Matches($trace, 'ssh-reconnect|reconnect-ok|switchToShell: 1 -> 0')).Count
Snapshot 'after'
Save-Json @{
    pointerBefore = $pointerBefore
    pointerAfterClick = $pointerAfterClick
    pointerAfter = $pointerAfter
    target = @{ clientX = $clickX; clientY = $clickY; bandTop = $bandTop; bandBottom = $bandBottom }
    clickX = $clickX
    clickY = $clickY
    clickPoint = @($clickX + $origin.X - $frame.Left, $clickY + $origin.Y - $frame.Top)
    inkOverlap = $overlap
    inkBefore = $before.ink
    inkAfter = $after.ink
    activeBefore = $stateBefore.active_tab
    activeAfter = (Read-Session).active_tab
    reopenLogLines = $reopens
} 'sidebar-row.json'
$check.pointer = $pointerAfter
$check.inkOverlap = $overlap
$check.activeBefore = $stateBefore.active_tab
$check.activeAfter = (Read-Session).active_tab
$check.screenshots = @('sidebar-row-before.png', 'sidebar-row-after.png')
if ($overlap -lt 70) { throw ('The clicked sidebar row no longer sits under the pointer: ink overlap ' + $overlap + '%') }
$check.passed = $true
Save-Json $check 'sidebar-row-check.json'
