param([Parameter(Mandatory=$true)][string]$Exe, [Parameter(Mandatory=$true)][string]$Notes, [Parameter(Mandatory=$true)][string]$Evidence)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:OS -ne 'Windows_NT') { throw 'Release card proof runs only on GitHub Windows' }
New-Item -ItemType Directory -Force $Evidence | Out-Null
$document = Get-Content $Notes -Raw | ConvertFrom-Json
$changes = @($document.releases | Where-Object { $_.version -eq $document.version } | ForEach-Object { $_.changes })
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
    Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class ReleaseCardProof { [StructLayout(LayoutKind.Sequential)] public struct Rect { public int L,T,R,B; } [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r); [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags); }'
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
