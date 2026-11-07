$ErrorActionPreference = 'Stop'
Add-Type -Path "$PSScriptRoot/../verify-reconnect/desktop.cs"
[ReconnectDesktop]::StartSpy()
. "$PSScriptRoot/foreground.ps1"
. "$PSScriptRoot/diagnostics.ps1"
$source = @'
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
trap {
    [Console]::Error.WriteLine($_.Exception.ToString())
    [Console]::Error.WriteLine($_.ScriptStackTrace)
    exit 1
}
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
[Console]::Out.WriteLine('probe: assemblies loaded')
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public static class FixtureControls {
    [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern IntPtr CreateWindowEx(int ex, string cls, string text, uint style, int x, int y, int w, int h, IntPtr parent, IntPtr menu, IntPtr instance, IntPtr param);
    [DllImport("user32.dll")] public static extern IntPtr SetFocus(IntPtr h);
    delegate IntPtr WindowProc(IntPtr h, uint msg, IntPtr wp, IntPtr lp);
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct WNDCLASS { public uint style; public WindowProc proc; public int clsExtra, wndExtra; public IntPtr instance, icon, cursor, background; public string menu, name; }
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern ushort RegisterClass(ref WNDCLASS cls);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] static extern IntPtr GetModuleHandle(string name);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr DefWindowProc(IntPtr h, uint msg, IntPtr wp, IntPtr lp);
    [DllImport("user32.dll")] static extern bool DestroyWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int command);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    static WindowProc proc = HandleMessage;
    static IntPtr owner;
    static IntPtr HandleMessage(IntPtr h, uint msg, IntPtr wp, IntPtr lp) {
        if (msg == 0x100 && (wp.ToInt64() == 0x1b || wp.ToInt64() == 0x0d)) {
            Console.Out.WriteLine(wp.ToInt64() == 0x1b ? "modal-cancel" : "modal-approve");
            Control.FromHandle(owner).Enabled = true;
            DestroyWindow(h);
            SetForegroundWindow(owner);
            return IntPtr.Zero;
        }
        return DefWindowProc(h, msg, wp, lp);
    }
    public static void Modal(IntPtr root, string title, bool wrongClass) {
        owner = root;
        string cls = wrongClass ? "FixtureOtherDialog" : "MultiPromptDialog";
        IntPtr instance = GetModuleHandle(null);
        var wc = new WNDCLASS { proc = proc, name = cls, instance = instance };
        RegisterClass(ref wc);
        IntPtr h = CreateWindowEx(0, cls, title, 0x80000000, 20, 20, 200, 100, root, IntPtr.Zero, instance, IntPtr.Zero);
        if (h == IntPtr.Zero) throw new Exception("Fixture modal creation failed");
        Control.FromHandle(root).Enabled = false;
        ShowWindow(h, 5);
        SetForegroundWindow(h);
        SetFocus(h);
    }
}
public class FixtureForm : Form {
    protected override bool IsInputKey(Keys keyData) {
        return (keyData & Keys.KeyCode) == Keys.Enter || base.IsInputKey(keyData);
    }
}
"@ -ReferencedAssemblies System.Windows.Forms, System.Drawing
[Console]::Out.WriteLine('probe: types compiled')
$form = [FixtureForm]::new()
[Console]::Out.WriteLine('probe: form created')
$form.Text = 'Account journey foreground probe'
$form.KeyPreview = $true
$form.Add_KeyDown({
    if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        [void][FixtureControls]::SetFocus($script:enabledEdit)
        $_.Handled = $true
    } elseif ($_.KeyCode -eq [System.Windows.Forms.Keys]::F2) {
        [FixtureControls]::Modal($form.Handle, 'Account: Approve devices', $false)
    } elseif ($_.KeyCode -eq [System.Windows.Forms.Keys]::F3) {
        [FixtureControls]::Modal($form.Handle, 'synthetic-secret-unknown', $false)
    } elseif ($_.KeyCode -eq [System.Windows.Forms.Keys]::F4) {
        [FixtureControls]::Modal($form.Handle, 'Account: Approve devices', $true)
    } elseif ($_.KeyCode -eq [System.Windows.Forms.Keys]::F5) {
        [FixtureControls]::Modal($form.Handle, 'Multi Bot sync', $false)
    } elseif ($_.KeyCode -eq [System.Windows.Forms.Keys]::F6) {
        [FixtureControls]::Modal($form.Handle, 'Multi Bot', $false)
    }
})
$form.Add_Shown({
    [Console]::Out.WriteLine('probe: form shown')
    foreach ($item in @(@('Edit', 0x50000000), @('Edit', 0x58000000), @('Edit', 0x40000000), @('Button', 0x50000000))) {
        $h = [FixtureControls]::CreateWindowEx(0, $item[0], 'private fixture text', [uint32]$item[1], 0, 0, 60, 20, $form.Handle, [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero)
        if ($h -eq [IntPtr]::Zero) { throw 'Cannot create fixture control' }
        if ($item[0] -eq 'Edit' -and $item[1] -eq 0x50000000) { $script:enabledEdit = $h }
    }
    foreach ($index in 1..14) {
        $h = [FixtureControls]::CreateWindowEx(0, 'STATIC', 'synthetic-secret-owned-title', [uint32]2147483648, 0, 0, 60, 20, $form.Handle, [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero)
        if ($h -eq [IntPtr]::Zero) { throw 'Cannot create owned fixture window' }
    }
    $dialog = [FixtureControls]::CreateWindowEx(0, '#32770', 'synthetic-secret-dialog-title', [uint32]2147483648, 0, 0, 60, 20, $form.Handle, [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero)
    if ($dialog -eq [IntPtr]::Zero) { throw 'Cannot create owned fixture dialog' }
    [void][FixtureControls]::SetFocus($form.Handle)
})
[System.Windows.Forms.Application]::Run($form)
'@
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($source))
$processes = @()
$logs = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $logs | Out-Null
$failed = $false
try {
    foreach ($index in 0, 1) {
        $processes += Start-Process powershell.exe -ArgumentList '-NoProfile', '-NonInteractive', '-STA', '-EncodedCommand', $encoded -PassThru -RedirectStandardError (Join-Path $logs "$index.err") -RedirectStandardOutput (Join-Path $logs "$index.out")
    }
    $windows = @()
    foreach ($index in 0, 1) {
        $process = $processes[$index]
        $deadline = [DateTime]::UtcNow.AddSeconds(20)
        $window = [IntPtr]::Zero
        do {
            $process.Refresh()
            if ($process.HasExited) { break }
            $candidates = [System.Collections.Generic.List[IntPtr]]::new()
            $callback = [ReconnectDesktop+EnumProc]{
                param([IntPtr]$h, [IntPtr]$p)
                if ([ReconnectDesktop]::Owner($h) -eq [uint32]$process.Id -and [ReconnectDesktop]::IsWindowVisible($h) -and [ReconnectDesktop]::Class($h) -like 'WindowsForms10.*') { $candidates.Add($h); return $false }
                return $true
            }
            [void][ReconnectDesktop]::EnumWindows($callback, [IntPtr]::Zero)
            if ($candidates.Count -gt 0) { $window = $candidates[0]; break }
            Start-Sleep -Milliseconds 100
        } while ([DateTime]::UtcNow -lt $deadline)
        if ($window -eq [IntPtr]::Zero) {
            foreach ($stream in 'out', 'err') {
                $detail = try { Get-Content -Raw (Join-Path $logs "$index.$stream") } catch { "unavailable: $($_.Exception.Message)" }
                Write-Host "Foreground probe $index $stream`n$detail"
            }
            throw "Foreground probe window did not appear (pid=$($process.Id), exited=$($process.HasExited)); see probe stdout and stderr above"
        }
        $windows += $window
    }
    foreach ($index in 0, 1) {
        $deadline = [DateTime]::UtcNow.AddSeconds(10)
        do {
            $snapshot = [JourneyForeground]::OwnedWindows($windows[$index], $processes[$index].Id)
            if ($snapshot -match '^count=(\d+),truncated=True,entries=(.*)$' -and [int]$Matches[1] -ge 15) { break }
            Start-Sleep -Milliseconds 50
        } while ([DateTime]::UtcNow -lt $deadline)
        if ($snapshot -notmatch '^count=(\d+),truncated=True,entries=(.*)$' -or [int]$Matches[1] -lt 15) { throw 'Owned-window count or truncation mismatch' }
        $entries = @($Matches[2] -split ',')
        if ($entries.Count -ne 12) { throw 'Owned-window output was not bounded' }
        foreach ($entry in $entries) {
            if ($entry -notmatch '^(\d+):(\d+):(True|False):(True|False):(MultiPromptDialog|MultipromptSettingsKey|#32770|other):(approval|sync|account-duplicate|unknown)$') { throw 'Unsafe owned-window entry' }
            if ([long]$Matches[2] -ne $windows[$index].ToInt64() -or [ReconnectDesktop]::Owner([IntPtr][long]$Matches[1]) -ne $processes[$index].Id) { throw 'Owned-window snapshot included a foreign owner or PID' }
        }
        $rejected = $false
        try { [void][JourneyForeground]::OwnedWindows($windows[$index], $processes[1 - $index].Id) } catch { $rejected = $true }
        if (!$rejected -or $snapshot -match 'synthetic-secret|STATIC') { throw 'Owned-window PID or redaction failure' }
    }
    foreach ($index in @(0, 1, 0, 1)) {
        Set-JourneyForeground $windows[$index] $processes[$index].Id
        Assert-Window $windows[$index] $processes[$index].Id
        if ([ReconnectDesktop]::Focus($windows[$index])[0] -ne $windows[$index].ToInt64()) { throw 'Foreground probe focus mismatch' }
    }
    foreach ($index in 0, 1) {
        $edits = @([JourneyForeground]::VisibleEdits($windows[$index], $processes[$index].Id))
        if ($edits.Count -ne 2 -or $edits[0] -eq $edits[1]) { throw 'Visible Edit enumeration included hidden or non-Edit controls, or missed controls' }
        if (@([JourneyForeground]::VisibleEdits($edits[0], $processes[$index].Id)).Count -ne 0) { throw 'Visible Edit enumeration found children of an Edit control' }
        foreach ($edit in $edits) {
            if ([ReconnectDesktop]::Owner($edit) -ne $processes[$index].Id -or [ReconnectDesktop]::GetAncestor($edit, 2) -ne $windows[$index] -or [ReconnectDesktop]::Class($edit) -cne 'Edit') { throw 'Visible Edit enumeration returned a foreign control' }
        }
        $thread = [JourneyForeground]::ThreadId($windows[$index])
        if (!$thread -or @($edits | Where-Object { [JourneyForeground]::ThreadId($_) -ne $thread }).Count -ne 0) { throw 'Edit thread identity mismatch' }
        $enabled = @($edits | ForEach-Object { [JourneyForeground]::Enabled($_) } | Sort-Object)
        if (($enabled -join ',') -cne 'False,True' -or [JourneyForeground]::ThreadFocus($thread) -notmatch '^\d+$' -or [JourneyForeground]::ThreadFocus(0) -cne 'unavailable' -or [JourneyForeground]::Enabled([IntPtr]::Zero) -cne 'unavailable') { throw 'Edit thread or enabled diagnostic mismatch' }
        if (@([JourneyForeground]::VisibleEdits($windows[$index], $processes[1 - $index].Id)).Count -ne 0) { throw 'Visible Edit enumeration accepted another PID' }
        $target = @($edits | Where-Object { [JourneyForeground]::Enabled($_) -ceq 'True' })[0]
        Set-JourneyForeground $windows[$index] $processes[$index].Id
        Assert-Window $windows[$index] $processes[$index].Id
        $focus = [ReconnectDesktop]::Focus($windows[$index])
        if ($focus[0] -ne $windows[$index].ToInt64() -or $focus[1] -ne $windows[$index].ToInt64()) { throw "Enter probe initial focus mismatch: root=$($windows[$index].ToInt64()) target=$($target.ToInt64()) foreground=$($focus[0]) focus=$($focus[1]) active=$($focus[2])" }
        [ReconnectDesktop]::Type(0x0D)
        $deadline = [DateTime]::UtcNow.AddSeconds(5)
        do {
            $focus = [ReconnectDesktop]::Focus($windows[$index])
            if ($focus[0] -eq $windows[$index].ToInt64() -and $focus[1] -eq $target.ToInt64()) { break }
            Start-Sleep -Milliseconds 50
        } while ([DateTime]::UtcNow -lt $deadline)
        if ($focus[0] -ne $windows[$index].ToInt64() -or $focus[1] -ne $target.ToInt64()) { throw "Enter probe focus mismatch: root=$($windows[$index].ToInt64()) target=$($target.ToInt64()) foreground=$($focus[0]) focus=$($focus[1]) active=$($focus[2])" }
        Assert-Window $windows[$index] $processes[$index].Id
    }
    $rejected = $false
    try { Set-JourneyForeground $windows[0] $processes[1].Id } catch { $rejected = $_.Exception.Message -match 'expected hwnd=.*owner=.*foreground=' }
    if (!$rejected) { throw 'Foreground probe accepted a window owned by another process' }

    Set-JourneyForeground $windows[0] $processes[0].Id
    [JourneyForeground]::Activate($windows[1])
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        $seen = @([ReconnectDesktop]::EventsSince($script:journeyEventStart) | Where-Object { $_.ev -eq 3 -and $_.hwnd -eq $windows[1].ToInt64() }).Count -gt 0
        if ([ReconnectDesktop]::GetForegroundWindow() -eq $windows[1] -and $seen) { break }
        Start-Sleep -Milliseconds 50
    } while ([DateTime]::UtcNow -lt $deadline)
    $caught = $null
    try { Assert-Window $windows[0] $processes[0].Id } catch { $caught = $_ }
    if (!$caught -or !$seen) { throw 'Foreground failure or event was not exercised' }
    $diagnostic = Get-JourneyError $caught
    $message = $diagnostic.message
    if ($message -notmatch 'expected hwnd=\d+ owner=\d+; actual owner=\d+ foreground=\d+ foreground owner=\d+; foreground_class=other foreground_root=\d+ events=(\d+:\d+:\d+:\d+)(,\d+:\d+:\d+:\d+){0,11}$' -or $diagnostic.redacted -or $diagnostic.stack -notmatch 'Assert-Window' -or $diagnostic.stack -notmatch 'foreground\.test\.ps1') { throw 'Foreground diagnostic lost failure, stack, or safe event trail' }
    $serialized = $diagnostic | ConvertTo-Json -Depth 4
    if ($serialized -notmatch 'foreground_class=other' -or $serialized -match 'Account journey foreground probe') { throw 'Foreground diagnostic serialization is unsafe' }

    foreach ($case in @(@(0x71, 'approval', 'MultiPromptDialog'), @(0x72, 'unknown', 'MultiPromptDialog'), @(0x73, 'approval', 'other'), @(0x74, 'sync', 'MultiPromptDialog'), @(0x75, 'account-duplicate', 'MultiPromptDialog'))) {
        Set-JourneyForeground $windows[0] $processes[0].Id
        [ReconnectDesktop]::Type([ushort]$case[0])
        $deadline = [DateTime]::UtcNow.AddSeconds(10)
        do {
            $active = @([JourneyForeground]::ActiveOwnedWindows($windows[0], $processes[0].Id))
            if ($active.Count -eq 1) { break }
            Start-Sleep -Milliseconds 50
        } while ([DateTime]::UtcNow -lt $deadline)
        if ($active.Count -ne 1 -or $active[0].Title -cne $case[1] -or $active[0].Class -cne $case[2] -or [JourneyForeground]::Enabled($windows[0]) -cne 'False') { throw 'Fixture modal identity mismatch' }
        $dialog = $active[0].Handle
        $rejected = $false
        try { Clear-JourneyApproval $windows[0] $processes[1].Id } catch { $rejected = $true }
        if (!$rejected -or ![JourneyForeground]::Exists($dialog)) { throw 'Foreign PID accepted' }
        $rejected = $false
        try { [void][JourneyForeground]::ActiveOwnedWindows($windows[1], $processes[0].Id) } catch { $rejected = $true }
        if (!$rejected) { throw 'Active enumeration accepted a foreign PID' }
        Clear-JourneyApproval $windows[1] $processes[1].Id
        if (![JourneyForeground]::Exists($dialog) -or [JourneyForeground]::Enabled($windows[0]) -cne 'False' -or [JourneyForeground]::Enabled($windows[1]) -cne 'True') { throw 'Foreign owner modal was affected' }
        if ($case[0] -eq 0x71) {
            Clear-JourneyApproval $windows[0] $processes[0].Id
            if ([JourneyForeground]::Exists($dialog) -or [JourneyForeground]::Enabled($windows[0]) -cne 'True') { throw 'Approval cancellation did not restore main' }
        } else {
            $caught = $null
            try { Clear-JourneyApproval $windows[0] $processes[0].Id } catch { $caught = $_ }
            if (!$caught -or $caught.Exception.Message -notmatch '^Unexpected owned window: classification=(unknown|approval|sync|account-duplicate)$' -or ![JourneyForeground]::Exists($dialog)) { throw 'Unexpected modal was not safely rejected' }
            Set-JourneyForeground $dialog $processes[0].Id
            [ReconnectDesktop]::Type(0x1B)
            $deadline = [DateTime]::UtcNow.AddSeconds(10)
            do { if (![JourneyForeground]::Exists($dialog)) { break }; Start-Sleep -Milliseconds 50 } while ([DateTime]::UtcNow -lt $deadline)
            if ([JourneyForeground]::Exists($dialog)) { throw 'Fixture modal cleanup failed' }
        }
    }
    $probeLog = Get-Content -Raw (Join-Path $logs '0.out')
    if (@([regex]::Matches($probeLog, 'modal-cancel')).Count -ne 5 -or $probeLog -match 'modal-approve') { throw 'Fixture observed an approval action or missing cancellation' }

    Add-Type -AssemblyName System.Drawing
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile("$PSScriptRoot/drive.ps1", [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw 'Could not parse account journey driver' }
    $shot = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Shot' }, $false)
    if (!$shot) { throw 'Screenshot function not found' }
    . ([scriptblock]::Create($shot.Extent.Text))
    $Output = $logs
    $script:settled = $false
    function Start-Sleep([int]$Milliseconds) {
        if ($Milliseconds -eq 2000) {
            $script:settled = $true
            Set-JourneyForeground $windows[1] $processes[1].Id
            Assert-Window $windows[1] $processes[1].Id
        } else {
            Microsoft.PowerShell.Utility\Start-Sleep -Milliseconds $Milliseconds
        }
    }
    Set-JourneyForeground $windows[0] $processes[0].Id
    Shot 'settle-race' $windows[0] $processes[0].Id
    if (!$script:settled -or !(Test-Path "$logs/settle-race.png")) { throw 'Screenshot settle race was not exercised' }
    Assert-Window $windows[0] $processes[0].Id
    $capture = Get-Content "$logs/settle-race.json" -Raw | ConvertFrom-Json
    if ($capture.pid -ne $processes[0].Id -or $capture.hwnd -ne $windows[0].ToInt64()) { throw 'Screenshot identity mismatch' }
    Write-Host 'Account journey foreground assertions passed'
} catch {
    $failed = $true
    throw
} finally {
    $cleanupErrors = @()
    foreach ($process in $processes) {
        try {
            if (!$process.HasExited) {
                try { $process.Kill() } catch { if (!$process.HasExited) { throw } }
            }
            if (!$process.WaitForExit(5000)) { throw "Owned foreground probe did not exit (pid=$($process.Id))" }
        } catch {
            $cleanupErrors += $_
        } finally {
            try { $process.Dispose() } catch { $cleanupErrors += $_ }
        }
    }
    $removeError = $null
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        try {
            Remove-Item -Recurse -Force $logs
            $removeError = $null
            break
        } catch {
            $removeError = $_
            Microsoft.PowerShell.Utility\Start-Sleep -Milliseconds 100
        }
    }
    if ($removeError) { $cleanupErrors += $removeError }
    if ($cleanupErrors.Count) {
        foreach ($cleanupError in $cleanupErrors) { Write-Host "Foreground cleanup failure: $cleanupError" }
        if (!$failed) { throw $cleanupErrors[0] }
    }
}
