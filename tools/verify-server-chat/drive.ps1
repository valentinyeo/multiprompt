param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)][string]$ExpectedHash,
    [Parameter(Mandatory)][string]$Evidence,
    [switch]$Busy,
    [switch]$FreshStart
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Use a GitHub Windows runner' }
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
$profile = Join-Path $env:RUNNER_TEMP ('server-chat-' + [guid]::NewGuid().ToString('N'))
$settings = Join-Path $profile 'roaming/ZigShell'
$actions = [Collections.Generic.List[object]]::new()
$result = @{ feature = $(if ($Busy) { 'server-chat-busy' } elseif ($FreshStart) { 'server-chat-fresh-start' } else { 'server-chat' }); status = 'failed'; version = $ExpectedVersion; sha256 = $ExpectedHash; cases = @(); agentBoundary = 'Real Windows app, Windows OpenSSH, WSL Linux OpenSSH server, tmux and production host/reader. Only the paid Claude process is a deterministic stream-json provider. Clear proves server receipt and a subsequent reply, not Claude context erasure.' }
$job = $null
$recorder = $null
$writer = $null
Start-Transcript "$Evidence/driver.log"
function Save($Value, [string]$Path) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 15), [Text.UTF8Encoding]::new($false)) }
function Wait-For([string]$Name, [scriptblock]$Check, [int]$Seconds = 90) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 200 } while ($timer.Elapsed.TotalSeconds -lt $Seconds)
    throw "Timed out: $Name"
}
function Log-Text([string]$path = "$settings/debug.log") {
    if (-not (Test-Path $path)) { return '' }
    $stream = [IO.File]::Open($path, 'Open', 'Read', ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    try { $reader = [IO.StreamReader]::new($stream); try { $reader.ReadToEnd() } finally { $reader.Dispose() } } finally { $stream.Dispose() }
}
function Doctor {
    $app.Refresh()
    if ($app.HasExited -or $app.Path -ne $Exe -or [ChatDeliveryDesktop]::Owner($main) -ne $app.Id -or [ChatDeliveryDesktop]::Class($main) -ne 'ZigShell') { throw 'Doctor: owned app identity changed' }
    $element = [Windows.Automation.AutomationElement]::FromHandle($main)
    if ($element.Current.IsOffscreen -or $element.Current.ProcessId -ne $app.Id) { throw 'Doctor: app is not visible' }
}
function Shot([string]$Name) {
    $bitmap = [Drawing.Bitmap]::new([ChatDeliveryDesktop]::GetSystemMetrics(0), [ChatDeliveryDesktop]::GetSystemMetrics(1))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen(0, 0, 0, 0, $bitmap.Size); $bitmap.Save("$Evidence/$Name.png", [Drawing.Imaging.ImageFormat]::Png) } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Press([int[]]$Keys, [string]$Label) {
    Doctor
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $main) }
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Refusing input outside the owned app' }
    $actions.Add(@{ input = $Label; keys = $Keys; at = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() })
    [ChatDeliveryDesktop]::Chord($Keys)
    Start-Sleep -Milliseconds 150
}
function Type-Text([string]$Text) {
    $actions.Add(@{ input = 'type'; text = $Text; at = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() })
    foreach ($letter in $Text.ToCharArray()) { Doctor; [ChatDeliveryDesktop]::Character($letter); Start-Sleep -Milliseconds 20 }
}
function Copy-Chat([string]$Name) {
    $offset = (Log-Text).Length
    Press @(0x11, 0x4B) 'Ctrl+K: open command palette'
    [void](Wait-For 'palette ready' { (Log-Text).Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    Type-Text 'chat view select all'
    [void](Wait-For 'select all messages command' { (Log-Text).Substring($offset) -match '\[palette\] ready chars=20 count=\d+ target=6364(?:\s|$)' })
    Press @(0x0D) 'Enter: select rendered messages'
    Press @(0x11, 0x43) 'Ctrl+C: copy rendered messages'
    $text = [Windows.Forms.Clipboard]::GetText()
    [IO.File]::WriteAllText("$Evidence/$Name.txt", $text)
    Press @(0x1B) 'Escape: return to composer'
    return $text
}
function Fresh-Chat {
    $offset = (Log-Text).Length
    Press @(0x11, 0x4B) 'Ctrl+K: open command palette'
    [void](Wait-For 'palette ready' { (Log-Text).Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    Type-Text 'chat view fresh start'
    [void](Wait-For 'fresh start command' { (Log-Text).Substring($offset) -match '\[palette\] ready chars=21 count=\d+ target=6498(?:\s|$)' })
    Press @(0x0D) 'Enter: fresh start of this chat'
}
function Send-Line([string]$Text) {
    $composer = Wait-For 'owned composer' { $h = [ChatDeliveryDesktop]::Composer($main); if ($h -ne [IntPtr]::Zero) { $h } }
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
    Type-Text $Text
    [void](Wait-For 'exact composer text' { [ChatDeliveryDesktop]::Text($composer) -ceq $Text })
    if ($Text.StartsWith('/')) { Press @(0x1B) 'Escape: dismiss slash completion without changing the text' }
    Press @(0x0D) 'Enter: send to real server'
    [void](Wait-For 'composer cleared' { [ChatDeliveryDesktop]::Text($composer) -ceq '' })
}
function Server-Snapshot([string]$Name) {
    $raw = & $ssh -F "$settings/ssh-key/config" remote-1 "python3 $repo/tools/verify-server-chat/snapshot.py"
    if ($LASTEXITCODE -ne 0) { throw 'Real SSH evidence read failed' }
    $snapshot = ($raw -join "`n") | ConvertFrom-Json
    Save $snapshot "$Evidence/$Name.json"
    return $snapshot
}
try {
    & "$PSScriptRoot/start.ps1" -Profile $profile -Evidence $Evidence
    $repo = (& wsl.exe -d Ubuntu-24.04 -u root --exec wslpath -a $env:GITHUB_WORKSPACE).Trim()
    $ssh = "$env:SystemRoot/System32/OpenSSH/ssh.exe"
    $env:APPDATA = "$profile/roaming"
    $env:LOCALAPPDATA = "$profile/local"
    $env:USERPROFILE = "$profile/home"
    $env:HOME = "$profile/home"
    $env:MULTIPROMPT_NO_LOGIN = '1'
    $env:ZIGSHELL_DEBUG = '1'
    $env:IGSH_246 = '0'
    $env:PATH = (Split-Path $ssh) + ';' + $env:PATH
    & python "$PSScriptRoot/../../.claude/skills/verify-multiprompt/seed-profile.py" --root $profile --home "$profile/home" --settings $settings --evidence $Evidence
    if ($LASTEXITCODE -ne 0) { throw 'Large saved-chat seed failed' }
    Save @{ active_tab = 0; single_window = $false; chat_active = $false; tabs = @(@{ kind = 'tmux'; name = 'Runner server chat'; manual = $true; tmux_host = 0; tmux_session = 'live-ci'; csid = 'a1b2c3d4-2567-4000-8000-000000002567'; cv = $false; pid = 0 }) } "$settings/session.json"
    if ((Get-FileHash $Exe -Algorithm SHA256).Hash -ine $ExpectedHash -or -not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable checksum/version mismatch' }
    Add-Type -AssemblyName System.Drawing, System.Windows.Forms, UIAutomationClient, UIAutomationTypes
    Add-Type -Path "$PSScriptRoot/../verify-chat-delivery/desktop.cs"
    Add-Type -Path "$PSScriptRoot/../verify-chat-delivery/job.cs"
    [void][ChatDeliveryDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
    $recorder = [Diagnostics.Process]::new()
    $recorder.StartInfo = [Diagnostics.ProcessStartInfo]::new((Get-Command ffmpeg.exe).Source, "-y -f gdigrab -framerate 10 -i desktop -c:v libx264 -preset ultrafast -pix_fmt yuv420p `"$Evidence/journey.mp4`"")
    $recorder.StartInfo.UseShellExecute = $false
    $recorder.StartInfo.RedirectStandardInput = $true
    $recorder.StartInfo.RedirectStandardError = $true
    [void]$recorder.Start()
    $videoLog = $recorder.StandardError.ReadToEndAsync()
    $writer = $recorder.StandardInput
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $profile, "$Evidence/stdout.log", "$Evidence/stderr.log", '--no-window-restore')
    $main = Wait-For 'owned app window' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    Press @(0x11, 0x31) 'Ctrl+1: open server tab'
    Press @(0x12, 0x43) 'Alt+C: open server Chat View'
    [void](Wait-For 'server transcript loaded' { (Log-Text) -match '\[chat\] transcript load shell=\d+ ok' })
    $opened = Copy-Chat 'open-copied'
    if (-not $opened.Contains('Server received: server seed') -or -not $opened.Contains('Synthetic chat 00 answer 1199.')) { throw 'Open did not show the real server reply and long seeded history' }
    Shot 'open'
    $result.cases += @{ name = 'open'; passed = $true; detail = 'Copied the host-persisted seed reply from the real UI' }
    $scenarios = @(@{ name = 'send'; text = 'windows send proof' })
    if (-not $Busy -and -not $FreshStart) { $scenarios += @(@{ name = 'clear'; text = '/clear' }, @{ name = 'after-clear'; text = 'windows after clear' }) }
    foreach ($case in $scenarios) {
        Send-Line $case.text
        [void](Wait-For ('server receipt for ' + $case.name) { $snapshot = Server-Snapshot ($case.name + '-server'); @($snapshot.inputs | Where-Object { $_.text -ceq $case.text }).Count -eq 1 })
        [void](Wait-For ('painted reply for ' + $case.name) { (Copy-Chat ($case.name + '-copied')).Contains('Server received: ' + $case.text) } 30)
        Shot $case.name
        $result.cases += @{ name = $case.name; passed = $true; detail = 'Exactly one provider receipt over real SSH and a copied rendered reply' }
    }
    Save @{ pid = $app.Id; hwnd = $main.ToInt64(); exe = $app.Path; sha256 = $ExpectedHash; visible = $true } "$Evidence/doctor.json"
    if ($FreshStart) {
        $beforeFresh = Server-Snapshot 'fresh-before'
        Copy-Item "$settings/session.json" "$Evidence/fresh-tab-before.json"
        Fresh-Chat
        [void](Wait-For 'fresh context resumed in the same public chat' {
            $state = Server-Snapshot 'fresh-after'
            $hostState = @($state.hosts | Where-Object { $_.sid -ceq 'a1b2c3d4-2567-4000-8000-000000002567' -and $_.alive -and -not $_.freshPhase })
            $state.provider.pid -ne $beforeFresh.provider.pid -and $hostState.Count -eq 1 -and @($state.inputs | Where-Object { $_.text.StartsWith('You are the same chat after a fresh start.') }).Count -eq 1
        }))
        $freshText = Copy-Chat 'fresh-copied'
        if (-not $freshText.Contains('Synthetic chat 00 answer 1199.') -or -not $freshText.Contains('Server received: windows send proof')) { throw 'Fresh start lost the readable history' }
        Shot 'fresh-after'
        $result.cases += @{ name = 'fresh-start-rotates'; passed = $true; detail = 'Actual palette Fresh start rotated the native provider process and retained the public tab history' }
        $actions.Add(@{ input = 'replace ended host through production CLI in the same tmux pane'; at = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() })
        $raw = & $ssh -F "$settings/ssh-key/config" remote-1 "python3 $repo/tools/verify-server-chat/replace-chat.py $repo"
        if ($LASTEXITCODE -ne 0) { throw 'Replacement chat lifecycle setup failed' }
        $replacement = ($raw -join "`n") | ConvertFrom-Json
        Save $replacement "$Evidence/replacement.json"
        [void](Server-Snapshot 'replacement-before')
        Fresh-Chat
        Shot 'replacement-fresh-start'
        $visible = $false
        try {
            [void](Wait-For 'same tab follows the fresh replacement' { (Copy-Chat 'replacement-copied').Contains('Server received: fresh replacement seed') } 30)
            $visible = $true
        } catch { $result.replacementViewError = $_.Exception.Message }
        Send-Line 'after fresh replacement'
        $received = $false
        try {
            [void](Wait-For 'same tab delivers to the replacement' {
                $state = Server-Snapshot 'replacement-after'
                $native = @($state.hosts | Where-Object { $_.sid -ceq $replacement.new -and $_.alive })
                $native.Count -eq 1 -and @($state.inputs | Where-Object { $_.text -ceq 'after fresh replacement' -and $_.sid -ceq $native[0].native_session -and $_.pid -eq $state.provider.pid }).Count -eq 1
            } 30)
            [void](Wait-For 'replacement reply is painted' { (Copy-Chat 'replacement-reply-copied').Contains('Server received: after fresh replacement') } 30)
            $received = $true
        } catch { $result.replacementSendError = $_.Exception.Message }
        [void](Server-Snapshot 'replacement-after')
        Copy-Item "$settings/session.json" "$Evidence/fresh-tab-after.json"
        if (Test-Path "$settings/chat-outbox.json") { Copy-Item "$settings/chat-outbox.json" "$Evidence/replacement-outbox.json" }
        Shot 'replacement-after'
        $result.cases += @{ name = 'replacement-follows'; passed = $visible; detail = 'The unchanged saved tab displays the new live chat in the same tmux pane after its previous host ended' }
        $result.cases += @{ name = 'replacement-send'; passed = $received; detail = 'One native composer send reaches the replacement provider and paints its reply' }
        if (-not $visible -or -not $received) { throw 'Tab still points at the old chat after a fresh replacement; inspect the native saved tab, host states, receipts and video' }
    }
    if ($Busy) {
        Send-Line 'busy server turn'
        [void](Wait-For 'provider is still inside the busy turn' { (Server-Snapshot 'busy-start').provider.busy })
        Send-Line 'follow-up during busy turn'
        $busyClock = [Diagnostics.Stopwatch]::StartNew()
        while ($busyClock.Elapsed.TotalSeconds -lt 611) {
            Doctor
            Start-Sleep -Seconds 1
        }
        $busyClock.Stop()
        $outboxText = Log-Text "$settings/chat-outbox.json"
        if (-not $outboxText) { throw 'Cannot observe the native pending message' }
        [IO.File]::WriteAllText("$Evidence/busy-outbox.json", $outboxText)
        $outbox = $outboxText | ConvertFrom-Json
        $pending = @($outbox.queues | ForEach-Object { $_.messages } | Where-Object { $_.t -ceq 'follow-up during busy turn' })
        $notSent = @($pending | Where-Object { $_.v1 -eq 1 -and $_.s -ne 4 -and ($_.s -eq 2 -or $_.phase -ceq 'failed' -or ($_.s -ne 3 -and $_.phase -notin @('accepted', 'started'))) }).Count -gt 0
        $beforeStop = Server-Snapshot 'busy-before-stop'
        Shot 'busy-before-stop'
        $stop = Wait-For 'painted Stop button' {
            $frame = ((Log-Text) -split '\[chat\] composer card')[-1]
            $button = [regex]::Match($frame, '\[chat\] stop rect (-?\d+),(-?\d+),(-?\d+),(-?\d+)')
            if ($button.Success) { $button }
        }
        Doctor
        $x = [int](([int]$stop.Groups[1].Value + [int]$stop.Groups[3].Value) / 2)
        $y = [int](([int]$stop.Groups[2].Value + [int]$stop.Groups[4].Value) / 2)
        [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, [ChatDeliveryDesktop]::Composer($main))
        if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Refusing Stop click outside the owned app' }
        $actions.Add(@{ input = 'click painted Stop'; x = $x; y = $y; at = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() })
        [ChatDeliveryDesktop]::PressClient($main, $app.Id, $x, $y)
        $stopClock = [Diagnostics.Stopwatch]::StartNew()
        do {
            $afterStop = Server-Snapshot 'busy-after-stop'
            $interrupts = @($afterStop.controls | Where-Object { $_.request.subtype -ceq 'interrupt' })
            $ended = @($afterStop.tables.message_events | ForEach-Object { $_.body | ConvertFrom-Json } | Where-Object { $_.PSObject.Properties['kind'] -and $_.kind -ceq 'turn.ended' -and $_.payload.status -ceq 'interrupted' })
            $stopEffective = $interrupts.Count -eq 1 -and -not $afterStop.provider.busy -and $ended.Count -eq 1
            if ($stopEffective) { break }
            Start-Sleep -Milliseconds 200
        } while ($stopClock.Elapsed.TotalSeconds -lt 10)
        $stopClock.Stop()
        Shot 'busy-after-stop'
        $received = $false
        if ($stopEffective) {
            try {
                [void](Wait-For 'queued follow-up reached the provider after Stop' {
                    $snapshot = Server-Snapshot 'busy-follow-up'
                    @($snapshot.inputs | Where-Object { $_.text -ceq 'follow-up during busy turn' }).Count -eq 1
                } 30)
                [void](Wait-For 'follow-up reply painted in the real transcript' {
                    (Copy-Chat 'busy-follow-up-copied').Contains('Server received: follow-up during busy turn')
                } 30)
                $received = $true
            } catch { $result.followUpError = $_.Exception.Message }
        }
        $result.reproduction = @{ notSent = $notSent; stopIneffective = -not $stopEffective; matchesReport = $notSent -and -not $stopEffective; waitedMilliseconds = $busyClock.ElapsedMilliseconds; stopMilliseconds = $stopClock.ElapsedMilliseconds; providerPid = $beforeStop.provider.pid }
        $result.cases += @{ name = 'busy-message-kept'; passed = -not $notSent; detail = 'Native pending state and screenshot after the real ten-minute delivery budget' }
        $result.cases += @{ name = 'stop-interrupts'; passed = $stopEffective; detail = 'Real Stop click, independent provider control receipt and production interrupted event within ten seconds' }
        $result.cases += @{ name = 'busy-follow-up'; passed = $received; detail = 'Exactly one provider receipt and copied reply after interrupting the previous turn' }
        Save $result.reproduction "$Evidence/reproduction.json"
        if (@($result.cases | Where-Object { -not $_.passed }).Count) { throw 'Busy server chat regression; inspect reproduction.json, native outbox, server snapshots and video' }
    }
    $result.status = 'passed'
} catch {
    $result.error = $_.ToString()
    if ($null -ne $job) { Shot 'failure' }
    throw
} finally {
    if ($null -ne $job) { $cleanup = $job.Stop(); $result.cleanup = @{ activeAfterStop = $cleanup.ActiveProcesses }; $job.Dispose() }
    if ($null -ne $recorder) {
        $writer.WriteLine('q')
        if (-not $recorder.WaitForExit(15000)) { $recorder.Kill(); $recorder.WaitForExit() }
        [IO.File]::WriteAllText("$Evidence/video.log", $videoLog.GetAwaiter().GetResult())
        $result.videoExit = $recorder.ExitCode
        if ($recorder.ExitCode -ne 0 -or -not (Test-Path "$Evidence/journey.mp4") -or (Get-Item "$Evidence/journey.mp4").Length -lt 1024) { $result.status = 'failed'; $result.error = 'Video recording failed' }
        $recorder.Dispose()
    }
    if (Test-Path "$settings/debug.log") { Copy-Item "$settings/debug.log" "$Evidence/debug.log" }
    try {
        $linuxEvidence = (& wsl.exe -d Ubuntu-24.04 -u root --exec wslpath -a $Evidence).Trim()
        & wsl.exe -d Ubuntu-24.04 -u root --exec bash -c 'cp /tmp/mp-ci-sshd.log "$1/sshd.log"; pkill -u mpverify || true; kill "$(cat /tmp/mp-ci-sshd.pid)"' bash $linuxEvidence
        if ($LASTEXITCODE -ne 0) { throw 'Linux evidence collection or cleanup failed' }
    } catch {
        $result.cleanupError = $_.ToString()
        $result.status = 'failed'
    }
    & wsl.exe --terminate Ubuntu-24.04
    Remove-Item -LiteralPath $profile -Recurse -Force -ErrorAction SilentlyContinue
    $result.keyRemoved = -not (Test-Path "$settings/ssh-key/multibot_ed25519")
    if (-not $result.keyRemoved) { $result.status = 'failed'; $result.error = 'Private key cleanup failed' }
    Save $actions "$Evidence/actions.json"
    Save $result "$Evidence/result.json"
    Stop-Transcript
}
if ($result.status -ne 'passed') { throw $result.error }
