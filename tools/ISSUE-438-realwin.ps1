param([Parameter(Mandatory)][string]$SourceRoot, [Parameter(Mandatory)][string]$Output, [string]$Label = 'local')
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $Output | Out-Null
$Output = (Resolve-Path $Output).Path
$SourceRoot = (Resolve-Path $SourceRoot).Path
Start-Transcript "$Output/driver.log"
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class Desktop438 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public UNION data; }
    [StructLayout(LayoutKind.Explicit)] public struct UNION {
        [FieldOffset(0)] public MOUSEINPUT mouse;
        [FieldOffset(0)] public KEYBDINPUT key;
    }
    [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx, dy; public uint mouseData, flags, time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort vk, scan; public uint flags, time; public UIntPtr extra; }
    public delegate bool EnumProc(IntPtr h, IntPtr p);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc fn, IntPtr p);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int height, bool paint);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int n);
    [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint count, INPUT[] inputs, int size);
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder b, int n);
    public static IntPtr Transcript() {
        IntPtr result = IntPtr.Zero;
        EnumWindows((h,p) => { var c=FindWindowEx(h,IntPtr.Zero,"ZigShellChatTranscript",null); if(c==IntPtr.Zero) return true; result=c; return false; },IntPtr.Zero);
        return result;
    }
    static void Send(INPUT i) { if(SendInput(1,new[]{i},Marshal.SizeOf<INPUT>())!=1) throw new Exception("SendInput failed: "+Marshal.GetLastWin32Error()); }
    public static void Mouse(int x,int y,uint flags) {
        var i=new INPUT(); i.data.mouse.dx=(int)Math.Round(x*65535.0/(GetSystemMetrics(0)-1)); i.data.mouse.dy=(int)Math.Round(y*65535.0/(GetSystemMetrics(1)-1)); i.data.mouse.flags=flags|0x8001; Send(i);
    }
    public static void Key(ushort vk,bool up) { var i=new INPUT(); i.type=1; i.data.key.vk=vk; i.data.key.flags=up?2u:0u; Send(i); }
    public static string ClassAt(int x,int y) { var b=new StringBuilder(256); var p=new POINT{X=x,Y=y}; GetClassName(WindowFromPoint(p),b,256); return b.ToString(); }
}
'@
[void][Desktop438]::SetThreadDpiAwarenessContext([IntPtr](-4))
function Shot([string]$Name) {
    $w = [Desktop438]::GetSystemMetrics(0); $h = [Desktop438]::GetSystemMetrics(1)
    $bitmap = [Drawing.Bitmap]::new($w, $h)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen(0, 0, 0, 0, $bitmap.Size); $bitmap.Save("$Output/$Name.png", [Drawing.Imaging.ImageFormat]::Png) }
    finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Key([ushort]$Code) { [Desktop438]::Key($Code, $false); [Desktop438]::Key($Code, $true); Start-Sleep -Milliseconds 150 }
