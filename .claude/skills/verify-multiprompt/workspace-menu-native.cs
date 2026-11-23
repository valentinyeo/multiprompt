using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

// Screen-only measurement helpers for the SOFT-2374 / SOFT-2580 / SOFT-2373 journeys.
// Every sample is a real CopyFromScreen capture of the presented window; nothing here
// posts application messages, forces a repaint or reads private app state.
public sealed class PaintProbe {
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] struct POINT { public int X, Y; }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr hwnd, ref POINT point);

    readonly int step;
    readonly int[] before;
    readonly int width, height;
    readonly Point origin;

    public PaintProbe(IntPtr owner, int left, int top, int right, int bottom) {
        step = 4;
        RECT frame;
        POINT point = new POINT { X = left, Y = top };
        if (!GetWindowRect(owner, out frame) || !ClientToScreen(owner, ref point)) throw new InvalidOperationException("Paint probe origin unavailable");
        if (right <= left || bottom <= top) throw new ArgumentOutOfRangeException("region");
        width = right - left;
        height = bottom - top;
        origin = new Point(point.X, point.Y);
        before = Sample(region: new Rectangle(origin.X, origin.Y, width, height));
    }

    static Bitmap Capture(Rectangle area) {
        var bitmap = new Bitmap(area.Width, area.Height, PixelFormat.Format32bppArgb);
        using (var graphics = Graphics.FromImage(bitmap)) graphics.CopyFromScreen(area.X, area.Y, 0, 0, bitmap.Size, CopyPixelOperation.SourceCopy);
        return bitmap;
    }

    static int[] ReadPixels(Bitmap bitmap) {
        BitmapData data = bitmap.LockBits(new Rectangle(0, 0, bitmap.Width, bitmap.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try {
            int[] pixels = new int[bitmap.Width * bitmap.Height];
            for (int row = 0; row < bitmap.Height; row++) {
                Marshal.Copy(data.Scan0 + row * data.Stride, pixels, row * bitmap.Width, bitmap.Width);
            }
            return pixels;
        } finally { bitmap.UnlockBits(data); }
    }

    int[] Sample(Rectangle region) {
        using (var bitmap = Capture(region)) {
            int[] raw = ReadPixels(bitmap);
            int columns = (width + step - 1) / step;
            int rows = (height + step - 1) / step;
            int[] sampled = new int[columns * rows];
            for (int y = 0; y < rows; y++) {
                for (int x = 0; x < columns; x++) {
                    sampled[y * columns + x] = raw[Math.Min(height - 1, y * step) * width + Math.Min(width - 1, x * step)];
                }
            }
            return sampled;
        }
    }

    int Changed(int[] current) {
        int changed = 0;
        for (int i = 0; i < before.Length; i++) if (before[i] != current[i]) changed++;
        return changed;
    }

    public Dictionary<string, object> WaitForChange(Stopwatch timer, int timeoutMs, int threshold) {
        var region = new Rectangle(origin.X, origin.Y, width, height);
        int last = 0;
        int samples = 0;
        while (timer.ElapsedMilliseconds < timeoutMs) {
            int[] current = Sample(region);
            samples++;
            last = Changed(current);
            if (last >= threshold) {
                return new Dictionary<string, object> {
                    { "paintMs", Math.Round(timer.Elapsed.TotalMilliseconds, 1) }, { "changedSamples", last },
                    { "samplesTaken", samples }, { "threshold", threshold }, { "sampleStep", step },
                    { "regionClient", new int[] { 0, 0, width, height } }
                };
            }
            Thread.Sleep(2);
        }
        return new Dictionary<string, object> {
            { "paintMs", (double)timeoutMs }, { "changedSamples", last }, { "samplesTaken", samples },
            { "threshold", threshold }, { "sampleStep", step }, { "timedOut", true }
        };
    }
}

public static class SessionPaintProof {
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] struct POINT { public int X, Y; }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr hwnd, ref POINT point);

    static Bitmap Capture(Rectangle area) {
        var bitmap = new Bitmap(area.Width, area.Height, PixelFormat.Format32bppArgb);
        using (var graphics = Graphics.FromImage(bitmap)) graphics.CopyFromScreen(area.X, area.Y, 0, 0, bitmap.Size, CopyPixelOperation.SourceCopy);
        return bitmap;
    }

    static int[] ReadPixels(Bitmap bitmap) {
        BitmapData data = bitmap.LockBits(new Rectangle(0, 0, bitmap.Width, bitmap.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try {
            int[] pixels = new int[bitmap.Width * bitmap.Height];
            for (int row = 0; row < bitmap.Height; row++) {
                Marshal.Copy(data.Scan0 + row * data.Stride, pixels, row * bitmap.Width, bitmap.Width);
            }
            return pixels;
        } finally { bitmap.UnlockBits(data); }
    }

    static Point ScreenOrigin(IntPtr owner, int left, int top) {
        POINT point = new POINT { X = left, Y = top };
        if (!ClientToScreen(owner, ref point)) throw new InvalidOperationException("Client origin unavailable");
        return new Point(point.X, point.Y);
    }

    sealed class Region {
        public int Left, Top, Right, Bottom, Step, Threshold;
        public bool CountDistinct;
        public Rectangle Screen;
        public int[] Last;
        public int ChangedFrames, BlankFrames, DistinctMin;
        public double LuminanceMin = 999, LuminanceMax = -1;
    }

    static Region NewRegion(IntPtr owner, int[] bounds, int step, int threshold, bool countDistinct) {
        var region = new Region { Left = bounds[0], Top = bounds[1], Right = bounds[2], Bottom = bounds[3], Step = step, Threshold = threshold, CountDistinct = countDistinct, DistinctMin = int.MaxValue };
        Point origin = ScreenOrigin(owner, region.Left, region.Top);
        region.Screen = new Rectangle(origin.X, origin.Y, region.Right - region.Left, region.Bottom - region.Top);
        return region;
    }

    static void Step(Region region) {
        using (var bitmap = Capture(region.Screen)) {
            int[] raw = ReadPixels(bitmap);
            int[] sampled = raw;
            if (region.Step > 1) {
                int columns = (bitmap.Width + region.Step - 1) / region.Step;
                int rows = (bitmap.Height + region.Step - 1) / region.Step;
                sampled = new int[columns * rows];
                for (int y = 0; y < rows; y++) {
                    for (int x = 0; x < columns; x++) {
                        sampled[y * columns + x] = raw[Math.Min(bitmap.Height - 1, y * region.Step) * bitmap.Width + Math.Min(bitmap.Width - 1, x * region.Step)];
                    }
                }
            }
            if (region.CountDistinct) {
                var distinct = new HashSet<int>();
                double total = 0;
                foreach (int pixel in sampled) {
                    distinct.Add(pixel);
                    total += 0.114 * (pixel & 0xff) + 0.587 * ((pixel >> 8) & 0xff) + 0.299 * ((pixel >> 16) & 0xff);
                }
                region.DistinctMin = Math.Min(region.DistinctMin, distinct.Count);
                double mean = total / sampled.Length;
                region.LuminanceMin = Math.Min(region.LuminanceMin, mean);
                region.LuminanceMax = Math.Max(region.LuminanceMax, mean);
                if (distinct.Count <= 3) region.BlankFrames++;
            }
            if (region.Last != null) {
                int changed = 0;
                for (int i = 0; i < sampled.Length; i++) if (region.Last[i] != sampled[i]) changed++;
                if (changed >= region.Threshold) region.ChangedFrames++;
            }
            region.Last = sampled;
        }
    }

    // Counts presented-frame changes in two client regions at a fixed frame rate and
    // writes one crop of the first region every `stripEverySeconds` seconds.
    public static Dictionary<string, object> SampleChurn(IntPtr owner, int[] sidebar, int[] chat, int fps, int seconds, string directory) {
        if (fps < 1 || seconds < 1) throw new ArgumentOutOfRangeException("fps");
        // The sidebar is sampled at 4 px and needs 8 changed samples: only a repaint that
        // visibly moves the sidebar counts, and its distinct-colour count detects a blank
        // frame. The chat pane is compared pixel for pixel with a 25 pixel threshold so a
        // single appended text character still counts as output reaching the screen.
        var side = NewRegion(owner, sidebar, 4, 8, true);
        var pane = NewRegion(owner, chat, 1, 25, false);
        var frames = new List<Dictionary<string, object>>();
        var timer = Stopwatch.StartNew();
        Directory.CreateDirectory(directory);
        while (timer.ElapsedMilliseconds < seconds * 1000) {
            long started = timer.ElapsedMilliseconds;
            Step(side);
            Step(pane);
            frames.Add(new Dictionary<string, object> {
                { "ms", started }, { "sidebarChanged", side.ChangedFrames }, { "chatChanged", pane.ChangedFrames },
                { "sidebarDistinct", side.DistinctMin }, { "paneDistinct", pane.DistinctMin }
            });
            long due = started + (1000L / fps);
            long wait = due - timer.ElapsedMilliseconds;
            if (wait > 0) Thread.Sleep((int)wait);
        }
        timer.Stop();
        return new Dictionary<string, object> {
            { "requestedFps", fps }, { "requestedSeconds", seconds }, { "capturedFrames", frames.Count },
            { "elapsedMs", Math.Round(timer.Elapsed.TotalMilliseconds, 1) },
            { "sidebarChangedFrames", side.ChangedFrames },
            { "chatChangedFrames", pane.ChangedFrames },
            { "sidebarBlankFrames", side.BlankFrames },
            { "chatBlankFrames", pane.BlankFrames },
            { "sidebarDistinctColorsMin", side.DistinctMin },
            { "paneDistinctColorsMin", pane.DistinctMin },
            { "sidebarLuminanceMin", Math.Round(side.LuminanceMin, 2) },
            { "sidebarLuminanceMax", Math.Round(side.LuminanceMax, 2) },
            { "sidebarRegionClient", sidebar }, { "chatRegionClient", chat },
            { "sidebarThreshold", "8 changed samples of a 4 px grid" }, { "chatThreshold", "25 changed pixels at full resolution" },
            { "frames", frames.ToArray() },
            { "capture", "screen CopyFromScreen of the presented window; 4px sampling for the sidebar, 8px for the chat pane; no forced repaint" }
        };
    }

    // Saves full-resolution crops of the sidebar at evenly spaced presented frames.
    public static List<string> SaveStrip(IntPtr owner, int[] sidebar, int count, string directory, string prefix) {
        var saved = new List<string>();
        Directory.CreateDirectory(directory);
        Point origin = ScreenOrigin(owner, sidebar[0], sidebar[1]);
        var area = new Rectangle(origin.X, origin.Y, sidebar[2] - sidebar[0], sidebar[3] - sidebar[1]);
        for (int i = 0; i < count; i++) {
            string path = Path.Combine(directory, prefix + "-" + i + ".png");
            using (var bitmap = Capture(area)) bitmap.Save(path, ImageFormat.Png);
            saved.Add(path);
            Thread.Sleep(250);
        }
        return saved;
    }
}
