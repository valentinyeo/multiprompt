param(
    [Parameter(Mandatory=$true)][ValidateSet('appearance', 'sessions', 'workspaces', 'inbox', 'command-palette')][string]$Feature,
    [Parameter(Mandatory=$true)][string]$Exe,
    [Parameter(Mandatory=$true)][string]$ExpectedVersion,
    [Parameter(Mandatory=$true)][string]$ExpectedHash,
    [Parameter(Mandatory=$true)][string]$Evidence
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Run only on a GitHub Windows runner through verify.yml' }
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class VerifyNative {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct Mouse { public int x, y; public uint data, flags, time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] public struct Keyboard { public ushort key, scan; public uint flags, time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Explicit)] public struct Union { [FieldOffset(0)] public Mouse mouse; [FieldOffset(0)] public Keyboard keyboard; }
    [StructLayout(LayoutKind.Sequential)] public struct Input { public uint type; public Union data; }
    [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint count, Input[] inputs, int size);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr hwnd, uint flags);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int command);
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hwnd, int x, int y, int width, int height, bool repaint);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("dwmapi.dll")] public static extern int DwmFlush();
    static void Key(ushort key, ushort scan, uint flags) {
        Input input = new Input(); input.type = 1;
        input.data.keyboard = new Keyboard { key = key, scan = scan, flags = flags };
        if (SendInput(1, new Input[] { input }, Marshal.SizeOf(typeof(Input))) != 1) throw new InvalidOperationException("SendInput failed");
    }
    public static void Chord(int[] keys) {
        foreach (int key in keys) { Key((ushort)key, 0, 0); Thread.Sleep(35); }
        for (int i = keys.Length - 1; i >= 0; i--) Key((ushort)keys[i], 0, 2);
        Thread.Sleep(250);
    }
    public static void Text(string text) {
        foreach (char c in text) { Key(0, c, 4); Key(0, c, 6); Thread.Sleep(30); }
        Thread.Sleep(250);
    }
    public static string Title(IntPtr hwnd) {
        StringBuilder text = new StringBuilder(512); GetWindowText(hwnd, text, text.Capacity); return text.ToString();
    }
    public static string Class(IntPtr hwnd) {
        StringBuilder text = new StringBuilder(256); GetClassName(hwnd, text, text.Capacity); return text.ToString();
    }
}
'@

$Evidence = [IO.Path]::GetFullPath($Evidence)
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$scratch = Join-Path $env:RUNNER_TEMP ('multiprompt-verify-' + [guid]::NewGuid().ToString('N'))
$process = $null
$script:window = [IntPtr]::Zero
$script:actions = New-Object System.Collections.ArrayList
$result = [ordered]@{ feature = $Feature; status = 'failed'; version = $ExpectedVersion; sha256 = $ExpectedHash; checks = @(); offlineLogin = $true; cleanup = 'pending' }
$original = @{}

function Save-Json($Value, [string]$Name) {
    ConvertTo-Json -InputObject $Value -Depth 12 | Set-Content -Encoding UTF8 (Join-Path $Evidence $Name)
}

function Record([string]$Action) {
    [void]$script:actions.Add(@{ time = [DateTime]::UtcNow.ToString('o'); action = $Action; title = [VerifyNative]::Title($script:window) })
    Save-Json @($script:actions.ToArray()) 'actions.json'
}

function Wait-Until([scriptblock]$Condition, [string]$Description, [int]$Seconds = 20) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    $lastError = ''
    do {
        if ($process.HasExited) { throw "App exited while waiting for $Description" }
        try { if (& $Condition) { return } } catch { $lastError = $_.Exception.Message }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Missing precondition or resulting state: $Description. $lastError"
}

function Read-Session {
    $path = Join-Path $scratch 'roaming/ZigShell/session.json'
    if (Test-Path $path) {
        try { return Get-Content $path -Raw | ConvertFrom-Json } catch { return $null }
    }
    return $null
}

function Read-Inbox {
    $path = Join-Path $scratch 'roaming/ZigShell/inbox-default.json'
    if (Test-Path $path) {
        try { return Get-Content $path -Raw | ConvertFrom-Json } catch { return $null }
    }
    return $null
}