function Move([int]$X, [int]$Y) { [Desktop438]::Mouse($X, $Y, 0); Start-Sleep -Milliseconds 150 }
function Wait-For([string]$Description, [scriptblock]$Check) {
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 250 } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out: $Description"
}
$first = 'Opening words Anchor amber birch cedar drift elm forest garden hill island jasmine kettle lantern maple north ocean pine quiet river silver trail under violet willow yellow zenith across the valley until the winding road reaches its peaceful closing.'
$second = 'Second message reaches harbor meadow with enough additional words to show that copying a message is different from copying only the selected text.'
$app = $null
try {
    $agent = Get-Content "$SourceRoot/tools/chat-reply-agent.c" -Raw
    $fixture = 'const WCHAR message[] = L"\x25cf Reply fixture line\r\n\r\n";'
    if (!$agent.Contains($fixture)) { throw 'Shared fixture changed' }
    $agent = $agent.Replace($fixture, "const WCHAR message[] = L`"\x25cf $first\r\n\r\n\x25cf $second\r\n\r\n`";")
    $agentFile = "$Output/select-agent.c"
    Set-Content $agentFile $agent
    & zig cc -target x86_64-windows-gnu -O2 $agentFile -o "$Output/claude.exe"
    if ($LASTEXITCODE -ne 0) { throw "agent compile exit $LASTEXITCODE" }
    $env:APPDATA = "$Output/profile"
    $env:ZIGSHELL_DEBUG = '1'
    $env:MULTIPROMPT_NO_LOGIN = '1'
    $settings = "$env:APPDATA/ZigShell"
    New-Item -ItemType Directory -Force $settings | Out-Null
    @{ active_tab=0; single_window=$false; chat_active=$true; chat_view_mode='everywhere'; tabs=@(@{kind='cmd'; name='Reply test'; manual=$true; cv=$true; cwd='C:\'; pid=0}) } | ConvertTo-Json -Depth 5 | Set-Content "$settings/session.json"
    $revision = git -C $SourceRoot rev-parse HEAD
    Write-Output "SOURCE $Label $revision"
    $app = Start-Process "$SourceRoot/zig-out/bin/multiprompt.exe" -ArgumentList '--no-window-restore' -PassThru
    $transcript = Wait-For 'transcript window' { $h=[Desktop438]::Transcript(); if($h -ne [IntPtr]::Zero) { $h } }
    $parent = [Desktop438]::GetParent($transcript)
    $windowWidth = [Math]::Min(1180, [Desktop438]::GetSystemMetrics(0) - 40)
    $windowHeight = [Math]::Min(820, [Desktop438]::GetSystemMetrics(1) - 40)
    [void][Desktop438]::MoveWindow($parent, 20, 20, $windowWidth, $windowHeight, $true)
    [void][Desktop438]::SetForegroundWindow($parent)
    $shellPid = Wait-For 'restored CMD pid' { try { $p=(Get-Content "$settings/session.json" -Raw | ConvertFrom-Json).tabs[0].pid; if($p -gt 0) { $p } } catch {} }
    & "$Output/claude.exe" --start $shellPid
    if ($LASTEXITCODE -ne 0) { throw "start fixture exit $LASTEXITCODE" }
    Wait-For 'captured console fixture' { if(Test-Path "$settings/debug.log") { (Get-Content "$settings/debug.log" -Raw) -match 'PERF\[chat\]: reconcile ms=\d+ size=[1-9]' } } | Out-Null
    Start-Sleep -Seconds 3
    $rect = [Desktop438+RECT]::new()
    [void][Desktop438]::GetWindowRect($transcript, [ref]$rect)
    $dpi = [Desktop438]::GetDpiForWindow($transcript)
    Write-Output "DISPLAY dpi=$dpi size=$([Desktop438]::GetSystemMetrics(0))x$([Desktop438]::GetSystemMetrics(1)) transcript=$($rect | ConvertTo-Json -Compress)"
    Shot 'before'
    $ocr = 'C:/Program Files/Tesseract-OCR/tesseract.exe'
    if (!(Test-Path $ocr)) { $ocr=(Get-Command tesseract).Source }
    & $ocr "$Output/before.png" "$Output/words" --psm 11 tsv
    if ($LASTEXITCODE -ne 0) { throw "OCR exit $LASTEXITCODE" }
    $words = Import-Csv "$Output/words.tsv" -Delimiter "`t"
    function Word([string]$Text) {
        $found = @($words | Where-Object { $_.text -eq $Text -and [int]$_.left -ge $rect.Left -and [int]$_.top -ge $rect.Top -and [int]$_.left -lt $rect.Right -and [int]$_.top -lt $rect.Bottom })
        if ($found.Count -ne 1) { throw "Expected one visible '$Text', got $($found.Count)" }
        return $found[0]
    }
    function Point($Word) { return @(([int]$Word.left + 1), ([int]$Word.top + [int]([int]$Word.height / 2))) }
    $anchor=Word 'Anchor'; $amber=Word 'amber'; $closing=Word 'closing.'; $secondStart=Word 'Second'; $meadow=Word 'meadow'; $last=Word 'text.'
    if ([int]$closing.top -le [int]$anchor.top + [int]$anchor.height) { throw 'First message did not wrap' }
    if ([int]$secondStart.top -le [int]$closing.top + [int]$closing.height + 6) { throw 'No message gap' }
    $start=Point $anchor
    $end=@(($rect.Right - 27), (Point $last)[1])
    $targetClass=[Desktop438]::ClassAt($start[0],$start[1])
    Write-Output "INPUT_TARGET $targetClass"
    if ($targetClass -ne 'ZigShellChatTranscript') { throw 'Mouse target is not transcript' }
    Key 0x1B
    Set-Clipboard 'UNCHANGED-drag'
    Move $start[0] $start[1]
    [Desktop438]::Mouse($start[0],$start[1],2)
    $points=@(@(([int]$amber.left - 2),$start[1]),@(($rect.Right - 27),$start[1]),@(($rect.Left + 25),([int]$closing.top + [int]$closing.height + 3)),@(($rect.Left + 100),[int](([int]$closing.top + [int]$closing.height + [int]$secondStart.top)/2)),(Point $secondStart),@(([int]$meadow.left - 2),(Point $meadow)[1]),$end)
    foreach($point in $points) { Move $point[0] $point[1] }
    Shot 'during'
    [Desktop438]::Mouse($end[0],$end[1],4)
    Start-Sleep -Milliseconds 300
    Shot 'after'
    [Desktop438]::Key(0x11,$false); Key 0x43; [Desktop438]::Key(0x11,$true)
    Start-Sleep -Milliseconds 300
    $drag=Get-Clipboard -Raw
    Write-Output "DRAG_CLIPBOARD $($drag | ConvertTo-Json -Compress)"
    Key 0x1B
    Set-Clipboard 'UNCHANGED-message'
    $p=Point $secondStart
    Move $p[0] $p[1]
    [Desktop438]::Mouse($p[0],$p[1],8); [Desktop438]::Mouse($p[0],$p[1],16)
    Start-Sleep -Milliseconds 300
    Shot 'copy-menu'
    Key 0x24; Key 0x0D
    Start-Sleep -Milliseconds 300
    $message=Get-Clipboard -Raw
    Write-Output "MESSAGE_CLIPBOARD $($message | ConvertTo-Json -Compress)"
    Shot 'copied'
    $expected=$first.Substring($first.IndexOf('Anchor'))+"`r`n`r`n"+$second
    $result=@{label=$Label;revision=$revision;dpi=$dpi;drag=$drag;message=$message;expectedDrag=$expected;expectedMessage=$second;dragPass=($drag -ceq $expected);messagePass=($message -ceq $second)}
    $result | ConvertTo-Json -Depth 5 | Set-Content "$Output/result.json"
    if(!$result.dragPass -or !$result.messagePass) { throw 'Native clipboard assertions failed' }
    Write-Output 'ISSUE-438 REAL WINDOWS PASS'
} finally {
    Shot 'final'
    if($app -and !$app.HasExited) { Stop-Process -Id $app.Id -Force }
    Stop-Transcript
}
