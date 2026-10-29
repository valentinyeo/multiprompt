[void](Wait-For 'initial transcript read' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
Bind-Transcript
$observation.rounds = [Collections.Generic.List[object]]::new()
$frames = [Collections.Generic.List[string]]::new()
$longDelivery = $env:CHAT_LONG_PROOF -eq '1'
$crashStress = $env:CHAT_CRASH_PROOF -eq '1'
$releasedLongDelivery = $longDelivery -and $env:RELEASE_TAG -and -not $crashStress
$roundCount = if ($crashStress) { 30 } elseif ($releasedLongDelivery) { 31 } else { 10 }
$firstReplyMs = 0L
$observation.longDelivery = $longDelivery
$observation.crashStress = $crashStress
if ($longDelivery) {
    $retained = Wait-For 'older history fully retained before live refresh' {
        foreach ($cache in @(Get-ChildItem "$settings/chatcache/*.jsonl" -ErrorAction SilentlyContinue)) {
            $header = Get-Content -LiteralPath $cache.FullName -TotalCount 1 | ConvertFrom-Json
            if ($header.sid -eq $sid -and $header.start -eq 0 -and $header.offset -eq (Get-Item $transcript).Length) { return $header }
        }
    }
    Save $retained "$caseDir/retained-header.json"
}
$readerStart = @(Get-ChildItem "$state/reader-subscriptions/*.json" -ErrorAction SilentlyContinue).Count
$observation.startupReaderSubscriptions = $readerStart
foreach ($round in 1..$roundCount) {
    if ($longDelivery -and $round -gt 1) { Shell-Run @('refresh-live-tail') }
    Shell-Input 'busy'
    $messages = @(1..3 | ForEach-Object { "Live request $round part $_" })
    foreach ($message in $messages) {
        Type-Composer $message
        Press @(0x0D) 'Enter: send busy message' $true
        [void](Wait-For 'message reaches busy session queue' { @((Fake-State).queue) -contains $message })
    }
    [void](Wait-For 'all three sent messages shown queued' {
        $shown = [string](Queue-View)
        @($messages | Where-Object { -not $shown.Contains('queued:' + $_) }).Count -eq 0
    })
    $queuedFrame = 'live-queued-' + $round.ToString('00')
    Shot $queuedFrame
    $frames.Add($queuedFrame)
    if ($releasedLongDelivery -and $round -gt 1) {
        $due = $firstReplyMs + ($round - 1) * 60000
        while ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() -lt $due) {
            Doctor $true
            Start-Sleep -Milliseconds 500
        }
    }
    Shell-Run @('live-turn', [string]$round)
    if ($firstReplyMs -eq 0) { $firstReplyMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }
    $answer = "Live answer $round"
    [void](Wait-For 'fresh reply rendered without changing views' {
        $paletteStart = (Read-Shared "$settings/debug.log").Length
        Press @(0x11, 0x4B) 'Ctrl+K: select live conversation'
        [void](Wait-For 'live palette ready' { (Read-Shared "$settings/debug.log").Substring($paletteStart) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
        $query = 'chat view select all'
        foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
        [void](Wait-For 'live select-all command ready' { (Read-Shared "$settings/debug.log").Substring($paletteStart) -match ('\[palette\] ready chars=' + $query.Length + ' count=\d+ target=6364(?:\s|$)') })
        Press @(0x0D) 'Enter: select live conversation'
        Press @(0x11, 0x43) 'Ctrl+C: copy rendered live conversation'
        $script:liveCopied = [Windows.Forms.Clipboard]::GetText()
        $script:liveCopied.Contains($answer) -and @($messages | Where-Object { -not $script:liveCopied.Contains($_) }).Count -eq 0
    } 2)
    $shownMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    [IO.File]::WriteAllText("$caseDir/round-$round-copied.txt", $script:liveCopied)
    Press @(0x1B) 'Esc: clear live selection'
    [void](Wait-For 'accepted messages no longer pending' {
        $shown = [string](Queue-View)
        @($messages | Where-Object { -not $shown.Contains('sent:' + $_) }).Count -eq 0
    } 2)
    $outbox = if (Test-Path "$settings/chat-outbox.json") { Read-Shared "$settings/chat-outbox.json" } else { '{"queues":[]}' }
    [IO.File]::WriteAllText("$caseDir/round-$round-outbox.json", $outbox)
    $frameName = 'live-round-' + $round.ToString('00')
    Shot $frameName
    $frames.Add($frameName)
    $observation.rounds.Add(@{round=$round; messages=$messages; answer=$answer; shownMs=$shownMs})
}
$observation.sustainedMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - $firstReplyMs
$readers = @(Get-ChildItem "$state/reader-subscriptions/*.json" -ErrorAction SilentlyContinue)
if ($readerStart -lt 1 -or $readers.Count -ne $readerStart) { throw "Background delivery replaced the visible reader: $($readers.Count - $readerStart) new subscriptions" }
$observation.readerSubscriptions = $readers.Count
if ($longDelivery) {
    Shot 'live-chat-after'
    Press @(0x12, 0x43) 'Alt+C: capture completed shell'
    Shot 'live-shell-after'
    Press @(0x12, 0x43) 'Alt+C: return after completed proof'
    $composer = Wait-For 'composer restored after completed proof' { $h = [ChatDeliveryDesktop]::Composer($main); if ($h -ne [IntPtr]::Zero) { $h } }
    [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
    foreach ($phase in @('before', 'after')) {
        $shellImage = [Drawing.Image]::FromFile("$Evidence/" + $(if ($phase -eq 'before') { 'live-delivery-before.png' } else { 'live-shell-after.png' }))
        $chatImage = [Drawing.Image]::FromFile("$Evidence/" + $(if ($phase -eq 'before') { 'live-queued-01.png' } else { 'live-chat-after.png' }))
        $pair = [Drawing.Bitmap]::new($shellImage.Width + $chatImage.Width, [Math]::Max($shellImage.Height, $chatImage.Height))
        $graphics = [Drawing.Graphics]::FromImage($pair)
        try {
            $graphics.DrawImage($shellImage, 0, 0)
            $graphics.DrawImage($chatImage, $shellImage.Width, 0)
            $pair.Save("$Evidence/live-side-by-side-$phase.png", [Drawing.Imaging.ImageFormat]::Png)
        } finally { $graphics.Dispose(); $pair.Dispose(); $shellImage.Dispose(); $chatImage.Dispose() }
    }
}
Add-Type -AssemblyName PresentationCore, WindowsBase
$encoder = [System.Windows.Media.Imaging.GifBitmapEncoder]::new()
foreach ($name in $frames) {
    $image = [System.Windows.Media.Imaging.BitmapFrame]::Create([Uri]::new("$Evidence/$name.png"), [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat, [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
    $metadata = [System.Windows.Media.Imaging.BitmapMetadata]::new('gif')
    $metadata.SetQuery('/grctlext/Delay', [UInt16]100)
    $metadata.SetQuery('/grctlext/Disposal', [byte]1)
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($image, $null, $metadata, $null))
}
$stream = [IO.File]::Create("$Evidence/live-delivery.gif")
try { $encoder.Save($stream) } finally { $stream.Dispose() }
$observation.recordedFrames = $frames.ToArray()
