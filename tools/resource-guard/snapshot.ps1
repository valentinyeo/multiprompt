function Test-GuardReaderCommand([string]$CommandLine) {
    return $CommandLine -cmatch '(?:^|\s)--(?:serve|watch)(?:\s|$)' -or
        $CommandLine -cmatch "(?:^|\s)python3 -u -c 'import base64,sys;exec\(base64\.b64decode\(sys\.stdin\.buffer\.readline\(\)\)\)'\s*$"
}

function Get-StableJobSnapshot {
    param($Job, [int]$AppId, [scriptblock]$Enumerate = { [Diagnostics.Process]::GetProcesses() }, [scriptblock]$EnumerateCim = { Get-CimInstance Win32_Process }, [scriptblock]$EnumerateTcp = { Get-CimInstance -Namespace root/StandardCimv2 -ClassName MSFT_NetTCPConnection -Filter "State = 5" -ErrorAction Stop })
    for ($attempt = 0; $attempt -lt 10; $attempt++) {
        $cimById = @{}
        foreach ($detail in (& $EnumerateCim)) {
            $id = [int]$detail.ProcessId
            if ($cimById.ContainsKey($id)) { $cimById[$id] = $null } else { $cimById[$id] = $detail }
        }
        $before = $Job.ReadAccounting()
        $raw = @()
        foreach ($p in (& $Enumerate)) {
            try {
                if ($Job.Contains($p)) { $raw += @{ id=$p.Id; name=$p.ProcessName; workingSetBytes=$p.WorkingSet64; startTime=$p.StartTime.ToUniversalTime() } }
            } catch {
            } finally { $p.Dispose() }
        }
        $owned = @{}
        foreach ($process in $raw) { $owned[$process.id] = $true }
        $connections = @(& $EnumerateTcp | Where-Object { $owned.ContainsKey([int]$_.OwningProcess) } | ForEach-Object {
            @{ state=$_.State; owningProcess=$_.OwningProcess; localAddress=$_.LocalAddress; localPort=$_.LocalPort; remoteAddress=$_.RemoteAddress; remotePort=$_.RemotePort }
        })
        $after = $Job.ReadAccounting()
        $complete = $true
        $seen = @{}
        foreach ($process in $raw) {
            if ($seen.ContainsKey($process.id)) { $complete = $false; continue }
            $seen[$process.id] = $true
            $detail = $cimById[$process.id]
            if ($null -eq $detail) { $complete = $false; continue }
            if ([string]::IsNullOrWhiteSpace($detail.CommandLine) -or [string]::IsNullOrWhiteSpace($detail.ExecutablePath) -or
                $null -eq $detail.ParentProcessId -or $null -eq $detail.CreationDate -or
                [Math]::Abs(($process.startTime - $detail.CreationDate.ToUniversalTime()).TotalMilliseconds) -ge 1) {
                $complete = $false; continue
            }
            $process.commandLine = $detail.CommandLine
            $process.executablePath = $detail.ExecutablePath
            $process.parentProcessId = $detail.ParentProcessId
            $process.creationTime = $detail.CreationDate.ToUniversalTime()
            $process.Remove('startTime')
        }
        if ($before.TotalProcesses -eq $after.TotalProcesses -and
            $before.TerminatedProcesses -eq $after.TerminatedProcesses -and
            $before.ActiveProcesses -eq $after.ActiveProcesses -and
            $raw.Count -eq $after.ActiveProcesses -and $complete -and
            @($raw | Where-Object { $_.id -eq $AppId }).Count -eq 1) {
            return @{ processes=$raw; connections=$connections; accounting=$after; capturedAt=[DateTime]::UtcNow }
        }
        if ($attempt -lt 9) { Start-Sleep -Milliseconds 100 }
    }
    throw "Unable to obtain complete stable job snapshot after 10 attempts: $($raw.Count) vs $($after.ActiveProcesses)"
}
