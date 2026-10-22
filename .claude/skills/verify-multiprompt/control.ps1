param(
    [Parameter(Mandatory=$true)][ValidateSet('appearance', 'sessions', 'workspaces', 'workspace-focus', 'inbox', 'command-palette', 'session-open', 'browser-pane-stuck', 'browser-workspaces', 'chat-tables', 'safe-updates', 'chat-view', 'browser-emulation')][string]$Feature,
    [Parameter(Mandatory=$true)][string]$Exe,
    [Parameter(Mandatory=$true)][string]$ExpectedVersion,
    [Parameter(Mandatory=$true)][string]$ExpectedHash,
    [Parameter(Mandatory=$true)][string]$Evidence
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Run only on a GitHub Windows runner through verify.yml' }
switch ($Feature) {
        'safe-updates' {
            if ((Get-FileHash $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Executable checksum mismatch before update journey' }
            if (-not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable version mismatch before update journey' }
            & "$PSScriptRoot/../../../tools/update-release-journey.ps1" -Exe $Exe -Evidence $Evidence
            return
        }
}

Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class VerifyNative {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct Mouse { public int x, y; public uint data, flags, time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] public struct Keyboard { public ushort key, scan; public uint flags, time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Explicit)] public struct Union { [FieldOffset(0)] public Mouse mouse; [FieldOffset(0)] public Keyboard keyboard; }
    [StructLayout(LayoutKind.Sequential)] public struct Input { public uint type; public Union data; }
    [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint count, Input[] inputs, int size);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll", SetLastError=true)] static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr hwnd);
    [StructLayout(LayoutKind.Sequential)] public struct GuiThreadInfo { public uint size, flags; public IntPtr active, focus, capture, menuOwner, moveSize, caret; public Rect caretRect; }
    [DllImport("user32.dll", SetLastError=true)] static extern bool GetGUIThreadInfo(uint thread, ref GuiThreadInfo info);
    public static void FocusOwnedWindow(IntPtr hwnd, int expectedPid, IntPtr frame) {
        uint owner;
        uint target = GetWindowThreadProcessId(hwnd, out owner);
        if (owner != expectedPid || Class(frame) != "ZigShell" || GetAncestor(hwnd, 3) != frame || (hwnd != frame && Class(hwnd) != "Chrome_WidgetWin_1")) throw new InvalidOperationException("Focus window ownership mismatch");
        SetForegroundWindow(hwnd);
        if (GetForegroundWindow() != hwnd) {
            BringWindowToTop(hwnd);
            Rect bounds;
            if (!GetWindowRect(hwnd, out bounds)) throw new InvalidOperationException("Owned browser bounds unavailable");
            Point point = new Point { X = hwnd == frame ? bounds.Left + 100 : bounds.Right - 160, Y = bounds.Top + 22 };
            if (GetAncestor(WindowFromPoint(point), 2) != hwnd || GetAncestor(WindowFromPoint(point), 3) != frame) throw new InvalidOperationException("Refusing click outside the exact owned browser");
            if (!SetCursorPos(point.X, point.Y)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            Input[] click = new Input[2];
            click[0].data.mouse = new Mouse { flags = 2 };
            click[1].data.mouse = new Mouse { flags = 4 };
            if (SendInput(2, click, Marshal.SizeOf(typeof(Input))) != 2) throw new InvalidOperationException("Owned browser click failed");
            Thread.Sleep(100);
        }
        if (GetForegroundWindow() != hwnd) throw new InvalidOperationException("Owned frame could not become foreground");
        GuiThreadInfo info = new GuiThreadInfo { size = (uint)Marshal.SizeOf(typeof(GuiThreadInfo)) };
        if (!GetGUIThreadInfo(target, ref info) || info.active != hwnd || GetAncestor(info.focus, 3) != frame || (hwnd != frame && GetAncestor(info.focus, 2) != hwnd)) throw new InvalidOperationException("Owned window did not receive keyboard focus");
    }
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", SetLastError=true)] static extern bool GetGUIThreadInfo(uint thread, ref GuiThreadInfo info);
    [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr hwnd, uint flags);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int command);
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hwnd, int x, int y, int width, int height, bool repaint);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr hwnd, ref Point point);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint message, UIntPtr count, StringBuilder text, uint flags, uint timeout, out UIntPtr result);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern short VkKeyScan(char character);
    [DllImport("dwmapi.dll")] public static extern int DwmFlush();
    static void Key(ushort key, ushort scan, uint flags) {
        Input input = new Input(); input.type = 1;
        input.data.keyboard = new Keyboard { key = key, scan = scan, flags = flags };
        if (SendInput(1, new Input[] { input }, Marshal.SizeOf(typeof(Input))) != 1) throw new InvalidOperationException("SendInput failed");
    }
    public static void Chord(int[] keys) {
        Input[] inputs = new Input[keys.Length * 2];
        for (int i = 0; i < keys.Length; i++) {
            inputs[i].type = 1;
            inputs[i].data.keyboard = new Keyboard { key = (ushort)keys[i] };
            inputs[keys.Length + i].type = 1;
            inputs[keys.Length + i].data.keyboard = new Keyboard { key = (ushort)keys[keys.Length - i - 1], flags = 2 };
        }
        if (SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(Input))) != inputs.Length) throw new InvalidOperationException("SendInput chord failed");
        Thread.Sleep(250);
    }
    public static void Text(string text) {
        foreach (char c in text) {
            short mapping = VkKeyScan(c);
            if (mapping == -1 || (mapping & 0x600) != 0) throw new InvalidOperationException("Character requires an unsupported keyboard layout: " + c);
            bool shift = (mapping & 0x100) != 0;
            if (shift) { Key(0x10, 0, 0); Thread.Sleep(35); }
            ushort key = (ushort)(mapping & 0xff);
            Key(key, 0, 0); Thread.Sleep(35); Key(key, 0, 2);
            if (shift) Key(0x10, 0, 2);
            Thread.Sleep(30);
        }
        Thread.Sleep(250);
    }
    public static void OpenAndCloseBrowserPane() {
        var inputs = new List<Input>();
        Action<ushort, uint> key = (code, flags) => {
            Input input = new Input(); input.type = 1;
            input.data.keyboard = new Keyboard { key = code, flags = flags };
            inputs.Add(input);
        };
        foreach (string query in new string[] { "open browser", "close browser pane" }) {
            key(0x11, 0); key(0x4B, 0); key(0x4B, 2); key(0x11, 2);
            foreach (char c in query) {
                short mapping = VkKeyScan(c);
                if (mapping == -1 || (mapping & 0x700) != 0) throw new InvalidOperationException("Batch query requires an unshifted keyboard mapping: " + c);
                key((ushort)(mapping & 0xff), 0); key((ushort)(mapping & 0xff), 2);
            }
            key(0x0D, 0); key(0x0D, 2);
        }
        Input[] batch = inputs.ToArray();
        if (SendInput((uint)batch.Length, batch, Marshal.SizeOf(typeof(Input))) != (uint)batch.Length) throw new InvalidOperationException("SendInput batch failed");
    }
    delegate bool EnumWindow(IntPtr hwnd, IntPtr data);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindow callback, IntPtr data);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr GetProp(IntPtr hwnd, string name);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
    public static bool PaneVisible(IntPtr owner) {
        Rect frame;
        if (!GetWindowRect(owner, out frame)) return false;
        bool visible = false;
        EnumWindows(delegate(IntPtr hwnd, IntPtr data) {
            if (GetProp(hwnd, "ZigShellPaneOwner") != owner || !IsWindowVisible(hwnd)) return true;
            Rect pane;
            if (GetWindowRect(hwnd, out pane) && pane.Right > pane.Left && pane.Bottom > pane.Top &&
                pane.Left < frame.Right && pane.Right > frame.Left && pane.Top < frame.Bottom && pane.Bottom > frame.Top) visible = true;
            return true;
        }, IntPtr.Zero);
        return visible;
    }
    public static void ClickClient(IntPtr hwnd, int x, int y) {
        Point point = new Point { X = x, Y = y };
        if (!ClientToScreen(hwnd, ref point) || WindowFromPoint(point) != hwnd) throw new InvalidOperationException("Pill is not in the owned window");
        if (!SetCursorPos(point.X, point.Y)) throw new InvalidOperationException("Cannot position mouse on pill");
        foreach (uint flags in new uint[] { 2, 4 }) {
            Input input = new Input(); input.type = 0;
            input.data.mouse = new Mouse { flags = flags };
            if (SendInput(1, new Input[] { input }, Marshal.SizeOf(typeof(Input))) != 1) throw new InvalidOperationException("Mouse SendInput failed");
            Thread.Sleep(35);
        }
    }
    public static IntPtr GetFocusedWindow(IntPtr hwnd) {
        uint pid;
        uint thread = GetWindowThreadProcessId(hwnd, out pid);
        if (thread == 0) throw new InvalidOperationException("Cannot find the owned window thread");
        GuiThreadInfo info = new GuiThreadInfo();
        info.Size = (uint)Marshal.SizeOf(typeof(GuiThreadInfo));
        if (!GetGUIThreadInfo(thread, ref info)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        return info.Focus;
    }
    public static string EditText(IntPtr hwnd) {
        if (Class(hwnd) != "Edit") throw new InvalidOperationException("Expected the owned Edit control");
        StringBuilder text = new StringBuilder(512);
        UIntPtr length;
        if (SendMessageTimeout(hwnd, 0x000D, new UIntPtr((uint)text.Capacity), text, 2, 1000, out length) == IntPtr.Zero) throw new InvalidOperationException("Cannot read Edit text within timeout");
        if (length.ToUInt64() >= (ulong)(text.Capacity - 1)) throw new InvalidOperationException("Edit text may be truncated");
        return text.ToString();
    }
    public static string Title(IntPtr hwnd) {
        StringBuilder text = new StringBuilder(512); GetWindowText(hwnd, text, text.Capacity); return text.ToString();
    }
    public static string Class(IntPtr hwnd) {
        StringBuilder text = new StringBuilder(256); GetClassName(hwnd, text, text.Capacity); return text.ToString();
    }
}
public sealed class VerifyJob : IDisposable {
    [StructLayout(LayoutKind.Sequential)] struct SecurityAttributes { public int Length; public IntPtr Descriptor; public int Inherit; }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct StartupInfo {
        public int Size; public string Reserved, Desktop, Title;
        public uint X, Y, XSize, YSize, XChars, YChars, Fill, Flags;
        public ushort Show, ReservedSize; public IntPtr ReservedBytes, Input, Output, Error;
    }
    [StructLayout(LayoutKind.Sequential)] struct ProcessInfo { public IntPtr Process, Thread; public uint Pid, Tid; }
    [StructLayout(LayoutKind.Sequential)] struct BasicLimits {
        public long ProcessTime, JobTime; public uint Flags; public UIntPtr MinWorkingSet, MaxWorkingSet;
        public uint ActiveProcessLimit; public UIntPtr Affinity; public uint Priority, Scheduling;
    }
    [StructLayout(LayoutKind.Sequential)] struct IoCounters { public ulong ReadOps, WriteOps, OtherOps, ReadBytes, WriteBytes, OtherBytes; }
    [StructLayout(LayoutKind.Sequential)] struct ExtendedLimits {
        public BasicLimits Basic; public IoCounters Io;
        public UIntPtr ProcessMemory, JobMemory, PeakProcessMemory, PeakJobMemory;
    }
    [StructLayout(LayoutKind.Sequential)] public struct Accounting {
        public long UserTime, KernelTime, PeriodUserTime, PeriodKernelTime;
        public uint PageFaults, TotalProcesses, ActiveProcesses, TerminatedProcesses;
    }
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr CreateJobObject(IntPtr attributes, string name);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool SetInformationJobObject(IntPtr job, int kind, ref ExtendedLimits limits, int size);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool QueryInformationJobObject(IntPtr job, int kind, out Accounting info, int size, IntPtr returned);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool TerminateJobObject(IntPtr job, uint code);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool CreateProcess(string app, StringBuilder command, IntPtr processAttributes, IntPtr threadAttributes, bool inherit, uint flags, IntPtr environment, string directory, ref StartupInfo startup, out ProcessInfo process);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr CreateFile(string path, uint access, uint share, ref SecurityAttributes attributes, uint disposition, uint flags, IntPtr template);
    [DllImport("kernel32.dll", SetLastError=true)] static extern uint ResumeThread(IntPtr thread);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool TerminateProcess(IntPtr process, uint code);
    [DllImport("kernel32.dll", SetLastError=true)] static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    IntPtr job;
    bool started;
    static void Check(bool success) {
        if (!success) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
    }
    public VerifyJob() {
        job = CreateJobObject(IntPtr.Zero, null);
        Check(job != IntPtr.Zero);
        try {
            ExtendedLimits limits = new ExtendedLimits();
            limits.Basic.Flags = 0x2000;
            Check(SetInformationJobObject(job, 9, ref limits, Marshal.SizeOf(typeof(ExtendedLimits))));
        } catch { Dispose(); throw; }
    }
    static IntPtr OpenLog(string path, uint access, uint disposition) {
        SecurityAttributes attributes = new SecurityAttributes();
        attributes.Length = Marshal.SizeOf(typeof(SecurityAttributes)); attributes.Inherit = 1;
        IntPtr handle = CreateFile(path, access, 3, ref attributes, disposition, 0x80, IntPtr.Zero);
        Check(handle != new IntPtr(-1));
        return handle;
    }
    public System.Diagnostics.Process Start(string exe, string directory, string stdout, string stderr) {
        return Start(exe, directory, stdout, stderr, "--single-window --no-window-restore");
    }
    public System.Diagnostics.Process Start(string exe, string directory, string stdout, string stderr, string arguments) {
        if (started || job == IntPtr.Zero) throw new InvalidOperationException("Job is not available for launch");
        IntPtr output = IntPtr.Zero, error = IntPtr.Zero, input = IntPtr.Zero;
        ProcessInfo native = new ProcessInfo();
        System.Diagnostics.Process process = null;
        try {
            output = OpenLog(stdout, 0x40000000, 2); error = OpenLog(stderr, 0x40000000, 2);
            input = OpenLog("NUL", 0x80000000, 3);
            StartupInfo startup = new StartupInfo();
            startup.Size = Marshal.SizeOf(typeof(StartupInfo)); startup.Flags = 0x100;
            startup.Input = input; startup.Output = output; startup.Error = error;
            Check(CreateProcess(exe, new StringBuilder("\"" + exe + "\" " + arguments), IntPtr.Zero, IntPtr.Zero, true, 4, IntPtr.Zero, directory, ref startup, out native));
            Check(AssignProcessToJobObject(job, native.Process));
            process = System.Diagnostics.Process.GetProcessById((int)native.Pid);
            IntPtr handle = process.Handle;
            Check(ResumeThread(native.Thread) != uint.MaxValue);
            started = true;
            return process;
        } catch {
            if (native.Process != IntPtr.Zero) {
                Check(TerminateProcess(native.Process, 1));
                if (WaitForSingleObject(native.Process, 10000) != 0) throw new TimeoutException("Suspended launch did not stop");
            }
            if (process != null) process.Dispose();
            throw;
        } finally {
            if (native.Thread != IntPtr.Zero) CloseHandle(native.Thread);
            if (native.Process != IntPtr.Zero) CloseHandle(native.Process);
            if (input != IntPtr.Zero) CloseHandle(input);
            if (output != IntPtr.Zero) CloseHandle(output);
            if (error != IntPtr.Zero) CloseHandle(error);
        }
    }
    public Accounting ReadAccounting() {
        Accounting info;
        Check(QueryInformationJobObject(job, 1, out info, Marshal.SizeOf(typeof(Accounting)), IntPtr.Zero));
        return info;
    }
    public Accounting Stop() {
        Check(TerminateJobObject(job, 1));
        System.Diagnostics.Stopwatch timer = System.Diagnostics.Stopwatch.StartNew();
        for (;;) {
            Accounting info = ReadAccounting();
            if (info.ActiveProcesses == 0) return info;
            if (timer.ElapsedMilliseconds >= 10000) throw new TimeoutException("Owned process tree did not stop");
            Thread.Sleep(100);
        }
    }
    public void Dispose() {
        if (job != IntPtr.Zero) { CloseHandle(job); job = IntPtr.Zero; }
    }
}
'@

