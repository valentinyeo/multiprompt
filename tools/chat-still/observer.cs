using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;

public sealed class ChatStillObserver {
    [StructLayout(LayoutKind.Sequential)] struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left, Top, Right, Bottom; }
    delegate bool EnumProc(IntPtr window, IntPtr state);
    [DllImport("dwmapi.dll")] static extern int DwmFlush();
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr owner, EnumProc callback, IntPtr state);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr window, StringBuilder name, int count);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr window, ref Point point);
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr window, out Rect rect);
    readonly List<Dictionary<string, object>> samples = new List<Dictionary<string, object>>();
    readonly Dictionary<string, int[]> rows = new Dictionary<string, int[]>();
    readonly Stopwatch clock = new Stopwatch();
    Thread thread;
    string error, key, latest;
    int[] baseline;
    double first = -1, streaming = -1;
    long streamStartedUtc;
    long position;
    string carry = "";
    bool target, building;
    int dirty, width, layout, paints, height;
    readonly HashSet<int> heights = new HashSet<int>();
    volatile bool stop;
    public static int[] ParseRect(string value) { return Array.ConvertAll(value.Split(','), Int32.Parse); }
    public static bool Same(int[] a, int[] b) {
        if (a == null || b == null || a.Length != 4 || b.Length != 4) return false;
        for (int i = 0; i < 4; i++) if (a[i] != b[i]) return false;
        return true;
    }
    public static void AssertFrame(int[] baseline, int[] current, int dirty, int width, int layout) {
        if (dirty != 0 || width != layout) throw new InvalidOperationException("Half-laid-out transcript painted");
        if (!Same(baseline, current)) throw new InvalidOperationException("Newest visible message moved after its first frame");
    }
    IntPtr Transcript(int pid, IntPtr owner) {
        uint actual;
        GetWindowThreadProcessId(owner, out actual);
        if (actual != pid) throw new InvalidOperationException("Observer owner PID mismatch");
        IntPtr found = IntPtr.Zero;
        int count = 0;
        EnumChildWindows(owner, delegate(IntPtr child, IntPtr state) {
            var name = new StringBuilder(128);
            GetWindowThreadProcessId(child, out actual);
            GetClassName(child, name, name.Capacity);
            if (actual == pid && IsWindowVisible(child) && name.ToString() == "ZigShellChatTranscript") { found = child; count++; }
            return true;
        }, IntPtr.Zero);
        if (count != 1) throw new InvalidOperationException("Expected one visible owned transcript");
        return found;
    }
    void Sample(IntPtr view, string kind) {
        if (!target || building || latest == null) return;
        if (first < 0) { key = latest; first = clock.Elapsed.TotalMilliseconds; }
        int[] rect;
        if (!rows.TryGetValue(key, out rect)) throw new InvalidOperationException("Newest initially visible message disappeared: " + key);
        var origin = new Point();
        if (!ClientToScreen(view, ref origin)) throw new InvalidOperationException("Transcript screen origin unavailable");
        var screen = new int[] { rect[0] + origin.X, rect[1] + origin.Y, rect[2] + origin.X, rect[3] + origin.Y };
        samples.Add(new Dictionary<string, object> { { "ms", clock.Elapsed.TotalMilliseconds }, { "utc_ms", DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() }, { "height", height }, { "kind", kind }, { "phase", streaming < 0 ? "idle" : "streaming" }, { "message", key }, { "rect", screen }, { "dirty", dirty }, { "width", width }, { "layout", layout } });
        if (baseline == null) baseline = screen;
        AssertFrame(baseline, screen, dirty, width, layout);
        Rect client;
        if (!GetClientRect(view, out client)) throw new InvalidOperationException("Transcript client rectangle unavailable");
        AssertFrame(baseline, screen, dirty, client.Right - client.Left, layout);
        if (rect[3] <= 0 || rect[1] >= client.Bottom) throw new InvalidOperationException("Newest initially visible message is no longer on screen");
    }
    void Read(string log, string shell, IntPtr view) {
        using (var stream = new FileStream(log, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete)) {
            if (stream.Length < position) throw new InvalidOperationException("Paint log truncated during observation");
            stream.Position = position;
            using (var reader = new StreamReader(stream)) {
                carry += reader.ReadToEnd();
                position = stream.Position;
            }
        }
        int end;
        while ((end = carry.IndexOf('\n')) >= 0) {
            string line = carry.Substring(0, end);
            carry = carry.Substring(end + 1);
            var header = Regex.Match(line, @"\[chat-still\] begin shell=(\d+) dirty=(\d+) width=(\d+) layout=(\d+) height=(\d+)");
            if (header.Success) {
                if (building) throw new InvalidOperationException("Native paint geometry was incomplete before the next paint");
                target = header.Groups[1].Value == shell;
                building = true;
                rows.Clear(); latest = null;
                dirty = Int32.Parse(header.Groups[2].Value); width = Int32.Parse(header.Groups[3].Value); layout = Int32.Parse(header.Groups[4].Value); height = Int32.Parse(header.Groups[5].Value);
            }
            var row = Regex.Match(line, @"\[chat-still\] row message=(\d+) offset=(\d+) rect=(-?\d+,-?\d+,-?\d+,-?\d+)");
            if (!building && first >= 0 && row.Success) throw new InvalidOperationException("Native message geometry arrived outside a complete paint");
            if (building && target && row.Success) {
                latest = row.Groups[1].Value == "0" ? "offset/" + row.Groups[2].Value : "message/" + row.Groups[1].Value;
                rows[latest] = ParseRect(row.Groups[3].Value);
            }
            if (line.Contains("[chat-still] end")) {
                building = false;
                if (target) {
                    if (streaming >= 0) { paints++; heights.Add(height); }
                    if (first >= 0 && latest == null) throw new InvalidOperationException("Transcript flickered blank after being shown");
                    Sample(view, "paint");
                }
            }
        }
    }
    public void Start(int pid, IntPtr owner, string log, long offset, string shell, string state) {
        if (thread != null) throw new InvalidOperationException("Observer already started");
        thread = new Thread(delegate() {
            try {
                IntPtr view = Transcript(pid, owner);
                position = offset;
                clock.Start();
                while (!stop && clock.Elapsed.TotalMilliseconds < 30000 && (streaming < 0 || clock.Elapsed.TotalMilliseconds - streaming < 4200 || building)) {
                    if (DwmFlush() != 0) throw new InvalidOperationException("DWM frame sampling unavailable");
                    Read(log, shell, view);
                    Sample(view, "display-frame");
                    if (first >= 0 && streaming < 0 && clock.Elapsed.TotalMilliseconds - first >= 2100 && File.Exists(Path.Combine(state, "still-subscribed"))) {
                        streaming = clock.Elapsed.TotalMilliseconds;
                        streamStartedUtc = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
                        File.WriteAllText(Path.Combine(state, "still-stream-start"), "start");
                    }
                }
                if (first < 0) throw new InvalidOperationException("No first content frame was observed");
                if (streaming < 0) throw new InvalidOperationException("No production live subscription was observed");
                if (clock.Elapsed.TotalMilliseconds - streaming < 4000) throw new InvalidOperationException("Streaming observation was incomplete");
                foreach (string phase in new string[] { "idle", "streaming" }) {
                    if (samples.FindAll(s => (string)s["kind"] == "display-frame" && (string)s["phase"] == phase).Count < 30)
                        throw new InvalidOperationException("Too few display frames sampled during " + phase);
                }
                if (building) throw new InvalidOperationException("Incomplete paint geometry at observation end");
            } catch (Exception failure) { error = failure.Message; }
        });
        thread.IsBackground = true;
        thread.Start();
    }
    public Dictionary<string, object> Finish() {
        if (thread == null || !thread.Join(35000)) { stop = true; throw new InvalidOperationException("Observer did not finish"); }
        return new Dictionary<string, object> { { "status", error == null ? "passed" : "failed" }, { "error", error }, { "message", key }, { "baseline", baseline }, { "samples", samples }, { "streaming_paints", paints }, { "distinct_streaming_heights", heights.Count }, { "elapsed_ms", clock.Elapsed.TotalMilliseconds }, { "idle_ms", first < 0 || streaming < 0 ? 0 : streaming - first }, { "streaming_ms", streaming < 0 ? 0 : clock.Elapsed.TotalMilliseconds - streaming }, { "stream_started_utc_ms", streamStartedUtc } };
    }
}
