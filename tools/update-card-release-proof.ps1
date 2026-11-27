param([Parameter(Mandatory=$true)][string]$Exe, [Parameter(Mandatory=$true)][string]$Notes, [Parameter(Mandatory=$true)][string]$Evidence, [switch]$Wrapped, [ValidateSet('new', 'released')][string]$Contract = 'new')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:OS -ne 'Windows_NT') { throw 'Release card proof runs only on GitHub Windows' }
New-Item -ItemType Directory -Force $Evidence | Out-Null
$document = Get-Content $Notes -Raw | ConvertFrom-Json
$changes = @($document.releases | Where-Object { $_.version -eq $document.version } | ForEach-Object { $_.changes })
if ($Wrapped) {
    $candidates = @($document.releases | ForEach-Object { $_.changes })
    if ($Contract -eq 'new') { $candidates = @($candidates | Where-Object { $_ -match '^(?:IGSH|MUBO)-\d+ \S' }) }
    $changes = @($candidates | Sort-Object -Unique | Sort-Object { $_.Length } -Descending | Select-Object -First 40)
}
if ($changes.Count -eq 0) { throw 'Released card proof needs real product notes' }
$binaryVersion = [regex]::Match([Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)), 'MPVERSION=(\d+\.\d+\.\d+);')
if (-not $binaryVersion.Success) { throw 'Card binary carries no version marker' }
$binaryVersion = $binaryVersion.Groups[1].Value
$cardExe = Join-Path $Evidence 'card.exe'
Copy-Item -LiteralPath $Exe -Destination $cardExe
$hash = (Get-FileHash $cardExe -Algorithm SHA256).Hash.ToLowerInvariant()
New-Item -ItemType Directory -Force "$cardExe.update" | Out-Null
[IO.File]::WriteAllText("$cardExe.update/ready.txt", 'MPVERSION=999.0.0;')
[IO.File]::WriteAllText("$cardExe.update/release-notes.json", (@{ version = '999.0.0'; releases = @(@{ version = '999.0.0'; changes = $changes }) } | ConvertTo-Json -Depth 6))
$env:APPDATA = Join-Path $Evidence 'roaming'
$env:LOCALAPPDATA = Join-Path $Evidence 'local'
$env:USERPROFILE = Join-Path $Evidence 'profile'
$env:HOME = $env:USERPROFILE
$env:MULTIPROMPT_NO_LOGIN = '1'
$env:ZIGSHELL_DEBUG = '1'
$env:IGSH_246 = '1'
New-Item -ItemType Directory -Force "$env:APPDATA/ZigShell", $env:LOCALAPPDATA, $env:USERPROFILE | Out-Null
$eventName = 'Local\MultipromptReleaseCard-' + [guid]::NewGuid().ToString('N')
$event = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::ManualReset, $eventName)
$mutexName = 'Local\MultipromptUpdate-' + ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::Unicode.GetBytes($cardExe.ToLowerInvariant())))).Replace('-', '')
$mutex = New-Object Threading.Mutex($false, $mutexName)
$null = $mutex.WaitOne()
$process = $null
$log = Join-Path $env:APPDATA 'ZigShell/debug.log'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class ReleaseCardProof { [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int command); [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h); [StructLayout(LayoutKind.Sequential)] public struct Point { public int X,Y; } [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int height, uint flags); [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref Point p); [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr wp, IntPtr lp); [StructLayout(LayoutKind.Sequential)] public struct Rect { public int L,T,R,B; } [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r); [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags); [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out Rect r); [DllImport("user32.dll")] public static extern bool RedrawWindow(IntPtr h, IntPtr update, IntPtr region, uint flags); [DllImport("user32.dll")] public static extern int GetDpiForWindow(IntPtr h); [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr context); [DllImport("dwmapi.dll")] public static extern int DwmFlush(); [DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(int awareness); }'
try { if (-not [ReleaseCardProof]::SetProcessDpiAwarenessContext([IntPtr](-4))) { $null = [ReleaseCardProof]::SetProcessDpiAwareness(2) } } catch { try { $null = [ReleaseCardProof]::SetProcessDpiAwareness(2) } catch { $null = $_ } }
$script:cardLog = ''
$script:cardLogMark = 0
$script:cardResized = $false
$script:cardMaximized = $false
$script:cardImages = @()
function Card-Log {
    if (-not (Test-Path -LiteralPath $log)) { return '' }
    $stream = [IO.File]::Open($log, 'Open', 'Read', ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    $reader = [IO.StreamReader]::new($stream)
    try { $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function Card-Mark {
    $script:cardLog = Card-Log
    $script:cardLogMark = $script:cardLog.Length
}
function Card-Tail {
    if ($script:cardLogMark -ge $script:cardLog.Length) { return '' }
    return $script:cardLog.Substring($script:cardLogMark)
}
function Card-Fresh {
    if ($script:cardResized) { return Card-Tail }
    return $script:cardLog
}
function Wait-Card([scriptblock]$Condition, [string]$Failure) {
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        $script:cardLog = Card-Log
        if (& $Condition) { return }
        if ($process.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw $Failure }
        Start-Sleep -Milliseconds 100
    } while ($true)
}
function Card-Bounds {
    $matches = [regex]::Matches($script:cardLog, '\[update\] notes viewport=(\d+),(\d+),(\d+),(\d+) content=(\d+) scroll=(\d+)')
    if ($matches.Count -eq 0) { throw 'Card did not expose wrapped note bounds' }
    $m = $matches[$matches.Count - 1]
    return @{ left = [int]$m.Groups[1].Value; top = [int]$m.Groups[2].Value; right = [int]$m.Groups[3].Value; bottom = [int]$m.Groups[4].Value; content = [int]$m.Groups[5].Value; scroll = [int]$m.Groups[6].Value }
}
function Card-Click([string]$Label) {
    $matches = [regex]::Matches($script:cardLog, '\[update\] ' + $Label + '=(\d+),(\d+)')
    if ($matches.Count -eq 0) { throw 'Card control unavailable' }
    $m = $matches[$matches.Count - 1]
    return @{ x = [int]$m.Groups[1].Value; y = [int]$m.Groups[2].Value }
}
function Card-Geometry {
    $process.Refresh()
    $window = New-Object ReleaseCardProof+Rect
    if (-not [ReleaseCardProof]::GetWindowRect($process.MainWindowHandle, [ref]$window)) { throw 'Card window rect unavailable' }
    $client = New-Object ReleaseCardProof+Rect
    $origin = New-Object ReleaseCardProof+Point
    if (-not [ReleaseCardProof]::GetClientRect($process.MainWindowHandle, [ref]$client) -or -not [ReleaseCardProof]::ClientToScreen($process.MainWindowHandle, [ref]$origin)) { throw 'Card client geometry unavailable' }
    $scale = 0
    try { $scale = [ReleaseCardProof]::GetDpiForWindow($process.MainWindowHandle) } catch { $scale = 0 }
    return @{ window = @{ left = $window.L; top = $window.T; width = $window.R - $window.L; height = $window.B - $window.T }; client = @{ left = $origin.X - $window.L; top = $origin.Y - $window.T; width = $client.R; height = $client.B }; scale = $scale }
}
function Card-Present {
    $null = [ReleaseCardProof]::RedrawWindow($process.MainWindowHandle, [IntPtr]::Zero, [IntPtr]::Zero, 0x0181)
    try { $null = [ReleaseCardProof]::DwmFlush() } catch { $null = $_ }
}
function Set-Card-Window([int]$Width, [int]$Height) {
    $process.Refresh()
    $before = New-Object ReleaseCardProof+Rect
    if (-not [ReleaseCardProof]::GetWindowRect($process.MainWindowHandle, [ref]$before)) { throw 'Card resize has no window' }
    $script:cardResized = ($before.R - $before.L -ne $Width -or $before.B - $before.T -ne $Height)
    if ($script:cardResized) { Card-Mark }
    if (-not [ReleaseCardProof]::SetWindowPos($process.MainWindowHandle, [IntPtr]::Zero, 0, 0, $Width, $Height, 0x0040)) { throw 'Card resize failed' }
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        $after = New-Object ReleaseCardProof+Rect
        if ([ReleaseCardProof]::GetWindowRect($process.MainWindowHandle, [ref]$after) -and $after.R - $after.L -eq $Width -and $after.B - $after.T -eq $Height) { break }
        if ($process.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw 'Native card dimensions do not match requested proof size' }
        Start-Sleep -Milliseconds 50
    } while ($true)
}
function Card-Bitmap-Point([int]$x, [int]$y) {
    $origin = New-Object ReleaseCardProof+Point
    $window = New-Object ReleaseCardProof+Rect
    if (-not [ReleaseCardProof]::ClientToScreen($process.MainWindowHandle, [ref]$origin) -or -not [ReleaseCardProof]::GetWindowRect($process.MainWindowHandle, [ref]$window)) { throw 'Card client geometry unavailable' }
    return @{ x = $origin.X - $window.L + $x; y = $origin.Y - $window.T + $y }
}
function Card-Ink($Picture, [int]$Left, [int]$Top, [int]$Right, [int]$Bottom) {
    $ink = 0
    for ($y = $Top; $y -le $Bottom; $y++) {
        if ($y -lt 0 -or $y -ge $Picture.Height) { continue }
        for ($x = $Left; $x -le $Right; $x++) {
            if ($x -lt 0 -or $x -ge $Picture.Width) { continue }
            $colour = $Picture.GetPixel($x, $y)
            if ($colour.R -gt 90 -and $colour.G -gt 90 -and $colour.B -gt 90) { $ink += 1 }
        }
    }
    return $ink
}
function Test-Card-Legacy-Blue($Colour) {
    return ($Colour.B -ge 150 -and ($Colour.B - $Colour.R) -ge 60 -and ($Colour.B - $Colour.G) -ge 40)
}
function Card-Legacy-Restart($Picture) {
    $bottom = $Picture.Height - 1
    $top = [Math]::Max(0, $Picture.Height - 320)
    $right = [Math]::Min($Picture.Width - 1, 260)
    $rows = [int[]]::new($bottom + 1)
    for ($y = $top; $y -le $bottom; $y++) {
        $count = 0
        for ($x = 0; $x -le $right; $x++) {
            if (Test-Card-Legacy-Blue $Picture.GetPixel($x, $y)) { $count += 1 }
        }
        $rows[$y] = $count
    }
    $buttonTop = -1
    $buttonBottom = -1
    $tallest = 0
    $scan = -1
    for ($y = $top; $y -le $bottom + 1; $y++) {
        if ($y -le $bottom -and $rows[$y] -ge 60) { if ($scan -lt 0) { $scan = $y }; continue }
        if ($scan -ge 0 -and $y - $scan -gt $tallest) { $tallest = $y - $scan; $buttonTop = $scan; $buttonBottom = $y - 1 }
        $scan = -1
    }
    if ($buttonTop -lt 0) { return $null }
    $height = $buttonBottom - $buttonTop + 1
    $band = [Math]::Max(3, [int]($height / 2))
    $columns = [int[]]::new($right + 1)
    for ($x = 0; $x -le $right; $x++) {
        $count = 0
        for ($y = $buttonTop; $y -le $buttonBottom; $y++) {
            if (Test-Card-Legacy-Blue $Picture.GetPixel($x, $y)) { $count += 1 }
        }
        $columns[$x] = $count
    }
    $left = -1
    $width = 0
    $scan = -1
    for ($x = 0; $x -le $right + 1; $x++) {
        if ($x -le $right -and $columns[$x] -ge $band) { if ($scan -lt 0) { $scan = $x }; continue }
        if ($scan -ge 0 -and $x - $scan -gt $width) { $width = $x - $scan; $left = $scan }
        $scan = -1
    }
    if ($left -lt 0) { return $null }
    $buttonRight = $left + $width - 1
    $label = 0
    for ($y = $buttonTop; $y -le $buttonBottom; $y++) {
        for ($x = $left; $x -le $buttonRight; $x++) {
            $colour = $Picture.GetPixel($x, $y)
            if ($colour.R -ge 200 -and $colour.G -ge 200 -and $colour.B -ge 200) { $label += 1 }
        }
    }
    return @{ left = $left; top = $buttonTop; right = $buttonRight; bottom = $buttonBottom; width = $width; height = $height; labelInk = $label }
}
function Assert-Card-Image([string]$Name, [string]$File, $Geometry) {
    $picture = New-Object Drawing.Bitmap($File)
    try {
        if ($picture.Width -ne $Geometry.window.width -or $picture.Height -ne $Geometry.window.height) { throw ('Card ' + $Name + ' screenshot is ' + $picture.Width + 'x' + $picture.Height + ' instead of the window it captured') }
        $visible = @{ restartVisible = $false; seeAllVisible = $false; notesVisible = $false }
        $restart = Card-Click 'restart button'
        if ($Contract -ne 'new') {
            $legacy = Card-Legacy-Restart $picture
            if ($null -ne $legacy) {
                if ($legacy.width -lt 70 -or $legacy.width -gt 100 -or $legacy.height -lt 15 -or $legacy.height -gt 24) { throw ('Card ' + $Name + ' screenshot shows no Restart button') }
                if ($legacy.labelInk -lt 40) { throw ('Card ' + $Name + ' screenshot shows no Restart label') }
                if ($legacy.left -lt 8 -or $legacy.right -gt 260 -or $legacy.bottom -gt $picture.Height - 8) { throw ('Card ' + $Name + ' screenshot put the Restart button outside the card') }
                $visible.restartVisible = $true
                $visible.legacyButton = $legacy
                return $visible
            }
            $point = Card-Bitmap-Point $restart.x $restart.y
            if ($point.x -lt 8 -or $point.y -lt 8 -or $point.x -ge $picture.Width - 8 -or $point.y -ge $picture.Height - 8) { throw ('Card ' + $Name + ' screenshot cut the Restart button at ' + $point.x + ',' + $point.y) }
            if ((Card-Ink $picture ($point.x - 12) ($point.y - 4) ($point.x + 12) ($point.y + 4)) -lt 30) { throw ('Card ' + $Name + ' screenshot shows no Restart button at the place the app paints it') }
            $visible.restartVisible = $true
            $visible.legacyButton = $null
            return $visible
        }
        $point = Card-Bitmap-Point $restart.x $restart.y
        if ($point.x -lt 8 -or $point.y -lt 8 -or $point.x -ge $picture.Width - 8 -or $point.y -ge $picture.Height - 8) { throw ('Card ' + $Name + ' screenshot cut the Restart button at ' + $point.x + ',' + $point.y) }
        if ((Card-Ink $picture ($point.x - 12) ($point.y - 4) ($point.x + 12) ($point.y + 4)) -lt 30) { throw ('Card ' + $Name + ' screenshot shows no Restart button at the place the app paints it') }
        $visible.restartVisible = $true
        $bounds = Card-Bounds
        $more = Card-Click 'more row'
        if ($bounds.top -lt 0 -or $bounds.right -gt $Geometry.client.width -or $bounds.bottom -gt $Geometry.client.height -or $more.y -ge $Geometry.client.height) { throw ('Card ' + $Name + ' screenshot put the card outside the window') }
        $row = Card-Bitmap-Point $bounds.left ($bounds.bottom + 2)
        $rowBottom = (Card-Bitmap-Point $bounds.left ($more.y + 8)).y
        if ($rowBottom -ge $picture.Height) { throw ('Card ' + $Name + ' screenshot cut the See all row') }
        if ((Card-Ink $picture $row.x $row.y ($row.x + ($bounds.right - $bounds.left)) $rowBottom) -lt 8) { throw ('Card ' + $Name + ' screenshot shows no See all row below the notes') }
        $visible.seeAllVisible = $true
        $line = Card-Bitmap-Point $bounds.left ($bounds.top + 4)
        $lineBottom = [Math]::Min($line.y + 24, $picture.Height - 1)
        if ((Card-Ink $picture $line.x $line.y ($line.x + ($bounds.right - $bounds.left)) $lineBottom) -lt 8) { throw ('Card ' + $Name + ' screenshot shows no note lines') }
        $visible.notesVisible = $true
        return $visible
    } finally { $picture.Dispose() }
}
function Capture-Card-Image([string]$Name) {
    Card-Present
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        $script:cardLog = Card-Log
        $geometry = Card-Geometry
        $placed = [regex]::Matches($script:cardLog, '\[reposition\] client=(\d+)x(\d+)')
        if ($placed.Count -eq 0) { break }
        $last = $placed[$placed.Count - 1]
        if ([int]$last.Groups[1].Value -eq $geometry.client.width -and [int]$last.Groups[2].Value -eq $geometry.client.height) { break }
        if ($process.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw ('Card client size differs from the size the app laid out (' + $Name + ')') }
        Start-Sleep -Milliseconds 50
    } while ($true)
    $geometry = Card-Geometry
    $file = Join-Path $Evidence ($Name + '.png')
    $bitmap = New-Object Drawing.Bitmap($geometry.window.width, $geometry.window.height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $dc = $graphics.GetHdc()
    try { if (-not [ReleaseCardProof]::PrintWindow($process.MainWindowHandle, $dc, 2)) { throw 'Card screenshot failed' } } finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
    try { $bitmap.Save($file) } finally { $bitmap.Dispose() }
    Card-Mark
    $visible = Assert-Card-Image $Name $file $geometry
    $state = $null
    $viewport = [regex]::Matches($script:cardLog, '\[update\] notes viewport=(\d+),(\d+),(\d+),(\d+) content=(\d+) scroll=(\d+)')
    if ($viewport.Count -gt 0) {
        $last = $viewport[$viewport.Count - 1]
        $state = @{ top = [int]$last.Groups[2].Value; bottom = [int]$last.Groups[4].Value; content = [int]$last.Groups[5].Value; scroll = [int]$last.Groups[6].Value }
    }
    $record = @{ name = $Name; file = ($Name + '.png'); window = $geometry.window; client = $geometry.client; scale = $geometry.scale; maximized = [ReleaseCardProof]::IsZoomed($process.MainWindowHandle); logOffset = $script:cardLog.Length; notes = $state; restartVisible = $visible['restartVisible']; seeAllVisible = $visible['seeAllVisible']; notesVisible = $visible['notesVisible']; legacyButton = $visible['legacyButton'] }
    $script:cardImages = @($script:cardImages) + @($record)
    return $record
}
function Normalize-Card {
    if ([ReleaseCardProof]::IsZoomed($process.MainWindowHandle)) {
        $null = [ReleaseCardProof]::ShowWindow($process.MainWindowHandle, 9)
        $deadline = [DateTime]::UtcNow.AddSeconds(10)
        do {
            if (-not [ReleaseCardProof]::IsZoomed($process.MainWindowHandle)) { break }
            if ($process.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw 'Card window did not restore before its first screenshot' }
            Start-Sleep -Milliseconds 50
        } while ($true)
    }
    Set-Card-Window 1024 768
    Card-Present
    Card-Mark
    if ($Contract -eq 'new') {
        $normalBounds = Card-Bounds
        $normalRestart = Card-Click 'restart button'
        $normalClient = Card-Geometry
        if ($normalBounds.top -lt 0 -or $normalBounds.right -gt $normalClient.client.width -or $normalBounds.bottom -gt $normalClient.client.height -or $normalRestart.y -ge $normalClient.client.height) { throw 'Card controls fall outside the window at the normal proof size' }
    }
}
try {
    $process = Start-Process $cardExe -ArgumentList "--update-ready $eventName" -PassThru
    if (-not $event.WaitOne(15000)) { throw 'Released app did not report readiness' }
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        $text = if (Test-Path $log) { Get-Content $log -Raw } else { '' }
        if ($text -match '\[update\] card view=collapsed' -and $text -match '\[update\] card remaining=') { break }
        if ($process.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw 'Released app did not paint the card' }
        Start-Sleep -Milliseconds 100
    } while ($true)
    $script:cardMaximized = [ReleaseCardProof]::IsZoomed($process.MainWindowHandle)
    Normalize-Card
    $image = Join-Path $Evidence 'released-card.png'
    $firstCapture = Capture-Card-Image 'released-card'
    $text = Card-Log
    $published = @($changes)
    $plainLines = @($published | ForEach-Object { ($_ -replace '^(?:IGSH|MUBO)-\d+ ', '') })
    $publishedIds = @($published | ForEach-Object { [regex]::Match($_, '^((?:IGSH|MUBO)-\d+)').Groups[1].Value })
    $blocks = [regex]::Matches($text, '\[update\] card view=collapsed n=\d+')
    $current = if ($blocks.Count -gt 0) { $text.Substring($blocks[$blocks.Count - 1].Index) } else { $text }
    $named = @([regex]::Matches($current, '\[update\] card note \d+=([^\r\n]*)') | ForEach-Object { $_.Groups[1].Value })
    $views = [regex]::Matches($current, '\[update\] card view=collapsed n=(\d+)')
    if ($views.Count -eq 0) { throw 'Released app painted no card view line' }
    if ([int]$views[$views.Count - 1].Groups[1].Value -ne $named.Count) { throw 'Released card view count differs from its note lines' }
    if ($text -match '\[update\] card note \d+=.*(behind the scenes|latest improvements)') { throw 'Released card showed filler' }
    if ($Contract -eq 'released') {
        if ($named.Count -gt [Math]::Min(3, $published.Count)) { throw 'Released old card painted more lines than its own filter keeps' }
        foreach ($line in $named) { if ($published -notcontains $line) { throw 'Released old card painted a line it never published verbatim' } }
        if ($text -match '\[update\] card note id ') { throw 'Released old card already logs a ticket id' }
        if ($text -match '\[update\] card see all=') { throw 'Released old card already links the release notes' }
        if ($Wrapped -and $named.Count -eq 0) { throw 'Released old painter named no published note to wrap' }
        $paintedIds = @()
        $seeAll = $false
    } else {
        if ($named.Count -eq 0) { throw 'New card painted no published change lines' }
        if ($named.Count -ne [Math]::Min(3, $published.Count)) { throw 'New card painted a different number of change lines than published' }
        $matchedIds = @()
        $cursor = 0
        for ($i = 0; $i -lt $named.Count; $i++) {
            $at = $i
            if ($Wrapped) {
                $at = -1
                for ($j = $cursor; $j -lt $plainLines.Count; $j++) { if ($plainLines[$j] -ceq $named[$i]) { $at = $j; break } }
            }
            if ($at -lt 0 -or $at -ge $plainLines.Count -or $plainLines[$at] -cne $named[$i]) { throw 'New card differs from the published change text' }
            $cursor = $at + 1
            $id = [regex]::Match($current, '\[update\] card note id ' + $i + '=([^\r\n]*)')
            if (-not $id.Success -or $id.Groups[1].Value -cne $publishedIds[$at]) { throw 'New card lost the published ticket id' }
            $matchedIds += $publishedIds[$at]
        }
        if ($text -match '\[update\] card note \d+=.*(?:IGSH|MUBO)-\d+') { throw 'New card painted a ticket number into the change text' }
        if ($text -notmatch '\[update\] card see all=https://github\.com/valentinyeo/multiprompt/releases/tag/v') { throw 'New card has no See all destination' }
        $paintedIds = @($matchedIds)
        $seeAll = $true
    }
    if ((Get-FileHash $cardExe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) { throw 'Released binary changed during proof' }
    $receipt = @{ contract = $Contract; binaryVersion = $binaryVersion; version = $document.version; sha256 = $hash; changes = $published; painted = $named; ids = $paintedIds; seeAll = $seeAll; simulatedOffer = '999.0.0'; maximized = $script:cardMaximized; image = $firstCapture; success = $true }
    $receipt | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $Evidence 'released-card.json')
    if ($Wrapped) {
        function Capture-Card([string]$Name) {
            $null = Capture-Card-Image $Name
            $file = Join-Path $Evidence ($Name + '.png')
            Write-Output ('WRAPPED_CARD_IMAGE=' + $Name + ':' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($file)))
        }
        function Resize-Card([int]$Width, [int]$Height) {
            Set-Card-Window $Width $Height
            Wait-Card { (Card-Fresh) -match '\[update\] notes viewport=' -and (Card-Fresh) -match '\[update\] card remaining=' } 'Card did not expose wrapped note bounds'
            if ([ReleaseCardProof]::IsZoomed($process.MainWindowHandle)) { throw 'Native card dimensions do not match requested proof size' }
            Write-Output ('WRAPPED_CARD_WINDOW=' + $Width + 'x' + $Height)
        }
        Write-Output ('WRAPPED_CARD_WAS_MAXIMIZED=' + $script:cardMaximized)
        Resize-Card 1024 768
        $normal = Card-Bounds
        $noteHeights = @(foreach ($index in 0..2) {
            $match = [regex]::Matches($script:cardLog, '\[update\] note height ' + $index + '=(\d+)')
            if ($match.Count -eq 0) { throw 'Long real notes did not wrap onto multiple lines' }
            [int]$match[$match.Count - 1].Groups[1].Value
        })
        if (@($noteHeights | Where-Object { $_ -le 24 }).Count -ne 0) { throw 'Long real notes did not wrap onto multiple lines' }
        Capture-Card 'wrapped-normal'
        Resize-Card 640 480
        Capture-Card 'wrapped-minimum'
        $minimum = Card-Bounds
        $restartMinimum = Card-Click 'restart button'
        if ($minimum.top -lt 0 -or $restartMinimum.y -le $minimum.bottom) { throw 'Restart is not visible below the notes at the minimum size' }
        $overflowHeight = 0
        foreach ($candidate in @(400, 360, 320, 280, 240)) {
            Resize-Card 640 $candidate
            $fitted = Card-Bounds
            if ($fitted.content -gt $fitted.bottom - $fitted.top) { $overflowHeight = $candidate; break }
        }
        if ($overflowHeight -eq 0) { throw 'Long real notes did not require scrolling' }
        $collapsed = Card-Bounds
        $restartBefore = Card-Click 'restart button'
        $local = New-Object ReleaseCardProof+Point
        $local.X = [int](($collapsed.left + $collapsed.right) / 2)
        $local.Y = [int](($collapsed.top + $collapsed.bottom) / 2)
        if (-not [ReleaseCardProof]::ClientToScreen($process.MainWindowHandle, [ref]$local)) { throw 'Card wheel coordinate failed' }
        $wheelPoint = [IntPtr](($local.Y -shl 16) -bor ($local.X -band 0xffff))
        Card-Mark
        $null = [ReleaseCardProof]::PostMessage($process.MainWindowHandle, 0x20A, [IntPtr](-120 -shl 16), $wheelPoint)
        Wait-Card { (Card-Tail) -match '\[update\] card remaining=' -and (Card-Bounds).scroll -gt 0 } 'Notes did not scroll inside their card'
        $scrolled = Card-Bounds
        $restartAfter = Card-Click 'restart button'
        if ($restartBefore.x -ne $restartAfter.x -or $restartBefore.y -ne $restartAfter.y -or $restartAfter.y -le $scrolled.bottom -or $scrolled.top -lt 0) { throw 'Scrolling moved or hid Restart' }
        Capture-Card 'wrapped-scrolled'
        for ($i = 0; $i -lt 20 -and (Card-Bounds).scroll -gt 0; $i++) {
            $null = [ReleaseCardProof]::PostMessage($process.MainWindowHandle, 0x20A, [IntPtr](120 -shl 16), $wheelPoint)
            Start-Sleep -Milliseconds 150
        }
        Wait-Card { (Card-Bounds).scroll -eq 0 -and $script:cardLog -match '\[update\] card remaining=' } 'Notes did not return to their first line'
        Capture-Card 'wrapped-collapsed'
        $wrappedReceipt = @{ contract = $Contract; binaryVersion = $binaryVersion; version = $document.version; sha256 = $hash; wrapped = $true; scrollVerified = $true; noteHeights = $noteHeights; overflowWindow = ('640x' + $overflowHeight); normal = $normal; minimum = $minimum; collapsed = $collapsed; scrolled = $scrolled; restartBefore = $restartBefore; restartAfter = $restartAfter; changes = $published; painted = $named; ids = $paintedIds; seeAll = $seeAll; simulatedOffer = '999.0.0'; maximized = $script:cardMaximized; images = $script:cardImages; firstImage = $firstCapture; success = $true }
        $wrappedReceipt | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $Evidence 'wrapped-card.json')
        Write-Output ('WRAPPED_CARD_RECEIPT=' + [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $Evidence 'wrapped-card.json'))))
    }
    Write-Output ('RELEASE_CARD_RECEIPT=' + [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $Evidence 'released-card.json'))))
    Write-Output ('RELEASE_CARD_PNG=' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($image)))
} finally {
    if ($process -and -not (Test-Path (Join-Path $Evidence 'released-card.png'))) {
        try {
            $process.Refresh()
            $shotRect = New-Object ReleaseCardProof+Rect
            if ([ReleaseCardProof]::GetWindowRect($process.MainWindowHandle, [ref]$shotRect) -and $shotRect.R -gt $shotRect.L -and $shotRect.B -gt $shotRect.T) {
                $shot = New-Object Drawing.Bitmap(($shotRect.R - $shotRect.L), ($shotRect.B - $shotRect.T))
                $shotGraphics = [Drawing.Graphics]::FromImage($shot)
                $shotDc = $shotGraphics.GetHdc()
                try { $null = [ReleaseCardProof]::PrintWindow($process.MainWindowHandle, $shotDc, 2) } finally { $shotGraphics.ReleaseHdc($shotDc); $shotGraphics.Dispose() }
                try { $shot.Save((Join-Path $Evidence 'released-card.png')) } finally { $shot.Dispose() }
            }
        } catch { $null = $_ }
    }
    if ($process) {
        Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $process.Id -and $_.Name -ieq 'powershell.exe' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
    }
    if ($Wrapped -and (Test-Path -LiteralPath $log)) { Copy-Item -LiteralPath $log -Destination (Join-Path $Evidence 'debug.log') -Force -ErrorAction SilentlyContinue }
    if ($Wrapped -and (Test-Path -LiteralPath $log)) { Get-Content -LiteralPath $log | Select-Object -Last 80 | ForEach-Object { Write-Output ('WRAPPED_CARD_LOG=' + $_) } }
    $mutex.ReleaseMutex()
    $mutex.Dispose()
    $event.Dispose()
}
