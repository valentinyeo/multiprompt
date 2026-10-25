using System;
using System.Collections.Generic;
using System.Drawing;
using System.Runtime.InteropServices;

public static class CaptionProof {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
    [DllImport("user32.dll")] static extern int GetDisplayConfigBufferSizes(uint flags, out uint paths, out uint modes);
    [DllImport("user32.dll")] static extern int QueryDisplayConfig(uint flags, ref uint paths, IntPtr path, ref uint modes, IntPtr mode, IntPtr topology);
    [DllImport("user32.dll")] static extern int DisplayConfigGetDeviceInfo(IntPtr packet);
    [DllImport("user32.dll")] static extern int DisplayConfigSetDeviceInfo(IntPtr packet);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr hwnd, ref Point point);
    [DllImport("user32.dll")] static extern uint GetDpiForWindow(IntPtr hwnd);
    [DllImport("user32.dll")] static extern uint GetDpiForSystem();
    [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr hwnd, uint attribute, out Rect rect, uint size);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool EnumDisplaySettings(string device, int mode, IntPtr settings);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int ChangeDisplaySettings(IntPtr settings, uint flags);
    static byte[] originalDisplay;
    static byte[] source;
    static int originalRelative, recommendedIndex;
    static bool originalKnown;
    static readonly int[] scales = { 100, 125, 150, 175, 200, 225, 250, 300, 350, 400, 450, 500 };
    static void Require(bool value, string detail) {
        if (!value) throw new InvalidOperationException("IGSH-845 " + detail);
    }
    static IntPtr Packet(int type, int size) {
        IntPtr packet = Marshal.AllocHGlobal(size);
        for (int i = 0; i < size; i++) Marshal.WriteByte(packet, i, 0);
        Marshal.WriteInt32(packet, 0, type);
        Marshal.WriteInt32(packet, 4, size);
        Marshal.Copy(source, 0, IntPtr.Add(packet, 8), 12);
        return packet;
    }
    public static void SetDpi(int dpi) {
        Require(SetThreadDpiAwarenessContext(new IntPtr(-4)) != IntPtr.Zero, "per-monitor awareness unavailable");
        IntPtr settings = Marshal.AllocHGlobal(220);
        try {
            for (int i = 0; i < 220; i++) Marshal.WriteByte(settings, i, 0);
            Marshal.WriteInt16(settings, 68, 220);
            Require(EnumDisplaySettings(null, -1, settings), "current display mode unavailable");
            originalDisplay = new byte[220];
            Marshal.Copy(settings, originalDisplay, 0, 220);
            if (Marshal.ReadInt32(settings, 172) < 1920 || Marshal.ReadInt32(settings, 176) < 1080) {
                Marshal.WriteInt32(settings, 72, 0x180000);
                Marshal.WriteInt32(settings, 172, 1920);
                Marshal.WriteInt32(settings, 176, 1080);
                Require(ChangeDisplaySettings(settings, 0) == 0, "1920x1080 disposable display mode unavailable");
            }
        } finally { Marshal.FreeHGlobal(settings); }
        uint paths, modes;
        Require(GetDisplayConfigBufferSizes(2, out paths, out modes) == 0 && paths > 0, "display paths unavailable");
        IntPtr path = Marshal.AllocHGlobal((int)paths * 72), mode = Marshal.AllocHGlobal((int)modes * 64);
        try {
            Require(QueryDisplayConfig(2, ref paths, path, ref modes, mode, IntPtr.Zero) == 0 && paths == 1, "requires one active disposable runner display");
            source = new byte[12];
            Marshal.Copy(path, source, 0, 12);
        } finally { Marshal.FreeHGlobal(path); Marshal.FreeHGlobal(mode); }
        IntPtr get = Packet(-3, 32);
        try {
            Require(DisplayConfigGetDeviceInfo(get) == 0, "monitor DPI query unsupported");
            originalRelative = Marshal.ReadInt32(get, 24);
            originalKnown = true;
            int current = Array.IndexOf(scales, (int)GetDpiForSystem() * 100 / 96);
            Require(current >= 0, "unrecognized initial DPI");
            recommendedIndex = current - originalRelative;
            int desired = Array.IndexOf(scales, dpi * 100 / 96) - recommendedIndex;
            Require(Array.IndexOf(scales, dpi * 100 / 96) >= 0 && desired >= Marshal.ReadInt32(get, 20) && desired <= Marshal.ReadInt32(get, 28), "requested real monitor DPI unavailable");
            SetRelative(desired);
        } finally { Marshal.FreeHGlobal(get); }
    }
    static void SetRelative(int relative) {
        IntPtr packet = Packet(-4, 24);
        try {
            Marshal.WriteInt32(packet, 20, relative);
            Require(DisplayConfigSetDeviceInfo(packet) == 0, "monitor DPI change failed");
        } finally { Marshal.FreeHGlobal(packet); }
    }
    public static void RestoreDpi() {
        try { if (originalKnown) SetRelative(originalRelative); }
        finally {
            if (originalDisplay != null) {
                IntPtr settings = Marshal.AllocHGlobal(originalDisplay.Length);
                try {
                    Marshal.Copy(originalDisplay, 0, settings, originalDisplay.Length);
                    Require(ChangeDisplaySettings(settings, 0) == 0, "original display mode restore failed");
                } finally { Marshal.FreeHGlobal(settings); }
            }
        }
    }
    public static int[] Geometry(IntPtr hwnd) {
        Rect frame, buttons;
        Point client = new Point();
        Require(GetWindowRect(hwnd, out frame) && ClientToScreen(hwnd, ref client), "caption geometry unavailable");
        Require(DwmGetWindowAttribute(hwnd, 5, out buttons, 16) == 0 && buttons.Right > buttons.Left && buttons.Bottom > buttons.Top, "DWM button bounds unavailable");
        return new int[] { frame.Left, frame.Top, frame.Right, frame.Bottom, buttons.Left, buttons.Top, buttons.Right, client.Y - frame.Top, (int)GetDpiForWindow(hwnd) };
    }
    static int Bright(Color pixel) { return Math.Max(pixel.R, Math.Max(pixel.G, pixel.B)); }
    static int Delta(Color a, Color b) { return Math.Max(Math.Abs(a.R - b.R), Math.Max(Math.Abs(a.G - b.G), Math.Abs(a.B - b.B))); }
    public static Dictionary<string, object> Measure(string referencePath, string actualPath, int[] geometry, int[] browser, int[][] masks, string browserTheme) {
        var proof = new Dictionary<string, object>();
        double scale = geometry[8] / 96.0;
        int left = geometry[4] - (int)Math.Ceiling(12 * scale), top = geometry[5], right = geometry[6], bottom = geometry[7];
        int mismatches = 0, nonBlack = 0, greyBandPixels = 0;
        var glyphs = new List<int[]>();
        int[] maskRect = null;
        int candidates = 0;
        foreach (int[] rect in masks) {
            int width = Math.Min(rect[2], browser[2]) - Math.Max(rect[0], browser[0]);
            int height = Math.Min(rect[3], browser[3]) - Math.Max(rect[1], browser[1]);
            if (rect[1] <= browser[1] && rect[2] >= browser[2] && width >= 100 * scale && width <= 180 * scale && height >= 24 * scale && height <= 40 * scale) { maskRect = rect; candidates++; }
        }
        Require(candidates == 1, "expected exactly one Chromium controls mask");
        using (var reference = new Bitmap(referencePath))
        using (var actual = new Bitmap(actualPath)) {
            Require(reference.Size == actual.Size && left >= 0 && top >= 0 && right <= actual.Width && bottom <= actual.Height && bottom > top, "invalid caption capture bounds");
            int start = -1, minY = bottom, maxY = top, area = 0;
            for (int x = left; x <= right; x++) {
                bool occupied = false;
                for (int y = top; x < right && y < bottom; y++) {
                    if (Bright(reference.GetPixel(x, y)) <= 8) continue;
                    occupied = true; minY = Math.Min(minY, y); maxY = Math.Max(maxY, y); area++;
                }
                if (occupied && start < 0) start = x;
                if (!occupied && start >= 0) {
                    glyphs.Add(new int[] { start, minY, x, maxY + 1, area });
                    start = -1; minY = bottom; maxY = top; area = 0;
                }
            }
            for (int y = top; y < bottom; y++) {
                int rowGrey = 0;
                for (int x = left; x < right; x++) {
                    Color expected = reference.GetPixel(x, y), pixel = actual.GetPixel(x, y);
                    if (Delta(expected, pixel) > 8) mismatches++;
                    if (Bright(expected) <= 8 && Bright(pixel) > 8) nonBlack++;
                    if (pixel.R >= 80 && pixel.G >= 80 && pixel.B >= 80 && Math.Abs(pixel.R - pixel.G) <= 10 && Math.Abs(pixel.G - pixel.B) <= 10) rowGrey++;
                }
                if (rowGrey > (right - left) / 2) greyBandPixels += rowGrey;
            }
            int apronNonBlack = 0, apronPixels = 0;
            int apronTop = Math.Max(maskRect[1], geometry[1] + bottom);
            for (int y = apronTop; y < browser[1]; y++) {
                for (int x = maskRect[0]; x < Math.Min(maskRect[2], geometry[2]); x++) {
                    apronPixels++;
                    if (Bright(actual.GetPixel(x - geometry[0], y - geometry[1])) > 8) apronNonBlack++;
                }
            }
            int sampleX = (maskRect[0] + browser[2]) / 2;
            Color apron = actual.GetPixel(sampleX - geometry[0], apronTop - geometry[1]);
            Color chrome = actual.GetPixel(maskRect[0] - (int)Math.Ceiling(4 * scale) - geometry[0], browser[1] + (int)(12 * scale) - geometry[1]);
            Color interior = actual.GetPixel(sampleX - geometry[0], browser[1] + (int)(12 * scale) - geometry[1]);
            int framePixels = 0, frameMismatches = 0;
            int referenceX = maskRect[0] - (int)Math.Ceiling(4 * scale);
            int referenceY = maskRect[3] + (int)Math.Ceiling(8 * scale);
            for (int y = browser[1]; y < browser[1] + (int)(3 * scale); y++) {
                Color expected = actual.GetPixel(referenceX - geometry[0], y - geometry[1]);
                for (int x = maskRect[0]; x < browser[2] - (int)Math.Ceiling(24 * scale); x++) {
                    framePixels++;
                    if (Delta(expected, actual.GetPixel(x - geometry[0], y - geometry[1])) > 8) frameMismatches++;
                }
            }
            for (int x = browser[2] - (int)(6 * scale); x < Math.Min(maskRect[2], geometry[2]); x++) {
                Color expected = actual.GetPixel(x - geometry[0], referenceY - geometry[1]);
                for (int y = browser[1] + (int)Math.Ceiling(20 * scale); y < maskRect[3]; y++) {
                    framePixels++;
                    if (Delta(expected, actual.GetPixel(x - geometry[0], y - geometry[1])) > 8) frameMismatches++;
                }
            }
            proof["framePixels"] = framePixels; proof["frameMismatches"] = frameMismatches;
            proof["captionRect"] = new int[] { left, top, right, bottom };
            proof["glyphBoundsAndAreas"] = glyphs;
            proof["captionMismatches"] = mismatches; proof["nonBlackBackgroundPixels"] = nonBlack; proof["greyBandPixels"] = greyBandPixels;
            proof["appMaskRect"] = new int[] { maskRect[0], apronTop, maskRect[2], browser[1] };
            proof["appMaskPixels"] = apronPixels; proof["appMaskNonBlackPixels"] = apronNonBlack;
            proof["appMaskColor"] = new int[] { apron.R, apron.G, apron.B };
            proof["browserChromeColor"] = new int[] { chrome.R, chrome.G, chrome.B };
            proof["browserMaskColor"] = new int[] { interior.R, interior.G, interior.B };
            proof["appMaskChromeDelta"] = Delta(apron, chrome); proof["browserMaskChromeDelta"] = Delta(interior, chrome);
            proof["browserThemeObserved"] = browserTheme == "light" ? chrome.R >= 160 && chrome.G >= 160 && chrome.B >= 160 : chrome.R >= 16 && chrome.G >= 16 && chrome.B >= 16 && Bright(chrome) <= 100;
            proof["tolerance"] = 8; proof["geometry"] = geometry; proof["browserRect"] = browser; proof["maskRects"] = masks;
        }
        return proof;
    }
    public static void CheckFrame(Dictionary<string, object> proof) {
        Require((int)proof["framePixels"] > 0 && (int)proof["frameMismatches"] == 0, "IGSH-858 controls cover overlaps the surrounding browser frame");
    }
    public static void Check(Dictionary<string, object> proof) {
        var glyphs = (List<int[]>)proof["glyphBoundsAndAreas"];
        double scale = ((int[])proof["geometry"])[8] / 96.0;
        Require(glyphs.Count == 3, "baseline must contain exactly three distinct glyph shapes");
        for (int i = 0; i < 3; i++) {
            int[] glyph = glyphs[i];
            Require(glyph[2] - glyph[0] >= 6 * scale && glyph[2] - glyph[0] <= 20 * scale && glyph[4] >= 6 * scale, "missing or malformed native glyph");
            Require(i == 0 ? glyph[3] - glyph[1] <= 3 * scale : glyph[3] - glyph[1] >= 6 * scale && glyph[3] - glyph[1] <= 20 * scale, "minimize/maximize-or-restore/close glyph signature mismatch");
        }
        Require((bool)proof["browserThemeObserved"], "browser chrome does not have the requested light/dark theme");
        Require((int)proof["captionMismatches"] == 0 && (int)proof["nonBlackBackgroundPixels"] == 0 && (int)proof["greyBandPixels"] == 0, "caption doubled-pixel signature or non-black band differs from the single native set");
        Require((int)proof["appMaskPixels"] > 0 && (int)proof["appMaskNonBlackPixels"] == 0 && (int)proof["appMaskChromeDelta"] > 8, "caption-facing mask must follow app black, not browser chrome");
        Require((int)proof["browserMaskChromeDelta"] <= 10, "IGSH-810 browser-interior mask must still match browser chrome");
    }
    public static void NegativeControls(string referencePath, int[] geometry, string output) {
        int left = geometry[4], top = geometry[5], right = geometry[6], bottom = geometry[7];
        using (var reference = new Bitmap(referencePath))
        using (var doubled = new Bitmap(reference))
        using (var band = new Bitmap(reference)) {
            int shift = Math.Max(2, geometry[8] / 48), doubledChanges = 0, bandChanges = 0;
            for (int y = top; y < bottom - shift; y++) for (int x = left; x < right - shift; x++) {
                if (Bright(reference.GetPixel(x, y)) > 8 && Bright(reference.GetPixel(x + shift, y + shift)) <= 8) {
                    doubled.SetPixel(x + shift, y + shift, Color.FromArgb(96, 96, 96)); doubledChanges++;
                }
            }
            for (int x = left; x < right; x++) { band.SetPixel(x, bottom - 1, Color.FromArgb(192, 192, 192)); bandChanges++; }
            doubled.Save(System.IO.Path.Combine(output, "negative-doubled.png"));
            band.Save(System.IO.Path.Combine(output, "negative-band.png"));
            Require(doubledChanges > 0 && bandChanges > 0, "negative controls did not introduce measurable defects");
        }
    }
}
