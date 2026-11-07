$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'GitHub Actions only' }
. "$PSScriptRoot/snapshot.ps1"
class TcpTestJob {
    [int]$Reads = 0
    [int]$OwnerPid
    [bool]$Churn = $false
    TcpTestJob([int]$ownerPid) { $this.OwnerPid = $ownerPid }
    [object] ReadAccounting() {
        $this.Reads++
        return @{ TotalProcesses=$(if ($this.Churn) { $this.Reads } else { 1 }); ActiveProcesses=1; TerminatedProcesses=0 }
    }
    [bool] Contains([object]$process) { return $process.Id -eq $this.OwnerPid }
}
function Check($condition, $message) { if (-not $condition) { throw $message } }
function Snapshot($job, $tcp) {
    $currentId = $PID
    Get-StableJobSnapshot -Job $job -AppId $currentId -Enumerate { [Diagnostics.Process]::GetProcessById($currentId) } -EnumerateTcp $tcp
}
$job = [TcpTestJob]::new($PID)
$empty = Snapshot $job { Check ($job.Reads -eq 1) 'TCP enumeration must follow the first accounting read'; @() }
Check ($job.Reads -eq 2) 'TCP enumeration must precede the second accounting read'
Check ($empty.connections.Count -eq 0) 'Empty TCP enumeration must succeed'
$failed = $false
try { Snapshot $job { throw 'TCP collection failed' } | Out-Null } catch { $failed = $_.Exception.Message -match 'TCP collection failed' }
Check $failed 'TCP collection errors must propagate'
$foreign = Snapshot $job { [pscustomobject]@{ OwningProcess=0; LocalAddress='127.0.0.1'; LocalPort=1; RemoteAddress='127.0.0.1'; RemotePort=2 } }
Check ($foreign.connections.Count -eq 0) 'Foreign TCP rows must not be attributed to the job'
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$clients = @(); $accepted = @()
try {
    $listener.Start()
    $endpoint = $listener.LocalEndpoint
    $client = [Net.Sockets.TcpClient]::new()
    $client.Connect($endpoint.Address, $endpoint.Port)
    $clients += $client; $accepted += $listener.AcceptTcpClient()
    $first = Snapshot ([TcpTestJob]::new($PID)) { Get-CimInstance -Namespace root/StandardCimv2 -ClassName MSFT_NetTCPConnection -Filter 'State = 5' -ErrorAction Stop }
    $firstRows = @($first.connections | Where-Object { $_.localPort -eq $endpoint.Port -or $_.remotePort -eq $endpoint.Port })
    Check ($firstRows.Count -eq 2 -and @($firstRows | Where-Object { $_.owningProcess -eq $PID }).Count -eq 2) 'Real loopback socket must produce two owned established rows'
    $client = [Net.Sockets.TcpClient]::new()
    $client.Connect($endpoint.Address, $endpoint.Port)
    $clients += $client; $accepted += $listener.AcceptTcpClient()
    $second = Snapshot ([TcpTestJob]::new($PID)) { Get-CimInstance -Namespace root/StandardCimv2 -ClassName MSFT_NetTCPConnection -Filter 'State = 5' -ErrorAction Stop }
    $secondRows = @($second.connections | Where-Object { $_.localPort -eq $endpoint.Port -or $_.remotePort -eq $endpoint.Port })
    Check ($secondRows.Count -eq 4 -and $second.connections.Count -ge ($first.connections.Count + 2)) 'Extra socket must increase the established count'
} finally {
    foreach ($socket in $clients + $accepted) { $socket.Dispose() }
    $listener.Stop()
}
$churn = [TcpTestJob]::new($PID); $churn.Churn = $true
$failed = $false
try { Snapshot $churn { @() } | Out-Null } catch { $failed = $_.Exception.Message -match 'complete stable job snapshot' }
Check ($failed -and $churn.Reads -eq 20) 'Membership churn across TCP enumeration must fail closed'
