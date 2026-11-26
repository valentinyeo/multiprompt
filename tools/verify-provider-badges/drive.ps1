param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)][string]$ExpectedHash,
    [Parameter(Mandatory)][string]$Evidence,
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
Add-Type -Path "$PSScriptRoot/input.cs"
[void][ChatDeliveryDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
$env:IGSH_246 = '0'
$env:MULTIPROMPT_NO_LOGIN = '1'
$env:ZIGSHELL_DEBUG = '1'
$env:MP_VERIFY_PYTHON = (Get-Command python.exe).Source
$env:MP_VERIFY_BOUNDARY = (Resolve-Path "$PSScriptRoot/../verify-chat-delivery/boundary.py").Path
$env:PATH = (Split-Path $Exe) + ';' + $env:PATH
$env:PYTHONUTF8 = '1'
$checks = [Collections.Generic.List[object]]::new()
$result = @{passed=$false; error=$null; checks=$checks; cleanup='pending'; shell=@{version="$($PSVersionTable.PSVersion)"; modulePath=$env:PSModulePath; fileHash=[bool](Get-Command Get-FileHash -ErrorAction SilentlyContinue)}}
$job = $null
$profile = Join-Path $env:RUNNER_TEMP "provider-badges-$PID"
$providers = @(
    @{name='Codex work'; agent=1; hex='D97757'; tol=26; pinned=$true},
    @{name='Claude work'; agent=2; hex='10A37F'; tol=26; pinned=$true},
    @{name='Pi work'; agent=3; hex='8E95A2'; tol=9; pinned=$false},
    @{name='Antigravity work'; agent=8; hex='3C78DC'; tol=26; pinned=$false},
    @{name='Plain terminal'; agent=0; hex=''; tol=26; pinned=$false}
)
function Wait-For([string]$Name, [scriptblock]$Check) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 150 } while ($watch.Elapsed.TotalSeconds -lt 60)
    throw "Timed out: $Name"
}
function Save($Value, [string]$File) { [IO.File]::WriteAllText($File, ($Value | ConvertTo-Json -Depth 15), [Text.UTF8Encoding]::new($false)) }
function Hash-File([string]$Path) {
    $stream = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $bytes = $sha.ComputeHash($stream) } finally { $sha.Dispose() }
    } finally { $stream.Dispose() }
    ($bytes | ForEach-Object { $_.ToString('x2') }) -join ''
}
function Read-Log {
    if (-not (Test-Path "$settings/debug.log")) { return '' }
    $stream = [IO.File]::Open("$settings/debug.log", 'Open', 'Read', 'ReadWrite')
    $reader = [IO.StreamReader]::new($stream)
    try { $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function Read-State([string]$File) {
    Wait-For "readable $File snapshot" {
        try { Get-Content (Join-Path $settings $File) -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
        catch { $null }
    }
}
function Shot([string]$Name) {
    $bounds = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = [Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.Size); $bitmap.Save("$Evidence/$Name.png") } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Badge($Row) {
    $side = [int][Math]::Max(6, [int][Math]::Floor(($Row.size * 10 + 18) / 36))
    $border = [int][Math]::Max(1, [int][Math]::Floor(($Row.size + 18) / 36))
    @{ side=$side; border=$border; right=$Row.right; left=($Row.right - $side); top=$Row.y }
}
function In-Triangle([int]$x, [int]$y, [int]$Right, [int]$Top, [int]$Legs) {
    ($x -le $Right) -and ($x -ge ($Right - $Legs)) -and ($y -ge $Top) -and ($y -le ($Top + $Legs)) -and (($y - $Top) -le ($x - ($Right - $Legs)))
}
function Fill-Clear([int]$x, [int]$y, [int]$Right, [int]$Top, [int]$Legs) {
    ($x -ge $Right) -or ($x + 1 -le ($Right - $Legs)) -or ($y + 1 -le $Top) -or ($y -ge ($Top + $Legs)) -or (($y - $Top) -ge ($x + 1 - ($Right - $Legs)))
}
function Corners-Inside([int]$x, [int]$y, [int]$Right, [int]$Top, [int]$Legs) {
    foreach ($corner in @(@(0,0), @(1,0), @(0,1), @(1,1))) {
        if (-not (In-Triangle ($x + $corner[0]) ($y + $corner[1]) $Right $Top $Legs)) { return $false }
    }
    $true
}
function Corners-Outside([int]$x, [int]$y, [int]$Right, [int]$Top, [int]$Legs) {
    foreach ($corner in @(@(0,0), @(1,0), @(0,1), @(1,1))) {
        if (In-Triangle ($x + $corner[0]) ($y + $corner[1]) $Right $Top $Legs) { return $false }
    }
    $true
}
function Badge-Coverage([int]$x, [int]$y, $Box) {
    $fill = $Box.side - $Box.border * 2
    $edgeRight = $Box.side; $edgeTop = 0
    $fillRight = $edgeRight - $Box.border; $fillTop = $edgeTop + $Box.border
    if ($fill -gt 0 -and (Corners-Inside $x $y $fillRight $fillTop $fill)) { return 'inside' }
    if (Corners-Outside $x $y $edgeRight $edgeTop $Box.side) { return 'outside' }
    if ((Corners-Inside $x $y $edgeRight $edgeTop $Box.side) -and ($fill -le 0 -or (Fill-Clear $x $y $fillRight $fillTop $fill))) { return 'border' }
    'edge'
}
function Capture([int]$x, [int]$y, [int]$w, [int]$h) {
    $origin = [ChatDeliveryDesktop]::ScreenPoint($main, $x, $y)
    $bitmap = [Drawing.Bitmap]::new($w, $h)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen($origin.X, $origin.Y, 0, 0, $bitmap.Size) } finally { $graphics.Dispose() }
    $bitmap
}
function Near($Pixel, [int]$R, [int]$G, [int]$B, [int]$Tolerance) {
    ([Math]::Abs($Pixel.R - $R) -le $Tolerance) -and ([Math]::Abs($Pixel.G - $G) -le $Tolerance) -and ([Math]::Abs($Pixel.B - $B) -le $Tolerance)
}
function Colour([string]$Hex) { @([Convert]::ToInt32($Hex.Substring(0, 2), 16), [Convert]::ToInt32($Hex.Substring(2, 2), 16), [Convert]::ToInt32($Hex.Substring(4, 2), 16)) }
function Diagnose-Badge($Bitmap, $Box, [string]$Name, [string]$Reason, $Classes, $Colours, $Stats) {
    try { $Bitmap.Save("$Evidence/badge-$Name.png") } catch { }
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add("badge=$Name")
    $lines.Add("reason=$Reason")
    $lines.Add("side=$($Box.side) border=$($Box.border) left=$($Box.left) top=$($Box.top)")
    foreach ($entry in $Stats.GetEnumerator()) { $lines.Add("$($entry.Key)=$($entry.Value)") }
    $lines.Add('classes: I=wholly inside the provider fill a pixel clear of every edge, B=wholly in its dark separator border, O=wholly outside the triangle, E=an antialiased boundary')
    foreach ($row in $Classes) { $lines.Add($row) }
    $lines.Add('pixels: RRGGBB per pixel on the same grid')
    foreach ($row in $Colours) { $lines.Add($row) }
    [IO.File]::WriteAllLines("$Evidence/badge-$Name-pixels.txt", $lines)
}
function Check-Badge($Row, [string]$Hex, [int]$Tolerance, [string]$Name) {
    $b = Badge $Row
    $bitmap = Capture $b.left $b.top $b.side $b.side
    try {
        $rgb = Colour $Hex
        $area = $bitmap.Width * $bitmap.Height
        $match = 0
        for ($y = 0; $y -lt $bitmap.Height; $y++) {
            for ($x = 0; $x -lt $bitmap.Width; $x++) {
                if (Near $bitmap.GetPixel($x, $y) $rgb[0] $rgb[1] $rgb[2] $Tolerance) { $match++ }
            }
        }
        $inside = 0; $outside = 0; $edge = 0; $bordered = 0; $missing = 0; $leaked = 0; $glyph = 0; $unbordered = 0
        $classes = [Collections.Generic.List[string]]::new()
        $colours = [Collections.Generic.List[string]]::new()
        for ($y = 0; $y -lt $bitmap.Height; $y++) {
            $classRow = [Text.StringBuilder]::new()
            $colourRow = [Text.StringBuilder]::new()
            for ($x = 0; $x -lt $bitmap.Width; $x++) {
                $pixel = $bitmap.GetPixel($x, $y)
                $class = Badge-Coverage $x $y $b
                if ($class -eq 'inside') {
                    $inside++
                    [void]$classRow.Append('I')
                    if (-not (Near $pixel $rgb[0] $rgb[1] $rgb[2] $Tolerance)) { $missing++ }
                } elseif ($class -eq 'outside') {
                    $outside++
                    [void]$classRow.Append('O')
                    if (Near $pixel $rgb[0] $rgb[1] $rgb[2] $Tolerance) { $leaked++ }
                } elseif ($class -eq 'border') {
                    $bordered++
                    [void]$classRow.Append('B')
                    if (($pixel.R + $pixel.G + $pixel.B) -ge 240) { $unbordered++ }
                } else {
                    $edge++
                    [void]$classRow.Append('E')
                }
                if (($class -eq 'inside' -or $class -eq 'border') -and $pixel.R -ge 225 -and $pixel.G -ge 225 -and $pixel.B -ge 225) { $glyph++ }
                [void]$colourRow.Append(('{0:X2}{1:X2}{2:X2}' -f $pixel.R, $pixel.G, $pixel.B))
            }
            $classes.Add($classRow.ToString())
            $colours.Add($colourRow.ToString())
        }
        $stats = @{inside=$inside; outside=$outside; bordered=$bordered; edge=$edge; missing=$missing; leaked=$leaked; unbordered=$unbordered; glyph=$glyph; match=$match; area=$area}
        $fail = $null
        if ($match -lt $area * .08) { $fail = "Provider colour absent: $Name match=$match area=$area" }
        elseif ($match -gt $area * .85) { $fail = "The badge fills its box instead of a triangle: $Name match=$match area=$area" }
        elseif ($inside -lt 4 -or $inside * 100 -lt $area * 6) { $fail = "The triangle is missing its solid body: $Name inside=$inside area=$area" }
        elseif ($missing -ne 0) { $fail = "The solid triangle body is not the provider colour: $Name missing=$missing inside=$inside" }
        elseif ($leaked -ne 0) { $fail = "The triangle paints outside its corner shape: $Name leaked=$leaked outside=$outside" }
        elseif ($b.border -ge 2 -and $bordered -lt 4) { $fail = "The badge lost its dark separator border: $Name bordered=$bordered side=$($b.side)" }
        elseif ($unbordered -ne 0) { $fail = "The separator border is not dark: $Name unbordered=$unbordered bordered=$bordered" }
        elseif ($glyph -ne 0) { $fail = "A drawn glyph appeared in the badge: $Name glyph=$glyph" }
        if ($fail) { Diagnose-Badge $bitmap $b $Name $fail $classes $colours $stats; throw $fail }
        $spill = 0
        foreach ($band in @(
            @{x=($Row.right); y=$b.top; w=1; h=$b.side},
            @{x=$b.left; y=($Row.y - 1); w=$b.side; h=1}
        )) {
            $patch = Capture $band.x $band.y $band.w $band.h
            try {
                for ($y = 0; $y -lt $patch.Height; $y++) { for ($x = 0; $x -lt $patch.Width; $x++) { if (Near $patch.GetPixel($x, $y) $rgb[0] $rgb[1] $rgb[2] $Tolerance) { $spill++ } } }
            } finally { $patch.Dispose() }
        }
        if ($spill -ne 0) {
            $stats.spill = $spill
            $reason = "The badge spills outside the avatar: $Name spill=$spill"
            Diagnose-Badge $bitmap $b $Name $reason $classes $colours $stats
            throw $reason
        }
        $bitmap.Save("$Evidence/badge-$Name.png")
        $checks.Add(@{name="badge-$Name"; passed=$true; size=$Row.size; match=$match; area=$area; side=$b.side; border=$b.border; inside=$inside; outside=$outside; edge=$edge})
    } finally { $bitmap.Dispose() }
}
function Check-NoBadge($Row, [string]$Name) {
    $b = Badge $Row
    $bitmap = Capture $b.left $b.top $b.side $b.side
    try {
        $area = $bitmap.Width * $bitmap.Height
        foreach ($provider in $providers) {
            if ($provider.hex -eq '') { continue }
            $rgb = Colour $provider.hex
            $match = 0
            for ($y = 0; $y -lt $bitmap.Height; $y++) {
                for ($x = 0; $x -lt $bitmap.Width; $x++) { if (Near $bitmap.GetPixel($x, $y) $rgb[0] $rgb[1] $rgb[2] $provider.tol) { $match++ } }
            }
            if ($match -gt $area * .06) { throw "A $($provider.name) badge appeared without a provider: $Name match=$match area=$area" }
        }
        $checks.Add(@{name="no-badge-$Name"; passed=$true; size=$Row.size; area=$area})
    } finally { $bitmap.Dispose() }
}
function Rows([int]$Offset) {
    $log = Read-Log
    $tail = $log.Substring([Math]::Min($Offset, $log.Length))
    $found = [ordered]@{}
    foreach ($m in [regex]::Matches($tail, '\[photo-proof\] (?:expanded|pinned|collapsed) target=(\d+) rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)')) {
        $g = $m.Groups
        $row = @{index=[int]$g[1].Value; x=[int]$g[2].Value; y=[int]$g[3].Value; right=[int]$g[4].Value; bottom=[int]$g[5].Value}
        $row.size = $row.right - $row.x
        $key = "$($row.index)"
        if ($found.Contains($key)) { $found.Remove($key) }
        $found[$key] = $row
    }
    @($found.Values)
}
function Ring-White([int]$X, [int]$Y, [int]$Side) {
    $bitmap = Capture $X $Y $Side $Side
    try {
        $centre = [int][Math]::Floor($Side / 2)
        $reach = [int][Math]::Floor($Side * 3 / 8)
        foreach ($offset in @(@(($centre - $reach), $centre), @(($centre + $reach), $centre), @($centre, ($centre - $reach)), @($centre, ($centre + $reach)))) {
            $pixel = $bitmap.GetPixel($offset[0], $offset[1])
            if ($pixel.R -lt 200 -or $pixel.G -lt 200 -or $pixel.B -lt 200) { return $false }
        }
        $true
    } finally { $bitmap.Dispose() }
}
function Difference($First, $Second) {
    $changed = 0
    for ($y = 0; $y -lt $First.Height; $y++) {
        for ($x = 0; $x -lt $First.Width; $x++) {
            $a = $First.GetPixel($x, $y); $b = $Second.GetPixel($x, $y)
            if (([Math]::Abs($a.R - $b.R) + [Math]::Abs($a.G - $b.G) + [Math]::Abs($a.B - $b.B)) -gt 30) { $changed++ }
        }
    }
    $changed
}
try {
    [CaptionProof]::SetDpi($Dpi)
    $actualHash = Hash-File $Exe
    Save @{ requestedDpi=$Dpi; exe=$Exe; expectedVersion=$ExpectedVersion; expectedHash=$ExpectedHash; actualHash=$actualHash; evidence=$Evidence; started=(Get-Date).ToString('o') } "$Evidence/provenance.json"
    if ($actualHash -ne $ExpectedHash) { throw 'Binary checksum mismatch' }
    if (-not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Binary version mismatch' }
    $names = @()
    for ($i = 0; $i -lt $providers.Count; $i++) { $names += "live-badge-$i" }
    $sids = @{}
    $panes = @{}
    for ($i = 0; $i -lt $names.Count; $i++) {
        $panes[$names[$i]] = 5300 + $i
        $sids[$names[$i]] = ('a1b2c3d4-0927-4000-8000-00000000b5{0:D2}' -f $i)
    }
    $settings = "$profile/roaming/ZigShell"
    $state = "$profile/remote-state"
    New-Item -ItemType Directory -Force $settings, $state, "$profile/local", "$profile/home" | Out-Null
    $env:APPDATA = "$profile/roaming"; $env:LOCALAPPDATA = "$profile/local"; $env:USERPROFILE = "$profile/home"; $env:HOME = "$profile/home"
    $env:MP_VERIFY_STATE = $state
    Save @{name='provider-badges'; fake=$true; mode='idle'; suggestion=''; sessions=$names; panes=$panes; sids=$sids; home="$profile/home"; procRoot=([IO.Path]::GetPathRoot($profile) + 'proc')} "$state/state.json"
    & $env:MP_VERIFY_PYTHON $env:MP_VERIFY_BOUNDARY shell seed-many 1
    if ($LASTEXITCODE -ne 0) { throw 'Transcript seed failed' }
    $tabs = @()
    for ($i = 0; $i -lt $providers.Count; $i++) {
        $tab = @{kind='tmux'; name=$providers[$i].name; manual=$true; tmux_host=0; tmux_session=$names[$i]; workspace=0; color=6; pinned_top=$providers[$i].pinned; favorite=($i -eq 0); cv=$false; pid=0}
        if ($providers[$i].agent -ne 0) {
            $tab.ai_agent = $providers[$i].agent
            $tab.csid = $sids[$names[$i]]
        }
        $tabs += $tab
    }
    Save @{active_tab=0; single_window=$true; active_workspace=0; workspace_count=1; workspaces=@(@{name='Badges'; wid='workspace-badges'}); chat_active=$false; amoled_theme=$true; tabs=$tabs} "$settings/session.json"
    [IO.File]::WriteAllText("$settings/theme-mode.txt", 'amoled')
    [IO.File]::WriteAllText("$settings/ssh-path.txt", (Join-Path (Split-Path $Exe) 'ssh.exe'))
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $profile, "$Evidence/stdout.log", "$Evidence/stderr.log", '--no-window-restore')
    $main = Wait-For 'owned main window' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    [void](Wait-For 'foreground owned app' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $main) })
    [void](Wait-For 'all restored sessions' { if (Test-Path "$settings/inbox-default.json") { $doc = Read-State 'inbox-default.json'; if (@($doc.shells).Count -eq $providers.Count) { $true } } })
    [void](Wait-For 'restored provider identities' {
        $published = Read-State 'inbox-default.json'
        $shells = @($published.shells)
        $matched = $shells.Count -eq $providers.Count
        for ($i = 0; $matched -and $i -lt $providers.Count; $i++) {
            $field = $shells[$i].PSObject.Properties['ag']
            $agent = if ($null -ne $field) { [int]$field.Value } else { 0 }
            $matched = $agent -eq $providers[$i].agent -and $shells[$i].name -eq $providers[$i].name
        }
        $matched
    })
    $wanted = 0..($providers.Count - 1)
    $expanded = Wait-For 'every sidebar avatar' {
        $v = Rows 0
        if (@($v | Where-Object { $wanted -contains $_.index -and $_.size -ge [int][Math]::Floor(28 * $Dpi / 96) }).Count -eq $providers.Count) { ,$v }
    }
    for ($i = 0; $i -lt $providers.Count; $i++) {
        $row = @($expanded | Where-Object { $_.index -eq $i })[0]
        $place = if ($providers[$i].pinned) { 'pinned' } else { 'recent' }
        if ($providers[$i].agent -eq 0) { Check-NoBadge $row "$place-$i" } else { Check-Badge $row $providers[$i].hex $providers[$i].tol "$place-$i" }
    }
    $listRow = @($expanded | Where-Object { $_.index -eq 2 })[0]
    $pinRow = @($expanded | Where-Object { $_.index -eq 0 })[0]
    Save @{ requestedDpi=$Dpi; pinSize=$pinRow.size; listSize=$listRow.size; triangle=@(@{size='list'; side=(Badge $listRow).side; border=(Badge $listRow).border}, @{size='pinned'; side=(Badge $pinRow).side; border=(Badge $pinRow).border}) } "$Evidence/display.json"
    Shot "sidebar-badges-$Dpi"
    $favourite = @($expanded | Where-Object { $_.index -eq 0 })[0]
    $marker = Capture ($favourite.right - [int][Math]::Floor(4 * $Dpi / 96) - 3) ($favourite.bottom - [int][Math]::Floor(4 * $Dpi / 96) - 3) 6 6
    try {
        $yellow = 0
        for ($y = 0; $y -lt 6; $y++) { for ($x = 0; $x -lt 6; $x++) { if (Near $marker.GetPixel($x, $y) 240 196 75 30) { $yellow++ } } }
        if ($yellow -lt 3) { throw "The favourite marker left the avatar bottom right while the badge is drawn: yellow=$yellow" }
        $checks.Add(@{name='badge-and-favourite-corners'; passed=$true; yellow=$yellow})
    } finally { $marker.Dispose() }
    $hover = @($expanded | Where-Object { $_.index -eq 2 })[0]
    $stripLeft = $hover.right + [int][Math]::Floor(6 * $Dpi / 96)
    $stripTop = $hover.bottom - [int][Math]::Floor(6 * $Dpi / 96)
    $stripWidth = [int][Math]::Floor(120 * $Dpi / 96)
    $stripHeight = [int][Math]::Floor(22 * $Dpi / 96)
    $client = [ChatDeliveryDesktop+Rect]::new()
    if (-not [ChatDeliveryDesktop]::GetClientRect($main, [ref]$client)) { throw 'Main client bounds unavailable' }
    $rest = [ChatDeliveryDesktop]::ScreenPoint($main, ($client.Right - 12), ($client.Bottom - 12))
    [ProviderBadgeInput]::Move($rest.X, $rest.Y)
    Start-Sleep -Milliseconds 400
    $before = Capture $stripLeft $stripTop $stripWidth $stripHeight
    $point = [ChatDeliveryDesktop]::ScreenPoint($main, ($hover.x + [int]($hover.size / 2)), ($hover.y + [int]($hover.size / 2)))
    [ProviderBadgeInput]::Move($point.X, $point.Y)
    try {
        [void](Wait-For 'hover names the provider' {
            $now = Capture $stripLeft $stripTop $stripWidth $stripHeight
            try { if ((Difference $before $now) -ge 8) { $true } else { $false } } finally { $now.Dispose() }
        })
        Shot "hover-detail-$Dpi"
        $checks.Add(@{name='hover-detail'; passed=$true; row=2})
    } finally { $before.Dispose() }
    $jump = @($expanded | Where-Object { $_.index -eq 0 })[0]
    $jumpSide = [int][Math]::Floor(16 * $Dpi / 96)
    $jumpLeft = $jump.x - [int][Math]::Floor(4 * $Dpi / 96)
    $jumpTop = $jump.y - [int][Math]::Floor(4 * $Dpi / 96)
    $jumpBase = Capture $jumpLeft $jumpTop $jumpSide $jumpSide
    [ProviderBadgeInput]::Control($true)
    try {
        [void](Wait-For 'ctrl shows the jump badge' { Ring-White $jumpLeft $jumpTop $jumpSide })
        Shot "jump-badge-$Dpi"
        $checks.Add(@{name='jump-badge-top-left'; passed=$true; row=0})
    } finally { [ProviderBadgeInput]::Control($false) }
    try {
        [void](Wait-For 'ctrl release hides the jump badge' {
            $now = Capture $jumpLeft $jumpTop $jumpSide $jumpSide
            try { (Difference $jumpBase $now) -eq 0 } finally { $now.Dispose() }
        })
    } finally { $jumpBase.Dispose() }
    $offset = (Read-Log).Length
    [ChatDeliveryDesktop]::Chord(@(0x11, 0x10, 0x42))
    $collapsed = Wait-For 'collapsed sidebar avatars' {
        $v = Rows $offset
        if (@($v | Where-Object { $wanted -contains $_.index -and $_.size -lt [int][Math]::Floor(30 * $Dpi / 96) + 2 }).Count -eq $providers.Count) { ,$v }
    }
    for ($i = 0; $i -lt $providers.Count; $i++) {
        $row = @($collapsed | Where-Object { $_.index -eq $i })[0]
        if ($providers[$i].agent -eq 0) { Check-NoBadge $row "collapsed-$i" } else { Check-Badge $row $providers[$i].hex $providers[$i].tol "collapsed-$i" }
    }
    Shot "sidebar-collapsed-badges-$Dpi"
    [ChatDeliveryDesktop]::Chord(@(0x11, 0x10, 0x42))
    [ChatDeliveryDesktop]::Chord(@(0x11, 0x10, 0x42))
    Copy-Item "$settings/session.json" "$Evidence/session.json"
    Save @(Rows 0) "$Evidence/rows.json"
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
if (-not $result.passed -or $result.cleanup -ne 0) { throw 'Provider badge acceptance failed; see result.json' }
