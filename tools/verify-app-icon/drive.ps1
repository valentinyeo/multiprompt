param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)][string]$ExpectedHash,
    [Parameter(Mandatory)][string]$Evidence
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Run only through verify.yml on a GitHub Windows runner' }
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
$assets = (Resolve-Path "$PSScriptRoot/../../assets").Path
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class AppIconProbe {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc p, IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", EntryPoint = "GetClassLongPtrW")] static extern IntPtr GetClassLongPtr(IntPtr h, int i);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    public static IntPtr[] VisibleWindows(uint[] pids) {
        var found = new List<IntPtr>();
        EnumWindows((h, l) => {
            uint pid;
            GetWindowThreadProcessId(h, out pid);
            if (IsWindowVisible(h) && Array.IndexOf(pids, pid) >= 0) found.Add(h);
            return true;
        }, IntPtr.Zero);
        return found.ToArray();
    }
    public static int IndexOf(byte[] haystack, byte[] needle) {
        for (int i = 0; i + needle.Length <= haystack.Length; i++) {
            if (haystack[i] != needle[0]) continue;
            int j = 1;
            while (j < needle.Length && haystack[i + j] == needle[j]) j++;
            if (j == needle.Length) return i;
        }
        return -1;
    }
    public static IntPtr WindowIcon(IntPtr h, bool big) {
        IntPtr icon;
        if (SendMessageTimeoutW(h, 0x7F, (IntPtr)(big ? 1 : 0), IntPtr.Zero, 2, 5000, out icon) == IntPtr.Zero) icon = IntPtr.Zero;
        if (icon == IntPtr.Zero) icon = GetClassLongPtr(h, big ? -14 : -34);
        return icon;
    }
}
'@
[void][AppIconProbe]::SetProcessDPIAware()

$checks = [Collections.Generic.List[object]]::new()
$state = @{ failure = $null; cleanup = 'pending' }
$scratch = Join-Path $env:RUNNER_TEMP "app-icon-$PID"
New-Item -ItemType Directory -Force $scratch | Out-Null

function Add-Check([string]$Name, [bool]$Passed, [string]$Detail) {
    $checks.Add([ordered]@{ name = $Name; passed = $Passed; detail = $Detail })
    Write-Host "$(if ($Passed) { 'PASS' } else { 'FAIL' }) $Name $Detail"
}

