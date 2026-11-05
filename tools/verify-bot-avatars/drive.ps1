param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)][string]$ExpectedHash,
    [Parameter(Mandatory)][string]$Evidence,
    [ValidateRange(0, 2)][int]$WorkspaceIndex = 0,
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
Add-Type -Path "$PSScriptRoot/settings.cs"
[void][ChatDeliveryDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
$env:IGSH_246 = '0'
$env:MULTIPROMPT_NO_LOGIN = '1'
$env:ZIGSHELL_DEBUG = '1'
$env:MP_VERIFY_PYTHON = (Get-Command python.exe).Source
$env:MP_VERIFY_BOUNDARY = (Resolve-Path "$PSScriptRoot/../verify-chat-delivery/boundary.py").Path
$env:PATH = (Split-Path $Exe) + ';' + $env:PATH
$env:PYTHONUTF8 = '1'
$workspaceNames = @('Cedar', 'Orbit', 'Lagoon')
$WorkspaceName = $workspaceNames[$WorkspaceIndex]
$colorIndex = $WorkspaceIndex % 8
$palette = @(0x8FCB6B, 0xE9875A, 0xE8C65A, 0x6F9FE0, 0xA77FE0, 0xE77B98, 0x5CCFC0, 0xEDEDED)
$layoutOffset = 0
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
    $color = $colorIndex
    @{face=[int]($hash % 20); color=$color}
}
function Layouts {
    $log = Read-Log
    $matches = [regex]::Matches($log.Substring([Math]::Min($layoutOffset, $log.Length)), '\[bots\] face=(\d+) color=(\d+) rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)')
    $unique = [ordered]@{}
    foreach ($match in $matches) {
        $g = $match.Groups
        $row = @{face=[int]$g[1].Value; color=[int]$g[2].Value; x=[int]$g[3].Value; y=[int]$g[4].Value; right=[int]$g[5].Value; bottom=[int]$g[6].Value}
        $row.size = $row.right - $row.x
        $key = "$($row.x),$($row.y),$($row.size)"
        if ($unique.Contains($key)) { $unique.Remove($key) }
        $unique[$key] = $row
    }
    @($unique.Values)
}
function Palette-Select([string]$Query, [int]$Target, [bool]$Open = $true) {
    $start = (Read-Log).Length
    if ($Open) {
        [ChatDeliveryDesktop]::Chord(@(0x11, 0x4b))
        [void](Wait-For 'palette ready' { (Read-Log).Substring($start) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    }
    else {
        [void](Wait-For 'palette submenu ready' { (Read-Log).Substring($script:paletteTransition) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    }
    $start = (Read-Log).Length
    foreach ($letter in $Query.ToCharArray()) { [ChatDeliveryDesktop]::Character($letter) }
    $selection = Wait-For "palette results for $Query" {
        $tail = (Read-Log).Substring($start)
        $pattern = "\[palette\] rows chars=$($Query.Length) count=\d+ ids=([^\r\n]+)\r?\n(?:[^\r\n]*\r?\n){0,5}[^\r\n]*\[palette\] ready chars=$($Query.Length) count=\d+ target=(\d+)"
        $found = [regex]::Matches($tail, $pattern)
        if ($found.Count) {
            $last = $found[$found.Count - 1]
            $ids = @($last.Groups[1].Value -split ' ' | Where-Object { $_ -match '^\d+$' })
            $current = [Array]::IndexOf($ids, $last.Groups[2].Value)
            $wanted = [Array]::IndexOf($ids, [string]$Target)
            if ($current -ge 0 -and $wanted -ge 0) { @{ids=$ids; current=$current; wanted=$wanted} }
        }
    }
    $steps = ($selection.wanted - $selection.current + $selection.ids.Count) % $selection.ids.Count
    for ($step = 0; $step -lt $steps; $step++) { [ChatDeliveryDesktop]::Chord(@(0x28)) }
    $script:paletteTransition = (Read-Log).Length
    [ChatDeliveryDesktop]::Chord(@(0x0d))
    if ($Target -in @(7188, 4000)) {
        [void](Wait-For 'selected palette submenu opened' {
            $tail = (Read-Log).Substring($script:paletteTransition)
            $ready = [regex]::Matches($tail, '\[palette\] ready chars=(\d+) count=\d+ target=(\d+)')
            if ($ready.Count) {
                $last = $ready[$ready.Count - 1]
                if ($last.Groups[1].Value -eq '0') { return $true }
                if ([int]$last.Groups[1].Value -eq $Query.Length -and [int]$last.Groups[2].Value -eq $Target) {
                    [ChatDeliveryDesktop]::Chord(@(0x0d))
                }
            }
            $false
        })
    }
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
        $bright = 0; $dark = 0; $tint = 0; $workspaceTint = 0; $whiteBody = 0
        for ($y = 0; $y -lt $Row.size; $y++) {
            for ($x = 0; $x -lt $Row.size; $x++) {
                $p = $bitmap.GetPixel($x, $y)
                $expected = $palette[$Row.color]
                $red = ($expected -shr 16) -band 255
                $green = ($expected -shr 8) -band 255
                $blue = $expected -band 255
                $shade = $p.R / [double]$red
                if ($shade -ge .60 -and $shade -le 1.03 -and [Math]::Abs($p.G - $green * $shade) -lt 12 -and [Math]::Abs($p.B - $blue * $shade) -lt 12) { $workspaceTint++ }
                if ($x -ge $Row.size * .15 -and $x -lt $Row.size * .85 -and $y -ge $Row.size * .15 -and $y -lt $Row.size * .85 -and $p.R -ge 175 -and $p.R -le 212 -and [Math]::Abs($p.G - $p.R) -lt 8 -and [Math]::Abs($p.B - $p.R) -lt 8) { $whiteBody++ }
                if ([Math]::Min($p.R, [Math]::Min($p.G, $p.B)) -gt 215) { $bright++ }
                if ([Math]::Max($p.R, [Math]::Max($p.G, $p.B)) -lt 40) { $dark++ }
                if ([Math]::Max($p.R, [Math]::Max($p.G, $p.B)) - [Math]::Min($p.R, [Math]::Min($p.G, $p.B)) -gt 16) { $tint++ }
            }
        }
        $area = $Row.size * $Row.size
        $minimumBrightFraction = if ($Row.face -in @(3, 19)) { .005 } else { .01 }
        if ($bright -lt $area * $minimumBrightFraction -or $dark -lt $area * .15 -or ($Row.color -ne 7 -and $tint -lt $area * .12)) { throw "Robot pixels absent: $Name bright=$bright dark=$dark tint=$tint area=$area" }
        if ($workspaceTint -lt $area * .08) { throw "Workspace hue absent: $Name" }
        if ($Row.color -eq 7 -and $whiteBody -lt $area * .04) { throw "White robot body absent: $Name midgray=$whiteBody area=$area" }
        $bitmap.Save("$Evidence/$Name.png")
        $checks.Add(@{name=$Name; passed=$true; face=$Row.face; color=$Row.color; size=$Row.size; bright=$bright; dark=$dark; tint=$tint; workspaceTint=$workspaceTint; whiteBody=$whiteBody})
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Wait-Pixels([string]$Name, [scriptblock]$FindRows) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $lastError = 'no matching layout'
    do {
        $candidates = @(& $FindRows)
        [Array]::Reverse($candidates)
        foreach ($row in $candidates) {
            try { Check-Pixels $row $Name; return $row }
            catch {
                $lastError = $_.Exception.Message
                if ($lastError -notmatch '^(Robot pixels absent|Workspace hue absent|White robot body absent):') { throw }
            }
        }
        Start-Sleep -Milliseconds 150
    } while ($watch.Elapsed.TotalSeconds -lt 10)
    throw "Timed out waiting for pixels: $Name ($lastError)"
}
try {
    [CaptionProof]::SetDpi($Dpi)
    function Px([int]$Value) { [int][Math]::Floor($Value * $Dpi / 96) }
    if ((Get-FileHash $Exe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $ExpectedHash) { throw 'Binary checksum mismatch' }
    if (-not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Binary version mismatch' }
    $displayNames = @('Cedar agent', 'Orbit agent', 'Lagoon agent', 'Moss agent', 'Dune agent', 'Coral agent', 'Pine agent', 'Fern agent')
    $names = @($displayNames | ForEach-Object { $_.Replace(' ', '-') })
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
    for ($i = 0; $i -lt $names.Count; $i++) { $tabs += @{kind='tmux'; name=$displayNames[$i]; manual=$true; tmux_host=0; tmux_session=$names[$i]; workspace=$WorkspaceIndex; pinned_top=($i -lt 2); cv=$false; pid=0} }
    Save @{active_tab=0; single_window=$true; active_workspace=$WorkspaceIndex; workspace_count=3; workspaces=@($workspaceNames | ForEach-Object { @{name=$_; wid=('workspace-' + $_.ToLowerInvariant())} }); chat_active=$false; amoled_theme=$true; tabs=$tabs} "$settings/session.json"
    [IO.File]::WriteAllText("$settings/theme-mode.txt", 'amoled')
    [IO.File]::WriteAllText("$settings/ssh-path.txt", (Join-Path (Split-Path $Exe) 'ssh.exe'))
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $profile, "$Evidence/stdout.log", "$Evidence/stderr.log", '--no-window-restore')
    $main = Wait-For 'owned main window' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    [void](Wait-For 'foreground owned app' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $main) })
    [void](Wait-For 'all restored sessions' { if (Test-Path "$settings/inbox-default.json") { $doc = Get-Content "$settings/inbox-default.json" -Raw | ConvertFrom-Json; if (@($doc.shells).Count -eq 8) { $true } } })
    $rows = Wait-For 'large pinned and list robots' { $v = @(Layouts); if (@($v | Where-Object { $_.size -eq (Px 56) }).Count -ge 2 -and @($v | Where-Object { $_.size -eq (Px 36) }).Count -ge 4) { ,$v } }
    $client = [ChatDeliveryDesktop+Rect]::new()
    if (-not [ChatDeliveryDesktop]::GetClientRect($main, [ref]$client)) { throw 'Main client bounds unavailable' }
    $screen = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $origin = [ChatDeliveryDesktop]::ScreenPoint($main, 0, 0)
    $inboxRequired = (Px 72) + 7 * (Px 58) + (Px 56) + (Px 40)
    $sidebarRequired = 34 + (Px (8 + 52 + 104 + 42 + 6 * 58))
    if ($client.Bottom -lt [Math]::Max($inboxRequired, $sidebarRequired) -or $origin.Y -lt $screen.Top -or $origin.Y + $client.Bottom -gt $screen.Bottom) {
        throw "Insufficient visible height for eight robots: client=$($client.Bottom) inbox=$inboxRequired sidebar=$sidebarRequired"
    }
    $checks.Add(@{name='eight-row-height'; passed=$true; clientHeight=$client.Bottom; inboxRequired=$inboxRequired; sidebarRequired=$sidebarRequired; screenHeight=$screen.Height})
    [void](Wait-For 'real console messages reach list previews' {
        $published = Get-Content "$settings/inbox-default.json" -Raw | ConvertFrom-Json
        @($published.shells | Where-Object { $_.pv -like '*Robot previews are ready*' }).Count -eq 8
    })
    $checks.Add(@{name='last-message-previews'; passed=$true})
    Save @{ requestedDpi=$Dpi; listSize=(Px 36); pinSize=(Px 56); uiScale=100 } "$Evidence/display.json"
    $expectedColor = (Appearance $names[0]).color
    if (@($rows | Where-Object { $_.color -ne $expectedColor }).Count) { throw 'Workspace robot color mismatch' }
    $checks.Add(@{name='workspace-colors'; passed=$true; workspace=$WorkspaceName; color=$expectedColor})
    $rows = @(Layouts)
    $pins = @($rows | Where-Object { $_.size -eq (Px 56) } | Sort-Object x)
    $list = @($rows | Where-Object { $_.size -eq (Px 36) } | Sort-Object y)
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
            $member = if ($isPin) { $tab.tmux_session -in $names[0..1] } else { $tab.tmux_session -in $names[2..7] }
            if ($member -and $expected.face -eq $entry.row.face -and $expected.color -eq $entry.row.color) { $tab.tmux_session }
        }
        $checks.Add(@{name=($entry.name + '-click'); passed=$true; selected=$selected})
        $expected = Appearance $selected
        [void](Wait-Pixels $entry.name {
            Layouts | Where-Object { $_.size -eq $entry.row.size -and $_.face -eq $expected.face -and $_.color -eq $expected.color }
        })
    }
    Shot 'sidebar-amoled'
    $layoutOffset = (Read-Log).Length
    [ChatDeliveryDesktop]::Chord(@(0x12, 0x43))
    [void](Wait-For 'native chat composer' { [ChatDeliveryDesktop]::Composer($main) -ne [IntPtr]::Zero })
    $title = Wait-Pixels 'chat-title-robot' {
        Layouts | Where-Object { $_.size -eq (Px 28) -and $_.x -gt 300 -and $_.face -eq $expected.face -and $_.color -eq $expected.color }
    }
    $selectedRow = @($list | Where-Object { $_.face -eq $title.face -and $_.color -eq $title.color })
    if ($selectedRow.Count -eq 0) { throw 'Chat title robot differs from the selected session' }
    [void](Wait-For 'selected conversation has loaded' { (Read-Log) -match '\[chat\] transcript load shell=\d+ ok' })
    Shot 'chat-amoled'
    Copy-Item "$settings/session.json" "$Evidence/session-selected.json"
    Save @(Layouts) "$Evidence/layouts.json"
    [ChatDeliveryDesktop]::Chord(@(0x11, 0xbc))
    $panel = Wait-For 'settings palette panel' { $h = [BotSettingsDesktop]::Panel($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    $content = Wait-For 'settings palette content' { $h = [BotSettingsDesktop]::Content($panel, $app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    [BotSettingsDesktop]::Scroll($content, $app.Id, 4)
    Shot 'workspace-settings-picker'
    $top = [BotSettingsDesktop]::ColorsTop($content) + [BotSettingsDesktop]::Scale($content, $WorkspaceIndex * 80 + 54 - 192)
    $layoutOffset = (Read-Log).Length
    [ChatDeliveryDesktop]::PressClient($content, $app.Id, ([BotSettingsDesktop]::ColorX($content, 4)), $top)
    [void](Wait-For 'picked palette color persisted' {
        $saved = Get-Content "$settings/session.json" -Raw | ConvertFrom-Json
        $workspace = @($saved.workspaces)[$WorkspaceIndex]
        if ($workspace.PSObject.Properties['color']) { $workspace.color -eq 4 }
    })
    $checks.Add(@{name='settings-color-persisted'; passed=$true; workspace=$WorkspaceName; color=4})
    Shot 'workspace-settings-picked'
    [ChatDeliveryDesktop]::Chord(@(0x1b))
    [void](Wait-For 'settings closed' { [BotSettingsDesktop]::Panel($app.Id) -eq [IntPtr]::Zero })
    $colorIndex = 4
    $overridden = Wait-For 'workspace faces recolored' {
        $v = @(Layouts | Where-Object { $_.color -eq 4 -and $_.size -eq (Px 56) })
        if ($v.Count -ge 2) { ,$v }
    }
    [void](Wait-Pixels 'overridden-workspace-robot' { $overridden[0] })
    Shot 'workspace-override'
    [ChatDeliveryDesktop]::Chord(@(0x11, 0xbc))
    $panel = Wait-For 'settings palette panel for white' { $h = [BotSettingsDesktop]::Panel($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    $content = Wait-For 'settings palette content for white' { $h = [BotSettingsDesktop]::Content($panel, $app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    [BotSettingsDesktop]::Scroll($content, $app.Id, 4)
    $top = [BotSettingsDesktop]::ColorsTop($content) + [BotSettingsDesktop]::Scale($content, $WorkspaceIndex * 80 + 54 - 192)
    $layoutOffset = (Read-Log).Length
    [ChatDeliveryDesktop]::PressClient($content, $app.Id, ([BotSettingsDesktop]::ColorX($content, 7)), $top)
    [void](Wait-For 'white workspace color persisted' {
        $saved = Get-Content "$settings/session.json" -Raw | ConvertFrom-Json
        $workspace = @($saved.workspaces)[$WorkspaceIndex]
        if ($workspace.PSObject.Properties['color']) { $workspace.color -eq 7 }
    })
    $checks.Add(@{name='settings-white-persisted'; passed=$true; workspace=$WorkspaceName; color=7})
    Shot 'workspace-settings-white'
    [ChatDeliveryDesktop]::Chord(@(0x1b))
    [void](Wait-For 'settings closed after white' { [BotSettingsDesktop]::Panel($app.Id) -eq [IntPtr]::Zero })
    $white = Wait-For 'workspace faces painted white' {
        $v = @(Layouts | Where-Object { $_.color -eq 7 -and $_.size -eq (Px 56) })
        if ($v.Count -ge 2) { ,$v }
    }
    [void](Wait-Pixels 'white-workspace-robot' { $white[0] })
    Shot 'workspace-white'
    Copy-Item "$settings/debug.log" "$Evidence/before-restart-debug.log"
    $stopped = $job.Stop()
    if ($stopped.ActiveProcesses -ne 0) { throw 'Owned app did not stop for white restart' }
    $job.Dispose()
    $job = [VerifyJob]::new()
    $layoutOffset = (Read-Log).Length
    $app = $job.Start($Exe, $profile, "$Evidence/restart-stdout.log", "$Evidence/restart-stderr.log", '--no-window-restore')
    $main = Wait-For 'restarted owned main window' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    [void](Wait-For 'restarted app foreground' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $main) })
    $white = Wait-For 'white workspace restored after restart' {
        $saved = Get-Content "$settings/session.json" -Raw | ConvertFrom-Json
        $workspace = @($saved.workspaces)[$WorkspaceIndex]
        $v = @(Layouts | Where-Object { $_.color -eq 7 -and $_.size -eq (Px 56) })
        if ($workspace.PSObject.Properties['color'] -and $workspace.color -eq 7 -and @($saved.tabs).Count -eq 8 -and $v.Count -ge 2) { ,$v }
    }
    [void](Wait-Pixels 'white-restarted-robot' { $white[0] })
    Shot 'workspace-white-restarted'
    $checks.Add(@{name='white-restart'; passed=$true; workspace=$WorkspaceName; color=7})
    $colorNames = @('sage', 'clay', 'sand', 'mist', 'lilac', 'rose', 'mint', 'white')
    $sessionWrite = (Get-Item "$settings/session.json").LastWriteTimeUtc
    Palette-Select 'manual' 6218
    [void](Wait-For 'manual session order saved' { (Get-Item "$settings/session.json").LastWriteTimeUtc -gt $sessionWrite })
    $orderedTabs = @((Get-Content "$settings/session.json" -Raw | ConvertFrom-Json).tabs)
    $orderedNames = @($orderedTabs | Where-Object { $_.PSObject.Properties['pinned_top'] -and $_.pinned_top } | ForEach-Object { $_.tmux_session }) + @($orderedTabs | Where-Object { -not $_.PSObject.Properties['pinned_top'] -or -not $_.pinned_top } | ForEach-Object { $_.tmux_session })
    if ($orderedNames.Count -ne 8) { throw 'Manual session order does not contain eight tabs' }
    $selectedNames = @{}
    for ($i = 0; $i -lt 8; $i++) {
        [ChatDeliveryDesktop]::Chord(@(0x11, (0x31 + $i)))
        $selected = Wait-For "session $i selected" {
            $saved = Get-Content "$settings/session.json" -Raw | ConvertFrom-Json
            $tab = @($saved.tabs)[$saved.active_tab]
            if ($tab.tmux_session -eq $orderedNames[$i] -and -not $selectedNames.ContainsKey($tab.tmux_session)) { $tab.tmux_session }
        }
        $selectedNames[$selected] = $true
        Palette-Select 'bot color' 7188
        Palette-Select $colorNames[$i] (7162 + $i) $false
        [void](Wait-For "session $selected color persisted" {
            $saved = Get-Content "$settings/session.json" -Raw | ConvertFrom-Json
            $tab = @($saved.tabs | Where-Object { $_.tmux_session -eq $selected })
            $tab.Count -eq 1 -and $tab[0].PSObject.Properties['color'] -and $tab[0].color -eq $i
        })
        $checks.Add(@{name='session-color-persisted'; passed=$true; session=$selected; color=$i})
    }
    foreach ($theme in @(@{name='light'; id=4012}, @{name='amoled'; id=4013}, @{name='dark'; id=4010}, @{name='mid'; id=4011})) {
        Palette-Select 'themes' 4000
        $layoutOffset = (Read-Log).Length
        Palette-Select $theme.name $theme.id $false
        [void](Wait-For "theme $($theme.name) persisted" { (Get-Content "$settings/theme-mode.txt" -Raw).Trim() -eq $theme.name })
        [ChatDeliveryDesktop]::Chord(@(0x1b))
        $sidebarRows = Wait-For "sidebar colors $($theme.name)" {
            $v = @(Layouts | Where-Object { ($_.size -eq (Px 56) -or $_.size -eq (Px 36)) -and $_.x -ge 0 -and $_.right -le (Px 300) -and $_.y -ge 0 -and $_.bottom -le $client.Bottom })
            if (@($v | ForEach-Object { $_.color } | Select-Object -Unique).Count -eq 8) { ,$v }
        }
        foreach ($row in $sidebarRows) {
            $pixelRow = $row
            [void](Wait-Pixels "sidebar-$($theme.name)-$($row.color)" { $pixelRow })
        }
        Shot "sidebar-$($theme.name)-colors"
        [ChatDeliveryDesktop]::Chord(@(0x12, 0x49))
        [void](Wait-For 'inbox opened' { (Get-Content "$settings/inbox-default.json" -Raw | ConvertFrom-Json).inbox_active })
        $layoutOffset = (Read-Log).Length
        [ChatDeliveryDesktop]::Chord(@(0x12, 0x49))
        $inboxWidth = [Math]::Min((Px 920), $client.Right - (Px 24))
        $inboxX = [int][Math]::Truncate(($client.Right - $inboxWidth) / 2) + (Px 10)
        $inboxRows = Wait-For "all inbox colors $($theme.name)" {
            $v = @(Layouts | Where-Object { $_.size -eq (Px 40) -and $_.x -eq $inboxX -and $_.y -ge 0 -and $_.bottom -le $client.Bottom })
            if (@($v | ForEach-Object { $_.color } | Select-Object -Unique).Count -eq 8) { ,$v }
        }
        foreach ($row in $inboxRows) {
            $pixelRow = $row
            [void](Wait-Pixels "inbox-$($theme.name)-$($row.color)" { $pixelRow })
        }
        Shot "inbox-$($theme.name)-colors"
        [ChatDeliveryDesktop]::Chord(@(0x1b))
        [void](Wait-For 'inbox closed' { -not (Get-Content "$settings/inbox-default.json" -Raw | ConvertFrom-Json).inbox_active })
    }
    $result.passed = $true
 } catch {
    $result.error = $_.Exception.Message
    Write-Host $result.error
    if (Get-Variable main -ErrorAction SilentlyContinue) { Shot 'failure' }
} finally {
    $cleanupErrors = [Collections.Generic.List[string]]::new()
    $ownedStopped = $null -eq $job
    if ($null -ne $job) {
        try {
            $stopped = $job.Stop()
            $result.cleanup = $stopped.ActiveProcesses
            $ownedStopped = $stopped.ActiveProcesses -eq 0
            if (-not $ownedStopped) { $cleanupErrors.Add('Owned processes remain') }
        } catch { $cleanupErrors.Add("Owned job stop failed: $($_.Exception.Message)") }
        finally { $job.Dispose() }
    } else { $result.cleanup = 0 }
    if (Get-Variable settings -ErrorAction SilentlyContinue) {
        foreach ($file in @('debug.log', 'session.json', 'inbox-default.json')) {
            $destination = if ($file -eq 'debug.log') { $file } else { "final-$file" }
            try { if (Test-Path "$settings/$file") { Copy-Item "$settings/$file" "$Evidence/$destination" } }
            catch { $cleanupErrors.Add("Evidence copy failed for ${file}: $($_.Exception.Message)") }
        }
    }
    if (Get-Variable state -ErrorAction SilentlyContinue) {
        foreach ($file in @('invocations.jsonl', 'unsupported.jsonl')) {
            try { if (Test-Path "$state/$file") { Copy-Item "$state/$file" "$Evidence/$file" } }
            catch { $cleanupErrors.Add("Evidence copy failed for ${file}: $($_.Exception.Message)") }
        }
        try { if (Test-Path $state) { Get-ChildItem $state -Filter 'reader-*.stderr.log' | Copy-Item -Destination $Evidence } }
        catch { $cleanupErrors.Add("Reader evidence copy failed: $($_.Exception.Message)") }
    }
    $result.scratchRemoved = $false
    if ($ownedStopped) {
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $removeError = $null
        do {
            try {
                if (Test-Path -LiteralPath $profile -ErrorAction Stop) { Remove-Item -LiteralPath $profile -Recurse -Force -ErrorAction Stop }
                $result.scratchRemoved = -not (Test-Path -LiteralPath $profile -ErrorAction Stop)
                $removeError = $null
            } catch { $removeError = $_.Exception.Message }
            if (-not $result.scratchRemoved -and $watch.Elapsed.TotalSeconds -lt 10) { Start-Sleep -Milliseconds 250 }
        } while (-not $result.scratchRemoved -and $watch.Elapsed.TotalSeconds -lt 10)
        if (-not $result.scratchRemoved) { $cleanupErrors.Add("Scratch removal failed: $removeError") }
    } else { $cleanupErrors.Add('Scratch retained because owned job was not verified stopped') }
    try { [CaptionProof]::RestoreDpi() } catch { $cleanupErrors.Add("Display restore failed: $($_.Exception.Message)") }
    if ($cleanupErrors.Count) {
        $result.passed = $false
        $cleanupError = $cleanupErrors -join '; '
        $result.error = if ($result.error) { "$($result.error); cleanup: $cleanupError" } else { "Cleanup: $cleanupError" }
    }
    Save $result "$Evidence/result.json"
}
if (-not $result.passed -or $result.cleanup -ne 0) { throw 'Robot avatar acceptance failed; see result.json' }
