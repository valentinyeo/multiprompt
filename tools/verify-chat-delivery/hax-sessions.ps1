function Hax-Palette([string]$Query) {
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x4B) 'Ctrl+K: open runner proof command'
    foreach ($letter in $Query.ToCharArray()) { [ChatDeliveryDesktop]::Character($letter) }
    [void](Wait-For 'runner proof command selected' { (Read-Shared "$settings/debug.log").Substring($offset) -match ('\[palette\] ready chars=' + $Query.Length + ' count=1 target=\d+') })
    Press @(0x0D) 'Enter: run runner proof command'
}
$before = @((Get-Content "$settings/inbox-default.json" -Raw | ConvertFrom-Json).shells)
$observation.beforeIds = @($before | ForEach-Object { $_.sid })
if ($before.Count -ne 4) { throw 'Expected four distinct saved runner tabs' }
Hax-Palette 'chat view on everywhere'
if ($plan.name -eq 'hax-reader') {
    $observation.runners = [Collections.Generic.List[object]]::new()
    foreach ($index in 0..2) {
        Press @(0x11, (0x31 + $index)) 'Ctrl+number: select actual saved runner tab'
        [void](Wait-For 'runner Chat View composer' { $h = [ChatDeliveryDesktop]::Composer($main); if ($h -ne [IntPtr]::Zero) { $script:composer = $h; $true } })
        Bind-Transcript
        $wanted = "IGSH1043 runner $index saved reply"
        [void](Wait-For 'saved native hax reply visibly rendered' {
            Hax-Palette 'chat view select all'
            Press @(0x11, 0x43) 'Ctrl+C: inspect actual runner conversation'
            $script:haxCopied = [Windows.Forms.Clipboard]::GetText()
            Press @(0x1B) 'Esc: clear copied runner conversation'
            $script:haxCopied.Contains($wanted)
        } 45)
        foreach ($other in 0..2) {
            if ($other -ne $index -and $script:haxCopied.Contains("IGSH1043 runner $other saved reply")) { throw 'Another same-folder runner conversation leaked into this tab' }
        }
        [IO.File]::WriteAllText("$caseDir/runner-$index-copied.txt", $script:haxCopied)
        Shot "hax-runner-$index"
        $observation.runners.Add(@{index=$index; wanted=$wanted; sid=$before[$index].sid; copied=$script:haxCopied})
    }
} else {
    [void](Wait-For 'actual host inventory contains all four live runners' { (Read-Shared "$settings/debug.log") -match 'fetchHostIntoCache\(host=0\) done:.*added=4' })
    Press @(0x11, 0x34) 'Ctrl+4: select the empty runner session'
    $emptyId = $before[3].sid
    $observation.closedId = $emptyId
    $observation.savedBefore = @((Get-Content "$settings/session.json" -Raw | ConvertFrom-Json).tabs).Count
    Press @(0x11, 0x57) 'Ctrl+W: close the empty runner session'
    $expectedShells = 3
    [void](Wait-For 'closed tab removed from saved and published state' {
        $rows = @((Get-Content "$settings/inbox-default.json" -Raw | ConvertFrom-Json).shells)
        $saved = @((Get-Content "$settings/session.json" -Raw | ConvertFrom-Json).tabs)
        $rows.Count -eq 3 -and $saved.Count -eq 3 -and @($rows | Where-Object { $_.sid -eq $emptyId }).Count -eq 0
    })
    $beforeLists = @((Read-Shared "$state/invocations.jsonl") -split "`n" | Where-Object { $_ -match '"kind": "list"' }).Count
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x4B) 'Ctrl+K: refresh live host session inventory'
    foreach ($letter in 'runner-empty'.ToCharArray()) { [ChatDeliveryDesktop]::Character($letter) }
    [void](Wait-For 'actual host session refresh completed' {
        (@((Read-Shared "$state/invocations.jsonl") -split "`n" | Where-Object { $_ -match '"kind": "list"' }).Count -gt $beforeLists) -and ((Read-Shared "$settings/debug.log").Substring($offset) -match 'fetchHostIntoCache\(host=0\) done:.*added=4')
    })
    $after = @((Get-Content "$settings/inbox-default.json" -Raw | ConvertFrom-Json).shells)
    $observation.afterIds = @($after | ForEach-Object { $_.sid })
    $observation.savedAfter = @((Get-Content "$settings/session.json" -Raw | ConvertFrom-Json).tabs).Count
    $observation.hostRefresh = $true
    [void](Wait-For 'closed runner remains absent after live host refresh' {
        (Read-Shared "$settings/debug.log").Substring($offset) -match '\[palette\] ready chars=12 count=0(?:\s|$)'
    } 20)
    Shot 'hax-closed-after-host-sync'
    Press @(0x1B) 'Esc: close runner proof search'
    if (@($after | Where-Object { $_.sid -eq $emptyId -or $observation.beforeIds -notcontains $_.sid }).Count -ne 0) { throw 'Close plus sync allocated or restored a runner shell' }
    $closedSaved = @((Get-Content "$settings/session.json" -Raw | ConvertFrom-Json).closed_tmux)
    if (@($closedSaved | Where-Object { $_.host -eq 0 -and $_.session -eq 'runner-empty' }).Count -ne 1) { throw 'Close intent was not saved by host and session' }
    Restart-OwnedApp
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x4B) 'Ctrl+K: verify closed runner after restart'
    foreach ($letter in 'runner-empty'.ToCharArray()) { [ChatDeliveryDesktop]::Character($letter) }
    [void](Wait-For 'persisted close survives restart and actual host refresh' {
        $log = (Read-Shared "$settings/debug.log").Substring($offset)
        ($log -match 'fetchHostIntoCache\(host=0\) done:.*added=4') -and ($log -match '\[palette\] ready chars=12 count=0(?:\s|$)')
    })
    Press @(0x1B) 'Esc: close restarted runner search'
    $observation.restartClosed = $true
    Press @(0x11, 0x10, 0x54) 'Ctrl+Shift+T: explicitly reopen closed runner'
    $expectedShells = 4
    [void](Wait-For 'explicit reopen restores only the requested runner' {
        $rows = @((Get-Content "$settings/inbox-default.json" -Raw | ConvertFrom-Json).shells)
        $rows.Count -eq 4 -and @($rows | Where-Object { $_.name -eq 'runner-empty' }).Count -eq 1
    })
    $observation.explicitReopen = $true
    Press @(0x11, 0x57) 'Ctrl+W: close the explicitly reopened runner again'
    $expectedShells = 3
    [void](Wait-For 'reopened runner closes without a duplicate tab' { @((Get-Content "$settings/inbox-default.json" -Raw | ConvertFrom-Json).shells).Count -eq 3 })
}
$composer = Wait-For 'owned composer after runner proof' { $h = [ChatDeliveryDesktop]::Composer($main); if ($h -ne [IntPtr]::Zero) { $h } }
[void](Wait-For 'runner proof composer foreground' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, $app.Id, $composer) })
$observation.passed = $true
