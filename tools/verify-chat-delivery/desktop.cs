using System;
using System.Runtime.InteropServices;
using System.Text;
public static class ChatDeliveryDesktop {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
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
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
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
    public static void Type(ushort key) { Chord(new[] { (int)key }); }
}
