function Invoke-BreakItWindow([IntPtr]$Frame, [uint32]$Owner, [scriptblock]$Chord, [scriptblock]$ReadSession) {
    if (-not $env:MP_BREAK_IT_VARIATION) { return }
    $mode = $env:MP_BREAK_IT_VARIATION
    $receipt = Join-Path $Evidence 'break-it-input.json'
    if (Test-Path $receipt) { return }
    $before = & $ReadSession
    $inputs = @()
    switch ($mode) {
        'resize' {
            & $Chord @(0x5B, 0x25)
            $inputs += 'Win+Left: resize by snapping'
        }
        'maximize' {
            & $Chord @(0x5B, 0x26)
            $inputs += 'Win+Up: maximize'
        }
        'fast-switch' {
            if (@($before.tabs).Count -lt 2) { throw 'Break-it infrastructure: fast-switch needs two seeded sessions' }
            & $Chord @(0x11, 0x09)
            $deadline = [DateTime]::UtcNow.AddSeconds(10)
            do { $selected = & $ReadSession; if ($selected.active_tab -ne $before.active_tab) { break }; Start-Sleep -Milliseconds 50 } while ([DateTime]::UtcNow -lt $deadline)
            if ($selected.active_tab -eq $before.active_tab) { throw 'Break-it infrastructure: native session switch did not occur' }
            & $Chord @(0x11, 0x10, 0x09)
            for ($i = 0; $i -lt 12; $i++) { & $Chord @(0x11, 0x09); & $Chord @(0x11, 0x10, 0x09) }
            $inputs += 'Observed a different session, then 12 rapid Ctrl+Tab and Ctrl+Shift+Tab pairs'
        }
        'long-chat' {
            $manifest = Get-Content (Join-Path $Evidence 'fixture-manifest.json') -Raw | ConvertFrom-Json
            if ($manifest.longChats -ne 8 -or $manifest.messagesPerLongChat -ne 2400) { throw 'Break-it infrastructure: real-size seed missing' }
            throw 'Break-it infrastructure: this journey has no long-chat assertion adapter'
        }
        default { return }
    }
    $after = & $ReadSession
    @{ mode=$mode; pid=$Owner; hwnd=$Frame.ToInt64(); inputs=$inputs; before=$before; after=$after } | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 $receipt
}