function Doctor {
    $process.Refresh()
    if ($process.HasExited -or $script:window -eq [IntPtr]::Zero) { throw 'Doctor: owned app window missing' }
    [uint32]$owner = 0
    [void][VerifyNative]::GetWindowThreadProcessId($script:window, [ref]$owner)
    if ($owner -ne $process.Id -or [VerifyNative]::Class($script:window) -ne 'ZigShell') { throw 'Doctor: window ownership mismatch' }
    if ($process.Path -ne $Exe -or (Get-FileHash $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Doctor: executable identity mismatch' }
    $title = [VerifyNative]::Title($script:window)
    if ($title -notmatch ('multiprompt v' + [regex]::Escape($ExpectedVersion) + '(?:\s|$)')) { throw "Doctor: wrong version in $title" }
    $element = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    if ($element.Current.ProcessId -ne $process.Id -or $element.Current.IsOffscreen) { throw 'Doctor: UI Automation cannot see owned window' }
    $state = Read-Inbox
    if ($null -eq $state -or @($state.shells).Count -lt 1) { throw 'Doctor: no usable initial shell published' }
    Save-Json @{ pid = $process.Id; hwnd = $script:window.ToInt64(); title = $title; class = $element.Current.ClassName; version = $ExpectedVersion; sha256 = $ExpectedHash; shellCount = @($state.shells).Count; data = $scratch } 'doctor.json'
}

function Snapshot([string]$Name) {
    $element = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    $nodes = $element.FindAll([System.Windows.Automation.TreeScope]::Subtree, [System.Windows.Automation.Condition]::TrueCondition)
    $tree = foreach ($node in $nodes) {
        @{ name = $node.Current.Name; class = $node.Current.ClassName; type = $node.Current.ControlType.ProgrammaticName; pid = $node.Current.ProcessId; handle = $node.Current.NativeWindowHandle }
    }
    Save-Json @($tree) ($Name + '.uia.json')
    [void][VerifyNative]::DwmFlush()
    $rect = New-Object VerifyNative+Rect
    if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$rect)) { throw 'Window rectangle unavailable' }
    $bitmap = New-Object Drawing.Bitmap(($rect.Right - $rect.Left), ($rect.Bottom - $rect.Top))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
        $bitmap.Save((Join-Path $Evidence ($Name + '.png')), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}

function Assert-Foreground {
    if ([VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -ne $script:window) { throw 'Refusing input: owned app is not foreground' }
}

function Press([int[]]$Keys, [string]$Label) {
    Doctor
    Assert-Foreground
    Record $Label
    [VerifyNative]::Chord($Keys)
}

function Type-Text([string]$Text) {
    Doctor
    Assert-Foreground
    Record ('Type ' + $Text)
    [VerifyNative]::Text($Text)
}

function Palette([string]$Query) {
    Press @(0x11, 0x4B) 'Ctrl+K: open command palette'
    Type-Text $Query
}

function Select-Theme([string]$Theme, [string]$ActionShot) {
    Palette 'themes'
    Press @(0x0D) 'Enter: Themes...'
    Type-Text $Theme
    Snapshot $ActionShot
    Press @(0x0D) ('Enter: choose ' + $Theme)
    $path = Join-Path $scratch 'roaming/ZigShell/theme-mode.txt'
    Wait-Until { (Test-Path $path) -and (Get-Content $path -Raw).Trim() -eq $Theme } "app-written theme-mode.txt equals $Theme"
    Snapshot ($ActionShot + '-selected')
    Press @(0x1B) 'Esc: close Themes palette'
}

function Sidebar-Luminance([string]$Name) {
    $image = [Drawing.Bitmap]::FromFile((Join-Path $Evidence ($Name + '.png')))
    try {
        $total = 0.0
        $count = 0
        for ($x = 25; $x -lt 130; $x += 7) {
            for ($y = 170; $y -lt 550; $y += 7) {
                $pixel = $image.GetPixel($x, $y)
                $total += ($pixel.R + $pixel.G + $pixel.B) / 3.0
                $count++
            }
        }
        return $total / $count
    } finally { $image.Dispose() }
}

try {
    if ((Get-FileHash $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Executable checksum mismatch before launch' }
    $bytes = [IO.File]::ReadAllBytes($Exe)
    if (-not [Text.Encoding]::ASCII.GetString($bytes).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable build/version marker mismatch' }
    foreach ($name in @('APPDATA', 'LOCALAPPDATA', 'USERPROFILE', 'HOME', 'MULTIPROMPT_NO_LOGIN', 'ZIGSHELL_DEBUG')) {
        $original[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    foreach ($directory in @('roaming', 'local', 'profile')) { New-Item -ItemType Directory -Force (Join-Path $scratch $directory) | Out-Null }
    $env:APPDATA = Join-Path $scratch 'roaming'
    $env:LOCALAPPDATA = Join-Path $scratch 'local'
    $env:USERPROFILE = Join-Path $scratch 'profile'
    $env:HOME = $env:USERPROFILE
    $env:MULTIPROMPT_NO_LOGIN = '1'
    $env:ZIGSHELL_DEBUG = '1'
    $process = Start-Process -FilePath $Exe -ArgumentList '--single-window', '--no-window-restore' -WorkingDirectory $scratch -PassThru -RedirectStandardOutput (Join-Path $Evidence 'stdout.log') -RedirectStandardError (Join-Path $Evidence 'stderr.log')
    Wait-Until {
        $process.Refresh()
        $script:window = $process.MainWindowHandle
        $state = Read-Inbox
        $script:window -ne [IntPtr]::Zero -and $null -ne $state -and @($state.shells).Count -gt 0
    } 'owned main window and initialized CMD session' 60
    [void][VerifyNative]::ShowWindow($script:window, 9)
    [void][VerifyNative]::MoveWindow($script:window, 10, 10, 1000, 650, $true)
    [void][VerifyNative]::SetForegroundWindow($script:window)
    Wait-Until { [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window } 'foreground main window'
    Doctor
    Record 'Launch complete; read-only Doctor passed'
    Snapshot 'before'
    switch ($Feature) {
        'appearance' {
            Select-Theme 'dark' 'baseline-dark-action'
            Snapshot 'before'
            Select-Theme 'light' 'action'
            Snapshot 'after'
            $dark = Sidebar-Luminance 'before'
            $light = Sidebar-Luminance 'after'
            if ($light -lt $dark + 60) { throw "Visible sidebar did not become light: $dark -> $light" }
            $result.checks += @{ name = 'dark-to-light'; darkLuminance = $dark; lightLuminance = $light; savedTheme = 'light' }
        }
        'sessions' {
            $before = @( (Read-Session).tabs ).Count
            Palette 'new cmd'
            Snapshot 'action'
            Press @(0x0D) 'Enter: New CMD shell'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -eq $before + 1 } 'new CMD tab saved'
            Press @(0x71) 'F2: rename active tab'
            Press @(0x11, 0x41) 'Ctrl+A: replace tab name'
            Type-Text 'Verification session'
            Press @(0x0D) 'Enter: save tab name'
            Wait-Until { @((Read-Session).tabs | Where-Object { $_.name -eq 'Verification session' }).Count -eq 1 } 'renamed tab persisted'
            $marker = Join-Path $scratch 'user-created.txt'
            Type-Text ('echo verified-from-real-cmd>"' + $marker + '"')
            Press @(0x0D) 'Enter: execute shell command'
            Wait-Until { (Test-Path $marker) -and (Get-Content $marker -Raw).Trim() -eq 'verified-from-real-cmd' } 'real console command wrote file'
            $result.checks += @{ name = 'create-rename-execute'; tabsBefore = $before; tabsAfter = @((Read-Session).tabs).Count; marker = (Get-Content $marker -Raw).Trim() }
            Snapshot 'after'
        }
        'workspaces' {
            $before = (Read-Session).workspace_count
            Snapshot 'action'
            Press @(0x11, 0x4E) 'Ctrl+N: create workspace'
            Wait-Until { (Read-Session).workspace_count -eq $before + 1 } 'workspace and CMD tab persisted'
            Snapshot 'created'
            $created = (Read-Session).active_workspace
            Press @(0x12, 0x32) 'Alt+2: return to first stored workspace'
            Wait-Until { (Read-Session).active_workspace -eq 0 } 'first workspace active'
            Press @(0x12, 0x27) 'Alt+Right: cycle to new workspace'
            Wait-Until { (Read-Session).active_workspace -eq $created } 'new workspace active again'
            $result.checks += @{ name = 'create-switch-return'; workspacesBefore = $before; workspacesAfter = (Read-Session).workspace_count; activeWorkspace = $created; title = [VerifyNative]::Title($script:window) }
            Snapshot 'after'
        }
        'inbox' {
            Press @(0x11, 0x10, 0x49) 'Ctrl+Shift+I: open Inbox'
            Wait-Until { [VerifyNative]::Title($script:window).StartsWith('Inbox - ') } 'Inbox window state'
            Snapshot 'action'
            $prior = (Read-Inbox).shells[0].att
            Press @(0x55) 'u: toggle selected Inbox session unread'
            Wait-Until { (Read-Inbox).shells[0].att -ne $prior } 'published attention state toggled'
            Snapshot 'after'
            $result.checks += @{ name = 'inbox-toggle-read'; attentionBefore = $prior; attentionAfter = (Read-Inbox).shells[0].att; title = [VerifyNative]::Title($script:window) }
            Press @(0x1B) 'Esc: return from Inbox'
            Wait-Until { -not [VerifyNative]::Title($script:window).StartsWith('Inbox - ') } 'Inbox closed'
            Snapshot 'returned'
        }
        'command-palette' {
            Palette 'interface'
            Snapshot 'action'
            Press @(0x0D) 'Enter: UI Size: Increase'
            Wait-Until { (Read-Session).ui_scale -eq 110 } 'UI scale saved as 110'
            Snapshot 'after'
            Palette 'interface'
            Press @(0x28) 'Down: UI Size: Decrease'
            Press @(0x28) 'Down: UI Size: Reset'
            Press @(0x0D) 'Enter: UI Size: Reset'
            Wait-Until { $state = Read-Session; -not ($state.PSObject.Properties.Name -contains 'ui_scale') -or $state.ui_scale -eq 100 } 'UI scale reset to default'
            Snapshot 'reset'
            $result.checks += @{ name = 'palette-increase-reset'; increasedScale = 110; resetScale = 100 }
        }
    }
    Doctor
    $result.status = 'passed'
} catch {
    $result.error = $_.Exception.Message
    if ($script:window -ne [IntPtr]::Zero) {
        try { Snapshot 'failure' } catch { $result.captureError = $_.Exception.Message }
    }
} finally {
    try {
        if ($null -ne $process -and -not $process.HasExited) {
            Record 'Cleanup: close only the process started by this run'
            [void]$process.CloseMainWindow()
            if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
        }
        if (Test-Path $scratch) {
            Copy-Item $scratch (Join-Path $Evidence 'data') -Recurse -Force
            Remove-Item $scratch -Recurse -Force
        }
        $result.cleanup = 'owned PID stopped; scratch copied to evidence/data then removed'
        if ($result.status -eq 'passed') {
            foreach ($name in @('before.png', 'action.png', 'after.png', 'doctor.json', 'actions.json')) {
                if (-not (Test-Path (Join-Path $Evidence $name))) { throw "Evidence lost during cleanup: $name" }
            }
        }
    } catch {
        $result.status = 'failed'
        $result.cleanup = $_.Exception.Message
    }
    foreach ($name in $original.Keys) { [Environment]::SetEnvironmentVariable($name, $original[$name], 'Process') }
    Save-Json $result 'result.json'
}
if ($result.status -ne 'passed') { throw ('Verification failed: ' + ($result | ConvertTo-Json -Depth 8 -Compress)) }
Write-Output "VERIFIED $Feature with real input and retained evidence"
