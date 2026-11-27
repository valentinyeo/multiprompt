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
$notesHash = (Get-FileHash $Notes -Algorithm SHA256).Hash.ToLowerInvariant()
$tempRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { $env:TEMP }
$disposable = Join-Path $tempRoot ('multiprompt-real-card-' + [guid]::NewGuid().ToString('N'))
$cardExe = Join-Path $disposable 'card.exe'
$appData = Join-Path $disposable 'roaming'
$localData = Join-Path $disposable 'local'
$profileData = Join-Path $disposable 'profile'
$proofPage = Join-Path $disposable 'browser-proof.html'
New-Item -ItemType Directory -Force $disposable | Out-Null
New-Item -ItemType Directory -Force $appData, $localData, $profileData, (Join-Path $appData 'ZigShell') | Out-Null
Copy-Item -LiteralPath $Exe -Destination $cardExe
$hash = (Get-FileHash $cardExe -Algorithm SHA256).Hash.ToLowerInvariant()
$binaryVersion = [regex]::Match([Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($cardExe)), 'MPVERSION=(\d+\.\d+\.\d+);')
if (-not $binaryVersion.Success -or $binaryVersion.Groups[1].Value -cne $installed) { throw 'Card binary does not carry the installed earlier version' }
New-Item -ItemType Directory -Force "$cardExe.update" | Out-Null
Copy-Item -LiteralPath $Notes -Destination "$cardExe.update/release-notes.json" -Force
if ((Get-FileHash $Notes -Algorithm SHA256).Hash -ne (Get-FileHash "$cardExe.update/release-notes.json" -Algorithm SHA256).Hash) { throw 'Staged notes differ from the downloaded production asset' }
[IO.File]::WriteAllText("$cardExe.update/ready.txt", "MPVERSION=$Offer;multiprompt-x64.exe")
[IO.File]::WriteAllText($proofPage, '<html><head><title>Multiprompt browser proof ready</title></head><body>ready</body></html>')
$env:APPDATA = $appData
$env:LOCALAPPDATA = $localData
$env:USERPROFILE = $profileData
$env:HOME = $profileData
$env:MULTIPROMPT_NO_LOGIN = '1'
$env:ZIGSHELL_DEBUG = '1'
$env:IGSH_246 = '1'
$browserExe = ''
$browserProgId = ''
$browserProfilePath = ''
$associationSource = ''
$browserFirstRunPolicyScope = ''
$browserProbeTitle = ''
$browserLaunchCommand = ''
$browserPidsBeforeClick = @()
$shellBrowserIds = @()
$browserPolicyChanges = @()
$browserPolicyRestored = $false
$browserWindowTitle = ''
$navigationSource = ''
$openedValue = 0
$firstShellOpen = 0
$process = $null
$browser = $null
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class RealCardProof {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int L,T,R,B; }
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int X,Y; }
    [StructLayout(LayoutKind.Sequential)] public struct Mouse { public int x, y; public uint data, flags, time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Explicit)] public struct InputUnion { [FieldOffset(0)] public Mouse mouse; }
    [StructLayout(LayoutKind.Sequential)] public struct Input { public uint type; public InputUnion data; }
    public delegate bool EnumProc(IntPtr window, IntPtr parameter);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(Point p);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref Point p);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out Rect r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int command);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc callback, IntPtr parameter);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr window, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint count, Input[] inputs, int size);
    public static string Title(IntPtr window) {
        StringBuilder text = new StringBuilder(1024);
        GetWindowTextW(window, text, text.Capacity);
        return text.ToString();
    }
    public static IntPtr[] VisibleWindows(uint[] processIds) {
        List<IntPtr> found = new List<IntPtr>();
        EnumWindows(delegate(IntPtr window, IntPtr parameter) {
            uint processId;
            GetWindowThreadProcessId(window, out processId);
            if (Array.IndexOf(processIds, processId) >= 0 && IsWindowVisible(window)) found.Add(window);
            return true;
        }, IntPtr.Zero);
        return found.ToArray();
    }
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
$mutex = $null
$mutexAcquired = $false
$log = Join-Path $appData 'ZigShell/debug.log'
$script:cardText = ''
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
function Save-Json($Value, [string]$Name) {
    $Value | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 (Join-Path $Evidence $Name)
}
function Save-CardWindow([IntPtr]$Window, [string]$Name) {
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
function Save-ScreenWindow([IntPtr]$Window, [string]$Name) {
    $previous = [RealCardProof]::SetThreadDpiAwarenessContext([IntPtr](-4))
    try {
        $rectangle = New-Object RealCardProof+Rect
        if (-not [RealCardProof]::GetWindowRect($Window, [ref]$rectangle)) { throw "$Name window rectangle unavailable" }
        $width = $rectangle.R - $rectangle.L
        $height = $rectangle.B - $rectangle.T
        if ($width -lt 400 -or $height -lt 300) { throw "$Name browser window is too small to prove the page" }
        $bitmap = New-Object Drawing.Bitmap($width, $height)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try { $graphics.CopyFromScreen($rectangle.L, $rectangle.T, 0, 0, (New-Object Drawing.Size($width, $height))) } finally { $graphics.Dispose() }
        $file = Join-Path $Evidence ($Name + '.png')
        try { $bitmap.Save($file) } finally { $bitmap.Dispose() }
        Save-Json @{ handle = $Window.ToInt64(); rectangle = $rectangle; width = $width; height = $height; capture = 'screen' } ($Name + '.json')
        return $file
    } finally { [void][RealCardProof]::SetThreadDpiAwarenessContext($previous) }
}
function Save-Desktop([string]$Name) {
    $previous = [RealCardProof]::SetThreadDpiAwarenessContext([IntPtr](-4))
    try {
        $width = [Math]::Max(200, [RealCardProof]::GetSystemMetrics(0))
        $height = [Math]::Max(200, [RealCardProof]::GetSystemMetrics(1))
        $bitmap = New-Object Drawing.Bitmap($width, $height)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try { $graphics.CopyFromScreen(0, 0, 0, 0, (New-Object Drawing.Size($width, $height))) } finally { $graphics.Dispose() }
        $file = Join-Path $Evidence ($Name + '.png')
        try { $bitmap.Save($file) } finally { $bitmap.Dispose() }
        return $file
    } finally { [void][RealCardProof]::SetThreadDpiAwarenessContext($previous) }
}
function Get-OwnedTree([int]$RootProcessId) {
    $snapshot = @(Get-CimInstance Win32_Process | Select-Object -Property ProcessId, ParentProcessId)
    $ids = @($RootProcessId)
    do {
        $added = @($snapshot | Where-Object { $ids -contains [int]$_.ParentProcessId -and $ids -notcontains [int]$_.ProcessId } | ForEach-Object { [int]$_.ProcessId })
        $ids = @($ids + $added)
    } while ($added.Count -gt 0)
    return $ids
}
function Get-BrowserProcesses {
    return @(Get-CimInstance Win32_Process -Filter "Name = 'msedge.exe' OR Name = 'chrome.exe'" | ForEach-Object {
        @{ pid = [int]$_.ProcessId; parent = [int]$_.ParentProcessId; name = $_.Name; commandLine = [string]$_.CommandLine }
    })
}
function Set-BrowserFirstRunPolicy {
    $settings = @(
        @{ name = 'HideFirstRunExperience'; value = 1 },
        @{ name = 'SyncDisabled'; value = 1 }
    )
    foreach ($scope in @('HKLM:', 'HKCU:')) {
        $root = $scope + '\SOFTWARE\Policies\Microsoft\Edge'
        $previous = @()
        try {
            if (-not (Test-Path $root)) { New-Item -Path $root -Force -ErrorAction Stop | Out-Null }
            foreach ($setting in $settings) {
                $existing = Get-ItemProperty -Path $root -Name $setting.name -ErrorAction SilentlyContinue
                $previous += @{ root = $root; name = $setting.name; existed = ($null -ne $existing); value = $(if ($null -ne $existing) { $existing.($setting.name) } else { 0 }) }
                New-ItemProperty -Path $root -Name $setting.name -Value $setting.value -PropertyType DWord -Force -ErrorAction Stop | Out-Null
            }
            $script:browserPolicyChanges = $previous
            return $scope.TrimEnd(':')
        } catch { $previous = @() }
    }
    throw 'This machine refused the documented browser first-run policy, so a first-run page would replace the release notes'
}
function Restore-BrowserFirstRunPolicy {
    foreach ($change in @($script:browserPolicyChanges)) {
        if ($change.existed) {
            New-ItemProperty -Path $change.root -Name $change.name -Value $change.value -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
        } else {
            Remove-ItemProperty -Path $change.root -Name $change.name -Force -ErrorAction SilentlyContinue
        }
    }
}
function Test-BrowserUsesProfile([string]$ProfilePath) {
    if ($ProfilePath.Length -eq 0) { return $false }
    $quoted = '--user-data-dir="' + $ProfilePath + '"'
    $bare = '--user-data-dir=' + $ProfilePath
    foreach ($browserProcess in @(Get-BrowserProcesses)) {
        $command = [string]$browserProcess.commandLine
        if ($command.Contains($quoted) -or $command.Contains($bare)) { return $true }
    }
    return $false
}
function Get-BrowserWindows {
    $browserIds = @(Get-Process -Name 'msedge', 'chrome' -ErrorAction SilentlyContinue | ForEach-Object { [uint32]$_.Id })
    if ($browserIds.Count -eq 0) { return @() }
    return @([RealCardProof]::VisibleWindows([uint32[]]$browserIds) | ForEach-Object {
        $handle = [IntPtr]$_
        @{ handle = $handle.ToInt64(); title = [RealCardProof]::Title($handle) }
    } | Where-Object { $_.title.Length -gt 0 })
}
function Get-BrowserProcessIds {
    return @(Get-Process -Name 'msedge', 'chrome' -ErrorAction SilentlyContinue | ForEach-Object { [int]$_.Id })
}
function Get-OwnedWindows([int[]]$Roots) {
    $ids = @()
    foreach ($root in @($Roots)) { if ($root -gt 0) { $ids += @(Get-OwnedTree $root) } }
    $unique = [uint32[]]@($ids | Select-Object -Unique | ForEach-Object { [uint32]$_ })
    if ($unique.Count -eq 0) { return @() }
    return @([RealCardProof]::VisibleWindows($unique) | ForEach-Object {
        $handle = [IntPtr]$_
        @{ handle = $handle; title = [RealCardProof]::Title($handle) }
    } | Where-Object { $_.title.Length -gt 0 })
}
function Wait-OwnedWindowTitle([int[]]$Roots, [string]$Pattern, [int]$Seconds) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    do {
        foreach ($candidate in @(Get-OwnedWindows $Roots)) {
            if ($candidate.title -match $Pattern) { return $candidate }
        }
        if ([DateTime]::UtcNow -gt $deadline) { return $null }
        Start-Sleep -Milliseconds 250
    } while ($true)
}
function Resolve-DefaultBrowser {
    $progId = ''
    try { $progId = [string](Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice' -ErrorAction Stop).ProgId } catch { $progId = '' }
    $appLocal = [IO.Path]::GetFullPath($env:LOCALAPPDATA)
    $programFiles = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }
    $chrome = @($programFiles | ForEach-Object { Join-Path $_ 'Google\Chrome\Application\chrome.exe' }) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    $edge = @($programFiles | ForEach-Object { Join-Path $_ 'Microsoft\Edge\Application\msedge.exe' }) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($progId -eq 'ChromeHTML' -and $chrome) { return @{ progId = $progId; exe = $chrome; profile = (Join-Path (Join-Path $appLocal 'Google\Chrome') 'User Data'); source = 'user choice' } }
    if ($progId -eq 'MSEdgeHTM' -and $edge) { return @{ progId = $progId; exe = $edge; profile = (Join-Path (Join-Path $appLocal 'Microsoft\Edge') 'User Data'); source = 'user choice' } }
    if ($edge) { return @{ progId = $progId; exe = $edge; profile = (Join-Path (Join-Path $appLocal 'Microsoft\Edge') 'User Data'); source = 'proof fallback' } }
    if ($chrome) { return @{ progId = $progId; exe = $chrome; profile = (Join-Path (Join-Path $appLocal 'Google\Chrome') 'User Data'); source = 'proof fallback' } }
    throw 'No installed browser can carry the release notes proof'
}
function Set-UrlHandler([string]$BrowserExe) {
    foreach ($scheme in @('http', 'https')) {
        $protocol = "HKCU:\Software\Classes\$scheme"
        if (-not (Test-Path $protocol)) { New-Item -Path $protocol -Force | Out-Null }
        if ($null -eq (Get-ItemProperty -Path $protocol -Name 'URL Protocol' -ErrorAction SilentlyContinue)) { Set-ItemProperty -Path $protocol -Name 'URL Protocol' -Value '' }
        $command = Join-Path $protocol 'shell\open\command'
        if (-not (Test-Path $command)) { New-Item -Path $command -Force | Out-Null }
        Set-Item -Path $command -Value ('"' + $BrowserExe + '" "%1"') -Force
    }
}
function Start-ProofBrowser([string]$Page) {
    $script:browser = Start-Process -FilePath $browserExe -ArgumentList ('"' + $Page + '"') -PassThru
    $probe = Wait-OwnedWindowTitle ([int[]]@($script:browser.Id)) 'Multiprompt browser proof ready' 90
    if ($null -eq $probe) { throw 'The browser did not render a page in the app environment, so its first-run setup would replace the release notes' }
    $script:browserProbeTitle = $probe.title
    $stopped = @(Stop-OwnedTree $script:browser.Id)
    $alive = @(Wait-ProcessGone ([int[]]@($stopped | Select-Object -Unique)) 20)
    if ($alive.Count -gt 0) { throw 'The configured proof browser did not stop before the See all click' }
}
function Invoke-SeeAllClick([int]$HintX, [int]$HintY) {
    $dpiContext = [RealCardProof]::SetThreadDpiAwarenessContext([IntPtr](-4))
    try {
        $point = New-Object RealCardProof+Point
        $point.X = $HintX
        $point.Y = $HintY
        $client = New-Object RealCardProof+Rect
        if (-not [RealCardProof]::GetClientRect($process.MainWindowHandle, [ref]$client)) { throw 'Real card client bounds unavailable' }
        if ($point.X -lt 0 -or $point.Y -lt 0 -or $point.X -ge $client.R -or $point.Y -ge $client.B) { throw 'See all row is outside the real card client' }
        if (-not [RealCardProof]::ClientToScreen($process.MainWindowHandle, [ref]$point)) { throw 'See all row has no screen position' }
        $null = [RealCardProof]::SetForegroundWindow($process.MainWindowHandle)
        if (-not [RealCardProof]::SetCursorPos($point.X, $point.Y)) { throw 'Could not reach the See all row' }
        if ([RealCardProof]::WindowFromPoint($point) -ne $process.MainWindowHandle) { throw 'See all row is obscured' }
        Start-Sleep -Milliseconds 100
        [RealCardProof]::Click()
    } finally { [void][RealCardProof]::SetThreadDpiAwarenessContext($dpiContext) }
}
function Wait-SeeAllOpen([int]$Offset) {
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    do {
        $text = Read-CardLog
        $fresh = $text.Substring([Math]::Min($Offset, $text.Length))
        if ($fresh -match '\[update\] card see all opened=\d+') {
            $last = @([regex]::Matches($fresh, '\[update\] card see all opened=(\d+)'))[-1]
            return [int]$last.Groups[1].Value
        }
        if ($process.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw 'See all did not report a shell open' }
        Start-Sleep -Milliseconds 100
    } while ($true)
}
function Show-BrowserForCapture([IntPtr]$Window) {
    [void][RealCardProof]::ShowWindow($Window, 9)
    $null = [RealCardProof]::SetForegroundWindow($Window)
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        if ([RealCardProof]::GetForegroundWindow() -eq $Window) { return $true }
        if ([DateTime]::UtcNow -gt $deadline) { return $false }
        Start-Sleep -Milliseconds 100
    } while ($true)
}
function Save-FailureEvidence([string]$Reason) {
    $text = Read-CardLog
    $tail = if ($text.Length -gt 4000) { $text.Substring($text.Length - 4000) } else { $text }
    if ($text.Length -gt 0) { Copy-Item -LiteralPath $log -Destination (Join-Path $Evidence 'debug.log') -Force -ErrorAction SilentlyContinue }
    $desktop = ''
    try { $desktop = Save-Desktop 'failure-desktop' } catch { $desktop = '' }
    Save-Json @{
        reason = $Reason
        before = [bool]$Before
        seeAllUrl = $seeAll
        shellOpenCode = $openedValue
        firstShellOpenCode = $firstShellOpen
        navigationSource = $navigationSource
        cardLogTail = $tail
        browserExe = $browserExe
        browserProgId = $browserProgId
        browserProfile = $browserProfilePath
        associationSource = $associationSource
        browserFirstRunPolicyScope = $browserFirstRunPolicyScope
        browserProbeTitle = $browserProbeTitle
        browserLaunchCommand = $browserLaunchCommand
        browserPid = $(if ($browser) { $browser.Id } else { 0 })
        browserExited = $(if ($browser) { $browser.HasExited } else { $true })
        browserProfileInAppEnvironment = $(if ($browserProfilePath) { $browserProfilePath.StartsWith([IO.Path]::GetFullPath($env:LOCALAPPDATA), [StringComparison]::OrdinalIgnoreCase) } else { $false })
        browserProfileConfirmed = (Test-BrowserUsesProfile $browserProfilePath)
        browserProcesses = @(Get-BrowserProcesses)
        browserWindows = @(Get-BrowserWindows)
        desktopPng = $(if ($desktop) { Split-Path $desktop -Leaf } else { '' })
    } 'see-all-diagnostics.json'
}
function Stop-OwnedTree([Nullable[int]]$RootProcessId) {
    if ($null -eq $RootProcessId -or $RootProcessId -le 0) { return @() }
    $owned = @(Get-OwnedTree $RootProcessId)
    if ($owned.Count -gt 0) {
        $ordered = @($owned)
        [array]::Reverse($ordered)
        foreach ($ownedId in $ordered) { Stop-Process -Id $ownedId -Force -ErrorAction SilentlyContinue }
    }
    return $owned
}
function Wait-ProcessGone([int[]]$ProcessIds, [int]$Seconds) {
    if ($ProcessIds.Count -eq 0) { return @() }
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    do {
        $alive = @($ProcessIds | ForEach-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue } | Where-Object { $_ } | ForEach-Object { [int]$_.Id })
        if ($alive.Count -eq 0) { return @() }
        if ([DateTime]::UtcNow -gt $deadline) { return $alive }
        Start-Sleep -Milliseconds 100
    } while ($true)
}
function Invoke-CardProof {
    if (-not $Before) {
        $browserChoice = Resolve-DefaultBrowser
        $script:browserExe = $browserChoice.exe
        $script:browserProgId = $browserChoice.progId
        $script:browserProfilePath = $browserChoice.profile
        $script:associationSource = $browserChoice.source
        if ($script:associationSource -eq 'proof fallback') { Set-UrlHandler $script:browserExe }
        $appRoot = [IO.Path]::GetFullPath($env:LOCALAPPDATA)
        if (-not $script:browserProfilePath.StartsWith($appRoot, [StringComparison]::OrdinalIgnoreCase)) { throw "Browser profile $($script:browserProfilePath) is outside the app environment $appRoot" }
        $script:browserFirstRunPolicyScope = Set-BrowserFirstRunPolicy
        Start-ProofBrowser ([uri]$proofPage).AbsoluteUri
    }
    $script:process = Start-Process $cardExe -ArgumentList "--update-ready $eventName" -PassThru
    if (-not $event.WaitOne(20000)) { throw 'Real card app did not report readiness' }
    if ($Before) {
        Wait-CardLog { $script:cardText -match '\[update\] card view=collapsed n=0 ' -and $script:cardText -match '\[update\] card remaining=' } 'Released card did not paint its version row' 30
        if ($cardText -match '\[update\] card note ') { throw 'Released card already names a change' }
        if ($cardText -match '\[update\] more row=') { throw 'Released card already offers See all' }
        if ($cardText -match '\[update\] card see all=') { throw 'Released card already links the release notes' }
        $process.Refresh()
        $beforeImage = Save-CardWindow $process.MainWindowHandle 'before-card'
        if ((Get-FileHash $cardExe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) { throw 'Card binary changed during proof' }
        Copy-Item -LiteralPath $log -Destination (Join-Path $Evidence 'before-debug.log') -ErrorAction SilentlyContinue
        Save-Json @{
            released = "v$installed"
            installed = $installed
            offered = $Offer
            notesVersion = $document.version
            notesSha256 = $notesHash
            binarySha256 = $hash
            painted = @()
            seeAll = $false
            empty = $true
            cardPng = 'before-card.png'
            success = $true
        } 'before-card.json'
        Save-Json @{
            kind = 'released installed executable'
            sourceExe = $Exe
            binarySha256 = $hash
            binaryVersion = $installed
            notesPath = $Notes
            notesSha256 = $notesHash
            notesVersion = $document.version
            offered = $Offer
            seeAllUrl = $seeAll
            os = [Environment]::OSVersion.VersionString
            commit = [string]$env:GITHUB_SHA
        } 'provenance.json'
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
    $cardImage = Save-CardWindow $cardProcess.MainWindowHandle 'released-card'
    $paintedAt = $cardText.Length
    $script:browserPidsBeforeClick = @(Get-BrowserProcessIds)
    foreach ($staleWindow in @(Get-OwnedWindows $script:browserPidsBeforeClick)) {
        if ($staleWindow.title -match [regex]::Escape("v$Offer")) { throw 'A browser window already named the offered release before the click' }
    }
    Invoke-SeeAllClick ([int]$more.Groups[1].Value) ([int]$more.Groups[2].Value)
    $script:openedValue = Wait-SeeAllOpen $paintedAt
    $script:firstShellOpen = $script:openedValue
    if ($script:openedValue -le 32) {
        Set-UrlHandler $browserExe
        foreach ($scheme in @('http', 'https')) { Remove-Item -Path "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\$scheme\UserChoice" -Force -ErrorAction SilentlyContinue }
        $script:associationSource = 'proof fallback after shell open failed'
        $paintedAt = (Read-CardLog).Length
        Invoke-SeeAllClick ([int]$more.Groups[1].Value) ([int]$more.Groups[2].Value)
        $script:openedValue = Wait-SeeAllOpen $paintedAt
        if ($script:openedValue -le 32) { $null = Save-FailureEvidence "See all shell open failed with code $script:openedValue"; throw "See all shell open failed with code $script:openedValue" }
    }
    $releaseWindow = [IntPtr]::Zero
    $windowTitle = ''
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    do {
        $script:shellBrowserIds = @(Get-BrowserProcessIds | Where-Object { $script:browserPidsBeforeClick -notcontains $_ })
        if ($script:browserLaunchCommand -eq '') {
            $launch = @(Get-BrowserProcesses | Where-Object { $script:browserPidsBeforeClick -notcontains $_.pid -and ([string]$_.commandLine).Contains($seeAll) })
            if ($launch.Count -gt 0) { $script:browserLaunchCommand = [string]$launch[0].commandLine }
        }
        foreach ($candidate in @(Get-OwnedWindows $script:shellBrowserIds)) {
            if ($candidate.title -match [regex]::Escape("v$Offer")) { $releaseWindow = [IntPtr]$candidate.handle; $windowTitle = $candidate.title; break }
        }
        if ($releaseWindow -ne [IntPtr]::Zero) { break }
        if ([DateTime]::UtcNow -gt $deadline) { break }
        Start-Sleep -Milliseconds 500
    } while ($true)
    $script:browserWindowTitle = $windowTitle
    if ($script:browserLaunchCommand -eq '') { $null = Save-FailureEvidence 'no browser process carried the See all address'; throw 'No browser process carried the See all address, so the click did not reach a browser' }
    if ($releaseWindow -eq [IntPtr]::Zero) { $null = Save-FailureEvidence 'no browser window rendered the release notes page'; throw 'See all did not reach the release notes page in a browser' }
    if ($windowTitle -notmatch [regex]::Escape("v$Offer")) { $null = Save-FailureEvidence 'the release notes page is open but no browser window names the offered release'; throw 'No browser window shows the offered release, so the screenshot would not prove the destination' }
    if (-not (Test-BrowserUsesProfile $script:browserProfilePath) -and -not (Test-Path (Join-Path $script:browserProfilePath 'Default\Preferences'))) { $null = Save-FailureEvidence 'no browser used the app environment profile'; throw 'No browser used the app environment profile, so the destination browser was not the one the app launches' }
    $script:navigationSource = 'window-title'
    if (-not (Show-BrowserForCapture $releaseWindow)) { $null = Save-FailureEvidence 'release notes browser did not take the foreground'; throw 'Could not bring the release notes browser to the front' }
    $releaseImage = Save-ScreenWindow $releaseWindow 'see-all-release'
    $cardProcess.Refresh()
    if ($cardProcess.HasExited -or -not $cardProcess.Responding) { throw 'Real card app stopped answering after See all' }
    if ((Read-CardLog) -notmatch '\[update\] card view=collapsed n=1 ') { throw 'See all changed the painted change lines' }
    if ((Get-FileHash $cardExe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) { throw 'Card binary changed during proof' }
    Copy-Item -LiteralPath $log -Destination (Join-Path $Evidence 'debug.log') -ErrorAction SilentlyContinue
    Save-Json @{
        installed = $installed
        offered = $Offer
        notesVersion = $document.version
        notesSha256 = $notesHash
        binarySha256 = $hash
        published = $changes
        painted = @($painted)
        ids = @($id)
        seeAllUrl = $seeAll
        seeAllOpened = $script:openedValue
        firstShellOpen = $script:firstShellOpen
        navigationSource = $script:navigationSource
        browserExe = $browserExe
        browserProgId = $browserProgId
        browserProfile = $browserProfilePath
        browserProfileConfirmed = $true
        browserFirstRunPolicyScope = $browserFirstRunPolicyScope
        browserProbeTitle = $script:browserProbeTitle
        browserLaunchCommand = $script:browserLaunchCommand
        releaseWindowBeforeClick = $false
        associationSource = $associationSource
        browserTitle = $script:browserWindowTitle
        cardPng = 'released-card.png'
        releasePng = 'see-all-release.png'
        success = $true
    } 'released-card.json'
    Save-Json @{
        kind = 'branch build with build-option version override'
        sourceExe = $Exe
        binarySha256 = $hash
        binaryVersion = $installed
        notesPath = $Notes
        notesSha256 = $notesHash
        notesVersion = $document.version
        offered = $Offer
        seeAllUrl = $seeAll
        os = [Environment]::OSVersion.VersionString
        commit = [string]$env:GITHUB_SHA
        browserExe = $browserExe
        browserProgId = $browserProgId
        browserFirstRunPolicyScope = $browserFirstRunPolicyScope
        browserProbeTitle = $script:browserProbeTitle
        associationSource = $associationSource
    } 'provenance.json'
    Write-Output ('REAL_CARD_RECEIPT=' + [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $Evidence 'released-card.json'))))
    Write-Output ('REAL_CARD_PNG=' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($cardImage)))
    Write-Output ('SEE_ALL_PNG=' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($releaseImage)))
}
try {
    $mutex = New-Object Threading.Mutex($false, $mutexName)
    $null = $mutex.WaitOne()
    $mutexAcquired = $true
    try { Invoke-CardProof } catch {
        $reason = [string]$_.Exception.Message
        try { $null = Save-FailureEvidence $reason } catch { $null = $_ }
        throw
    }
} finally {
    $stopped = @()
    if ($null -ne $process -and -not $process.HasExited) { $stopped += @(Stop-OwnedTree $process.Id) }
    if ($null -ne $browser -and -not $browser.HasExited) { $stopped += @(Stop-OwnedTree $browser.Id) }
    foreach ($rootId in @($shellBrowserIds)) { if ($rootId -gt 0) { $stopped += @(Stop-OwnedTree $rootId) } }
    $remaining = @()
    if ($stopped.Count -gt 0) { $remaining = @(Wait-ProcessGone ([int[]]@($stopped | Select-Object -Unique)) 20) }
    try { Restore-BrowserFirstRunPolicy; $browserPolicyRestored = $true } catch { $browserPolicyRestored = $false }
    $disposableRemoved = $false
    for ($attempt = 0; $attempt -lt 10 -and -not $disposableRemoved; $attempt++) {
        Remove-Item -LiteralPath $disposable -Recurse -Force -ErrorAction SilentlyContinue
        $disposableRemoved = -not (Test-Path -LiteralPath $disposable)
        if (-not $disposableRemoved) { Start-Sleep -Milliseconds 200 }
    }
    try {
        Save-Json @{
            ownedPids = @($stopped | Select-Object -Unique)
            remainingPids = $remaining
            disposableRemoved = $disposableRemoved
            browserProfile = $browserProfilePath
            browserProfileRetained = $(if ($browserProfilePath) { Test-Path -LiteralPath $browserProfilePath } else { $false })
            browserPolicyRestored = $browserPolicyRestored
            evidenceFiles = @(Get-ChildItem -LiteralPath $Evidence -File | ForEach-Object { $_.Name })
            success = ($remaining.Count -eq 0 -and $disposableRemoved)
        } 'cleanup.json'
    } catch { $null = $_ }
    if ($mutexAcquired) { $mutex.ReleaseMutex() }
    if ($null -ne $mutex) { $mutex.Dispose() }
    $event.Dispose()
}
