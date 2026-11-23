using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class Mbv249Probe {
    [DllImport("user32.dll", SetLastError=true)] static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint message, UIntPtr wParam, IntPtr lParam, uint flags, uint timeout, out UIntPtr result);
    public static readonly List<double[]> Pings = new List<double[]>();
    public static readonly List<string[]> Bridge = new List<string[]>();
    static Thread pingThread;
    static Thread bridgeThread;
    static volatile bool running;
    static readonly Stopwatch clock = Stopwatch.StartNew();

    public static double Now() { return clock.Elapsed.TotalMilliseconds; }

    static string Exchange(int port, string request, int timeoutMs, out double ms) {
        var watch = Stopwatch.StartNew();
        string text = "";
        try {
            using (var client = new TcpClient()) {
                client.ReceiveTimeout = timeoutMs;
                client.SendTimeout = timeoutMs;
                client.Connect("127.0.0.1", port);
                var stream = client.GetStream();
                var bytes = Encoding.UTF8.GetBytes(request + "\n");
                stream.Write(bytes, 0, bytes.Length);
                var buffer = new byte[4096];
                var builder = new StringBuilder();
                while (true) {
                    int n = stream.Read(buffer, 0, buffer.Length);
                    if (n <= 0) break;
                    builder.Append(Encoding.UTF8.GetString(buffer, 0, n));
                    if (builder.ToString().IndexOf('\n') >= 0) break;
                }
                text = builder.ToString().Trim();
            }
        } catch (Exception e) {
            text = "error: " + e.GetType().Name;
        }
        ms = watch.Elapsed.TotalMilliseconds;
        return text;
    }

    public static void Start(IntPtr hwnd, int port, string session) {
        running = true;
        pingThread = new Thread(() => {
            while (running) {
                UIntPtr reply;
                double started = Now();
                IntPtr ok = SendMessageTimeout(hwnd, 0, UIntPtr.Zero, IntPtr.Zero, 0, 30000, out reply);
                double elapsed = Now() - started;
                lock (Pings) { Pings.Add(new double[] { started, elapsed, ok == IntPtr.Zero ? 1 : 0 }); }
                Thread.Sleep(50);
            }
        });
        pingThread.IsBackground = true;
        pingThread.Start();
        if (port > 0) {
            bridgeThread = new Thread(() => {
                string status = "ZSB:" + session + ":" + Convert.ToBase64String(Encoding.UTF8.GetBytes("status"));
                var hex = new StringBuilder();
                foreach (byte b in Encoding.UTF8.GetBytes(session)) hex.Append(b.ToString("x2"));
                string who = "ZSBWHO:" + hex.ToString();
                while (running) {
                    double ms;
                    double started = Now();
                    string text = Exchange(port, status, 20000, out ms);
                    lock (Bridge) { Bridge.Add(new string[] { "status", started.ToString("F1"), ms.ToString("F1"), text.Length > 160 ? text.Substring(0, 160) : text }); }
                    Thread.Sleep(1000);
                    started = Now();
                    text = Exchange(port, who, 20000, out ms);
                    lock (Bridge) { Bridge.Add(new string[] { "who", started.ToString("F1"), ms.ToString("F1"), text.Length > 160 ? text.Substring(0, 160) : text }); }
                    Thread.Sleep(1000);
                }
            });
            bridgeThread.IsBackground = true;
            bridgeThread.Start();
        }
    }

    public static void Stop() {
        running = false;
        if (pingThread != null) pingThread.Join(35000);
        if (bridgeThread != null) bridgeThread.Join(25000);
    }
}
