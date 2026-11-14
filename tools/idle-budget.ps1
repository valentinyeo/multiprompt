param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$Evidence,
    [int]$SettleSeconds = 90,
    [int]$IdleSeconds = 300
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'The idle budget gate runs only on GitHub Windows' }
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
Add-Type -Path "$PSScriptRoot/verify-chat-delivery/desktop.cs"
Add-Type -Path "$PSScriptRoot/verify-chat-delivery/job.cs"
$sandbox = Join-Path $env:RUNNER_TEMP ('idle-budget-' + [guid]::NewGuid().ToString('N'))
$env:APPDATA = "$sandbox/roaming"
$env:LOCALAPPDATA = "$sandbox/local"
$env:USERPROFILE = "$sandbox/home"
$env:HOME = "$sandbox/home"
$env:MP_VERIFY_STATE = "$sandbox/state"
$env:MP_VERIFY_PYTHON = (Get-Command python.exe).Source
$env:MP_VERIFY_BOUNDARY = (Resolve-Path "$PSScriptRoot/verify-chat-delivery/boundary.py").Path
$env:MULTIPROMPT_NO_LOGIN = '1'
$env:IGSH_246 = '0'
$env:PYTHONUTF8 = '1'
Remove-Item Env:ZIGSHELL_DEBUG -ErrorAction SilentlyContinue
$settings = "$sandbox/roaming/ZigShell"
$counters = "$sandbox/state/idle-counters.json"
$env:MULTIPROMPT_IDLE_COUNTERS = $counters
$invocations = "$sandbox/state/invocations.jsonl"
$job = $null
$app = $null
$verdict = 1
function Wait-For([string]$Name, [scriptblock]$Check, [int]$Seconds = 120, [int]$PollMs = 1000) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        if ($null -ne $app -and $app.HasExited) { throw "App exited during $Name" }
        $value = & $Check
        if ($value) { return $value }
        Start-Sleep -Milliseconds $PollMs
    } while ($timer.Elapsed.TotalSeconds -lt $Seconds)
    throw "Timed out: $Name"
}
function Read-Counters {
    try {
        $text = [IO.File]::ReadAllText($counters)
        $value = $text | ConvertFrom-Json
        if ($null -ne $value -and $null -ne $value.PSObject.Properties['tick_ms']) { return $text }
    } catch { return $null }
    return $null
}
function Count-Invocations {
    if (-not (Test-Path $invocations)) { return 0 }
    $stream = [IO.File]::Open($invocations, 'Open', 'Read', ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    $reader = [IO.StreamReader]::new($stream)
    try {
        $count = 0
        while ($null -ne $reader.ReadLine()) { $count++ }
        return $count
    } finally { $reader.Dispose() }
}
try {
    & python "$PSScriptRoot/idle-budget-fixture.py" $sandbox "$(Split-Path $Exe)/ssh.exe"
    if ($LASTEXITCODE -ne 0) { throw 'Idle budget fixture failed' }
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $sandbox, "$Evidence/stdout.log", "$Evidence/stderr.log", '--single-window --no-window-restore')
    [void](Wait-For 'owned app window' { $handle = [ChatDeliveryDesktop]::Window($app.Id); if ($handle -ne [IntPtr]::Zero) { $handle } })
    [void](Wait-For 'three restored server chats' {
        try {
            $snapshot = Get-Content "$settings/session.json" -Raw | ConvertFrom-Json
            @($snapshot.tabs).Count -eq 3 -and @($snapshot.tabs | Where-Object { -not $_.cv }).Count -eq 0
        } catch { $false }
    })
    [void](Wait-For 'first counter dump' { Read-Counters } 90)
    Write-Host "Settling for $SettleSeconds s with no input"
    $settle = [Diagnostics.Stopwatch]::StartNew()
    while ($settle.Elapsed.TotalSeconds -lt $SettleSeconds) {
        if ($app.HasExited) { throw 'App exited while settling' }
        Start-Sleep -Seconds 1
    }
    $beforeText = Wait-For 'counter dump before the idle window' { Read-Counters } 60
    $before = $beforeText | ConvertFrom-Json
    $invocationsBefore = Count-Invocations
    Write-Host "Idling for $IdleSeconds s with no input from tick $($before.tick_ms)"
    $afterText = Wait-For 'counter dump after the idle window' {
        $text = Read-Counters
        if ($null -ne $text -and ([long]($text | ConvertFrom-Json).tick_ms - [long]$before.tick_ms) -ge ($IdleSeconds * 1000)) { $text }
    } ($IdleSeconds + 120) 2000
    $invocationsAfter = Count-Invocations
    Set-Content -Path "$Evidence/counters-before.json" -Value $beforeText
    Set-Content -Path "$Evidence/counters-after.json" -Value $afterText
    $note = "ssh invocations during the idle window: $($invocationsAfter - $invocationsBefore) (report only, not budgeted)"
    & node "$PSScriptRoot/idle-budget.mjs" "$Evidence/counters-before.json" "$Evidence/counters-after.json" "$Evidence/report.txt"
    $verdict = $LASTEXITCODE
    Add-Content -Path "$Evidence/report.txt" -Value $note
    Write-Host $note
} finally {
    if ($null -ne $job) { [void]$job.Stop(); $job.Dispose() }
    if (Test-Path "$settings/session.json") { Copy-Item "$settings/session.json" "$Evidence/session.json" }
    if (Test-Path $invocations) { Copy-Item $invocations "$Evidence/invocations.jsonl" }
    if (Test-Path $counters) { Copy-Item $counters "$Evidence/counters-last.json" }
}
exit $verdict
