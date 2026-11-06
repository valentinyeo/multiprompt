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

function Get-SafeNativeFocusRecords([string]$Text) {
    $pattern = '\A(?:(?<timestamp>[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}) )?\[focus-native\] result_null=[01] last_error=(?<last_error>[0-9]{1,10}) caller_thread=(?<caller_thread>[0-9]{1,10}) target_thread=(?<target_thread>[0-9]{1,10}) target=0x[0-9A-F]{1,16} focus=0x[0-9A-F]{1,16}\z'
    foreach ($line in ($Text -split "`n")) {
        if ($line.EndsWith("`r")) { $line = $line.Substring(0, $line.Length - 1) }
        $match = [regex]::Match($line, $pattern)
        if (!$match.Success) { continue }
        $number = [uint32]0
        $valid = $true
        foreach ($field in @('last_error', 'caller_thread', 'target_thread')) {
            if (![uint32]::TryParse($match.Groups[$field].Value, [ref]$number)) { $valid = $false; break }
        }
        if (!$valid) { continue }
        $date = [datetime]::MinValue
        if ($match.Groups['timestamp'].Success -and ![datetime]::TryParseExact($match.Groups['timestamp'].Value, 'yyyy-MM-dd HH:mm:ss.fff', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$date)) { continue }
        $match.Value
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
