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
$result.slowNetwork = @{
    delayMs = [int]$env:MP_VERIFY_SLOW_MS
    proxyPort = [int]$env:MP_VERIFY_SLOW_PORT
    boundary = 'Real app and native window driven through a local TCP delay proxy in front of the repository SSH/tmux stand-in; the delay is real TCP latency, the remote host is synthetic'
    stallLimitMs = $slowLimitMs
}
$script:slowActions = New-Object System.Collections.Generic.List[object]
$script:slowInputErrors = New-Object System.Collections.Generic.List[string]

function Save-SlowTimings {
    $actions = @($script:slowActions.ToArray())
    $worst = if ($actions.Count -gt 0) { [int](($actions | ForEach-Object { [int]$_.maxPumpMs } | Measure-Object -Maximum).Maximum) } else { 0 }
    $hung = @($actions | Where-Object { $_.hung -eq $true -or $_.hadError -eq $true }).Count
    Save-Json @{
        limitMs = $slowLimitMs
        delayMs = [int]$env:MP_VERIFY_SLOW_MS
        actions = $actions
        worstMs = $worst
        hungActions = $hung
        inputErrors = @($script:slowInputErrors.ToArray())
        passed = ($worst -le $slowLimitMs -and $hung -eq 0)
    } 'slow-network-timings.json'
    $null = $result.slowNetwork.worstMs = $worst
    $null = $result.slowNetwork.hungActions = $hung
}

function Measure-PumpWindow([scriptblock]$Action, [int]$WindowMs) {
    $started = [Diagnostics.Stopwatch]::StartNew()
    $script:slowActionError = ''
    try { & $Action } catch { $script:slowActionError = $_.Exception.Message }
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
    $entry = @{ startedAt = [DateTime]::UtcNow.ToString('o'); elapsedMs = [int]$started.ElapsedMilliseconds; maxPumpMs = [int][Math]::Ceiling($longest); samples = $samples; hung = $hung; hadError = ($script:slowActionError -ne '') }
    if ($script:slowActionError) {
        $entry.inputError = $script:slowActionError
        $script:slowInputErrors.Add($script:slowActionError)
    }
    $script:slowActions.Add($entry)
    $null = Save-SlowTimings
    $entry
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

$switches = New-Object System.Collections.Generic.List[object]
for ($index = 0; $index -lt 10; $index++) {
    $offset = (Read-SharedText $slowLog).Length
    $before = (Read-Session).active_tab
    $action = [Diagnostics.Stopwatch]::StartNew()
    $sample = Measure-PumpWindow { Press @(0x11, 0x09) "Ctrl+Tab session switch $($index + 1) while the remote link is slow" } 3000
    $sample.kind = 'switch'
    $sample.index = $index
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    $switched = $false
    if ($sample.hadError -ne $true) {
        do {
            $trace = (Read-SharedText $slowLog).Substring($offset)
            $state = Read-Session
            if ($trace -match 'switchToShell: \d+ -> \d+' -or ($null -ne $state -and [int]$state.active_tab -ne [int]$before)) {
                $sample.responseMs = [int]$action.ElapsedMilliseconds
                $switched = $true
                break
            }
            Start-Sleep -Milliseconds 100
        } while ([DateTime]::UtcNow -lt $deadline)
    }
    if (-not $switched -and $sample.hadError -ne $true) { throw "Session switch $index never changed the selected session under the slow link" }
    $switches.Add($sample)
    if ($index -eq 4) { Snapshot 'slow-network-switch' }
}
$result.slowNetwork.switchMaxPumpMs = [int](($switches | ForEach-Object { [int]$_.maxPumpMs } | Measure-Object -Maximum).Maximum)
$result.slowNetwork.switchHung = @($switches | Where-Object { $_.hung -eq $true -or $_.hadError -eq $true }).Count -gt 0

$openChat = Measure-PumpWindow { Press @(0x12, 0x43) 'Alt+C: open Chat View for the selected remote session' } 3000
$openChat.kind = 'chat-view'
$result.slowNetwork.chatViewMaxPumpMs = [int]$openChat.maxPumpMs
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
$result.slowNetwork.typingHung = @($typing | Where-Object { $_.hung -eq $true -or $_.hadError -eq $true }).Count -gt 0
Snapshot 'slow-network-typing'

Save-SlowTimings
Snapshot 'after'
$worst = $result.slowNetwork.worstMs
$hungActions = $result.slowNetwork.hungActions
$result.checks += @{ name = 'slow-network'; sessions = 2; switches = $switches.Count; typed = $typed.Length; worstMs = $worst; limitMs = $slowLimitMs; hungActions = $hungActions; delayMs = [int]$env:MP_VERIFY_SLOW_MS }

if ($hungActions -ne 0) { throw "Windows reported a not-responding window or refused input during $hungActions slow-network actions: $($script:slowInputErrors -join '; ')" }
if ($worst -gt $slowLimitMs) { throw "UI stall ${worst}ms exceeded the ${slowLimitMs}ms limit with a $($env:MP_VERIFY_SLOW_MS)ms one-way slow link" }
Write-Output "SLOW_NETWORK_OK worst=${worst}ms limit=${slowLimitMs}ms delay=$($env:MP_VERIFY_SLOW_MS)ms"
