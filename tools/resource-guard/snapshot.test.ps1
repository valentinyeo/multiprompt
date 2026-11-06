$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'GitHub Actions only' }
. "$PSScriptRoot/snapshot.ps1"
function Start-Sleep { param([int]$Milliseconds) $script:delays++ }
class FakeProcess {
    [int]$Id
    [string]$ProcessName = 'fake'
    [long]$WorkingSet64 = 42
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
function Expect-Failure($job, $appId, $processes) {
    $script:delays = 0
    $failed = $false
    try { Get-StableJobSnapshot -Job $job -AppId $appId -Enumerate { $processes } | Out-Null } catch { $failed = $_.Exception.Message -match 'complete stable job snapshot' }
    Check $failed 'Expected snapshot failure'
    Check ($job.Reads -eq 20 -and $script:delays -eq 9) 'Retries must be bounded'
}
$script:delays = 0
$app = [FakeProcess]::new(1)
$other = [FakeProcess]::new(2)
$outside = [FakeProcess]::new(3); $outside.Member = $false
$stable = Account 2 2 0
$job = [FakeJob]::new(@($stable, (Account 3 2 1), (Account 3 2 1), (Account 3 2 1)))
$snapshot = Get-StableJobSnapshot -Job $job -AppId 1 -Enumerate { @($app, $other, $outside) }
Check ($job.Reads -eq 4 -and $script:delays -eq 1) 'Birth and death with unchanged count must retry'
Check ($snapshot.processes.Count -eq 2 -and $snapshot.accounting.TotalProcesses -eq 3) 'Stable snapshot must include job members only'
Check ($app.Disposed -and $other.Disposed -and $outside.Disposed) 'Processes must be disposed'
Expect-Failure ([FakeJob]::new(@($stable))) 1 @($app)
$other.Accessible = $false
Expect-Failure ([FakeJob]::new(@($stable))) 1 @($app, $other)
$other.Accessible = $true
Expect-Failure ([FakeJob]::new(@($stable))) 99 @($app, $other)
$accounts = @(1..20 | ForEach-Object { Account $_ 2 $_ })
Expect-Failure ([FakeJob]::new($accounts)) 1 @($app, $other)
