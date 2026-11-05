param([Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string]$Ssh, [Parameter(Mandatory)][string]$Output)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $Output | Out-Null
$Output = (Resolve-Path $Output).Path
$Exe = (Resolve-Path $Exe).Path
$Ssh = (Resolve-Path $Ssh).Path
Start-Transcript "$Output/driver.log"
Add-Type -AssemblyName System.Drawing
Add-Type -Path "$PSScriptRoot/desktop.cs"
[void][ReconnectDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
[ReconnectDesktop]::StartSpy()
$profile = Join-Path $env:RUNNER_TEMP ("pending-close-" + [guid]::NewGuid().ToString('N'))
$state = "$profile/state"
$settings = "$profile/roaming/ZigShell"
$log = "$settings/debug.log"
$results = [Collections.Generic.List[object]]::new()
$app = $null
$failure = $null
$main = [IntPtr]::Zero
function Read-Log {
    if (!(Test-Path $log)) { return '' }
    for ($retry = 0; $retry -lt 100; $retry++) {
        $stream = $null
        $reader = $null
        try {
            $stream = [IO.File]::Open($log, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
            $reader = [IO.StreamReader]::new($stream)
            return $reader.ReadToEnd()
        } catch [IO.IOException] {
            if ($retry -eq 99) { throw }
            Start-Sleep -Milliseconds 10
        } finally {
            if ($reader) { $reader.Dispose() } elseif ($stream) { $stream.Dispose() }
        }
    }
}
function Wait-For([string]$Description, [scriptblock]$Check, [int]$Seconds = 60) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 200 } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out: $Description"
}
function Shot([string]$Name) {
    $bitmap = [Drawing.Bitmap]::new([ReconnectDesktop]::GetSystemMetrics(0), [ReconnectDesktop]::GetSystemMetrics(1))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen(0, 0, 0, 0, $bitmap.Size); $bitmap.Save("$Output/$Name.png", [Drawing.Imaging.ImageFormat]::Png) }
    finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Press([int]$Vk) { [ReconnectDesktop]::Type([ushort]$Vk) }