function Get-Frame([string]$Path, [int]$Size) {
    $source = [Drawing.Bitmap]::FromFile($Path)
    $frame = [Drawing.Bitmap]::new($Size, $Size, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($frame)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.DrawImage($source, 0, 0, $Size, $Size)
    $g.Dispose(); $source.Dispose()
    return $frame
}

function Get-IconDifference([Drawing.Bitmap]$Actual, [string]$ExpectedPath) {
    $size = $Actual.Width
    $expected = Get-Frame $ExpectedPath $size
    $total = 0.0
    $bg = 30
    for ($y = 0; $y -lt $size; $y++) {
        for ($x = 0; $x -lt $size; $x++) {
            $a = $Actual.GetPixel($x, $y); $e = $expected.GetPixel($x, $y)
            foreach ($pair in @(@($a.R, $a.A, $e.R, $e.A), @($a.G, $a.A, $e.G, $e.A), @($a.B, $a.A, $e.B, $e.A))) {
                $va = ($pair[0] * $pair[1] + $bg * (255 - $pair[1])) / 255
                $ve = ($pair[2] * $pair[3] + $bg * (255 - $pair[3])) / 255
                $total += [math]::Abs($va - $ve)
            }
        }
    }
    $expected.Dispose()
    return [math]::Round($total / ($size * $size * 3), 2)
}

function Save-Icon($Handle, [string]$Name) {
    $icon = [Drawing.Icon]::FromHandle($Handle)
    $bitmap = [Drawing.Bitmap]::new($icon.ToBitmap())
    $bitmap.Save("$Evidence/$Name.png", [Drawing.Imaging.ImageFormat]::Png)
    return $bitmap
}

function Get-OwnedProcessIds {
    @(Get-Process | Where-Object { $_.Path -and ($_.Path -ieq $Exe) } | ForEach-Object { [uint32]$_.Id })
}

$maxDifference = 8.0
try {
    if ((Get-FileHash $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Executable checksum mismatch' }
    if (-not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable version mismatch' }

    $exeBytes = [IO.File]::ReadAllBytes($Exe)
    $missing = @(16, 32, 48, 64, 256 | Where-Object { [AppIconProbe]::IndexOf($exeBytes, [IO.File]::ReadAllBytes("$assets/icon$_.png")) -lt 0 })
    Add-Check 'exe-embeds-all-frames' ($missing.Count -eq 0) "approved icon frames missing from the executable: $(if ($missing.Count) { $missing -join ', ' } else { 'none' }) of 16, 32, 48, 64, 256"
    $exeIcon = [Drawing.Icon]::ExtractAssociatedIcon($Exe)
    $exeBitmap = [Drawing.Bitmap]::new($exeIcon.ToBitmap())
    $exeBitmap.Save("$Evidence/exe-icon.png", [Drawing.Imaging.ImageFormat]::Png)
    $exeDifference = Get-IconDifference $exeBitmap "$assets/icon$($exeBitmap.Width).png"
    Add-Check 'exe-icon-is-robot' ($exeDifference -le $maxDifference) "embedded $($exeBitmap.Width)px icon differs from the approved frame by $exeDifference of 255 (limit $maxDifference)"

    $env:APPDATA = Join-Path $scratch 'roaming'
    $env:LOCALAPPDATA = Join-Path $scratch 'local'
    $env:USERPROFILE = Join-Path $scratch 'profile'
    $env:HOME = $env:USERPROFILE
    foreach ($dir in @($env:APPDATA, $env:LOCALAPPDATA, $env:USERPROFILE)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    $env:MULTIPROMPT_NO_LOGIN = '1'
    $process = Start-Process -FilePath $Exe -PassThru
    $windows = @()
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while ($windows.Count -eq 0 -and $timer.Elapsed.TotalSeconds -lt 60) {
        Start-Sleep -Milliseconds 500
        $windows = @([AppIconProbe]::VisibleWindows([uint32[]]@(Get-OwnedProcessIds)))
    }
    Add-Check 'window-visible' ($windows.Count -gt 0) "visible app windows: $($windows.Count)"
    if ($windows.Count -eq 0) { throw 'The app window never appeared' }
    Start-Sleep -Seconds 5
    $windows = @([AppIconProbe]::VisibleWindows([uint32[]]@(Get-OwnedProcessIds)))
    if ($windows.Count -eq 0) { throw 'The app window disappeared after it appeared' }
    $window = $windows[0]

    $big = [AppIconProbe]::WindowIcon($window, $true)
    $small = [AppIconProbe]::WindowIcon($window, $false)
    if ($big -eq [IntPtr]::Zero -or $small -eq [IntPtr]::Zero) { throw 'The window reports no icon' }
    $bigBitmap = Save-Icon $big 'window-icon-big'
    $smallBitmap = Save-Icon $small 'window-icon-small'
    $bigDifference = Get-IconDifference $bigBitmap "$assets/icon$($bigBitmap.Width).png"
    $smallDifference = Get-IconDifference $smallBitmap "$assets/icon$($smallBitmap.Width).png"
    Add-Check 'taskbar-icon-is-robot' ($bigDifference -le $maxDifference) "window $($bigBitmap.Width)px icon differs from the approved frame by $bigDifference of 255 (limit $maxDifference)"
    Add-Check 'small-icon-is-robot' ($smallDifference -le $maxDifference) "window $($smallBitmap.Width)px icon differs from the approved frame by $smallDifference of 255 (limit $maxDifference)"

    $bounds = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $shot = [Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
    $graphics = [Drawing.Graphics]::FromImage($shot)
    $graphics.CopyFromScreen($bounds.Left, $bounds.Top, 0, 0, $shot.Size)
    $graphics.Dispose()
    $shot.Save("$Evidence/desktop.png", [Drawing.Imaging.ImageFormat]::Png)
    $stripHeight = [math]::Min(96, $bounds.Height)
    $strip = $shot.Clone([Drawing.Rectangle]::new(0, $bounds.Height - $stripHeight, $bounds.Width, $stripHeight), $shot.PixelFormat)
    $strip.Save("$Evidence/taskbar-strip.png", [Drawing.Imaging.ImageFormat]::Png)
    Add-Check 'desktop-captured' $true "full screen $($bounds.Width)x$($bounds.Height) saved with the bottom $stripHeight px as taskbar-strip.png"
} catch {
    $state.failure = "$_"
    Add-Check 'journey' $false "$_"
} finally {
    foreach ($id in (Get-OwnedProcessIds)) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 1
    $remaining = @(Get-OwnedProcessIds).Count
    Remove-Item -Recurse -Force $scratch -ErrorAction SilentlyContinue
    $state.cleanup = "remaining_owned_processes=$remaining; scratch_removed=$(-not (Test-Path $scratch))"
}

$passed = (@($checks | Where-Object { -not $_.passed }).Count -eq 0) -and ($checks.Count -ge 6)
$result = [ordered]@{ feature = 'app-icon'; status = $(if ($passed) { 'passed' } else { 'failed' }); version = $ExpectedVersion; sha256 = $ExpectedHash; checks = $checks; cleanup = $state.cleanup }
$result | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 "$Evidence/result.json"
if (-not $passed) { throw "app-icon verification failed: $((@($checks | Where-Object { -not $_.passed } | ForEach-Object { $_.name }) -join ', ')) $($state.failure)" }
Write-Output 'VERIFIED app-icon with the real exe and retained evidence'
