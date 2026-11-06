$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'GitHub Actions only' }
. "$PSScriptRoot/session.ps1"
function Check($condition, $message) { if (-not $condition) { throw $message } }
$tabs = @(1..30 | ForEach-Object { @{ kind='tmux'; shell_id=$_; cv=$true } })
$writer = @{ tabs=$tabs } | ConvertTo-Json -Depth 5 | ConvertFrom-Json
$ids = Get-GuardSessionIds $writer 30
Check ($null -ne $ids -and $ids.Count -eq 30) 'Writer schema without active_tab must be accepted'
$seed = @{ active_tab=0; single_window=$true; chat_active=$true; tabs=$tabs } | ConvertTo-Json -Depth 5 | ConvertFrom-Json
Check ($null -ne (Get-GuardSessionIds $seed 30)) 'Fixture schema must be accepted'
$writer.tabs[0].PSObject.Properties.Remove('cv')
Check ($null -eq (Get-GuardSessionIds $writer 30)) 'Missing cv must fail closed'
$writer.tabs[0] | Add-Member -NotePropertyName cv -NotePropertyValue $true
$writer.tabs[1].shell_id = $writer.tabs[0].shell_id
Check ($null -eq (Get-GuardSessionIds $writer 30)) 'Duplicate IDs must fail closed'
$writer.tabs[1].shell_id = '2'
Check ($null -eq (Get-GuardSessionIds $writer 30)) 'String IDs must fail closed'
Check ($null -eq (Get-GuardSessionIds (ConvertFrom-Json '{}') 30)) 'Missing tabs must fail closed'
$seen = @{}
foreach ($id in 1..30) {
    $trace = "hook: Ctrl+Tab shift=0 -> NEXT_TAB`nswitchToShell: 0 -> 1 restoring=false`n[switch] chat content shown shell=$id blocks=3 ms=1"
    $painted = Get-GuardPaintedId $trace $ids
    Check ($painted -eq "$id" -and -not $seen.ContainsKey($painted)) 'Each switch must prove a distinct painted shell'
    $seen[$painted] = $true
}
Check ($seen.Count -eq 30) 'All thirty shells must be visited'
Check ($null -eq (Get-GuardPaintedId '[switch] chat content shown shell=1 blocks=3' $ids)) 'Paint alone is not a switch'
Check ($null -eq (Get-GuardPaintedId "hook: Ctrl+Tab shift=0 -> NEXT_TAB`nswitchToShell: 0 -> 1 restoring=false`n[switch] chat content shown shell=1 blocks=0" $ids)) 'Empty paint is not ready'
$failed = $false
try { Get-GuardPaintedId "hook: Ctrl+Tab shift=0 -> NEXT_TAB`nswitchToShell: 0 -> 1 restoring=false`n[switch] chat content shown shell=31 blocks=1" $ids } catch { $failed = $true }
Check $failed 'Unknown painted shell must fail closed'
