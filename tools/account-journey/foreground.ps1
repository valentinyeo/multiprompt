Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using System.Text;
public static class JourneyForeground {
    delegate bool EnumProc(IntPtr h, IntPtr parameter);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumProc callback, IntPtr parameter);
    [DllImport("user32.dll", SetLastError=true)] static extern bool EnumWindows(EnumProc callback, IntPtr parameter);
    [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr h, uint command);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsWindowEnabled(IntPtr h);
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int left, top, right, bottom; }
    [StructLayout(LayoutKind.Sequential)] struct GUITHREADINFO { public uint size, flags; public IntPtr active, focus, capture, menuOwner, moveSize, caret; public RECT caretRect; }
    [DllImport("user32.dll")] static extern bool GetGUIThreadInfo(uint thread, ref GUITHREADINFO info);
    public static uint ThreadId(IntPtr h) { uint pid; return GetWindowThreadProcessId(h, out pid); }
    public static uint ForegroundThreadId() { return ThreadId(GetForegroundWindow()); }
    public static string Enabled(IntPtr h) { return IsWindow(h) ? IsWindowEnabled(h).ToString() : "unavailable"; }
    public static bool Exists(IntPtr h) { return IsWindow(h); }
    public static string ThreadFocus(uint thread) {
        if (thread == 0) return "unavailable";
        var info = new GUITHREADINFO();
        info.size = (uint)Marshal.SizeOf(typeof(GUITHREADINFO));
        return GetGUIThreadInfo(thread, ref info) ? info.focus.ToInt64().ToString() : "unavailable";
    }
    [DllImport("user32.dll")] static extern IntPtr GetAncestor(IntPtr h, uint flags);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder name, int max);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder text, int max);
    static string TitleKind(IntPtr h) {
        var text = new StringBuilder(256);
        GetWindowText(h, text, text.Capacity);
        switch (text.ToString()) {
            case "Account: Approve devices": return "approval";
            case "Multi Bot sync": return "sync";
            case "Multi Bot": return "account-duplicate";
            default: return "unknown";
        }
    }
    public sealed class OwnedWindow {
        public IntPtr Handle;
        public string Class;
        public string Title;
    }
    public static OwnedWindow[] ActiveOwnedWindows(IntPtr root, int processId) {
        uint rootPid;
        if (root == IntPtr.Zero || processId <= 0 || GetWindowThreadProcessId(root, out rootPid) == 0 || rootPid != (uint)processId) throw new ArgumentException("Invalid root");
        var entries = new List<OwnedWindow>();
        bool failed = false;
        EnumProc callback = (h, parameter) => {
            uint pid;
            if (GetWindow(h, 4) != root || GetWindowThreadProcessId(h, out pid) == 0 || pid != (uint)processId || !IsWindowVisible(h) || !IsWindowEnabled(h)) return true;
            var name = new StringBuilder(256);
            if (GetClassName(h, name, name.Capacity) == 0 || entries.Count >= 12) { failed = true; return false; }
            string cls = name.ToString();
            entries.Add(new OwnedWindow { Handle = h, Class = cls == "MultiPromptDialog" ? cls : "other", Title = TitleKind(h) });
            return true;
        };
        if (!EnumWindows(callback, IntPtr.Zero) || failed) throw new InvalidOperationException("Owned window enumeration unavailable");
        return entries.ToArray();
    }
    public static string OwnedWindows(IntPtr root, int processId) {
        uint rootPid;
        if (root == IntPtr.Zero || processId <= 0 || GetWindowThreadProcessId(root, out rootPid) == 0 || rootPid != (uint)processId) throw new ArgumentException("Invalid root");
        var entries = new List<string>();
        int count = 0;
        bool failed = false;
        EnumProc callback = (h, parameter) => {
            uint pid;
            IntPtr owner = GetWindow(h, 4);
            if (owner != root || GetWindowThreadProcessId(h, out pid) == 0 || pid != (uint)processId) return true;
            count++;
            if (entries.Count < 12) {
                var name = new StringBuilder(256);
                if (GetClassName(h, name, name.Capacity) == 0) { failed = true; return false; }
                string cls = name.ToString();
                if (cls != "MultiPromptDialog" && cls != "MultipromptSettingsKey" && cls != "#32770") cls = "other";
                entries.Add(string.Format("{0}:{1}:{2}:{3}:{4}:{5}", h.ToInt64(), owner.ToInt64(), IsWindowVisible(h), IsWindowEnabled(h), cls, TitleKind(h)));
            }
            return true;
        };
        if (!EnumWindows(callback, IntPtr.Zero) || failed) throw new InvalidOperationException("Enumeration unavailable");
        return string.Format("count={0},truncated={1},entries={2}", count, count > 12, string.Join(",", entries.ToArray()));
    }
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
function Clear-JourneyApproval([IntPtr]$Window, [int]$ProcessId) {
    $active = @([JourneyForeground]::ActiveOwnedWindows($Window, $ProcessId))
    if ($active.Count -eq 0) {
        if ([JourneyForeground]::Enabled($Window) -cne 'True') { throw 'Main window disabled without an active owned window' }
        return
    }
    if ($active.Count -ne 1 -or $active[0].Class -cne 'MultiPromptDialog' -or $active[0].Title -cne 'approval') {
        $kinds = @($active | ForEach-Object { $_.Title }) -join ','
        throw "Unexpected owned window: classification=$kinds"
    }
    $dialog = $active[0].Handle
    Set-JourneyForeground $dialog $ProcessId
    $active = @([JourneyForeground]::ActiveOwnedWindows($Window, $ProcessId))
    $focus = [ReconnectDesktop]::Focus($dialog)
    if ($active.Count -ne 1 -or $active[0].Handle -ne $dialog -or $active[0].Class -cne 'MultiPromptDialog' -or $active[0].Title -cne 'approval' -or [ReconnectDesktop]::Owner($dialog) -ne $ProcessId -or $focus[0] -ne $dialog.ToInt64() -or $focus[1] -ne $dialog.ToInt64()) { throw 'Approval dialog identity changed before cancellation' }
    [ReconnectDesktop]::Type(0x1B)
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        $active = @([JourneyForeground]::ActiveOwnedWindows($Window, $ProcessId))
        if ($active.Count -gt 0) {
            if ($active.Count -ne 1 -or $active[0].Handle -ne $dialog -or $active[0].Class -cne 'MultiPromptDialog' -or $active[0].Title -cne 'approval') {
                $kinds = @($active | ForEach-Object { $_.Title }) -join ','
                throw "Unexpected owned window: classification=$kinds"
            }
        } elseif (-not [JourneyForeground]::Exists($dialog) -and [JourneyForeground]::Enabled($Window) -ceq 'True') {
            Write-Host "Approval dialog cancelled; main window enabled (pid=$ProcessId)"
            return
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'Timed out: approval cancellation and main window enablement'
}
function Test-JourneyForeground([IntPtr]$Window, [int]$ProcessId, [IntPtr]$Foreground) {
    if ($Window -eq [IntPtr]::Zero -or $ProcessId -le 0 -or [ReconnectDesktop]::Owner($Window) -ne $ProcessId -or $Foreground -eq [IntPtr]::Zero -or [ReconnectDesktop]::Owner($Foreground) -eq 0) { return $false }
    return $Foreground -eq $Window -or ([ReconnectDesktop]::Class($Foreground) -ceq 'ConsoleWindowClass' -and [ReconnectDesktop]::GetAncestor($Foreground, 2) -eq $Window)
}
function Assert-Window([IntPtr]$Window, [int]$ProcessId) {
    $foreground = [ReconnectDesktop]::GetForegroundWindow()
    $owner = [ReconnectDesktop]::Owner($Window)
    $foregroundOwner = [ReconnectDesktop]::Owner($foreground)
    if (-not (Test-JourneyForeground $Window $ProcessId $foreground)) {
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
        if (Test-JourneyForeground $Window $ProcessId ([ReconnectDesktop]::GetForegroundWindow())) { return }
        [ReconnectDesktop]::Key(0x12, $false)
        try { [JourneyForeground]::Activate($Window) } finally { [ReconnectDesktop]::Key(0x12, $true) }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    Assert-Window $Window $ProcessId
}
