$metadata = Join-Path $env:APPDATA 'ZigShell/all-sessions.json'
$baseline = Read-Session
Invoke-JourneyCommand 'Show all sessions' -Confirm {
    Press @(0x0D) 'Enter: open the All Sessions card'
}
Snapshot 'all-sessions-before'
Press @(0x53) 'S: star Studio Guide'
Wait-Until {
    $rows = @(Get-Content $metadata -Raw | ConvertFrom-Json)
    @($rows | Where-Object { $_.starred -eq $true }).Count -eq 1
} 'exactly one fixture session starred by the app'
$starred = @(Get-Content $metadata -Raw | ConvertFrom-Json) | Where-Object { $_.starred -eq $true }
if ([Text.Encoding]::UTF8.GetString([byte[]]$starred.session).TrimEnd([char]0) -cne 'fixture-guide') { throw 'S starred the wrong session' }
Snapshot 'all-sessions-starred'
Press @(0x09) 'Tab: select Frequent'
Snapshot 'all-sessions-frequent'
Press @(0x09) 'Tab: select Favorites'
Snapshot 'all-sessions-favorites'
Press @(0x11, 0x46) 'Ctrl+F: focus session search'
Type-Text 'Studio Guide'
Snapshot 'all-sessions-search'
Press @(0x1B) 'Esc: clear search'
Press @(0x10, 0x41) 'Shift+A: select Archived'
Snapshot 'all-sessions-archived'
Press @(0x1B) 'Esc: return to the workspace'
Doctor
$after = Read-Session
if (@($after.tabs).Count -ne @($baseline.tabs).Count) { throw 'Browsing archived cards changed the open sessions' }
$result.checks += @{ name = 'all-sessions-fixture'; syntheticArchive = $true; starredSession = 'fixture-guide'; preservedOpenTabs = @($after.tabs).Count }
Snapshot 'all-sessions-returned'
