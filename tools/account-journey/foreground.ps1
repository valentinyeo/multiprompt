Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using System.Text;
public static class JourneyForeground {
    delegate bool EnumProc(IntPtr h, IntPtr parameter);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumProc callback, IntPtr parameter);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr GetAncestor(IntPtr h, uint flags);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder name, int max);
    public static IntPtr[] VisibleEdits(IntPtr root, int processId) {
        if (root == IntPtr.Zero) throw new ArgumentException("Missing root");
        uint rootPid;
        if (GetWindowThreadProcessId(root, out rootPid) == 0 || rootPid != (uint)processId) return new IntPtr[0];
        var edits = new List<IntPtr>();
        EnumProc callback = (h, parameter) => {
            uint pid;
            GetWindowThreadProcessId(h, out pid);
            var name = new StringBuilder(16);
            if (pid == (uint)processId && GetAncestor(h, 2) == root && IsWindowVisible(h) && GetClassName(h, name, name.Capacity) != 0 && name.ToString() == "Edit") edits.Add(h);
            return true;
        };
        EnumChildWindows(root, callback, IntPtr.Zero);
        return edits.ToArray();
    }
    [StructLayout(LayoutKind.Sequential)] struct MSG { public IntPtr hwnd; public uint message; public UIntPtr wParam; public IntPtr lParam; public uint time; public int x, y; public uint lPrivate; }
    [DllImport("user32.dll")] static extern bool PeekMessage(out MSG message, IntPtr hwnd, uint min, uint max, uint remove);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint from, uint to, bool attach);
    [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    public static void Activate(IntPtr h) {
        MSG message;
        PeekMessage(out message, IntPtr.Zero, 0, 0, 0);
        uint pid;
        uint current = GetCurrentThreadId();
        uint foreground = GetWindowThreadProcessId(GetForegroundWindow(), out pid);
        uint target = GetWindowThreadProcessId(h, out pid);
        bool attachedForeground = foreground != 0 && foreground != current && AttachThreadInput(current, foreground, true);
        bool attachedTarget = target != 0 && target != current && target != foreground && AttachThreadInput(current, target, true);
        try {
            BringWindowToTop(h);
            SetForegroundWindow(h);
        } finally {
            if (attachedTarget) AttachThreadInput(current, target, false);
            if (attachedForeground) AttachThreadInput(current, foreground, false);
        }
    }
}
'@
function Assert-Window([IntPtr]$Window, [int]$ProcessId) {
    $foreground = [ReconnectDesktop]::GetForegroundWindow()
    $owner = [ReconnectDesktop]::Owner($Window)
    $foregroundOwner = [ReconnectDesktop]::Owner($foreground)
    if ($Window -eq [IntPtr]::Zero -or $owner -ne $ProcessId -or $foreground -ne $Window) {
        $detail = 'diagnostics=unavailable'
        try {
            $class = [ReconnectDesktop]::Class($foreground)
            if ($class -cnotin @('ZigShell', 'ConsoleWindowClass', 'Edit')) { $class = 'other' }
            $root = [ReconnectDesktop]::GetAncestor($foreground, 2).ToInt64()
            $count = [ReconnectDesktop]::EventCount()
            $start = [Math]::Max([int]$script:journeyEventStart, $count - 12)
            $events = @([ReconnectDesktop]::EventsSince($start) | Select-Object -Last 12 | ForEach-Object { "$( $_.ev ):$( $_.hwnd ):$( $_.pid ):$( $_.root )" }) -join ','
            $detail = "foreground_class=$class foreground_root=$root events=$events"
        } catch {}
        throw "App window is not owned and foreground: expected hwnd=$($Window.ToInt64()) owner=$ProcessId; actual owner=$owner foreground=$($foreground.ToInt64()) foreground owner=$foregroundOwner; $detail"
    }
}
function Set-JourneyForeground([IntPtr]$Window, [int]$ProcessId) {
    try { $script:journeyEventStart = [ReconnectDesktop]::EventCount() } catch { $script:journeyEventStart = 0 }
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        if ($Window -eq [IntPtr]::Zero -or [ReconnectDesktop]::Owner($Window) -ne $ProcessId) { Assert-Window $Window $ProcessId }
        if ([ReconnectDesktop]::GetForegroundWindow() -eq $Window) { return }
        [ReconnectDesktop]::Key(0x12, $false)
        try { [JourneyForeground]::Activate($Window) } finally { [ReconnectDesktop]::Key(0x12, $true) }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    Assert-Window $Window $ProcessId
}
