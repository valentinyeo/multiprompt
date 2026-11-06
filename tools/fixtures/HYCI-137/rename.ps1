$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
public static class ReconnectDesktop {
    public static bool Opened, Ready, Typed, Selected, Entered;
    public static string Mode = "happy";
    public static int FocusReads, Cursor = -1;
    public class FocusEvent { public uint ev; public long hwnd; public uint pid; public long root; public string cls = "synthetic-secret-event"; }
    public static int EventCount() {
        if (Mode == "spy-count-error") throw new Exception("synthetic-secret-spy-count");
        return Entered ? 99 : 3;
    }
    public static FocusEvent[] EventsSince(int start) {
        Cursor = start;
        if (Mode == "spy-events-error") throw new Exception("synthetic-secret-spy-events");
        var events = new FocusEvent[15];
        for (int i = 0; i < events.Length; i++) events[i] = new FocusEvent { ev = (uint)(i + 1), hwnd = 200 + i, pid = 42, root = 100 };
        return events;
    }
    public static void Key(ushort key, bool up) { }
    public static void Type(ushort key) {
        if (key == 0x4B) Opened = true;
        if (key == 0x0D) {
            if (!Selected) throw new Exception("Entered before rename selection was ready");
            Entered = true;
        }
    }
    public static long[] Focus(IntPtr window) {
        if (!Entered) return new long[] { 100, 100 };
        FocusReads++;
        return new long[] { 100, Mode == "wrong" || Mode == "happy" || (Mode == "transient" && FocusReads == 1) ? 200 : 0 };
    }
    public static IntPtr Composer(IntPtr window) {
        if (Mode == "probe-error") throw new Exception("synthetic-secret-probe-error");
        return Mode.StartsWith("missing") ? IntPtr.Zero : new IntPtr(200);
    }
    public static int Owner(IntPtr window) { return Mode == "wrong-owner" ? 43 : 42; }
    public static IntPtr GetAncestor(IntPtr window, int flags) { return new IntPtr(Mode == "wrong-root" ? 101 : 100); }
    public static string Class(IntPtr window) { return "Edit"; }
    public static string Text(IntPtr window) { return Mode == "snapshot-new" && window == new IntPtr(201) ? "private-expected-name" : Mode == "wrong" || Mode == "wrong-name" ? "synthetic-secret-wrong-name" : "Runners"; }
}
public static class JourneyForeground {
    public static uint ThreadId(IntPtr window) {
        if (ReconnectDesktop.Mode == "thread-error") throw new Exception("synthetic-secret-thread");
        return window == new IntPtr(100) ? 10u : 20u;
    }
    public static uint ForegroundThreadId() {
        if (ReconnectDesktop.Mode == "thread-error") throw new Exception("synthetic-secret-foreground");
        return 30;
    }
    public static string Enabled(IntPtr window) {
        if (ReconnectDesktop.Mode == "thread-error") throw new Exception("synthetic-secret-enabled");
        return window == new IntPtr(201) ? "False" : "True";
    }
    public static string ThreadFocus(uint thread) {
        if (ReconnectDesktop.Mode == "thread-error") throw new Exception("synthetic-secret-focus");
        return thread == 20 ? "201" : thread == 30 ? "100" : "unavailable";
    }
    public static IntPtr[] VisibleEdits(IntPtr window, int pid) {
        string mode = ReconnectDesktop.Mode;
        if (mode == "snapshot-error" || (mode == "baseline-error" && !ReconnectDesktop.Entered) || (mode == "timeout-error" && ReconnectDesktop.Entered)) throw new Exception("synthetic-secret-snapshot");
        if (mode == "snapshot-missing") return new IntPtr[0];
        if (mode == "snapshot-many") {
            var result = new IntPtr[14];
            for (int i = 0; i < result.Length; i++) result[i] = new IntPtr(200 + i);
            return result;
        }
        if (mode == "snapshot-new" || mode == "baseline-error") return ReconnectDesktop.Entered ? new IntPtr[] { new IntPtr(200), new IntPtr(201) } : new IntPtr[] { new IntPtr(200) };
        return new IntPtr[] { new IntPtr(200) };
    }
}
'@
$script:trace = "[palette] ready chars=0 count=1 target=1`n[palette] ready chars=16 count=1 target=7000`n"
$script:reads = 0
$app = [pscustomobject]@{ Id = 42 }
$appB = $null
$log = 'fixture'
function Read-Log([string]$LogPath) {
    if ([ReconnectDesktop]::Opened) {
        $script:reads++
        if (![ReconnectDesktop]::Typed -and $script:reads -eq 2) {
            [ReconnectDesktop]::Ready = $true
            $script:trace += "[palette] ready chars=0 count=2 target=1`n"
        }
        if ([ReconnectDesktop]::Typed -and $script:reads -eq 4) {
            [ReconnectDesktop]::Selected = $true
            $script:trace += "[palette] ready chars=16 count=1 target=7000`n"
        }
    }
    if ([ReconnectDesktop]::Entered -and [ReconnectDesktop]::Mode -ne 'missing-unconfirmed') {
        $script:trace += "2026-10-18 03:04:05.067 [palette] confirm target=7000`n"
    }
    return $script:trace
}
function Wait-For([string]$Description, [scriptblock]$Check, [int]$Seconds) {
    for ($attempt = 0; $attempt -lt 8; $attempt++) {
        $value = & $Check
        if ($value) { return $value }
    }
    throw "Timed out: $Description"
}
function Set-JourneyForeground([IntPtr]$Window, [int]$ProcessId) { }
function Assert-Window([IntPtr]$Window, [int]$ProcessId) {
    if ($Window -ne [IntPtr]100 -or $ProcessId -ne 42) { throw 'Wrong window' }
}
function Assert-Focus([IntPtr]$Window, [int]$ProcessId, [IntPtr]$Expected) {
    Assert-Window $Window $ProcessId
    if ([ReconnectDesktop]::Focus($Window)[1] -ne $Expected.ToInt64()) { throw 'Wrong focus' }
}
function Type-Ascii([string]$Value, [IntPtr]$Window, [int]$ProcessId, [IntPtr]$Expected) {
    Assert-Focus $Window $ProcessId $Expected
    if (![ReconnectDesktop]::Ready) { throw 'Typed before fresh palette readiness' }
    if ($Value -cne 'rename workspace') { throw 'Wrong search query' }
    [ReconnectDesktop]::Typed = $true
    $script:trace += "[palette] ready chars=16 count=1 target=42`n"
}
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path (Get-Location) 'tools/account-journey/drive.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Could not parse drive.ps1' }
$function = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Open-Rename' }, $true)
if ($function.Count -ne 1) { throw 'Open-Rename not found' }
. ([scriptblock]::Create($function[0].Extent.Text))
$edit = Open-Rename ([IntPtr]100) 42 'Runners'
if ($edit -ne [IntPtr]200 -or ![ReconnectDesktop]::Entered -or ![ReconnectDesktop]::Selected) { throw 'Rename did not return the owned edit' }
. (Join-Path (Get-Location) 'tools/account-journey/diagnostics.ps1')
$secrets = @{ admin_key = 'synthetic-secret' }
foreach ($mode in @('wrong', 'unfocused', 'wrong-name', 'missing-confirmed', 'missing-unconfirmed', 'wrong-owner', 'wrong-root', 'probe-error', 'transient', 'spy-count-error', 'spy-events-error', 'snapshot-new', 'snapshot-missing', 'snapshot-many', 'snapshot-error', 'baseline-error', 'timeout-error', 'thread-error')) {
    $script:trace = "[palette] confirm target=7000`n"
    [ReconnectDesktop]::Opened = $false
    [ReconnectDesktop]::Ready = $false
    [ReconnectDesktop]::Typed = $false
    [ReconnectDesktop]::Selected = $false
    [ReconnectDesktop]::Entered = $false
    [ReconnectDesktop]::Mode = $mode
    [ReconnectDesktop]::FocusReads = 0
    [ReconnectDesktop]::Cursor = -1
    $script:reads = 0
    $caught = $null
    $expected = if ($mode -eq 'unfocused') { 'Runners' } else { 'private-expected-name' }
    try { Open-Rename ([IntPtr]100) 42 $expected | Out-Null } catch { $caught = $_ }
    if (!$caught) { throw 'Expected rename timeout' }
    $diagnostic = Get-JourneyError $caught
    $message = $diagnostic.message
    $exists = $mode -notin @('missing-confirmed', 'missing-unconfirmed', 'wrong-owner', 'wrong-root', 'probe-error')
    $focused = $mode -eq 'wrong'
    $nameMatch = $mode -eq 'unfocused'
    $hwnd = if ($exists) { 200 } else { 0 }
    $probeFailed = $mode -eq 'probe-error'
    if ($message -notmatch '^Timed out: workspace rename edit; expected_window=100 expected_pid=42 foreground=100 ' -or
        $message -notmatch "expected_name_match=False confirm_target_7000=$($mode -ne 'missing-unconfirmed') owned_edit_exists=$exists owned_edit_focused=$focused owned_edit_expected_name_match=$nameMatch owned_edit_hwnd=$hwnd owned_edit_probe_failed=$probeFailed " -or
        $message -match 'synthetic-secret|wrong-name|private-expected-name' -or
        !$caught.Exception.InnerException -or $caught.Exception.InnerException.Message -cne 'Timed out: workspace rename edit' -or
        $diagnostic.original_script_stack -notmatch 'Wait-For') { throw 'Unsafe or incomplete rename timeout diagnostic' }
    $sawEdit = $mode -in @('wrong', 'transient')
    $eventTrail = if ($mode -in @('spy-count-error', 'spy-events-error')) { 'unavailable' } else { ((3..14 | ForEach-Object { "$(1 + $_):$(200 + $_):42:100" }) -join ',') }
    if (!$message.EndsWith("saw_focused_owned_edit=$sawEdit events=$eventTrail")) { throw 'Incorrect rename history diagnostic' }
    if ([ReconnectDesktop]::Cursor -ne $(if ($mode -eq 'spy-count-error') { -1 } else { 3 })) { throw 'Incorrect pre-Enter event cursor' }
    $snapshot = switch ($mode) {
        'snapshot-new' { 'before_edits=[count=1,truncated=False,entries=200:False] timeout_edits=[count=2,truncated=False,entries=200:True:False,201:False:True]' }
        'snapshot-missing' { 'before_edits=[count=0,truncated=False,entries=] timeout_edits=[count=0,truncated=False,entries=]' }
        'snapshot-many' { $before = (200..211 | ForEach-Object { "${_}:False" }) -join ','; $after = (200..211 | ForEach-Object { "${_}:True:False" }) -join ','; "before_edits=[count=14,truncated=True,entries=$before] timeout_edits=[count=14,truncated=True,entries=$after]" }
        'snapshot-error' { 'before_edits=[unavailable] timeout_edits=[unavailable]' }
        'baseline-error' { 'before_edits=[unavailable] timeout_edits=[count=2,truncated=False,entries=200:unavailable:False,201:unavailable:False]' }
        'timeout-error' { 'before_edits=[count=1,truncated=False,entries=200:False] timeout_edits=[unavailable]' }
        'unfocused' { 'before_edits=[count=1,truncated=False,entries=200:True] timeout_edits=[count=1,truncated=False,entries=200:True:True]' }
        default { $null }
    }
    if ($snapshot -and !$message.Contains($snapshot)) { throw "Incorrect sanitized snapshot for $mode" }
    $threads = switch ($mode) {
        'snapshot-error' { 'unavailable' }
        'timeout-error' { 'unavailable' }
        'snapshot-missing' { 'main_thread=10,foreground_thread=30,foreground_focus=100,entries=' }
        'snapshot-new' { 'main_thread=10,foreground_thread=30,foreground_focus=100,entries=200:20:True:201,201:20:False:201' }
        'baseline-error' { 'main_thread=10,foreground_thread=30,foreground_focus=100,entries=200:20:True:201,201:20:False:201' }
        'snapshot-many' { $entries = (200..211 | ForEach-Object { if ($_ -eq 201) { "${_}:20:False:201" } else { "${_}:20:True:201" } }) -join ','; "main_thread=10,foreground_thread=30,foreground_focus=100,entries=$entries" }
        'thread-error' { 'main_thread=unavailable,foreground_thread=unavailable,foreground_focus=unavailable,entries=200:unavailable:unavailable:unavailable' }
        default { 'main_thread=10,foreground_thread=30,foreground_focus=100,entries=200:20:True:201' }
    }
    if (!$message.Contains("thread_edits=[$threads]")) { throw "Incorrect thread diagnostic for $mode" }
    if ($mode -eq 'wrong' -and $message -notmatch 'focus=200 owner=42 root=100 edit_class=True ') { throw 'Wrong-name edit not identified' }
    if ($mode -like 'missing-*' -and $message -notmatch 'focus=0 owner=0 root=0 edit_class=False ') { throw 'Missing edit not identified' }
}
Write-Output 'Delayed palette and rename timeout diagnostics passed'