switch ($Feature) {
        'browser-emulation' {
            $Evidence = [IO.Path]::GetFullPath($Evidence)
            New-Item -ItemType Directory -Force $Evidence | Out-Null
            $browserJob = New-Object VerifyJob
            $driver = $null
            try {
                $node = (Get-Command node.exe -ErrorAction Stop).Source
                $scriptPath = (Resolve-Path '.claude/skills/verify-multiprompt/browser-emulation.mjs').Path
                $driver = $browserJob.Start($node, $pwd.Path, (Join-Path $Evidence 'stdout.log'), (Join-Path $Evidence 'stderr.log'), ('"' + $scriptPath + '"'))
                if (-not $driver.WaitForExit(600000)) { throw 'Browser verification timed out' }
                if ($driver.ExitCode -ne 0) { throw ('Browser verification failed: ' + (Get-Content (Join-Path $Evidence 'stderr.log') -Raw)) }
            } finally {
                try {
                    $beforeStop = $browserJob.ReadAccounting()
                    $stopped = $browserJob.Stop()
                    @{ totalProcesses = $stopped.TotalProcesses; activeBeforeStop = $beforeStop.ActiveProcesses; activeAfterStop = $stopped.ActiveProcesses } | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $Evidence 'process-tree.json')
                } finally {
                    if ($null -ne $driver) { $driver.Dispose() }
                    $browserJob.Dispose()
                }
            }
            Write-Output 'VERIFIED browser-emulation with real native CLI and zero active job processes'
            return
        }
}

$Evidence = [IO.Path]::GetFullPath($Evidence)
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$scratch = Join-Path $env:RUNNER_TEMP ('multiprompt-verify-' + [guid]::NewGuid().ToString('N'))
$process = $null
$job = $null
$script:window = [IntPtr]::Zero
$script:actions = New-Object System.Collections.ArrayList
$script:scratchLinks = @()
$script:transientEvidence = New-Object System.Collections.ArrayList
$result = [ordered]@{ feature = $Feature; status = 'failed'; version = $ExpectedVersion; sha256 = $ExpectedHash; checks = @(); offlineLogin = $true; cleanup = 'pending' }
$original = @{}

function Save-Json($Value, [string]$Name) {
    ConvertTo-Json -InputObject $Value -Depth 12 | Set-Content -Encoding UTF8 (Join-Path $Evidence $Name)
}

function Record([string]$Action) {
    if ($Feature -eq 'browser-workspaces') { Write-Host ('workspace action: ' + $Action) }
    [void]$script:actions.Add(@{ time = [DateTime]::UtcNow.ToString('o'); action = $Action; title = [VerifyNative]::Title($script:window) })
    Save-Json @($script:actions.ToArray()) 'actions.json'
}

function Prepare-ScratchEvidence([string]$Path) {
    $blockedAttributes = [IO.FileAttributes]::ReadOnly -bor [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System
    foreach ($entry in Get-ChildItem -LiteralPath $Path -Force) {
        if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            $script:scratchLinks += @{ path = $entry.FullName.Substring($scratch.Length + 1); attributes = $entry.Attributes.ToString(); linkType = $entry.LinkType; target = @($entry.Target) }
            Save-Json @($script:scratchLinks) 'scratch-links.json'
            $entry.Delete()
            Record 'Cleanup: recorded and unlinked scratch reparse point without traversing its target'
        } elseif ($entry -is [IO.FileInfo] -and $entry.Name -in @('lockfile', 'LOCK', 'SingletonLock', 'SingletonCookie', 'SingletonSocket')) {
            [void]$script:transientEvidence.Add(@{ path = $entry.FullName.Substring($scratch.Length); kind = 'browser process lock; not durable evidence' })
            $deadline = [DateTime]::UtcNow.AddSeconds(20)
            while ($true) {
                try { $entry.Delete(); break } catch {
                    if ([DateTime]::UtcNow -ge $deadline) { throw }
                    Start-Sleep -Milliseconds 200
                }
            }
        } else {
            $entry.Attributes = $entry.Attributes -band (-bnot $blockedAttributes)
            if ($entry -is [IO.DirectoryInfo]) { Prepare-ScratchEvidence $entry.FullName }
        }
    }
}

function Wait-Until([scriptblock]$Condition, [string]$Description, [int]$Seconds = 20) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    $lastError = ''
    do {
        if ($process.HasExited) { throw "App exited while waiting for $Description" }
        try { if (& $Condition) { return } } catch { $lastError = $_.Exception.Message }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Missing precondition or resulting state: $Description. $lastError"
}

function Read-Session {
    $path = Join-Path $scratch 'roaming/ZigShell/session.json'
    if (Test-Path $path) {
        try { return Get-Content $path -Raw | ConvertFrom-Json } catch { return $null }
    }
    return $null
}

function Read-Inbox {
    $path = Join-Path $scratch 'roaming/ZigShell/inbox-default.json'
    if (Test-Path $path) {
        try { return Get-Content $path -Raw | ConvertFrom-Json } catch { return $null }
    }
    return $null
}

function Read-BrowserPane {
    $state = Read-Inbox
    if ($null -eq $state) { return $null }
    return @($state.shells | Where-Object { $_.sid -eq $script:browserShellId })[0]
}

function Assert-BrowserPane([string]$State, [string]$Step, [long]$PreviousId = 0) {
    Wait-Until {
        $pane = Read-BrowserPane
        $null -ne $pane -and
            (($State -eq 'open' -and $pane.browser_state -in @('opening', 'connected')) -or $pane.browser_state -eq $State) -and
            (($State -in @('open', 'opening', 'connected') -and $pane.browser_connection_id -gt $PreviousId) -or
             ($State -in @('closed', 'failed') -and $pane.browser_connection_id -eq 0))
    } "browser-pane-stuck ${Step}: $State and connection identity" 25
    $pane = Read-BrowserPane
    if ($pane.browser_window_id -ne 0) { throw 'Unexpected browser extension connection in the no-extension journey' }
    Save-Json $pane ("browser-pane-$Step.json")
    $result.checks += @{ name = "browser-pane-stuck $Step"; state = $pane.browser_state; connectionId = $pane.browser_connection_id }
    Write-Host "browser-pane-stuck $Step PASS"
    return $pane
}

