using System;
using System.Runtime.InteropServices;

public static class NativeConsoleControl {
    delegate IntPtr WindowProc(IntPtr hwnd, uint message, IntPtr w, IntPtr l);
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct WindowClass {
        public uint Style; public WindowProc Proc; public int ClassExtra, WindowExtra;
        public IntPtr Instance, Icon, Cursor, Background; public string Menu, Name;
    }
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern ushort RegisterClass(ref WindowClass cls);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr CreateWindowEx(uint extended, string cls, string title, uint style, int x, int y, int width, int height, IntPtr parent, IntPtr menu, IntPtr instance, IntPtr data);
    [DllImport("user32.dll")] static extern IntPtr DefWindowProc(IntPtr hwnd, uint message, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int command);
    [DllImport("user32.dll")] static extern bool DestroyWindow(IntPtr hwnd);
    [DllImport("user32.dll")] static extern IntPtr SetParent(IntPtr hwnd, IntPtr parent);
    [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr hwnd, int index, int value);
    [DllImport("user32.dll")] static extern bool MoveWindow(IntPtr hwnd, int x, int y, int width, int height, bool repaint);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] static extern IntPtr GetModuleHandle(string module);
    [DllImport("kernel32.dll")] static extern bool FreeConsole();
    [DllImport("kernel32.dll")] static extern bool AllocConsole();
    [DllImport("kernel32.dll")] static extern IntPtr GetConsoleWindow();
    [DllImport("kernel32.dll")] public static extern ulong GetTickCount64();
    static readonly WindowProc proc = DefWindowProc;
    static IntPtr main, console;
    public static long[] Create() {
        FreeConsole();
        if (!AllocConsole()) throw new Exception("Positive control could not allocate a native console");
        console = GetConsoleWindow();
        ShowWindow(console, 0);
        foreach (string name in new[] { "ZigShell", "ZigShellChatTranscript" }) {
            var cls = new WindowClass { Proc = proc, Name = name, Instance = GetModuleHandle(null) };
            if (RegisterClass(ref cls) == 0) throw new Exception("Positive control window class failed");
        }
        main = CreateWindowEx(0, "ZigShell", "Observer positive control", 0x00CF0000, 100, 100, 900, 700, IntPtr.Zero, IntPtr.Zero, GetModuleHandle(null), IntPtr.Zero);
        IntPtr chat = CreateWindowEx(0, "ZigShellChatTranscript", "", 0x40000000, 0, 0, 800, 600, main, IntPtr.Zero, GetModuleHandle(null), IntPtr.Zero);
        if (main == IntPtr.Zero || chat == IntPtr.Zero || console == IntPtr.Zero) throw new Exception("Positive control windows missing");
        SetParent(console, main);
        SetWindowLong(console, -16, 0x40000000);
        MoveWindow(console, 0, 0, 800, 600, false);
        ShowWindow(main, 4);
        ShowWindow(chat, 4);
        return new[] { main.ToInt64(), console.ToInt64() };
    }
    public static void Flash() { ShowWindow(console, 4); ShowWindow(console, 0); }
    public static void Close() {
        ShowWindow(console, 0);
        SetParent(console, IntPtr.Zero);
        FreeConsole();
        if (main != IntPtr.Zero) DestroyWindow(main);
    }
}
