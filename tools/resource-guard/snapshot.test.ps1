$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'GitHub Actions only' }
. "$PSScriptRoot/snapshot.ps1"
function Start-Sleep { param([int]$Milliseconds) $script:delays++ }
class FakeProcess {
    [int]$Id
    [string]$ProcessName = 'fake'
    [long]$WorkingSet64 = 42
    [datetime]$StartTime = [datetime]'2025-01-01T00:00:00Z'
    [bool]$Accessible = $true
    [bool]$Member = $true
    [bool]$Disposed = $false
    FakeProcess([int]$id) { $this.Id = $id }
    [void] Dispose() { $this.Disposed = $true }
}
class FakeJob {
    [object[]]$Accounts
    [int]$Reads = 0
    FakeJob([object[]]$accounts) { $this.Accounts = $accounts }
    [object] ReadAccounting() { $value = $this.Accounts[[Math]::Min($this.Reads, $this.Accounts.Count - 1)]; $this.Reads++; return $value }
    [bool] Contains([object]$p) { if (-not $p.Accessible) { throw 'inaccessible' }; return $p.Member }
}
function Account($total, $active, $terminated) { return @{ TotalProcesses=$total; ActiveProcesses=$active; TerminatedProcesses=$terminated } }
function Check($condition, $message) { if (-not $condition) { throw $message } }
function Cim($processes) {
    foreach ($process in $processes) {
        [pscustomobject]@{ ProcessId=$process.Id; ParentProcessId=0; ExecutablePath='C:\fake.exe'; CommandLine='fake'; CreationDate=$process.StartTime }
    }
}
function Expect-Failure($job, $appId, $processes, $cim = $null) {
    if ($null -eq $cim) { $cim = @(Cim $processes) }
    $script:delays = 0
    $failed = $false
    try { Get-StableJobSnapshot -Job $job -AppId $appId -Enumerate { $processes } -EnumerateCim { $cim } | Out-Null } catch { $failed = $_.Exception.Message -match 'complete stable job snapshot' }
    Check $failed 'Expected snapshot failure'
    Check ($job.Reads -eq 20 -and $script:delays -eq 9) 'Retries must be bounded'
}
$script:delays = 0
$app = [FakeProcess]::new(1)
$other = [FakeProcess]::new(2)
$outside = [FakeProcess]::new(3); $outside.Member = $false
$stable = Account 2 2 0
$job = [FakeJob]::new(@($stable, (Account 3 2 1), (Account 3 2 1), (Account 3 2 1)))
$snapshot = Get-StableJobSnapshot -Job $job -AppId 1 -Enumerate { @($app, $other, $outside) } -EnumerateCim { Cim @($app, $other, $outside) }
Check ($job.Reads -eq 4 -and $script:delays -eq 1) 'Birth and death with unchanged count must retry'
Check ($snapshot.processes.Count -eq 2 -and $snapshot.accounting.TotalProcesses -eq 3) 'Stable snapshot must include job members only'
Check ($app.Disposed -and $other.Disposed -and $outside.Disposed) 'Processes must be disposed'
Check ($snapshot.processes[0].commandLine -eq 'fake' -and $snapshot.processes[0].executablePath -eq 'C:\fake.exe' -and $snapshot.processes[0].parentProcessId -eq 0 -and $snapshot.processes[0].creationTime -eq $app.StartTime.ToUniversalTime()) 'Joined provenance must be retained'
$script:cimReads = 0; $script:delays = 0
$job = [FakeJob]::new(@($stable))
$snapshot = Get-StableJobSnapshot -Job $job -AppId 1 -Enumerate { @($app, $other) } -EnumerateCim {
    $script:cimReads++
    if ($script:cimReads -eq 1) { Cim @($app) } else { Cim @($app, $other) }
}
Check ($job.Reads -eq 4 -and $script:delays -eq 1 -and $snapshot.processes.Count -eq 2) 'Missing CIM member must retry'
Expect-Failure ([FakeJob]::new(@($stable))) 1 @($app, $other) @(Cim @($app))
$reused = @(Cim @($app, $other)); $reused[1].CreationDate = $reused[1].CreationDate.AddSeconds(1)
Expect-Failure ([FakeJob]::new(@($stable))) 1 @($app, $other) $reused
$incomplete = @(Cim @($app, $other)); $incomplete[1].CommandLine = ''
Expect-Failure ([FakeJob]::new(@($stable))) 1 @($app, $other) $incomplete
Expect-Failure ([FakeJob]::new(@($stable))) 1 @($app)
$other.Accessible = $false
Expect-Failure ([FakeJob]::new(@($stable))) 1 @($app, $other)
$other.Accessible = $true
Expect-Failure ([FakeJob]::new(@($stable))) 99 @($app, $other)
$accounts = @(1..20 | ForEach-Object { Account $_ 2 $_ })
Expect-Failure ([FakeJob]::new($accounts)) 1 @($app, $other)
