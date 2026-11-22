Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class PaneCount {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr GetPropW(IntPtr h, string s);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder sb, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  static List<RECT> found;
  static EnumProc cb = Visit;
  public static List<RECT> Panes() { found = new List<RECT>(); EnumWindows(cb, IntPtr.Zero); return found; }
  static bool Visit(IntPtr h, IntPtr l) {
    var c = new StringBuilder(64); GetClassNameW(h, c, 64);
    if (c.ToString() != "Chrome_WidgetWin_1" || GetPropW(h, "ZigShellPaneOwner") == IntPtr.Zero || !IsWindowVisible(h)) return true;
    RECT r; if (GetWindowRect(h, out r)) found.Add(r);
    return true;
  }
}
"@
$screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
$panes = [PaneCount]::Panes()
$onscreen = @($panes | Where-Object { $_.R -gt $screen.Left -and $_.L -lt $screen.Right -and $_.B -gt $screen.Top -and $_.T -lt $screen.Bottom }).Count
"panes=$($panes.Count) onscreen=$onscreen"
