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
                Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class UpdateProof { [StructLayout(LayoutKind.Sequential)] public struct Rect { public int L,T,R,B; } [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r); [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags); [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l); }'
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
                $deadline = [DateTime]::UtcNow.AddSeconds(30)
                do {
                    $cardLog = if (Test-Path $log) { -join (Get-Content $log -Raw) } else { '' }
                    if ($cardLog -match '\[update\] card remaining=and 1 more') { break }
                    Assert (-not $cardProcess.HasExited) 'Card fixture exited before painting notes'
                    if ([DateTime]::UtcNow -gt $deadline) { throw 'Update card did not paint release notes' }
                    Start-Sleep -Milliseconds 100
                } while ($true)
                Assert ($cardLog -match '\[update\] card view=collapsed n=3 first=Typing feels faster\.') 'Card did not show three newest notes'
                $expectedNotes = @('Typing feels faster.', 'Chats keep your place.', 'Middle change.')
                $observedNotes = @()
                for ($i = 0; $i -lt $expectedNotes.Count; $i++) {
                    $note = [regex]::Match($cardLog, '\[update\] card note ' + $i + '=([^\r\n]*)')
                    Assert ($note.Success -and $note.Groups[1].Value -ceq $expectedNotes[$i]) 'Card note order or version range is wrong'
                    $observedNotes += $note.Groups[1].Value
                }
                Assert ($cardLog -notmatch '\[update\] card note \d+=.*(IGSH-123|src/main|Not offered yet|Already installed|Older change)') 'Card leaked an internal, out-of-range or hidden note'
                Assert ($cardLog -notmatch 'latest improvements') 'Card showed generic filler text'
                $cardProcess.Refresh()
                $rectangle = New-Object UpdateProof+Rect
                Assert ([UpdateProof]::GetWindowRect($cardProcess.MainWindowHandle, [ref]$rectangle)) 'Update card window unavailable'
                $bitmap = New-Object Drawing.Bitmap(($rectangle.R - $rectangle.L), ($rectangle.B - $rectangle.T))
                $graphics = [Drawing.Graphics]::FromImage($bitmap)
                $dc = $graphics.GetHdc()
                try { Assert ([UpdateProof]::PrintWindow($cardProcess.MainWindowHandle, $dc, 2)) 'Update card screenshot failed' } finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
                try { $bitmap.Save((Join-Path $Evidence 'update-card-notes.png')) } finally { $bitmap.Dispose() }
                $observedNotes | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $Evidence 'update-card-notes.json')
                Passed 'update card shows aggregated plain notes'
                $moreRows = [regex]::Matches($cardLog, '\[update\] more row=(\d+),(\d+)')
                Assert ($moreRows.Count -gt 0) 'More row coordinates were not painted'
                $moreRow = $moreRows[$moreRows.Count - 1]
                $moreClick = [IntPtr](([int]$moreRow.Groups[2].Value -shl 16) -bor [int]$moreRow.Groups[1].Value)
                Assert ([UpdateProof]::PostMessage($cardProcess.MainWindowHandle, 0x201, [IntPtr]1, $moreClick)) 'More row press failed'
                Assert ([UpdateProof]::PostMessage($cardProcess.MainWindowHandle, 0x202, [IntPtr]0, $moreClick)) 'More row release failed'
                $deadline = [DateTime]::UtcNow.AddSeconds(15)
                do {
                    $cardLog = -join (Get-Content $log -Raw)
                    if ($cardLog -match '\[update\] card view=expanded n=4 first=Typing feels faster\.') { break }
                    Assert (-not $cardProcess.HasExited) 'Card fixture exited before opening the full list'
                    if ([DateTime]::UtcNow -gt $deadline) { throw 'Update card did not open the full list on click' }
                    Start-Sleep -Milliseconds 100
                } while ($true)
                $expandedLog = $cardLog.Substring($cardLog.IndexOf('card view=expanded'))
                $expectedAll = @('Typing feels faster.', 'Chats keep your place.', 'Middle change.', 'Older change.')
                $observedAll = @()
                for ($i = 0; $i -lt $expectedAll.Count; $i++) {
                    $note = [regex]::Match($expandedLog, '\[update\] card note ' + $i + '=([^\r\n]*)')
                    Assert ($note.Success -and $note.Groups[1].Value -ceq $expectedAll[$i]) 'Full list order or skipped versions are wrong'
                    $observedAll += $note.Groups[1].Value
                }
                Assert ($expandedLog -notmatch '\[update\] card note 4=') 'Full list shows more rows than the release has'
                Assert ($cardLog -notmatch 'latest improvements') 'Full list showed generic filler text'
                Start-Sleep -Milliseconds 300
                $cardProcess.Refresh()
                $rectangle = New-Object UpdateProof+Rect
                Assert ([UpdateProof]::GetWindowRect($cardProcess.MainWindowHandle, [ref]$rectangle)) 'Update card window unavailable'
                $bitmap = New-Object Drawing.Bitmap(($rectangle.R - $rectangle.L), ($rectangle.B - $rectangle.T))
                $graphics = [Drawing.Graphics]::FromImage($bitmap)
                $dc = $graphics.GetHdc()
                try { Assert ([UpdateProof]::PrintWindow($cardProcess.MainWindowHandle, $dc, 2)) 'Expanded update card screenshot failed' } finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
                try { $bitmap.Save((Join-Path $Evidence 'update-card-expanded.png')) } finally { $bitmap.Dispose() }
                $observedAll | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $Evidence 'update-card-expanded.json')
                Passed 'update card opens the full list on click'
                Select-Release 'v9.11.0'
                Assert (Save-Update $cardExe '0.0.0' 'x64') 'Quiet release was not staged'
                $deadline = [DateTime]::UtcNow.AddSeconds(30)
                do {
                    $cardLog = -join (Get-Content $log -Raw)
                    if ($cardLog -match '\[update\] quiet release waiting 9\.11\.0') { break }
                    Assert (-not $cardProcess.HasExited) 'Quiet update interrupted the app'
                    if ([DateTime]::UtcNow -gt $deadline) { throw 'Quiet release was not processed' }
                    Start-Sleep -Milliseconds 100
                } while ($true)
                $cardProcess.Refresh()
                Assert ($cardProcess.Responding) 'Quiet update blocked the app'
                Assert ([UpdateProof]::GetWindowRect($cardProcess.MainWindowHandle, [ref]$rectangle)) 'Quiet update window unavailable'
                $bitmap = New-Object Drawing.Bitmap(($rectangle.R - $rectangle.L), ($rectangle.B - $rectangle.T))
                $graphics = [Drawing.Graphics]::FromImage($bitmap)
                $dc = $graphics.GetHdc()
                try { Assert ([UpdateProof]::PrintWindow($cardProcess.MainWindowHandle, $dc, 2)) 'Quiet update screenshot failed' } finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
                try { $bitmap.Save((Join-Path $Evidence 'update-card-quiet.png')) } finally { $bitmap.Dispose() }
                Passed 'maintenance release waits without an update card'
                Select-Release 'v9.10.0'
                Assert (Save-Update $cardExe '0.0.0' 'x64') 'Real product notes were not restored'
                $deadline = [DateTime]::UtcNow.AddSeconds(30)
                do {
                    $cardLog = -join (Get-Content $log -Raw)
                    $afterQuiet = $cardLog.Substring($cardLog.IndexOf('[update] quiet release waiting'))
                    if ($afterQuiet -match '\[update\] card view=collapsed n=3') { break }
                    if ([DateTime]::UtcNow -gt $deadline) { throw 'Real product notes did not show again' }
                    Start-Sleep -Milliseconds 100
                } while ($true)
                $versionMatch = [regex]::Match([Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Verifier)), 'MPVERSION=(\d+\.\d+\.\d+);')
                Assert $versionMatch.Success 'Native verifier version marker missing'
                $oldVersion = $versionMatch.Groups[1].Value
                $newVersion = '9.99.999'
                Assert ($NativeUpdate -and (Test-Path $NativeUpdate)) 'Native update build was not supplied'
                Assert ([Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($NativeUpdate)).Contains("MPVERSION=$newVersion;")) 'Native update build has the wrong version'
                Remove-Item -LiteralPath "$cardExe.update/ready.txt" -Force
                Move-Item -LiteralPath $cardExe -Destination "$Root/card.running.exe"
                Copy-Item -LiteralPath $NativeUpdate -Destination $cardExe
                $deadline = [DateTime]::UtcNow.AddSeconds(15)
                do {
                    $cardLog = -join (Get-Content $log -Raw)
                    if ($cardLog.Contains('update-card: new version ready ' + $newVersion)) { break }
                    if ([DateTime]::UtcNow -gt $deadline) { throw 'Installed update was not offered on the card' }
                    Start-Sleep -Milliseconds 100
                } while ($true)
                Start-Sleep -Milliseconds 300
                $buttons = [regex]::Matches((Get-Content $log -Raw), '\[update\] restart button=(\d+),(\d+)')
                Assert ($buttons.Count -gt 0) 'Restart button coordinates were not painted'
                $button = $buttons[$buttons.Count - 1]
                $click = [IntPtr](([int]$button.Groups[2].Value -shl 16) -bor [int]$button.Groups[1].Value)
                $inboxPath = Join-Path $env:APPDATA 'ZigShell/inbox-default.json'
                Remove-Item -LiteralPath $inboxPath -Force -ErrorAction SilentlyContinue
                $restartTimer = [Diagnostics.Stopwatch]::StartNew()
                Assert ([UpdateProof]::PostMessage($cardProcess.MainWindowHandle, 0x201, [IntPtr]1, $click)) 'Restart button press failed'
                Assert ([UpdateProof]::PostMessage($cardProcess.MainWindowHandle, 0x202, [IntPtr]0, $click)) 'Restart button release failed'
                Assert ($cardProcess.WaitForExit(15000)) 'Restart card did not close the old app'
                $deadline = [DateTime]::UtcNow.AddSeconds(20)
                do {
                    $restored = @(Get-Process | Where-Object {
                        try { $processPath = $_.Path; $processPath -ieq $cardExe -and $_.MainWindowTitle.Contains($newVersion) } catch { $false }
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
                    if (Test-Path $proofFile) { Copy-Item -LiteralPath $proofFile -Destination $Evidence -Force }
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
