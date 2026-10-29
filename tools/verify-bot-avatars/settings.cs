using System;
using System.Runtime.InteropServices;
using System.Text;
public static class BotSettingsDesktop {
    delegate bool EnumProc(IntPtr hwnd, IntPtr parameter);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc callback, IntPtr parameter);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumProc callback, IntPtr parameter);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder text, int length);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] static extern uint GetDpiForWindow(IntPtr hwnd);
    [DllImport("user32.dll")] static extern bool RedrawWindow(IntPtr hwnd, IntPtr rect, IntPtr region, uint flags);
    [DllImport("user32.dll")] static extern IntPtr SendMessageW(IntPtr hwnd, uint message, IntPtr wp, IntPtr lp);
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    static bool Matches(IntPtr hwnd, uint pid, string name) {
        uint actual;
        GetWindowThreadProcessId(hwnd, out actual);
        var text = new StringBuilder(128);
        GetClassName(hwnd, text, text.Capacity);
        return actual == pid && IsWindowVisible(hwnd) && text.ToString() == name;
    }
    public static IntPtr Panel(uint pid) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((h,p) => { if (Matches(h, pid, "MultipromptSettings")) { found = h; return false; } return true; }, IntPtr.Zero);
        return found;
    }
    public static IntPtr Content(IntPtr panel, uint pid) {
        IntPtr found = IntPtr.Zero;
        EnumChildWindows(panel, (h,p) => { if (Matches(h, pid, "MultipromptSettingsContent")) { found = h; return false; } return true; }, IntPtr.Zero);
        return found;
    }
    public static void Scroll(IntPtr content, uint pid, int notches) {
        if (!Matches(content, pid, "MultipromptSettingsContent")) throw new InvalidOperationException("Settings owner mismatch");
        SendMessageW(content, 0x020a, new IntPtr(unchecked((-120 * notches) << 16)), IntPtr.Zero);
        RedrawWindow(content, IntPtr.Zero, IntPtr.Zero, 0x0101);
    }
    public static int Scale(IntPtr content, int value) { return value * (int)GetDpiForWindow(content) / 96; }
    public static int ColorsTop(IntPtr content) {
        Rect rect;
        if (!GetClientRect(content, out rect)) throw new InvalidOperationException("Settings bounds unavailable");
        return Scale(content, rect.Right < Scale(content, 440) ? 252 : 212);
    }
}
