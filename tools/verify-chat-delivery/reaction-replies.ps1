[void](Wait-For 'reaction transcript loaded' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
[void](Wait-For 'Claude-only reaction menu available' {
    @((Read-Shared "$settings/inbox-default.json" | ConvertFrom-Json).shells | Where-Object { $_.PSObject.Properties['ag'] -and $_.ag -eq 1 }).Count -eq 1
})
Press @(0x11, 0x4B) 'Ctrl+K: open theme picker'
foreach ($letter in 'themes'.ToCharArray()) { [ChatDeliveryDesktop]::Character($letter) }
Press @(0x0D) 'Enter: Themes'
foreach ($letter in 'amoled'.ToCharArray()) { [ChatDeliveryDesktop]::Character($letter) }
Press @(0x0D) 'Enter: AMOLED'
[void](Wait-For 'AMOLED saved' { (Read-Shared "$settings/theme-mode.txt").Trim() -eq 'amoled' })
Press @(0x1B) 'Esc: close Themes'
Bind-Transcript
Type-Composer $plan.text
[void](Wait-For 'remote draft synchronized' { (Fake-State).box -ceq $plan.text })
$viewport = Transcript-Viewport
Save @{left=$viewport.Left; top=$viewport.Top; right=$viewport.Right; bottom=$viewport.Bottom} "$caseDir/area.json"
$expected = [char]::ConvertFromUtf32(0x1f44d) + ' to: Same first words for this example for this example for this example for this' + [char]0x2026
$observation.deliveries = @()
foreach ($attempt in 1..2) {
    Shell-Run @('busy')
    [void](Scroll-Transcript 30000)
    $point = Wait-For 'original reply painted' {
        Shot 'reactions-before'
        $ErrorActionPreference = 'Continue'
        $located = & node "$PSScriptRoot/../chat-reactions-proof.mjs" $Evidence --locate 2> "$caseDir/locate-$attempt.log"
        if ($LASTEXITCODE -eq 0) { ($located -join "`n") | ConvertFrom-Json }
    }
    Doctor
    $actions.Add(@{case=$plan.name; input='right-click original reply'; attempt=$attempt; x=$point.x; y=$point.y})
    [ChatDeliveryDesktop]::RightClickOwnedTranscript($main, $app.Id, [IntPtr]$views[0].Current.NativeWindowHandle, $point.x, $point.y)
    $popup = Wait-For 'owned reaction menu visible' { $h = [ChatDeliveryDesktop]::Menu($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
    Shot "reactions-menu-$attempt"
    $actions.Add(@{case=$plan.name; input='click thumbs-up menu item'; attempt=$attempt})
    [ChatDeliveryDesktop]::PressOwnedMenu($main, $app.Id, $popup)
    [void](Wait-For 'one exact code-free reaction queued' { $queued = @((Fake-State).queue); $queued.Count -eq 1 -and $queued[0] -ceq $expected })
    $accepted = Wait-For 'desktop accepted this attempt without Not sent' {
        if (-not (Test-Path "$settings/chat-outbox.json")) { return $false }
        $saved = Read-Shared "$settings/chat-outbox.json" | ConvertFrom-Json
        $messages = @($saved.queues | ForEach-Object { $_.messages } | Where-Object { $_.t -ceq $expected -and $_.v1 -eq 1 -and $_.phase -ceq 'accepted' -and $_.wire_id -cnotin @($observation.deliveries | ForEach-Object { $_.wire_id }) })
        if ($messages.Count -eq 1) { $messages[0] }
    }
    Copy-Item "$settings/chat-outbox.json" "$caseDir/outbox-accepted-$attempt.json"
    if ([ChatDeliveryDesktop]::Text($composer) -cne $plan.text) { throw 'Reaction changed the composer draft' }
    Shot "reactions-accepted-$attempt"
    Shell-Run @('idle')
    [void](Wait-For 'agent consumed this reaction' { @((Fake-State).queue).Count -eq 0 })
    [void](Wait-For 'remote draft preserved' { (Fake-State).box -ceq $plan.text })
    $observation.deliveries += @{wire_id=$accepted.wire_id; text=$accepted.t; phase=$accepted.phase; draft=[ChatDeliveryDesktop]::Text($composer)}
    Shot "reactions-consumed-$attempt"
}
if ($observation.deliveries[0].wire_id -ceq $observation.deliveries[1].wire_id) { throw 'Repeated reactions reused a delivery identity' }
$offset = (Read-Shared "$settings/debug.log").Length
Press @(0x11, 0x4B) 'Ctrl+K: copy visible transcript'
$query = 'chat view select all'
foreach ($letter in $query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
[void](Wait-For 'select-all command ready' { (Read-Shared "$settings/debug.log").Substring($offset) -match ('\[palette\] ready chars=' + $query.Length + ' count=1 target=\d+') })
Press @(0x0D) 'Enter: select transcript'
[Windows.Forms.Clipboard]::Clear()
Press @(0x11, 0x43) 'Ctrl+C: copy actual transcript text'
$copied = Wait-For 'transcript copied' { $value = [Windows.Forms.Clipboard]::GetText(); if ($value.Contains('Same first words')) { $value } }
if ($copied.Contains('[mp:')) { throw 'Private reaction code reached visible transcript text' }
[IO.File]::WriteAllText("$caseDir/copied.txt", $copied)
Press @(0x1B) 'Esc: clear transcript selection'
[void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
$observation.composerText = [ChatDeliveryDesktop]::Text($composer)
Shot 'reactions-replies-done'
