function Get-JourneyError([System.Management.Automation.ErrorRecord]$Record) {
    $message = $Record.Exception.Message
    $unsafe = $message -match '(?i)(bearer\s|refresh.token|access.token|admin.key|workspace.key|pfxpass|[\r\n{}])'
    foreach ($value in @($secrets.refresh_token, $secrets.second_refresh_token, $secrets.admin_key, $secrets.workspace_key, $secrets.other_key, $tokenB.access_token, $tokenB.refresh_token)) {
        if ($value -and $message.Contains([string]$value)) { $unsafe = $true }
    }
    [ordered]@{
        message = if ($unsafe) { '[redacted: potentially sensitive exception]' } else { $message }
        redacted = [bool]$unsafe
        type = $Record.Exception.GetType().FullName
        stack = $Record.ScriptStackTrace
        exception_stack = $Record.Exception.StackTrace
    }
}
