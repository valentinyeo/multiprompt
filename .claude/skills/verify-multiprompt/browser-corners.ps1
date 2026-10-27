Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class BrowserCornerProof {
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr hwnd, uint command);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr CreateWindowExW(uint ex, string cls, string title, uint style, int x, int y, int w, int h, IntPtr owner, IntPtr menu, IntPtr instance, IntPtr param);
    [DllImport("user32.dll")] public static extern bool DestroyWindow(IntPtr hwnd);
    public static IntPtr BackgroundControl(int x, int y) {
        IntPtr hwnd = CreateWindowExW(0x80, "STATIC", "Other app", 0x90000000, x, y, 80, 40, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);
        if (hwnd == IntPtr.Zero) throw new InvalidOperationException("External focus control creation failed");
        return hwnd;
    }
    static int Z(IntPtr hwnd) {
        int index = 0;
        for (IntPtr current = GetWindow(hwnd, 0); current != IntPtr.Zero; current = GetWindow(current, 2)) {
            if (current == hwnd) return index;
            if (++index > 10000) break;
        }
        throw new InvalidOperationException("Window missing from desktop stacking order");
    }
    public static Dictionary<string, object> Check(string path, string prefix, int[] frame, IntPtr browser,
        Dictionary<string, object>[] masks, int radius, int insetX, int insetTop, int insetBottom) {
        var proof = new Dictionary<string, object>();
        var results = new List<Dictionary<string, object>>();
        Rect pane;
        if (!GetWindowRect(browser, out pane)) throw new InvalidOperationException("Missing browser rectangle");
        bool passed = masks.Length == 10;
        using (var image = new Bitmap(path)) {
            for (int corner = 0; corner < 4; corner++) {
                bool right = (corner & 1) != 0, bottom = corner >= 2;
                int insetY = bottom ? insetBottom : insetTop;
                int width = radius + insetX, height = radius + insetY;
                int left = right ? pane.Right - width : pane.Left;
                int top = bottom ? pane.Bottom - height : pane.Top;
                long handle = 0;
                foreach (var mask in masks) {
                    var rect = (int[])mask["rect"];
                    if (rect[0] == left && rect[1] == top && rect[2] == left + width && rect[3] == top + height) {
                        if (handle != 0) throw new InvalidOperationException("Ambiguous corner mask");
                        handle = (long)mask["handle"];
                    }
                }
                if (handle == 0) throw new InvalidOperationException("Corner mask missing: " + corner);
                int z = Z(new IntPtr(handle));
                bool above = z < Z(browser);
                foreach (var mask in masks) {
                    var rect = (int[])mask["rect"];
                    if ((long)mask["handle"] == handle || rect[0] >= left + width || rect[2] <= left || rect[1] >= top + height || rect[3] <= top) continue;
                    above &= z < Z(new IntPtr((long)mask["handle"]));
                }
                int dx = insetX + Math.Max(2, radius / 10), dy = insetY + Math.Max(2, radius / 10);
                int x = right ? pane.Right - 1 - dx : pane.Left + dx;
                int y = bottom ? pane.Bottom - 1 - dy : pane.Top + dy;
                Color outside = image.GetPixel(x - frame[0], y - frame[1]);
                int innerX = right ? pane.Right - 1 - insetX - radius : pane.Left + insetX + radius;
                int innerY = bottom ? pane.Bottom - 1 - insetY - radius : pane.Top + insetY + radius;
                Color inside = image.GetPixel(innerX - frame[0], innerY - frame[1]);
                bool rounded = outside.R <= 24 && outside.G <= 24 && outside.B <= 24;
                bool contrast = !bottom || (inside.R >= 200 && inside.G >= 200 && inside.B >= 200);
                using (var crop = image.Clone(new Rectangle(left - frame[0], top - frame[1], width, height), PixelFormat.Format32bppArgb))
                    crop.Save(prefix + "-corner-" + corner + ".png", ImageFormat.Png);
                results.Add(new Dictionary<string, object> {
                    { "corner", corner }, { "handle", handle }, { "rect", new int[] { left, top, left + width, top + height } },
                    { "aboveBrowserAndStrips", above }, { "outsideRGB", new int[] { outside.R, outside.G, outside.B } },
                    { "insideRGB", new int[] { inside.R, inside.G, inside.B } }, { "rounded", rounded }, { "whitePageControl", contrast }
                });
                passed &= above && rounded && contrast;
            }
        }
        proof["corners"] = results;
        proof["passed"] = passed;
        return proof;
    }
}
'@

