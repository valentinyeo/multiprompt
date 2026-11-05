param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)][string]$ExpectedHash,
    [Parameter(Mandatory)][string]$Evidence
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Hosted Windows only' }
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type -Path "$PSScriptRoot/../verify-chat-delivery/desktop.cs"
Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -Path "$PSScriptRoot/../../.claude/skills/verify-multiprompt/control-native.cs"
[void][ChatDeliveryDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
$profile = Join-Path $env:RUNNER_TEMP ('session-actions-' + [guid]::NewGuid().ToString('N'))
$env:APPDATA = Join-Path $profile 'roaming'
$env:LOCALAPPDATA = Join-Path $profile 'local'
$env:USERPROFILE = Join-Path $profile 'home'
$env:HOME = $env:USERPROFILE
$env:MULTIPROMPT_NO_LOGIN = '1'
$env:ZIGSHELL_DEBUG = '1'
$env:IGSH_246 = '0'
$env:MP_VERIFY_STATE = Join-Path $profile 'remote'
$env:MP_VERIFY_PYTHON = (Get-Command python).Source
$env:MP_VERIFY_BOUNDARY = Join-Path $PSScriptRoot 'boundary.py'
$env:PATH = (Split-Path $Exe) + ';' + $env:PATH
$env:PYTHONUTF8 = '1'
$env:PYTHONIOENCODING = 'utf-8'
$settings = Join-Path $env:APPDATA 'ZigShell'
New-Item -ItemType Directory -Force $settings, $env:LOCALAPPDATA, $env:USERPROFILE, $env:MP_VERIFY_STATE | Out-Null
$logPath = Join-Path $settings 'debug.log'
$actions = [Collections.Generic.List[object]]::new()
$checks = [Collections.Generic.List[object]]::new()
$servers = [Collections.Generic.List[object]]::new()
$job = $null
$app = $null
$main = [IntPtr]::Zero
$result = @{status='failed'; checks=$checks; error=$null; cleanup='pending'; boundary='Offline account; synthetic SSH, provider processes and transcripts; real native app and production session-end commands'}
function Save($Value, [string]$Path) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false)) }
function Wait-For([string]$Name, [scriptblock]$Check) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 150 } while ($timer.Elapsed.TotalSeconds -lt 90)
    throw "Timed out: $Name"
}
function Check([string]$Name, [bool]$Condition) {
    $checks.Add(@{name=$Name; passed=$Condition})
    if (!$Condition) { throw "Failed: $Name" }
}
function Session {
    try { Get-Content (Join-Path $settings 'session.json') -Raw | ConvertFrom-Json } catch { $null }
}
function Log {
    if (!(Test-Path $logPath)) { return '' }
    $stream = [IO.File]::Open($logPath, 'Open', 'Read', 'ReadWrite')
    $reader = [IO.StreamReader]::new($stream)
    try { $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function Focus {
    [void](Wait-For 'owned foreground' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, [uint32]$app.Id, $main) })
}
function Press([int[]]$Keys) {
    if ($app.HasExited -or [ChatDeliveryDesktop]::Owner($main) -ne $app.Id -or [ChatDeliveryDesktop]::Class($main) -ne 'ZigShell' -or [ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'Keyboard owner mismatch' }
    $actions.Add(@{at=[DateTime]::UtcNow.ToString('o'); kind='keys'; keys=$Keys})
    [VerifyNative]::Chord($Keys)
}
function Palette([string]$Query, [int]$Target) {
    Focus
    $offset = (Log).Length
    Press @(0x11,0x4b)
    [void](Wait-For 'palette open' { $trace=Log; $trace.Length -ge $offset -and $trace.Substring($offset) -match '\[palette\] ready chars=0 count=[1-9]\d*' })
    $offset = (Log).Length
    [VerifyNative]::Text($Query)
    [void](Wait-For 'palette target' { $trace=Log; $trace.Length -ge $offset -and $trace.Substring($offset) -match ('\[palette\] ready chars='+$Query.Length+' count=[1-9]\d* target='+$Target+'(?:\r?\n|$)') })
    Press @(0x0d)
}
function Shot([string]$Name) {
    $actions.Add(@{at=[DateTime]::UtcNow.ToString('o'); kind='screenshot'; name=$Name})
    $bitmap = [Drawing.Bitmap]::new([ChatDeliveryDesktop]::GetSystemMetrics(0), [ChatDeliveryDesktop]::GetSystemMetrics(1))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen(0, 0, 0, 0, $bitmap.Size); $bitmap.Save((Join-Path $Evidence "$Name.png")) } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Start-App {
    $launchOffset = (Log).Length
    $script:job = [VerifyJob]::new()
    $script:app = $job.Start($Exe, $profile, (Join-Path $profile 'stdout.log'), (Join-Path $profile 'stderr.log'), '--single-window --no-window-restore')
    $script:main = Wait-For 'owned main window' {
        if ($app.HasExited) { throw ('App exited: '+$app.ExitCode) }
        $window = [ChatDeliveryDesktop]::Window([uint32]$app.Id)
        if ($window -ne [IntPtr]::Zero) { $window }
    }
    [void](Wait-For 'both restored transports ready' { $trace=Log; $trace.Length -ge $launchOffset -and [regex]::Matches($trace.Substring($launchOffset), 'ssh-reconnect ok id=\d+').Count -ge 2 })
    [void](Wait-For 'saved remote tabs' { $s=Session; $s -and @($s.tabs | Where-Object { $_.kind -eq 'tmux' }).Count -eq 2 })
    Save @{pid=$app.Id; hwnd=$main.ToInt64(); path=$app.MainModule.FileName; sha256=(Get-FileHash $Exe -Algorithm SHA256).Hash; class=[ChatDeliveryDesktop]::Class($main)} (Join-Path $Evidence ('launch-'+$app.Id+'.json'))
    Focus
}
function Stop-AppJob {
    $stopped = $job.Stop()
    Check 'owned-app-processes-cleaned' ($stopped.ActiveProcesses -eq 0)
    $job.Dispose(); $script:job=$null
}
function Context([int]$Index) {
    Focus
    $pair = Wait-For 'painted sidebar target' {
        $lines = (Log) -split '\r?\n'
        $found = $null
        for ($i=0; $i -lt $lines.Count-1; $i++) {
            if ($lines[$i] -match ('\[sidebar-avatar\] target='+$Index+' face=(\d+) color=(\d+)$')) {
                $face=$Matches[1]; $color=$Matches[2]
                if ($lines[$i+1] -match ('\[bots\] face='+$face+' color='+$color+' rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)$')) { $found=@([int]$Matches[1],[int]$Matches[2],[int]$Matches[3],[int]$Matches[4]) }
            }
        }
        if ($found) { return ,$found }
    }
    $offset = (Log).Length
    [ChatDeliveryDesktop]::RightClickClient($main, [uint32]$app.Id, [int](($pair[0]+$pair[2])/2), [int](($pair[1]+$pair[3])/2))
    [void](Wait-For 'seven ordered context actions' { $trace=Log; $trace.Length -ge $offset -and $trace.Substring($offset) -match '\[palette\] rows chars=0 count=7 ids=7113 7104 7195 6249 7196 7197 7112(?:\s|$)' })
}
try {
    Check 'binary-sha256' ((Get-FileHash $Exe -Algorithm SHA256).Hash.ToLowerInvariant() -eq $ExpectedHash.ToLowerInvariant())
    Check 'embedded-version' ([Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;"))
    $names=@('verify-agent','verify-background')
    $ids=@('a1b2c3d4-1666-4000-8000-000000000001','a1b2c3d4-1666-4000-8000-000000000002')
    $events=@{}; $sids=@{}; $panes=@{}
    for ($i=0; $i -lt 2; $i++) {
        $name=$names[$i]
        $events[$name]='Local\MultipromptProof-'+[guid]::NewGuid().ToString('N')
        $sids[$name]=$ids[$i]; $panes[$name]=4242+$i
        $ready=Join-Path $env:MP_VERIFY_STATE ("server-$i.json")
        $owned=[VerifyJob]::new()
        $server=@{job=$owned; process=$null}
        $servers.Add($server)
        $server.process=$owned.Start($env:MP_VERIFY_PYTHON, $profile, (Join-Path $profile "server-$i.out"), (Join-Path $profile "server-$i.err"), ('-u "'+$PSScriptRoot+'/server.py" "'+$events[$name]+'" "'+$ready+'"'), $true)
        [void](Wait-For 'independent synthetic agent ready' { Test-Path $ready })
    }
    $procRoot=Join-Path ([IO.Path]::GetPathRoot($profile)) 'proc'
    Save @{name='session-actions'; mode='idle'; fake=$true; suggestion=''; sessions=$names; end_events=$events; session_ids=$sids; sids=$sids; panes=$panes; procRoot=$procRoot; home=$env:USERPROFILE; panePid=4242; sid=$ids[0]; cwd='C:/verify/work0'; transcript=(Join-Path $env:USERPROFILE ('.claude/projects/C--verify-work0/'+$ids[0]+'.jsonl'))} (Join-Path $env:MP_VERIFY_STATE 'state.json')
    & $env:MP_VERIFY_PYTHON $env:MP_VERIFY_BOUNDARY shell seed-many 1
    if ($LASTEXITCODE -ne 0) { throw 'Synthetic transcript preparation failed' }
    $transcripts=@(Get-ChildItem (Join-Path $env:USERPROFILE '.claude/projects') -Filter '*.jsonl' -Recurse)
    Check 'two-separate-transcripts' ($transcripts.Count -eq 2)
    $hashes=@($transcripts | ForEach-Object { (Get-FileHash $_.FullName -Algorithm SHA256).Hash })
    Save @{active_tab=0; single_window=$true; chat_active=$false; workspace_count=1; workspaces=@(@{name='Work'; wid='work'}); tabs=@(
        @{kind='tmux'; name='Alpha'; manual=$true; tmux_host=0; tmux_session=$names[0]; csid=$ids[0]; workspace=0; cv=$false; pid=0},
        @{kind='tmux'; name='Beta'; manual=$true; tmux_host=0; tmux_session=$names[1]; csid=$ids[1]; workspace=0; cv=$false; pid=0}
    )} (Join-Path $settings 'session.json')
    [IO.File]::WriteAllText((Join-Path $settings 'ssh-path.txt'), (Join-Path (Split-Path $Exe) 'ssh.exe'))
    Start-App
    Shot 'before'
    Press @(0x11,0x57)
    [void](Wait-For 'Ctrl+W quits' { $app.HasExited })
    Check 'quit-keeps-both-server-agents' (!$servers[0].process.HasExited -and !$servers[1].process.HasExited)
    Stop-AppJob
    Start-App
    Check 'quit-reopen-retains-both-chats' (@((Session).tabs | Where-Object { $_.name -in @('Alpha','Beta') }).Count -eq 2)
    Shot 'after-reopen'
    Press @(0x12,0x58)
    Check 'Alt-X-does-not-end-an-agent' (!$servers[0].process.HasExited -and !$servers[1].process.HasExited)
    Check 'Alt-X-does-not-close-a-chat' (@((Session).tabs | Where-Object { $_.kind -eq 'tmux' }).Count -eq 2)
    Palette 'copy chat id' 7196
    Check 'global-copy-chat-id' ([Windows.Forms.Clipboard]::GetText() -ceq $ids[0])
    Context 1
    Shot 'right-click-seven-actions'
    $menu=[Drawing.Bitmap]::new((Join-Path $Evidence 'right-click-seven-actions.png'))
    $red=0
    try { for ($y=0; $y -lt $menu.Height; $y++) { for ($x=0; $x -lt $menu.Width; $x++) { $pixel=$menu.GetPixel($x,$y); if ($pixel.R -gt 140 -and $pixel.G -lt 110 -and $pixel.B -lt 110) { $red++ } } } } finally { $menu.Dispose() }
    Check 'delete-has-red-pixels' ($red -gt 10)
    for ($i=0; $i -lt 6; $i++) { Press @(0x28) }
    Press @(0x0d)
    [void](Wait-For 'context Delete stops Beta only' { $servers[1].process.HasExited -and !$servers[0].process.HasExited })
    [void](Wait-For 'context Delete removes captured Beta' { $s=Session; $s -and @($s.tabs | Where-Object { $_.name -eq 'Beta' }).Count -eq 0 -and @($s.tabs | Where-Object { $_.name -eq 'Alpha' }).Count -eq 1 })
    Shot 'context-delete-beta'
    Focus
    Press @(0x11,0x10,0x57)
    [void](Wait-For 'one Ctrl+Shift+W stops Alpha' { $servers[0].process.HasExited })
    [void](Wait-For 'Alpha removed' { $s=Session; $s -and @($s.tabs | Where-Object { $_.name -eq 'Alpha' }).Count -eq 0 })
    $requests=@(Get-Content (Join-Path $env:MP_VERIFY_STATE 'end-requests.jsonl') | ForEach-Object { $_ | ConvertFrom-Json })
    foreach ($name in $names) { Check ('one-stop-request-'+$name) (@($requests | Where-Object { $_.session -eq $name }).Count -eq 1) }
    $archive=Get-Content (Join-Path $settings 'archive.json') -Raw | ConvertFrom-Json
    Check 'deleted-chats-keep-history-identities' (@($archive | Where-Object { $_.csid -in $ids }).Count -eq 2)
    for ($i=0; $i -lt $transcripts.Count; $i++) { Check 'original-history-bytes-retained' ((Get-FileHash $transcripts[$i].FullName -Algorithm SHA256).Hash -ceq $hashes[$i]) }
    Save @($names | ForEach-Object { Get-Content (Join-Path $env:MP_VERIFY_STATE ('ended-'+$_+'.json')) -Raw | ConvertFrom-Json }) (Join-Path $Evidence 'end-commands.json')
    Shot 'after-delete'
    $result.history_ui_readability='not exercised; retained original transcripts and saved identities only'
    $result.status='passed'
} catch {
    $result.error=$_.Exception.Message
    try { Shot 'failure' } catch {}
} finally {
    $remaining=0
    if ($null -ne $job) { $remaining+=$job.Stop().ActiveProcesses; $job.Dispose() }
    foreach ($server in $servers) { $remaining+=$server.job.Stop().ActiveProcesses; $server.job.Dispose() }
    $result.cleanup=$remaining
    if (Test-Path $profile) {
        Copy-Item -Recurse $profile (Join-Path $Evidence 'data')
        Remove-Item -Recurse -Force $profile
    }
    $result.scratch_removed=!(Test-Path $profile)
    Save @($actions) (Join-Path $Evidence 'actions.json')
    Save $result (Join-Path $Evidence 'result.json')
}
if ($result.status -ne 'passed' -or $result.cleanup -ne 0 -or !$result.scratch_removed) { throw 'Session actions verification failed; inspect result.json' }
