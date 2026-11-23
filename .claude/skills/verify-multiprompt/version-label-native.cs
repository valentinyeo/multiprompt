using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class VerifyVersionLabel {
    [StructLayout(LayoutKind.Sequential)]
    struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
    static extern int AddFontResourceEx(string path, uint flags, IntPtr reserved);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
    static extern bool RemoveFontResourceEx(string path, uint flags, IntPtr reserved);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr CreateFont(int height, int width, int escapement, int orientation, int weight, uint italic, uint underline, uint strikeout, uint charset, uint output, uint clip, uint quality, uint pitch, string face);
    [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc, IntPtr value);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr value);
    [DllImport("gdi32.dll")] static extern int SetBkMode(IntPtr dc, int mode);
    [DllImport("gdi32.dll")] static extern uint SetTextColor(IntPtr dc, uint color);
    [DllImport("gdi32.dll")] static extern uint SetBkColor(IntPtr dc, uint color);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern int DrawText(IntPtr dc, string text, int length, ref Rect rect, uint flags);

    public static int[] Assert(string screenshot, int left, int top, int width, int height, int fontHeight, string fontPath, string version, int ink, string referencePath, int paddingLeft, int paddingRight) {
        if (AddFontResourceEx(fontPath, 16, IntPtr.Zero) == 0) throw new Exception("Version reference font could not be loaded");
        try {
            using (var screen = new Bitmap(screenshot))
            using (var expected = new Bitmap(width, height, PixelFormat.Format32bppRgb)) {
                Color background = screen.GetPixel(left, top);
                using (var graphics = Graphics.FromImage(expected)) {
                    graphics.Clear(background);
                    IntPtr dc = graphics.GetHdc();
                    IntPtr font = CreateFont(-fontHeight, 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 5, 0, "IBM Plex Sans");
                    IntPtr old = SelectObject(dc, font);
                    try {
                        SetBkMode(dc, 2);
                        SetBkColor(dc, (uint)(background.R | background.G << 8 | background.B << 16));
                        SetTextColor(dc, (uint)(ink | ink << 8 | ink << 16));
                        var rect = new Rect { Left = paddingLeft, Right = width - paddingRight, Bottom = height };
                        if (DrawText(dc, version, version.Length, ref rect, 0x20 | 0x4 | 0x800 | 0x8000) == 0) throw new Exception("Expected version text could not be drawn");
                    } finally {
                        SelectObject(dc, old);
                        DeleteObject(font);
                        graphics.ReleaseHdc(dc);
                    }
                }
                expected.Save(referencePath, ImageFormat.Png);
                int inkPixels = 0;
                int differences = 0;
                int minX = width, minY = height, maxX = -1, maxY = -1;
                for (int y = 0; y < height; y++) {
                    for (int x = 0; x < width; x++) {
                        Color actual = screen.GetPixel(left + x, top + y);
                        Color wanted = expected.GetPixel(x, y);
                        bool actualInk = Math.Abs(actual.R - background.R) + Math.Abs(actual.G - background.G) + Math.Abs(actual.B - background.B) > 45;
                        bool expectedInk = Math.Abs(wanted.R - background.R) + Math.Abs(wanted.G - background.G) + Math.Abs(wanted.B - background.B) > 45;
                        if (actualInk) {
                            minX = Math.Min(minX, x); minY = Math.Min(minY, y);
                            maxX = Math.Max(maxX, x); maxY = Math.Max(maxY, y);
                        }
                        if (expectedInk) inkPixels++;
                        if (actualInk != expectedInk) differences++;
                    }
                }
                if (inkPixels < 30 || differences != 0) throw new Exception("Version pixels do not match " + version + ": " + differences + " differing pixels, " + inkPixels + " expected ink pixels");
                return new int[] { inkPixels, left + minX, top + minY, maxX - minX + 1, maxY - minY + 1 };
            }
        } finally { RemoveFontResourceEx(fontPath, 16, IntPtr.Zero); }
    }
}
