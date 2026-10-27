param([Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string]$Evidence, [Parameter(Mandatory)][string]$Revision)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Performance workload runs only on GitHub Windows' }
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
Add-Type -AssemblyName System.Drawing
Add-Type -Path "$PSScriptRoot/verify-chat-delivery/desktop.cs"
Add-Type -Path "$PSScriptRoot/verify-chat-delivery/job.cs"
$profile = Join-Path $env:RUNNER_TEMP ('switch-performance-' + [guid]::NewGuid().ToString('N'))
$env:APPDATA = "$profile/roaming"
$env:LOCALAPPDATA = "$profile/local"
$env:USERPROFILE = "$profile/home"
$env:HOME = "$profile/home"
$env:MP_VERIFY_STATE = "$profile/state"
$env:MP_VERIFY_PYTHON = (Get-Command python.exe).Source
$env:MP_VERIFY_BOUNDARY = (Resolve-Path "$PSScriptRoot/verify-chat-delivery/boundary.py").Path
$env:MULTIPROMPT_NO_LOGIN = '1'
$env:ZIGSHELL_DEBUG = '1'
$env:IGSH_246 = '0'
$env:PYTHONUTF8 = '1'
$settings = "$profile/roaming/ZigShell"
$log = "$settings/debug.log"
$job = $null
$app = $null
function Read-Log {
    if (-not (Test-Path $log)) { return '' }
    $stream = [IO.File]::Open($log, 'Open', 'Read', ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    $reader = [IO.StreamReader]::new($stream)
    try { $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function Wait-For([string]$Name, [scriptblock]$Check, [int]$Seconds = 120) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        if ($null -ne $app -and $app.HasExited) { throw "App exited during $Name" }
        $value = & $Check
        if ($value) { return $value }
        Start-Sleep -Milliseconds 25
    } while ($timer.Elapsed.TotalSeconds -lt $Seconds)
    throw "Timed out: $Name"
}
function Session { Get-Content "$settings/session.json" -Raw | ConvertFrom-Json }
$result = @{ revision=$Revision; switches=@(); idleUs=@() }
try {
    & python "$PSScriptRoot/switch-performance-fixture.py" $profile "$(Split-Path $Exe)/ssh.exe"
    if ($LASTEXITCODE -ne 0) { throw 'Performance fixture failed' }
    $workload = Get-Content "$profile/state/workload.json" -Raw | ConvertFrom-Json
    $result.sessionCount = $workload.sessionCount
    $result.transcriptBytes = $workload.transcriptBytes
    $result.sha256 = (Get-FileHash $Exe -Algorithm SHA256).Hash
    $result.cpuCores = [Environment]::ProcessorCount
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $profile, "$Evidence/stdout.log", "$Evidence/stderr.log", '--single-window --no-window-restore')
    $main = Wait-For 'owned app window' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    [void](Wait-For 'ten restored Chat View sessions' { $s = Session; @($s.tabs).Count -eq 10 -and @($s.tabs | Where-Object { -not $_.cv }).Count -eq 0 })
    [void](Wait-For 'initial conversation painted' { (Read-Log) -match '\[switch\] chat content shown shell=\d+ blocks=[1-9]' })
    $initial = (Session).active_tab
    for ($i = 0; $i -lt 60; $i++) {
        [void](Wait-For 'owned window foreground' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $main) })
        $offset = (Read-Log).Length
        $previous = (Session).active_tab
        [ChatDeliveryDesktop]::Chord(@(0x11, 0x09))
        $target = ($previous + 1) % 10
        [void](Wait-For 'different target selected' { (Session).active_tab -eq $target })
        $targetShellId = (Session).tabs[$target].shell_id
        [void](Wait-For 'switch dispatch and nonempty target painted' {
            $range = (Read-Log).Substring($offset)
            $range -match ('switch-timing: to=' + $target + ' total_us=\d+') -and $range -match ('\[switch\] chat content shown shell=' + $targetShellId + ' blocks=[1-9]')
        })
        if ($i -ge 10) {
            $range = (Read-Log).Substring($offset)
            $timing = [regex]::Matches($range, 'switch-timing: to=(\d+) total_us=(\d+)')
            $paint = [regex]::Match($range, ('\[switch\] chat content shown shell=' + $targetShellId + ' blocks=(\d+)'))
            if ($timing.Count -ne 1 -or [int]$timing[0].Groups[1].Value -ne $target) { throw 'Missing or ambiguous switch timing' }
            $result.switches += @{ shell=$target; us=[long]$timing[0].Groups[2].Value; blocks=[int]$paint.Groups[1].Value }
        }
        Start-Sleep -Milliseconds 300
    }
    $idleOffset = (Read-Log).Length
    [void](Wait-For 'ten unchanged idle Chat View polls' { [regex]::Matches((Read-Log).Substring($idleOffset), 'chat-idle-poll: us=(\d+)').Count -ge 10 } 60)
    $result.idleUs = @([regex]::Matches((Read-Log).Substring($idleOffset), 'chat-idle-poll: us=(\d+)') | ForEach-Object { [long]$_.Groups[1].Value })
    $result.finalTab = (Session).active_tab
    if ($result.finalTab -ne $initial) { throw 'Switch cycle failed to return to initial session' }
    $app.Refresh()
    $result.cpuMs = $app.TotalProcessorTime.TotalMilliseconds
    $bitmap = [Drawing.Bitmap]::new([ChatDeliveryDesktop]::GetSystemMetrics(0), [ChatDeliveryDesktop]::GetSystemMetrics(1))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen(0, 0, 0, 0, $bitmap.Size); $bitmap.Save("$Evidence/screen.png") } finally { $graphics.Dispose(); $bitmap.Dispose() }
} finally {
    $result | ConvertTo-Json -Depth 6 | Set-Content "$Evidence/samples.json"
    if ($null -ne $job) { $job.Dispose() }
    if (Test-Path $log) { Copy-Item $log "$Evidence/debug.log" }
    if (Test-Path "$profile/state/invocations.jsonl") { Copy-Item "$profile/state/invocations.jsonl" "$Evidence/invocations.jsonl" }
    Get-ChildItem "$profile/state" -Filter '*.stderr.log' -ErrorAction SilentlyContinue | Copy-Item -Destination $Evidence
    if (Test-Path $profile) { Remove-Item -LiteralPath $profile -Recurse -Force }
}
