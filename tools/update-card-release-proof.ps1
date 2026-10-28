param([Parameter(Mandatory=$true)][string]$Exe, [Parameter(Mandatory=$true)][string]$Notes, [Parameter(Mandatory=$true)][string]$Evidence, [switch]$Wrapped)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:OS -ne 'Windows_NT') { throw 'Release card proof runs only on GitHub Windows' }
New-Item -ItemType Directory -Force $Evidence | Out-Null
$document = Get-Content $Notes -Raw | ConvertFrom-Json
$changes = @($document.releases | Where-Object { $_.version -eq $document.version } | ForEach-Object { $_.changes })
if ($Wrapped) { $changes = @($document.releases | Select-Object -First 20 | ForEach-Object { $_.changes } | Sort-Object { $_.Length } -Descending | Select-Object -First 16) }
if ($changes.Count -eq 0) { throw 'Released card proof needs real product notes' }
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
try {
    $process = Start-Process $cardExe -ArgumentList "--update-ready $eventName" -PassThru
    if (-not $event.WaitOne(15000)) { throw 'Released app did not report readiness' }
    $log = Join-Path $env:APPDATA 'ZigShell/debug.log'
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        $text = if (Test-Path $log) { Get-Content $log -Raw } else { '' }
        if ($text -match '\[update\] card view=collapsed' -and $text -match '\[update\] card remaining=') { break }
        if ($process.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw 'Released app did not paint the card' }
        Start-Sleep -Milliseconds 100
    } while ($true)
    for ($i = 0; $i -lt [Math]::Min(3, $changes.Count); $i++) {
        $note = [regex]::Match($text, '\[update\] card note ' + $i + '=([^\r\n]*)')
        if (-not $note.Success -or $note.Groups[1].Value -cne $changes[$i]) { throw 'Released card differs from published notes' }
    }
    if ($text -match '\[update\] card note \d+=.*(behind the scenes|latest improvements)') { throw 'Released card showed filler' }
    Add-Type -AssemblyName System.Drawing
    Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class ReleaseCardProof { [StructLayout(LayoutKind.Sequential)] public struct Point { public int X,Y; } [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int height, uint flags); [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref Point p); [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr wp, IntPtr lp); [StructLayout(LayoutKind.Sequential)] public struct Rect { public int L,T,R,B; } [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r); [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags); }'
    $process.Refresh()
    $rectangle = New-Object ReleaseCardProof+Rect
    if (-not [ReleaseCardProof]::GetWindowRect($process.MainWindowHandle, [ref]$rectangle)) { throw 'Released window unavailable' }
    $bitmap = New-Object Drawing.Bitmap(($rectangle.R - $rectangle.L), ($rectangle.B - $rectangle.T))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $dc = $graphics.GetHdc()
    try { if (-not [ReleaseCardProof]::PrintWindow($process.MainWindowHandle, $dc, 2)) { throw 'Released screenshot failed' } } finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
    $image = Join-Path $Evidence 'released-card.png'
    try { $bitmap.Save($image) } finally { $bitmap.Dispose() }
    if ((Get-FileHash $cardExe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) { throw 'Released binary changed during proof' }
    @{ version = $document.version; sha256 = $hash; changes = $changes; simulatedOffer = '999.0.0'; success = $true } | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $Evidence 'released-card.json')
    if ($Wrapped) {
        function Wait-Card([scriptblock]$Condition, [string]$Failure) {
            $deadline = [DateTime]::UtcNow.AddSeconds(10)
            do {
                $script:cardLog = Get-Content $log -Raw
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
            $script:cardLog = ''
            Remove-Item $log -Force
            if (-not [ReleaseCardProof]::SetWindowPos($process.MainWindowHandle, [IntPtr]::Zero, 0, 0, $Width, $Height, 0x0040)) { throw 'Card resize failed' }
            Wait-Card { $script:cardLog -match '\[update\] notes viewport=' } 'Card did not expose wrapped note bounds'
        }
        function Toggle-Card([string]$View) {
            $click = Card-Click 'more row'
            $lp = [IntPtr](($click.y -shl 16) -bor $click.x)
            $null = [ReleaseCardProof]::PostMessage($process.MainWindowHandle, 0x201, [IntPtr]1, $lp)
            $null = [ReleaseCardProof]::PostMessage($process.MainWindowHandle, 0x202, [IntPtr]0, $lp)
            Wait-Card { $script:cardLog -match ('card view=' + $View) } 'Card expansion control did not change view'
        }
        Resize-Card 1024 768
        $normal = Card-Bounds
        $heights = [regex]::Matches($script:cardLog, '\[update\] note height \d+=(\d+)')
        if ($heights.Count -lt 3 -or @($heights | Where-Object { [int]$_.Groups[1].Value -gt 24 }).Count -ne $heights.Count) { throw 'Long real notes did not wrap onto multiple lines' }
        Capture-Card 'wrapped-normal'
        Resize-Card 640 480
        Capture-Card 'wrapped-minimum'
        Toggle-Card 'expanded'
        $expanded = Card-Bounds
        $restartBefore = Card-Click 'restart button'
        if ($expanded.content -le $expanded.bottom - $expanded.top) { throw 'Long real notes did not require scrolling' }
        $local = New-Object ReleaseCardProof+Point
        $local.X = [int](($expanded.left + $expanded.right) / 2)
        $local.Y = [int](($expanded.top + $expanded.bottom) / 2)
        if (-not [ReleaseCardProof]::ClientToScreen($process.MainWindowHandle, [ref]$local)) { throw 'Card wheel coordinate failed' }
        $wheelPoint = [IntPtr](($local.Y -shl 16) -bor ($local.X -band 0xffff))
        $null = [ReleaseCardProof]::PostMessage($process.MainWindowHandle, 0x20A, [IntPtr](-120 -shl 16), $wheelPoint)
        Wait-Card { (Card-Bounds).scroll -gt 0 } 'Notes did not scroll inside their card'
        $scrolled = Card-Bounds
        $restartAfter = Card-Click 'restart button'
        if ($restartBefore.x -ne $restartAfter.x -or $restartBefore.y -ne $restartAfter.y -or $restartAfter.y -le $scrolled.bottom -or $scrolled.top -lt 0 -or $restartAfter.y -ge 480) { throw 'Scrolling moved or hid Restart' }
        Capture-Card 'wrapped-scrolled'
        Toggle-Card 'collapsed'
        if ((Card-Bounds).scroll -ne 0) { throw 'Collapse did not reset note scrolling' }
        Capture-Card 'wrapped-collapsed'
        $wrappedReceipt = @{ version = $document.version; sha256 = $hash; wrapped = $true; scrollVerified = $true; toggleVerified = $true; normal = $normal; expanded = $expanded; scrolled = $scrolled; restartBefore = $restartBefore; restartAfter = $restartAfter; changes = $changes; simulatedOffer = '999.0.0'; success = $true }
        $wrappedReceipt | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $Evidence 'wrapped-card.json')
        Write-Output ('WRAPPED_CARD_RECEIPT=' + [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $Evidence 'wrapped-card.json'))))
    }
    Write-Output ('RELEASE_CARD_RECEIPT=' + [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $Evidence 'released-card.json'))))
    Write-Output ('RELEASE_CARD_PNG=' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($image)))
} finally {
    if ($process) {
        Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $process.Id -and $_.Name -ieq 'powershell.exe' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
    }
    $mutex.ReleaseMutex()
    $mutex.Dispose()
    $event.Dispose()
}
