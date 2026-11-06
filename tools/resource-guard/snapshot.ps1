function Get-StableJobSnapshot {
    param($Job, [int]$AppId, [scriptblock]$Enumerate = { [Diagnostics.Process]::GetProcesses() })
    for ($attempt = 0; $attempt -lt 10; $attempt++) {
        $before = $Job.ReadAccounting()
        $raw = @()
        foreach ($p in (& $Enumerate)) {
            try {
                if ($Job.Contains($p)) { $raw += @{ id=$p.Id; name=$p.ProcessName; workingSetBytes=$p.WorkingSet64 } }
            } catch {
            } finally { $p.Dispose() }
        }
        $after = $Job.ReadAccounting()
        if ($before.TotalProcesses -eq $after.TotalProcesses -and
            $before.TerminatedProcesses -eq $after.TerminatedProcesses -and
            $before.ActiveProcesses -eq $after.ActiveProcesses -and
            $raw.Count -eq $after.ActiveProcesses -and
            @($raw | Where-Object { $_.id -eq $AppId }).Count -eq 1) {
            return @{ processes=$raw; accounting=$after }
        }
        if ($attempt -lt 9) { Start-Sleep -Milliseconds 100 }
    }
    throw "Unable to obtain complete stable job snapshot after 10 attempts: $($raw.Count) vs $($after.ActiveProcesses)"
}