function Focus-BrowserPaneOwner([string]$Step, [long]$ConnectionId) {
    Wait-Until {
        $pane = Read-BrowserPane
        $null -ne $pane -and $pane.browser_state -eq 'connected' -and
            $pane.browser_connection_id -eq $ConnectionId -and [VerifyNative]::PaneVisible($script:window)
    } "browser-pane-stuck ${Step}: docked pane ready for main-window activation" 25
    Doctor
    Record "Activate main window after browser-pane-stuck ${Step} docking"
    [void][VerifyNative]::SetForegroundWindow($script:window)
    Wait-Until { [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window } "browser-pane-stuck ${Step}: main window is foreground" 5
}

function Open-BrowserPane([string]$Step, [long]$PreviousId = 0) {
    Palette 'open browser'
    Press @(0x0D) 'Enter: Open Browser Pane'
    $pane = Assert-BrowserPane 'open' $Step $PreviousId
    Focus-BrowserPaneOwner $Step $pane.browser_connection_id
    return $pane
}

function Assert-ConnectedPaneStaysVisible([long]$ConnectionId) {
    $connected = Assert-BrowserPane 'connected' 'connected-pane-docked' ($ConnectionId - 1)
    if ($connected.browser_connection_id -ne $ConnectionId) { throw 'Docking replaced the browser connection' }
    Wait-Until { [VerifyNative]::PaneVisible($script:window) } 'docked browser pane is visible inside the app'
    $deadline = [DateTime]::UtcNow.AddSeconds(21)
    do {
        $pane = Read-BrowserPane
        if ($null -eq $pane -or $pane.browser_state -ne 'connected' -or $pane.browser_connection_id -ne $ConnectionId -or
            $pane.browser_window_id -ne 0 -or -not [VerifyNative]::PaneVisible($script:window)) {
            throw 'Connected pane closed, hid, or lost its identity past the opening deadline'
        }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $deadline)
    $pane = Assert-BrowserPane 'connected' 'connected-pane-stays-visible' ($ConnectionId - 1)
    Snapshot 'connected'
}

function Doctor {
    $process.Refresh()
    if ($process.HasExited -or $script:window -eq [IntPtr]::Zero) { throw 'Doctor: owned app window missing' }
    [uint32]$owner = 0
    [void][VerifyNative]::GetWindowThreadProcessId($script:window, [ref]$owner)
    if ($owner -ne $process.Id -or [VerifyNative]::Class($script:window) -ne 'ZigShell') { throw 'Doctor: window ownership mismatch' }
    if ($process.Path -ne $Exe -or (Get-FileHash $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Doctor: executable identity mismatch' }
    $title = [VerifyNative]::Title($script:window)
    if ($title -notmatch ('multiprompt v' + [regex]::Escape($ExpectedVersion) + '(?:\s|$)')) { throw "Doctor: wrong version in $title" }
    $element = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    if ($element.Current.ProcessId -ne $process.Id -or $element.Current.IsOffscreen) { throw 'Doctor: UI Automation cannot see owned window' }
    $state = Read-Inbox
    if ($null -eq $state -or @($state.shells).Count -lt 1) { throw 'Doctor: no usable initial shell published' }
    Save-Json @{ pid = $process.Id; hwnd = $script:window.ToInt64(); title = $title; class = $element.Current.ClassName; version = $ExpectedVersion; sha256 = $ExpectedHash; shellCount = @($state.shells).Count; data = $scratch } 'doctor.json'
}

function Snapshot([string]$Name) {
    $focus = @{ foreground = [VerifyNative]::GetForegroundWindow().ToInt64() }
    try { $focus.native = [VerifyNative]::GetFocusedWindow($script:window).ToInt64() } catch { $focus.nativeError = $_.Exception.Message }
    try {
        $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
        $focus.uia = @{ handle = $focused.Current.NativeWindowHandle; pid = $focused.Current.ProcessId; class = $focused.Current.ClassName }
    } catch { $focus.uiaError = $_.Exception.Message }
    Save-Json $focus ($Name + '.focus.json')
    $element = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    $nodes = $element.FindAll([System.Windows.Automation.TreeScope]::Subtree, [System.Windows.Automation.Condition]::TrueCondition)
    $tree = foreach ($node in $nodes) {
        @{ name = $node.Current.Name; class = $node.Current.ClassName; type = $node.Current.ControlType.ProgrammaticName; pid = $node.Current.ProcessId; handle = $node.Current.NativeWindowHandle }
    }
    Save-Json @($tree) ($Name + '.uia.json')
    [void][VerifyNative]::DwmFlush()
    $rect = New-Object VerifyNative+Rect
    if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$rect)) { throw 'Window rectangle unavailable' }
    $bitmap = New-Object Drawing.Bitmap(($rect.Right - $rect.Left), ($rect.Bottom - $rect.Top))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
        $bitmap.Save((Join-Path $Evidence ($Name + '.png')), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}

function Assert-Foreground {
    if ([VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -ne $script:window) { throw 'Refusing input: owned app is not foreground' }
}

function Press([int[]]$Keys, [string]$Label) {
    if ($Feature -eq 'browser-workspaces') { Focus-WorkspaceFrame }
    Doctor
    Wait-Until {
        [void][VerifyNative]::SetForegroundWindow($script:window)
        [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window
    } 'owned app foreground for keyboard input'
    Assert-Foreground
    Record $Label
    [VerifyNative]::Chord($Keys)
}

function Type-Text([string]$Text) {
    Doctor
    Assert-Foreground
    Record ('Type ' + $Text)
    [VerifyNative]::Text($Text)
}

function Click-WorkspacePill([int]$Workspace) {
    Wait-Until {
        $state = Read-Session
        $null -ne $state -and $state.single_window -and $state.PSObject.Properties['hide_pills'] -and -not $state.hide_pills -and -not ($state.PSObject.Properties['hide_sidebar'] -and $state.hide_sidebar) -and -not ($state.PSObject.Properties['sidebar_collapsed'] -and $state.sidebar_collapsed) -and $Workspace -ge 0 -and $Workspace -lt $state.workspace_count -and @($state.workspaces | Where-Object { $_.PSObject.Properties['snoozed'] -and $_.snoozed }).Count -eq 0 -and (-not $state.PSObject.Properties['ui_scale'] -or $state.ui_scale -eq 100)
    } "visible unsnoozed workspace pill $Workspace at default layout"
    Doctor
    Assert-Foreground
    Record ("Click workspace pill for stored workspace $Workspace")
    [void][VerifyNative]::DwmFlush()
    [VerifyNative]::ClickClient($script:window, (8 + ($Workspace + 1) * 29 + 12), 17)
}

function Focus-Palette([string]$Query, [int]$Target) {
    $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
    $start = (Get-Content $log -Raw).Length
    Press @(0x11, 0x4B) 'Ctrl+K: open command palette'
    Wait-Until {
        $trace = (Get-Content $log -Raw).Substring($start)
        $trace -match '\[palette\] ready chars=0 count=\d+ target=\d+' -and [VerifyNative]::GetForegroundWindow() -eq $script:window -and [VerifyNative]::GetFocusedWindow($script:window) -eq $script:window
    } 'command palette initialized and owned frame focused'
    Type-Text $Query
    Wait-Until {
        (Get-Content $log -Raw).Substring($start) -match ('\[palette\] ready chars=' + $Query.Length + ' count=[1-9]\d* target=' + $Target + '(?:\r?\n|$)')
    } "palette query consumed and expected command $Target selected"
}

function Wait-WorkspaceSurface([int]$Workspace, [int]$Tab, [bool]$Chat, [int]$Composer = 0) {
    Wait-Until {
        $state = Read-Session
        if ($null -eq $state -or $state.active_workspace -ne $Workspace -or $state.active_tab -ne $Tab -or $state.tabs[$Tab].kind -ne 'cmd' -or [bool]($state.tabs[$Tab].PSObject.Properties['cv'] -and $state.tabs[$Tab].cv) -ne $Chat) { return $false }
        $foreground = [VerifyNative]::GetForegroundWindow()
        if ([VerifyNative]::GetAncestor($foreground, 2) -ne $script:window) { return $false }
        if (-not $Chat) {
            return [VerifyNative]::Class($foreground) -eq 'ConsoleWindowClass' -and [VerifyNative]::Title($foreground).EndsWith(('ZigShell-' + $state.tabs[$Tab].shell_id), [StringComparison]::Ordinal)
        }
        $element = [System.Windows.Automation.AutomationElement]::FromHandle([IntPtr]$Composer)
        $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
        $foreground -eq $script:window -and $element.Current.ProcessId -eq $process.Id -and -not $element.Current.IsOffscreen -and $focused.Current.NativeWindowHandle -eq $Composer
    } "workspace $Workspace session $Tab Chat View=$Chat visible and input ready"
}

function Wait-ConsoleText([string]$Command) {
    Wait-Until {
        $foreground = [VerifyNative]::GetForegroundWindow()
        if ([VerifyNative]::GetAncestor($foreground, 2) -ne $script:window -or [VerifyNative]::Class($foreground) -ne 'ConsoleWindowClass') { return $false }
        $console = [System.Windows.Automation.AutomationElement]::FromHandle($foreground)
        $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Document)
        $document = $console.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
        if ($null -eq $document) { return $false }
        $pattern = $document.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern)
        $text = $pattern.DocumentRange.GetText(-1) -replace '[\r\n]', ''
        $text.TrimEnd().EndsWith($Command, [StringComparison]::Ordinal)
    } "console visibly contains staged command: $Command"
}

function Focus-WorkspaceShell {
    Doctor
    Record 'Focus the verified owned app frame for workspace keyboard commands'
    Wait-Until {
        [VerifyNative]::FocusOwnedWindow($script:window, $process.Id, $script:window)
        $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
        if ($null -eq $focused) { return $false }
        $owner = [int]$focused.Current.ProcessId
        $owner -gt 0 -and [Diagnostics.Process]::GetProcessById($owner).ProcessName -ne 'msedge'
    } 'workspace shell owns keyboard input'
}

function Focus-WorkspaceBrowser([string]$Root) {
    $script:bookmarkWindow = [IntPtr]::Zero
    Wait-Until {
        $browsers = @(Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($Root) -and $_.CommandLine -notlike '*--type=*' })
        if ($browsers.Count -ne 1) { return $false }
        $element = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
        $nodes = $element.FindAll([System.Windows.Automation.TreeScope]::Subtree, [System.Windows.Automation.Condition]::TrueCondition)
        foreach ($node in $nodes) {
            if ($node.Current.ProcessId -ne $browsers[0].ProcessId -or $node.Current.ClassName -ne 'Chrome_WidgetWin_1' -or $node.Current.NativeWindowHandle -eq 0) { continue }
            $candidate = [IntPtr]$node.Current.NativeWindowHandle
            if ([VerifyNative]::GetAncestor($candidate, 3) -ne $script:window) { continue }
            $script:bookmarkWindow = $candidate
            $script:bookmarkPid = [int]$browsers[0].ProcessId
            return $true
        }
        return $false
    } 'exact profile browser HWND belongs to the owned app' 60
    Record 'Focus the actual owned Edge window for the keyboard favorite action'
    Wait-Until {
        [VerifyNative]::FocusOwnedWindow($script:bookmarkWindow, $script:bookmarkPid, $script:window)
        [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:bookmarkWindow
    } 'exact workspace browser owns keyboard input'
}

function Press-WorkspaceBrowser([int[]]$Keys, [string]$Label) {
    Doctor
    Wait-Until {
        [VerifyNative]::FocusOwnedWindow($script:bookmarkWindow, $script:bookmarkPid, $script:window)
        $foreground = [VerifyNative]::GetForegroundWindow()
        [VerifyNative]::GetAncestor($foreground, 2) -eq $script:bookmarkWindow -and
            [VerifyNative]::GetAncestor($foreground, 3) -eq $script:window
    } 'exact owned profile browser foreground for keyboard input'
    Record $Label
    [VerifyNative]::Chord($Keys)
}

function Focus-WorkspaceFrame {
    Doctor
    Record 'Activate the exact owned app frame before workspace keyboard input'
    Wait-Until {
        [VerifyNative]::FocusOwnedWindow($script:window, $process.Id, $script:window)
        [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window
    } 'exact owned workspace frame receives keyboard focus'
}

function Palette([string]$Query) {
    if ($Feature -eq 'browser-workspaces') { Focus-WorkspaceFrame }
    Press @(0x11, 0x4B) 'Ctrl+K: open command palette'
    Type-Text $Query
}

function Invoke-Zsb([string[]]$Arguments, [int]$Port, [string]$Name, [string]$Session = 'workspace') {
    Doctor
    Assert-Foreground
    Record ('zsb ' + ($Arguments -join ' '))
    $payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($Arguments -join [char]0x1F) + [char]0x1F))
    $wire = [Text.Encoding]::UTF8.GetBytes("ZSB:workspace:${payload}`n")
    if ($Session -ne 'workspace') { $wire = [Text.Encoding]::UTF8.GetBytes("ZSB:${Session}:${payload}`n") }
    [IO.File]::WriteAllBytes((Join-Path $Evidence ($Name + '.request.bin')), $wire)
    $client = New-Object Net.Sockets.TcpClient
    $reply = New-Object IO.MemoryStream
    try {
        $connecting = $client.ConnectAsync('127.0.0.1', $Port)
        if (-not $connecting.Wait(5000)) { throw 'zsb local bridge connection timed out' }
        [void]$connecting.GetAwaiter().GetResult()
        $stream = $client.GetStream()
        $stream.WriteTimeout = 5000
        $stream.Write($wire, 0, $wire.Length)
        $timer = [Diagnostics.Stopwatch]::StartNew()
        $buffer = New-Object byte[] 65536
        do {
            $remaining = 90000 - $timer.ElapsedMilliseconds
            if ($remaining -le 0) { throw 'zsb reply exceeded 90 seconds' }
            $stream.ReadTimeout = [int]$remaining
            $count = $stream.Read($buffer, 0, $buffer.Length)
            if ($reply.Length + $count -gt 16 * 1024 * 1024) { throw 'zsb reply exceeded 16 MiB' }
            $reply.Write($buffer, 0, $count)
        } while ($count -gt 0)
        $raw = [Text.Encoding]::UTF8.GetString($reply.ToArray())
        [IO.File]::WriteAllText((Join-Path $Evidence ($Name + '.reply.json')), $raw)
        $response = $raw | ConvertFrom-Json
        if ($response.ok -ne $true) { throw "zsb rejected $Name`: $raw" }
        return $response
    } finally { $reply.Dispose(); $client.Dispose() }
}

function Register-WorkspaceBridge([string]$Root) {
    $script:extensionIds = @()
    Wait-Until {
        foreach ($name in @('Preferences', 'Secure Preferences')) {
            $path = Join-Path $Root ('Default/' + $name)
            if (-not (Test-Path $path)) { continue }
            $saved = Get-Content $path -Raw | ConvertFrom-Json
            if (-not $saved.PSObject.Properties['extensions'] -or -not $saved.extensions.PSObject.Properties['settings']) { continue }
            $script:extensionIds = @($saved.extensions.settings.PSObject.Properties | Where-Object { $_.Value.PSObject.Properties['path'] -and $_.Value.path -eq $script:extensionPath } | ForEach-Object { $_.Name })
            if ($script:extensionIds.Count -eq 1) { return $true }
        }
        return $false
    } 'real unpacked extension identity saved by Edge' 60
    $manifest = Join-Path $scratch 'native-host.json'
    $hostExe = Join-Path (Split-Path $Exe) 'zigshell-bridge.exe'
    if (-not (Test-Path $hostExe)) { throw 'Matching native host executable missing' }
    $value = @{ name = 'com.zigshell.bridge'; description = 'GitHub isolated workspace verification'; path = $hostExe; type = 'stdio'; allowed_origins = @('chrome-extension://' + $script:extensionIds[0] + '/') }
    [IO.File]::WriteAllText($manifest, ($value | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
    $registry = 'HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\com.zigshell.bridge'
    if (Test-Path $registry) { throw 'Fresh runner already has a native host registration' }
    New-Item -Path $registry -Force | Out-Null
    $script:nativeRegistry = $registry
    Set-Item -Path $script:nativeRegistry -Value $manifest
    Record ('Registered real Edge extension native host: ' + $script:extensionIds[0])
}

function Enable-WorkspaceExtension([string]$Root, [int]$Index) {
    Focus-WorkspaceBrowser $Root
    Press-WorkspaceBrowser @(0x12, 0x44) 'Alt+D: focus the actual Edge address bar'
    Doctor
    $foreground = [VerifyNative]::GetForegroundWindow()
    if ([VerifyNative]::GetAncestor($foreground, 2) -ne $script:bookmarkWindow -or [VerifyNative]::GetAncestor($foreground, 3) -ne $script:window) { throw 'Refusing URL input: exact owned profile browser is not foreground' }
    Record 'Type edge://extensions/ in the real Edge address bar'
    [VerifyNative]::Text('edge://extensions/')
    Press-WorkspaceBrowser @(0x0D) 'Enter: open the actual Edge Extensions page'
    Wait-Until {
        $browser = [System.Windows.Automation.AutomationElement]::FromHandle($script:bookmarkWindow)
        $nodes = $browser.FindAll([System.Windows.Automation.TreeScope]::Subtree, [System.Windows.Automation.Condition]::TrueCondition)
        foreach ($node in $nodes) {
            if ($node.Current.Name -ne 'Extensions menu' -or $node.Current.ProcessId -ne $script:bookmarkPid) { continue }
            Doctor
            if ($Index -eq 0) { Snapshot 'extensions-action' }
            Record ('Open the actual Edge Extensions sidebar for profile ' + $Index)
            $menu = $node.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
            $menu.Invoke()
            return $true
        }
        return $false
    } 'open the narrow Edge Extensions navigation menu' 60
    Wait-Until {
        $browser = [System.Windows.Automation.AutomationElement]::FromHandle($script:bookmarkWindow)
        $nodes = $browser.FindAll([System.Windows.Automation.TreeScope]::Subtree, [System.Windows.Automation.Condition]::TrueCondition)
        foreach ($node in $nodes) {
            if ($node.Current.Name -ne 'Developer mode' -or $node.Current.ProcessId -ne $script:bookmarkPid) { continue }
            $toggle = $null
            if (-not $node.TryGetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern, [ref]$toggle)) { continue }
            if ($toggle.Current.ToggleState -eq [System.Windows.Automation.ToggleState]::Off) {
                Doctor
                Record ('Enable Developer mode through the visible Edge Extensions toggle for profile ' + $Index)
                $toggle.Toggle()
            }
            return $toggle.Current.ToggleState -eq [System.Windows.Automation.ToggleState]::On
        }
        return $false
    } 'real Edge Developer mode toggle is on' 60
    Snapshot ('extensions-enabled-' + $Index)
    $token = 'e-' + (Split-Path $Root -Leaf)
    $pipe = '\\.\pipe\multiprompt-browser-isolated-' + $token
    Wait-Until { [IO.Directory]::GetFiles('\\.\pipe\') -contains $pipe } 'enabled unpacked extension registered its actual workspace native pipe' 60
    $script:extensionSetups += @{ root = $Root; profileToken = $token; pipe = $pipe; developerMode = 'On'; extensionId = $script:extensionIds[0]; pid = $script:bookmarkPid; hwnd = $script:bookmarkWindow.ToInt64() }
    Save-Json @($script:extensionSetups) 'workspace-extension-setup.json'
}

function Read-BookmarkUrls($Node) {
    if ($null -eq $Node) { return }
    if ($Node.PSObject.Properties['url']) { [string]$Node.url }
    if ($Node.PSObject.Properties['children']) { foreach ($child in $Node.children) { Read-BookmarkUrls $child } }
}

function Assert-WorkspaceProfile([string]$Stage, [string]$Id, [string]$Root, [string]$Bookmark) {
    Wait-Until {
        $state = Read-Session
        if ($null -eq $state) { return $false }
        if ($state.PSObject.Properties['single_window'] -and $state.single_window) {
            if ($state.workspaces[$state.active_workspace].wid -cne $Id) { return $false }
        } elseif (-not $state.PSObject.Properties['workspace_id'] -or $state.workspace_id -cne $Id) { return $false }
        if ($state.tabs[$state.active_tab].burl -cne $Bookmark) { return $false }
        $file = Join-Path $Root 'Default/Bookmarks'
        if (-not (Test-Path $file)) { return $false }
        $bookmarks = Get-Content $file -Raw | ConvertFrom-Json
        $urls = @($bookmarks.roots.PSObject.Properties | ForEach-Object { Read-BookmarkUrls $_.Value })
        if ($Bookmark -notin $urls) { return $false }
        $live = @(Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($Root) -and $_.CommandLine -notlike '*--type=*' })
        if ($live.Count -ne 1) { return $false }
        $script:profileObservation = @{ stage = $Stage; workspaceId = $Id; root = $Root; bookmarkUrls = $urls; browserPid = $live[0].ProcessId; commandLine = $live[0].CommandLine; state = $state }
        return $true
    } ($Stage + ': same saved workspace ID, live profile root and user-created bookmark') 60
    if (@(Get-ChildItem (Split-Path $Root) -Directory).Count -ne 6) { throw 'Lifecycle created an unexpected profile root' }
    $script:profileObservations += $script:profileObservation
    Save-Json $script:profileObservations 'workspace-lifecycle.json'
    [void][VerifyNative]::SetForegroundWindow($script:window)
    Wait-Until { [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 3) -eq $script:window } 'original owned workspace foreground for lifecycle screenshot'
    Snapshot $Stage
}

function Select-Theme([string]$Theme, [string]$ActionShot) {
    Palette 'themes'
    Press @(0x0D) 'Enter: Themes...'
    Type-Text $Theme
    Snapshot $ActionShot
    Press @(0x0D) ('Enter: choose ' + $Theme)
    $path = Join-Path $scratch 'roaming/ZigShell/theme-mode.txt'
    Wait-Until { (Test-Path $path) -and (Get-Content $path -Raw).Trim() -eq $Theme } "app-written theme-mode.txt equals $Theme"
    Snapshot ($ActionShot + '-selected')
    Press @(0x1B) 'Esc: close Themes palette'
}

function Sidebar-Luminance([string]$Name) {
    $image = [Drawing.Bitmap]::FromFile((Join-Path $Evidence ($Name + '.png')))
    try {
        $total = 0.0
        $count = 0
        for ($x = 25; $x -lt 130; $x += 7) {
            for ($y = 170; $y -lt 550; $y += 7) {
                $pixel = $image.GetPixel($x, $y)
                $total += ($pixel.R + $pixel.G + $pixel.B) / 3.0
                $count++
            }
        }
        return $total / $count
    } finally { $image.Dispose() }
}

try {
    if ((Get-FileHash $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Executable checksum mismatch before launch' }
    $bytes = [IO.File]::ReadAllBytes($Exe)
    if (-not [Text.Encoding]::ASCII.GetString($bytes).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable build/version marker mismatch' }
    foreach ($name in @('APPDATA', 'LOCALAPPDATA', 'USERPROFILE', 'HOME', 'MULTIPROMPT_NO_LOGIN', 'ZIGSHELL_DEBUG', 'IGSH_246')) {
        $original[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    foreach ($directory in @('roaming', 'local', 'profile')) { New-Item -ItemType Directory -Force (Join-Path $scratch $directory) | Out-Null }
    $env:APPDATA = Join-Path $scratch 'roaming'
    $env:LOCALAPPDATA = Join-Path $scratch 'local'
    $env:USERPROFILE = Join-Path $scratch 'profile'
    $env:HOME = $env:USERPROFILE
    $env:IGSH_246 = '0'
    $env:MULTIPROMPT_NO_LOGIN = '1'
    $env:ZIGSHELL_DEBUG = '1'
    if ($Feature -eq 'browser-workspaces') {
        $script:extensionPath = Join-Path $env:USERPROFILE 'Documents/GitHub/zigshell/extension'
        New-Item -ItemType Directory -Force (Split-Path $script:extensionPath) | Out-Null
        Copy-Item (Join-Path $PSScriptRoot '../../../extension') $script:extensionPath -Recurse
    }
    $job = New-Object VerifyJob
    $process = $job.Start($Exe, $scratch, (Join-Path $Evidence 'stdout.log'), (Join-Path $Evidence 'stderr.log'))
    Wait-Until {
        $process.Refresh()
        $script:window = $process.MainWindowHandle
        $state = Read-Inbox
        $script:window -ne [IntPtr]::Zero -and $null -ne $state -and @($state.shells).Count -gt 0
    } 'owned main window and initialized CMD session' 60
    [void][VerifyNative]::ShowWindow($script:window, 9)
    [void][VerifyNative]::MoveWindow($script:window, 10, 10, 1000, 650, $true)
    [void][VerifyNative]::SetForegroundWindow($script:window)
    Wait-Until { [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window } 'foreground main window'
    Doctor
    Record 'Launch complete; read-only Doctor passed'
    Snapshot 'before'
    switch ($Feature) {
        'appearance' {
            Select-Theme 'dark' 'baseline-dark-action'
            Snapshot 'before'
            Select-Theme 'light' 'action'
            Snapshot 'after'
            $dark = Sidebar-Luminance 'before'
            $light = Sidebar-Luminance 'after'
            if ($light -lt $dark + 60) { throw "Visible sidebar did not become light: $dark -> $light" }
            $result.checks += @{ name = 'dark-to-light'; darkLuminance = $dark; lightLuminance = $light; savedTheme = 'light' }
        }
        'chat-tables' {
            $command = 'powershell -nop -c "''250c 2500 252c 2500 2510'',''2502 0041 2502 0042 2502'',''251c 2500 253c 2500 2524'',''2502 0031 2502 0032 2502'',''2514 2500 2534 2500 2518''|ForEach-Object{-join($_.Split('' '')|ForEach-Object{[char][Convert]::ToInt32($_,16)})}"'
            $command += ' && echo table-ready>"' + (Join-Path $scratch 'table-ready.txt') + '"'
            Type-Text $command
            Press @(0x0D) 'Enter: print table and persist console completion marker in CMD'
            Wait-Until { Test-Path (Join-Path $scratch 'table-ready.txt') } 'real console table command completed'
            Press @(0x12, 0x43) 'Alt+C: open formatted Chat View'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 -and $state.active_tab -ge 0 -and $state.active_tab -lt @($state.tabs).Count } 'saved initial table tab'
            $tableTab = (Read-Session).active_tab
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            Wait-Until { (Test-Path $log) -and (Get-Content $log -Raw) -match 'CHAT_TABLE rows=1 columns=2 .*source=box' } 'formatted table built from real console output'
            Wait-Until { (Read-Session).tabs[$tableTab].cv } 'Chat View preference persisted for table tab'
            Snapshot 'before'
            $buildsBefore = @([regex]::Matches((Get-Content $log -Raw), 'CHAT_TABLE rows=1 columns=2 .*source=box')).Count
            $tabsBefore = @((Read-Session).tabs).Count
            Palette 'new cmd'
            Snapshot 'action'
            Press @(0x0D) 'Enter: create another real CMD tab'
            Wait-Until { @((Read-Session).tabs).Count -eq $tabsBefore + 1 -and (Read-Session).active_tab -ne $tableTab } 'new CMD tab active and saved'
            Snapshot 'away'
            $awayLogLength = (Get-Content $log -Raw).Length
            Press @(0x11, 0x10, 0x09) 'Ctrl+Shift+Tab: return to table Chat View'
            Wait-Until { (Read-Session).active_tab -eq $tableTab -and (Read-Session).tabs[$tableTab].cv } 'original Chat View tab active again'
            Wait-Until { $text = Get-Content $log -Raw; $text.Length -gt $awayLogLength -and $text.Substring($awayLogLength) -match '\[switch\] chat painted in' } 'returned Chat View painted'
            Snapshot 'after'
            $buildsAfter = @([regex]::Matches((Get-Content $log -Raw), 'CHAT_TABLE rows=1 columns=2 .*source=box')).Count
            if ($buildsAfter -ne $buildsBefore) { throw "Unchanged table rebuilt across tab switch: $buildsBefore -> $buildsAfter" }
            $result.checks += @{ name = 'console-table-switch-return'; tableTab = $tableTab; buildsBefore = $buildsBefore; buildsAfter = $buildsAfter; marker = (Get-Content (Join-Path $scratch 'table-ready.txt') -Raw).Trim(); chatViewSaved = $true }
        }
        'sessions' {
            $before = @( (Read-Session).tabs ).Count
            Palette 'new cmd'
            Snapshot 'action'
            Press @(0x0D) 'Enter: New CMD shell'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq $before + 1 } 'new CMD tab saved'
            Press @(0x71) 'F2: rename active tab'
            Press @(0x11, 0x41) 'Ctrl+A: replace tab name'
            Type-Text 'Verification session'
            Press @(0x0D) 'Enter: save tab name'
            Wait-Until { @((Read-Session).tabs | Where-Object { $_.name -eq 'Verification session' }).Count -eq 1 } 'renamed tab persisted'
            $marker = Join-Path $scratch 'user-created.txt'
            Type-Text ('echo verified-from-real-cmd>"' + $marker + '"')
            Press @(0x0D) 'Enter: execute shell command'
            Wait-Until { (Test-Path $marker) -and (Get-Content $marker -Raw).Trim() -eq 'verified-from-real-cmd' } 'real console command wrote file'
            $result.checks += @{ name = 'create-rename-execute'; tabsBefore = $before; tabsAfter = @((Read-Session).tabs).Count; marker = (Get-Content $marker -Raw).Trim() }
            Snapshot 'after'
        }
        'workspaces' {
            $before = (Read-Session).workspace_count
            Snapshot 'action'
            Press @(0x11, 0x4E) 'Ctrl+N: create workspace'
            Wait-Until { (Read-Session).workspace_count -eq $before + 1 } 'workspace and CMD tab persisted'
            Snapshot 'created'
            $created = (Read-Session).active_workspace
            Press @(0x12, 0x32) 'Alt+2: return to first stored workspace'
            Wait-Until { (Read-Session).active_workspace -eq 0 } 'first workspace active'
            Press @(0x12, 0x27) 'Alt+Right: cycle to new workspace'
            Wait-Until { (Read-Session).active_workspace -eq $created } 'new workspace active again'
            $result.checks += @{ name = 'create-switch-return'; workspacesBefore = $before; workspacesAfter = (Read-Session).workspace_count; activeWorkspace = $created; title = [VerifyNative]::Title($script:window) }
            Snapshot 'after'
        }
        'session-open' {
            $result.sshBoundary = @{ verified = $false; expected = 'No remote credentials or tmux server are supplied; only background tab creation and idempotency are verified'; observed = 'pending'; tabRemoved = $null }
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 -and $state.active_workspace -ge 0 -and $state.active_tab -ge 0 } 'saved workspace and initial active tab'
            $initial = Read-Session
            if (@($initial.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'verify-1' }).Count -ne 0) { throw 'verify-1 already exists before the journey' }
            $initialGroupIds = @()
            if ($initial.PSObject.Properties['groups']) { $initialGroupIds = @($initial.groups | ForEach-Object { $_.id }) }
            $groupCount = $initialGroupIds.Count
            Palette 'move to group'
            Press @(0x0D) 'Enter: Move to Group submenu'
            Type-Text 'new group'
            Snapshot 'group-action'
            Press @(0x0D) 'Enter: New group'
            Wait-Until {
                $state = Read-Session
                if ($null -eq $state -or -not $state.PSObject.Properties['groups'] -or @($state.groups).Count -ne $groupCount + 1) { return $false }
                $newGroups = @($state.groups | Where-Object { $_.id -notin $initialGroupIds })
                $newGroups.Count -eq 1 -and -not [string]::IsNullOrWhiteSpace($newGroups[0].name) -and $state.tabs[$initial.active_tab].group_id -eq $newGroups[0].id
            } 'user-created group name and original tab membership saved'
            $baseline = Read-Session
            $group = @($baseline.groups | Where-Object { $_.id -notin $initialGroupIds })[0]
            $result.groupSetup = @{ name = $group.name; id = $group.id; customNameExercised = $false; reason = 'Palette creation does not reliably focus an inline rename editor; using the default name read from session.json' }
            Record ('Use persisted group ' + $group.name + '; custom name path not exercised')
            $workspaceBefore = $baseline.active_workspace
            $activeTabBefore = $baseline.active_tab
            $activeBefore = $baseline.tabs[$activeTabBefore]
            if ($activeBefore.group_id -ne $group.id) { throw 'New group does not contain the original active tab' }
            $titleBefore = [VerifyNative]::Title($script:window)
            $foregroundBefore = [VerifyNative]::GetForegroundWindow()
            $foregroundTitleBefore = [VerifyNative]::Title($foregroundBefore)
            Save-Json $baseline 'session-before.json'
            Snapshot 'before'
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $script:zsbPort = 0
            Wait-Until {
                if (-not (Test-Path $log)) { return $false }
                $listener = [regex]::Match((Get-Content $log -Raw), 'notify-listener: tunnel-inbound listening port=(\d+) err=0')
                if (-not $listener.Success) { return $false }
                $script:zsbPort = [int]$listener.Groups[1].Value
                @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort $script:zsbPort | Where-Object { $_.OwningProcess -eq $process.Id }).Count -eq 1
            } 'app-owned loopback tunnel-inbound listener' 30
            $listed = Invoke-Zsb @('workspace-list') $script:zsbPort 'workspace-list'
            $workspaceName = $baseline.workspaces[$workspaceBefore].name
            if (-not $workspaceName) { $workspaceName = 'Workspace ' + ($workspaceBefore + 1) }
            $workspaces = @($listed.workspaces | Where-Object { $_.id -eq $workspaceBefore -and $_.name -ceq $workspaceName -and $_.active -eq $true })
            if ($workspaces.Count -ne 1) { throw 'workspace-list did not report the saved active workspace' }
            $listedGroups = @($workspaces[0].groups | Where-Object { $_.id -eq $group.id -and $_.name -ceq $group.name })
            if ($listedGroups.Count -ne 1) { throw 'workspace-list did not report the user-created group' }
            if (@($listed.hosts).Count -lt 1 -or -not ($listed.hosts[0] -is [string]) -or -not $listed.hosts[0]) { throw 'workspace-list reported no usable host name' }
            $hostName = $listed.hosts[0]
            $openArgs = @('session-open', '--workspace', $workspaceName, '--group', $group.name, '--host', $hostName, '--tmux', 'verify-1', '--name', 'Verify 1')
            $assertSaved = {
                $state = Read-Session
                if ($null -eq $state) { throw 'session.json is not readable' }
                $tabs = @($state.tabs | Where-Object { $_.PSObject.Properties['tmux_session'] -and $_.tmux_session -ceq 'verify-1' })
                if ($tabs.Count -ne 1 -or @($state.tabs).Count -ne @($baseline.tabs).Count + 1) { throw 'Expected exactly one new verify-1 tab' }
                $tab = $tabs[0]
                $tabWorkspace = 0
                if ($tab.PSObject.Properties['workspace']) { $tabWorkspace = $tab.workspace }
                if ($tab.kind -cne 'tmux' -or $tab.name -cne 'Verify 1' -or $tab.group_id -ne $group.id -or $tabWorkspace -ne $workspaceBefore) { throw 'Saved tmux tab title, group or workspace mismatch' }
                if (@($state.groups).Count -ne $groupCount + 1 -or @($state.groups | Where-Object { $_.id -eq $group.id -and $_.name -ceq $group.name }).Count -ne 1) { throw 'Saved group changed' }
                if ($state.active_workspace -ne $workspaceBefore -or $state.active_tab -ne $activeTabBefore -or $state.tabs[$activeTabBefore].name -cne $activeBefore.name -or $state.tabs[$activeTabBefore].kind -cne $activeBefore.kind) { throw 'Background request changed the active workspace or active tab' }
                if ([VerifyNative]::GetForegroundWindow() -ne $foregroundBefore -or [VerifyNative]::Title($foregroundBefore) -cne $foregroundTitleBefore -or [VerifyNative]::Title($script:window) -cne $titleBefore) { throw 'Background request changed foreground window or title' }
                $script:sessionOpenSaved = $state
                return $true
            }
            Snapshot 'action'
            $created = Invoke-Zsb $openArgs $script:zsbPort 'session-open-created'
            if ($created.created -ne $true -or $created.tab -le 0) { throw 'session-open did not reply ok/created with a tab ID' }
            Wait-Until $assertSaved 'exact saved background tab and unchanged selection after creation'
            Save-Json $script:sessionOpenSaved 'session-created.json'
            $repeated = Invoke-Zsb $openArgs $script:zsbPort 'session-open-repeated'
            if ($repeated.existing -ne $true -or $repeated.tab -ne $created.tab -or $repeated.workspace -cne $workspaceName) { throw 'Repeated session-open was not an existing:true no-op for the same tab and workspace' }
            Wait-Until $assertSaved 'repeat no-op with exactly one saved tab and unchanged selection'
            Save-Json $script:sessionOpenSaved 'session-repeated.json'
            $script:sshFailure = $null
            Wait-Until {
                $failure = [regex]::Match((Get-Content $log -Raw), ('ssh-reconnect disconnect id=' + $created.tab + ' reason=(process-exit-event|process-exit-poll|startup-console-missing) exit_code=(\d+) known=true'))
                if (-not $failure.Success -or [uint64]$failure.Groups[2].Value -in @(0, 259)) { return $false }
                $script:sshFailure = @{ reason = $failure.Groups[1].Value; exitCode = [uint64]$failure.Groups[2].Value; logLine = $failure.Value }
                return $true
            } 'observed failed SSH attach for the created tab' 60
            $result.sshBoundary.observed = $script:sshFailure
            Wait-Until $assertSaved 'failed SSH tab preserved in saved state with unchanged active tab and foreground'
            $result.sshBoundary.tabRemoved = $false
            Save-Json $script:sessionOpenSaved 'session-after.json'
            $result.checks += @{ name = 'session-open-background-idempotent'; workspace = $workspaceName; group = $group.name; groupId = $group.id; host = $hostName; port = $script:zsbPort; created = $created; repeated = $repeated; tmux = 'verify-1'; title = 'Verify 1'; matchingTabs = 1; tabsBefore = @($baseline.tabs).Count; tabsAfter = @($script:sessionOpenSaved.tabs).Count; activeWorkspaceBefore = $workspaceBefore; activeWorkspaceAfter = $script:sessionOpenSaved.active_workspace; activeTabBefore = $activeTabBefore; activeTabAfter = $script:sessionOpenSaved.active_tab; foregroundBefore = $foregroundBefore.ToInt64(); foregroundAfter = [VerifyNative]::GetForegroundWindow().ToInt64(); windowTitleBefore = $titleBefore; windowTitleAfter = [VerifyNative]::Title($script:window) }
            Snapshot 'after'
        }
        'workspace-focus' {
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and @($state.tabs).Count -gt 0 -and $state.tabs[$state.active_tab].kind -eq 'cmd'
            } 'initial CMD session saved' 60
            $initial = Read-Session
            if ($initial.active_workspace -ne 0 -or $initial.workspace_count -ne 1) { throw 'Expected one initial stored workspace' }
            $initialTab = $initial.active_tab
            Wait-WorkspaceSurface 0 $initialTab $false
            if ($initial.hide_pills) {
                Focus-Palette 'workspace switcher' 6213
                Press @(0x0D) 'Enter: show workspace switcher'
            }
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and $state.PSObject.Properties['hide_pills'] -and -not $state.hide_pills -and -not ($state.PSObject.Properties['hide_sidebar'] -and $state.hide_sidebar) -and -not ($state.PSObject.Properties['sidebar_collapsed'] -and $state.sidebar_collapsed)
            } 'workspace switcher shown and saved'
            Wait-WorkspaceSurface 0 $initialTab $false
            Snapshot 'pills-ready'
            Focus-Palette 'per tab' 6345
            Press @(0x0D) 'Enter: Chat View per tab'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and -not ($state.PSObject.Properties.Name -contains 'chat_view_mode')
            } 'per-session Chat View mode saved'
            Wait-WorkspaceSurface 0 $initialTab $false
            $tab = (Read-Session).tabs[$initialTab]
            if (-not ($tab.PSObject.Properties.Name -contains 'cv' -and $tab.cv)) {
                Press @(0x12, 0x43) 'Alt+C: enable Chat View for the test session'
            }
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and $state.tabs[$initialTab].PSObject.Properties['cv'] -and $state.tabs[$initialTab].cv
            } 'test session Chat View enabled'
            $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
            $editCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
            Wait-Until {
                $candidate = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $editCondition)
                $null -ne $candidate -and $candidate.Current.ProcessId -eq $process.Id -and -not $candidate.Current.IsOffscreen -and $candidate.Current.NativeWindowHandle -ne 0
            } 'owned Chat View typing box visible' 30
            $composer = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $editCondition)
            $composerHandle = $composer.Current.NativeWindowHandle
            if ([VerifyNative]::GetAncestor([IntPtr]$composerHandle, 2) -ne $script:window) { throw 'Chat View typing box is not in the owned window' }
            Record 'Setup: foreground owned Chat View before focus regression'
            [void][VerifyNative]::ShowWindow($script:window, 9)
            [void][VerifyNative]::SetForegroundWindow($script:window)
            Wait-Until { [VerifyNative]::GetForegroundWindow() -eq $script:window } 'foreground Chat View frame'
            Wait-Until {
                $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
                $focused.Current.ProcessId -eq $process.Id -and $focused.Current.NativeWindowHandle -eq $composerHandle
            } 'owned Chat View typing box focused'
            Type-Text 'before-'
            Wait-Until {
                [VerifyNative]::EditText([IntPtr]$composerHandle) -ceq 'before-'
            } 'initial text landed in Chat View typing box'
            Snapshot 'action'
            Press @(0x11, 0x4E) 'Ctrl+N: create second workspace'
            Wait-Until {
                $state = Read-Session
                $null -ne $state -and $state.workspace_count -eq $initial.workspace_count + 1 -and $state.active_workspace -eq 1 -and $state.active_tab -ne $initialTab -and $state.tabs[$state.active_tab].workspace -eq 1 -and $state.tabs[$state.active_tab].kind -eq 'cmd'
            } 'second workspace and distinct CMD session saved'
            $second = (Read-Session).active_workspace
            $secondTab = (Read-Session).active_tab
            Wait-WorkspaceSurface $second $secondTab $false
            Press @(0x12, 0x32) 'Alt+2: return to first workspace'
            Wait-WorkspaceSurface 0 $initialTab $true $composerHandle
            Press @(0x12, 0x27) 'Alt+Right: leave Chat View workspace'
            Wait-WorkspaceSurface $second $secondTab $false
            Press @(0x12, 0x25) 'Alt+Left: return to Chat View workspace'
            Wait-WorkspaceSurface 0 $initialTab $true $composerHandle
            Type-Text 'workspace-focus-chat'
            $expectedText = 'before-workspace-focus-chat'
            Wait-Until {
                [VerifyNative]::EditText([IntPtr]$composerHandle) -ceq $expectedText
            } 'text landed in Chat View typing box without a click'
            $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
            if ($focused.Current.NativeWindowHandle -ne $composerHandle) { throw 'Chat View typing box did not retain keyboard focus' }
            $chatState = Read-Session
            if ($chatState.active_tab -ne $initialTab -or $chatState.workspaces[0].focus -ne 'chat') { throw 'Chat focus or selected session was not persisted' }
            $result.checks += @{ name = 'workspace-focus-chat'; text = $expectedText; composer = $composerHandle; activeTab = $chatState.active_tab; savedFocus = $chatState.workspaces[0].focus }
            Write-Output 'workspace-focus chat PASS'
            Snapshot 'chat-returned'
            Click-WorkspacePill $second
            Wait-WorkspaceSurface $second $secondTab $false
            Click-WorkspacePill 0
            Wait-WorkspaceSurface 0 $initialTab $true $composerHandle
            Type-Text '-pill'
            Wait-Until {
                [VerifyNative]::EditText([IntPtr]$composerHandle) -ceq ($expectedText + '-pill')
            } 'pill return restored Chat View input without a composer click'
            $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
            $pillState = Read-Session
            if ($focused.Current.NativeWindowHandle -ne $composerHandle -or $pillState.active_tab -ne $initialTab -or $pillState.workspaces[0].focus -ne 'chat') { throw 'Pill return lost Chat View focus or selected session' }
            $result.checks += @{ name = 'workspace-focus-chat-pill'; text = ($expectedText + '-pill'); composer = $composerHandle; activeTab = $pillState.active_tab; savedFocus = $pillState.workspaces[0].focus }
            Write-Output 'workspace-focus chat pill PASS'
            Press @(0x12, 0x43) 'Alt+C: switch to shell console'
            Wait-WorkspaceSurface 0 $initialTab $false
            $pillMarker = Join-Path $scratch 'workspace-focus-shell-pill.txt'
            if (Test-Path $pillMarker) { throw 'Pill shell marker must not exist before input' }
            Type-Text 'echo workspace-focus-shell-pill'
            Wait-ConsoleText 'echo workspace-focus-shell-pill'
            Click-WorkspacePill $second
            Wait-WorkspaceSurface $second $secondTab $false
            if ((Read-Session).workspaces[0].focus -ne 'shell') { throw 'Pill mouse-down did not capture the newly selected shell surface' }
            Click-WorkspacePill 0
            Wait-WorkspaceSurface 0 $initialTab $false
            Type-Text ('>"' + $pillMarker + '"')
            Wait-ConsoleText ('echo workspace-focus-shell-pill>"' + $pillMarker + '"')
            Press @(0x0D) 'Enter: execute in pill-restored shell without a console click'
            Wait-Until { (Test-Path $pillMarker) -and (Get-Content $pillMarker -Raw).Trim() -ceq 'workspace-focus-shell-pill' } 'pill-restored console executed typed command'
            $pillState = Read-Session
            if ($pillState.active_tab -ne $initialTab -or $pillState.workspaces[0].focus -ne 'shell') { throw 'Pill return lost shell focus or selected session' }
            $result.checks += @{ name = 'workspace-focus-shell-pill'; marker = (Get-Content $pillMarker -Raw).Trim(); activeTab = $pillState.active_tab; savedFocus = $pillState.workspaces[0].focus }
            Write-Output 'workspace-focus shell pill PASS'
            Wait-WorkspaceSurface 0 $initialTab $false
            $marker = Join-Path $scratch 'workspace-focus-shell.txt'
            if (Test-Path $marker) { throw 'Shell focus marker must not exist before input' }
            Type-Text 'echo workspace-focus-shell'
            Wait-ConsoleText 'echo workspace-focus-shell'
            Press @(0x12, 0x27) 'Alt+Right: leave shell workspace'
            Wait-WorkspaceSurface $second $secondTab $false
            Press @(0x12, 0x25) 'Alt+Left: return to shell workspace'
            Wait-WorkspaceSurface 0 $initialTab $false
            Type-Text ('>"' + $marker + '"')
            Wait-ConsoleText ('echo workspace-focus-shell>"' + $marker + '"')
            Press @(0x0D) 'Enter: execute in restored shell without a click'
            Wait-Until { (Test-Path $marker) -and (Get-Content $marker -Raw).Trim() -ceq 'workspace-focus-shell' } 'restored console executed the typed command'
            $shellState = Read-Session
            if ($shellState.active_tab -ne $initialTab -or $shellState.workspaces[0].focus -ne 'shell') { throw 'Shell focus or selected session was not persisted' }
            $result.checks += @{ name = 'workspace-focus-shell'; marker = (Get-Content $marker -Raw).Trim(); activeTab = $shellState.active_tab; savedFocus = $shellState.workspaces[0].focus }
            Write-Output 'workspace-focus shell PASS'
            Snapshot 'after'
        }
        'chat-view' {
            $result.agentBoundary = @{ liveDeliveryVerified = $false; reason = 'The fresh offline CMD has no signed-in agent or received conversation; the separate native painter proof uses a synthetic envelope without seeding app state' }
            Palette 'interface'
            Press @(0x28) 'Down: UI Size: Decrease'
            Press @(0x28) 'Down: UI Size: Reset'
            Press @(0x0D) 'Enter: persist default UI size before Chat View'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 } 'saved initial tab before Chat View'
            $baseline = Read-Session
            if ($baseline.PSObject.Properties['ui_scale'] -and $baseline.ui_scale -ne 100) { throw 'Chat View baseline UI size is not 100' }
            Save-Json $baseline 'session-before.json'
            Press @(0x12, 0x43) 'Alt+C: open Chat View'
            $toggleReady = [DateTime]::UtcNow.AddMilliseconds(1600)
            Wait-Until {
                $state = Read-Session
                $state.tabs[$state.active_tab].PSObject.Properties['cv'] -and $state.tabs[$state.active_tab].cv -eq $true
            } 'Chat View enabled in app-written session'
            Wait-Until {
                $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
                $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
                @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen }).Count -eq 1
            } 'visible native Chat View transcript control'
            Save-Json (Read-Session) 'session-opened.json'
            Snapshot 'action'
            Wait-Until { [DateTime]::UtcNow -ge $toggleReady } 'Alt+C debounce elapsed before closing'
            Press @(0x12, 0x43) 'Alt+C: close Chat View'
            $toggleReady = [DateTime]::UtcNow.AddMilliseconds(1600)
            Wait-Until {
                $state = Read-Session
                -not $state.tabs[$state.active_tab].PSObject.Properties['cv'] -or $state.tabs[$state.active_tab].cv -eq $false
            } 'Chat View disabled in app-written session'
            Save-Json (Read-Session) 'session-closed.json'
            Snapshot 'closed'
            Wait-Until { [DateTime]::UtcNow -ge $toggleReady } 'Alt+C debounce elapsed before reopening'
            Press @(0x12, 0x43) 'Alt+C: reopen Chat View'
            Wait-Until {
                $state = Read-Session
                $state.tabs[$state.active_tab].PSObject.Properties['cv'] -and $state.tabs[$state.active_tab].cv -eq $true
            } 'Chat View re-enabled in app-written session'
            $after = Read-Session
            if ($after.active_tab -ne $baseline.active_tab -or @($after.tabs).Count -ne @($baseline.tabs).Count) { throw 'Chat View changed the selected tab or tab count' }
            Save-Json $after 'session-after.json'
            Snapshot 'after'
            $result.checks += @{ name = 'chat-view-open-close-reopen'; activeTab = $after.active_tab; tabCount = @($after.tabs).Count; savedChatView = $after.tabs[$after.active_tab].cv; entry = 'Alt+C' }
        }
        'browser-workspaces' {
            Press @(0x11, 0x4E) 'Ctrl+N: create a workspace and persist the fresh workspace layout'
            Wait-Until { $state = Read-Session; $null -ne $state -and $state.PSObject.Properties['workspace_count'] -and $state.workspace_count -eq 2 } 'initial and new workspaces saved'
            Press @(0x12, 0x32) 'Alt+2: return to the initial workspace'
            Wait-Until { (Read-Session).active_workspace -eq 0 } 'initial workspace active'
            $roots = @()
            $identities = @()
            $script:extensionSetups = @()
            $browserRoot = Join-Path $scratch 'local/ZigShell/BrowserWorkspaces/edge'
            for ($index = 0; $index -lt 6; $index++) {
                if ($index -eq 1) {
                    Press @(0x12, 0x33) 'Alt+3: select the already created second workspace'
                    Wait-Until { (Read-Session).active_workspace -eq 1 } 'second workspace active'
                } elseif ($index -gt 1) {
                    Press @(0x11, 0x4E) 'Ctrl+N: create an independent workspace'
                    Wait-Until { (Read-Session).workspace_count -eq $index + 1 } 'new workspace saved'
                }
                $state = Read-Session
                $slot = [int]$state.active_workspace
                $id = [string]$state.workspaces[$slot].wid
                if (-not $id) { throw 'Workspace has no stable ID' }
                $sha = [Security.Cryptography.SHA256]::Create()
                try { $hash = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($id)))).Replace('-', '').ToLowerInvariant().Substring(0, 30) } finally { $sha.Dispose() }
                $root = Join-Path $browserRoot $hash
                Press @(0x12, 0x41) 'Alt+A: open this workspace browser pane'
                Wait-Until {
                    (Test-Path (Join-Path $root '.multiprompt-clone-complete')) -and
                    (Test-Path (Join-Path $root 'Local State')) -and
                    @((Read-Inbox).shells | Where-Object { $_.ws -eq $slot -and $_.br -eq 2 }).Count -gt 0
                } 'completed workspace profile and live docked browser' 60
                if ($index -eq 0) { Register-WorkspaceBridge $root }
                Enable-WorkspaceExtension $root $index
                $roots += $root
                $identities += $id
                Snapshot ('workspace-' + $index)
                if ($index -eq 0) { Snapshot 'action' }
                Focus-WorkspaceFrame
            }
            if (@($roots | Select-Object -Unique).Count -ne 6) { throw 'Workspaces reused a browser profile root' }
            $live = @(Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -like '*--user-data-dir=*' -and $_.CommandLine -notlike '*--type=*' })
            foreach ($root in $roots) {
                if (@($live | Where-Object { $_.CommandLine.Contains($root) }).Count -ne 1) { throw "Expected exactly one live browser process for $root" }
            }
            Save-Json @($live | Select-Object ProcessId, ParentProcessId, CommandLine) 'workspace-browser-processes.json'
            Press @(0x12, 0x32) 'Alt+2: return to the first workspace'
            Wait-Until { (Read-Session).active_workspace -eq 0 } 'first workspace restored'
            if ((Read-Session).workspaces[0].wid -ne $identities[0]) { throw 'Workspace ID changed on return' }
            if (@(Get-ChildItem $browserRoot -Directory).Count -ne 6) { throw 'Switching created another browser profile' }
            if ((Test-Path (Join-Path $scratch 'local/ZigShell/EdgeUserData')) -or (Test-Path (Join-Path $scratch 'local/ZigShell/ChromeUserData'))) { throw 'Fresh launches wrote a shared seed' }
            $result.checks += @{ name = 'six-stable-live-workspace-profiles'; workspaceIds = $identities; roots = $roots; liveProfiles = 6; sharedSeedCreated = $false; nativeExtensionRouting = 'real unpacked extension and native host; zsb lifecycle below' }
            $script:profileObservations = @()
            $targetId = $identities[5]
            $targetRoot = $roots[5]
            $bookmark = 'https://example.com/?igsh224=workspace-five'
            Press @(0x12, 0x37) 'Alt+7: select the sixth workspace'
            Wait-Until { (Read-Session).active_workspace -eq 5 } 'sixth workspace active'
            Palette 'rename workspace'
            Snapshot 'rename-action'
            Press @(0x0D) 'Enter: Rename workspace'
            Snapshot 'rename-editor'
            Press @(0x11, 0x41) 'Ctrl+A: replace workspace name'
            Type-Text 'IGSH224 Journey'
            Press @(0x0D) 'Enter: save workspace name'
            Wait-Until { (Read-Session).workspaces[5].name -ceq 'IGSH224 Journey' } 'workspace rename persisted'
            Palette 'open url in browser'
            Snapshot 'url-action'
            Press @(0x0D) 'Enter: browser URL input in the palette'
            Type-Text $bookmark
            Press @(0x0D) 'Enter: navigate to the synthetic bookmark URL'
            Wait-Until { (Read-Session).tabs | Where-Object { $_.PSObject.Properties['burl'] -and $_.burl -eq $bookmark } } 'app observed browser navigation' 60
            Focus-WorkspaceBrowser $targetRoot
            Press-WorkspaceBrowser @(0x11, 0x39) 'Ctrl+9: select the URL tab opened by the palette'
            Wait-Until {
                $browser = [System.Windows.Automation.AutomationElement]::FromHandle($script:bookmarkWindow)
                $edits = $browser.FindAll([System.Windows.Automation.TreeScope]::Subtree, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Edit)))
                foreach ($edit in $edits) {
                    if ($edit.Current.Name -ne 'Address and search bar') { continue }
                    $value = $edit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
                    if ($value.Current.Value -in @($bookmark, $bookmark.Substring(8))) {
                        Save-Json @{ url = $value.Current.Value; hwnd = $script:bookmarkWindow.ToInt64(); pid = $script:bookmarkPid } 'bookmark-page.json'
                        return $true
                    }
                }
                return $false
            } 'actual owned browser address bar shows the synthetic bookmark URL' 60
            Press-WorkspaceBrowser @(0x11, 0x44) 'Ctrl+D: bookmark this page in Edge'
            Snapshot 'bookmark-action'
            Press-WorkspaceBrowser @(0x0D) 'Enter: save favorite'
            Press-WorkspaceBrowser @(0x1B) 'Esc: close favorite dialog'
            Assert-WorkspaceProfile 'renamed' $targetId $targetRoot $bookmark
            Palette 'sort workspaces'
            Press @(0x0D) 'Enter: Sort Workspaces'
            for ($step = 0; $step -lt 5; $step++) { Press @(0x28) 'Down: select the sixth workspace in sort list' }
            Press @(0x11, 0x26) 'Ctrl+Up: move the workspace one position earlier'
            Wait-Until { (Read-Session).workspaces[4].wid -ceq $targetId } 'workspace reorder persisted'
            Press @(0x1B) 'Esc: close workspace sort list'
            Assert-WorkspaceProfile 'reordered' $targetId $targetRoot $bookmark
            Palette 'window mode'
            Press @(0x0D) 'Enter: convert to multi-window mode'
            Wait-Until { $state = Read-Session; $state.PSObject.Properties['workspace_id'] -and $state.workspace_id -ceq $targetId -and -not $state.PSObject.Properties['single_window'] } 'standalone identity persisted' 60
            Assert-WorkspaceProfile 'multi-window' $targetId $targetRoot $bookmark
            Wait-Until { @(Get-ChildItem (Join-Path $scratch 'roaming/ZigShell') -Filter 'inbox-*.json').Count -eq 6 } 'six standalone workspace windows published' 60
            Palette 'window mode'
            Press @(0x0D) 'Enter: convert back to single-window mode'
            Wait-Until { $state = Read-Session; $state.PSObject.Properties['single_window'] -and $state.single_window -and $state.workspace_count -eq 6 -and $state.workspaces[4].wid -ceq $targetId } 'all workspace identities and order restored' 90
            Assert-WorkspaceProfile 'single-window' $targetId $targetRoot $bookmark
            Palette 'close workspace'
            Press @(0x0D) 'Enter: close this named workspace'
            Wait-Until { @((Read-Session).workspaces | Where-Object { $_.wid -ceq $targetId }).Count -eq 0 } 'target workspace closed and saved'
            Snapshot 'workspace-closed'
            Palette 'IGSH224 Journey'
            Press @(0x0D) 'Enter: reopen the named workspace'
            Wait-Until { $state = Read-Session; $state.workspaces[$state.active_workspace].wid -ceq $targetId } 'same workspace identity reopened' 60
            $state = Read-Session
            $script:browserShellId = $state.tabs[$state.active_tab].shell_id
            Palette 'open browser'
            Press @(0x0D) 'Enter: reopen the workspace browser pane'
            Wait-Until {
                $pane = Read-BrowserPane
                $null -ne $pane -and $pane.browser_state -eq 'connected' -and
                    $pane.browser_connection_id -gt 0 -and $pane.browser_window_id -gt 0 -and
                    [VerifyNative]::PaneVisible($script:window)
            } 'workspace-reopened: exact shell has a connected extension browser pane' 60
            Save-Json (Read-BrowserPane) 'workspace-reopened-pane.json'
            Focus-BrowserPaneOwner 'workspace-reopened' (Read-BrowserPane).browser_connection_id
            Assert-WorkspaceProfile 'reopened' $targetId $targetRoot $bookmark
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            $script:zsbPort = 0
            Wait-Until {
                $listener = [regex]::Match((Get-Content $log -Raw), 'notify-listener: tunnel-inbound listening port=(\d+) err=0')
                if (-not $listener.Success) { return $false }
                $script:zsbPort = [int]$listener.Groups[1].Value
                @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort $script:zsbPort | Where-Object { $_.OwningProcess -eq $process.Id }).Count -eq 1
            } 'original app-owned zsb listener remains live'
            $state = Read-Session
            $targetTab = $state.tabs[$state.active_tab]
            $targetKey = 'zss-' + $targetTab.shell_id
            $foreignTab = @($state.tabs | Where-Object { (-not $_.PSObject.Properties['workspace']) -or $_.workspace -eq 0 })[0]
            $foreignKey = 'zss-' + $foreignTab.shell_id
            $token = 'e-' + (Split-Path $targetRoot -Leaf)
            Wait-Until { [IO.Directory]::GetFiles('\\.\pipe\') -contains ('\\.\pipe\multiprompt-browser-isolated-' + $token) } 'reopened workspace native host registered its exact profile pipe' 60
            Focus-BrowserPaneOwner 'workspace-reopened-zsb' (Read-BrowserPane).browser_connection_id
            $routed = Invoke-Zsb @('url') $script:zsbPort 'zsb-target-url' $targetKey
            if ($routed.result.url -cne $bookmark) { throw 'zsb reached the wrong workspace browser host' }
            Press @(0x12, 0x32) 'Alt+2: select another workspace before requesting the parked target'
            Wait-Until { (Read-Session).active_workspace -eq 0 } 'foreign workspace selected'
            Focus-BrowserPaneOwner 'workspace-parked-zsb' (Read-BrowserPane).browser_connection_id
            $parked = Invoke-Zsb @('url') $script:zsbPort 'zsb-parked-target-url' $targetKey
            $foreign = Invoke-Zsb @('url') $script:zsbPort 'zsb-foreign-url' $foreignKey
            if ($parked.result.url -cne $bookmark -or $foreign.result.url -ceq $bookmark) { throw 'zsb borrowed the foreground or wrong workspace host' }
            if ((Read-Session).active_workspace -ne 0) { throw 'Background zsb routing changed the active workspace' }
            $foreignBookmarks = Join-Path $roots[0] 'Default/Bookmarks'
            if ((Test-Path $foreignBookmarks) -and (Get-Content $foreignBookmarks -Raw).Contains($bookmark)) { throw 'Target bookmark leaked into the other workspace profile' }
            Save-Json @(Get-CimInstance Win32_Process | Where-Object { $_.Name -in @('msedge.exe', 'zigshell-bridge.exe') } | Select-Object ProcessId, ParentProcessId, Name, CommandLine) 'workspace-host-processes.json'
            Palette 'IGSH224 Journey'
            Press @(0x0D) 'Enter: return to the verified workspace'
            Assert-WorkspaceProfile 'after' $targetId $targetRoot $bookmark
            $result.checks += @{ name = 'workspace-lifecycle-and-zsb'; workspaceId = $targetId; root = $targetRoot; bookmark = $bookmark; stages = @($script:profileObservations | ForEach-Object { $_.stage }); targetSession = $targetKey; foreignSession = $foreignKey; targetReply = $routed; parkedReply = $parked; foreignReply = $foreign; extensionId = $script:extensionIds[0]; profileToken = $token; realLogin = 'post-install laptop1 only' }

        }
        'inbox' {
            Press @(0x11, 0x10, 0x49) 'Ctrl+Shift+I: open Inbox'
            Wait-Until { [VerifyNative]::Title($script:window).StartsWith('Inbox - ') } 'Inbox window state'
            Press @(0x12, 0x49) 'Alt+I: select All split'
            Snapshot 'action'
            $prior = (Read-Inbox).shells[0].att
            Press @(0x55) 'u: toggle selected Inbox session unread'
            Wait-Until { (Read-Inbox).shells[0].att -ne $prior } 'published attention state toggled'
            Snapshot 'after'
            $result.checks += @{ name = 'inbox-toggle-read'; attentionBefore = $prior; attentionAfter = (Read-Inbox).shells[0].att; title = [VerifyNative]::Title($script:window) }
            Press @(0x1B) 'Esc: return from Inbox'
            Wait-Until { -not [VerifyNative]::Title($script:window).StartsWith('Inbox - ') } 'Inbox closed'
            Snapshot 'returned'
        }
        'browser-pane-stuck' {
            $script:browserShellId = (Read-Inbox).shells[0].sid
            if (Test-Path (Join-Path $env:USERPROFILE 'Documents/GitHub/zigshell/extension/manifest.json')) { throw 'Expected no browser extension in the isolated profile' }
            Press @(0x12, 0x43) 'Alt+C: open Chat View'
            Wait-Until { @((Read-Session).tabs | Where-Object { $_.cv -eq $true }).Count -eq 1 } 'Chat View saved for the initial session'
            $first = Open-BrowserPane 'initial-open'
            Snapshot 'action'
            Press @(0x12, 0x41) 'Alt+A: close browser pane'
            $closed = Assert-BrowserPane 'closed' 'shortcut-close'
            $second = Open-BrowserPane 'reopen-after-shortcut' $first.browser_connection_id
            Palette 'close all browser panes'
            Press @(0x0D) 'Enter: Close All Browser Panes'
            $closed = Assert-BrowserPane 'closed' 'palette-close-all'
            if (@((Read-Inbox).shells | Where-Object { $_.browser_state -ne 'closed' }).Count -ne 0) { throw 'Close All left a browser pane open' }
            Doctor
            Assert-Foreground
            Record 'reopen-after-close-all: batch palette open then close before adoption timers'
            [VerifyNative]::OpenAndCloseBrowserPane()
            $closed = Assert-BrowserPane 'closed' 'palette-close-pane'
            $fourth = Open-BrowserPane 'reopen-after-close-pane' $second.browser_connection_id
            if ($fourth.browser_connection_id -le $second.browser_connection_id + 1) { throw 'Palette batch did not open and cancel an intermediate connection' }
            Assert-ConnectedPaneStaysVisible $fourth.browser_connection_id
            Press @(0x12, 0x10, 0x41) 'Alt+Shift+A: toggle working browser pane closed'
            $shiftToggleCooldown = [Diagnostics.Stopwatch]::StartNew()
            $closed = Assert-BrowserPane 'closed' 'shift-a-toggle'
            Wait-Until { $shiftToggleCooldown.ElapsedMilliseconds -ge 1600 } 'browser shortcut debounce elapsed' 5
            Press @(0x12, 0x10, 0x42) 'Alt+Shift+B: toggle browser pane open'
            $fifth = Assert-BrowserPane 'open' 'shift-b-toggle' $fourth.browser_connection_id
            Focus-BrowserPaneOwner 'shift-b-toggle' $fifth.browser_connection_id
            Palette 'close all browser panes'
            Press @(0x0D) 'Enter: Close All Browser Panes'
            $closed = Assert-BrowserPane 'closed' 'final-close'
            Snapshot 'after'
        }
        'command-palette' {
            Palette 'interface'
            Snapshot 'action'
            Press @(0x0D) 'Enter: UI Size: Increase'
            Wait-Until { (Read-Session).ui_scale -eq 110 } 'UI scale saved as 110'
            Snapshot 'after'
            Palette 'interface'
            Press @(0x28) 'Down: UI Size: Decrease'
            Press @(0x28) 'Down: UI Size: Reset'
            Press @(0x0D) 'Enter: UI Size: Reset'
            Wait-Until { $state = Read-Session; -not ($state.PSObject.Properties.Name -contains 'ui_scale') -or $state.ui_scale -eq 100 } 'UI scale reset to default'
            Snapshot 'reset'
            $result.checks += @{ name = 'palette-increase-reset'; increasedScale = 110; resetScale = 100 }
            Palette 'restart to update'
            Snapshot 'update-command'
            $image = New-Object Drawing.Bitmap((Join-Path $Evidence 'update-command.png'))
            $selectedTextPixels = 0
            try {
                $top = $image.Height
                $bottom = 0
                for ($y = [int]($image.Height * 0.2); $y -lt [int]($image.Height * 0.8); $y++) {
                    $pixel = $image.GetPixel([int]($image.Width / 2), $y)
                    if ($pixel.R -lt 50 -and $pixel.G -gt 70 -and $pixel.G -lt 160 -and $pixel.B -gt 150) {
                        $top = [Math]::Min($top, $y)
                        $bottom = [Math]::Max($bottom, $y)
                    }
                }
                for ($y = $top; $y -le $bottom; $y++) {
                    for ($x = [int]($image.Width * 0.3); $x -lt [int]($image.Width * 0.7); $x++) {
                        $pixel = $image.GetPixel($x, $y)
                        if ($pixel.R -gt 180 -and $pixel.G -gt 180 -and $pixel.B -gt 180) { $selectedTextPixels++ }
                    }
                }
                if ($selectedTextPixels -lt 40) { throw 'Update command row is blank or unreadable' }
            } finally { $image.Dispose() }
            Press @(0x0D) 'Enter: Restart to update with no update ready'
            Doctor
            Snapshot 'update-idle'
            $result.checks += @{ name = 'update-command-without-ready-keeps-session'; pid = $process.Id; scale = 100; selectedTextPixels = $selectedTextPixels }
        }
    }
    Doctor
    $result.status = 'passed'
} catch {
    $result.error = $_.Exception.Message
    if ($script:window -ne [IntPtr]::Zero) {
        try { Snapshot 'failure' } catch { $result.captureError = $_.Exception.Message }
    }
} finally {
    try {
        try {
            if ($null -ne $process -and -not $process.HasExited) {
                Record 'Cleanup: close owned app before stopping its job-owned process tree'
                [void]$process.CloseMainWindow()
                [void]$process.WaitForExit(10000)
            }
        } finally {
            try {
                if ($null -ne $job) {
                    $beforeStop = $job.ReadAccounting()
                    $stopped = $job.Stop()
                    Save-Json @{ totalProcesses = $stopped.TotalProcesses; activeBeforeStop = $beforeStop.ActiveProcesses; activeAfterStop = $stopped.ActiveProcesses } 'process-tree.json'
                    Record 'Cleanup: owned process tree stopped; job active process count is zero'
                }
            } finally {
                if (Test-Path $scratch) {
                    Prepare-ScratchEvidence $scratch
                    Save-Json @($script:scratchLinks) 'scratch-links.json'
                    Save-Json @($script:transientEvidence.ToArray()) 'scratch-transient-files.json'
                    $data = Join-Path $Evidence 'data'
                    New-Item -ItemType Directory -Force $data | Out-Null
                    $deadline = [DateTime]::UtcNow.AddSeconds(20)
                    while ($true) {
                        try { Copy-Item (Join-Path $scratch '*') $data -Recurse -Force; break } catch {
                            if ([DateTime]::UtcNow -ge $deadline) { throw }
                            Start-Sleep -Milliseconds 200
                        }
                    }
                }
            }
        }
        if (Test-Path $scratch) {
            $deadline = [DateTime]::UtcNow.AddSeconds(20)
            while (Test-Path $scratch) {
                try { Remove-Item $scratch -Recurse -Force } catch {
                    if ([DateTime]::UtcNow -ge $deadline) { throw }
                    Start-Sleep -Milliseconds 200
                }
            }
        }
        $result.cleanup = 'owned process tree stopped; scratch copied to evidence/data then removed'
        $result.scratchRemoved = -not (Test-Path $scratch)
        if (-not $result.scratchRemoved) { throw 'Scratch directory still exists' }
        Write-Output $result.cleanup
        if ($result.status -eq 'passed') {
            foreach ($name in @('before.png', 'action.png', 'after.png', 'doctor.json', 'actions.json')) {
                if (-not (Test-Path (Join-Path $Evidence $name))) { throw "Evidence lost during cleanup: $name" }
            }
        }
    } catch {
        $result.status = 'failed'
        $result.cleanup = $_.Exception.Message
    }
    if (Get-Variable nativeRegistry -Scope Script -ErrorAction SilentlyContinue) {
        if (Test-Path $script:nativeRegistry) { Remove-Item $script:nativeRegistry -Force }
    }
    if ($null -ne $job) { $job.Dispose() }
    if ($null -ne $process) { $process.Dispose() }
    foreach ($name in $original.Keys) { [Environment]::SetEnvironmentVariable($name, $original[$name], 'Process') }
    Save-Json $result 'result.json'
}
if ($result.status -ne 'passed') { throw ('Verification failed: ' + ($result | ConvertTo-Json -Depth 8 -Compress)) }
Write-Output "VERIFIED $Feature with real input and retained evidence"
