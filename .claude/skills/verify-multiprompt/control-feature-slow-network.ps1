Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class SlowNetPump {
    [DllImport("user32.dll", EntryPoint = "SendMessageTimeoutW")]
    static extern IntPtr SendMessageTimeoutW(IntPtr hwnd, uint message, IntPtr wparam, IntPtr lparam, uint flags, uint timeout, out IntPtr result);

    [DllImport("user32.dll")]
    static extern bool IsHungAppWindow(IntPtr hwnd);

    public static double Ping(IntPtr hwnd, uint timeoutMs, out bool timedOut) {
        var watch = System.Diagnostics.Stopwatch.StartNew();
        IntPtr result;
        IntPtr ok = SendMessageTimeoutW(hwnd, 0, IntPtr.Zero, IntPtr.Zero, 2, timeoutMs, out result);
        watch.Stop();
        timedOut = ok == IntPtr.Zero;
        return watch.Elapsed.TotalMilliseconds;
    }

    public static bool Hung(IntPtr hwnd) {
        return IsHungAppWindow(hwnd);
    }
}
'@

$slowLimitMs = 500
$slowLog = Join-Path $scratch 'roaming/ZigShell/debug.log'
$slowComposer = [IntPtr]::Zero
$result.slowNetwork = @{
    delayMs = [int]$env:MP_VERIFY_SLOW_MS
    proxyPort = [int]$env:MP_VERIFY_SLOW_PORT
    boundary = 'Real app and native window driven through a local TCP delay proxy in front of the repository SSH/tmux stand-in; the delay is real TCP latency, the remote host is synthetic'
    stallLimitMs = $slowLimitMs
}

function Measure-PumpWindow([scriptblock]$Action, [int]$WindowMs) {
    $started = [Diagnostics.Stopwatch]::StartNew()
    & $Action
    $longest = 0.0
    $samples = 0
    $hung = $false
    while ($started.ElapsedMilliseconds -lt $WindowMs) {
        $timedOut = $false
        $milliseconds = [SlowNetPump]::Ping($script:window, 5000, [ref]$timedOut)
        $samples++
        if ($milliseconds -gt $longest) { $longest = $milliseconds }
        if ($timedOut -or [SlowNetPump]::Hung($script:window)) { $hung = $true }
        Start-Sleep -Milliseconds 10
    }
    @{ startedAt = [DateTime]::UtcNow.ToString('o'); elapsedMs = [int]$started.ElapsedMilliseconds; maxPumpMs = [int][Math]::Ceiling($longest); samples = $samples; hung = $hung }
}

Write-Host 'Wait: two remote sessions attached through the slow link'
Wait-Until {
    $trace = Read-SharedText $slowLog
    $trace -match "session='verify-one'" -and $trace -match "session='verify-two'"
} 'two remote session transports attached' 240
Wait-Until {
    $state = Read-Inbox
    $null -ne $state -and @($state.shells).Count -ge 2
} 'two published remote shells' 120
Wait-Until {
    $probes = [regex]::Matches((Read-SharedText $slowLog), 'ssh-probe result host=0 ok=(\d)')
    $probes.Count -gt 0 -and $probes[$probes.Count - 1].Groups[1].Value -eq '1'
} 'remote session probe healthy through the slow link' 120
$result.slowNetwork.sessions = @('verify-one', 'verify-two')

Press @(0x12, 0x43) 'Alt+C: open Chat View for the selected remote session'
Wait-Until {
    $state = Read-Session
    $null -ne $state -and $state.tabs[$state.active_tab].cv -eq $true
} 'Chat View enabled on the selected remote session' 60
Wait-ChatFocus 'Edit' 'slow-network-composer'
$element = [System.Windows.Automation.AutomationElement]::FocusedElement
if ($element.Current.ClassName -cne 'Edit' -or [VerifyNative]::GetAncestor([IntPtr]$element.Current.NativeWindowHandle, 2) -ne $script:window) { throw 'Composer Edit is not owned by the app window' }
$slowComposer = [IntPtr]$element.Current.NativeWindowHandle
if ([VerifyNative]::EditText($slowComposer) -cne '') { throw 'Expected an empty composer before the slow-network typing proof' }
Snapshot 'slow-network-chat-view'

$composerRect = New-Object VerifyNative+Rect
if (-not [VerifyNative]::GetClientRect($slowComposer, [ref]$composerRect) -or $composerRect.Right -le 0 -or $composerRect.Bottom -le 0) { throw 'Composer rectangle unavailable before typing' }
Doctor
Assert-Foreground
Record 'Click the ownership-checked composer before the slow-network typing proof'
[VerifyNative]::ClickClient($slowComposer, [int][Math]::Min(60, $composerRect.Right / 2), [int]($composerRect.Bottom / 2))
Start-Sleep -Milliseconds 300
Wait-ChatFocus 'Edit' 'slow-network-typing-focus'
Press @(0x11, 0x41) 'Ctrl+A: select any composer draft before the typing proof'
Press @(0x08) 'Backspace: clear the composer'

