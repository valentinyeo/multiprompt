param(
    [Parameter(Mandatory=$true, Position=0)][ValidatePattern('^[a-z][a-z0-9-]*$')][string]$Feature,
    [Parameter(Position=1)][ValidatePattern('^[a-z][a-z0-9-]*$')][string]$Journey,
    [Parameter(Mandatory=$true)][string]$Exe,
    [Parameter(Mandatory=$true)][string]$ExpectedVersion,
    [Parameter(Mandatory=$true)][string]$ExpectedHash,
    [Parameter(Mandatory=$true)][string]$Evidence
)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Use verify.yml on GitHub Windows' }
$map = Join-Path $PSScriptRoot "features/$Feature.md"
$text = Get-Content -LiteralPath $map -Raw
if ($text -match '(?m)^Journeys: (.+)\r?$') {
    $journeys = $Matches[1].Trim() -split ', '
    if (-not $Journey) { $Journey = $journeys[0] }
    if ($Journey -notin $journeys) { throw "Journey $Journey is not mapped under $Feature" }
} else {
    if ($Journey -and $Journey -ne $Feature) { throw 'Legacy maps accept only their own journey' }
    $Journey = $Feature
}
$Evidence = [IO.Path]::GetFullPath($Evidence)
New-Item -ItemType Directory -Force $Evidence | Out-Null
if (Test-Path "$Evidence/journey.json") { throw 'Use a fresh evidence folder for each journey' }
$record = [ordered]@{ feature=$Feature; journey=$Journey; revision=(git rev-parse HEAD).Trim(); status='failed'; error=$null }
$video = $null
$windows = $null
$frameRate = if ($env:CHAT_POSITION_REPLAY -eq '1') { 30 } else { 8 }
try {
    if ($env:CHAT_POSITION_REPLAY -eq '1') {
        Add-Type -Path (Join-Path $PSScriptRoot '../../../tools/verify-chat-delivery/layout-capture.cs')
        [LayoutCapture]::Display()
    }
    if ($Feature -ne 'server-chat') {
        $start = [Diagnostics.ProcessStartInfo]::new('ffmpeg', "-y -f gdigrab -framerate $frameRate -i desktop -an -c:v libx264 -preset ultrafast -pix_fmt yuv420p `"$Evidence/journey.mp4`"")
        $start.UseShellExecute = $false
        $start.RedirectStandardInput = $true
        $start.CreateNoWindow = $true
        $video = [Diagnostics.Process]::Start($start)
    }
    if ($env:CHAT_POSITION_REPLAY -eq '1') {
        Add-Type -Path (Join-Path $PSScriptRoot '../../../tools/verify-chat-delivery/native-console-recorder.cs') -ReferencedAssemblies System.Drawing, System.Windows.Forms
        $windows = [NativeConsoleRecorder]::new("$Evidence/windows")
    }
    & powershell -NoProfile -File "$PSScriptRoot/control.ps1" -Feature $Journey -Exe $Exe -ExpectedVersion $ExpectedVersion -ExpectedHash $ExpectedHash -Evidence $Evidence
    if ($LASTEXITCODE -ne 0) { throw "Journey exited $LASTEXITCODE; inspect result.json" }
    $result = Get-Content "$Evidence/result.json" -Raw | ConvertFrom-Json
    if ($result.status -ne 'passed') { throw 'Journey did not pass' }
    if ($Feature -eq 'chat-delivery') {
        $cleanup = Get-Content "$Evidence/cleanup.json" -Raw | ConvertFrom-Json
        if (-not $cleanup.scratch_removed -or $cleanup.remaining_owned_processes -ne 0) { throw 'Owned cleanup failed' }
    } elseif ($Feature -eq 'server-chat') {
        if ($result.cleanup.activeAfterStop -ne 0 -or -not $result.keyRemoved -or $result.videoExit -ne 0) { throw 'Owned server cleanup or recording failed' }
    } else {
        $tree = Get-Content "$Evidence/process-tree.json" -Raw | ConvertFrom-Json
        if (-not $result.scratchRemoved -or $tree.activeAfterStop -ne 0) { throw 'Owned cleanup failed' }
    }
    $required = @('before.png', 'action.png', 'after.png', 'actions.json', 'doctor.json')
    if ($Feature -eq 'chat-delivery') { $required += @('steady-live/debug.log', 'steady-live/host') }
    elseif ($Feature -eq 'server-chat') { $required = @('open.png', 'send.png', 'clear.png', 'after-clear.png', 'actions.json', 'doctor.json', 'journey.mp4', 'sshd.log', 'key-acl.json') }
    else { $required += 'data' }
    foreach ($name in $required) {
        if (-not (Test-Path "$Evidence/$name")) { throw "Evidence missing after cleanup: $name" }
    }
    $record.status = 'passed'
} catch {
    $record.error = $_.Exception.Message
} finally {
    if ($env:CHAT_POSITION_REPLAY -eq '1') {
        try {
            if ($null -eq $windows) { throw 'Native window observer did not start' }
            $windows.Dispose()
            & node (Join-Path $PSScriptRoot '../../../tools/verify-chat-delivery/native-console.test.cjs') $Evidence
            if ($LASTEXITCODE -ne 0) {
                $native = Get-Content "$Evidence/native-console.json" -Raw | ConvertFrom-Json
                if ($native.status -eq 'failed') { throw 'Native console appeared over visible Chat View; inspect native-console.json' }
                throw "Native window observation incomplete: $($native.error)"
            }
        } catch { $record.status='failed'; if (-not $record.error) { $record.error=$_.Exception.Message } }
    }
    if ($null -ne $video) {
        try {
            if (-not $video.HasExited) { $video.StandardInput.WriteLine('q'); $video.StandardInput.Close() }
            if (-not $video.WaitForExit(15000)) { $video.Kill(); $video.WaitForExit(); throw 'Recorder did not stop' }
            if ($video.ExitCode -ne 0 -or -not (Test-Path "$Evidence/journey.mp4")) { throw 'Recorder failed' }
            $probe = & ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height -of json "$Evidence/journey.mp4"
            if ($LASTEXITCODE -ne 0 -or @((($probe -join "`n") | ConvertFrom-Json).streams).Count -ne 1) { throw 'Video is not readable' }
            $probe | Set-Content -Encoding UTF8 "$Evidence/video.json"
        } catch { $record.status='failed'; $record.error=$_.Exception.Message }
        finally { $video.Dispose() }
    }
    if ($env:CHAT_POSITION_REPLAY -eq '1' -and (Test-Path "$Evidence/result.json")) {
        $observed = Get-Content "$Evidence/result.json" -Raw | ConvertFrom-Json
        $observed | Add-Member -Force NoteProperty nativeConsole $(if (Test-Path "$Evidence/native-console.json") { Get-Content "$Evidence/native-console.json" -Raw | ConvertFrom-Json } else { @{status='incomplete'; error=$record.error} })
        if ($observed.nativeConsole.status -eq 'incomplete') { $observed | Add-Member -Force NoteProperty failureKind 'infrastructure' }
        if ($record.status -ne 'passed') {
            $observed.status = 'failed'
            $observed | Add-Member -Force NoteProperty error $record.error
        }
        $observed | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 "$Evidence/result.json"
    }
    $record | ConvertTo-Json | Set-Content -Encoding UTF8 "$Evidence/journey.json"
}
if ($record.status -ne 'passed') { throw $record.error }
Write-Output "VERIFIED $Feature/$Journey; evidence retained at $Evidence"
