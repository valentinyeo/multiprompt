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
    & node (Join-Path $PSScriptRoot '../../../tools/chat-working-proof.mjs') (Join-Path $Evidence ($name + '.bmp')) (Join-Path $Evidence 'working-area.json') (Join-Path $Evidence ($name + '.json')) $state
    $LASTEXITCODE -eq 0
}
Wait-Until { & $probe 'working-0' 'busy' } 'IGSH-924 inline dots painted' -Seconds 20
$first = Get-Content (Join-Path $Evidence 'working-0.json') -Raw | ConvertFrom-Json
$check.frames += $first
Wait-Until {
    if (-not (& $probe 'working-1' 'busy')) { return $false }
    $next = Get-Content (Join-Path $Evidence 'working-1.json') -Raw | ConvertFrom-Json
    ($first.dots | ConvertTo-Json -Compress) -cne ($next.dots | ConvertTo-Json -Compress)
} 'IGSH-924 dots animate' -Seconds 20
$check.frames += (Get-Content (Join-Path $Evidence 'working-1.json') -Raw | ConvertFrom-Json)
[IO.File]::WriteAllText(($prefix + '-reply'), 'reply now')
Wait-Until { & $probe 'after' 'idle' } 'IGSH-924 dots gone after reply' -Seconds 45
Press @(0x11, 0x41) 'Ctrl+A: select real transcript text'
$check.passed = $true
Save-Json $check 'working-proof.json'
