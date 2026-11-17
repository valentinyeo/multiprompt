using System;
using System.Runtime.InteropServices;
using System.Text;

public static class NativeConsoleControl {
    delegate IntPtr WindowProc(IntPtr hwnd, uint message, IntPtr w, IntPtr l);
    delegate bool EnumProc(IntPtr hwnd, IntPtr data);
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct WindowClass {
        public uint Style; public WindowProc Proc; public int ClassExtra, WindowExtra;
        public IntPtr Instance, Icon, Cursor, Background; public string Menu, Name;
    }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct StartupInfo {
        public int Size; public string Reserved, Desktop, Title;
        public uint X, Y, XSize, YSize, XChars, YChars, Fill, Flags;
        public ushort Show, ReservedSize; public IntPtr ReservedBytes, Input, Output, Error;
    }
    [StructLayout(LayoutKind.Sequential)] struct ProcessInfo { public IntPtr Process, Thread; public uint Pid, Tid; }
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern ushort RegisterClass(ref WindowClass cls);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr CreateWindowEx(uint extended, string cls, string title, uint style, int x, int y, int width, int height, IntPtr parent, IntPtr menu, IntPtr instance, IntPtr data);
    [DllImport("user32.dll")] static extern IntPtr DefWindowProc(IntPtr hwnd, uint message, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr hwnd, int command);
    [DllImport("user32.dll")] static extern bool DestroyWindow(IntPtr hwnd);
    [DllImport("user32.dll")] static extern IntPtr SetParent(IntPtr hwnd, IntPtr parent);
    [DllImport("user32.dll")] static extern IntPtr GetParent(IntPtr hwnd);
    [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr hwnd, int index, int value);
    [DllImport("user32.dll")] static extern bool MoveWindow(IntPtr hwnd, int x, int y, int width, int height, bool repaint);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int width, int height, uint flags);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc callback, IntPtr data);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder text, int length);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int length);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] static extern IntPtr GetModuleHandle(string module);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool CreateProcess(string app, StringBuilder command, IntPtr processAttributes, IntPtr threadAttributes, bool inherit, uint flags, IntPtr environment, string directory, ref StartupInfo startup, out ProcessInfo process);
    [DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr process, uint code);
    [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll")] public static extern ulong GetTickCount64();
    static readonly WindowProc proc = DefWindowProc;
    static readonly string title = "native-console-control-" + Guid.NewGuid().ToString("N");
    static IntPtr main, console, process;
    public static void Create() {
        string exe = Environment.GetEnvironmentVariable("ComSpec");
        var startup = new StartupInfo { Size = Marshal.SizeOf(typeof(StartupInfo)), Title = title, Flags = 1, Show = 0 };
        ProcessInfo child;
        if (!CreateProcess(exe, new StringBuilder("\"" + exe + "\" /d /q /k title " + title), IntPtr.Zero, IntPtr.Zero, false, 0x10, IntPtr.Zero, null, ref startup, out child)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        process = child.Process;
        CloseHandle(child.Thread);
        foreach (string name in new[] { "ZigShell", "ZigShellChatTranscript" }) {
            var cls = new WindowClass { Proc = proc, Name = name, Instance = GetModuleHandle(null) };
            if (RegisterClass(ref cls) == 0) throw new Exception("Positive control window class failed");
        }
        main = CreateWindowEx(0, "ZigShell", "Observer positive control", 0x00CF0000, 100, 100, 900, 700, IntPtr.Zero, IntPtr.Zero, GetModuleHandle(null), IntPtr.Zero);
        IntPtr chat = CreateWindowEx(0, "ZigShellChatTranscript", "", 0x40000000, 0, 0, 800, 600, main, IntPtr.Zero, GetModuleHandle(null), IntPtr.Zero);
        if (main == IntPtr.Zero || chat == IntPtr.Zero) throw new Exception("Positive control windows missing");
        ShowWindow(main, 4);
        ShowWindow(chat, 4);
    }
    public static bool Attach() {
        EnumWindows(delegate(IntPtr hwnd, IntPtr data) {
            var name = new StringBuilder(256);
            var text = new StringBuilder(256);
            GetClassName(hwnd, name, name.Capacity);
            GetWindowText(hwnd, text, text.Capacity);
            if (name.ToString() == "ConsoleWindowClass" && text.ToString() == title) { console = hwnd; return false; }
            return true;
        }, IntPtr.Zero);
        if (console == IntPtr.Zero) return false;
        ShowWindow(console, 0);
        SetParent(console, main);
        SetWindowLong(console, -16, 0x40000000);
        if (GetParent(console) != main || !MoveWindow(console, 0, 0, 800, 600, false)) throw new Exception("Positive control console adoption failed");
        return true;
    }
    public static long[] Handles() { return new[] { main.ToInt64(), console.ToInt64() }; }
    public static void Flash() {
        if (!SetWindowPos(console, IntPtr.Zero, 0, 0, 0, 0, 0x13)) throw new Exception("Positive control console Z-order failed");
        ShowWindow(console, 4);
        ShowWindow(console, 0);
    }
    public static void Close() {
        if (console != IntPtr.Zero) { ShowWindow(console, 0); SetParent(console, IntPtr.Zero); }
        if (main != IntPtr.Zero) DestroyWindow(main);
        if (process != IntPtr.Zero) {
            TerminateProcess(process, 0);
            uint stopped = WaitForSingleObject(process, 10000);
            CloseHandle(process);
            process = IntPtr.Zero;
            if (stopped != 0) throw new Exception("Positive control console process survived cleanup");
        }
    }
}
