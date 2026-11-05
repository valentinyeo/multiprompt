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
Write-Host 'Account journey diagnostics assertions passed'
