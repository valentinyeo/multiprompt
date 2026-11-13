param([string]$Action = 'rects', [string]$Value = '')

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class MpRig {
    public delegate bool Proc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(Proc p, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll", SetLastError = true)] public static extern bool AttachThreadInput(uint from, uint to, bool attach);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool AllowSetForegroundWindow(uint pid);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
    public struct RECT { public int Left, Top, Right, Bottom; }
    public static IntPtr Found = IntPtr.Zero;
    public static IntPtr FindWindowFor(uint want, string cls) {
        Found = IntPtr.Zero;
        EnumWindows((h, l) => {
            uint pid; GetWindowThreadProcessId(h, out pid);
            var c = new StringBuilder(64); GetClassName(h, c, 64);
            if (pid == want && IsWindowVisible(h) && c.ToString() == cls) { Found = h; return false; }
            return true;
        }, IntPtr.Zero);
        return Found;
    }
    public static uint ForegroundPid() { uint p; GetWindowThreadProcessId(GetForegroundWindow(), out p); return p; }
    public static void Focus(IntPtr hwnd) {
        uint pid; uint fgThread = GetWindowThreadProcessId(GetForegroundWindow(), out pid);
        uint cur = GetCurrentThreadId(); uint targetPid; uint targetThread = GetWindowThreadProcessId(hwnd, out targetPid);
        bool a = fgThread != 0 && fgThread != cur && AttachThreadInput(cur, fgThread, true);
        bool b = targetThread != 0 && targetThread != cur && targetThread != fgThread && AttachThreadInput(cur, targetThread, true);
        keybd_event(0x12, 0, 0, UIntPtr.Zero);
        keybd_event(0xE8, 0, 0, UIntPtr.Zero);
        keybd_event(0xE8, 0, 2, UIntPtr.Zero);
        try { AllowSetForegroundWindow(targetPid); BringWindowToTop(hwnd); ShowWindow(hwnd, 3); SetForegroundWindow(hwnd); }
        finally { keybd_event(0x12, 0, 2, UIntPtr.Zero); if (b) AttachThreadInput(cur, targetThread, false); if (a) AttachThreadInput(cur, fgThread, false); }
    }
    public static string Rect(IntPtr h) {
        RECT r; if (!GetWindowRect(h, out r)) return "no-rect";
        return "" + r.Left + "," + r.Top + "," + (r.Right - r.Left) + "x" + (r.Bottom - r.Top);
    }
}
'@ -ReferencedAssemblies System.Drawing

function Dev-Process {
    Get-Process -Name 'multiprompt-dev' -ErrorAction SilentlyContinue | Select-Object -First 1
}

function Dev-Window($proc) {
    if (-not $proc) { return [IntPtr]::Zero }
    return [MpRig]::FindWindowFor([uint32]$proc.Id, 'ZigShell')
}

function Stable-Rect {
    $stable = Get-Process -Name 'multibot','multiprompt' -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if (-not $stable) { return 'stable-none' }
    $h = [MpRig]::FindWindowFor([uint32]$stable.Id, 'ZigShell')
    if ($h -eq [IntPtr]::Zero) { return 'stable-window-missing' }
    return 'stable=' + [MpRig]::Rect($h)
}

$dev = Dev-Process
$hwnd = Dev-Window $dev

switch ($Action) {
    'rects' {
        $devText = if ($dev) { 'dev=' + $dev.Id + ' ' + [MpRig]::Rect($hwnd) } else { 'dev-none' }
        'fg=' + [MpRig]::ForegroundPid() + ' ' + $devText + ' ' + (Stable-Rect)
    }
    'launch' {
        if ($dev) { 'already ' + $dev.Id }
        else {
            $dir = Join-Path $env:LOCALAPPDATA 'MultipromptDev'
            $exe = Join-Path $dir 'multiprompt-dev.exe'
            if (-not (Test-Path $exe)) { 'exe-missing'; break }
            $p = Start-Process -FilePath $exe -WorkingDirectory $dir -PassThru
            Start-Sleep -Seconds 6
            'launched ' + $p.Id
        }
    }
    'place' {
        if (-not $dev) { 'dev-not-running'; break }
        if ($hwnd -eq [IntPtr]::Zero) { 'window-missing'; break }
        [MpRig]::SetWindowPos($hwnd, [IntPtr]::Zero, -2560, -493, 2048, 1280, 0x0040) | Out-Null
        'placed ' + [MpRig]::Rect($hwnd)
    }
    'focus' {
        if (-not $dev) { 'dev-not-running'; break }
        if ($hwnd -eq [IntPtr]::Zero) { 'window-missing'; break }
        [MpRig]::Focus($hwnd)
        Start-Sleep -Milliseconds 350
        'fg=' + [MpRig]::ForegroundPid() + ' dev=' + $dev.Id
    }
    'guard' {
        if (-not $dev) { 'dev-not-running'; break }
        $fg = [MpRig]::ForegroundPid()
        if ($fg -eq [uint32]$dev.Id) { 'guard=dev' } else { 'guard=other fg=' + $fg + ' dev=' + $dev.Id }
    }
    'keys' {
        if (-not $dev -or [MpRig]::ForegroundPid() -ne [uint32]$dev.Id) { 'refused=foreground'; break }
        [System.Windows.Forms.SendKeys]::SendWait($Value)
        'keys=' + $Value
    }
    'type' {
        if (-not $dev -or [MpRig]::ForegroundPid() -ne [uint32]$dev.Id) { 'refused=foreground'; break }
        $escaped = $Value -replace '([+^%~(){}\[\]])', '{$1}'
        [System.Windows.Forms.SendKeys]::SendWait($escaped)
        'typed len=' + $Value.Length
    }
    'clipimg' {
        $img = [System.Drawing.Image]::FromFile($Value)
        [System.Windows.Forms.Clipboard]::SetImage($img)
        $img.Dispose()
        'clipboard=image'
    }
    'clip' {
        [System.Windows.Forms.Clipboard]::SetText($Value)
        'clipboard=text'
    }
    'shot' {
        if (-not $dev) { 'dev-not-running'; break }
        if ($hwnd -eq [IntPtr]::Zero) { 'window-missing'; break }
        $rect = New-Object MpRig+RECT
        [MpRig]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
        $bmp = New-Object System.Drawing.Bitmap (($rect.Right - $rect.Left), ($rect.Bottom - $rect.Top))
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $dc = $g.GetHdc()
        [MpRig]::PrintWindow($hwnd, $dc, 0) | Out-Null
        $g.ReleaseHdc($dc)
        $g.Dispose()
        $path = Join-Path $env:TEMP ($Value + '.png')
        $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        'shot=' + $path
    }
    'png' {
        $path = Join-Path $env:TEMP ($Value + '.png')
        if (-not (Test-Path $path)) { 'missing'; break }
        $bytes = [IO.File]::ReadAllBytes($path)
        $offset = 0
        while ($offset -lt $bytes.Length) {
            $take = [Math]::Min(150000, $bytes.Length - $offset)
            [Convert]::ToBase64String($bytes, $offset, $take)
            $offset += $take
        }
    }
    'sshpids' {
        if (-not $dev) { 'dev-not-running'; break }
        (Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $dev.Id -and $_.Name -match '^(ssh|plink)' } | ForEach-Object { $_.ProcessId }) -join ','
    }
    'killssh' {
        $targets = Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $dev.Id -and $_.Name -match '^(ssh|plink)' } | ForEach-Object { $_.ProcessId }
        foreach ($t in $targets) { Stop-Process -Id $t -Force -ErrorAction SilentlyContinue }
        'killed=' + (($targets) -join ',')
    }
    'stopdev' {
        if (-not $dev) { 'dev-not-running'; break }
        $dev | Stop-Process -Force
        'stopped ' + $dev.Id
    }
    default { 'unknown-action ' + $Action }
}
