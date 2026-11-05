param([string]$Root = "$env:RUNNER_TEMP/update-release-fixtures", [string]$Verifier = "$pwd/zig-out/bin/multiprompt.exe", [string]$Evidence = '', [string]$NativeUpdate = '', [ValidateSet('All', 'Lifecycle', 'Rollback')][string]$TestGroup = 'All')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$script:manifestFault = ''
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:OS -ne 'Windows_NT') { throw 'Run update tests only on GitHub Windows' }
. "$PSScriptRoot/../src/update_release.ps1" -Mode Library

function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Refuses([scriptblock]$Action, [string]$Message) {
    $refused = $false
    try { & $Action } catch { $refused = $true }
    Assert $refused $Message
}
function Stop-FixtureApps {
    Get-Process | Where-Object {
        try {
            $processPath = $_.Path
            $processPath -and $processPath.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)
        } catch { $false }
    } | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue; $null = $_.WaitForExit(5000) }
}
function Wait-File([string]$Path) {
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    while (-not (Test-Path -LiteralPath $Path)) {
        if ([DateTime]::UtcNow -gt $deadline) { throw "Timed out waiting for $Path" }
        Start-Sleep -Milliseconds 100
    }
}
function Read-SharedLog([string]$Path) {
    $deadline = [DateTime]::UtcNow.AddSeconds(3)
    do {
        try {
            $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
            try {
                $reader = New-Object IO.StreamReader($stream)
                try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
            } finally { $stream.Dispose() }
        } catch [IO.FileNotFoundException] { return '' }
        catch [IO.IOException] {
            if ([DateTime]::UtcNow -gt $deadline) { throw }
            Start-Sleep -Milliseconds 25
        }
    } while ($true)
}
function Wait-CardView([string]$Path, [int]$From, [string]$View, [string[]]$Expected, [string]$Remaining) {
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    do {
        if ($cardProcess.HasExited) { throw 'Update card process exited before painting' }
        $text = Read-SharedLog $Path
        $fresh = if ($text.Length -ge $From) { $text.Substring($From) } else { '' }
        $views = [regex]::Matches($fresh, '(?s)\[update\] card view=(collapsed|expanded) n=(\d+) first=([^\r\n]*)[^\n]*\n(.*?)\[update\] card remaining=([^\r\n]*)\r?\n')
        $matching = @($views | Where-Object { $_.Groups[1].Value -ceq $View })
        if ($matching.Count -gt 0) { break }
        if ([DateTime]::UtcNow -gt $deadline) { throw "Timed out waiting for $View update card paint" }
        Start-Sleep -Milliseconds 100
    } while ($true)
    $viewMatch = $matching[-1]
    $notes = @([regex]::Matches($viewMatch.Groups[4].Value, '\[update\] card note (\d+)=([^\r\n]*)') | ForEach-Object { $_.Groups[2].Value })
    Assert ([int]$viewMatch.Groups[2].Value -eq $Expected.Count -and $notes.Count -eq $Expected.Count) "$View card note count changed"
    for ($i = 0; $i -lt $Expected.Count; $i++) { Assert ($notes[$i] -ceq $Expected[$i]) "$View card note $i changed" }
    Assert ($viewMatch.Groups[3].Value -ceq $Expected[0]) "$View card first note changed"
    Assert ($viewMatch.Groups[5].Value -ceq $Remaining) "$View card remaining label changed"
    $before = $fresh.Substring(0, $viewMatch.Index)
    $positions = [regex]::Matches($before, '\[update\] more row=(\d+),(\d+)')
    $viewports = [regex]::Matches($before, '\[update\] notes viewport=(\d+),(\d+),(\d+),(\d+) content=(\d+) scroll=(\d+)')
    Assert ($positions.Count -gt 0 -and $viewports.Count -gt 0) "$View card geometry missing"
    $position = $positions[$positions.Count - 1]
    $viewport = $viewports[$viewports.Count - 1]
    Assert ([int]$viewport.Groups[6].Value -eq 0 -and [int]$viewport.Groups[5].Value -le ([int]$viewport.Groups[4].Value - [int]$viewport.Groups[2].Value)) "$View card notes are clipped"
    return @{ view = $View; notes = $notes; remaining = $Remaining; moreX = [int]$position.Groups[1].Value; moreY = [int]$position.Groups[2].Value; viewport = $viewport.Value; logEnd = $From + $viewMatch.Index + $viewMatch.Length }
}
$script:lastCardClick = $null
function Click-CardMore($View) {
    if ($null -ne $script:lastCardClick) {
        $threshold = [int][UpdateProof]::GetDoubleClickTime() + 1
        while (($remaining = $threshold - $script:lastCardClick.ElapsedMilliseconds) -gt 0) {
            Start-Sleep -Milliseconds ([int]$remaining)
        }
    }
    $dpiContext = [UpdateProof]::SetThreadDpiAwarenessContext([IntPtr](-4))
    Assert ($dpiContext -ne [IntPtr]::Zero) 'Cannot set per-monitor DPI awareness for card input'
    try {
        $cardProcess.Refresh()
        $hwnd = $cardProcess.MainWindowHandle
        Assert ($hwnd -ne [IntPtr]::Zero -and [UpdateProof]::SetForegroundWindow($hwnd)) 'Could not focus update card window'
        $point = New-Object UpdateProof+Point
        $point.X = $View.moreX; $point.Y = $View.moreY
        $client = New-Object UpdateProof+Rect
        Assert ([UpdateProof]::GetClientRect($hwnd, [ref]$client)) 'Update card client bounds unavailable'
        Assert ($point.X -ge 0 -and $point.Y -ge 0 -and $point.X -lt $client.R -and $point.Y -lt $client.B) 'More row is outside the client'
        Assert ([UpdateProof]::ClientToScreen($hwnd, [ref]$point)) 'Cannot convert more row to screen coordinates'
        Assert ([UpdateProof]::WindowFromPoint($point) -eq $hwnd) 'More row is obscured by another window'
        Assert ([UpdateProof]::GetForegroundWindow() -eq $hwnd) 'Update card lost foreground before click'
        Assert ([UpdateProof]::SetCursorPos($point.X, $point.Y)) 'Cannot move pointer to more row'
        [UpdateProof]::Click()
        $script:lastCardClick = [Diagnostics.Stopwatch]::StartNew()
    } finally { [void][UpdateProof]::SetThreadDpiAwarenessContext($dpiContext) }
}
function Select-Release([string]$Version) {
    $script:releaseFolder = Join-Path $Root $Version
    $script:release = [pscustomobject]@{
        tag_name = $Version; draft = $false; prerelease = $false; author = @{ login = 'github-actions[bot]' }
        assets = @(Get-ChildItem -LiteralPath $script:releaseFolder -File | Where-Object { $_.Name -ne 'wrong.sig' } | ForEach-Object { @{ name = $_.Name; browser_download_url = "https://github.com/valentinyeo/multiprompt/releases/download/$Version/$($_.Name)" } })
    }
}
function Invoke-RestMethod { param($Uri, $Headers, $TimeoutSec) return $script:release }
function Invoke-WebRequest {
    param($Uri, $Headers, [switch]$UseBasicParsing, $TimeoutSec, $OutFile)
    $name = [IO.Path]::GetFileName($Uri)
    if ($script:manifestFault -eq 'missing' -and $name -eq 'SHA256SUMS.txt.sig') { throw 'Fixture signature asset missing' }
    if ($script:manifestFault -eq 'wrong' -and $name -eq 'SHA256SUMS.txt.sig') { $name = 'wrong.sig' }
    Copy-Item -LiteralPath (Join-Path $script:releaseFolder $name) -Destination $OutFile -Force
    if ($script:manifestFault -eq 'tampered' -and $name -eq 'SHA256SUMS.txt') { [IO.File]::AppendAllText($OutFile, 'tampered') }
}

