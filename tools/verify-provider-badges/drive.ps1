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
$result = @{passed=$false; error=$null; checks=$checks; cleanup='pending'}
$job = $null
$profile = Join-Path $env:RUNNER_TEMP "provider-badges-$PID"
$providers = @(
    @{name='Codex work'; agent=1; hex='D97757'},
    @{name='Claude work'; agent=2; hex='3C78DC'},
    @{name='Pi work'; agent=3; hex='8FCB6B'},
    @{name='Antigravity work'; agent=8; hex='A77FE0'},
    @{name='Plain terminal'; agent=0; hex=''}
)
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
    $inset = [int][Math]::Floor(4 * $Dpi / 96)
    $side = [int][Math]::Floor(10 * $Dpi / 96)
    @{ side=$side; inset=$inset; left=($Row.right - $inset - $side); top=($Row.y + $inset) }
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
function Check-Badge($Row, [string]$Hex, [string]$Name) {
    $b = Badge $Row
    $bitmap = Capture $b.left $b.top $b.side $b.side
    try {
        $rgb = Colour $Hex
        $area = $bitmap.Width * $bitmap.Height
        $match = 0; $glyph = 0
        for ($y = 0; $y -lt $bitmap.Height; $y++) {
            for ($x = 0; $x -lt $bitmap.Width; $x++) {
                $p = $bitmap.GetPixel($x, $y)
                if (Near $p $rgb[0] $rgb[1] $rgb[2] 26) { $match++ }
                if ($p.R -ge 225 -and $p.G -ge 225 -and $p.B -ge 225) { $glyph++ }
            }
        }
        $topEdge = 0; $rightEdge = 0
        for ($i = 1; $i -lt $b.side; $i++) {
            if (Near $bitmap.GetPixel($i, 1) $rgb[0] $rgb[1] $rgb[2] 26) { $topEdge++ }
            if (Near $bitmap.GetPixel(($b.side - 1), $i) $rgb[0] $rgb[1] $rgb[2] 26) { $rightEdge++ }
        }
        if ($match -lt $area * .30) { throw "Provider colour absent: $Name match=$match area=$area" }
        if ($match -gt $area * .65) { throw "The badge fills its box instead of a triangle: $Name match=$match area=$area" }
        if ($topEdge -lt $b.side - 3) { throw "The badge is not a triangle along the top edge: $Name top=$topEdge side=$($b.side)" }
        if ($rightEdge -lt $b.side - 3) { throw "The badge is not a triangle down the right edge: $Name right=$rightEdge side=$($b.side)" }
        if (Near $bitmap.GetPixel(0, ($b.side - 1)) $rgb[0] $rgb[1] $rgb[2] 26) { throw "The badge is round or square, not a triangle: $Name" }
        if ($glyph -ne 0) { throw "A drawn glyph appeared in the badge: $Name glyph=$glyph" }
        $spill = 0
        foreach ($band in @(
            @{x=($Row.right); y=$b.top; w=1; h=$b.side},
            @{x=$b.left; y=($Row.y - 1); w=$b.side; h=1}
        )) {
            $patch = Capture $band.x $band.y $band.w $band.h
            try {
                for ($y = 0; $y -lt $patch.Height; $y++) { for ($x = 0; $x -lt $patch.Width; $x++) { if (Near $patch.GetPixel($x, $y) $rgb[0] $rgb[1] $rgb[2] 26) { $spill++ } } }
            } finally { $patch.Dispose() }
        }
        if ($spill -ne 0) { throw "The badge spills outside the avatar: $Name spill=$spill" }
        $overlap = 0
        foreach ($corner in @(
            @{x=($Row.x + 2); y=($Row.y + 2)},
            @{x=($Row.right - [int][Math]::Floor(8 * $Dpi / 96)); y=($Row.bottom - [int][Math]::Floor(8 * $Dpi / 96))}
        )) {
            $patch = Capture $corner.x $corner.y 6 6
            try {
                for ($y = 0; $y -lt $patch.Height; $y++) { for ($x = 0; $x -lt $patch.Width; $x++) { if (Near $patch.GetPixel($x, $y) $rgb[0] $rgb[1] $rgb[2] 26) { $overlap++ } } }
            } finally { $patch.Dispose() }
        }
        if ($overlap -ne 0) { throw "The badge covers another avatar corner: $Name overlap=$overlap" }
        $bitmap.Save("$Evidence/badge-$Name.png")
        $checks.Add(@{name="badge-$Name"; passed=$true; size=$Row.size; match=$match; area=$area; topEdge=$topEdge; rightEdge=$rightEdge})
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
                for ($x = 0; $x -lt $bitmap.Width; $x++) { if (Near $bitmap.GetPixel($x, $y) $rgb[0] $rgb[1] $rgb[2] 26) { $match++ } }
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
    if ((Get-FileHash $Exe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $ExpectedHash) { throw 'Binary checksum mismatch' }
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
        $tab = @{kind='tmux'; name=$providers[$i].name; manual=$true; tmux_host=0; tmux_session=$names[$i]; workspace=0; pinned_top=($i -lt 2); favorite=($i -eq 0); cv=$false; pid=0}
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
    [void](Wait-For 'restored list previews' {
        $published = Read-State 'inbox-default.json'
        @($published.shells | Where-Object { $_.pv -like '*answer 0*' }).Count -eq $providers.Count
    })
    $wanted = 0..($providers.Count - 1)
    $expanded = Wait-For 'every sidebar avatar' {
        $v = Rows 0
        if (@($v | Where-Object { $wanted -contains $_.index -and $_.size -ge [int][Math]::Floor(28 * $Dpi / 96) }).Count -eq $providers.Count) { ,$v }
    }
    for ($i = 0; $i -lt $providers.Count; $i++) {
        $row = @($expanded | Where-Object { $_.index -eq $i })[0]
        if ($providers[$i].agent -eq 0) { Check-NoBadge $row "expanded-$i" } else { Check-Badge $row $providers[$i].hex "expanded-$i" }
    }
    Save @{ requestedDpi=$Dpi; pinSize=[int][Math]::Floor(56 * $Dpi / 96); listSize=[int][Math]::Floor(36 * $Dpi / 96); triangleSide=[int][Math]::Floor(10 * $Dpi / 96); triangleInset=[int][Math]::Floor(4 * $Dpi / 96) } "$Evidence/display.json"
    Shot "sidebar-badges-$Dpi"
    $favourite = @($expanded | Where-Object { $_.index -eq 0 })[0]
    $marker = Capture ($favourite.right - [int][Math]::Floor(4 * $Dpi / 96) - 3) ($favourite.bottom - [int][Math]::Floor(4 * $Dpi / 96) - 3) 6 6
    try {
        $yellow = 0
        for ($y = 0; $y -lt 6; $y++) { for ($x = 0; $x -lt 6; $x++) { if (Near $marker.GetPixel($x, $y) 240 196 75 30) { $yellow++ } } }
        if ($yellow -lt 3) { throw "The favourite marker left the avatar bottom right while the badge is drawn: yellow=$yellow" }
        $checks.Add(@{name='badge-and-favourite-corners'; passed=$true; yellow=$yellow})
    } finally { $marker.Dispose() }
    $hover = @($expanded | Where-Object { $_.index -eq 1 })[0]
    $client = [ChatDeliveryDesktop+Rect]::new()
    if (-not [ChatDeliveryDesktop]::GetClientRect($main, [ref]$client)) { throw 'Main client bounds unavailable' }
    $rest = [ChatDeliveryDesktop]::ScreenPoint($main, ($client.Right - 12), ($client.Bottom - 12))
    [ProviderBadgeInput]::Move($rest.X, $rest.Y)
    Start-Sleep -Milliseconds 400
    $before = Capture ($hover.right + 6) ($hover.bottom - 10) 120 ([int][Math]::Floor(18 * $Dpi / 96))
    $point = [ChatDeliveryDesktop]::ScreenPoint($main, ($hover.x + [int]($hover.size / 2)), ($hover.y + [int]($hover.size / 2)))
    [ProviderBadgeInput]::Move($point.X, $point.Y)
    try {
        [void](Wait-For 'hover names the provider' {
            $now = Capture ($hover.right + 6) ($hover.bottom - 10) 120 ([int][Math]::Floor(18 * $Dpi / 96))
            try { if ((Difference $before $now) -ge 8) { $true } else { $false } } finally { $now.Dispose() }
        })
        Shot "hover-detail-$Dpi"
        $checks.Add(@{name='hover-detail'; passed=$true; row=1})
    } finally { $before.Dispose() }
    $jump = @($expanded | Where-Object { $_.index -eq 0 })[0]
    $jumpSide = [int][Math]::Floor(16 * $Dpi / 96)
    $jumpLeft = $jump.x - [int][Math]::Floor(4 * $Dpi / 96)
    $jumpTop = $jump.y - [int][Math]::Floor(4 * $Dpi / 96)
    $jumpX = $jumpLeft + [int][Math]::Floor($jumpSide / 4)
    $jumpY = $jumpTop + [int][Math]::Floor($jumpSide / 2)
    [ProviderBadgeInput]::Control($true)
    try {
        [void](Wait-For 'ctrl shows the jump badge' {
            $p = Capture $jumpX $jumpY 1 1
            try { $pixel = $p.GetPixel(0, 0); ($pixel.R -ge 200 -and $pixel.G -ge 200 -and $pixel.B -ge 200) } finally { $p.Dispose() }
        })
        Shot "jump-badge-$Dpi"
        $checks.Add(@{name='jump-badge-top-left'; passed=$true; row=0})
    } finally { [ProviderBadgeInput]::Control($false) }
    [void](Wait-For 'ctrl release hides the jump badge' {
        $p = Capture $jumpX $jumpY 1 1
        try { $pixel = $p.GetPixel(0, 0); ($pixel.R -lt 150 -and $pixel.G -lt 150 -and $pixel.B -lt 150) } finally { $p.Dispose() }
    })
    $offset = (Read-Log).Length
    [ChatDeliveryDesktop]::Chord(@(0x11, 0x10, 0x42))
    $collapsed = Wait-For 'collapsed sidebar avatars' {
        $v = Rows $offset
        if (@($v | Where-Object { $wanted -contains $_.index -and $_.size -lt [int][Math]::Floor(30 * $Dpi / 96) + 2 }).Count -eq $providers.Count) { ,$v }
    }
    for ($i = 0; $i -lt $providers.Count; $i++) {
        $row = @($collapsed | Where-Object { $_.index -eq $i })[0]
        if ($providers[$i].agent -eq 0) { Check-NoBadge $row "collapsed-$i" } else { Check-Badge $row $providers[$i].hex "collapsed-$i" }
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
