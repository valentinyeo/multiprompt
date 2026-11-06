$caught = $null
try {
    & { throw [InvalidOperationException]::new('native baseline probe') }
} catch {
    $caught = $_
}
$diagnostic = Get-JourneyError $caught
if ($diagnostic.message -cne 'native baseline probe' -or $diagnostic.type -cne 'System.InvalidOperationException' -or $diagnostic.stack -notmatch 'diagnostics\.test\.ps1') { throw 'Journey error diagnostic lost the original exception' }
$secrets = @{ admin_key = 'synthetic-secret' }
try { throw 'synthetic-secret' } catch { $private = Get-JourneyError $_ }
if (!$private.redacted -or $private.message -match 'synthetic-secret') { throw 'Journey error diagnostic exposed a credential' }
try {
    throw $caught
} catch {
    if ($_.Exception.Message -cne $diagnostic.message -or $_.Exception.GetType().FullName -cne $diagnostic.type -or $_.ScriptStackTrace -notmatch 'diagnostics\.test\.ps1') { throw 'Journey rethrow lost the original exception' }
}
$lines = @(
    'secret synthetic-secret [palette] confirm target=7000'
    '2026-10-18 03:04:05.067 [palette] ready chars=16 count=1 target=7000'
    '[palette] confirm target=7000'
    '[palette] ready chars=0 count=9999 target=99999'
    '[palette] confirm target=3'
    '[palette] confirm target=7000 synthetic-secret'
    '[palette] confirm target=123456'
    '[palette] ready chars=1000 count=1 target=1'
    '[palette] ready chars=1 count=10000 target=1'
    '[palette] ready chars=1 count=1 target=100000'
    'prefix [palette] ready chars=1 count=1 target=1'
    "[palette] confirm target=7000`rsecret"
    '[palette] confirm target=7 workspace=private-name'
    '[palette] confirm target=１２'
)
$actual = @(Get-SafePaletteRecords ($lines -join "`r`n"))
$expected = @('[palette] ready chars=16 count=1 target=7000', '[palette] confirm target=7000', '[palette] ready chars=0 count=9999 target=99999', '[palette] confirm target=3')
if (($actual -join "`n") -cne ($expected -join "`n")) { throw 'Palette sanitizer accepted unsafe records or changed ordering' }
$focusBase = '[focus-trace] event=allowed caller=exe+0x123 target=0x456 class="Edit" pid=42 ours=true focus=0x789 foreground=0x456 foreground_class="ZigShell"'
$focusTimed = '[focus-trace] 2026-10-18 03:04:05.067 event=blocked caller=exe+0x0 target=0xFFFFFFFFFFFFFFFF class="ConsoleWindowClass" pid=4294967295 ours=false focus=0x0 foreground=0x1 foreground_class="Edit" repeats=4294967295'
$focusRefocus = $focusBase.Replace('event=allowed', 'event=activation_refocus') + ' repeats=0'
$focusNullReturn = $focusBase.Replace('event=allowed', 'event=setfocus_null_return')
$focusReturned = $focusBase.Replace('event=allowed', 'event=setfocus_returned')
$focusLines = @(
    $focusBase
    $focusTimed
    $focusRefocus
    $focusNullReturn
    $focusReturned
    $focusNullReturn.Replace('event=setfocus_null_return', 'event=prefix_setfocus_null_return')
    $focusNullReturn.Replace('event=setfocus_null_return', 'event=setfocus_null_return_suffix')
    $focusReturned.Replace('event=setfocus_returned', 'event=prefix_setfocus_returned')
    $focusReturned.Replace('event=setfocus_returned', 'event=setfocus_returned_suffix')
    $focusBase.Replace('event=allowed', 'event=setfocus_unknown')
    "synthetic-secret $focusBase"
    "$focusBase synthetic-secret"
    "$focusBase`rsynthetic-secret"
    $focusBase.Replace('class="Edit"', 'class="synthetic-secret"')
    $focusBase.Replace('foreground_class="ZigShell"', 'foreground_class="synthetic-secret"')
    $focusBase.Replace('event=allowed', 'event=composer_killfocus')
    $focusBase.Replace('pid=42', 'pid=4294967296')
    ($focusBase + ' repeats=4294967296')
    $focusBase.Replace('target=0x456', 'target=0x10000000000000000')
    $focusBase.Replace('focus=0x789', 'focus=0xabc')
    $focusBase.Replace('ours=true', 'ours=TRUE')
    $focusTimed.Replace('2026-10-18', '2026-13-18')
    $focusTimed.Replace('03:04:05.067', '24:04:05.067')
    $focusBase.Replace('pid=42', 'pid=-1')
    $focusBase.Replace('pid=42', 'pid=１２')
)
$focusActual = @(Get-SafeFocusRecords ($focusLines -join "`r`n"))
$focusExpected = @($focusBase, $focusTimed, $focusRefocus, $focusNullReturn, $focusReturned)
if (($focusActual -join "`n") -cne ($focusExpected -join "`n")) { throw 'Focus sanitizer accepted unsafe records or changed ordering' }
Write-Host 'Account journey diagnostics assertions passed'
