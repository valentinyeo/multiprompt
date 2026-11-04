param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)][string]$ExpectedHash,
    [Parameter(Mandatory)][string]$Evidence
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'GitHub Windows only' }
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type -Path "$PSScriptRoot/../verify-chat-delivery/desktop.cs"
Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -Path "$PSScriptRoot/../../.claude/skills/verify-multiprompt/control-native.cs"
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class PhotoDialogOwner {
    [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr window, uint command);
}
'@
[void][ChatDeliveryDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
$profile = Join-Path $env:RUNNER_TEMP ("bot-photo-" + [guid]::NewGuid().ToString('N'))
$settings = Join-Path $profile 'roaming/ZigShell'
$env:APPDATA = Join-Path $profile 'roaming'
$env:LOCALAPPDATA = Join-Path $profile 'local'
$env:USERPROFILE = Join-Path $profile 'home'
$env:HOME = $env:USERPROFILE
$env:MULTIPROMPT_NO_LOGIN = '1'
$env:ZIGSHELL_DEBUG = '1'
$env:IGSH_246 = '0'
$env:PATH = (Split-Path $Exe) + ';' + $env:PATH
New-Item -ItemType Directory -Force $settings, $env:LOCALAPPDATA, $env:USERPROFILE, (Join-Path $env:USERPROFILE 'Desktop'), (Join-Path $env:USERPROFILE 'Documents') | Out-Null
$checks = [Collections.Generic.List[object]]::new()
$result = @{ feature='bot-photo'; version=$ExpectedVersion; sha256=$ExpectedHash; status='failed'; checks=$checks; cleanup='pending'; error=$null }
$job = $null
$app = $null
$main = [IntPtr]::Zero
function Save($Value, [string]$Path) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false)) }
function Wait-For([string]$Name, [scriptblock]$Test) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do { $value = & $Test; if ($value) { return $value }; Start-Sleep -Milliseconds 150 } while ($timer.Elapsed.TotalSeconds -lt 45)
    throw "Timed out: $Name"
}
function Check([string]$Name, [bool]$Condition) {
    $checks.Add(@{name=$Name; passed=$Condition})
    if (-not $Condition) { throw "Failed: $Name" }
}
function Log {
    $path = Join-Path $settings 'debug.log'
    if (-not (Test-Path $path)) { return '' }
    $stream = [IO.File]::Open($path, 'Open', 'Read', 'ReadWrite')
    $reader = [IO.StreamReader]::new($stream)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function State { Get-Content (Join-Path $settings 'session.json') -Raw | ConvertFrom-Json }
function Index-Name([string]$Name) {
    $tabs = @((State).tabs)
    $indices = @(for ($i = 0; $i -lt $tabs.Count; $i++) { if ($tabs[$i].name -ceq $Name) { $i } })
    if ($indices.Count -ne 1) { throw 'Local tab name missing or duplicated' }
    return [int]$indices[0]
}
function Index-For([string]$Id) {
    $tabs = @((State).tabs)
    $indices = @(for ($i = 0; $i -lt $tabs.Count; $i++) {
        if ($tabs[$i].PSObject.Properties['avatar_local_id'] -and $tabs[$i].avatar_local_id -ceq $Id) { $i }
    })
    if ($indices.Count -ne 1) { throw 'Local avatar identity missing or duplicated' }
    return [int]$indices[0]
}
function Focus {
    [void](Wait-For 'owned foreground' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, [uint32]$app.Id, $main) })
}
function Press([int[]]$Keys) {
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'App does not own keyboard' }
    $opensPalette = $Keys.Count -eq 2 -and $Keys[0] -eq 0x11 -and $Keys[1] -eq 0x4b
    $offset = if ($opensPalette) { (Log).Length } else { 0 }
    [VerifyNative]::Chord($Keys)
    if ($opensPalette) {
        [void](Wait-For 'palette opened' { $trace = Log; $trace.Length -ge $offset -and $trace.Substring($offset) -match '\[palette\] ready chars=0 count=[1-9]\d*' })
    }
}
function Query([string]$Text, [int]$Target) {
    $before = (Log).Length
    [VerifyNative]::Text($Text)
    [void](Wait-For "palette $Text selects $Target" { $s = Log; $s.Length -ge $before -and $s.Substring($before) -match ("\[palette\] ready chars=" + $Text.Length + " count=[1-9]\d* target=" + $Target + "(?:\r?\n|$)") })
}
function Look([string]$Menu, [string]$Choice, [int]$Target) {
    Focus
    Press @(0x11, 0x4b)
    Query $Menu $(if ($Menu -eq 'bot face') { 7187 } else { 7188 })
    Press @(0x0d)
    Query $Choice $Target
    Press @(0x0d)
}
function Dialog {
    $dialog = Wait-For 'owned file dialog' {
        $window = [ChatDeliveryDesktop]::GetForegroundWindow()
        if ($window -ne [IntPtr]::Zero -and [ChatDeliveryDesktop]::Owner($window) -eq [uint32]$app.Id -and [ChatDeliveryDesktop]::Class($window) -eq '#32770' -and [PhotoDialogOwner]::GetWindow($window, 4) -eq $main) { $window }
    }
    return $dialog
}
function Pick([string]$Path) {
    $start = (Log).Length
    Look 'bot face' 'upload image' 7193
    $dialog = Dialog
    if ($Path -eq '') {
        [ChatDeliveryDesktop]::Chord(@(0x1b))
        [void](Wait-For 'cancelled dialog closed' { [ChatDeliveryDesktop]::GetForegroundWindow() -ne $dialog })
        return
    }
    [Windows.Forms.Clipboard]::SetText($Path)
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $dialog) { throw 'File dialog lost foreground' }
    [ChatDeliveryDesktop]::Chord(@(0x12, 0x4e))
    [ChatDeliveryDesktop]::Chord(@(0x11, 0x41))
    [ChatDeliveryDesktop]::Chord(@(0x11, 0x56))
    [ChatDeliveryDesktop]::Chord(@(0x0d))
    [void](Wait-For 'file dialog closed' { [ChatDeliveryDesktop]::GetForegroundWindow() -ne $dialog })
    [void](Wait-For 'import completed' { $trace = Log; $trace.Length -ge $start -and $trace.Substring($start) -match '\[bot-photo\] import=(ok|failed)' })
}
function Shot([string]$Name) {
    $bounds = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = [Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bitmap.Size); $bitmap.Save((Join-Path $Evidence "$Name.png")) } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Assets { @(Get-ChildItem (Join-Path $env:LOCALAPPDATA 'ZigShell/bot-avatars') -Filter '*.png' -ErrorAction SilentlyContinue) }
