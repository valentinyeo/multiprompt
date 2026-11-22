using System; using System.Diagnostics; using System.IO; using System.Text; using System.Threading;
static class ChangelogReceiver {
    [STAThread] static int Main(string[] args) {
        if (args.Length != 4) return 1;
        try {
            using (var ack = EventWaitHandle.OpenExisting(args[2])) {
                string temp = args[0] + ".tmp";
                File.WriteAllText(temp, args[1] + "\n" + Process.GetCurrentProcess().Id + "\n" + args[3], new UTF8Encoding(false));
                File.Move(temp, args[0]);
                return ack.WaitOne(30000) ? 0 : 2;
            }
        } catch { return 3; }
    }
}