$Root = [IO.Path]::GetFullPath($Root)
$Verifier = (Resolve-Path $Verifier).Path
$original = @{}
foreach ($name in @('APPDATA', 'LOCALAPPDATA', 'USERPROFILE', 'HOME', 'MULTIPROMPT_NO_LOGIN', 'IGSH_246', 'MULTIPROMPT_TEST_VERIFIER', 'ZIGSHELL_DEBUG')) { $original[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$target = Join-Path $Root 'app.exe'
$dir = "$target.update"
$checks = New-Object System.Collections.ArrayList
$journeySucceeded = $false
function Passed([string]$Name) { [void]$checks.Add($Name); Write-Host "$Name passed" }
try {
    foreach ($folder in @('roaming/ZigShell', 'local', 'profile/Documents/GitHub/zigshell/extension/themes/current')) { New-Item -ItemType Directory -Force (Join-Path $Root $folder) | Out-Null }
    $env:APPDATA = Join-Path $Root 'roaming'
    $env:LOCALAPPDATA = Join-Path $Root 'local'
    $env:USERPROFILE = Join-Path $Root 'profile'
    $env:HOME = $env:USERPROFILE
    $env:IGSH_246 = '1'
    $env:MULTIPROMPT_NO_LOGIN = ''
    Copy-Item -LiteralPath $Verifier -Destination "$Root/verifier.exe" -Force
    $env:MULTIPROMPT_TEST_VERIFIER = "$Root/verifier.exe"
    if ($TestGroup -ne 'Rollback') {
        $eventName = 'Local\MultipromptSignIn-' + [guid]::NewGuid().ToString('N')
        $event = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::ManualReset, $eventName)
        $timer = [Diagnostics.Stopwatch]::StartNew()
        $signedOut = Start-Process -FilePath "$Root/verifier.exe" -ArgumentList "--name `"Review sign in`" --update-ready $eventName" -PassThru
        try {
            Assert ($event.WaitOne(15000)) 'Sign-in screen did not report responsive readiness'
            $signedOut.Refresh()
            Assert (-not $signedOut.HasExited -and $signedOut.MainWindowHandle -ne [IntPtr]::Zero) 'Sign-in readiness had no live main window'
            Start-Sleep -Seconds 2
            Assert ($signedOut.Responding) 'Sign-in process is unresponsive during background network check'
            if ($Evidence) {
                New-Item -ItemType Directory -Force $Evidence | Out-Null
                Add-Type -AssemblyName System.Drawing
                Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class UpdateProof { [StructLayout(LayoutKind.Sequential)] public struct Rect { public int L,T,R,B; } [StructLayout(LayoutKind.Sequential)] public struct Point { public int X,Y; } [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref Point p); [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(Point p); [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags); [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow(); [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y); [DllImport("user32.dll")] public static extern uint GetDoubleClickTime(); [StructLayout(LayoutKind.Sequential)] public struct Mouse { public int x, y; public uint data, flags, time; public UIntPtr extra; } [StructLayout(LayoutKind.Explicit)] public struct InputUnion { [FieldOffset(0)] public Mouse mouse; } [StructLayout(LayoutKind.Sequential)] public struct Input { public uint type; public InputUnion data; } [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint count, Input[] inputs, int size); [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context); public static void Click() { foreach (uint flags in new uint[] { 2, 4 }) { Input input = new Input(); input.data.mouse.flags = flags; if (SendInput(1, new Input[] { input }, Marshal.SizeOf(typeof(Input))) != 1) throw new InvalidOperationException("Mouse SendInput failed"); System.Threading.Thread.Sleep(35); } } [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r); [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out Rect r); [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h); [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags); [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l); }'
                $rectangle = New-Object UpdateProof+Rect
                Assert ([UpdateProof]::GetWindowRect($signedOut.MainWindowHandle, [ref]$rectangle)) 'Sign-in window rectangle unavailable'
                $bitmap = New-Object Drawing.Bitmap(($rectangle.R - $rectangle.L), ($rectangle.B - $rectangle.T))
                $graphics = [Drawing.Graphics]::FromImage($bitmap)
                $dc = $graphics.GetHdc()
                try { Assert ([UpdateProof]::PrintWindow($signedOut.MainWindowHandle, $dc, 2)) 'Sign-in screenshot failed' } finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
                try { $bitmap.Save((Join-Path $Evidence 'sign-in-ready.png')) } finally { $bitmap.Dispose() }
            }
            Assert (-not (Test-Path "$env:APPDATA/ZigShell/session.json")) 'Signed-out startup restored sessions'
            Passed 'sign-in screen responsive ready before deferred tabs'
        } finally {
            Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $signedOut.Id -and $_.Name -ieq 'powershell.exe' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
            if (-not $signedOut.HasExited) { $signedOut.Kill(); $signedOut.WaitForExit() }
            $event.Dispose()
        }
        Assert ($timer.Elapsed.TotalSeconds -lt 20) 'Sign-in launch was blocked'
        if ($Evidence) {
            $sharedLogFixture = Join-Path $Root 'shared-log-proof.txt'
            $writer = [IO.File]::Open($sharedLogFixture, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::Read)
            try {
                $bytes = [Text.Encoding]::UTF8.GetBytes('first')
                $writer.Write($bytes, 0, $bytes.Length); $writer.Flush()
                Assert ((Read-SharedLog $sharedLogFixture) -ceq 'first') 'Shared log read failed while writer was open'
                $bytes = [Text.Encoding]::UTF8.GetBytes(' second')
                $writer.Write($bytes, 0, $bytes.Length); $writer.Flush()
                Assert ((Read-SharedLog $sharedLogFixture) -ceq 'first second') 'Shared log read missed appended data'
            } finally { $writer.Dispose(); Remove-Item -LiteralPath $sharedLogFixture -Force }
            Passed 'shared log reads while writer remains open'
            $cardExe = Join-Path $Root 'card.exe'
            Copy-Item -LiteralPath $Verifier -Destination $cardExe -Force
            Select-Release 'v9.10.0'
            Assert (Save-Update $cardExe '0.0.0' 'x64') 'Card notes fixture was not staged'
            $mutexName = 'Local\MultipromptUpdate-' + ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::Unicode.GetBytes($cardExe.ToLowerInvariant())))).Replace('-', '')
            $cardMutex = New-Object Threading.Mutex($false, $mutexName)
            $null = $cardMutex.WaitOne()
            $cardEventName = 'Local\MultipromptCard-' + [guid]::NewGuid().ToString('N')
            $cardEvent = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::ManualReset, $cardEventName)
            $cardProcess = $null
            $env:APPDATA = Join-Path $Root 'card-roaming'
            New-Item -ItemType Directory -Force (Join-Path $env:APPDATA 'ZigShell') | Out-Null
            $log = Join-Path $env:APPDATA 'ZigShell/debug.log'
            Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue
            $env:MULTIPROMPT_NO_LOGIN = '1'
            $env:ZIGSHELL_DEBUG = '1'
            try {
                $sessionPath = Join-Path $env:APPDATA 'ZigShell/session.json'
                [IO.File]::WriteAllText($sessionPath, '{"tabs":[{"kind":"cmd","name":"Restart proof"}],"active_tab":0}')
                $cardProcess = Start-Process $cardExe -ArgumentList "--update-ready $cardEventName" -PassThru
                Assert ($cardEvent.WaitOne(15000)) 'Card fixture did not report readiness'
                $stagedNotes = Get-Content "$cardExe.update/release-notes.json" -Raw | ConvertFrom-Json
                Assert ($stagedNotes.version -ceq '9.10.0') 'Staged notes version mismatch'
                $expectedNotes = @('IGSH-5 Typing feels faster', 'IGSH-6 Chats keep your place', 'IGSH-2 Middle change', 'IGSH-1 Older change')
                $currentReleases = @(@($stagedNotes.releases) | Where-Object { $_.version -ceq '9.10.0' })
                $middleReleases = @(@($stagedNotes.releases) | Where-Object { $_.version -ceq '9.9.0' })
                $olderReleases = @(@($stagedNotes.releases) | Where-Object { $_.version -ceq '9.8.0' })
                Assert ($currentReleases.Count -eq 1 -and $middleReleases.Count -eq 1 -and $olderReleases.Count -eq 1) 'Staged note releases missing or duplicated'
                $observedNotes = @($currentReleases[0].changes[0], $currentReleases[0].changes[1], $middleReleases[0].changes[0], $olderReleases[0].changes[0])
                for ($i = 0; $i -lt $expectedNotes.Count; $i++) { Assert ($observedNotes[$i] -ceq $expectedNotes[$i]) 'Staged note order changed' }
                Assert ((Get-FileHash "$cardExe.update/release-notes.json" -Algorithm SHA256).Hash -eq (Get-FileHash (Join-Path $script:releaseFolder 'release-notes.json') -Algorithm SHA256).Hash) 'Staged notes differ from the signed release'
                $collapsed = Wait-CardView $log 0 'collapsed' $expectedNotes[0..2] 'and 1 more'
                $cardProcess.Refresh()
                $rectangle = New-Object UpdateProof+Rect
                Assert ([UpdateProof]::GetWindowRect($cardProcess.MainWindowHandle, [ref]$rectangle)) 'Update card window unavailable'
                $bitmap = New-Object Drawing.Bitmap(($rectangle.R - $rectangle.L), ($rectangle.B - $rectangle.T))
                $graphics = [Drawing.Graphics]::FromImage($bitmap)
                $dc = $graphics.GetHdc()
                try { Assert ([UpdateProof]::PrintWindow($cardProcess.MainWindowHandle, $dc, 2)) 'Update card screenshot failed' } finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
                try { $bitmap.Save((Join-Path $Evidence 'update-card-notes.png')) } finally { $bitmap.Dispose() }
                $collapsed | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $Evidence 'update-card-notes.json')
                Click-CardMore $collapsed
                $expanded = Wait-CardView $log $collapsed.logEnd 'expanded' $expectedNotes 'Show less'
                Assert ([UpdateProof]::GetWindowRect($cardProcess.MainWindowHandle, [ref]$rectangle)) 'Expanded update card window unavailable'
                $bitmap = New-Object Drawing.Bitmap(($rectangle.R - $rectangle.L), ($rectangle.B - $rectangle.T))
                $graphics = [Drawing.Graphics]::FromImage($bitmap)
                $dc = $graphics.GetHdc()
                try { Assert ([UpdateProof]::PrintWindow($cardProcess.MainWindowHandle, $dc, 2)) 'Expanded update card screenshot failed' } finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
                try { $bitmap.Save((Join-Path $Evidence 'update-card-expanded.png')) } finally { $bitmap.Dispose() }
                $expanded | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $Evidence 'update-card-expanded.json')
                Click-CardMore $expanded
                $null = Wait-CardView $log $expanded.logEnd 'collapsed' $expectedNotes[0..2] 'and 1 more'
                Passed 'update card paints ticket titles and expands with real click'
                Passed 'signed staged notes retain expected data'
                Select-Release 'v9.11.0'
                Assert (Save-Update $cardExe '0.0.0' 'x64') 'Ticket-title release was not staged'
                $titleNotes = Get-Content "$cardExe.update/release-notes.json" -Raw | ConvertFrom-Json
                Assert ($titleNotes.releases[0].changes.Count -eq 1 -and $titleNotes.releases[0].changes[0] -ceq 'IGSH-1243 Changelog ticket links') 'Ticket title is missing or changed'
                Assert ($titleNotes.releases[0].tickets.Count -eq 1 -and $titleNotes.releases[0].tickets[0] -ceq 'https://app.hypertask.ai/detail/project-2060/1243') 'Ticket link is missing or changed'
                Assert ((Get-Content "$cardExe.update/ready.txt" -Raw).Contains('MPVERSION=9.11.0;')) 'Ticket-title update marker missing'
                Assert (-not $cardProcess.HasExited) 'Ticket-title update interrupted the app'
                $cardProcess.Refresh()
                Assert ($cardProcess.Responding) 'Ticket-title update blocked the app'
                Assert ([UpdateProof]::GetWindowRect($cardProcess.MainWindowHandle, [ref]$rectangle)) 'Ticket-title update window unavailable'
                $bitmap = New-Object Drawing.Bitmap(($rectangle.R - $rectangle.L), ($rectangle.B - $rectangle.T))
                $graphics = [Drawing.Graphics]::FromImage($bitmap)
                $dc = $graphics.GetHdc()
                try { Assert ([UpdateProof]::PrintWindow($cardProcess.MainWindowHandle, $dc, 2)) 'Ticket-title update screenshot failed' } finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
                try { $bitmap.Save((Join-Path $Evidence 'update-card-ticket-title.png')) } finally { $bitmap.Dispose() }
                Passed 'ticket-title staged notes retain title and ticket link'
                Select-Release 'v9.10.0'
                Assert (Save-Update $cardExe '0.0.0' 'x64') 'Real product notes were not restored'
                Assert ((Get-Content "$cardExe.update/ready.txt" -Raw).Contains('MPVERSION=9.10.0;')) 'Restored update marker missing'
                $versionMatch = [regex]::Match([Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Verifier)), 'MPVERSION=(\d+\.\d+\.\d+);')
                Assert $versionMatch.Success 'Native verifier version marker missing'
                $oldVersion = $versionMatch.Groups[1].Value
                $newVersion = '9.99.999'
                Assert ($NativeUpdate -and (Test-Path $NativeUpdate)) 'Native update build was not supplied'
                Assert ([Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($NativeUpdate)).Contains("MPVERSION=$newVersion;")) 'Native update build has the wrong version'
                $installedNotes = Get-Content "$cardExe.update/release-notes.json" -Raw | ConvertFrom-Json
                $installedNotes.version = $newVersion
                $installedNotes.releases = @(@{ version = $newVersion; changes = @('IGSH-5 Typing feels faster') }) + @($installedNotes.releases)
                [IO.File]::WriteAllText("$cardExe.update/release-notes.json", ($installedNotes | ConvertTo-Json -Depth 8))
                Remove-Item -LiteralPath "$cardExe.update/ready.txt" -Force
                $deadline = [DateTime]::UtcNow.AddSeconds(15)
                do {
                    if ((Test-Path -LiteralPath $log) -and (Read-SharedLog $log).Contains('update-card: launch path stamp captured')) { break }
                    if ([DateTime]::UtcNow -gt $deadline) { throw 'Update card did not capture its launch stamp' }
                    Start-Sleep -Milliseconds 100
                } while ($true)
                Copy-Item -LiteralPath $NativeUpdate -Destination "$Root/card.next.exe"
                Move-Item -LiteralPath $cardExe -Destination "$Root/card.running.exe"
                Move-Item -LiteralPath "$Root/card.next.exe" -Destination $cardExe
                $win32 = Get-Content "$PSScriptRoot/../src/win32.zig" -Raw
                $appMessage = [regex]::Match($win32, 'pub const WM_APP: u32 = (0x[0-9a-fA-F]+);')
                $updateMessage = [regex]::Match($win32, 'pub const WM_APP_UPDATE_CHANGED: u32 = WM_APP \+ (\d+);')
                Assert ($appMessage.Success -and $updateMessage.Success) 'Update notification binding unavailable'
                $message = [Convert]::ToUInt32($appMessage.Groups[1].Value.Substring(2), 16) + [uint32]$updateMessage.Groups[1].Value
                Assert ([UpdateProof]::PostMessage($cardProcess.MainWindowHandle, $message, [IntPtr]::Zero, [IntPtr]::Zero)) 'Update notification failed'
                do {
                    $cardLog = Read-SharedLog $log
                    if ($cardLog.Contains('update-card: new version ready ' + $newVersion)) { break }
                    if ([DateTime]::UtcNow -gt $deadline) { throw 'Installed update was not offered on the card' }
                    Start-Sleep -Milliseconds 100
                } while ($true)
                Start-Sleep -Milliseconds 300
                $client = New-Object UpdateProof+Rect
                Assert ([UpdateProof]::GetClientRect($cardProcess.MainWindowHandle, [ref]$client)) 'Restart client bounds unavailable'
                $scale = [UpdateProof]::GetDpiForWindow($cardProcess.MainWindowHandle) / 96.0
                Assert ($scale -gt 0 -and $client.B -gt [int](104 * $scale)) 'Restart client DPI or height invalid'
                $clickX = [int][Math]::Round(24 * $scale)
                $clickY = $client.B - [int][Math]::Round(29 * $scale)
                $click = [IntPtr](($clickY -shl 16) -bor $clickX)
                $inboxPath = Join-Path $env:APPDATA 'ZigShell/inbox-default.json'
                Remove-Item -LiteralPath $inboxPath -Force -ErrorAction SilentlyContinue
                $restartTimer = [Diagnostics.Stopwatch]::StartNew()
                Assert ([UpdateProof]::PostMessage($cardProcess.MainWindowHandle, 0x201, [IntPtr]1, $click)) 'Restart button press failed'
                Assert ([UpdateProof]::PostMessage($cardProcess.MainWindowHandle, 0x202, [IntPtr]0, $click)) 'Restart button release failed'
                Assert ($cardProcess.WaitForExit(15000)) 'Restart card did not close the old app'
                $deadline = [DateTime]::UtcNow.AddSeconds(20)
                do {
                    $restored = @(Get-Process | Where-Object {
                        try { $processPath = $_.Path; $processPath -ieq $cardExe -and $_.MainWindowTitle -ceq 'Multi Bot' } catch { $false }
                    })
                    if ($restored.Count -eq 1 -and (Test-Path $inboxPath)) {
                        try {
                            $inbox = Get-Content $inboxPath -Raw | ConvertFrom-Json
                            if ($inbox.hwnd -eq $restored[0].MainWindowHandle.ToInt64().ToString() -and @($inbox.shells | Where-Object { $_.name -ceq 'Restart proof' }).Count -eq 1) { break }
                        } catch {}
                    }
                    if ([DateTime]::UtcNow -gt $deadline) { throw 'Restart did not reopen the new native app with its session restored' }
                    Start-Sleep -Milliseconds 100
                } while ($true)
                Assert ($restartTimer.Elapsed.TotalSeconds -lt 10) 'Restart took longer than ten seconds'
                $saved = Get-Content $sessionPath -Raw | ConvertFrom-Json
                Assert (@($saved.tabs | Where-Object { $_.name -ceq 'Restart proof' }).Count -eq 1) 'Restart lost or duplicated the saved session'
                Assert ([UpdateProof]::GetWindowRect($restored[0].MainWindowHandle, [ref]$rectangle)) 'Restored window unavailable'
                $bitmap = New-Object Drawing.Bitmap(($rectangle.R - $rectangle.L), ($rectangle.B - $rectangle.T))
                $graphics = [Drawing.Graphics]::FromImage($bitmap)
                $dc = $graphics.GetHdc()
                try { Assert ([UpdateProof]::PrintWindow($restored[0].MainWindowHandle, $dc, 2)) 'Restart screenshot failed' } finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
                try { $bitmap.Save((Join-Path $Evidence 'update-card-restarted.png')) } finally { $bitmap.Dispose() }
                @{ oldVersion = $oldVersion; newVersion = $newVersion; seconds = $restartTimer.Elapsed.TotalSeconds; session = 'Restart proof'; process = $restored[0].Id } | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $Evidence 'update-card-restarted.json')
                Passed 'restart card reopens newer native app with session restored'
            } finally {
                foreach ($proofFile in @($log, $sessionPath, (Join-Path $env:APPDATA 'ZigShell/inbox-default.json'))) {
                    if (Test-Path $proofFile) {
                        if ($proofFile -eq $log) { [IO.File]::WriteAllText((Join-Path $Evidence 'debug.log'), (Read-SharedLog $log)) }
                        else { Copy-Item -LiteralPath $proofFile -Destination $Evidence -Force }
                    }
                }
                Get-Process | Where-Object { try { $processPath = $_.Path; $processPath -and $processPath.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase) } catch { $false } } | Select-Object Id,Path,MainWindowTitle | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $Evidence 'restart-processes.json')
                if ($cardProcess -and -not $cardProcess.HasExited) { $cardProcess.Kill(); $cardProcess.WaitForExit() }
                Stop-FixtureApps
                Remove-Item -LiteralPath $sessionPath, "$sessionPath.bak" -Force -ErrorAction SilentlyContinue
                $cardEvent.Dispose()
                $cardMutex.ReleaseMutex()
                $cardMutex.Dispose()
                $env:MULTIPROMPT_NO_LOGIN = ''
                $env:ZIGSHELL_DEBUG = ''
                $env:APPDATA = Join-Path $Root 'roaming'
            }
        }

        $env:IGSH_246 = '0'
        Select-Release 'v1.10.0'
        $cold = Join-Path $Root 'cold.exe'
        Copy-Item -LiteralPath $Verifier -Destination $cold
        Assert (Save-Update $cold '0.0.0' 'x64') 'Cold-launch fixture was not staged'
        $env:IGSH_246 = '1'
        $coldStart = Start-Process $cold -ArgumentList ' "--name" "Review Desk" "--other" "C:\tail\\"' -PassThru
        Assert ($coldStart.WaitForExit(20000)) 'Cold launch did not hand off its staged update before restoring tabs'
        Wait-File "$cold.starts"
        $coldDeadline = [DateTime]::UtcNow.AddSeconds(20)
        while (Test-Path "$cold.update/ready.txt") {
            if ([DateTime]::UtcNow -gt $coldDeadline) { throw 'Cold staged update did not finish' }
            Start-Sleep -Milliseconds 100
        }
        Assert ((Get-FileHash $cold).Hash -eq (Get-FileHash "$Root/v1.10.0/multiprompt-x64.exe").Hash) 'Cold staged swap did not install verified update'
        Assert ((Get-Content "$cold.starts" -Raw).Contains('--name|Review Desk|--other|C:\tail\|--update-ready|')) 'Real app update did not forward launch arguments'
        Assert (-not (Test-Path "$env:APPDATA/ZigShell/session.json")) 'Cold update restored tabs before swapping'
        Passed 'real cold-launch staged apply preserves launch arguments before tabs'
        Stop-FixtureApps
        Remove-Item "$Root/zigshell-bridge.exe" -Force
        $env:IGSH_246 = '0'


        Copy-Item "$Root/fixture.exe" $target -Force
        Copy-Item "$Root/fixture.exe" "$Root/zigshell-bridge.exe" -Force
        $oldHash = (Get-FileHash $target).Hash
        $launch = ' "--name" "Review Desk" "--other" "C:\tail\\"'
        $encodedArguments = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($launch))
        Select-Release 'v1.10.0'
        New-Item -ItemType Directory -Force $dir | Out-Null
        Copy-Item "$script:releaseFolder/SHA256SUMS.txt*" $dir -Force
        Assert-Manifest $target $dir
        Assert (Save-Update $target '1.9.0' 'x64') 'Valid manifest signature did not stage an update'
        Passed 'valid signature accepted'
        Assert (Test-Path "$dir/release-notes.json") 'Verified release notes were not staged'
        [IO.File]::AppendAllText("$dir/release-notes.json", 'tampered')
        Refuses { Assert-Update "$dir/release-notes.json" "$dir/SHA256SUMS.txt" 'release-notes.json' $target } 'Tampered notes accepted'
        Assert (Save-Update $target '1.9.0' 'x64') 'Could not restage verified notes'
        Passed 'release notes checksum verified'
        Copy-Item "$script:releaseFolder/wrong.sig" "$dir/SHA256SUMS.txt.sig" -Force
        Refuses { Assert-Manifest $target $dir } 'Wrong signing key accepted'
        $script:manifestFault = 'wrong'
        try { Refuses { Save-Update $target '1.9.0' 'x64' } 'Unverified manifest staged an update' } finally { $script:manifestFault = '' }
        Assert (-not (Test-Path "$dir/ready.txt")) 'Unverified signature left update ready'
        Assert ((Get-FileHash $target).Hash -eq $oldHash) 'Unverified manifest modified installation'
        Passed 'wrong key rejected'
        Copy-Item "$script:releaseFolder/SHA256SUMS.txt.sig" "$dir/SHA256SUMS.txt.sig" -Force
        [IO.File]::AppendAllText("$dir/SHA256SUMS.txt", 'tampered')
        Refuses { Assert-Manifest $target $dir } 'Tampered manifest accepted'
        $script:manifestFault = 'tampered'
        try { Refuses { Save-Update $target '1.9.0' 'x64' } 'Unverified manifest staged an update' } finally { $script:manifestFault = '' }
        Assert (-not (Test-Path "$dir/ready.txt")) 'Unverified signature left update ready'
        Assert ((Get-FileHash $target).Hash -eq $oldHash) 'Unverified manifest modified installation'
        Passed 'tampered SHA256SUMS rejected'
        Copy-Item "$script:releaseFolder/SHA256SUMS.txt" "$dir/SHA256SUMS.txt" -Force
        Remove-Item "$dir/SHA256SUMS.txt.sig"
        Refuses { Assert-Manifest $target $dir } 'Missing signature accepted'
        $script:manifestFault = 'missing'
        try { Refuses { Save-Update $target '1.9.0' 'x64' } 'Unverified manifest staged an update' } finally { $script:manifestFault = '' }
        Assert (-not (Test-Path "$dir/ready.txt")) 'Unverified signature left update ready'
        Assert ((Get-FileHash $target).Hash -eq $oldHash) 'Unverified manifest modified installation'
        Passed 'missing signature rejected'

        Assert ((Get-ReleaseVersion 'v1.10.0') -gt (Get-ReleaseVersion '1.9.999')) 'Numeric version comparison'
        Assert ((Get-ReleaseVersion '1.2.3') -eq (Get-ReleaseVersion 'v1.2.3')) 'Equal versions'
        Assert ((Get-ReleaseVersion '2.0.0') -gt (Get-ReleaseVersion '1.999.999')) 'Major comparison'
        foreach ($invalid in @('1.2', '1.2.3-beta', '1.2.3.4', '01.2.3', 'v1.2.3;bad')) { Refuses { Get-ReleaseVersion $invalid } 'Invalid version accepted' }
        Passed 'version comparison'
        $signatureBytes = [IO.File]::ReadAllBytes("$script:releaseFolder/SHA256SUMS.txt.sig")
        $signatureBytes[0] = $signatureBytes[0] -bxor 1
        [IO.File]::WriteAllBytes("$dir/SHA256SUMS.txt.sig", $signatureBytes)
        Refuses { Assert-Manifest $target $dir } 'Invalid signature accepted'
        Assert (-not (Test-Path "$dir/ready.txt")) 'Invalid signature marked ready'
        $script:release.author.login = 'untrusted-user'
        Refuses { Save-Update $target '1.9.0' 'x64' } 'Untrusted author accepted'
        $script:release.author.login = 'github-actions[bot]'
        $script:release.assets[0].browser_download_url = 'https://example.com/untrusted.exe'
        Refuses { Save-Update $target '1.9.0' 'x64' } 'External asset URL accepted'
        Select-Release 'v1.10.0'
        Assert (-not (Save-Update $target '2.0.0' 'x64')) 'Downgrade staged'
        Assert (-not (Save-Update $target '1.10.0' 'x64')) 'Equal release staged'
        Assert (Save-Update $target '1.9.0' 'x64') 'Verified update was not staged'
        Assert ((Get-FileHash $target).Hash -eq $oldHash) 'Background check replaced installation'
        Assert (-not (Test-Path "$target.starts")) 'Background check launched the app'
        Assert (-not (Test-Path "$target.previous.exe")) 'Background check installed without consent'
        Passed 'no automatic restart while running'
        [IO.File]::AppendAllText("$dir/next.exe", 'tampered')
        Refuses { Assert-Update "$dir/next.exe" "$dir/SHA256SUMS.txt" 'multiprompt-x64.exe' $target } 'Checksum mismatch accepted'
        Passed 'checksum mismatch refused'
        Assert (Save-Update $target '1.9.0' 'x64') 'Could not restage good checksum'
        [IO.File]::AppendAllText("$dir/next-bridge.exe", 'tampered')
        Refuses { Assert-Update "$dir/next-bridge.exe" "$dir/SHA256SUMS.txt" 'zigshell-bridge-x64.exe' $target } 'Bridge checksum mismatch accepted'
        Passed 'matching bridge checksum enforced'
        Assert (Save-Update $target '1.9.0' 'x64') 'Could not restage good bridge'
        Refuses { Install-Update $target 'x64' '' '2.0.0' } 'Staged downgrade accepted'
        Stop-FixtureApps
        Assert (Save-Update $target '1.9.0' 'x64') 'Could not restage after stale refusal'

        $mutexName = 'Local\MultipromptUpdate-' + ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::Unicode.GetBytes($target.ToLowerInvariant())))).Replace('-', '')
        $mutex = New-Object Threading.Mutex($false, $mutexName)
        $null = $mutex.WaitOne()
        $acceptedName = 'Local\MultipromptApplyTest-' + [guid]::NewGuid().ToString('N')
        $accepted = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::ManualReset, $acceptedName)
        try {
            $updater = [IO.Path]::GetFullPath("$PSScriptRoot/../src/update_release.ps1")
            $apply = Start-Process powershell.exe -ArgumentList "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$updater`" -Mode Apply -Exe `"$target`" -Current 1.9.0 -Arch x64 -AcceptedEvent $acceptedName -LaunchArguments $encodedArguments" -PassThru
            Assert ($accepted.WaitOne(5000)) 'Restart did not acknowledge while download lock was held'
            Start-Sleep -Seconds 16
            Assert (-not $apply.HasExited) 'Apply silently abandoned download lock'
        } finally { $mutex.ReleaseMutex(); $mutex.Dispose(); $accepted.Dispose() }
        Assert ($apply.WaitForExit(30000)) 'Apply did not finish after download completed'
        Assert ($apply.ExitCode -eq 0) 'First signed swap failed'
        Assert ((Get-FileHash $target).Hash -eq (Get-FileHash "$Root/v1.10.0/multiprompt-x64.exe").Hash) 'First app swap mismatch'
        Assert ((Get-FileHash "$Root/zigshell-bridge.exe").Hash -eq (Get-FileHash "$Root/v1.10.0/zigshell-bridge-x64.exe").Hash) 'First bridge swap mismatch'
        Assert (-not (Test-Path "$dir/ready.txt")) 'Successful card did not clear'
        Assert ((Get-Content "$target.starts" -Raw).Contains('--name|Review Desk|--other|C:\tail\|--update-ready|')) 'Launch arguments not preserved'
        Passed 'restart during download lock finishes after download'
        Passed 'first signed local release swap'
        Stop-FixtureApps

        $collector = Start-Process "$target.previous.exe" -ArgumentList '--usage-telemetry' -PassThru
        Wait-File "$target.previous.exe.telemetry-ready"
        $bridgeHelper = Start-Process "$Root/zigshell-bridge.exe" -PassThru
        Wait-File "$Root/zigshell-bridge.exe.starts"
        Assert (-not $collector.HasExited -and -not $bridgeHelper.HasExited) 'Old helpers did not hold executable locks'
        Select-Release 'v1.11.0'
        Assert (Save-Update $target '1.10.0' 'x64') 'Second release not staged'
        Install-Update $target 'x64' '' '1.10.0'
        Assert ($collector.WaitForExit(5000) -and $bridgeHelper.WaitForExit(5000)) 'Old helper processes survived swap'
        Assert ((Get-FileHash $target).Hash -eq (Get-FileHash "$Root/v1.11.0/multiprompt-x64.exe").Hash) 'Second app update failed'
        Assert ((Get-FileHash "$Root/zigshell-bridge.exe").Hash -eq (Get-FileHash "$Root/v1.11.0/zigshell-bridge-x64.exe").Hash) 'Second bridge update failed'
        Assert (-not (Test-Path "$dir/ready.txt")) 'Second card did not clear'
        Passed 'locked backup update succeeds'
        Passed 'second consecutive update'
        Stop-FixtureApps

        $extension = Join-Path $env:USERPROFILE 'Documents/GitHub/zigshell/extension'
        Assert ((Get-Content "$extension/manifest.json" -Raw) -match '2.0.0') 'Matching extension files were not updated'
        Assert (-not (Test-Path "$extension/themes/current/manifest.json")) 'User-selected current theme overwritten'
        Passed 'extension install preserves current theme'
    }
    if ($TestGroup -eq 'Rollback') {
        $env:IGSH_246 = '0'
        Copy-Item "$Root/v1.11.0/multiprompt-x64.exe" $target -Force
        Copy-Item "$Root/v1.11.0/zigshell-bridge-x64.exe" "$Root/zigshell-bridge.exe" -Force
        Copy-Item "$Root/v1.10.0/multiprompt-x64.exe" "$target.previous.exe" -Force
        $extension = Join-Path $env:USERPROFILE 'Documents/GitHub/zigshell/extension'
        Copy-Item "$Root/extension/manifest.json" "$extension/manifest.json" -Force
        $launch = ' "--name" "Review Desk" "--other" "C:\tail\\"'
        $null = Start-Process $target -ArgumentList '--name "Rollback setup"' -PassThru
        Wait-File "$target.starts"
        Stop-FixtureApps
    }
    if ($TestGroup -ne 'Lifecycle') {
        $goodHash = (Get-FileHash $target).Hash
        $bridgeHash = (Get-FileHash "$Root/zigshell-bridge.exe").Hash
        Select-Release 'v1.12.0'
        Assert (Save-Update $target '1.11.0' 'x64') 'Broken release not staged'
        Refuses { Install-Update $target 'x64' '' '1.11.0' } 'Broken new executable reported success'
        Assert ((Get-FileHash $target).Hash -eq $goodHash) 'Rollback did not restore app'
        Assert ((Get-FileHash "$Root/zigshell-bridge.exe").Hash -eq $bridgeHash) 'Rollback did not restore bridge'
        Assert ((Get-FileHash "$target.previous.exe").Hash -eq $goodHash) 'Previous executable not retained'
        Assert ((Get-FileHash "$dir/failed.exe").Hash -eq (Get-FileHash "$Root/v1.12.0/multiprompt-x64.exe").Hash) 'Failed executable not quarantined'
        Assert ((Get-Content "$dir/rejected.txt" -Raw) -eq 'v1.12.0') 'Failed version not suppressed'
        Assert (-not (Save-Update $target '1.11.0' 'x64')) 'Failed version retried'
        Assert (-not (Test-Path "$dir/ready.txt")) 'Failed version remains ready'
        $rollbackDeadline = [DateTime]::UtcNow.AddSeconds(15)
        while ((Get-Content "$target.starts" | Select-Object -Last 1) -ne '--name|Review Desk|--other|C:\tail\') {
            if ([DateTime]::UtcNow -gt $rollbackDeadline) { throw 'Rollback arguments changed or retained readiness flag' }
            Start-Sleep -Milliseconds 100
        }
        $restored = @(Get-Process | Where-Object { $processPath = $_.Path; $processPath -eq $target })
        Assert ($restored.Count -eq 1) 'Rollback did not leave exactly one app running'
        Start-Sleep -Seconds 61
        Assert (-not $restored[0].HasExited) 'Old rollback app killed on ready deadline'
        Passed 'rollback after failed start'
        Passed 'immediate-exit rollback'
        Passed 'restored app has no ready deadline'
        Stop-FixtureApps

    }
    if ($TestGroup -ne 'Rollback') {
        Select-Release 'v1.11.0'
        Assert (Save-Update $target '1.10.0' 'x64') 'Exit-timeout fixture not staged'
        $script:timeoutObserved = $false
        $script:unboundedObserved = $false
        function Get-WaitingProcesses([string]$Pids) {
            $fake = New-Object PSObject
            $fake | Add-Member ScriptMethod WaitForExit {
                if ($args.Count -gt 0) { Assert ($args[0] -eq 60000) 'Wrong exit timeout'; $script:timeoutObserved = $true; return $false }
                $script:unboundedObserved = $true
            }
            return $fake
        }
        Install-Update $target 'x64' '999' '1.10.0'
        Assert ($script:timeoutObserved -and $script:unboundedObserved) 'Long exit was not supervised until completion'
        Wait-File "$target.starts"
        $running = @(Get-Process | Where-Object { $processPath = $_.Path; $processPath -eq $target })
        Assert ($running.Count -eq 1) 'Exit-timeout recovery left no runnable app'
        Passed 'exit timeout relaunches runnable old app'
    }
    $journeySucceeded = $true
    Write-Host 'UPDATE BEHAVIOR PASSED'
} finally {
    Stop-FixtureApps
    foreach ($name in $original.Keys) { [Environment]::SetEnvironmentVariable($name, $original[$name], 'Process') }
    if ($Evidence) {
        New-Item -ItemType Directory -Force $Evidence | Out-Null
        @{ checks = @($checks.ToArray()); success = $journeySucceeded; revision = $env:GITHUB_SHA; fixtureSource = 'signed local folder with ephemeral job-only signing key'; cleanup = 'all fixture processes stopped' } | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $Evidence 'safe-updates.json')
    }
}
