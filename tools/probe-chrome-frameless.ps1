$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type @'
using System;
using System.Text;
using System.Net;
using System.Threading.Tasks;
using System.Runtime.InteropServices;
using System.Collections.Generic;
public static class FrameProbe {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc callback, IntPtr data);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr GetWindowLongPtrW(IntPtr h, int index);
    [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr SetWindowLongPtrW(IntPtr h, int index, IntPtr value);
    [DllImport("kernel32.dll")] public static extern void SetLastError(uint error);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int width, int height, uint flags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect rect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(System.Drawing.Point point);
    [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint x, uint y, uint data, UIntPtr extra);
    [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    public static IntPtr[] Windows(uint pid) {
        var list = new List<IntPtr>();
        EnumWindows((h,l) => {
            uint owner; GetWindowThreadProcessId(h, out owner);
            var name = new StringBuilder(256); GetClassNameW(h, name, name.Capacity);
            if (owner == pid && IsWindowVisible(h) && name.ToString() == "Chrome_WidgetWin_1") list.Add(h);
            return true;
        }, IntPtr.Zero);
        return list.ToArray();
    }
    public static int Hit(IntPtr h, int x, int y) {
        IntPtr result;
        if (SendMessageTimeoutW(h, 0x84, IntPtr.Zero, new IntPtr((y << 16) | (x & 65535)), 2, 2000, out result) == IntPtr.Zero) throw new Exception("WM_NCHITTEST timed out");
        return result.ToInt32();
    }
    public static HttpListener Serve(int port) {
        var server = new HttpListener(); server.Prefixes.Add("http://127.0.0.1:" + port + "/"); server.Start();
        Task.Run(async () => {
            while (server.IsListening) {
                var context = await server.GetContextAsync();
                var page = context.Request.Url.AbsolutePath;
                string html = "<!doctype html><html><head><title>FrameProbe " + page + "</title><style>html,body{margin:0;width:100%;height:100%;background:#c7ecff;font:24px sans-serif}a{display:inline-block;margin:120px 80px;padding:30px;background:#fff;color:#123}h1{position:absolute;top:25px;left:40px;margin:0;pointer-events:none}</style></head><body><h1>Frame probe " + page + "</h1><a id='next' href='/third'>Normal in-page link</a><script>window.probeClicks=[];document.addEventListener('click',e=>window.probeClicks.push({x:e.clientX,y:e.clientY,target:e.target.tagName}));</script></body></html>";
                byte[] bytes = Encoding.UTF8.GetBytes(html); context.Response.ContentType = "text/html; charset=utf-8"; context.Response.ContentLength64 = bytes.Length;
                await context.Response.OutputStream.WriteAsync(bytes, 0, bytes.Length); context.Response.Close();
            }
        });
        return server;
    }
}
'@
[FrameProbe]::SetProcessDPIAware() | Out-Null
$out = Join-Path $PWD 'artifacts/chrome-frameless'
New-Item -ItemType Directory -Force $out | Out-Null
$profile = Join-Path $env:TEMP ('frame-probe-' + [guid]::NewGuid())
$result = [ordered]@{
    status = 'running'
    runUrl = "https://github.com/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"
    commit = $env:GITHUB_SHA
    browser = $null
    stripMask = '0x00CF0000'
    requestedFrameChangedFlags = '0x00000037'
    stages = @()
    navigation = @()
    error = $null
}
$browserProcess = $null
$server = $null
$ws = $null
$script:sequence = 0
function Free-Port {
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    $listener.Stop()
    return $port
}
function Cdp($method, $parameters = @{}) {
    $script:sequence++
    $id = $script:sequence
    $payload = @{ id = $id; method = $method; params = $parameters } | ConvertTo-Json -Depth 15 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
    $cancel = [Threading.CancellationTokenSource]::new(15000)
    try {
        $ws.SendAsync([ArraySegment[byte]]::new($bytes), [Net.WebSockets.WebSocketMessageType]::Text, $true, $cancel.Token).GetAwaiter().GetResult() | Out-Null
        do {
            $stream = [IO.MemoryStream]::new()
            do {
                $buffer = [byte[]]::new(65536)
                $received = $ws.ReceiveAsync([ArraySegment[byte]]::new($buffer), $cancel.Token).GetAwaiter().GetResult()
                if ($received.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close) { throw 'Chrome closed CDP' }
                $stream.Write($buffer, 0, $received.Count)
            } until ($received.EndOfMessage)
            $message = [Text.Encoding]::UTF8.GetString($stream.ToArray()) | ConvertFrom-Json
            $stream.Dispose()
        } until ($message.id -eq $id)
        if ($message.error) { throw ($message.error | ConvertTo-Json -Compress) }
        return $message.result
    } finally { $cancel.Dispose() }
}
function Evaluate($expression) {
    $response = Cdp 'Runtime.evaluate' @{ expression = $expression; returnByValue = $true }
    if ($response.exceptionDetails) { throw ($response.exceptionDetails | ConvertTo-Json -Compress) }
    return $response.result.value
}
function Wait-Page($path) {
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    do {
        if ((Evaluate 'location.pathname + ":" + document.readyState') -eq ($path + ':complete')) { return }
        Start-Sleep -Milliseconds 150
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Page did not settle at $path"
}
function Current-Window {
    $handles = @([FrameProbe]::Windows([uint32]$browserProcess.Id))
    if ($handles.Count -ne 1) { throw "Expected one app HWND for PID $($browserProcess.Id), found $($handles.Count)" }
    return $handles[0]
}
function Hex-Handle([IntPtr]$handle) { return ('0x{0:X}' -f $handle.ToInt64()) }
function Style([IntPtr]$handle) { return [uint32]([FrameProbe]::GetWindowLongPtrW($handle, -16).ToInt64() -band 0xffffffffL) }
function Snapshot($label) {
    $handle = Current-Window
    $rect = [FrameProbe+Rect]::new()
    if (-not [FrameProbe]::GetWindowRect($handle, [ref]$rect)) { throw 'GetWindowRect failed' }
    $style = Style $handle
    $points = [ordered]@{
        topLeftCorner = @(($rect.Left + 20), ($rect.Top + 20))
        topRightCorner = @(($rect.Right - 20), ($rect.Top + 20))
        formerCloseButton = @(($rect.Right - 25), ($rect.Top + 18))
        top = @([int](($rect.Left + $rect.Right) / 2), ($rect.Top + 1))
        left = @(($rect.Left + 1), [int](($rect.Top + $rect.Bottom) / 2))
        right = @(($rect.Right - 2), [int](($rect.Top + $rect.Bottom) / 2))
        bottom = @([int](($rect.Left + $rect.Right) / 2), ($rect.Bottom - 2))
        bottomRight = @(($rect.Right - 2), ($rect.Bottom - 2))
        caption = @(($rect.Left + 150), ($rect.Top + 18))
    }
    $hits = [ordered]@{}
    $hitNames = @{ '-2'='HTERROR'; '-1'='HTTRANSPARENT'; '0'='HTNOWHERE'; '1'='HTCLIENT'; '2'='HTCAPTION'; '3'='HTSYSMENU'; '8'='HTMINBUTTON'; '9'='HTMAXBUTTON'; '10'='HTLEFT'; '11'='HTRIGHT'; '12'='HTTOP'; '13'='HTTOPLEFT'; '14'='HTTOPRIGHT'; '15'='HTBOTTOM'; '16'='HTBOTTOMLEFT'; '17'='HTBOTTOMRIGHT'; '20'='HTCLOSE' }
    foreach ($key in $points.Keys) {
        $code = [FrameProbe]::Hit($handle, $points[$key][0], $points[$key][1])
        $hits[$key] = @{ x=$points[$key][0]; y=$points[$key][1]; code=$code; name=$hitNames["$code"] }
    }
    [FrameProbe]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 400
    $bitmap = [Drawing.Bitmap]::new($rect.Right - $rect.Left, $rect.Bottom - $rect.Top)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
        $bitmap.Save((Join-Path $out "$label-full.png"))
        $width = [Math]::Min(260, $bitmap.Width)
        $height = [Math]::Min(160, $bitmap.Height)
        foreach ($side in @('left', 'right')) {
            $x = if ($side -eq 'left') { 0 } else { $bitmap.Width - $width }
            $crop = $bitmap.Clone([Drawing.Rectangle]::new($x, 0, $width, $height), $bitmap.PixelFormat)
            try { $crop.Save((Join-Path $out "$label-top-$side.png")) } finally { $crop.Dispose() }
        }
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
    return [ordered]@{
        label=$label; hwnd=(Hex-Handle $handle); pid=$browserProcess.Id
        style=('0x{0:X8}' -f $style); strippedBits=('0x{0:X8}' -f ($style -band 0x00cf0000))
        styleFlags=@{ caption=($style -band 0xc00000) -ne 0; sysMenu=($style -band 0x80000) -ne 0; minimizeBox=($style -band 0x20000) -ne 0; maximizeBox=($style -band 0x10000) -ne 0; thickFrame=($style -band 0x40000) -ne 0 }
        bounds=@{ left=$rect.Left; top=$rect.Top; right=$rect.Right; bottom=$rect.Bottom }
        page=(Evaluate '({url:location.href,innerWidth,innerHeight,outerWidth,outerHeight,screenX,screenY,devicePixelRatio})')
        hitTests=$hits
        draggableByHitTest=(@($hits.Values | Where-Object code -eq 2).Count -gt 0)
        resizableByHitTest=(@($hits.Values | Where-Object { $_.code -ge 10 -and $_.code -le 17 }).Count -gt 0)
        screenshots=@("$label-full.png", "$label-top-left.png", "$label-top-right.png")
        visualAssessment='Inspect screenshots; style bits alone do not establish visible Chrome-drawn controls'
    }
}
function Click-Screen($x, $y) {
    [FrameProbe]::SetCursorPos($x, $y) | Out-Null
    [FrameProbe]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
    [FrameProbe]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 400
}
function Corner-Clicks($stage) {
    $records = @()
    foreach ($corner in @('topLeftCorner', 'topRightCorner')) {
        $point = $stage.hitTests[$corner]
        $before = @(Evaluate 'window.probeClicks').Count
        $root = [FrameProbe]::GetAncestor([FrameProbe]::WindowFromPoint([Drawing.Point]::new($point.x, $point.y)), 2)
        Click-Screen $point.x $point.y
        $alive = [FrameProbe]::IsWindow([IntPtr]::new([Convert]::ToInt64($stage.hwnd.Substring(2), 16)))
        $events = if ($alive) { @(Evaluate 'window.probeClicks') } else { @() }
        $records += @{ corner=$corner; x=$point.x; y=$point.y; windowUnderPoint=(Hex-Handle $root); windowSurvived=$alive; deliveredToPage=($events.Count -gt $before); events=$events }
        if (-not $alive) { throw 'Physical corner click closed Chrome' }
    }
    return $records
}
try {
    $chromePaths = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe", "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe")
    $exe = $chromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    $installFailure = $null
    if (-not $exe) {
        try {
            & choco install googlechrome --yes --no-progress 2>&1 | Out-Host
            if ($LASTEXITCODE -ne 0) { throw "Chocolatey exit code $LASTEXITCODE" }
            $exe = $chromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
            if (-not $exe) { throw 'Google Chrome executable missing after installation' }
        } catch {
            $installFailure = $_.ToString()
            Write-Host "BRANDED GOOGLE CHROME INSTALLATION FAILED: $installFailure"
            $exe = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
            if (-not $exe) { throw 'No fallback browser installed' }
        }
    }
    $version = (Get-Item $exe).VersionInfo
    $result.browser = @{ path=$exe; productName=$version.ProductName; fileVersion=$version.FileVersion; productVersion=$version.ProductVersion; brandedGoogleChrome=($version.ProductName -eq 'Google Chrome'); installationFailure=$installFailure; cdp=$null }
    Write-Host ($result.browser | ConvertTo-Json -Compress)
    $httpPort = Free-Port
    $debugPort = Free-Port
    $server = [FrameProbe]::Serve($httpPort)
    $baseUrl = "http://127.0.0.1:$httpPort"
    $browserProcess = Start-Process $exe -ArgumentList @("--app=$baseUrl/first", "--user-data-dir=$profile", "--remote-debugging-port=$debugPort", '--no-first-run', '--no-default-browser-check', '--window-position=80,80', '--window-size=850,600') -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    do {
        try { $targets = Invoke-RestMethod "http://127.0.0.1:$debugPort/json/list"; $target = $targets | Where-Object { $_.type -eq 'page' -and $_.url -like "$baseUrl/*" } | Select-Object -First 1 } catch { $target = $null }
        if ($target) { break }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    if (-not $target) { throw 'Chrome CDP page did not start' }
    $ws = [Net.WebSockets.ClientWebSocket]::new()
    $cancel = [Threading.CancellationTokenSource]::new(15000)
    try { $ws.ConnectAsync([uri]$target.webSocketDebuggerUrl, $cancel.Token).GetAwaiter().GetResult() | Out-Null } finally { $cancel.Dispose() }
    $result.browser.cdp = Cdp 'Browser.getVersion'
    Cdp 'Page.enable' | Out-Null
    Wait-Page '/first'
    $handle = Current-Window
    [FrameProbe]::SetWindowPos($handle, [IntPtr]::Zero, 80, 80, 850, 600, 0x14) | Out-Null
    Start-Sleep -Milliseconds 800
    $before = Snapshot 'before'
    $result.stages += $before
    $oldStyle = Style $handle
    $newStyle = [long]($oldStyle -band (0xffffffffL -bxor 0x00cf0000L))
    [FrameProbe]::SetLastError(0)
    $previous = [FrameProbe]::SetWindowLongPtrW($handle, -16, [IntPtr]::new($newStyle))
    $setError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    if ($previous -eq [IntPtr]::Zero -and $setError -ne 0) { throw "SetWindowLongPtrW failed: $setError" }
    $frameChanged = [FrameProbe]::SetWindowPos($handle, [IntPtr]::Zero, 0, 0, 0, 0, 0x37)
    if (-not $frameChanged) { throw "SWP_FRAMECHANGED failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())" }
    $result.stripCall = @{ previousStyle=('0x{0:X8}' -f ($previous.ToInt64() -band 0xffffffffL)); requestedStyle=('0x{0:X8}' -f $newStyle); setLastError=$setError; frameChanged=$frameChanged; immediatelyReadStyle=('0x{0:X8}' -f (Style $handle)) }
    Start-Sleep -Milliseconds 700
    $after = Snapshot 'after-strip'
    $after.cornerClicks = @(Corner-Clicks $after)
    $result.stages += $after
    Cdp 'Page.navigate' @{ url="$baseUrl/second" } | Out-Null
    Wait-Page '/second'
    Start-Sleep -Milliseconds 500
    $direct = Snapshot 'after-navigation'
    $result.stages += $direct
    $result.navigation += @{ method='CDP Page.navigate'; from='/first'; to='/second'; sameHwnd=($direct.hwnd -eq $after.hwnd); oldHwndStillExists=[FrameProbe]::IsWindow($handle); stylesStillStripped=($direct.strippedBits -eq '0x00000000'); style=$direct.style; hwnd=$direct.hwnd }
    $link = Evaluate '(()=>{const r=document.querySelector("#next").getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2}})()'
    Cdp 'Input.dispatchMouseEvent' @{ type='mouseMoved'; x=$link.x; y=$link.y } | Out-Null
    Cdp 'Input.dispatchMouseEvent' @{ type='mousePressed'; x=$link.x; y=$link.y; button='left'; clickCount=1 } | Out-Null
    Cdp 'Input.dispatchMouseEvent' @{ type='mouseReleased'; x=$link.x; y=$link.y; button='left'; clickCount=1 } | Out-Null
    Wait-Page '/third'
    Start-Sleep -Milliseconds 500
    $clicked = Snapshot 'after-link-click'
    $clicked.cornerClicks = @(Corner-Clicks $clicked)
    $result.stages += $clicked
    $result.navigation += @{ method='normal anchor click via CDP mouse input, not Page.navigate or location assignment'; from='/second'; to='/third'; sameHwnd=($clicked.hwnd -eq $direct.hwnd); oldHwndStillExists=[FrameProbe]::IsWindow($handle); stylesStillStripped=($clicked.strippedBits -eq '0x00000000'); style=$clicked.style; hwnd=$clicked.hwnd }
    $result.verdict = @{ recreatedOnNavigation=(@($result.navigation | Where-Object { -not $_.sameHwnd }).Count -gt 0); stylesRetainedOnBothNavigations=(@($result.navigation | Where-Object { -not $_.stylesStillStripped }).Count -eq 0); cornersClickableAfterStrip=(@($after.cornerClicks | Where-Object { -not $_.deliveredToPage }).Count -eq 0); resizableEdgeAfterStrip=$after.resizableByHitTest; draggableAfterStrip=$after.draggableByHitTest; visibility='See before/after corner screenshots; requires visual inspection rather than inference from GWL_STYLE' }
    $result.status = 'complete'
} catch {
    $result.status = 'error'
    $result.error = $_.ToString() + "`n" + $_.ScriptStackTrace
} finally {
    $json = $result | ConvertTo-Json -Depth 30
    [IO.File]::WriteAllText((Join-Path $out 'result.json'), $json)
    Write-Output $json
    if ($ws) { $ws.Dispose() }
    if ($server) { $server.Stop(); $server.Close() }
    if ($browserProcess -and -not $browserProcess.HasExited) { Stop-Process -Id $browserProcess.Id -Force -ErrorAction SilentlyContinue }
}
if ($result.status -ne 'complete') { throw $result.error }
