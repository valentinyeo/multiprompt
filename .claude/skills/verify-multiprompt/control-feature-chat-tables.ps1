
            $command = 'powershell -nop -c "''250c 2500 252c 2500 2510'',''2502 0041 2502 0042 2502'',''251c 2500 253c 2500 2524'',''2502 0031 2502 0032 2502'',''2514 2500 2534 2500 2518''|ForEach-Object{-join($_.Split('' '')|ForEach-Object{[char][Convert]::ToInt32($_,16)})}"'
            $command += ' && echo table-ready>"' + (Join-Path $scratch 'table-ready.txt') + '"'
            Type-Text $command
            Press @(0x0D) 'Enter: print table and persist console completion marker in CMD'
            Wait-Until { Test-Path (Join-Path $scratch 'table-ready.txt') } 'real console table command completed'
            Press @(0x12, 0x43) 'Alt+C: open formatted Chat View'
            Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 -and $state.active_tab -ge 0 -and $state.active_tab -lt @($state.tabs).Count } 'saved initial table tab'
            $tableTab = (Read-Session).active_tab
            $log = Join-Path $scratch 'roaming/ZigShell/debug.log'
            Wait-Until { (Test-Path $log) -and ((Get-Content $log -Raw) -join '') -match 'CHAT_TABLE rows=1 columns=2 .*source=box' } 'formatted table built from real console output'
            Wait-Until { (Read-Session).tabs[$tableTab].cv } 'Chat View preference persisted for table tab'
            Snapshot 'before'
            $buildsBefore = @([regex]::Matches(((Get-Content $log -Raw) -join ''), 'CHAT_TABLE rows=1 columns=2 .*source=box')).Count
            $tabsBefore = @((Read-Session).tabs).Count
            Palette 'new cmd'
            Snapshot 'action'
            Press @(0x0D) 'Enter: create another real CMD tab'
            Wait-Until { @((Read-Session).tabs).Count -eq $tabsBefore + 1 -and (Read-Session).active_tab -ne $tableTab } 'new CMD tab active and saved'
            Snapshot 'away'
            $awayLogLength = ((Get-Content $log -Raw) -join '').Length
            Press @(0x11, 0x10, 0x09) 'Ctrl+Shift+Tab: return to table Chat View'
            Wait-Until { (Read-Session).active_tab -eq $tableTab -and (Read-Session).tabs[$tableTab].cv } 'original Chat View tab active again'
            Wait-Until { $text = (Get-Content $log -Raw) -join ''; $text.Length -gt $awayLogLength -and $text.Substring($awayLogLength) -match '\[switch\] chat painted in' } 'returned Chat View painted'
            Snapshot 'after'
            $buildsAfter = @([regex]::Matches(((Get-Content $log -Raw) -join ''), 'CHAT_TABLE rows=1 columns=2 .*source=box')).Count
            if ($buildsAfter -ne $buildsBefore) { throw "Unchanged table rebuilt across tab switch: $buildsBefore -> $buildsAfter" }
            $result.checks += @{ name = 'console-table-switch-return'; tableTab = $tableTab; buildsBefore = $buildsBefore; buildsAfter = $buildsAfter; marker = (Get-Content (Join-Path $scratch 'table-ready.txt') -Raw).Trim(); chatViewSaved = $true }
            Add-Type -Path (Join-Path $PSScriptRoot '../../../tools/verify-chat-delivery/layout-capture.cs')
            [LayoutCapture]::Display()
            [void][VerifyNative]::ShowWindow($script:window, 9)
            [void][VerifyNative]::MoveWindow($script:window, 0, 0, 1920, 1032, $true)
            foreach ($attempt in 1..3) {
                $client = New-Object VerifyNative+Rect
                $frame = New-Object VerifyNative+Rect
                if (-not [VerifyNative]::GetClientRect($script:window, [ref]$client) -or -not [VerifyNative]::GetWindowRect($script:window, [ref]$frame)) { throw 'Table window geometry unavailable' }
                if ($client.Right -eq 1920 -and $client.Bottom -eq 1032) { break }
                [void][VerifyNative]::MoveWindow($script:window, 0, 0, ($frame.Right - $frame.Left + 1920 - $client.Right), ($frame.Bottom - $frame.Top + 1032 - $client.Bottom), $true)
            }
            Wait-Until { [void][VerifyNative]::GetClientRect($script:window, [ref]$client); $client.Right -eq 1920 -and $client.Bottom -eq 1032 } 'reference-sized 1920x1032 table window'
            $wideScript = Join-Path $scratch 'wide-table.ps1'
            Set-Content -Path $wideScript -Encoding ascii -Value @'
