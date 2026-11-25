param([Parameter(Mandatory=$true)][string]$Exe, [Parameter(Mandatory=$true)][string]$Notes, [Parameter(Mandatory=$true)][string]$Offer, [Parameter(Mandatory=$true)][string]$Evidence, [switch]$Before)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:OS -ne 'Windows_NT') { throw 'Real release card proof runs only on GitHub Windows' }
New-Item -ItemType Directory -Force $Evidence | Out-Null
$document = Get-Content $Notes -Raw | ConvertFrom-Json
if ($document.version -cne $Offer) { throw 'Downloaded production notes do not name the offered version' }
$release = @($document.releases | Where-Object { $_.version -ceq $Offer })
if ($release.Count -ne 1) { throw 'Offered release is missing from the downloaded notes' }
$changes = @($release[0].changes)
if ($changes.Count -ne 1) { throw 'The reviewed production release must carry exactly one change' }
$marker = [regex]::Match($changes[0], '^((?:IGSH|MUBO)-\d+) (\S.*)$')
if (-not $marker.Success) { throw 'Published change has no ticket key and plain text' }
$id = $marker.Groups[1].Value
$painted = $marker.Groups[2].Value
$installed = '0.28.1984'
$seeAll = "https://github.com/valentinyeo/multiprompt/releases/tag/v$Offer"
$cardExe = Join-Path $Evidence 'card.exe'
Copy-Item -LiteralPath $Exe -Destination $cardExe
$hash = (Get-FileHash $cardExe -Algorithm SHA256).Hash.ToLowerInvariant()
$binaryVersion = [regex]::Match([Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($cardExe)), 'MPVERSION=(\d+\.\d+\.\d+);')
if (-not $binaryVersion.Success -or $binaryVersion.Groups[1].Value -cne $installed) { throw 'Card binary does not carry the installed earlier version' }
New-Item -ItemType Directory -Force "$cardExe.update" | Out-Null
Copy-Item -LiteralPath $Notes -Destination "$cardExe.update/release-notes.json" -Force
if ((Get-FileHash $Notes -Algorithm SHA256).Hash -ne (Get-FileHash "$cardExe.update/release-notes.json" -Algorithm SHA256).Hash) { throw 'Staged notes differ from the downloaded production asset' }
[IO.File]::WriteAllText("$cardExe.update/ready.txt", "MPVERSION=$Offer;multiprompt-x64.exe")
$env:APPDATA = Join-Path $Evidence 'roaming'
$env:LOCALAPPDATA = Join-Path $Evidence 'local'
$env:USERPROFILE = Join-Path $Evidence 'profile'
$env:HOME = $env:USERPROFILE
$env:MULTIPROMPT_NO_LOGIN = '1'
$env:ZIGSHELL_DEBUG = '1'
$env:IGSH_246 = '1'
New-Item -ItemType Directory -Force "$env:APPDATA/ZigShell", $env:LOCALAPPDATA, $env:USERPROFILE | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class RealCardProof {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int L,T,R,B; }
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int X,Y; }
    [StructLayout(LayoutKind.Sequential)] public struct Mouse { public int x, y; public uint data, flags, time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Explicit)] public struct InputUnion { [FieldOffset(0)] public Mouse mouse; }
    [StructLayout(LayoutKind.Sequential)] public struct Input { public uint type; public InputUnion data; }
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(Point p);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref Point p);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out Rect r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint count, Input[] inputs, int size);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr wp, IntPtr lp);
    public static void Click() {
        foreach (uint flags in new uint[] { 2, 4 }) {
            Input input = new Input();
            input.data.mouse.flags = flags;
            if (SendInput(1, new Input[] { input }, Marshal.SizeOf(typeof(Input))) != 1) throw new InvalidOperationException("Mouse SendInput failed");
            System.Threading.Thread.Sleep(35);
        }
    }
}
'@
$eventName = 'Local\MultipromptRealCard-' + [guid]::NewGuid().ToString('N')
$event = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::ManualReset, $eventName)
$mutexName = 'Local\MultipromptUpdate-' + ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::Unicode.GetBytes($cardExe.ToLowerInvariant())))).Replace('-', '')
$mutex = New-Object Threading.Mutex($false, $mutexName)
$null = $mutex.WaitOne()
$process = $null
$log = Join-Path $env:APPDATA 'ZigShell/debug.log'
function Read-CardLog {
    if (-not (Test-Path $log)) { return '' }
    return (Get-Content $log -Raw -ErrorAction SilentlyContinue)
}
function Wait-CardLog([scriptblock]$Condition, [string]$Failure, [int]$Seconds) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    do {
        $script:cardText = Read-CardLog
        if (& $Condition) { return }
        if ($process.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw $Failure }
        Start-Sleep -Milliseconds 100
    } while ($true)
}
function Save-Window([IntPtr]$Window, [string]$Name) {
    $rectangle = New-Object RealCardProof+Rect
    if (-not [RealCardProof]::GetWindowRect($Window, [ref]$rectangle)) { throw "$Name window rectangle unavailable" }
    $bitmap = New-Object Drawing.Bitmap([Math]::Max(1, $rectangle.R - $rectangle.L), [Math]::Max(1, $rectangle.B - $rectangle.T))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $dc = $graphics.GetHdc()
    try { if (-not [RealCardProof]::PrintWindow($Window, $dc, 2)) { throw "$Name screenshot failed" } } finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
    $file = Join-Path $Evidence ($Name + '.png')
    try { $bitmap.Save($file) } finally { $bitmap.Dispose() }
    return $file
}
try {
    $process = Start-Process $cardExe -ArgumentList "--update-ready $eventName" -PassThru
    if (-not $event.WaitOne(20000)) { throw 'Real card app did not report readiness' }
    if ($Before) {
        Wait-CardLog { $script:cardText -match '\[update\] card view=collapsed n=0 ' -and $script:cardText -match '\[update\] card remaining=' } 'Released card did not paint its version row' 30
        if ($cardText -match '\[update\] card note ') { throw 'Released card already names a change' }
        if ($cardText -match '\[update\] more row=') { throw 'Released card already offers See all' }
        if ($cardText -match '\[update\] card see all=') { throw 'Released card already links the release notes' }
        $process.Refresh()
        $beforeImage = Save-Window $process.MainWindowHandle 'before-card'
        if ((Get-FileHash $cardExe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) { throw 'Card binary changed during proof' }
        Copy-Item -LiteralPath $log -Destination (Join-Path $Evidence 'before-debug.log') -ErrorAction SilentlyContinue
        @{
            released = "v$installed"
            installed = $installed
            offered = $Offer
            notesVersion = $document.version
            notesSha256 = (Get-FileHash $Notes -Algorithm SHA256).Hash.ToLowerInvariant()
            binarySha256 = $hash
            painted = @()
            seeAll = $false
            empty = $true
            cardPng = 'before-card.png'
            success = $true
        } | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $Evidence 'before-card.json')
        Write-Output ('BEFORE_CARD_RECEIPT=' + [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $Evidence 'before-card.json'))))
        Write-Output ('BEFORE_CARD_PNG=' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($beforeImage)))
        return
    }
    Wait-CardLog { $script:cardText -match '\[update\] card note 0=' -and $script:cardText -match '\[update\] card remaining=' } 'Real card app did not paint its change lines' 30
    foreach ($expected in @(
        "\[update\] card view=collapsed n=1 first=$([regex]::Escape($painted))",
        "\[update\] card note 0=$([regex]::Escape($painted))",
        "\[update\] card note id 0=$id",
        '\[update\] card remaining=See all',
        "\[update\] card see all=$([regex]::Escape($seeAll))"
    )) { if ($cardText -notmatch $expected) { throw "Real card log is missing: $expected" } }
    if ($cardText -match '\[update\] card note \d+=.*(?:IGSH|MUBO)-\d+') { throw 'Real card painted a ticket number into the change text' }
    if ($cardText -match '\[update\] card view=collapsed n=(?!1\b)') { throw 'Real card painted an unexpected number of changes' }
    $restart = [regex]::Match($cardText, '\[update\] restart button=(\d+),(\d+)')
    $more = [regex]::Match($cardText, '\[update\] more row=(\d+),(\d+)')
    if (-not $restart.Success -or -not $more.Success) { throw 'Real card geometry is missing its controls' }
    $cardProcess = $process
    $cardProcess.Refresh()
    $cardImage = Save-Window $cardProcess.MainWindowHandle 'released-card'
    $dpiContext = [RealCardProof]::SetThreadDpiAwarenessContext([IntPtr](-4))
    try {
        $point = New-Object RealCardProof+Point
        $point.X = [int]$more.Groups[1].Value
        $point.Y = [int]$more.Groups[2].Value
        $client = New-Object RealCardProof+Rect
        if (-not [RealCardProof]::GetClientRect($cardProcess.MainWindowHandle, [ref]$client)) { throw 'Real card client bounds unavailable' }
        if ($point.X -lt 0 -or $point.Y -lt 0 -or $point.X -ge $client.R -or $point.Y -ge $client.B) { throw 'See all row is outside the real card client' }
        if (-not [RealCardProof]::ClientToScreen($cardProcess.MainWindowHandle, [ref]$point)) { throw 'See all row has no screen position' }
        $null = [RealCardProof]::SetForegroundWindow($cardProcess.MainWindowHandle)
        if (-not [RealCardProof]::SetCursorPos($point.X, $point.Y)) { throw 'Could not reach the See all row' }
        if ([RealCardProof]::WindowFromPoint($point) -ne $cardProcess.MainWindowHandle) { throw 'See all row is obscured' }
        Start-Sleep -Milliseconds 100
        $paintedAt = $cardText.Length
        [RealCardProof]::Click()
    } finally { [void][RealCardProof]::SetThreadDpiAwarenessContext($dpiContext) }
    Wait-CardLog { (Read-CardLog).Substring([Math]::Min($paintedAt, (Read-CardLog).Length)) -match '\[update\] card see all opened=' } 'See all did not open the release notes' 20
    $opened = [regex]::Match((Read-CardLog).Substring([Math]::Min($paintedAt, (Read-CardLog).Length)), '\[update\] card see all opened=(\d+)')
    $browser = $null
    $browserTitle = ''
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    do {
        foreach ($candidate in @(Get-Process -Name msedge, chrome -ErrorAction SilentlyContinue)) {
            if ($candidate.MainWindowHandle -eq [IntPtr]::Zero) { continue }
            if ($candidate.MainWindowTitle -notmatch [regex]::Escape("v$Offer")) { continue }
            $browser = $candidate
            $browserTitle = $candidate.MainWindowTitle
            break
        }
        if ($null -ne $browser -or [DateTime]::UtcNow -gt $deadline) { break }
        Start-Sleep -Milliseconds 250
    } while ($true)
    if ($null -eq $browser) { throw 'See all did not reach the release notes page in a browser' }
    Start-Sleep -Seconds 2
    $releaseImage = Save-Window $browser.MainWindowHandle 'see-all-release'
    $cardProcess.Refresh()
    if ($cardProcess.HasExited -or -not $cardProcess.Responding) { throw 'Real card app stopped answering after See all' }
    if ((Read-CardLog) -notmatch '\[update\] card view=collapsed n=1 ') { throw 'See all changed the painted change lines' }
    if ((Get-FileHash $cardExe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) { throw 'Card binary changed during proof' }
    Copy-Item -LiteralPath $log -Destination (Join-Path $Evidence 'debug.log') -ErrorAction SilentlyContinue
    @{
        installed = $installed
        offered = $Offer
        notesVersion = $document.version
        notesSha256 = (Get-FileHash $Notes -Algorithm SHA256).Hash.ToLowerInvariant()
        binarySha256 = $hash
        published = $changes
        painted = @($painted)
        ids = @($id)
        seeAllUrl = $seeAll
        seeAllOpened = [int]$opened.Groups[1].Value
        browserTitle = $browserTitle
        cardPng = 'released-card.png'
        releasePng = 'see-all-release.png'
        success = $true
    } | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $Evidence 'released-card.json')
    Write-Output ('REAL_CARD_RECEIPT=' + [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $Evidence 'released-card.json'))))
    Write-Output ('REAL_CARD_PNG=' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($cardImage)))
    Write-Output ('SEE_ALL_PNG=' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($releaseImage)))
} finally {
    if ($process) {
        Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $process.Id -and $_.Name -ieq 'powershell.exe' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
    }
    $mutex.ReleaseMutex()
    $mutex.Dispose()
    $event.Dispose()
}