Select-Theme 'amoled' 'corners-amoled'
$script:browserShellId = (Read-Inbox).shells[0].sid
$pane = Open-BrowserPane 'corners-open'
$browser = [VerifyNative]::PaneWindow($script:window)
if ($browser -eq [IntPtr]::Zero) { throw 'No owned browser pane for corner journey' }
Focus-LockedBrowser $browser
Press @(0x11, 0x4C) 'Ctrl+L: open synthetic white corner control page'
$browserRoot = [System.Windows.Automation.AutomationElement]::FromHandle($browser)
$omniboxCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'OmniboxViewViews')
Wait-Until {
    $omnibox = $browserRoot.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $omniboxCondition)
    $null -ne $omnibox -and $omnibox.Current.HasKeyboardFocus -and
        [System.Windows.Automation.Automation]::Compare($omnibox, [System.Windows.Automation.AutomationElement]::FocusedElement) -and
        [VerifyNative]::GetForegroundWindow() -eq $browser
} 'owned browser address bar has keyboard focus'
$html = '<title>Corner control</title><body style="margin:0;background:white;height:100vh"></body>'
Type-Text ('data:text/html,' + [Uri]::EscapeDataString($html))
Press @(0x0D) 'Enter: render white corner control page'
Wait-Until { [VerifyNative]::Title($browser) -match 'Corner control' } 'synthetic white page loaded' 20
Focus-Palette 'new cmd' 2000
Press @(0x0D) 'Enter: create second session for real chat switches'
Wait-Until { @((Read-Session).tabs).Count -eq 2 } 'two real sessions for switching'
Press @(0x11, 0x09) 'Ctrl+Tab: return to browser-owning session'
Wait-Until { [VerifyNative]::PaneWindow($script:window) -eq $browser } 'original browser visible'
Snapshot 'action'
$proofs = @()
$other = [IntPtr]::Zero
try {
for ($cycle = 0; $cycle -lt 20; $cycle++) {
    switch ($cycle % 5) {
        0 {
            Focus-LockedBrowser $browser
            Record "Corner cycle $cycle`: click browser content"
            [VerifyNative]::ClickBrowserContent($browser, $script:window)
        }
        1 {
            Activate-OwnedFrame
            Press @(0x11, 0x09) 'Ctrl+Tab: switch away from browser session'
            Wait-Until { (Read-Session).active_tab -eq 1 } 'second session selected'
            Press @(0x11, 0x09) 'Ctrl+Tab: switch back to browser session'
        }
        2 {
            Doctor
            Record "Corner cycle $cycle`: minimize and restore owned main window"
            [void][VerifyNative]::ShowWindow($script:window, 6)
            Start-Sleep -Milliseconds 250
            [void][VerifyNative]::ShowWindow($script:window, 9)
            [VerifyNative]::BringToForeground($script:window)
        }
        3 {
            Doctor
            Record "Corner cycle $cycle`: resize owned main window"
            [void][VerifyNative]::ShowWindow($script:window, 9)
            $monitor = [VerifyNative]::MonitorFromWindow($script:window, 2)
            $info = New-Object VerifyNative+MonitorInfo
            $info.Size = [Runtime.InteropServices.Marshal]::SizeOf($info)
            if (-not [VerifyNative]::GetMonitorInfoW($monitor, [ref]$info)) { throw 'Resize work area unavailable' }
            $width = [Math]::Min(960, $info.Work.Right - $info.Work.Left - 40) - 20 * ($cycle % 3)
            $height = [Math]::Min(650, $info.Work.Bottom - $info.Work.Top - 40)
            if (-not [VerifyNative]::MoveWindow($script:window, ($info.Work.Left + 20), ($info.Work.Top + 20), $width, $height, $true)) { throw 'Owned resize failed' }
        }
    }
    if ($cycle % 5 -eq 4) {
        $frame = New-Object VerifyNative+Rect
        if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame)) { throw 'Main rectangle unavailable' }
        if ($other -eq [IntPtr]::Zero) { $other = [BrowserCornerProof]::BackgroundControl(($frame.Left + 10), ($frame.Top + 60)) }
        [VerifyNative]::BringToForeground($other)
        Wait-Until { [VerifyNative]::GetForegroundWindow() -eq $other } 'unrelated native window owns foreground'
        Start-Sleep -Milliseconds 800
    }
    try {
        Wait-Until { [VerifyNative]::PaneWindow($script:window) -eq $browser -and [PaneLayoutProof]::Masks([uint32]$process.Id).Count -eq 10 } 'ten visible browser masks after activation' 10
    } catch {
        Snapshot ('corners-cycle-' + $cycle + '-failed')
        throw
    }
    Start-Sleep -Milliseconds 600
    $name = 'corners-cycle-' + $cycle
    Snapshot $name
    $frame = New-Object VerifyNative+Rect
    if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame)) { throw 'Main rectangle unavailable' }
    $visibleMonitor = [VerifyNative]::MonitorFromWindow($script:window, 2)
    $visibleInfo = New-Object VerifyNative+MonitorInfo
    $visibleInfo.Size = [Runtime.InteropServices.Marshal]::SizeOf($visibleInfo)
    if (-not [VerifyNative]::GetMonitorInfoW($visibleMonitor, [ref]$visibleInfo) -or
        $frame.Left -lt $visibleInfo.Work.Left -or $frame.Top -lt $visibleInfo.Work.Top -or
        $frame.Right -gt $visibleInfo.Work.Right -or $frame.Bottom -gt $visibleInfo.Work.Bottom) { throw 'All four corners must be inside the visible work area' }
    $state = Read-Session
    $scale = 100
    if ($state.PSObject.Properties['ui_scale']) { $scale = [int]$state.ui_scale }
    $dpi = [VerifyNative]::GetDpiForWindow($script:window)
    $unit = [double]$dpi * $scale / 9600
    $masks = [PaneLayoutProof]::Masks([uint32]$process.Id)
    $proof = [BrowserCornerProof]::Check((Join-Path $Evidence ($name + '.png')), (Join-Path $Evidence $name), @($frame.Left, $frame.Top), $browser, $masks.ToArray(), [int][Math]::Truncate(20 * $unit), [int][Math]::Truncate(8 * $unit), [int][Math]::Truncate(3 * $unit), [int][Math]::Truncate(8 * $unit))
    $proofs += @{ cycle = $cycle; action = $cycle % 5; foreground = [VerifyNative]::GetForegroundWindow().ToInt64(); pixels = $proof; masks = $masks; dpi = $dpi; scale = $scale }
    Save-Json $proofs 'browser-corners.json'
    if (-not $proof['passed']) { throw "browser-corners cycle $cycle FAIL: lost rounded corner or stacking order" }
    $result.checks += @{ name = "browser-corners cycle $cycle"; passed = $true }
    Write-Host "browser-corners cycle $cycle PASS"
}
} finally {
    if ($other -ne [IntPtr]::Zero) { [void][BrowserCornerProof]::DestroyWindow($other) }
}
Activate-OwnedFrame
Snapshot 'after'
Write-Host 'BROWSER_CORNERS_20_OK'
