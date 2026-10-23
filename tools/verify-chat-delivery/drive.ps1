param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$Ssh,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)][string]$ExpectedHash,
    [Parameter(Mandatory)][string]$Evidence
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Run only through verify.yml on GitHub Windows through the desktop workflow' }
$Exe = (Resolve-Path $Exe).Path
$Ssh = (Resolve-Path $Ssh).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
Start-Transcript "$Evidence/driver.log"
Add-Type -AssemblyName System.Drawing, UIAutomationClient, UIAutomationTypes
Add-Type -Path "$PSScriptRoot/desktop.cs"
Add-Type -Path "$PSScriptRoot/job.cs"
[void][ChatDeliveryDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
$plans = @(
    @{name='busy-send'; mode='busy'; text='busy delivery alpha'},
    @{name='idle-suggestion'; mode='idle'; text='idle delivery beta'},
    @{name='steer-chord'; mode='busy'; text='steer delivery gamma'},
    @{name='wrapped-leftover'; mode='busy'; text='wrapped delivery delta'; leftover='earlier long message about the weekly plan that keeps wrapping across rows'}
)
$results = @($plans | ForEach-Object { @{name=$_.name; passed=$false; detail='Case has not completed'} })
$actions = [Collections.Generic.List[object]]::new()
$env:MP_VERIFY_PYTHON = (Get-Command python.exe).Source
$env:MP_VERIFY_BOUNDARY = (Resolve-Path "$PSScriptRoot/boundary.py").Path
$env:PATH = (Split-Path $Ssh) + ';' + $env:PATH
$env:PYTHONUTF8 = '1'
$env:PYTHONIOENCODING = 'utf-8'
$env:MULTIPROMPT_NO_LOGIN = '1'
$env:ZIGSHELL_DEBUG = '1'
$env:IGSH_246 = '0'
foreach ($file in @('agent-buffer.jsonl', 'invocations.jsonl', 'debug.log')) { [IO.File]::WriteAllText("$Evidence/$file", '') }
function Save($Value, [string]$Path) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false)) }
function Wait-For([string]$Description, [scriptblock]$Check, [int]$Seconds = 60) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 100 } while ($timer.Elapsed.TotalSeconds -lt $Seconds)
    throw "Timed out: $Description"
}
function Shot([string]$Name) {
    $bitmap = [Drawing.Bitmap]::new([ChatDeliveryDesktop]::GetSystemMetrics(0), [ChatDeliveryDesktop]::GetSystemMetrics(1))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen(0, 0, 0, 0, $bitmap.Size); $bitmap.Save("$Evidence/$Name.png", [Drawing.Imaging.ImageFormat]::Png) }
    finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Doctor([bool]$Chat = $false) {
    $app.Refresh()
    if ($app.HasExited -or $app.Path -ne $Exe -or (Get-FileHash $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Doctor: executable identity mismatch' }
    if ([ChatDeliveryDesktop]::Owner($main) -ne $app.Id -or [ChatDeliveryDesktop]::Class($main) -ne 'ZigShell') { throw 'Doctor: owned main HWND missing' }
    $element = [System.Windows.Automation.AutomationElement]::FromHandle($main)
    $title = $element.Current.Name
    if ($element.Current.IsOffscreen -or $element.Current.ProcessId -ne $app.Id -or $title -notmatch ('multiprompt v' + [regex]::Escape($ExpectedVersion) + '(?:\s|$)')) { throw 'Doctor: visible versioned UI Automation identity missing' }
    $published = Get-Content "$settings/inbox-default.json" -Raw | ConvertFrom-Json
    if (@($published.shells).Count -ne 1 -or $published.shells[0].kind -ne 3) { throw 'Doctor: saved tmux shell was not published' }
    if ($Chat) {
        $focus = [ChatDeliveryDesktop]::Focus($main)
        if ($focus[0] -ne $main.ToInt64() -or $focus[1] -ne $composer.ToInt64()) { throw 'Doctor: owned composer must have foreground typing focus' }
    }
    $identity = @{pid=$app.Id; exe=$app.Path; hwnd=$main.ToInt64(); title=$title; version=$ExpectedVersion; sha256=$ExpectedHash; tmux=$true; chat=$Chat; focus=$(if ($Chat) { $focus } else { @() }); composer=$(if ($Chat) { $composer.ToInt64() } else { 0 })}
    Save $identity "$caseDir/doctor.json"
}
function Press([int[]]$Keys, [string]$Label, [bool]$Chat = $false) {
    Doctor
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) {
        $target = if ($Chat) { $composer } else { $main }
        [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $target)
    }
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Refusing keyboard input: owned app is not foreground' }
    if ($Chat) { Doctor $true }
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Refusing keyboard input: owned app is not foreground' }
    $actions.Add(@{case=$plan.name; ms=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); input=$Label; keys=$Keys})
    [ChatDeliveryDesktop]::Chord($Keys)
    Start-Sleep -Milliseconds 100
}
foreach ($plan in $plans) {
    $caseDir = "$Evidence/$($plan.name)"
    New-Item -ItemType Directory -Force $caseDir | Out-Null
    $profile = Join-Path $env:RUNNER_TEMP ('chat-delivery-' + [guid]::NewGuid().ToString('N'))
    $state = "$profile/state"
    $settings = "$profile/roaming/ZigShell"
    $app = $null
    $job = $null
    $main = [IntPtr]::Zero
    $composer = [IntPtr]::Zero
    $observation = @{name=$plan.name; text=$plan.text; mode=$plan.mode; suggestion='Try asking about the next step'; actionMs=0; endMs=0; error=$null}
    $cleanup = @{remaining_owned_processes=-1; evidence_preserved=$false; scratch_removed=$false}
    try {
        New-Item -ItemType Directory -Force $state, $settings, "$profile/local", "$profile/home" | Out-Null
        $env:APPDATA = "$profile/roaming"
        $env:LOCALAPPDATA = "$profile/local"
        $env:USERPROFILE = "$profile/home"
        $env:HOME = "$profile/home"
        $env:MP_VERIFY_STATE = $state
        [IO.File]::WriteAllText("$settings/ssh-path.txt", $Ssh)
        $seed = @{name=$plan.name; mode=$plan.mode; suggestion=$observation.suggestion}
        if ($plan.ContainsKey('leftover')) { $seed.leftover = $plan.leftover; $observation.leftover = $plan.leftover }
        Save $seed "$state/state.json"
        [IO.File]::WriteAllText("$state/agent-buffer.jsonl", '')
        Save @{active_tab=0; single_window=$false; chat_active=$false; tabs=@(@{kind='tmux'; name='Verify agent'; manual=$true; tmux_host=0; tmux_session='verify-agent'; cv=$false; pid=0})} "$settings/session.json"
        Copy-Item "$settings/session.json" "$caseDir/seed-session.json"
        if (-not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable embedded version mismatch' }
        $job = [VerifyJob]::new()
        $app = $job.Start($Exe, $profile, "$caseDir/stdout.log", "$caseDir/stderr.log", '--no-window-restore')
        $main = Wait-For 'owned app window' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
        [void](Wait-For 'stand-in console rendered and app published saved tmux tab' { (Test-Path "$state/ready.json") -and (Test-Path "$settings/inbox-default.json") })
        [void](Wait-For 'owned app foreground' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $main) })
        Press @(0x11, 0x31) 'Ctrl+1: select saved tmux tab'
        Shot "$($plan.name)-before"
        if ($plan.name -eq 'busy-send') { Shot 'before' }
        Press @(0x12, 0x43) 'Alt+C: open Chat View'
        $composer = Wait-For 'native Chat View composer' { $h = [ChatDeliveryDesktop]::Composer($main); if ($h -ne [IntPtr]::Zero) { $h } } 20
        [void](Wait-For 'composer typing focus' { $f = [ChatDeliveryDesktop]::Focus($main); $f[0] -eq $main.ToInt64() -and $f[1] -eq $composer.ToInt64() })
        Doctor $true
        $actions.Add(@{case=$plan.name; ms=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); input='type composer text'; text=$plan.text})
        foreach ($letter in $plan.text.ToCharArray()) {
            Doctor $true
            [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter))
            Start-Sleep -Milliseconds 30
        }
        $observation.composerText = [ChatDeliveryDesktop]::Text($composer)
        if ($observation.composerText -cne $plan.text) { throw 'Real keyboard composer text mismatch' }
        Shot "$($plan.name)-action"
        $observation.actionMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        if ($plan.name -eq 'steer-chord') {
            Press @(0x11, 0x58) 'Ctrl+X: steer prefix' $true
            Press @(0x11, 0x53) 'Ctrl+S: steer send' $true
        } else { Press @(0x0D) 'Enter: send composer' $true }
        $deadline = $observation.actionMs + 15000
        while ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() -lt $deadline) { Start-Sleep -Milliseconds 100 }
        $observation.endMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        Doctor $true
        Copy-Item "$settings/session.json" "$caseDir/session-chat.json"
        Shot "$($plan.name)-after"
    } catch {
        $observation.error = $_.ToString()
        $observation.error | Set-Content "$caseDir/error.txt"
    } finally {
        try { Shot "$($plan.name)-final"; Shot 'after' } catch { $observation.error = "Screenshot: $_" }
        try {
            if ($app -and -not $app.HasExited) { [void]$app.CloseMainWindow(); [void]$app.WaitForExit(3000) }
            if ($job) { $stopped = $job.Stop(); $cleanup.remaining_owned_processes = $stopped.ActiveProcesses; Save $stopped "$caseDir/process-tree.json" }
        } catch { $observation.error = "Owned cleanup: $_" } finally { if ($job) { $job.Dispose() } }
        try {
            if (Test-Path "$settings/debug.log") { Copy-Item "$settings/debug.log" "$caseDir/debug.log"; Get-Content "$caseDir/debug.log" | Add-Content "$Evidence/debug.log" }
            if (Test-Path $state) { Copy-Item $state "$caseDir/stand-in" -Recurse -Force }
            foreach ($file in @('agent-buffer.jsonl', 'invocations.jsonl')) {
                $source = "$caseDir/stand-in/$file"
                if (Test-Path $source) { Get-Content $source | Add-Content "$Evidence/$file" }
            }
            if (Test-Path "$settings/session.json") { Copy-Item "$settings/session.json" "$caseDir/session-after.json" }
            $cleanup.evidence_preserved = (Test-Path "$caseDir/debug.log") -and (Test-Path "$caseDir/stand-in/ready.json")
            Remove-Item -LiteralPath $profile -Recurse -Force
            $cleanup.scratch_removed = -not (Test-Path -LiteralPath $profile)
        } catch { $observation.error = "Evidence/cleanup: $_" }
        Save $observation "$caseDir/observation.json"
        Save $cleanup "$caseDir/cleanup.json"
        ($results | Where-Object { $_.name -eq $plan.name }).detail = $(if ($observation.error) { $observation.error } else { 'Awaiting independent buffer evaluation' })
        Save @{feature='chat-delivery'; status='failed'; agentBoundary='stand-in remote shell + fake tmux + scripted agent screen, not real Claude or a real server'; cases=$results} "$Evidence/result.json"
    }
}
Save $actions.ToArray() "$Evidence/actions.json"
$doctors = @($plans | ForEach-Object { $file = "$Evidence/$($_.name)/doctor.json"; if (Test-Path $file) { @{name=$_.name; identity=(Get-Content $file -Raw | ConvertFrom-Json)} } })
Save $doctors "$Evidence/doctor.json"
$cleanups = @($plans | ForEach-Object { Get-Content "$Evidence/$($_.name)/cleanup.json" -Raw | ConvertFrom-Json })
Save @{remaining_owned_processes=($cleanups | Measure-Object remaining_owned_processes -Sum).Sum; evidence_preserved=(@($cleanups | Where-Object { -not $_.evidence_preserved }).Count -eq 0); scratch_removed=(@($cleanups | Where-Object { -not $_.scratch_removed }).Count -eq 0)} "$Evidence/cleanup.json"
Stop-Transcript
& node "$PSScriptRoot/check-evidence.js" $Evidence
if ($LASTEXITCODE -ne 0) { exit 1 }
