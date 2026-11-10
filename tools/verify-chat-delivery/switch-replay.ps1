function Switch-Log { Read-Shared "$settings/debug.log" }
function Switch-Rows {
    foreach ($line in ((Read-Shared "$state/switch-host.jsonl") -split "`n")) {
        if ($line.Trim()) { $line | ConvertFrom-Json }
    }
}
function Rows-Of([string]$Stage, [string]$Chat) {
    @(Switch-Rows | Where-Object { $_.stage -eq $Stage -and $_.PSObject.Properties['chat'] -and $_.chat -eq $Chat })
}
function Live-Starts([string]$Text) { [regex]::Matches($Text, '\[chat-live\] start shell=(\d+) n=(\d+) f=(\d)') }
function Live-Count([string]$Text, [string]$Stage, [string]$Shell) {
    [regex]::Matches($Text, '\[chat-live\] ' + $Stage + ' shell=' + $Shell + ' n=').Count
}
$seeded = Wait-For 'stand-in history seeded' { if (Test-Path "$state/switch-seeded.json") { Get-Content "$state/switch-seeded.json" -Raw | ConvertFrom-Json } } 60
$lastA = [int]$seeded.a
$lastB = [int]$seeded.b
if ($lastA -lt 1000 -or $lastB -lt 1) { throw 'Seeded history is too short to prove replay' }
Bind-Transcript
$bounds = $views[0].Current.BoundingRectangle
$width = [int]$bounds.Width
$height = [int]$bounds.Height
[void](Wait-For 'chat A live subscription reached the reader' { (Rows-Of 'subscribed' 'a').Count -ge 1 } 60)
$startA = Wait-For 'chat A live stream start logged' {
    $found = Live-Starts (Switch-Log)
    if ($found.Count -gt 0) { $found[$found.Count - 1] }
} 30
$shellA = $startA.Groups[1].Value
[void](Wait-For 'chat A caught up to its last event' {
    $latest = @(Rows-Of 'pushed' 'a') | Select-Object -Last 1
    $null -ne $latest -and [int]$latest.next_after -eq $lastA
} 90)
$pagesA = 1 + @(Rows-Of 'pushed' 'a').Count
[void](Wait-For 'app received every replayed page of chat A' { (Live-Count (Switch-Log) 'page' $shellA) -ge $pagesA } 60)
Start-Sleep -Milliseconds 2500
Shot 'switch-a-before'
$observation.shellA = $shellA
$observation.lastA = $lastA
$observation.lastB = $lastB
$observation.initialPagesA = Live-Count (Switch-Log) 'page' $shellA
$observation.initialDrawsA = Live-Count (Switch-Log) 'draw' $shellA

$offsetB = (Switch-Log).Length
Press @(0x11, 0x32) 'Ctrl+2: select the second live chat'
$startB = Wait-For 'chat B live stream start logged' {
    foreach ($found in (Live-Starts (Switch-Log).Substring($offsetB))) { if ($found.Groups[1].Value -ne $shellA) { $found; break } }
} 30
$shellB = $startB.Groups[1].Value
[void](Wait-For 'chat B live subscription reached the reader' { (Rows-Of 'subscribed' 'b').Count -ge 1 } 30)
[void](Wait-For 'chat B page received' { (Live-Count (Switch-Log) 'page' $shellB) -ge 1 } 30)
Shot 'switch-b'
$observation.shellB = $shellB
Start-Sleep -Milliseconds 1500

$left = [int]$bounds.Left
$top = [int]$bounds.Top
$md5 = [Security.Cryptography.MD5]::Create()
function Sample-Transcript {
    $bitmap = [Drawing.Bitmap]::new($width, $height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($left, $top, 0, 0, $bitmap.Size)
        $data = $bitmap.LockBits([Drawing.Rectangle]::new(0, 0, $width, $height), [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $bytes = New-Object byte[] ($data.Stride * $height)
            [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
        } finally { $bitmap.UnlockBits($data) }
        [BitConverter]::ToString($md5.ComputeHash($bytes))
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
$returnOffset = (Switch-Log).Length
$returnMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
Press @(0x11, 0x31) 'Ctrl+1: switch back to the first live chat'
$seen = [Collections.Generic.HashSet[string]]::new()
$transitions = 0
$previous = ''
$samples = 0
$shotTaken = $false
$clock = [Diagnostics.Stopwatch]::StartNew()
while ($clock.ElapsedMilliseconds -lt 9000) {
    $hash = Sample-Transcript
    $samples++
    [void]$seen.Add($hash)
    if ($hash -ne $previous) { $transitions++; $previous = $hash }
    if (-not $shotTaken -and $clock.ElapsedMilliseconds -gt 2000) { Shot 'switch-a-replaying'; $shotTaken = $true }
    Start-Sleep -Milliseconds 30
}
$finalLog = Switch-Log
$returnLog = $finalLog.Substring($returnOffset)
$kept = @($returnLog -split "`n" | Where-Object { $_ -match '\[chat-live\]' })
[IO.File]::WriteAllText("$caseDir/switch-return-chat-live.log", (($kept -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
Shot 'switch-a-after'
$observation.returnMs = $returnMs
$observation.samples = $samples
$observation.transcriptStates = $seen.Count
$observation.transcriptTransitions = $transitions
$observation.returnPagesA = Live-Count $returnLog 'page' $shellA
$observation.returnDrawsA = Live-Count $returnLog 'draw' $shellA
$observation.returnStarts = @([regex]::Matches($returnLog, '\[chat-live\] start shell=' + $shellA + ' n=(\d+)') | ForEach-Object { [int]$_.Groups[1].Value })
$observation.aStreamEndedOnSwitch = (Live-Count $finalLog 'read-ended' $shellA) -ge 1
Save @{returnMs=$returnMs; shellA=$shellA; shellB=$shellB; lastA=$lastA; lastB=$lastB} "$caseDir/switch-replay.json"
