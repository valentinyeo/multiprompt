param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)][string]$ExpectedHash,
    [Parameter(Mandatory)][string]$Evidence,
    [string]$WorkspaceName = '',
    [ValidateSet(96, 144)][int]$Dpi = 96
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'GitHub Windows only' }
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type -Path "$PSScriptRoot/../verify-chat-delivery/desktop.cs"
Add-Type -Path "$PSScriptRoot/../verify-chat-delivery/job.cs"
Add-Type -Path "$PSScriptRoot/../../.claude/skills/verify-multiprompt/title-bar-native.cs"
[void][ChatDeliveryDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
$env:IGSH_246 = '0'
$env:MULTIPROMPT_NO_LOGIN = '1'
$env:ZIGSHELL_DEBUG = '1'
$env:MP_VERIFY_PYTHON = (Get-Command python.exe).Source
$env:MP_VERIFY_BOUNDARY = (Resolve-Path "$PSScriptRoot/../verify-chat-delivery/boundary.py").Path
$env:PATH = (Split-Path $Exe) + ';' + $env:PATH
$env:PYTHONUTF8 = '1'
$checks = [Collections.Generic.List[object]]::new()
$result = @{passed=$false; error=$null; checks=$checks; cleanup='pending'}
$job = $null
$profile = Join-Path $env:RUNNER_TEMP "bot-avatars-$PID"
function Wait-For([string]$Name, [scriptblock]$Check) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 150 } while ($watch.Elapsed.TotalSeconds -lt 60)
    throw "Timed out: $Name"
}
function Save($Value, [string]$File) { [IO.File]::WriteAllText($File, ($Value | ConvertTo-Json -Depth 15), [Text.UTF8Encoding]::new($false)) }
function Read-Log {
    if (-not (Test-Path "$settings/debug.log")) { return '' }
    $stream = [IO.File]::Open("$settings/debug.log", 'Open', 'Read', 'ReadWrite')
    $reader = [IO.StreamReader]::new($stream)
    try { $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function Appearance([string]$Name) {
    $hash = [uint64]2166136261
    foreach ($byte in [Text.Encoding]::UTF8.GetBytes($Name)) {
        $hash = (($hash -bxor [uint64]$byte) * [uint64]16777619) -band [uint64]4294967295
    }
    $color = switch ($WorkspaceName) { 'inne' { 2 } 'Hypertask' { 5 } 'Software Factory' { 4 } default { 0 } }
    @{face=[int]($hash % 20); color=$color}
}
function Layouts {
    $matches = [regex]::Matches((Read-Log), '\[bots\] face=(\d+) color=(\d+) rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)')
    $unique = @{}
    foreach ($match in $matches) {
        $g = $match.Groups
        $row = @{face=[int]$g[1].Value; color=[int]$g[2].Value; x=[int]$g[3].Value; y=[int]$g[4].Value; right=[int]$g[5].Value; bottom=[int]$g[6].Value}
        $row.size = $row.right - $row.x
        $unique["$($row.x),$($row.y),$($row.size)"] = $row
    }
    @($unique.Values)
}
function Shot([string]$Name) {
    $bounds = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = [Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.Size); $bitmap.Save("$Evidence/$Name.png") } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Check-Pixels($Row, [string]$Name) {
    $origin = [ChatDeliveryDesktop]::ScreenPoint($main, $Row.x, $Row.y)
    $bitmap = [Drawing.Bitmap]::new($Row.size, $Row.size)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($origin.X, $origin.Y, 0, 0, $bitmap.Size)
        $bright = 0; $dark = 0; $tint = 0; $workspaceTint = 0
        for ($y = 0; $y -lt $Row.size; $y++) {
            for ($x = 0; $x -lt $Row.size; $x++) {
                $p = $bitmap.GetPixel($x, $y)
                if (($Row.color -eq 2 -and $p.R -gt $p.G * 1.1 -and $p.G -gt $p.B * 1.1) -or
                    ($Row.color -eq 4 -and $p.B -gt $p.R * 1.1 -and $p.G -gt $p.R * 1.05) -or
                    ($Row.color -eq 5 -and $p.B -gt $p.G * 1.1 -and $p.R -gt $p.G * 1.05)) { $workspaceTint++ }
                if ([Math]::Min($p.R, [Math]::Min($p.G, $p.B)) -gt 215) { $bright++ }
                if ([Math]::Max($p.R, [Math]::Max($p.G, $p.B)) -lt 40) { $dark++ }
                if ([Math]::Max($p.R, [Math]::Max($p.G, $p.B)) - [Math]::Min($p.R, [Math]::Min($p.G, $p.B)) -gt 16) { $tint++ }
            }
        }
        $area = $Row.size * $Row.size
        if ($bright -lt $area * .01 -or $dark -lt $area * .15 -or ($Row.color -ne 0 -and $tint -lt $area * .12)) { throw "Robot pixels absent: $Name bright=$bright dark=$dark tint=$tint area=$area" }
        if ($Row.color -in @(2, 4, 5) -and $workspaceTint -lt $area * .08) { throw "Workspace hue absent: $Name" }
        $bitmap.Save("$Evidence/$Name.png")
        $checks.Add(@{name=$Name; passed=$true; face=$Row.face; color=$Row.color; size=$Row.size; bright=$bright; dark=$dark; tint=$tint; workspaceTint=$workspaceTint})
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
try {
    [CaptionProof]::SetDpi($Dpi)
    function Px([int]$Value) { [int][Math]::Floor($Value * $Dpi / 96) }
    if ((Get-FileHash $Exe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $ExpectedHash) { throw 'Binary checksum mismatch' }
    if (-not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Binary version mismatch' }
    $displayNames = @('inne Chief of Staff', 'Mini Boss CEO', 'HT Product Lead', 'SF Design Lead', 'HT Design Lead', 'Triage')
    $names = @($displayNames | ForEach-Object { $_.Replace(' ', '-') })
    $looks = @($names | ForEach-Object { $a = Appearance $_; "$($a.face):$($a.color)" } | Select-Object -Unique)
    if ($looks.Count -ne $names.Count) { throw 'Fixture bot identities must be visually distinct' }
    $settings = "$profile/roaming/ZigShell"
    $state = "$profile/remote-state"
    New-Item -ItemType Directory -Force $settings, $state, "$profile/local", "$profile/home" | Out-Null
    $env:APPDATA = "$profile/roaming"; $env:LOCALAPPDATA = "$profile/local"; $env:USERPROFILE = "$profile/home"; $env:HOME = "$profile/home"
    $env:MP_VERIFY_STATE = $state
    $panes = @{}; $sids = @{}
    for ($i = 0; $i -lt $names.Count; $i++) { $panes[$names[$i]] = 4300 + $i; $sids[$names[$i]] = ('a1b2c3d4-0927-4000-8000-0000000009{0:D2}' -f $i) }
    Save @{name='robot-avatars'; fake=$true; mode='idle'; suggestion=''; sessions=$names; panes=$panes; sids=$sids; home="$profile/home"; procRoot=([IO.Path]::GetPathRoot($profile) + 'proc')} "$state/state.json"
    & $env:MP_VERIFY_PYTHON $env:MP_VERIFY_BOUNDARY shell seed-many 1
    if ($LASTEXITCODE -ne 0) { throw 'Transcript seed failed' }
    $console = Get-Content "$state/claude.json" -Raw | ConvertFrom-Json
    $console | Add-Member -NotePropertyName turns -NotePropertyValue (,@('Show the next step', 'Robot previews are ready.')) -Force
    Save $console "$state/claude.json"
    $tabs = @()
    for ($i = 0; $i -lt $names.Count; $i++) { $tabs += @{kind='tmux'; name=$displayNames[$i]; manual=$true; tmux_host=0; tmux_session=$names[$i]; pinned_top=($i -lt 2); cv=$false; pid=0} }
    Save @{active_tab=0; single_window=$true; workspace_count=1; workspaces=@(@{name=$WorkspaceName; wid='default'}); chat_active=$false; amoled_theme=$true; tabs=$tabs} "$settings/session.json"
    [IO.File]::WriteAllText("$settings/theme-mode.txt", 'amoled')
    [IO.File]::WriteAllText("$settings/ssh-path.txt", (Join-Path (Split-Path $Exe) 'ssh.exe'))
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $profile, "$Evidence/stdout.log", "$Evidence/stderr.log", '--no-window-restore')
    $main = Wait-For 'owned main window' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    [void](Wait-For 'foreground owned app' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $main) })
    [void](Wait-For 'all restored sessions' { if (Test-Path "$settings/inbox-default.json") { $doc = Get-Content "$settings/inbox-default.json" -Raw | ConvertFrom-Json; if (@($doc.shells).Count -eq 6) { $true } } })
    $rows = Wait-For 'large pinned and list robots' { $v = @(Layouts); if (@($v | Where-Object { $_.size -eq (Px 56) }).Count -ge 2 -and @($v | Where-Object { $_.size -eq (Px 40) }).Count -ge 4) { ,$v } }
    [void](Wait-For 'real console messages reach list previews' {
        $published = Get-Content "$settings/inbox-default.json" -Raw | ConvertFrom-Json
        @($published.shells | Where-Object { $_.pv -like '*Robot previews are ready*' }).Count -eq 6
    })
    $checks.Add(@{name='last-message-previews'; passed=$true})
    Save @{ requestedDpi=$Dpi; listSize=(Px 40); pinSize=(Px 56); uiScale=100 } "$Evidence/display.json"
    $expectedColor = (Appearance $names[0]).color
    if (@($rows | Where-Object { $_.color -ne $expectedColor }).Count) { throw 'Workspace robot color mismatch' }
    $checks.Add(@{name='workspace-colors'; passed=$true; workspace=$WorkspaceName; color=$expectedColor})
    $rows = @(Layouts)
    $pins = @($rows | Where-Object { $_.size -eq (Px 56) } | Sort-Object x)
    $list = @($rows | Where-Object { $_.size -eq (Px 40) } | Sort-Object y)
    foreach ($entry in @(@{row=$pins[0]; name='pin-one'}, @{row=$pins[1]; name='pin-two'}, @{row=$list[0]; name='list-one'})) {
        $live = Wait-For 'current clicked robot position' {
            $v = @(Layouts | Where-Object { $_.size -eq $entry.row.size -and $_.face -eq $entry.row.face -and $_.color -eq $entry.row.color })
            if ($v.Count) { $v[-1] }
        }
        [ChatDeliveryDesktop]::PressClient($main, $app.Id, ($live.x + 10), ($live.y + 15))
        $selected = Wait-For 'clicked raw session selected' {
            $saved = Get-Content "$settings/session.json" -Raw | ConvertFrom-Json
            $tab = @($saved.tabs)[$saved.active_tab]
            $expected = Appearance $tab.tmux_session
            $isPin = $entry.name -ne 'list-one'
            $member = if ($isPin) { $tab.tmux_session -in $names[0..1] } else { $tab.tmux_session -in $names[2..5] }
            if ($member -and $expected.face -eq $entry.row.face -and $expected.color -eq $entry.row.color) { $tab.tmux_session }
        }
        $checks.Add(@{name=($entry.name + '-click'); passed=$true; selected=$selected})
        $expected = Appearance $selected
        $painted = Wait-For 'selected robot repainted' {
            $v = @(Layouts | Where-Object { $_.size -eq $entry.row.size -and $_.face -eq $expected.face -and $_.color -eq $expected.color })
            if ($v.Count) { $v[-1] }
        }
        Check-Pixels $painted $entry.name
    }
    Shot 'sidebar-amoled'
    [ChatDeliveryDesktop]::Chord(@(0x12, 0x43))
    [void](Wait-For 'native chat composer' { [ChatDeliveryDesktop]::Composer($main) -ne [IntPtr]::Zero })
    $title = Wait-For 'matching title robot' { $v = @(Layouts | Where-Object { $_.size -eq (Px 28) -and $_.x -gt 300 }); if ($v.Count) { $v[-1] } }
    Check-Pixels $title 'chat-title-robot'
    $selectedRow = @($list | Where-Object { $_.face -eq $title.face -and $_.color -eq $title.color })
    if ($selectedRow.Count -eq 0) { throw 'Chat title robot differs from the selected session' }
    [void](Wait-For 'selected conversation has loaded' { (Read-Log) -match '\[chat\] transcript load shell=\d+ ok' })
    Shot 'chat-amoled'
    Copy-Item "$settings/session.json" "$Evidence/session-selected.json"
    Save @(Layouts) "$Evidence/layouts.json"
    $result.passed = $true
 } catch {
    $result.error = $_.Exception.Message
    Write-Host $result.error
    if (Get-Variable main -ErrorAction SilentlyContinue) { Shot 'failure' }
} finally {
    if ($null -ne $job) { $stopped = $job.Stop(); $result.cleanup = $stopped.ActiveProcesses; $job.Dispose() }
    if (Test-Path "$settings/debug.log") { Copy-Item "$settings/debug.log" "$Evidence/debug.log" }
    if (Test-Path "$state/invocations.jsonl") { Copy-Item "$state/invocations.jsonl" "$Evidence/invocations.jsonl" }
    if (Test-Path "$state/unsupported.jsonl") { Copy-Item "$state/unsupported.jsonl" "$Evidence/unsupported.jsonl" }
    if (Test-Path $state) { Get-ChildItem $state -Filter 'reader-*.stderr.log' | Copy-Item -Destination $Evidence }
    foreach ($file in @('session.json', 'inbox-default.json')) {
        if (Test-Path "$settings/$file") { Copy-Item "$settings/$file" "$Evidence/final-$file" }
    }
    Save $result "$Evidence/result.json"
    if (Test-Path $profile) { Remove-Item -Recurse -Force $profile }
    [CaptionProof]::RestoreDpi()
}
if (-not $result.passed -or $result.cleanup -ne 0) { throw 'Robot avatar acceptance failed; see result.json' }
