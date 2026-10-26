using System;
using System.Collections.Generic;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Threading;

public static class WindowControlsProof {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] struct MonitorInfo { public int Size; public Rect Monitor, Work; public uint Flags; }
    [DllImport("user32.dll")] static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);
    [DllImport("user32.dll")] static extern bool GetMonitorInfoW(IntPtr monitor, ref MonitorInfo info);
    [DllImport("user32.dll")] static extern bool IsZoomed(IntPtr hwnd);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr hwnd, ref Point point);
    [DllImport("user32.dll")] static extern uint GetDpiForWindow(IntPtr hwnd);
    [DllImport("user32.dll")] static extern bool AdjustWindowRectExForDpi(ref Rect rect, uint style, bool menu, uint exStyle, uint dpi);
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] static extern void mouse_event(uint flags, uint x, uint y, uint data, UIntPtr extra);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hwnd);
    [DllImport("user32.dll")] static extern IntPtr SendMessageTimeoutW(IntPtr hwnd, uint msg, UIntPtr wp, IntPtr lp, uint flags, uint timeout, out UIntPtr result);
    public static int[] Geometry(IntPtr hwnd) {
        Rect frame, client;
        Point origin = new Point();
        if (!GetWindowRect(hwnd, out frame) || !GetClientRect(hwnd, out client) || !ClientToScreen(hwnd, ref origin)) throw new InvalidOperationException("Window geometry unavailable");
        uint dpi = GetDpiForWindow(hwnd);
        Rect native = new Rect { Right = client.Right, Bottom = client.Bottom };
        if (!AdjustWindowRectExForDpi(ref native, 0x00CF0000, false, 0, dpi)) throw new InvalidOperationException("Native caption comparison unavailable");
        MonitorInfo monitor = new MonitorInfo { Size = Marshal.SizeOf(typeof(MonitorInfo)) };
        if (!GetMonitorInfoW(MonitorFromWindow(hwnd, 2), ref monitor)) throw new InvalidOperationException("Monitor work area unavailable");
        return new int[] { frame.Left, frame.Top, frame.Right, frame.Bottom, origin.X, origin.Y, client.Right, client.Bottom, (int)dpi, -native.Top, monitor.Work.Left, monitor.Work.Top, monitor.Work.Right, monitor.Work.Bottom, IsZoomed(hwnd) ? 1 : 0 };
    }
    public static int Hit(IntPtr hwnd, int x, int y) {
        Point point = new Point { X = x, Y = y };
        if (!ClientToScreen(hwnd, ref point)) throw new InvalidOperationException("Hit-test coordinate unavailable");
        UIntPtr result;
        int packed = (point.X & 65535) | ((point.Y & 65535) << 16);
        if (SendMessageTimeoutW(hwnd, 0x84, UIntPtr.Zero, new IntPtr(packed), 2, 2000, out result) == IntPtr.Zero) throw new InvalidOperationException("Window hit test timed out");
        return (int)result.ToUInt64();
    }
    static Point OwnedPoint(IntPtr hwnd, int x, int y) {
        Point point = new Point { X = x, Y = y };
        if (GetForegroundWindow() != hwnd || !ClientToScreen(hwnd, ref point) || WindowFromPoint(point) != hwnd) throw new InvalidOperationException("Refusing input outside the owned foreground frame");
        return point;
    }
    public static void Drag(IntPtr hwnd, int x, int y, int dx, int dy) {
        Point point = OwnedPoint(hwnd, x, y);
        SetCursorPos(point.X, point.Y);
        mouse_event(2, 0, 0, 0, UIntPtr.Zero);
        try {
            for (int i = 1; i <= 20; i++) {
                SetCursorPos(point.X + dx * i / 20, point.Y + dy * i / 20);
                Thread.Sleep(20);
            }
        } finally { mouse_event(4, 0, 0, 0, UIntPtr.Zero); }
    }
    public static void DoubleClick(IntPtr hwnd, int x, int y) {
        Point point = OwnedPoint(hwnd, x, y);
        SetCursorPos(point.X, point.Y);
        for (int i = 0; i < 2; i++) {
            mouse_event(2, 0, 0, 0, UIntPtr.Zero);
            mouse_event(4, 0, 0, 0, UIntPtr.Zero);
            Thread.Sleep(60);
        }
    }
    public static int CompareControls(string reference, string actual, int[] geometry, int buttonWidth, int buttonHeight) {
        int differences = 0;
        using (Bitmap before = new Bitmap(reference))
        using (Bitmap after = new Bitmap(actual)) {
            int left = geometry[4] - geometry[0], top = geometry[5] - geometry[1];
            for (int y = top; y < top + buttonHeight; y++) {
                for (int x = left + geometry[6] - buttonWidth * 3; x < left + geometry[6]; x++) {
                    Color a = before.GetPixel(x, y), b = after.GetPixel(x, y);
                    if (Math.Max(Math.Abs(a.R - b.R), Math.Max(Math.Abs(a.G - b.G), Math.Abs(a.B - b.B))) > 8) differences++;
                }
            }
        }
        return differences;
    }
    public static void NegativeControl(string source, string target, int[] geometry, int buttonWidth) {
        using (Bitmap image = new Bitmap(source)) {
            int x = geometry[4] - geometry[0] + geometry[6] - buttonWidth * 3 + 8;
            int y = geometry[5] - geometry[1] + 8;
            Color prior = image.GetPixel(x, y);
            image.SetPixel(x, y, prior.R < 128 ? Color.White : Color.Black);
            image.Save(target);
        }
    }
    static int Delta(Color a, Color b) {
        return Math.Max(Math.Abs(a.R - b.R), Math.Max(Math.Abs(a.G - b.G), Math.Abs(a.B - b.B)));
    }
    public static Dictionary<string, object> Pixels(string path, int[] geometry, int sidebar, int buttonWidth, int buttonHeight, bool light) {
        var output = new Dictionary<string, object>();
        int topGap = geometry[5] - geometry[1];
        int leftGap = geometry[4] - geometry[0];
        int[] ink = new int[3];
        int separator = 0;
        using (Bitmap image = new Bitmap(path)) {
            for (int button = 0; button < 3; button++) {
                int center = leftGap + geometry[6] - buttonWidth * (3 - button) + buttonWidth / 2;
                for (int y = topGap + buttonHeight / 2 - 8; y <= topGap + buttonHeight / 2 + 8; y++) {
                    for (int x = center - 8; x <= center + 8; x++) {
                        Color p = image.GetPixel(x, y);
                        int bright = Math.Max(p.R, Math.Max(p.G, p.B));
                        if (light ? bright < 180 : bright > 80) ink[button]++;
                    }
                }
            }
            for (int y = topGap; y < topGap + 6; y++) {
                Color p = image.GetPixel(leftGap + sidebar - 1, y);
                Color neighbor = image.GetPixel(leftGap + sidebar - 3, y);
                if (Math.Abs(p.R - neighbor.R) + Math.Abs(p.G - neighbor.G) + Math.Abs(p.B - neighbor.B) >= 12) separator++;
            }
            int dpi = geometry[8];
            int start = leftGap + 240 * dpi / 96, end = leftGap + geometry[6] - 140 * dpi / 96;
            Color backdrop = image.GetPixel(start, topGap + 4 * dpi / 96);
            int minX = end, minY = image.Height, maxX = 0, maxY = 0;
            for (int y = topGap + 8 * dpi / 96; y < topGap + 55 * dpi / 96; y++) {
                for (int x = start; x < end; x++) {
                    if (Delta(image.GetPixel(x, y), backdrop) <= 2) continue;
                    minX = Math.Min(minX, x); maxX = Math.Max(maxX, x + 1);
                    minY = Math.Min(minY, y); maxY = Math.Max(maxY, y + 1);
                }
            }
            int titleInk = 0;
            if (maxX > minX && maxY > minY) {
                Color fill = image.GetPixel(minX + 8 * dpi / 96, (minY + maxY) / 2);
                for (int y = minY + 3 * dpi / 96; y < maxY - 3 * dpi / 96; y++) {
                    for (int x = minX + 16 * dpi / 96; x < maxX - 16 * dpi / 96; x++) {
                        if (Delta(image.GetPixel(x, y), fill) > 80) titleInk++;
                    }
                }
            }
            output["titleBounds"] = new int[] { minX, minY, maxX, maxY };
            output["titleInkPixels"] = titleInk;
        }
        output["topInset"] = topGap;
        output["captionInset"] = geometry[5] - (geometry[14] == 1 ? geometry[11] : geometry[1]);
        output["clientInsideWorkArea"] = geometry[14] != 1 || (geometry[4] == geometry[10] && geometry[5] == geometry[11] && geometry[4] + geometry[6] == geometry[12] && geometry[5] + geometry[7] == geometry[13]);
        output["nativeTopInset"] = geometry[9];
        output["recoveredTopPixels"] = geometry[9] - topGap;
        output["glyphPixels"] = ink;
        output["separatorTopPixels"] = separator;
        return output;
    }
}
