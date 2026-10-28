using System;
using System.Runtime.InteropServices;
using System.Text;
public static class ChatDeliveryDesktop {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] struct Message { public IntPtr Hwnd; public uint Id; public UIntPtr WParam; public IntPtr LParam; public uint Time; public Point Position; public uint Private; }
    [StructLayout(LayoutKind.Sequential)] public struct Gui { public uint Size, Flags; public IntPtr Active, Focus, Capture, Menu, Move, Caret; public Rect CaretRect; }
    [StructLayout(LayoutKind.Sequential)] public struct Mouse { public int X, Y; public uint Data, Flags, Time; public UIntPtr Extra; }
    [StructLayout(LayoutKind.Sequential)] public struct Keyboard { public ushort Key, Scan; public uint Flags, Time; public UIntPtr Extra; }
    [StructLayout(LayoutKind.Explicit)] public struct Union { [FieldOffset(0)] public Mouse Mouse; [FieldOffset(0)] public Keyboard Keyboard; }
    [StructLayout(LayoutKind.Sequential)] public struct Input { public uint Type; public Union Data; }
    public delegate bool EnumProc(IntPtr hwnd, IntPtr parameter);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc callback, IntPtr parameter);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumProc callback, IntPtr parameter);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder text, int length);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] static extern bool AllowSetForegroundWindow(uint pid);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern bool PeekMessage(out Message message, IntPtr hwnd, uint min, uint max, uint remove);
    [DllImport("user32.dll", SetLastError=true)] static extern bool AttachThreadInput(uint from, uint to, bool attach);
    [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr hwnd);
    [DllImport("user32.dll")] static extern IntPtr SetFocus(IntPtr hwnd);
    [DllImport("user32.dll")] static extern bool IsChild(IntPtr parent, IntPtr hwnd);
    [DllImport("user32.dll")] static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool GetGUIThreadInfo(uint thread, ref Gui info);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint message, IntPtr capacity, StringBuilder text, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint count, Input[] inputs, int size);
    public static uint Owner(IntPtr hwnd) { uint pid; GetWindowThreadProcessId(hwnd, out pid); return pid; }
    public static string Class(IntPtr hwnd) { var text = new StringBuilder(256); GetClassName(hwnd, text, text.Capacity); return text.ToString(); }
    public static IntPtr Window(uint pid) { IntPtr found = IntPtr.Zero; EnumWindows((h,p) => { if (Owner(h) == pid && IsWindowVisible(h) && Class(h) == "ZigShell") { found = h; return false; } return true; }, IntPtr.Zero); return found; }
    public static IntPtr Menu(uint pid) { IntPtr found = IntPtr.Zero; EnumWindows((h,p) => { if (Owner(h) == pid && IsWindowVisible(h) && Class(h) == "#32768") { found = h; return false; } return true; }, IntPtr.Zero); return found; }
    [StructLayout(LayoutKind.Sequential)] struct MenuBar { public uint Size; public Rect Rect; public IntPtr Menu, Window; public uint Focus; }
    [DllImport("user32.dll")] static extern bool GetMenuBarInfo(IntPtr hwnd, int obj, int item, ref MenuBar info);
    [DllImport("user32.dll")] static extern int GetMenuItemCount(IntPtr menu);
    [DllImport("user32.dll")] static extern bool GetMenuItemRect(IntPtr window, IntPtr menu, uint item, out Rect rect);
    public static Rect FirstMenuItem(IntPtr menu, uint pid, int count) {
        if (Owner(menu) != pid || Class(menu) != "#32768" || !IsWindowVisible(menu)) throw new InvalidOperationException("Menu item ownership mismatch");
        var bar = new MenuBar { Size = (uint)Marshal.SizeOf(typeof(MenuBar)) };
        Rect rect;
        if (!GetMenuBarInfo(menu, -4, 0, ref bar) || GetMenuItemCount(bar.Menu) != count ||
            !GetMenuItemRect(IntPtr.Zero, bar.Menu, 0, out rect) || rect.Right <= rect.Left || rect.Bottom <= rect.Top) throw new InvalidOperationException("Native reaction menu geometry unavailable");
        return rect;
    }
    public static void PressOwnedMenu(IntPtr main, uint pid, IntPtr menu, int count) {
        if (Owner(main) != pid || Class(main) != "ZigShell" || GetForegroundWindow() != main) throw new InvalidOperationException("Menu click foreground ownership mismatch");
        var rect = FirstMenuItem(menu, pid, count);
        var origin = ScreenPoint(menu, 0, 0);
        PressClient(menu, pid, (rect.Left + rect.Right) / 2 - origin.X, (rect.Top + rect.Bottom) / 2 - origin.Y);
    }
    public static IntPtr CombinedMenu(uint pid) { IntPtr found = IntPtr.Zero; EnumWindows((h,p) => { if (Owner(h) == pid && IsWindowVisible(h) && Class(h) == "MultipromptMessageMenu") { found = h; return false; } return true; }, IntPtr.Zero); return found; }
    public static Rect CombinedMenuRect(IntPtr menu, uint pid) {
        Rect rect;
        if (Owner(menu) != pid || Class(menu) != "MultipromptMessageMenu" || !IsWindowVisible(menu) || !GetWindowRect(menu, out rect)) throw new InvalidOperationException("Combined menu ownership mismatch");
        if (rect.Right - rect.Left != 232 || rect.Bottom - rect.Top != 162) throw new InvalidOperationException("Combined menu geometry mismatch");
        return rect;
    }
    public static void PressCombinedMenu(IntPtr main, uint pid, IntPtr menu, int x, int y) {
        if (Owner(main) != pid || GetForegroundWindow() != main) throw new InvalidOperationException("Combined menu foreground mismatch");
        CombinedMenuRect(menu, pid);
        PressClient(menu, pid, x, y);
    }
    public static IntPtr Composer(IntPtr main) { IntPtr found = IntPtr.Zero; EnumChildWindows(main, (h,p) => { if (Class(h) == "Edit" && IsWindowVisible(h)) { found = h; return false; } return true; }, IntPtr.Zero); return found; }
    public static long[] Focus(IntPtr main) { uint pid; uint thread = GetWindowThreadProcessId(main, out pid); var info = new Gui(); info.Size = (uint)Marshal.SizeOf(typeof(Gui)); if (!GetGUIThreadInfo(thread, ref info)) throw new InvalidOperationException("GetGUIThreadInfo failed"); return new[] { GetForegroundWindow().ToInt64(), info.Focus.ToInt64() }; }
    public static string Text(IntPtr hwnd) { var text = new StringBuilder(32768); IntPtr result; if (SendMessageTimeout(hwnd, 0x000D, (IntPtr)text.Capacity, text, 2, 2000, out result) == IntPtr.Zero) throw new InvalidOperationException("WM_GETTEXT failed"); return text.ToString(); }
    public static bool FocusOwnedWindow(IntPtr hwnd, uint pid, IntPtr focus) {
        uint actualPid;
        uint targetThread = GetWindowThreadProcessId(hwnd, out actualPid);
        if (hwnd == IntPtr.Zero || pid == 0 || targetThread == 0 || actualPid != pid || Class(hwnd) != "ZigShell" ||
            focus == IntPtr.Zero || Owner(focus) != pid || (focus != hwnd && !IsChild(hwnd, focus))) throw new InvalidOperationException("App focus ownership mismatch");
        Message message;
        PeekMessage(out message, IntPtr.Zero, 0, 0, 0);
        uint currentThread = GetCurrentThreadId();
        uint foregroundPid;
        uint foregroundThread = GetWindowThreadProcessId(GetForegroundWindow(), out foregroundPid);
        bool attachedForeground = false, attachedTarget = false;
        keybd_event(0x12, 0, 0, UIntPtr.Zero);
        try {
            if (foregroundThread != 0 && foregroundThread != currentThread) {
                attachedForeground = AttachThreadInput(currentThread, foregroundThread, true);
            }
            if (targetThread != currentThread && targetThread != foregroundThread) {
                attachedTarget = AttachThreadInput(currentThread, targetThread, true);
            }
            AllowSetForegroundWindow(pid);
            BringWindowToTop(hwnd);
            SetForegroundWindow(hwnd);
            SetFocus(focus);
        } finally {
            if (attachedTarget) AttachThreadInput(currentThread, targetThread, false);
            if (attachedForeground) AttachThreadInput(currentThread, foregroundThread, false);
            keybd_event(0x12, 0, 2, UIntPtr.Zero);
        }
        return GetForegroundWindow() == hwnd && Focus(hwnd)[1] == focus.ToInt64();
    }
    public static void Chord(int[] keys) {
        var inputs = new Input[keys.Length * 2];
        for (int i = 0; i < keys.Length; i++) {
            inputs[i].Type = 1;
            inputs[i].Data.Keyboard.Key = (ushort)keys[i];
            inputs[keys.Length + i].Type = 1;
            inputs[keys.Length + i].Data.Keyboard.Key = (ushort)keys[keys.Length - i - 1];
            inputs[keys.Length + i].Data.Keyboard.Flags = 2;
        }
        if (SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(Input))) != inputs.Length) throw new InvalidOperationException("SendInput failed");
    }
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr hwnd, ref Point point);
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);
    public static Point ScreenPoint(IntPtr hwnd, int x, int y) {
        var point = new Point { X = x, Y = y };
        if (!ClientToScreen(hwnd, ref point)) throw new InvalidOperationException("ClientToScreen failed");
        return point;
    }
    public static void WheelTranscript(IntPtr hwnd, uint pid, IntPtr view, int x, int y, int delta) {
        if (Owner(hwnd) != pid || Class(hwnd) != "ZigShell" || GetForegroundWindow() != hwnd ||
            Owner(view) != pid || Class(view) != "ZigShellChatTranscript" || !IsChild(hwnd, view) ||
            WindowFromPoint(new Point { X = x, Y = y }) != view) throw new InvalidOperationException("Wheel target is not the owned foreground transcript");
        if (delta == 0 || delta < short.MinValue || delta > short.MaxValue || delta % 120 != 0) throw new ArgumentOutOfRangeException("delta");
        var inputs = new Input[2];
        inputs[0].Data.Mouse = new Mouse { X = (int)Math.Round(x * 65535.0 / (GetSystemMetrics(0) - 1)), Y = (int)Math.Round(y * 65535.0 / (GetSystemMetrics(1) - 1)), Flags = 0x8001 };
        inputs[1].Data.Mouse = new Mouse { Data = unchecked((uint)delta), Flags = 0x0800 };
        if (SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(Input))) != inputs.Length) throw new InvalidOperationException("Wheel SendInput failed");
    }
    public static void PressClient(IntPtr hwnd, uint pid, int x, int y) {
        if (Owner(hwnd) != pid) throw new InvalidOperationException("Click owner mismatch");
        var point = new Point { X = x, Y = y };
        if (!ClientToScreen(hwnd, ref point) || WindowFromPoint(point) != hwnd) throw new InvalidOperationException("Click target is not the owned HWND");
        var inputs = new Input[3];
        inputs[0].Data.Mouse = new Mouse { X = (int)Math.Round(point.X * 65535.0 / (GetSystemMetrics(0) - 1)), Y = (int)Math.Round(point.Y * 65535.0 / (GetSystemMetrics(1) - 1)), Flags = 0x8001 };
        inputs[1].Data.Mouse.Flags = 2;
        inputs[2].Data.Mouse.Flags = 4;
        if (SendInput(3, inputs, Marshal.SizeOf(typeof(Input))) != 3) throw new InvalidOperationException("Mouse SendInput failed");
    }
    public static void WheelOwnedTranscript(IntPtr main, uint pid, IntPtr transcript, int delta) {
        Rect rect;
        if (Owner(main) != pid || Class(main) != "ZigShell" || GetForegroundWindow() != main ||
            Owner(transcript) != pid || !IsChild(main, transcript) || Class(transcript) != "ZigShellChatTranscript" ||
            !IsWindowVisible(transcript) || !GetWindowRect(transcript, out rect)) throw new InvalidOperationException("Transcript wheel ownership mismatch");
        WheelTranscript(main, pid, transcript, (rect.Left + rect.Right) / 2, (rect.Top + rect.Bottom) / 2, delta);
    }
    [DllImport("user32.dll", EntryPoint="SendMessageTimeoutW", SetLastError=true)] static extern IntPtr SendWheelMessage(IntPtr hwnd, uint message, UIntPtr wParam, IntPtr lParam, uint flags, uint timeout, out IntPtr result);
    public static void WheelOwnedTranscriptMessage(IntPtr main, uint pid, IntPtr transcript, int delta) {
        Rect rect;
        if (Owner(main) != pid || Class(main) != "ZigShell" || GetForegroundWindow() != main ||
            Owner(transcript) != pid || !IsChild(main, transcript) || Class(transcript) != "ZigShellChatTranscript" ||
            !IsWindowVisible(transcript) || !GetWindowRect(transcript, out rect)) throw new InvalidOperationException("Owned transcript wheel ownership mismatch");
        if (delta == 0 || delta < short.MinValue || delta > short.MaxValue || delta % 120 != 0) throw new ArgumentOutOfRangeException("delta");
        int x = (rect.Left + rect.Right) / 2, y = (rect.Top + rect.Bottom) / 2;
        IntPtr result;
        if (SendWheelMessage(transcript, 0x020A, new UIntPtr(unchecked((uint)(ushort)delta << 16)), new IntPtr(unchecked((y << 16) | (x & 0xffff))), 2, 2000, out result) == IntPtr.Zero) throw new InvalidOperationException("Owned transcript WM_MOUSEWHEEL failed");
    }
    public static void PressOwnedTranscript(IntPtr main, uint pid, IntPtr transcript, int x, int y) {
        if (Owner(main) != pid || Class(main) != "ZigShell" || GetForegroundWindow() != main ||
            Owner(transcript) != pid || !IsChild(main, transcript) || Class(transcript) != "ZigShellChatTranscript" ||
            !IsWindowVisible(transcript)) throw new InvalidOperationException("Transcript click ownership mismatch");
        var point = new Point { X = x, Y = y };
        if (!ClientToScreen(transcript, ref point) || WindowFromPoint(point) != transcript) throw new InvalidOperationException("Click target is not the owned transcript");
        if (!SetCursorPos(point.X, point.Y)) throw new InvalidOperationException("Transcript pointer move failed");
        var inputs = new Input[2];
        inputs[0].Data.Mouse.Flags = 2;
        inputs[1].Data.Mouse.Flags = 4;
        if (SendInput(2, inputs, Marshal.SizeOf(typeof(Input))) != 2) throw new InvalidOperationException("Transcript click input failed");
    }
    public static void RightClickOwnedTranscript(IntPtr main, uint pid, IntPtr transcript, int x, int y) {
        if (Owner(main) != pid || Class(main) != "ZigShell" || GetForegroundWindow() != main ||
            Owner(transcript) != pid || !IsChild(main, transcript) || Class(transcript) != "ZigShellChatTranscript" ||
            !IsWindowVisible(transcript)) throw new InvalidOperationException("Transcript right-click ownership mismatch");
        var point = new Point { X = x, Y = y };
        if (WindowFromPoint(point) != transcript || !SetCursorPos(x, y)) throw new InvalidOperationException("Right-click target is not the owned transcript");
        var inputs = new Input[2];
        inputs[0].Data.Mouse.Flags = 8;
        inputs[1].Data.Mouse.Flags = 16;
        if (SendInput(2, inputs, Marshal.SizeOf(typeof(Input))) != 2) throw new InvalidOperationException("Transcript right-click input failed");
    }
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern short VkKeyScan(char character);
    public static void Character(char character) {
        short mapped = VkKeyScan(character);
        if (mapped == -1) throw new InvalidOperationException("Character has no keyboard mapping");
        var keys = new System.Collections.Generic.List<int>();
        if ((mapped & 0x100) != 0) keys.Add(0x10);
        if ((mapped & 0x200) != 0) keys.Add(0x11);
        if ((mapped & 0x400) != 0) keys.Add(0x12);
        keys.Add(mapped & 0xff);
        Chord(keys.ToArray());
    }
    public static void Type(ushort key) { Chord(new[] { (int)key }); }
}
