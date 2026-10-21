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
$profile = Join-Path $env:RUNNER_TEMP ("reconnect-" + [guid]::NewGuid().ToString('N'))
$state = "$profile/state"
$settings = "$profile/roaming/ZigShell"
$log = "$settings/debug.log"
$results = [Collections.Generic.List[object]]::new()
$app = $null
$failure = $null
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
function Wait-For([string]$Description, [scriptblock]$Check, [int]$Seconds = 90) {
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
function Tab([int]$Number) {
    [ReconnectDesktop]::Click($main)
    Start-Sleep -Milliseconds 250
    [ReconnectDesktop]::Key(0x11, $false)
    [ReconnectDesktop]::Key([ushort](0x30 + $Number), $false)
    [ReconnectDesktop]::Key([ushort](0x30 + $Number), $true)
    [ReconnectDesktop]::Key(0x11, $true)
    Start-Sleep -Milliseconds 800
}
function Transport([string]$Name) {
    foreach ($file in Get-ChildItem "$state/transport-*.txt" -ErrorAction SilentlyContinue) {
        if ([IO.File]::ReadAllText($file.FullName).Trim() -eq $Name) {
            $id = [int]($file.BaseName -replace '^transport-', '')
            $process = Get-Process -Id $id -ErrorAction SilentlyContinue
            if ($process -and $process.Path -eq $Ssh) { return $process }
        }
    }
    return $null
}
function Publish($Result) {
    $results.Add($Result)
    $line = '{0} case={1} reposition_lines={2} focus_changed={3} session_gone_count={4} attempts_after_gone={5}' -f $(if ($Result.pass) { 'PASS' } else { 'FAIL' }), $Result.case, $Result.reposition_lines, $Result.focus_changed.ToString().ToLower(), $Result.session_gone_count, $Result.attempts_after_gone
    Write-Output $line
    if ($env:GITHUB_STEP_SUMMARY) { Add-Content $env:GITHUB_STEP_SUMMARY $line }
    $results.ToArray() | ConvertTo-Json -Depth 8 -AsArray | Set-Content "$Output/summary.json"
}
try {
    New-Item -ItemType Directory -Force $settings, $state, "$profile/local" | Out-Null
    $env:APPDATA = "$profile/roaming"
    $env:LOCALAPPDATA = "$profile/local"
    $env:MULTIPROMPT_NO_LOGIN = '1'
    $env:ZIGSHELL_DEBUG = '1'
    $env:MP_VERIFY_STATE = $state
    [IO.File]::WriteAllText("$settings/ssh-path.txt", $Ssh)
    [IO.File]::WriteAllText("$state/sessions.txt", "verify-one`nverify-two`n")
    @{active_tab=0; single_window=$false; chat_active=$false; chat_view_mode='nowhere'; tabs=@(
        @{kind='tmux'; name='Verify one'; manual=$true; tmux_host=0; tmux_session='verify-one'; cv=$false; pid=0},
        @{kind='tmux'; name='Verify two'; manual=$true; tmux_host=0; tmux_session='verify-two'; cv=$false; pid=0}
    )} | ConvertTo-Json -Depth 6 | Set-Content "$settings/session.json"
    Copy-Item "$settings/session.json" "$Output/seed-session.json"
    $app = Start-Process $Exe -ArgumentList '--no-window-restore' -PassThru
    $main = Wait-For 'app window' { $h = [ReconnectDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    [void](Wait-For 'two live transports and connected debug lines' {
        $text = Read-Log
        if ((Transport 'verify-one') -and (Transport 'verify-two') -and
            $text.Contains("ssh: selected working executable: $Ssh") -and
            ($text -match "session='verify-one'") -and ($text -match "session='verify-two'")) { $true }
    })
    [void][ReconnectDesktop]::SetForegroundWindow($main)
    Start-Sleep -Seconds 18
    foreach ($number in 1, 2) {
        Tab $number
        $readyOffset = (Read-Log).Length
        [ReconnectDesktop]::Key(0x11, $false)
        [ReconnectDesktop]::Key(0x10, $false)
        [ReconnectDesktop]::Key(0x52, $false)
        [ReconnectDesktop]::Key(0x52, $true)
        [ReconnectDesktop]::Key(0x10, $true)
        [ReconnectDesktop]::Key(0x11, $true)
        [void](Wait-For "tab $number confirmed connected" {
            $ready = (Read-Log).Substring($readyOffset)
            $spawn = [regex]::Match($ready, "respawnShellInPlace ok kind=tmux idx=$($number - 1) new_id=(\d+)")
            if ($spawn.Success -and $ready -match "ssh-reconnect ok id=$($spawn.Groups[1].Value)\b") { $true }
        })
    }
    Tab 1
    $inputSurface = Wait-For 'visible native console' { $h = [ReconnectDesktop]::InputSurface($main); if ($h -ne [IntPtr]::Zero) { $h } }
    [ReconnectDesktop]::Click($inputSurface)
    Start-Sleep -Seconds 3
    $before = [ReconnectDesktop]::Focus($main)
    if ($before[0] -ne $main.ToInt64() -and $before[0] -ne $inputSurface.ToInt64()) { throw 'Doctor: app or embedded console must be foreground' }
    $surfaceFocus = [ReconnectDesktop]::Focus($inputSurface)
    if ($before[1] -ne $inputSurface.ToInt64() -and $surfaceFocus[1] -ne $inputSurface.ToInt64()) { throw 'Doctor: native console must own typing focus' }
    @{pid=$app.Id; exe=$Exe; main=$main.ToInt64(); input_surface=$inputSurface.ToInt64(); focus=$before; surface_focus=$surfaceFocus; selected_ssh=$Ssh; two_transports=$true} | ConvertTo-Json -Depth 5 | Set-Content "$Output/doctor.json"
    $positiveControl = @([regex]::Matches((Read-Log), '\[reposition\]')).Count
    if ($positiveControl -lt 1) { throw 'Doctor: console layout positive control missing' }
    if ([ReconnectDesktop]::Owner($inputSurface) -ne (Transport 'verify-one').Id) { throw 'Doctor: active console is not tab one' }
    @{layout_positive_control=$positiveControl} | ConvertTo-Json | Set-Content "$Output/layout-control.json"
    Shot 'before'
    $offset = (Read-Log).Length
    $old = Transport 'verify-two'
    @{case='A'; action='kill background transport'; pid=$old.Id; log_offset=$offset; utc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content "$Output/action-A.json"
    Stop-Process -Id $old.Id -Force
    $samples = [Collections.Generic.List[object]]::new()
    $deadline = [DateTime]::UtcNow.AddSeconds(100)
    $connected = $false
    do {
        $focus = [ReconnectDesktop]::Focus($main)
        $samples.Add(@{utc=[DateTime]::UtcNow.ToString('o'); foreground=$focus[0]; focus=$focus[1]})
        $slice = (Read-Log).Substring($offset)
        $match = [regex]::Match($slice, 'respawnShellInPlace ok kind=tmux idx=1 new_id=(\d+)')
        $current = Transport 'verify-two'
        if ($match.Success -and $current -and $current.Id -ne $old.Id -and $slice -match "ssh-reconnect ok id=$($match.Groups[1].Value)\b") { $connected = $true; break }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    Start-Sleep -Seconds 2
    $after = [ReconnectDesktop]::Focus($main)
    $samples.Add(@{utc=[DateTime]::UtcNow.ToString('o'); foreground=$after[0]; focus=$after[1]})
    $slice = (Read-Log).Substring($offset)
    [IO.File]::WriteAllText("$Output/case-A.log", $slice)
    @{before=$before; after=$after; samples=$samples.ToArray(); connected=$connected} | ConvertTo-Json -Depth 6 | Set-Content "$Output/focus.json"
    $reposition = @($slice -split "`n" | Where-Object { $_ -match '\[reposition\]|posBrowser|posMasks' }).Count
    $changed = @($samples | Where-Object { $_.foreground -ne $before[0] -or $_.focus -ne $before[1] }).Count -gt 0
    Shot 'case-A'
    Publish @{case='A'; pass=($connected -and $reposition -eq 0 -and !$changed); reposition_lines=$reposition; focus_changed=$changed; session_gone_count=0; attempts_after_gone=0; reconnected=$connected; log_offset=$offset}
    if (!$connected) { throw 'Background tab never completed reconnect' }
    $offsetB = (Read-Log).Length
    $current = Transport 'verify-two'
    [IO.File]::WriteAllText("$state/sessions.next", "verify-one`n")
    Move-Item "$state/sessions.next" "$state/sessions.txt" -Force
    @{case='B'; action='delete session then kill transport'; pid=$current.Id; log_offset=$offsetB; utc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content "$Output/action-B.json"
    Stop-Process -Id $current.Id -Force
    $deadline = [DateTime]::UtcNow.AddSeconds(40)
    $ended = $null
    do {
        $sliceB = (Read-Log).Substring($offsetB)
        $ended = [regex]::Match($sliceB, 'ssh-reconnect ended id=(\d+) reason=session-gone')
        if ($ended.Success) { break }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    $observeOffset = (Read-Log).Length
    $observeStart = [DateTime]::UtcNow
    Start-Sleep -Seconds 60
    $observeSeconds = ([DateTime]::UtcNow - $observeStart).TotalSeconds
    $sliceB = (Read-Log).Substring($offsetB)
    $observation = (Read-Log).Substring($observeOffset)
    $goneCount = @([regex]::Matches($sliceB, 'ssh-reconnect ended id=\d+ reason=session-gone')).Count
    $idPattern = if ($ended.Success) { [regex]::Escape($ended.Groups[1].Value) } else { '\d+' }
    $attempts = @([regex]::Matches($observation, "ssh-reconnect attempt=\d+ id=$idPattern\b")).Count
    [IO.File]::WriteAllText("$Output/case-B.log", $sliceB)
    [IO.File]::WriteAllText("$Output/after-gone.log", $observation)
    Tab 2
    Start-Sleep -Seconds 1
    Shot 'case-B-session-ended'
    Publish @{case='B'; pass=($ended.Success -and $goneCount -eq 1 -and $attempts -eq 0 -and $observeSeconds -ge 60); reposition_lines=0; focus_changed=$false; session_gone_count=$goneCount; attempts_after_gone=$attempts; observed_seconds=$observeSeconds; ended_id=$(if ($ended.Success) { $ended.Groups[1].Value } else { $null })}
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
    if (Test-Path $state) { Copy-Item $state "$Output/stand-in" -Recurse -Force }
    $alive = @(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -eq $Ssh -or ($app -and $_.ProcessId -eq $app.Id) })
    @{app_pid=$(if ($app) { $app.Id } else { $null }); remaining_owned_processes=$alive.Count; evidence_preserved=(Test-Path "$Output/debug.log")} | ConvertTo-Json | Set-Content "$Output/cleanup.json"
    Remove-Item $profile -Recurse -Force -ErrorAction SilentlyContinue
    Stop-Transcript
}
if ($failure -or $results.Count -ne 2 -or @($results | Where-Object { !$_.pass }).Count -gt 0) { exit 1 }
