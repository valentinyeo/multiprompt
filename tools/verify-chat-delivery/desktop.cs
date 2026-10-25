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
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint message, IntPtr capacity, StringBuilder text, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint count, Input[] inputs, int size);
    public static uint Owner(IntPtr hwnd) { uint pid; GetWindowThreadProcessId(hwnd, out pid); return pid; }
    public static string Class(IntPtr hwnd) { var text = new StringBuilder(256); GetClassName(hwnd, text, text.Capacity); return text.ToString(); }
    public static IntPtr Window(uint pid) { IntPtr found = IntPtr.Zero; EnumWindows((h,p) => { if (Owner(h) == pid && IsWindowVisible(h) && Class(h) == "ZigShell") { found = h; return false; } return true; }, IntPtr.Zero); return found; }
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
    public static void ClickClient(IntPtr hwnd, uint pid, int x, int y) {
        if (Owner(hwnd) != pid) throw new InvalidOperationException("Click owner mismatch");
        var point = new Point { X = x, Y = y };
        if (!ClientToScreen(hwnd, ref point) || WindowFromPoint(point) != hwnd) throw new InvalidOperationException("Click target is not the owned HWND");
        var inputs = new Input[3];
        inputs[0].Data.Mouse = new Mouse { X = (int)Math.Round(point.X * 65535.0 / (GetSystemMetrics(0) - 1)), Y = (int)Math.Round(point.Y * 65535.0 / (GetSystemMetrics(1) - 1)), Flags = 0x8001 };
        inputs[1].Data.Mouse.Flags = 2;
        inputs[2].Data.Mouse.Flags = 4;
        if (SendInput(3, inputs, Marshal.SizeOf(typeof(Input))) != 3) throw new InvalidOperationException("Mouse SendInput failed");
    }
    public static void Type(ushort key) { Chord(new[] { (int)key }); }
}
