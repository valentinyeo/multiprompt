using System;
using System.IO;
using System.Text;
using System.Drawing;
using System.Diagnostics;
using System.Threading;
using System.Runtime.InteropServices;
public static class EverydayPerformance {
    [DllImport("user32.dll")] static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string name, string title);
    [DllImport("dwmapi.dll")] static extern int DwmFlush();
    [DllImport("user32.dll", EntryPoint="PostMessageW")] static extern bool PostMessage(IntPtr window, uint message, UIntPtr wp, IntPtr lp);
    static readonly ManualResetEvent pace = new ManualResetEvent(false);
    public static void ObserveFor(int milliseconds) { pace.WaitOne(milliseconds); }
    public static double LastAcknowledgedMs, LastCompositorMs, LastInjectionMs;
    public static long Tick() { return Stopwatch.GetTimestamp(); }
    public static long Frequency() { return Stopwatch.Frequency; }
    public static double CompositorControl() {
        long started = Tick();
        if (DwmFlush() < 0) throw new InvalidOperationException("DwmFlush failed");
        return (Tick() - started) * 1000.0 / Frequency();
    }
    public static IntPtr Transcript(IntPtr main) { return FindWindowEx(main, IntPtr.Zero, "ZigShellChatTranscript", null); }
    public static long Length(string path) { return File.Exists(path) ? new FileInfo(path).Length : 0; }
    public static string Tail(string path, long offset) {
        if (!File.Exists(path)) return "";
        using (var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete)) {
            stream.Position = Math.Min(offset, stream.Length);
            using (var reader = new StreamReader(stream)) return reader.ReadToEnd();
        }
    }
    public static long PaintCount(string path) {
        string text = Tail(path, Math.Max(0, Length(path) - 65536));
        var matches = System.Text.RegularExpressions.Regex.Matches(text, @"\[chat\] position [^\r\n]+ paints=(\d+)");
        if (matches.Count == 0) throw new InvalidOperationException("Missing prior transcript paint count");
        return long.Parse(matches[matches.Count - 1].Groups[1].Value);
    }
    public static double AwaitLog(string path, long offset, string first, string after, long started, int timeout) {
        return AwaitLog(path, offset, first, after, started, timeout, -1);
    }
    public static double AwaitLog(string path, long offset, string first, string after, long started, int timeout, long paintBefore) {
        while ((Tick() - started) * 1000.0 / Frequency() < timeout) {
            string text = Tail(path, offset);
            int at = text.IndexOf(first, StringComparison.Ordinal);
            bool painted = paintBefore < 0;
            if (at >= 0 && !painted) {
                var frames = System.Text.RegularExpressions.Regex.Matches(text.Substring(at), @"\[chat\] position [^\r\n]+ paints=(\d+)");
                foreach (System.Text.RegularExpressions.Match frame in frames)
                    if (long.Parse(frame.Groups[1].Value) > paintBefore) painted = true;
            }
            if (at >= 0 && painted && (after == "" || text.IndexOf(after, at + first.Length, StringComparison.Ordinal) >= 0)) {
                long acknowledged = Tick();
                LastAcknowledgedMs = (acknowledged - started) * 1000.0 / Frequency();
                if (DwmFlush() < 0) throw new InvalidOperationException("DwmFlush failed");
                long presented = Tick();
                LastCompositorMs = (presented - acknowledged) * 1000.0 / Frequency();
                return (presented - started) * 1000.0 / Frequency();
            }
            pace.WaitOne(2);
        }
        throw new TimeoutException("No confirmed output: " + first + " then " + after);
    }
    public static double Type(IntPtr main, uint pid, IntPtr composer, char character, string expected) {
        if (ChatDeliveryDesktop.Owner(composer) != pid || ChatDeliveryDesktop.GetForegroundWindow() != main || ChatDeliveryDesktop.Focus(main)[1] != composer.ToInt64()) throw new InvalidOperationException("Typing ownership mismatch");
        long started = Tick();
        ChatDeliveryDesktop.Character(character);
        LastInjectionMs = (Tick() - started) * 1000.0 / Frequency();
        while ((Tick() - started) * 1000.0 / Frequency() < 10000) {
            if (ChatDeliveryDesktop.Text(composer) == expected) {
                long acknowledged = Tick();
                LastAcknowledgedMs = (acknowledged - started) * 1000.0 / Frequency();
                if (DwmFlush() < 0) throw new InvalidOperationException("DwmFlush failed");
                long presented = Tick();
                LastCompositorMs = (presented - acknowledged) * 1000.0 / Frequency();
                return (presented - started) * 1000.0 / Frequency();
            }
            pace.WaitOne(2);
        }
        throw new TimeoutException("Typed character did not reach composer");
    }
    public static void CopyTranscript(IntPtr main, uint pid) {
        if (ChatDeliveryDesktop.Owner(main) != pid || ChatDeliveryDesktop.GetForegroundWindow() != main) throw new InvalidOperationException("Copy ownership mismatch");
        foreach (uint message in new uint[] { 0x8000 + 149, 0x8000 + 148 })
            if (!PostMessage(main, message, UIntPtr.Zero, IntPtr.Zero)) throw new InvalidOperationException("Copy failed");
    }
    public static void Screenshot(string path) {
        using (var bitmap = new Bitmap(ChatDeliveryDesktop.GetSystemMetrics(0), ChatDeliveryDesktop.GetSystemMetrics(1)))
        using (var graphics = Graphics.FromImage(bitmap)) {
            graphics.CopyFromScreen(0, 0, 0, 0, bitmap.Size);
            bitmap.Save(path);
        }
    }
}
