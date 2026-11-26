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
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class ReleaseCardProof { [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int command); [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h); [StructLayout(LayoutKind.Sequential)] public struct Point { public int X,Y; } [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int height, uint flags); [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref Point p); [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr wp, IntPtr lp); [StructLayout(LayoutKind.Sequential)] public struct Rect { public int L,T,R,B; } [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r); [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags); }'
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
    $process.Refresh()
    $rectangle = New-Object ReleaseCardProof+Rect
    if (-not [ReleaseCardProof]::GetWindowRect($process.MainWindowHandle, [ref]$rectangle)) { throw 'Released window unavailable' }
    $bitmap = New-Object Drawing.Bitmap(($rectangle.R - $rectangle.L), ($rectangle.B - $rectangle.T))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $dc = $graphics.GetHdc()
    try { if (-not [ReleaseCardProof]::PrintWindow($process.MainWindowHandle, $dc, 2)) { throw 'Released screenshot failed' } } finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
    $image = Join-Path $Evidence 'released-card.png'
    try { $bitmap.Save($image) } finally { $bitmap.Dispose() }
    $published = @($changes)
    $plainLines = @($published | ForEach-Object { ($_ -replace '^(?:IGSH|MUBO)-\d+ ', '') })
    $publishedIds = @($published | ForEach-Object { [regex]::Match($_, '^((?:IGSH|MUBO)-\d+)').Groups[1].Value })
    $named = @([regex]::Matches($text, '\[update\] card note \d+=([^\r\n]*)') | ForEach-Object { $_.Groups[1].Value })
    $views = [regex]::Matches($text, '\[update\] card view=collapsed n=(\d+)')
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
            $id = [regex]::Match($text, '\[update\] card note id ' + $i + '=([^\r\n]*)')
            if (-not $id.Success -or $id.Groups[1].Value -cne $publishedIds[$at]) { throw 'New card lost the published ticket id' }
            $matchedIds += $publishedIds[$at]
        }
        if ($text -match '\[update\] card note \d+=.*(?:IGSH|MUBO)-\d+') { throw 'New card painted a ticket number into the change text' }
        if ($text -notmatch '\[update\] card see all=https://github\.com/valentinyeo/multiprompt/releases/tag/v') { throw 'New card has no See all destination' }
        $paintedIds = @($matchedIds)
        $seeAll = $true
    }
    if ((Get-FileHash $cardExe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) { throw 'Released binary changed during proof' }
    $receipt = @{ contract = $Contract; binaryVersion = $binaryVersion; version = $document.version; sha256 = $hash; changes = $published; painted = $named; ids = $paintedIds; seeAll = $seeAll; simulatedOffer = '999.0.0'; success = $true }
    $receipt | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $Evidence 'released-card.json')
    if ($Wrapped) {
        function Wait-Card([scriptblock]$Condition, [string]$Failure) {
            $deadline = [DateTime]::UtcNow.AddSeconds(10)
            do {
                $script:cardLog = if (Test-Path $log) { Get-Content $log -Raw } else { '' }
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
        function Capture-Card([string]$Name) {
            $process.Refresh()
            $r = New-Object ReleaseCardProof+Rect
            if (-not [ReleaseCardProof]::GetWindowRect($process.MainWindowHandle, [ref]$r)) { throw 'Card screenshot has no window' }
            $b = New-Object Drawing.Bitmap(($r.R - $r.L), ($r.B - $r.T))
            $g = [Drawing.Graphics]::FromImage($b)
            $dc = $g.GetHdc()
            try { if (-not [ReleaseCardProof]::PrintWindow($process.MainWindowHandle, $dc, 2)) { throw 'Card screenshot failed' } } finally { $g.ReleaseHdc($dc); $g.Dispose() }
            $file = Join-Path $Evidence ($Name + '.png')
            try { $b.Save($file) } finally { $b.Dispose() }
            Write-Output ('WRAPPED_CARD_IMAGE=' + $Name + ':' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($file)))
        }
        function Resize-Card([int]$Width, [int]$Height) {
            $before = New-Object ReleaseCardProof+Rect
            if (-not [ReleaseCardProof]::GetWindowRect($process.MainWindowHandle, [ref]$before)) { throw 'Card resize has no window' }
            if ($before.R - $before.L -ne $Width -or $before.B - $before.T -ne $Height) {
                $script:cardLog = ''
                Remove-Item $log -Force
            }
            if (-not [ReleaseCardProof]::SetWindowPos($process.MainWindowHandle, [IntPtr]::Zero, 0, 0, $Width, $Height, 0x0040)) { throw 'Card resize failed' }
            Wait-Card { $script:cardLog -match '\[update\] notes viewport=' -and $script:cardLog -match '\[update\] card remaining=' } 'Card did not expose wrapped note bounds'
            $after = New-Object ReleaseCardProof+Rect
            if (-not [ReleaseCardProof]::GetWindowRect($process.MainWindowHandle, [ref]$after)) { throw 'Card resized window unavailable' }
            Write-Output ('WRAPPED_CARD_WINDOW=' + ($after.R - $after.L) + 'x' + ($after.B - $after.T))
            if ($after.R - $after.L -ne $Width -or $after.B - $after.T -ne $Height -or [ReleaseCardProof]::IsZoomed($process.MainWindowHandle)) { throw 'Native card dimensions do not match requested proof size' }
        }
        Write-Output ('WRAPPED_CARD_WAS_MAXIMIZED=' + [ReleaseCardProof]::IsZoomed($process.MainWindowHandle))
        $null = [ReleaseCardProof]::ShowWindow($process.MainWindowHandle, 9)
        Wait-Card { -not [ReleaseCardProof]::IsZoomed($process.MainWindowHandle) } 'Card window did not restore before resizing'
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
        $script:cardLog = ''
        Remove-Item $log -Force
        $null = [ReleaseCardProof]::PostMessage($process.MainWindowHandle, 0x20A, [IntPtr](-120 -shl 16), $wheelPoint)
        Wait-Card { $script:cardLog -match '\[update\] card remaining=' -and (Card-Bounds).scroll -gt 0 } 'Notes did not scroll inside their card'
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
        $wrappedReceipt = @{ contract = $Contract; binaryVersion = $binaryVersion; version = $document.version; sha256 = $hash; wrapped = $true; scrollVerified = $true; noteHeights = $noteHeights; overflowWindow = ('640x' + $overflowHeight); normal = $normal; minimum = $minimum; collapsed = $collapsed; scrolled = $scrolled; restartBefore = $restartBefore; restartAfter = $restartAfter; changes = $published; painted = $named; ids = $paintedIds; seeAll = $seeAll; simulatedOffer = '999.0.0'; success = $true }
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
    if ($Wrapped -and (Test-Path $log)) { Copy-Item -LiteralPath $log -Destination (Join-Path $Evidence 'debug.log') -Force -ErrorAction SilentlyContinue }
    if ($Wrapped -and (Test-Path $log)) { Get-Content $log | Select-Object -Last 80 | ForEach-Object { Write-Output ('WRAPPED_CARD_LOG=' + $_) } }
    $mutex.ReleaseMutex()
    $mutex.Dispose()
    $event.Dispose()
}
