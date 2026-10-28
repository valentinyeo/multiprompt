[void](Wait-For 'initial transcript read' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
Bind-Transcript
$observation.rounds = [Collections.Generic.List[object]]::new()
$frames = [Collections.Generic.List[string]]::new()
foreach ($round in 1..10) {
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
    Shell-Run @('live-turn', [string]$round)
    $answer = "Live answer $round"
    [void](Wait-For 'fresh reply rendered without changing views' {
        $paletteStart = (Read-Shared "$settings/debug.log").Length
        Press @(0x11, 0x4B) 'Ctrl+K: select live conversation'
        [void](Wait-For 'live palette ready' { (Read-Shared "$settings/debug.log").Substring($paletteStart) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
        $query = 'chat view select all'
        foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
        [void](Wait-For 'live select-all command ready' { (Read-Shared "$settings/debug.log").Substring($paletteStart) -match ('\[palette\] ready chars=' + $query.Length + ' count=1 target=\d+') })
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
        @($messages | Where-Object { $shown.Contains($_) }).Count -eq 0
    } 2)
    $outbox = if (Test-Path "$settings/chat-outbox.json") { Read-Shared "$settings/chat-outbox.json" } else { '{"queues":[]}' }
    [IO.File]::WriteAllText("$caseDir/round-$round-outbox.json", $outbox)
    $frameName = 'live-round-' + $round.ToString('00')
    Shot $frameName
    $frames.Add($frameName)
    $observation.rounds.Add(@{round=$round; messages=$messages; answer=$answer; shownMs=$shownMs})
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
