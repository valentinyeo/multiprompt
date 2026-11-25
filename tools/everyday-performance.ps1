param([Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string]$Evidence, [Parameter(Mandatory)][string]$Revision, [int]$Count = 100, [int]$Trials = 5, [switch]$Profile)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Measurement requires GitHub-hosted Windows' }
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
@{ revision=$Revision; startedUtc=[DateTime]::UtcNow.ToString('o') } | ConvertTo-Json | Set-Content "$Evidence/setup.json"
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type -Path "$PSScriptRoot/verify-chat-delivery/desktop.cs", "$PSScriptRoot/everyday-performance.cs" -ReferencedAssemblies System, System.Core, System.Drawing, System.Windows.Forms
Add-Type -Path "$PSScriptRoot/verify-chat-delivery/job.cs"
$machine = @{ cores=[Environment]::ProcessorCount; os=[Environment]::OSVersion.VersionString; cpu=(Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, LoadPercentage); processes=(Get-CimInstance Win32_Process | Select-Object Name, ProcessId, KernelModeTime, UserModeTime); revision=$Revision; exeSha256=(Get-FileHash $Exe -Algorithm SHA256).Hash; profile=[bool]$Profile; sampleCount=$Count; sampleCounts=@{ typing=$Count; switching=$Count; opening=[Math]::Min($Count,20); scrolling=$Count; streaming=$Count }; trials=$Trials; qpcFrequency=[EverydayPerformance]::Frequency(); imageOS=$env:ImageOS; imageVersion=$env:ImageVersion; optimization='ReleaseSmall; -Drelease=true; x86_64-windows-gnu'; observer='2ms event wait between incremental log reads; DwmFlush after acknowledgement; no forced repaint'; endpoints=@{ typing='SendInput to exact WM_GETTEXT value plus DwmFlush, not first-pixel latency'; switching='SendInput to target nonempty content paint log plus DwmFlush'; opening='Alt+C to increased nonempty transcript paint count plus DwmFlush; existing 1500ms toggle guard honored outside timed region'; scrolling='SendInput wheel to nonzero move log and subsequent position paint plus DwmFlush'; streaming='append incremental assistant part to reader push and subsequent position paint plus DwmFlush; synthetic local transport, excludes provider/network' } }
$machine | ConvertTo-Json -Depth 8 | Set-Content "$Evidence/machine.json"
for ($trial = 1; $trial -le $Trials; $trial++) {
    $directory = "$Evidence/trial-$trial"
    New-Item -ItemType Directory -Force $directory | Out-Null
    $root = Join-Path $env:RUNNER_TEMP ('everyday-' + [guid]::NewGuid().ToString('N'))
    $env:APPDATA = "$root/roaming"
    $env:LOCALAPPDATA = "$root/local"
    $env:USERPROFILE = "$root/home"
    $env:HOME = "$root/home"
    $env:MP_VERIFY_STATE = "$root/state"
    $env:MP_VERIFY_PYTHON = (Get-Command python.exe).Source
    $env:MP_VERIFY_BOUNDARY = (Resolve-Path "$PSScriptRoot/verify-chat-delivery/boundary.py").Path
    $env:MULTIPROMPT_NO_LOGIN = '1'
    $env:ZIGSHELL_DEBUG = '1'
    $env:IGSH_246 = '0'
    $env:PYTHONUTF8 = '1'
    $settings = "$root/roaming/ZigShell"
    $log = "$settings/debug.log"
    $job = $null
    $app = $null
    $samples = [Collections.Generic.List[object]]::new()
    $failure = $null
    function Await([string]$Name, [scriptblock]$Check, [int]$Seconds = 120) {
        $clock = [Diagnostics.Stopwatch]::StartNew()
        do {
            if ($null -ne $app -and $app.HasExited) { throw "App exited during $Name" }
            $value = & $Check
            if ($value) { return $value }
            [EverydayPerformance]::ObserveFor(10)
        } while ($clock.Elapsed.TotalSeconds -lt $Seconds)
        throw "Timeout: $Name"
    }
    function Read-State { try { [EverydayPerformance]::Tail("$settings/session.json", 0) | ConvertFrom-Json } catch { $null } }
    function Foreground {
        [void](Await 'owned composer foreground' {
            $edit = [ChatDeliveryDesktop]::Composer($main)
            $edit -ne [IntPtr]::Zero -and [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $edit)
        })
    }
    function Save-Sample([string]$Action, [int]$Index, [long]$Start, [double]$Ms, [long]$Offset, [string]$Proof, [double]$InjectedMs = 0) {
        $samples.Add(@{ action=$Action; index=$Index; startQpc=$Start; endQpc=$Start + [long]($Ms * [EverydayPerformance]::Frequency() / 1000); ms=$Ms; inputReturnMs=$InjectedMs; acknowledgedMs=[EverydayPerformance]::LastAcknowledgedMs; compositorWaitMs=[EverydayPerformance]::LastCompositorMs; logOffset=$Offset; proof=$Proof; success=$true })
    }
    try {
        & python "$PSScriptRoot/switch-performance-fixture.py" $root "$(Split-Path $Exe)/ssh.exe"
        if ($LASTEXITCODE -ne 0) { throw 'Fixture failed' }
        Copy-Item "$root/state/workload.json" "$directory/workload.json"
        $job = [VerifyJob]::new()
        $app = $job.Start($Exe, $root, "$directory/stdout.log", "$directory/stderr.log", '--single-window --no-window-restore')
        $main = Await 'owned app window' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
        [void](Await 'ten restored sessions and loaded transcript' {
            $state = Read-State
            $null -ne $state -and @($state.tabs).Count -eq 10 -and ([EverydayPerformance]::Tail($log, 0)).Contains('launch step=browser') -and ([EverydayPerformance]::Tail($log, 0)).Contains('[chat] position ')
        })
        Foreground
        $control = @(1..100 | ForEach-Object { [EverydayPerformance]::CompositorControl() })
        @{ compositorControlMs=$control; load=(Get-CimInstance Win32_Processor | Select-Object Name, LoadPercentage); availableDiskBytes=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($root)).AvailableFreeSpace; activeProcesses=$job.ReadAccounting().ActiveProcesses } | ConvertTo-Json -Depth 6 | Set-Content "$directory/control.json"
        $observer = [Diagnostics.Process]::GetCurrentProcess()
        $observer.Refresh(); $observerBefore = $observer.TotalProcessorTime.TotalMilliseconds
        $app.Refresh(); $appBefore = $app.TotalProcessorTime.TotalMilliseconds
        $trialClock = [Diagnostics.Stopwatch]::StartNew()
        for ($i = 0; $i -lt ($Count + 10); $i++) {
            Foreground
            $before = Read-State
            $target = ($before.active_tab + 1) % 10
            $shell = $before.tabs[$target].shell_id
            $offset = [EverydayPerformance]::Length($log)
            $start = [EverydayPerformance]::Tick()
            [ChatDeliveryDesktop]::Chord(@(0x11, 0x09))
            $injectedMs = ([EverydayPerformance]::Tick() - $start) * 1000.0 / [EverydayPerformance]::Frequency()
            $ms = [EverydayPerformance]::AwaitLog($log, $offset, "[switch] chat content shown shell=$shell ", '', $start, 30000)
            [void](Await 'target persisted after confirmed paint' { $saved = Read-State; $null -ne $saved -and $saved.active_tab -eq $target })
            if ($i -ge 10) { Save-Sample 'switching' ($i - 10) $start $ms $offset "target=$target shell=$shell nonempty paint" $injectedMs }
            [EverydayPerformance]::ObserveFor(100)
        }
        Foreground
        $longShell = (Read-State).tabs[1].shell_id
        $offset = [EverydayPerformance]::Length($log)
        $start = [EverydayPerformance]::Tick()
        [ChatDeliveryDesktop]::Chord(@(0x11, 0x09))
        [void][EverydayPerformance]::AwaitLog($log, $offset, "[switch] chat content shown shell=$longShell ", '', $start, 30000)
        [void](Await 'long chat persisted after confirmed paint' { $saved = Read-State; $null -ne $saved -and $saved.active_tab -eq 1 })
        Foreground
        $edit = [ChatDeliveryDesktop]::Composer($main)
        $expected = [ChatDeliveryDesktop]::Text($edit)
        for ($i = 0; $i -lt ($Count + 10); $i++) {
            $letter = [char](97 + ($i % 26))
            $expected += $letter
            $start = [EverydayPerformance]::Tick()
            $ms = [EverydayPerformance]::Type($main, $app.Id, $edit, $letter, $expected)
            if ($i -ge 10) { Save-Sample 'typing' ($i - 10) $start $ms 0 "exact composer length=$($expected.Length)" ([EverydayPerformance]::LastInjectionMs) }
            [EverydayPerformance]::ObserveFor(60)
        }
        [EverydayPerformance]::Screenshot("$directory/typing.png")
        for ($i = 0; $i -lt ([Math]::Min($Count,20) + 10); $i++) {
            Foreground
            [ChatDeliveryDesktop]::Chord(@(0x12, 0x43))
            [void](Await 'Chat View closed' { [ChatDeliveryDesktop]::Composer($main) -eq [IntPtr]::Zero })
            [EverydayPerformance]::ObserveFor(1600)
            [void](Await 'owned main window foreground before opening' { [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $main); [ChatDeliveryDesktop]::GetForegroundWindow() -eq $main })
            $paintBefore = [EverydayPerformance]::PaintCount($log)
            $offset = [EverydayPerformance]::Length($log)
            $start = [EverydayPerformance]::Tick()
            [ChatDeliveryDesktop]::Chord(@(0x12, 0x43))
            $injectedMs = ([EverydayPerformance]::Tick() - $start) * 1000.0 / [EverydayPerformance]::Frequency()
            $ms = [EverydayPerformance]::AwaitLog($log, $offset, '[chat] position ', '', $start, 30000, $paintBefore)
            Foreground
            if ($i -ge 10) { Save-Sample 'opening' ($i - 10) $start $ms $offset 'closed console to nonempty Chat View' $injectedMs }
            [EverydayPerformance]::ObserveFor(1600)
        }
        $view = [EverydayPerformance]::Transcript($main)
        [void](Await 'transcript focus before scrolling' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $view) })
        [ChatDeliveryDesktop]::Chord(@(0x23))
        [EverydayPerformance]::ObserveFor(500)
        for ($i = 0; $i -lt ($Count + 10); $i++) {
            Foreground
            $delta = if (($i % 20) -lt 10) { 120 } else { -120 }
            $paintBefore = [EverydayPerformance]::PaintCount($log)
            $offset = [EverydayPerformance]::Length($log)
            $start = [EverydayPerformance]::Tick()
            [ChatDeliveryDesktop]::WheelOwnedTranscript($main, $app.Id, $view, $delta)
            $injectedMs = ([EverydayPerformance]::Tick() - $start) * 1000.0 / [EverydayPerformance]::Frequency()
            $ms = [EverydayPerformance]::AwaitLog($log, $offset, "[chat] wheel delta=$delta moved=", '[chat] position ', $start, 30000, $paintBefore)
            $range = [EverydayPerformance]::Tail($log, $offset)
            if ($range -match '\[chat\] wheel delta=-?\d+ moved=0 ') { throw 'No-op scrolling sample' }
            if ($i -ge 10) { Save-Sample 'scrolling' ($i - 10) $start $ms $offset "delta=$delta nonzero scroll and subsequent paint" $injectedMs }
            [EverydayPerformance]::ObserveFor(60)
        }
        [EverydayPerformance]::Screenshot("$directory/scrolling.png")
        [void](Await 'transcript focus' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $view) })
        [ChatDeliveryDesktop]::Chord(@(0x23))
        [EverydayPerformance]::ObserveFor(500)
        $streamPath = "$root/home/.claude/projects/C--verify-work1/a1b2c3d4-1068-4000-8000-000000000001.jsonl"
        if (-not (Test-Path $streamPath)) { throw 'Long chat transcript missing' }
        @{ shell=$longShell; transcriptBytes=(Get-Item $streamPath).Length; rounds=40; source='synthetic Claude incremental assistant parts; real native reader and layout' } | ConvertTo-Json | Set-Content "$directory/long-chat-workload.json"
        $streamText = ''
        $encoding = [Text.UTF8Encoding]::new($false)
        for ($i = 0; $i -lt ($Count + 10); $i++) {
            $streamPiece = "chunk-$i is the next piece of a live reply."
            $streamText += $streamPiece + "`n"
            $row = @{ type='assistant'; timestamp=[DateTime]::UtcNow.ToString('o'); sessionId='a1b2c3d4-1068-4000-8000-000000000001'; uuid=[guid]::NewGuid().ToString(); isSidechain=$false; message=@{ role='assistant'; id="everyday-stream-$trial"; model='claude-opus-5-5'; content=@(@{ type='text'; text=$streamPiece }) } }
            $json = ($row | ConvertTo-Json -Depth 6 -Compress) + "`n"
            $paintBefore = [EverydayPerformance]::PaintCount($log)
            $offset = [EverydayPerformance]::Length($log)
            $start = [EverydayPerformance]::Tick()
            [IO.File]::AppendAllText($streamPath, $json, $encoding)
            $injectedMs = ([EverydayPerformance]::Tick() - $start) * 1000.0 / [EverydayPerformance]::Frequency()
            $ms = [EverydayPerformance]::AwaitLog($log, $offset, "[chat] push shell=$longShell ", '[chat] position ', $start, 30000, $paintBefore)
            if ($i -ge 10) { Save-Sample 'streaming' ($i - 10) $start $ms $offset "incremental part=$i bytes=$($encoding.GetByteCount($json))" $injectedMs }
            [EverydayPerformance]::ObserveFor(37 + (($i * 53) % 113))
        }
        [EverydayPerformance]::Screenshot("$directory/streaming.png")
        Foreground
        [Windows.Forms.Clipboard]::Clear()
        [EverydayPerformance]::CopyTranscript($main, $app.Id)
        [void](Await 'latest streamed part in real rendered transcript copy' { [Windows.Forms.Clipboard]::ContainsText() -and [Windows.Forms.Clipboard]::GetText().Contains($streamPiece) } 30)
        $copied = [Windows.Forms.Clipboard]::GetText()
        $parts = [regex]::Matches($copied, 'chunk-(\d+) is the next piece of a live reply\.')
        $correct = $parts.Count -eq ($Count + 10)
        for ($part = 0; $part -lt $parts.Count; $part++) { if ([int]$parts[$part].Groups[1].Value -ne $part) { $correct = $false } }
        @{ expectedLatest=$streamText; expectedParts=$Count + 10; actualParts=$parts.Count; copiedCharacters=$copied.Length; exactLatestFound=$correct } | ConvertTo-Json | Set-Content "$directory/stream-receipt.json"
        if (-not $correct) { [IO.File]::WriteAllText("$directory/incorrect-transcript.txt", $copied, $encoding); throw 'Stream output has missing, repeated or reordered parts' }
        $observer.Refresh(); $app.Refresh()
        @{ observerCpuMs=$observer.TotalProcessorTime.TotalMilliseconds - $observerBefore; appCpuMs=$app.TotalProcessorTime.TotalMilliseconds - $appBefore; wallMs=$trialClock.Elapsed.TotalMilliseconds; appPid=$app.Id } | ConvertTo-Json | Set-Content "$directory/accounting.json"
    } catch {
        $failure = $_.ToString()
        $failure | Set-Content "$directory/failure.txt"
    } finally {
        @{ trial=$trial; failure=$failure; samples=@($samples.ToArray()); successes=$samples.Count; errors=$(if ($null -ne $failure) { 1 } else { 0 }) } | ConvertTo-Json -Depth 8 | Set-Content "$directory/samples.json"
        [EverydayPerformance]::Screenshot("$directory/final.png")
        if ($null -ne $job) { $stopped = $job.Stop(); $stopped | ConvertTo-Json | Set-Content "$directory/cleanup.json"; $job.Dispose() }
        if (Test-Path $log) { Copy-Item $log "$directory/debug.log" }
        if (Test-Path "$settings/session.json") { Copy-Item "$settings/session.json" "$directory/session.json" }
        Get-ChildItem "$root/state" -Filter '*.stderr.log' -ErrorAction SilentlyContinue | Copy-Item -Destination $directory
        if (Test-Path "$root/state/invocations.jsonl") { Copy-Item "$root/state/invocations.jsonl" "$directory/invocations.jsonl" }
    }
    if ($null -ne $failure) { throw $failure }
}
