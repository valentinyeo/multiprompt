$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
public static class ReconnectDesktop {
    public static List<string> Keys = new List<string>();
    public static bool FailKey;
    public static void Key(ushort key, bool up) {
        Keys.Add(key + ":" + up);
        if (FailKey && key != 0x12) throw new Exception("Synthetic input failure");
    }
    public static long[] Focus(IntPtr window) { return new long[] { 100, 100 }; }
}
'@
function Set-JourneyForeground([IntPtr]$Window, [int]$ProcessId) { Assert-Window $Window $ProcessId }
function Assert-Window([IntPtr]$Window, [int]$ProcessId) {
    if ($Window -ne [IntPtr]100 -or $ProcessId -ne 42) { throw 'Wrong window' }
}
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path (Get-Location) 'tools/account-journey/drive.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Could not parse drive.ps1' }
$function = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Show-Workspace' }, $true)
if ($function.Count -ne 1) { throw 'Show-Workspace not found' }
. ([scriptblock]::Create($function[0].Extent.Text))
. (Join-Path (Get-Location) 'tools/account-journey/diagnostics.ps1')
$secrets = @{ admin_key = 'synthetic-secret' }
$session = Join-Path ([IO.Path]::GetTempPath()) ('workspace-' + [Guid]::NewGuid().ToString() + '.json')
$script:mode = 'delayed'
$script:attempts = 0
function Wait-For([string]$Description, [scriptblock]$Check, [int]$Seconds) {
    for ($attempt = 0; $attempt -lt 3; $attempt++) {
        $script:attempts++
        $state = [ordered]@{ workspaces = @(@{ name = 'Work' }, @{ name = 'synthetic-secret' }); active_workspace = 1; starred_view = $false }
        switch ($script:mode) {
            'delayed' {
                if ($attempt -eq 0) { $state.active_workspace = 0 }
                if ($attempt -eq 1) { $state.starred_view = $true }
            }
            'wrong-slot' { $state.active_workspace = 0 }
            'starred' { $state.starred_view = $true }
            'wrong-name' { $state.workspaces[1].name = 'private-name' }
            'missing-active' { $state.Remove('active_workspace'); $state.workspaces = @(@{ name = 'synthetic-secret' }) }
        }
        $state | ConvertTo-Json -Depth 4 | Set-Content $session
        if ($script:mode -eq 'unreadable') { Set-Content $session '{' }
        $value = & $Check
        if ($value) { return $value }
    }
    throw "Timed out: $Description"
}
try {
    foreach ($mode in @('delayed', 'wrong-slot', 'starred', 'wrong-name', 'missing-active', 'unreadable', 'input-failure')) {
        $script:mode = $mode
        $script:attempts = 0
        [ReconnectDesktop]::Keys.Clear()
        [ReconnectDesktop]::FailKey = $mode -eq 'input-failure'
        $initial = @{ workspaces = @(@{ name = 'Work' }, @{ name = 'synthetic-secret' }); active_workspace = 0 }
        if ($mode -eq 'missing-active') { $initial.workspaces = @(@{ name = 'synthetic-secret' }) }
        $initial | ConvertTo-Json -Depth 4 | Set-Content $session
        $caught = $null
        try { Show-Workspace 'synthetic-secret' ([IntPtr]100) 42 $session } catch { $caught = $_ }
        $digit = if ($mode -eq 'missing-active') { 50 } else { 51 }
        if ($mode -eq 'input-failure') {
            if (!$caught -or $caught.Exception.InnerException.Message -cne 'Synthetic input failure' -or [ReconnectDesktop]::Keys[-1] -cne '18:True') { throw 'Input failure lost its cause or left Alt held' }
            continue
        }
        if (([ReconnectDesktop]::Keys -join ',') -cne "18:False,${digit}:False,${digit}:True,18:True") { throw 'Wrong workspace shortcut or missing key release' }
        if ($mode -eq 'delayed') {
            if ($caught -or $script:attempts -ne 3) { throw 'Selection accepted stale workspace or Starred state' }
            continue
        }
        if (!$caught) { throw "Selection accepted $mode state" }
        $diagnostic = Get-JourneyError $caught
        if ($diagnostic.redacted -or $diagnostic.message -notmatch '^Timed out: selected workspace session; expected_window=100 expected_pid=42 expected_slot=[01] foreground=100 focus=100 session_readable=(True|False) active_slot=-?[01] starred=(True|False) expected_name_match=(True|False)$' -or
            $diagnostic.message -match 'synthetic-secret|private-name' -or !$caught.Exception.InnerException -or
            $caught.Exception.InnerException.Message -cne 'Timed out: selected workspace session' -or $diagnostic.original_script_stack -notmatch 'Wait-For') { throw 'Unsafe or incomplete workspace timeout diagnostic' }
        if ($mode -eq 'missing-active' -and $diagnostic.message -notmatch 'active_slot=-1 ') { throw 'Missing selection became slot zero' }
        if ($mode -eq 'unreadable' -and $diagnostic.message -notmatch 'session_readable=False active_slot=-1 ') { throw 'Unreadable selection retained stale state' }
    }
    Write-Output 'Workspace selection and timeout diagnostics passed'
} finally {
    Remove-Item $session -ErrorAction SilentlyContinue
}
