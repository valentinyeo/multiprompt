$check = @{ name = 'inline-working-dots'; passed = $false; frames = @() }
$result.checks += $check
$localAgent = Join-Path (Split-Path $Exe) 'claude.exe'
$prefix = Join-Path $scratch 'inline-working'
$initial = Read-Session
if ($initial.tabs[$initial.active_tab].PSObject.Properties['cv'] -and $initial.tabs[$initial.active_tab].cv) {
    Press @(0x12, 0x43) 'Alt+C: show owned console'
}
Type-Text ('"' + $localAgent + '" inline "' + $prefix + '"')
Press @(0x0D) 'Enter: start owned working console'
Wait-Until { Test-Path ($prefix + '-ready.json') } 'working console ready'
Wait-Until {
    $inbox = Read-Inbox
    @($inbox.shells | Where-Object { $_.sid -eq $initial.tabs[$initial.active_tab].shell_id -and $_.PSObject.Properties['ag'] -and $_.ag -eq 1 }).Count -eq 1
} 'owned working agent detected' -Seconds 45
Press @(0x12, 0x43) 'Alt+C: open working conversation'
Wait-Until {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
    $script:workingTranscript = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen })
    $script:workingTranscript.Count -eq 1
} 'visible owned transcript'
$frame = New-Object VerifyNative+Rect
if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame)) { throw 'Window rectangle unavailable' }
$bounds = $script:workingTranscript[0].Current.BoundingRectangle
$area = @{ left = [int]$bounds.Left - $frame.Left; top = [int]$bounds.Top - $frame.Top; right = [int]$bounds.Right - $frame.Left; bottom = [int]$bounds.Bottom - $frame.Top }
Save-Json $area 'working-area.json'
$probe = {
    param($name, $state)
    Snapshot $name
    $image = [Drawing.Bitmap]::FromFile((Join-Path $Evidence ($name + '.png')))
    try { $image.Save((Join-Path $Evidence ($name + '.bmp')), [Drawing.Imaging.ImageFormat]::Bmp) } finally { $image.Dispose() }
    & node (Join-Path $PSScriptRoot '../../../tools/chat-working-proof.mjs') (Join-Path $Evidence ($name + '.bmp')) (Join-Path $Evidence 'working-area.json') (Join-Path $Evidence ($name + '.json')) $state (Join-Path $Evidence 'working-0.json')
    $LASTEXITCODE -eq 0
}
$captureSecondLines = {
    param([string]$State)
    Wait-Until {
        $target = $initial.tabs[$initial.active_tab].shell_id
        $row = @((Read-Inbox).shells | Where-Object { $_.sid -eq $target })
        if ($row.Count -ne 1) { return $false }
        if ($State -eq 'finished') { return $row[0].pv -ceq 'Ready.' -and $row[0].act -eq 0 }
        $row[0].pv.StartsWith('Inspecting files') -and $row[0].pv -match ' · \d+m$'
    } ("IGSH-1665 $State semantic second line published") -Seconds 45
    $result.checks += @{ name = "IGSH-1665-$State-second-line"; preview = @((Read-Inbox).shells | Where-Object { $_.sid -eq $initial.tabs[$initial.active_tab].shell_id })[0].pv }
    foreach ($theme in @(@{ query = 'light'; saved = 'light' }, @{ query = 'amoled'; saved = 'amoled' }, @{ query = 'edge grey'; saved = 'edgegray' })) {
        Select-Theme $theme.query ("second-line-$State-$($theme.saved)-theme") $theme.saved
        Snapshot ("second-line-$State-$($theme.saved)-sidebar")
        Press @(0x11, 0x10, 0x49) 'Ctrl+Shift+I: inspect agent second line in Inbox'
        Wait-Until { (Read-Inbox).inbox_active -eq $true } 'second-line Inbox visible'
        Press @(0x12, 0x49) 'Alt+I: inspect All agents'
        Snapshot ("second-line-$State-$($theme.saved)-inbox")
        Press @(0x1B) 'Esc: return to agent sidebar'
        Wait-Until { (Read-Inbox).inbox_active -eq $false } 'second-line sidebar restored'
    }
    Select-Theme 'dark' ("second-line-$State-restore-dark")
}
$owned = Read-Session
$hookTarget = $owned.tabs[$owned.active_tab].name
& $Exe --notify ('ACTIVE:' + $hookTarget)
Wait-Until { & $probe 'working-0' 'busy' } 'IGSH-924 inline dots painted' -Seconds 20
Snapshot 'action'
$first = Get-Content (Join-Path $Evidence 'working-0.json') -Raw | ConvertFrom-Json
$check.frames += $first
Wait-Until {
    if (-not (& $probe 'working-1' 'busy')) { return $false }
    $next = Get-Content (Join-Path $Evidence 'working-1.json') -Raw | ConvertFrom-Json
    ($first.dots | ConvertTo-Json -Compress) -cne ($next.dots | ConvertTo-Json -Compress)
} 'IGSH-924 dots animate' -Seconds 20
$check.frames += (Get-Content (Join-Path $Evidence 'working-1.json') -Raw | ConvertFrom-Json)
& $captureSecondLines 'working'
$ready = Get-Content ($prefix + '-ready.json') -Raw | ConvertFrom-Json
$replyEvent = [Threading.EventWaitHandle]::OpenExisting(('Local\MultipromptInlineReply-' + $ready.pid))
try { [void]$replyEvent.Set() } finally { $replyEvent.Dispose() }
Wait-Until { Test-Path ($prefix + '-replied') } 'stand-in wrote the real reply to its console'
$readback = Get-Content ($prefix + '-replied') -Raw
$codes = ($readback -split 'chars=')[1] -split ',' | Where-Object { $_ }
$screen = -join @($codes | ForEach-Object { [char][int]$_ })
if ($screen -notmatch 'Ready\.' -or $screen -match 'interrupt') { throw ('Stand-in did not replace its working line: ' + $screen) }
& $Exe --notify ('DONE:' + $hookTarget)
Wait-Until { & $probe 'after' 'idle' } 'IGSH-924 dots gone after reply' -Seconds 45
& $captureSecondLines 'finished'
$check.passed = $true
Save-Json $check 'working-proof.json'
$referencePath = Join-Path $env:TEMP 'inline-working-reference.png'
Invoke-WebRequest 'https://screencast2.com/h9mN1.png' -OutFile $referencePath -UseBasicParsing
$reference = [Drawing.Bitmap]::FromFile($referencePath)
$working = [Drawing.Bitmap]::FromFile((Join-Path $Evidence 'working-0.png'))
$comparison = New-Object Drawing.Bitmap(($working.Width + 400), ($working.Height + 40))
$graphics = [Drawing.Graphics]::FromImage($comparison)
$font = New-Object Drawing.Font('Arial', 14)
try {
    $graphics.Clear([Drawing.Color]::FromArgb(20, 20, 20))
    $graphics.DrawString('Multiprompt: working', $font, [Drawing.Brushes]::White, 10, 8)
    $graphics.DrawImage($working, 0, 40, $working.Width, $working.Height)
    $graphics.DrawString('Grok reference', $font, [Drawing.Brushes]::White, ($working.Width + 10), 8)
    $target = New-Object Drawing.Rectangle(($working.Width + 10), 60, 370, 61)
    $source = New-Object Drawing.Rectangle(447, 918, 303, 50)
    $graphics.DrawImage($reference, $target, $source, [Drawing.GraphicsUnit]::Pixel)
    $comparison.Save((Join-Path $Evidence 'working-comparison.png'), [Drawing.Imaging.ImageFormat]::Png)
} finally {
    $font.Dispose()
    $graphics.Dispose()
    $comparison.Dispose()
    $working.Dispose()
    $reference.Dispose()
    Remove-Item $referencePath
}
