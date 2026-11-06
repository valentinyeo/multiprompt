function Get-SafePaletteRecords([string]$Text) {
    [regex]::Matches($Text, '(?m)^(?:[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3} )?(\[palette\] (?:ready chars=[0-9]{1,3} count=[0-9]{1,4} target=[0-9]{1,5}|confirm target=[0-9]{1,5}))\r?$') | ForEach-Object { $_.Groups[1].Value }
}

function Get-SafeFocusRecords([string]$Text) {
    $pattern = '(?m)^\[focus-trace\] (?:(?<timestamp>[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}) )?event=(?:allowed|blocked|activation_refocus|setfocus_null_return|setfocus_returned) caller=exe\+0x[0-9A-F]{1,16} target=0x[0-9A-F]{1,16} class="(?:Edit|ZigShell|ConsoleWindowClass)" pid=(?<pid>[0-9]{1,10}) ours=(?:true|false) focus=0x[0-9A-F]{1,16} foreground=0x[0-9A-F]{1,16} foreground_class="(?:Edit|ZigShell|ConsoleWindowClass)"(?: repeats=(?<repeats>[0-9]{1,10}))?\r?$'
    foreach ($match in [regex]::Matches($Text, $pattern)) {
        $number = [uint32]0
        $date = [datetime]::MinValue
        if (![uint32]::TryParse($match.Groups['pid'].Value, [ref]$number)) { continue }
        if ($match.Groups['repeats'].Success -and ![uint32]::TryParse($match.Groups['repeats'].Value, [ref]$number)) { continue }
        if ($match.Groups['timestamp'].Success -and ![datetime]::TryParseExact($match.Groups['timestamp'].Value, 'yyyy-MM-dd HH:mm:ss.fff', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$date)) { continue }
        $match.Value.TrimEnd("`r")
    }
}

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
        original_script_stack = $Record.Exception.Data['original_script_stack']
        inner_exception_stack = if ($Record.Exception.InnerException) { $Record.Exception.InnerException.StackTrace } else { $null }
    }
}
