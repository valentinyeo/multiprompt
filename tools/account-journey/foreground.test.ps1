$ErrorActionPreference = 'Stop'
Add-Type -Path "$PSScriptRoot/../verify-reconnect/desktop.cs"
[ReconnectDesktop]::StartSpy()
. "$PSScriptRoot/foreground.ps1"
. "$PSScriptRoot/diagnostics.ps1"
$source = @'
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public static class FixtureControls {
    [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern IntPtr CreateWindowEx(int ex, string cls, string text, uint style, int x, int y, int w, int h, IntPtr parent, IntPtr menu, IntPtr instance, IntPtr param);
    [DllImport("user32.dll")] public static extern IntPtr SetFocus(IntPtr h);
}
public class FixtureForm : Form {
    protected override bool IsInputKey(Keys keyData) {
        return (keyData & Keys.KeyCode) == Keys.Enter || base.IsInputKey(keyData);
    }
}
"@ -ReferencedAssemblies System.Windows.Forms, System.Drawing
$form = [FixtureForm]::new()
$form.Text = 'Account journey foreground probe'
$form.KeyPreview = $true
$form.Add_KeyDown({
    if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        [void][FixtureControls]::SetFocus($script:enabledEdit)
        $_.Handled = $true
    }
})
$form.Add_Shown({
    foreach ($item in @(@('Edit', 0x50000000), @('Edit', 0x58000000), @('Edit', 0x40000000), @('Button', 0x50000000))) {
        $h = [FixtureControls]::CreateWindowEx(0, $item[0], 'private fixture text', [uint32]$item[1], 0, 0, 60, 20, $form.Handle, [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero)
        if ($h -eq [IntPtr]::Zero) { throw 'Cannot create fixture control' }
        if ($item[0] -eq 'Edit' -and $item[1] -eq 0x50000000) { $script:enabledEdit = $h }
    }
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
        $processes += Start-Process powershell.exe -ArgumentList '-NoProfile', '-STA', '-EncodedCommand', $encoded -PassThru -RedirectStandardError (Join-Path $logs "$index.err")
    }
    $windows = @()
    foreach ($index in 0, 1) {
        $process = $processes[$index]
        $deadline = [DateTime]::UtcNow.AddSeconds(20)
        $window = [IntPtr]::Zero
        do {
            $process.Refresh()
            if ($process.HasExited) { break }
            $candidate = $process.MainWindowHandle
            if ($candidate -ne [IntPtr]::Zero -and [ReconnectDesktop]::IsWindowVisible($candidate) -and [ReconnectDesktop]::Class($candidate) -like 'WindowsForms10.*') { $window = $candidate; break }
            Start-Sleep -Milliseconds 100
        } while ([DateTime]::UtcNow -lt $deadline)
        if ($window -eq [IntPtr]::Zero) {
            $detail = try { Get-Content -Raw (Join-Path $logs "$index.err") } catch { "stderr unavailable: $($_.Exception.Message)" }
            throw "Foreground probe window did not appear (pid=$($process.Id), exited=$($process.HasExited)): $detail"
        }
        $windows += $window
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
