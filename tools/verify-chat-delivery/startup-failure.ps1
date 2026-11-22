$message = 'Could not start chat: working folder unavailable.'
[void](Wait-For 'startup failure persisted after subscription' {
    (Read-Shared "$state/startup-failure.jsonl").Contains('host-stopped')
} 30)
$observation.noTranscript = -not (Test-Path "$profile/home/.claude/projects")
Start-Sleep -Seconds 2
[void](Wait-For 'startup failure reaches the native transcript' {
    [Windows.Forms.Clipboard]::SetText('startup failure clipboard sentinel')
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x4B) 'Ctrl+K: select Chat View'
    [void](Wait-For 'palette ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[palette\] ready chars=0 count=\d+ target=\d+' })
    $query = 'chat view select all'
    foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
    [void](Wait-For 'select-all command ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match ('\[palette\] ready chars=' + $query.Length + ' count=1 target=\d+') })
    Press @(0x0D) 'Enter: select Chat View'
    Press @(0x11, 0x43) 'Ctrl+C: copy Chat View'
    Start-Sleep -Milliseconds 300
    $script:startupCopied = [Windows.Forms.Clipboard]::GetText()
    Press @(0x1B) 'Esc: clear selection'
    $script:startupCopied.Contains($message)
} 30)
Start-Sleep -Seconds 2
Shot 'startup-failure-visible'
$observation.copied = $script:startupCopied
$observation.endMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
[IO.File]::WriteAllText("$caseDir/copied.txt", $observation.copied)
[void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