function Press-Text([string]$Text) {
    foreach ($char in $Text.ToUpper().ToCharArray()) { if ($char -eq ' ') { Press 0x20 } else { Press ([int]$char) } }
}
function Host-Sessions { @(Get-Content "$state/sessions.txt" -ErrorAction SilentlyContinue | Where-Object { $_ }) }
function Kill-Calls { @(Get-ChildItem "$state/invocation-*.txt" -ErrorAction SilentlyContinue | ForEach-Object { Get-Content $_.FullName } | Where-Object { $_ -match 'tmux kill-session' }) }
function Record([string]$Case, [bool]$Pass, [string]$Detail) {
    $results.Add(@{case=$Case; pass=$Pass; detail=$Detail})
    $line = '{0} case={1} {2}' -f $(if ($Pass) { 'PASS' } else { 'FAIL' }), $Case, $Detail
    Write-Output $line
    if ($env:GITHUB_STEP_SUMMARY) { Add-Content $env:GITHUB_STEP_SUMMARY $line }
    $results.ToArray() | ConvertTo-Json -Depth 5 -AsArray | Set-Content "$Output/summary.json"
}
function Chord([int]$Vk, [bool]$Shift = $false) {
    [ReconnectDesktop]::Activate($main)
    [ReconnectDesktop]::Key(0x11, $false)
    if ($Shift) { [ReconnectDesktop]::Key(0x10, $false) }
    Press $Vk
    if ($Shift) { [ReconnectDesktop]::Key(0x10, $true) }
    [ReconnectDesktop]::Key(0x11, $true)
}
function Saved {
    try { Get-Content "$settings/session.json" -Raw | ConvertFrom-Json } catch { $null }
}
function Is-Closed([string]$Name) {
    $saved = Saved
    $saved -and @($saved.tabs | Where-Object { $_.tmux_session -eq $Name }).Count -eq 0 -and @($saved.closed_tmux | Where-Object { $_.session -eq $Name }).Count -eq 1
}
function Refresh {
    Chord 0x4B
    Start-Sleep -Milliseconds 500
    Press-Text 'show all sessions'
    Start-Sleep -Milliseconds 500
    Press 0x0D
    Start-Sleep -Seconds 2
    Press 0x1B
}
try {
    if ($env:GITHUB_ACTIONS -ne 'true' -or !$IsWindows) { throw 'Hosted Windows only' }
    New-Item -ItemType Directory -Force $settings, $state, "$profile/local" | Out-Null
    $env:APPDATA = "$profile/roaming"
    $env:LOCALAPPDATA = "$profile/local"
    $env:MULTIPROMPT_NO_LOGIN = '1'
    $env:ZIGSHELL_DEBUG = '1'
    $env:MP_VERIFY_STATE = $state
    [IO.File]::WriteAllText("$settings/ssh-path.txt", $Ssh)
    [IO.File]::WriteAllText("$state/sessions.txt", "verify-one`nverify-two`n")
    @{active_tab=0; single_window=$false; chat_active=$false; tabs=@(
        @{kind='tmux'; name='Verify one'; manual=$true; tmux_host=0; tmux_session='verify-one'; cv=$false; pid=0},
        @{kind='tmux'; name='Verify two'; manual=$true; tmux_host=0; tmux_session='verify-two'; cv=$false; pid=0}
    )} | ConvertTo-Json -Depth 6 | Set-Content "$settings/session.json"
    Copy-Item "$settings/session.json" "$Output/seed-session.json"
    $app = Start-Process $Exe -ArgumentList '--no-window-restore' -PassThru
    $main = Wait-For 'app window' { $h = [ReconnectDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } } 90
    [void](Wait-For 'both attached tabs' { (Read-Log) -match "session='verify-two'" } 90)
    Start-Sleep -Seconds 10
    Chord 0x31
    Start-Sleep -Seconds 1
    Shot 'before'
    New-Item "$state/kill-offline" -ItemType File | Out-Null
    Chord 0x57 $true
    [void](Wait-For 'offline close persisted' { Is-Closed 'verify-one' })
    Copy-Item "$settings/session.json" "$Output/offline-session.json"
    Refresh
    Record 'offline-tab-stays-closed' ((Is-Closed 'verify-one') -and (Host-Sessions) -contains 'verify-one') 'Remote kill unavailable; stale successful listing must not reopen the tab.'
    Shot 'offline-closed'
    Remove-Item "$state/kill-offline"
    Refresh
    [void](Wait-For 'queued end reaches host' { (Host-Sessions) -notcontains 'verify-one' })
    $done = @(Get-ChildItem "$state/kill-done-*.txt" | Where-Object { (Get-Content $_.FullName -Raw) -eq 'verify-one' })
    Record 'reconnect-ends-once' ($done.Count -eq 1 -and (Is-Closed 'verify-one')) "successful ends=$($done.Count)"
    Shot 'reconnected'
    New-Item "$state/kill-offline" -ItemType File | Out-Null
    Chord 0x31
    Start-Sleep -Seconds 1
    Chord 0x57 $true
    [void](Wait-For 'second offline close persisted' { Is-Closed 'verify-two' })
    Shot 'second-offline-closed'
    New-Item "$state/kill-hold" -ItemType File | Out-Null
    Remove-Item "$state/kill-offline"
    Refresh
    $held = Wait-For 'connecting retry process' { Get-ChildItem "$state/kill-held-*.txt" -ErrorAction SilentlyContinue | Select-Object -First 1 }
    $heldId = [int]($held.BaseName -replace '^kill-held-', '')
    $heldProcess = Get-Process -Id $heldId -ErrorAction Stop
    if ($heldProcess.Path -ne $Ssh -or $heldProcess.HasExited) { throw 'Expected the owned retry still connecting before reopen' }
    $cancelClock = [Diagnostics.Stopwatch]::StartNew()
    Chord 0x54 $true
    [void](Wait-For 'explicit reopen saved' {
        $saved = Saved
        $saved -and @($saved.tabs | Where-Object { $_.tmux_session -eq 'verify-two' }).Count -eq 1 -and @($saved.closed_tmux | Where-Object { $_.session -eq 'verify-two' }).Count -eq 0
    })
    [void](Wait-For 'cancelled connecting process exits' { !(Get-Process -Id $heldId -ErrorAction SilentlyContinue) } 5)
    $heldAgeMs = ([DateTime]::UtcNow - $held.LastWriteTimeUtc).TotalMilliseconds
    if ($heldAgeMs -ge 9000) { throw 'Cannot distinguish cancellation from the normal ten-second timeout' }
    @{pid=$heldId; cancelled_after_ms=$cancelClock.Elapsed.TotalMilliseconds; held_age_ms=$heldAgeMs; owned_path_checked=$true; exited=$true} | ConvertTo-Json | Set-Content "$Output/cancellation.json"
    Copy-Item "$settings/session.json" "$Output/reopened-session.json"
    Shot 'reopened'
    Remove-Item "$state/kill-hold"
    Refresh
    Refresh
    $saved = Saved
    $done = @(Get-ChildItem "$state/kill-done-*.txt" | Where-Object { (Get-Content $_.FullName -Raw) -eq 'verify-two' })
    Record 'reopen-cancels-running-end' ((Host-Sessions) -contains 'verify-two' -and $done.Count -eq 0 -and @($saved.tabs | Where-Object { $_.tmux_session -eq 'verify-two' }).Count -eq 1) "successful ends=$($done.Count); cancelled pid=$heldId"
} catch {
    $failure = $_.ToString()
    Write-Output "HARNESS ERROR $failure"
    $failure | Set-Content "$Output/error.txt"
} finally {
    try { Shot 'final' } catch { Write-Output "Screenshot error: $_" }
    if ($app -and !$app.HasExited) { & taskkill /PID $app.Id /T /F | Out-Null }
    foreach ($file in Get-ChildItem "$state/transport-*.txt" -ErrorAction SilentlyContinue) {
        $id = [int]($file.BaseName -replace '^transport-', '')
        $process = Get-Process -Id $id -ErrorAction SilentlyContinue
        if ($process -and $process.Path -eq $Ssh) { Stop-Process -Id $id -Force }
    }
    if (Test-Path $log) { Copy-Item $log "$Output/debug.log" }
    if (Test-Path "$settings/session.json") { Copy-Item "$settings/session.json" "$Output/final-session.json" }
    if (Test-Path $state) { Copy-Item $state "$Output/stand-in" -Recurse -Force }
    $alive = @(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -eq $Ssh -or ($app -and $_.ProcessId -eq $app.Id) })
    @{app_pid=$(if ($app) { $app.Id } else { $null }); remaining_owned_processes=$alive.Count; evidence_preserved=(Test-Path "$Output/debug.log")} | ConvertTo-Json | Set-Content "$Output/cleanup.json"
    if ($alive.Count -ne 0) { $failure = 'Owned processes survived cleanup' }
    Remove-Item $profile -Recurse -Force -ErrorAction SilentlyContinue
    Stop-Transcript
}
if ($failure -or $results.Count -ne 3 -or @($results | Where-Object { !$_.pass }).Count -gt 0) { exit 1 }