$rows = @(
    @('Brain tag', 'Use for', 'Codex and Anthropic models', 'DeepSeek and Cursor models'),
    @('brain-light', 'Tiny obvious fixes in one single file', 'Terra medium or Sonnet medium', '4.1 Flash low or Composer 2.5'),
    @('brain-medium', 'Normal work and the default when unsure', 'Sol medium or Sonnet medium', '4.1 Flash high or Grok 4.7 medium'),
    @('brain-hard', 'Hard bugs, security, money, many systems', 'Sol high or Opus or Sonnet high', 'Skip or Grok 4.7 high'),
    @('brain-extra-hard', 'Rare account integrity or security money', 'Skip or Opus 5.5 medium or high', 'Skip on both providers')
)
$widths = @(0, 0, 0, 0)
foreach ($row in $rows) { for ($i = 0; $i -lt 4; $i++) { $widths[$i] = [Math]::Max($widths[$i], $row[$i].Length) } }
$h = [string][char]0x2500
$v = [string][char]0x2502
function Border([int]$left, [int]$middle, [int]$right) { [string][char]$left + (($widths | ForEach-Object { $h * ($_ + 2) }) -join [string][char]$middle) + [string][char]$right }
Border 0x250C 0x252C 0x2510
for ($r = 0; $r -lt $rows.Count; $r++) {
    $v + ((0..3 | ForEach-Object { ' ' + $rows[$r][$_].PadRight($widths[$_]) + ' ' }) -join $v) + $v
    if ($r -eq 0) { Border 0x251C 0x253C 0x2524 }
}
Border 0x2514 0x2534 0x2518
'@
            Press @(0x12, 0x43) 'Alt+C: back to the shell to print a wide table'
            Wait-Until { -not (Read-Session).tabs[$tableTab].cv } 'table tab shows the shell'
            Type-Text ('powershell -nop -ExecutionPolicy Bypass -File "' + $wideScript + '" && echo wide-ready>"' + (Join-Path $scratch 'wide-ready.txt') + '"')
            Press @(0x0D) 'Enter: print the wide brain-tag table in CMD'
            Wait-Until { Test-Path (Join-Path $scratch 'wide-ready.txt') } 'real console wide table command completed'
            Press @(0x12, 0x43) 'Alt+C: Chat View with the wide table'
            Wait-Until { (Read-Session).tabs[$tableTab].cv } 'table tab back in Chat View'
            Wait-Until { ((Get-Content $log -Raw) -join '') -match 'CHAT_TABLE rows=4 columns=4 .*source=box' } 'wide table built from real console output'
            $wide = [regex]::Matches(((Get-Content $log -Raw) -join ''), 'CHAT_TABLE rows=4 columns=4 header_bold=1 content_w=(\d+) view_w=(\d+) source=box')
            $wideLine = $wide[$wide.Count - 1]
            Snapshot 'wide-in-chat'
            Palette 'expand table' '6495'
            Press @(0x0D) 'Enter: Chat View: Expand table'
            Wait-Until { ((Get-Content $log -Raw) -join '') -match 'CHAT_TABLE_EXPAND open card_w=\d+ content_w=\d+ view_w=\d+' } 'expanded table overlay opened'
            Wait-Until { [VerifyNative]::Class([VerifyNative]::GetForegroundWindow()) -ceq 'MultiPromptTableOverlay' } 'expanded table overlay owns the foreground'
            $overlay = [VerifyNative]::GetForegroundWindow()
            [uint32]$overlayPid = 0
            [void][VerifyNative]::GetWindowThreadProcessId($overlay, [ref]$overlayPid)
            if ($overlayPid -ne $process.Id -or [VerifyNative]::GetAncestor($overlay, 3) -ne $script:window) { throw 'Expanded table overlay is not owned by the app window' }
            $open = [regex]::Match(((Get-Content $log -Raw) -join ''), 'CHAT_TABLE_EXPAND open card_w=(\d+) content_w=(\d+) view_w=(\d+) content_h=(\d+) view_h=(\d+)')
            if ([int]$open.Groups[3].Value -lt [int]$open.Groups[2].Value -and [int]$open.Groups[3].Value -le [int]$wideLine.Groups[2].Value) { throw "Expanded table is no wider than Chat View: $($open.Value)" }
            Start-Sleep -Milliseconds 300
            Snapshot 'expanded'
            Press @(0x1B) 'Esc: close the expanded table'
            Wait-Until { ((Get-Content $log -Raw) -join '') -match 'CHAT_TABLE_EXPAND closed' } 'expanded table overlay closed'
            Wait-Until { [VerifyNative]::Class([VerifyNative]::GetForegroundWindow()) -cne 'MultiPromptTableOverlay' -and [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window } 'focus returned to the app window'
            Snapshot 'collapsed'
            $result.checks += @{ name = 'chat-table-expand'; inChat = $wideLine.Value; overlay = $open.Value; overlayClass = 'MultiPromptTableOverlay'; closedBy = 'Esc' }
        