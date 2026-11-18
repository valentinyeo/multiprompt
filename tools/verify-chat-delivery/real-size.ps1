$observation.realSizePassed = $false
$observation.realSizeChecks = @()
[void](Wait-For 'production live subscription and seeded long archive' { (Read-Shared "$state/working-host.jsonl") -match '"stage": "idle-history-ready"' } 60)
$manifest = Get-Content "$caseDir/fixture-manifest.json" -Raw | ConvertFrom-Json
if ($manifest.sessions -ne 64 -or $manifest.messagesPerLongChat -ne 2400 -or $manifest.longChats -ne 8) { throw 'Real-size profile counts differ from the documented fixture' }
function Copy-RealSize([string]$Stage, [string]$Expected) {
    $copied = Wait-For 'expected text copied from the native transcript' {
        $offset = (Read-Shared "$settings/debug.log").Length
        Press @(0x11, 0x4B) 'Ctrl+K: select all transcript text'
        [void](Wait-For 'select-all palette opened' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
        $query = 'chat view select all'
        $typed = ''
        foreach ($letter in $query.ToCharArray()) {
            $letterOffset = (Read-Shared "$settings/debug.log").Length
            $typed += $letter
            [ChatDeliveryDesktop]::Character($letter)
            [void](Wait-For 'palette character handled' { (Read-Shared "$settings/debug.log").Substring($letterOffset) -match ('\[palette\] ready chars=' + $typed.Length + ' count=') })
        }
        [void](Wait-For 'select-all palette row ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match ('\[palette\] ready chars=' + $query.Length + ' count=\d+ target=6364(?:\s|$)') })
        Press @(0x0D) 'Enter: select all transcript text'
        [Windows.Forms.Clipboard]::Clear()
        Press @(0x11, 0x43) 'Ctrl+C: copy the rendered transcript'
        $text = [Windows.Forms.Clipboard]::GetText()
        Press @(0x1B) 'Esc: clear transcript selection'
        [void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
        if ($text.Contains($Expected)) { $text }
    } 30
    [IO.File]::WriteAllText("$caseDir/$Stage-copied.txt", $copied)
    Shot "real-size-$Stage"
    return $copied
}
[void](Copy-RealSize 'loaded' 'Synthetic chat 00 answer 1199')
Shot 'before'
$observation.realSizeChecks += @{name='long-server-chat-loaded'; messages=2400; source='production host archive and native transcript copy'}
Type-Composer $plan.text
Shot 'action'
Press @(0x0D) 'Enter: send in the seeded server chat' $true
[void](Wait-For 'production message dispatch accepted the typed message' { (Read-Shared "$state/working-host.jsonl") -match '"stage": "accepted"' } 30)
[IO.File]::WriteAllText("$state/working-reply", '')
[void](Wait-For 'production text.delta reached the subscription' { (Read-Shared "$state/working-host.jsonl") -match '"stage": "text.delta"' } 30)
$partial = Copy-RealSize 'streaming' 'The hosted stand-in reply is visible.'
if ($partial.Contains('Streaming segment 7.')) { throw 'Stream completed before the partial-reply capture' }
[IO.File]::WriteAllText("$state/real-size-continue", '')
[void](Wait-For 'all eight deltas and the final reply were emitted' { (Read-Shared "$state/working-host.jsonl") -match '"stage": "real-size-complete"' } 30)
[void](Copy-RealSize 'completed' 'Streaming segment 7.')
$observation.realSizeChecks += @{name='real-send-stream-and-complete'; deltas=8; partial='streaming-copied.txt'; completed='completed-copied.txt'}
$observation.realSizePassed = $true