function Assert-Avatar([string]$Surface, [int]$Index, [string]$Name, [bool]$Tall = $false) {
    $pattern = "\[photo-proof\] $Surface target=$Index rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)"
    $match = Wait-For "$Surface avatar coordinates" { $matches = [regex]::Matches((Log), $pattern); if ($matches.Count -gt 0) { $matches[$matches.Count-1] } }
    $x = [int]$match.Groups[1].Value; $y = [int]$match.Groups[2].Value
    $size = [int]$match.Groups[3].Value - $x
    if ($size -lt 20) { throw 'Invalid avatar bounds' }
    $origin = [ChatDeliveryDesktop]::ScreenPoint($main, $x, $y)
    $bitmap = [Drawing.Bitmap]::new($size, $size)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($origin.X, $origin.Y, 0, 0, $bitmap.Size)
        $green = $bitmap.GetPixel([int]($size * .3), [int]($size * .3))
        $blue = $bitmap.GetPixel([int]($size * .6), [int]($size * .6))
        $corner = $bitmap.GetPixel(0, 0)
        $centerOk = if ($Tall) { $green.R -gt 150 -and $green.G -gt 150 -and $green.B -lt 100 -and $blue.R -gt 120 -and $blue.B -gt 120 -and $blue.G -lt 100 } else { $green.G -gt 140 -and $green.R -lt 100 -and $blue.B -gt 120 -and $blue.R -lt 100 }
        $cornerIsPhoto = if ($Tall) { $corner.R -gt 150 -and $corner.G -gt 150 -and $corner.B -lt 100 } else { $corner.G -gt 140 -and $corner.R -lt 100 }
        Check "$Name-circle-center" $centerOk
        Check "$Name-circle-corner" (-not $cornerIsPhoto)
        $bitmap.Save((Join-Path $Evidence "$Name.png"))
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Capture-Avatar([int]$Index, [string]$Name) {
    $pattern = "\[photo-proof\] expanded target=$Index rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)"
    $match = Wait-For 'other avatar coordinates' { $found = [regex]::Matches((Log), $pattern); if ($found.Count -gt 0) { $found[$found.Count-1] } }
    $x = [int]$match.Groups[1].Value; $y = [int]$match.Groups[2].Value
    $size = [int]$match.Groups[3].Value - $x
    $origin = [ChatDeliveryDesktop]::ScreenPoint($main, $x, $y)
    $bitmap = [Drawing.Bitmap]::new($size, $size)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen($origin.X, $origin.Y, 0, 0, $bitmap.Size); $bitmap.Save((Join-Path $Evidence "$Name.png")) } finally { $graphics.Dispose(); $bitmap.Dispose() }
    return (Get-FileHash (Join-Path $Evidence "$Name.png") -Algorithm SHA256).Hash
}
function Assert-Generated([int]$Index, [string]$Name) {
    $pattern = "\[photo-proof\] expanded target=$Index rect=(-?\d+),(-?\d+),(-?\d+),(-?\d+)"
    $match = Wait-For 'generated avatar coordinates' { $found = [regex]::Matches((Log), $pattern); if ($found.Count -gt 0) { $found[$found.Count-1] } }
    $x = [int]$match.Groups[1].Value; $y = [int]$match.Groups[2].Value
    $size = [int]$match.Groups[3].Value - $x
    $origin = [ChatDeliveryDesktop]::ScreenPoint($main, $x, $y)
    $bitmap = [Drawing.Bitmap]::new($size, $size)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($origin.X, $origin.Y, 0, 0, $bitmap.Size)
        $green = $bitmap.GetPixel([int]($size * .3), [int]($size * .3))
        $blue = $bitmap.GetPixel([int]($size * .6), [int]($size * .6))
        Check "$Name-not-photo" (-not ($green.R -gt 150 -and $green.G -gt 150 -and $green.B -lt 100 -and $blue.R -gt 120 -and $blue.B -gt 120 -and $blue.G -lt 100))
        $bitmap.Save((Join-Path $Evidence "$Name.png"))
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function New-Fixture([string]$Path, [int]$Width, [int]$Height, [bool]$Jpeg) {
    $bmp = [Drawing.Bitmap]::new($Width, $Height)
    $g = [Drawing.Graphics]::FromImage($bmp)
    try {
        $g.Clear([Drawing.Color]::Red)
        $side = [Math]::Min($Width, $Height)
        $center = if ($Jpeg) { [Drawing.Brushes]::Yellow } else { [Drawing.Brushes]::Lime }
        $marker = if ($Jpeg) { [Drawing.Brushes]::Magenta } else { [Drawing.Brushes]::Blue }
        $g.FillRectangle($center, [int](($Width-$side)/2), [int](($Height-$side)/2), $side, $side)
        $g.FillRectangle($marker, [int]($Width/2), [int]($Height/2), [int]($side/4), [int]($side/4))
        $bmp.Save($Path, $(if ($Jpeg) { [Drawing.Imaging.ImageFormat]::Jpeg } else { [Drawing.Imaging.ImageFormat]::Png }))
    } finally { $g.Dispose(); $bmp.Dispose() }
}
function Assert-Normalized([string]$Path, [bool]$Tall = $false) {
    $bitmap = [Drawing.Bitmap]::new($Path)
    try {
        Check 'normalized-size' ($bitmap.Width -eq 256 -and $bitmap.Height -eq 256)
        $green = $bitmap.GetPixel(48, 48); $blue = $bitmap.GetPixel(150, 150)
        $centerOk = if ($Tall) { $green.R -gt 180 -and $green.G -gt 180 -and $green.B -lt 80 } else { $green.G -gt 180 -and $green.R -lt 60 }
        $markerOk = if ($Tall) { $blue.R -gt 160 -and $blue.B -gt 160 -and $blue.G -lt 80 } else { $blue.B -gt 160 -and $blue.R -lt 80 }
        Check 'center-crop-excludes-red-edge' $centerOk
        Check 'asymmetric-center-retained' $markerOk
    } finally { $bitmap.Dispose() }
}
function Start-App {
    $script:job = [VerifyJob]::new()
    $script:app = $job.Start($Exe, $profile, (Join-Path $Evidence "stdout-$($checks.Count).log"), (Join-Path $Evidence "stderr-$($checks.Count).log"), '--single-window --no-window-restore')
    $script:main = Wait-For 'owned main' {
        if ($app.HasExited) { throw ('App exited before its main window: ' + $app.ExitCode) }
        $h = [ChatDeliveryDesktop]::Window([uint32]$app.Id)
        if ($h -ne [IntPtr]::Zero) { $h }
    }
    Focus
    [void](Wait-For 'local tabs restored' { try { @((State).tabs).Count -ge 2 -and (Log) -match 'launch step=browser' } catch { $false } })
}
function Stop-App {
    $stopped = $job.Stop()
    Check 'owned-processes-cleaned' ($stopped.ActiveProcesses -eq 0)
    $job.Dispose(); $script:job = $null
}
try {
    Check 'binary-sha256' ((Get-FileHash $Exe -Algorithm SHA256).Hash.ToLowerInvariant() -eq $ExpectedHash.ToLowerInvariant())
    Check 'embedded-version' ([Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;"))
    $tabs = @(@{kind='cmd'; name='Photo Alpha'; manual=$true; workspace=0}, @{kind='cmd'; name='Photo Beta'; manual=$true; workspace=0})
    Save @{active_tab=0; single_window=$true; active_workspace=0; workspace_count=1; workspaces=@(@{name='Home'; wid='home'}); tabs=$tabs} (Join-Path $settings 'session.json')
    $wide = Join-Path $profile 'wide.png'; $tall = Join-Path $profile 'tall.jpg'; $bad = Join-Path $profile 'bad.png'; $oversized = Join-Path $profile 'oversized.png'; $truncated = Join-Path $profile 'truncated.jpg'
    New-Fixture $wide 480 240 $false
    New-Fixture $tall 240 480 $true
    [IO.File]::WriteAllBytes($bad, [byte[]](137,80,78,71,13,10,26,10,0,0,0,0))
    $jpg = [IO.File]::ReadAllBytes($tall)
    [IO.File]::WriteAllBytes($truncated, $jpg[0..([int]($jpg.Length / 2))])
    $largeFile = [IO.File]::Create($oversized)
    try { $largeFile.SetLength(16MB + 1) } finally { $largeFile.Dispose() }
    Start-App
    Shot 'before'
    Look 'bot face' 'tall one eye' 7145
    Look 'bot color' 'sage' 7162
    $otherBefore = Capture-Avatar (Index-Name 'Photo Beta') 'other-before'
    Pick $wide
    $first = Wait-For 'first stored image' { $a = @(Assets); if ($a.Count -eq 1) { $a[0] } }
    $firstId = Wait-For 'first local identity' { $tab = @((State).tabs | Where-Object { $_.name -ceq 'Photo Alpha' -and $_.PSObject.Properties['avatar_local_id'] }); if ($tab.Count -eq 1 -and $tab[0].avatar_local_id -match '^[0-9a-f]{32}$') { $tab[0].avatar_local_id } }
    Assert-Normalized $first.FullName
    $firstHash = (Get-FileHash $first.FullName -Algorithm SHA256).Hash
    Check 'one-bot-isolated' (@(Assets).Count -eq 1)
    $sessionText = Get-Content (Join-Path $settings 'session.json') -Raw
    Check 'no-image-path-in-session' (-not $sessionText.Contains('wide.png') -and -not $sessionText.Contains('bot-avatars'))
    Check 'other-local-bot-unchanged' (@((State).tabs | Where-Object { $_.name -eq 'Photo Beta' -and $_.PSObject.Properties['avatar_local_id'] }).Count -eq 0)
    Shot 'uploaded-wide'
    Assert-Avatar 'expanded' (Index-For $firstId) 'expanded-wide'
    Check 'other-bot-pixels-unchanged' ((Capture-Avatar (Index-Name 'Photo Beta') 'other-after') -eq $otherBefore)
    Focus; Press @(0x11, 0x4b); Query 'bot face' 7187; Press @(0x0d)
    Query 'circle dots' 7141; Shot 'generated-face-previews'; Press @(0x1b)
    Focus; Press @(0x11, 0x4b); Query 'pin to top' 6293; Press @(0x0d)
    [void](Wait-For 'pinned local tab' { $tab = @((State).tabs | Where-Object { $_.name -eq 'Photo Alpha' })[0]; $tab.PSObject.Properties['pinned_top'] -and $tab.pinned_top -eq $true })
    Assert-Avatar 'pinned' (Index-For $firstId) 'pinned-wide'
    Focus; Press @(0x11, 0x4b); Query 'unpin from top' 6293; Press @(0x0d)
    [void](Wait-For 'unpinned local tab' { $tab = @((State).tabs | Where-Object { $_.name -eq 'Photo Alpha' })[0]; -not $tab.PSObject.Properties['pinned_top'] -or -not $tab.pinned_top })
    Focus; Press @(0x11, 0x10, 0x42)
    $firstIndex = Index-For $firstId
    [void](Wait-For 'collapsed sidebar' { (Log) -match ("\[photo-proof\] collapsed target=" + $firstIndex + " rect=") })
    Assert-Avatar 'collapsed' $firstIndex 'collapsed-wide'
    Focus; Press @(0x11, 0x10, 0x42)
    [void](Wait-For 'sidebar hidden' { $s = State; $s.PSObject.Properties['hide_sidebar'] -and $s.hide_sidebar })
    Focus; Press @(0x11, 0x10, 0x42)
    [void](Wait-For 'sidebar expanded' { $s = State; (-not $s.PSObject.Properties['hide_sidebar'] -or -not $s.hide_sidebar) -and (-not $s.PSObject.Properties['sidebar_collapsed'] -or -not $s.sidebar_collapsed) })
    Pick ''
    Check 'cancel-preserves-image' ((Get-FileHash $first.FullName -Algorithm SHA256).Hash -eq $firstHash)
    Pick $bad
    Check 'bad-image-preserves-image' ((Get-FileHash $first.FullName -Algorithm SHA256).Hash -eq $firstHash)
    Pick $truncated
    Check 'truncated-image-preserves-image' ((Get-FileHash $first.FullName -Algorithm SHA256).Hash -eq $firstHash)
    Pick $oversized
    Check 'oversized-image-preserves-image' ((Get-FileHash $first.FullName -Algorithm SHA256).Hash -eq $firstHash)
    $locked = [IO.File]::Open($first.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $start = (Log).Length
        Pick $tall
        $trace = (Log).Substring($start)
        Check 'failed-replace-reported' ($trace -match '\[bot-photo\] import=failed')
    } finally { $locked.Dispose() }
    Check 'failed-replace-preserves-image' ((Get-FileHash $first.FullName -Algorithm SHA256).Hash -eq $firstHash)
    Pick $tall
    [void](Wait-For 'replacement persisted' { (Get-FileHash $first.FullName -Algorithm SHA256).Hash -ne $firstHash })
    Assert-Normalized $first.FullName $true
    $replacementHash = (Get-FileHash $first.FullName -Algorithm SHA256).Hash
    Shot 'uploaded-tall'
    Assert-Avatar 'expanded' (Index-For $firstId) 'expanded-tall' $true
    $secondIndex = Index-Name 'Photo Beta'
    Focus; Press @(0x11, 0x4b); Query 'photo beta' $secondIndex; Press @(0x0d)
    Pick $wide
    $second = Wait-For 'second local image' { $a = @(Assets | Where-Object { $_.FullName -ne $first.FullName }); if ($a.Count -eq 1) { $a[0] } }
    $secondId = Wait-For 'second local identity' { $tab = @((State).tabs | Where-Object { $_.name -ceq 'Photo Beta' -and $_.PSObject.Properties['avatar_local_id'] }); if ($tab.Count -eq 1 -and $tab[0].avatar_local_id -match '^[0-9a-f]{32}$') { $tab[0].avatar_local_id } }
    Check 'local-identities-distinct' ($firstId -cne $secondId)
    $secondHash = (Get-FileHash $second.FullName -Algorithm SHA256).Hash
    Save @{binary=$ExpectedHash; first=$replacementHash; second=$secondHash; tag=$env:RELEASE_TAG} (Join-Path $Evidence 'hashes.json')
    Copy-Item $first.FullName (Join-Path $Evidence 'normalized-tall.png')
    Copy-Item $second.FullName (Join-Path $Evidence 'normalized-wide.png')
    Check 'second-bot-does-not-change-first' ((Get-FileHash $first.FullName -Algorithm SHA256).Hash -eq $replacementHash)
    Focus; Press @(0x11, 0x57)
    [void](Wait-For 'second local tab closed' { @((State).tabs | Where-Object { $_.name -eq 'Photo Beta' }).Count -eq 0 })
    $paintStart = (Log).Length
    Focus; Press @(0x11, 0x10, 0x54)
    [void](Wait-For 'second local tab reopened with same identity' { @((State).tabs | Where-Object { $_.name -ceq 'Photo Beta' -and $_.PSObject.Properties['avatar_local_id'] -and $_.avatar_local_id -ceq $secondId }).Count -eq 1 })
    $secondIndex = Index-For $secondId
    [void](Wait-For 'reopened photo painted' { $trace = Log; $trace.Length -ge $paintStart -and $trace.Substring($paintStart) -match ("\[photo-proof\] expanded target=" + $secondIndex + " rect=") })
    Assert-Avatar 'expanded' $secondIndex 'reopened-local-photo'
    Check 'reopened-photo-retained' ((Get-FileHash $second.FullName -Algorithm SHA256).Hash -eq $secondHash)
    $firstIndex = Index-For $firstId
    Focus; Press @(0x11, 0x4b); Query 'photo alpha' $firstIndex; Press @(0x0d)
    Remove-Item $wide, $tall
    Check 'source-files-unlocked' (-not (Test-Path $wide) -and -not (Test-Path $tall))
    Focus
    Press @(0x71); Press @(0x11, 0x41); [VerifyNative]::Text('Renamed Alpha'); Press @(0x0d)
    [void](Wait-For 'rename persisted' { @((State).tabs | Where-Object { $_.name -eq 'Renamed Alpha' }).Count -eq 1 })
    Check 'rename-keeps-photo' ((Get-FileHash $first.FullName -Algorithm SHA256).Hash -eq $replacementHash)
    Stop-App
    Start-App
    $restored = @((State).tabs | Where-Object { $_.name -ceq 'Renamed Alpha' -and $_.kind -eq 'cmd' -and $_.PSObject.Properties['avatar_local_id'] -and $_.avatar_local_id -ceq $firstId })
    $otherRestored = @((State).tabs | Where-Object { $_.name -ceq 'Photo Beta' -and $_.kind -eq 'cmd' -and $_.PSObject.Properties['avatar_local_id'] -and $_.avatar_local_id -ceq $secondId })
    Check 'restored-local-identities' ($restored.Count -eq 1 -and $otherRestored.Count -eq 1)
    $firstIndex = Index-For $firstId
    $secondIndex = Index-For $secondId
    Check 'photo-survives-restart' ((Get-FileHash $first.FullName -Algorithm SHA256).Hash -eq $replacementHash)
    Check 'other-photo-survives-restart' ((Get-FileHash $second.FullName -Algorithm SHA256).Hash -eq $secondHash)
    Assert-Avatar 'expanded' $firstIndex 'restored-local-photo' $true
    Assert-Avatar 'expanded' $secondIndex 'restored-other-local-photo'
    Shot 'after-restart'
    Focus; Press @(0x11, 0x4b); Query 'renamed alpha' $firstIndex; Press @(0x0d)
    Look 'bot face' 'square dots' 7147
    Check 'face-change-keeps-photo' ((Get-FileHash $first.FullName -Algorithm SHA256).Hash -eq $replacementHash)
    Look 'bot face' 'reset to show' 7194
    [void](Wait-For 'reset removes only selected asset' { -not (Test-Path $first.FullName) -and (Test-Path $second.FullName) })
    Check 'reset-keeps-other-photo' ((Get-FileHash $second.FullName -Algorithm SHA256).Hash -eq $secondHash)
    $saved = @((State).tabs | Where-Object { $_.name -eq 'Renamed Alpha' })[0]
    Check 'reset-retains-face-and-color' ($saved.face -eq 6 -and $saved.color -eq 0)
    Assert-Generated (Index-For $firstId) 'generated-after-reset'
    Shot 'reset'
    Stop-App
    Start-App
    Check 'reset-survives-restart' (-not (Test-Path $first.FullName) -and (Test-Path $second.FullName))
    $saved = @((State).tabs | Where-Object { $_.name -eq 'Renamed Alpha' })[0]
    Check 'local-appearance-survives-restart' ($saved.face -eq 6 -and $saved.color -eq 0)
    Shot 'reset-restart'
    $result.status = 'passed'
} catch {
    $result.error = $_.Exception.Message
    try { Shot 'failure' } catch {}
} finally {
    if ($null -ne $job) { $stopped = $job.Stop(); $result.cleanup = $stopped.ActiveProcesses; $job.Dispose() } else { $result.cleanup = 0 }
    if (Test-Path (Join-Path $settings 'session.json')) { Copy-Item (Join-Path $settings 'session.json') (Join-Path $Evidence 'session.json') }
    if (Test-Path (Join-Path $settings 'debug.log')) { Copy-Item (Join-Path $settings 'debug.log') (Join-Path $Evidence 'debug.log') }
    Save $result (Join-Path $Evidence 'result.json')
    if (Test-Path $profile) { Remove-Item -Recurse -Force $profile }
}
if ($result.status -ne 'passed' -or $result.cleanup -ne 0) { throw 'Bot photo verification failed; see result.json' }
