[void](Wait-For 'saved history loaded before restart' { (Read-Shared "$settings/debug.log") -match '\[chat\] transcript load shell=\d+ ok' })
Bind-Transcript
[void](Wait-For 'app saved a chat launch snapshot' {
    if (-not (Test-Path "$settings/session.json.launch.json")) { return $false }
    $snapshot = Read-Shared "$settings/session.json.launch.json" | ConvertFrom-Json
    $snapshot.chat -and @($snapshot.blocks).Count -gt 0
})
Shot 'instant-warm'
if (-not $app.CloseMainWindow() -or -not $app.WaitForExit(10000)) { throw 'Owned app did not close for cold restart' }
$stopped = $job.Stop()
Save $stopped "$caseDir/restart-process-tree.json"
if ($stopped.ActiveProcesses -ne 0) { throw 'Restart left owned processes running' }
$job.Dispose()
Copy-Item "$settings/session.json.launch.json" "$caseDir/saved-launch.json"
Copy-Item "$settings/debug.log" "$caseDir/warm-debug.log"
[IO.File]::WriteAllText("$settings/debug.log", '')
[IO.File]::WriteAllText("$state/connection-held", 'held')
$job = [VerifyJob]::new()
$restartStart = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$app = $job.Start($Exe, $profile, "$caseDir/restart-stdout.log", "$caseDir/restart-stderr.log", '--no-window-restore')
$main = Wait-For 'cold-start owned window' { $h = [ChatDeliveryDesktop]::Window($app.Id); if ($h -ne [IntPtr]::Zero) { $h } }
$paint = Wait-For 'cached history first paint while connection remains held' {
    $log = Read-Shared "$settings/debug.log"
    if ($log -match 'launch first-paint ms=(\d+)') { return [int]$Matches[1] + 1 }
} 5
$paintMs = $paint - 1
if ($paintMs -ge 1000) { throw "Saved chat first paint exceeded one second: $paintMs ms" }
Shot 'instant-first-paint'
Save @{startedMs=$restartStart; capturedMs=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); firstPaintMs=$paintMs} "$caseDir/startup-timing.json"
$composer = Wait-For 'cached native composer before connection' { $h = [ChatDeliveryDesktop]::Composer($main); if ($h -ne [IntPtr]::Zero -and [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $h)) { $h } }
Bind-Transcript
Press @(0x11, 0x4B) 'Ctrl+K: select saved conversation while offline'
foreach ($letter in 'chat view select all'.ToCharArray()) { [ChatDeliveryDesktop]::Character($letter) }
Press @(0x0D) 'Enter: select saved conversation'
Press @(0x11, 0x43) 'Ctrl+C: copy saved conversation'
$copied = [Windows.Forms.Clipboard]::GetText()
[IO.File]::WriteAllText("$caseDir/offline-copied.txt", $copied)
if (-not $copied.Contains('The fake session is ready.')) { throw 'Saved history not rendered before connect' }
Press @(0x1B) 'Esc: clear saved conversation selection'
[void][ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer)
$messages = @('preconnect first', 'preconnect second')
foreach ($message in $messages) {
    Type-Composer $message
    Press @(0x0D) 'Enter: buffer message before connection' $true
    [void](Wait-For 'composer cleared after durable offline send' { [ChatDeliveryDesktop]::Text($composer) -ceq '' } 2)
}
[void](Wait-For 'both offline sends persisted in order' {
    $saved = Read-Shared "$settings/chat-outbox.json" | ConvertFrom-Json
    $pending = @($saved.queues | ForEach-Object { $_.messages } | Where-Object { $_.t -in $messages })
    $pending.Count -eq 2 -and $pending[0].t -ceq $messages[0] -and $pending[1].t -ceq $messages[1]
} 3)
Copy-Item "$settings/chat-outbox.json" "$caseDir/offline-outbox.json"
[void](Wait-For 'real transport attempted while connection held' { Test-Path "$state/connection-waits.jsonl" } 5)
Shot 'instant-buffered'
$store = "$profile/home/.local/state/multiprompt/shared-messages/store.sqlite3"
$before = & $env:MP_VERIFY_PYTHON "$PSScriptRoot/instant-store.py" $store
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect pre-connect store' }
[IO.File]::WriteAllText("$caseDir/store-before.json", ($before -join "`n"))
$releaseMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
Remove-Item "$state/connection-held"
[void](Wait-For 'both messages arrive once at the host store' {
    $rows = & $env:MP_VERIFY_PYTHON "$PSScriptRoot/instant-store.py" $store
    if ($LASTEXITCODE -ne 0) { return $false }
    $received = @((($rows -join "`n") | ConvertFrom-Json) | Where-Object { $_.text -in $messages })
    if ($received.Count -eq 2) { return $true }
} 60)
$rows = & $env:MP_VERIFY_PYTHON "$PSScriptRoot/instant-store.py" $store
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect delivered store' }
[IO.File]::WriteAllText("$caseDir/store-after.json", ($rows -join "`n"))
Save @{releasedMs=$releaseMs; receivedMs=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); messages=$messages} "$caseDir/delivery-timing.json"
Shot 'instant-delivered'
$observation.actionMs = $restartStart
$observation.endMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
