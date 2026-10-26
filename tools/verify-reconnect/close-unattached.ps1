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
$profile = Join-Path $env:RUNNER_TEMP ("close-unattached-" + [guid]::NewGuid().ToString('N'))
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
function Probe {
    $offset = (Read-Log).Length
    Press 0x58
    $match = Wait-For 'close confirmation in the app log' {
        $found = [regex]::Match((Read-Log).Substring($offset), 'all-sessions close-confirm count=(\d+) strong=(\d) targets=(\S+)')
        if ($found.Success) { $found }
    } 20
    return @{count=[int]$match.Groups[1].Value; strong=[int]$match.Groups[2].Value; targets=$match.Groups[3].Value}
}
function Cancel-Confirm {
    $offset = (Read-Log).Length
    Press 0x1B
    [void](Wait-For 'cancel in the app log' { (Read-Log).Substring($offset) -match 'all-sessions close-cancelled' } 20)
}
function Go-Top { Press 0x47; Press 0x47 }
function Go-To([string[]]$Order, [string]$Name) {
    $index = [Array]::IndexOf($Order, $Name)
    if ($index -lt 0) { throw "Session $Name is not in the expected order $($Order -join ',')" }
    Go-Top
    for ($step = 0; $step -lt $index; $step++) { Press 0x4A }
}
function Confirm-And-Wait([string]$Expect) {
    $offset = (Read-Log).Length
    Press 0x0D
    [void](Wait-For "close to finish ($Expect)" { (Read-Log).Substring($offset) -match "all-sessions close-finished $Expect" } 60)
}
try {
    New-Item -ItemType Directory -Force $settings, $state, "$profile/local" | Out-Null
    $env:APPDATA = "$profile/roaming"
    $env:LOCALAPPDATA = "$profile/local"
    $env:MULTIPROMPT_NO_LOGIN = '1'
    $env:ZIGSHELL_DEBUG = '1'
    $env:MP_VERIFY_STATE = $state
    [IO.File]::WriteAllText("$settings/ssh-path.txt", $Ssh)
    $names = @('verify-one', 'idle-one', 'idle-two', 'idle-three', 'agent-one', 'agent-two')
    [IO.File]::WriteAllText("$state/sessions.txt", (($names -join "`n") + "`n"))
    @{active_tab=0; single_window=$false; chat_active=$false; tabs=@(
        @{kind='tmux'; name='Verify one'; manual=$true; tmux_host=0; tmux_session='verify-one'; cv=$false; pid=0}
    )} | ConvertTo-Json -Depth 6 | Set-Content "$settings/session.json"
    Copy-Item "$settings/session.json" "$Output/seed-session.json"
    $app = Start-Process $Exe -ArgumentList '--no-window-restore' -PassThru
    $main = Wait-For 'app window' { $h = [ReconnectDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } } 90
    [void](Wait-For 'attached tab' { (Read-Log) -match "session='verify-one'" } 90)
    Start-Sleep -Seconds 10
    [ReconnectDesktop]::Activate($main)
    Start-Sleep -Milliseconds 500
    $listOffset = (Read-Log).Length
    [ReconnectDesktop]::Key(0x11, $false)
    Press 0x4B
    [ReconnectDesktop]::Key(0x11, $true)
    Start-Sleep -Milliseconds 500
    Press-Text 'show all sessions'
    Start-Sleep -Milliseconds 500
    Press 0x0D
    [void](Wait-For 'tmux list with the five unattached sessions' { (Read-Log).Substring($listOffset) -match 'fetchHostIntoCache\(host=0\) done: total=\d+ bytes, added=6' } 60)
    Start-Sleep -Seconds 3
    Press 0x55
    Start-Sleep -Seconds 1
    Shot 'before'
    $order = @()
    for ($row = 0; $row -lt 5; $row++) {
        $probe = Probe
        $order += $probe.targets
        Cancel-Confirm
        Press 0x4A
    }
    @{order=$order} | ConvertTo-Json | Set-Content "$Output/order.json"
    $expectedSet = @('idle-one', 'idle-two', 'idle-three', 'agent-one', 'agent-two') | Sort-Object
    Record 'rows' ((@($order | Sort-Object) -join ',') -ceq ($expectedSet -join ',')) "order=$($order -join ',')"
    $killsBefore = (Kill-Calls).Count
    Record 'esc-closes-nothing' (((Host-Sessions).Count -eq 6) -and $killsBefore -eq 0) "host sessions=$((Host-Sessions) -join ',') kill_calls=$killsBefore"

    Go-To $order 'idle-one'
    $probe = Probe
    Shot 'confirm-single'
    Record 'single-confirm' ($probe.count -eq 1 -and $probe.targets -ceq 'idle-one' -and $probe.strong -eq 0) "count=$($probe.count) strong=$($probe.strong) targets=$($probe.targets)"
    Confirm-And-Wait 'done=1 failed=0'
    Start-Sleep -Seconds 1
    Shot 'after-single'
    $order = @($order | Where-Object { $_ -ne 'idle-one' })
    $calls = Kill-Calls
    Record 'single-closed-on-host' (((Host-Sessions) -notcontains 'idle-one') -and (Host-Sessions).Count -eq 5 -and @($calls | Where-Object { $_ -match 'idle-one' }).Count -eq 1) "host sessions=$((Host-Sessions) -join ',')"

    Go-To $order 'agent-one'
    $probe = Probe
    Shot 'confirm-agent'
    Record 'agent-warning' ($probe.count -eq 1 -and $probe.targets -ceq 'agent-one' -and $probe.strong -eq 1) "count=$($probe.count) strong=$($probe.strong) targets=$($probe.targets)"
    Cancel-Confirm
    Start-Sleep -Seconds 2
    Shot 'after-cancel'
    Record 'agent-esc-keeps-session' (((Host-Sessions) -contains 'agent-one') -and (Kill-Calls).Count -eq 1) "host sessions=$((Host-Sessions) -join ',') kill_calls=$((Kill-Calls).Count)"

    foreach ($name in 'idle-two', 'idle-three') {
        Go-To $order $name
        $markOffset = (Read-Log).Length
        Press 0x20
        [void](Wait-For "mark $name" { (Read-Log).Substring($markOffset) -match "all-sessions mark session=$name marked=1" } 20)
    }
    Shot 'marked'
    Go-Top
    $probe = Probe
    Shot 'confirm-multi'
    $targets = @($probe.targets -split ',' | Sort-Object)
    Record 'multi-confirm' ($probe.count -eq 2 -and (($targets -join ',') -ceq 'idle-three,idle-two') -and $probe.strong -eq 0) "count=$($probe.count) strong=$($probe.strong) targets=$($probe.targets)"
    Confirm-And-Wait 'done=2 failed=0'
    Start-Sleep -Seconds 1
    Shot 'after-multi'
    $left = @(Host-Sessions | Sort-Object)
    Record 'multi-closed-on-host' (($left -join ',') -ceq 'agent-one,agent-two,verify-one' -and (Kill-Calls).Count -eq 3) "host sessions=$($left -join ',') kill_calls=$((Kill-Calls).Count)"
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
if ($failure -or $results.Count -ne 8 -or @($results | Where-Object { !$_.pass }).Count -gt 0) { exit 1 }