$typed = 'slowlink'
$typing = New-Object System.Collections.Generic.List[object]
foreach ($letter in $typed.ToCharArray()) {
    $sample = Measure-PumpWindow { Type-Text ([string]$letter) } 800
    $sample.kind = 'typing'
    $sample.letter = [string]$letter
    $expected = $typed.Substring(0, $typing.Count + 1)
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    $landed = $false
    do {
        if ([VerifyNative]::EditText($slowComposer) -ceq $expected) { $landed = $true; break }
        Start-Sleep -Milliseconds 50
    } while ([DateTime]::UtcNow -lt $deadline)
    if (-not $landed) { throw "Composer never showed '$expected' after typing '$letter' under the slow link" }
    $typing.Add($sample)
}
if ([VerifyNative]::EditText($slowComposer) -cne $typed) { throw "Composer text after the slow-network typing proof was '$([VerifyNative]::EditText($slowComposer))'" }
$result.slowNetwork.typingMaxPumpMs = [int](($typing | ForEach-Object { [int]$_.maxPumpMs } | Measure-Object -Maximum).Maximum)
$result.slowNetwork.typingHung = @($typing | Where-Object { $_.hung -eq $true }).Count -gt 0
Snapshot 'slow-network-typing'

function Select-SessionRow([int]$Row, [string]$Label) {
    Doctor
    Assert-Foreground
    Record $Label
    [VerifyNative]::ClickClient($script:window, 150, 96 + 60 * $Row)
}

$switches = New-Object System.Collections.Generic.List[object]
for ($index = 0; $index -lt 10; $index++) {
    $row = if ($index % 2 -eq 0) { 1 } else { 0 }
    $offset = (Read-SharedText $slowLog).Length
    $action = [Diagnostics.Stopwatch]::StartNew()
    $sample = Measure-PumpWindow { Select-SessionRow $row "Click sidebar row $($row + 1): switch sessions while the remote link is slow" } 3000
    $sample.kind = 'switch'
    $sample.index = $index
    $sample.target = if ($row -eq 0) { 'verify-one' } else { 'verify-two' }
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    $switched = $false
    do {
        $trace = (Read-SharedText $slowLog).Substring($offset)
        if ($trace -match "switchToShell: \d+ -> $row\b") {
            $sample.responseMs = [int]$action.ElapsedMilliseconds
            $switched = $true
            break
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    if (-not $switched) { throw "Session switch $index never reached sidebar row $($row + 1) under the slow link" }
    $switches.Add($sample)
    if ($index -eq 4) { Snapshot 'slow-network-switch' }
}
$result.slowNetwork.switchMaxPumpMs = [int](($switches | ForEach-Object { [int]$_.maxPumpMs } | Measure-Object -Maximum).Maximum)
$result.slowNetwork.switchHung = @($switches | Where-Object { $_.hung -eq $true }).Count -gt 0

$actions = @($switches.ToArray()) + @($typing.ToArray())
$worst = [int](($actions | ForEach-Object { [int]$_.maxPumpMs } | Measure-Object -Maximum).Maximum)
$hungActions = @($actions | Where-Object { $_.hung -eq $true }).Count
Save-Json @{
    limitMs = $slowLimitMs
    delayMs = [int]$env:MP_VERIFY_SLOW_MS
    actions = $actions
    worstMs = $worst
    hungActions = $hungActions
    passed = ($worst -le $slowLimitMs -and $hungActions -eq 0)
} 'slow-network-timings.json'
$result.slowNetwork.worstMs = $worst
$result.slowNetwork.hungActions = $hungActions
$result.checks += @{ name = 'slow-network'; sessions = 2; switches = $switches.Count; typed = $typed.Length; worstMs = $worst; limitMs = $slowLimitMs; hungActions = $hungActions; delayMs = [int]$env:MP_VERIFY_SLOW_MS }

if ($worst -gt $slowLimitMs) { throw "UI stall ${worst}ms exceeded the ${slowLimitMs}ms limit with a $($env:MP_VERIFY_SLOW_MS)ms one-way slow link" }
if ($hungActions -ne 0) { throw "Windows reported a not-responding window during $hungActions slow-network actions" }
Write-Output "SLOW_NETWORK_OK worst=${worst}ms limit=${slowLimitMs}ms delay=$($env:MP_VERIFY_SLOW_MS)ms"
