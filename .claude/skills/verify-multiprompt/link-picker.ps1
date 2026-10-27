Select-Theme 'amoled' 'amoled'
Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 } 'initial session saved'
$initial = Read-Session
if ($initial.tabs[$initial.active_tab].PSObject.Properties['cv'] -and $initial.tabs[$initial.active_tab].cv) {
    Press @(0x12, 0x43) 'Alt+C: show console for link setup'
}
Wait-WorkspaceSurface $initial.active_workspace $initial.active_tab $false
$first = 'http://127.0.0.1:1/picker-first'
$second = 'http://127.0.0.1:1/picker-second'
$command = 'echo ' + $first + ' ' + $second
Type-Text $command
Wait-ConsoleText $command
Press @(0x0D) 'Enter: print two distinct links'
Press @(0x12, 0x43) 'Alt+C: open Chat View'
Wait-Until {
    $state = Read-Session
    $state.tabs[$state.active_tab].PSObject.Properties['cv'] -and $state.tabs[$state.active_tab].cv
} 'Chat View saved'
$transcript = [IntPtr]::Zero
Wait-Until {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
    $rows = @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { -not $_.Current.IsOffscreen })
    if ($rows.Count -ne 1) { return $false }
    $script:pickerTranscript = [IntPtr]$rows[0].Current.NativeWindowHandle
    return [VerifyNative]::IsWindowVisible($script:pickerTranscript)
} 'native chat transcript visible before picker'
$transcript = $script:pickerTranscript
Snapshot 'before'
Press @(0x12, 0x57) 'Alt+W: open link list above Chat View'
Wait-Until { -not [VerifyNative]::IsWindowVisible($transcript) } 'chat child hidden under link list'
Snapshot 'action'
$image = New-Object Drawing.Bitmap((Join-Path $Evidence 'action.png'))
$fill = 0
$outline = 0
$blue = 0
try {
    $frame = New-Object VerifyNative+Rect
    $client = New-Object VerifyNative+Rect
    $origin = New-Object VerifyNative+Point
    if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::GetClientRect($script:window, [ref]$client) -or -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'Picker native geometry missing' }
    $left = $origin.X - $frame.Left + [int](($client.Right - 640) / 2)
    $top = $origin.Y - $frame.Top + [int](($client.Bottom - 114) / 3) + 36
    for ($y = $top; $y -lt $top + 36; $y++) {
        for ($x = $left + 4; $x -lt $left + 636; $x++) {
            $pixel = $image.GetPixel($x, $y)
            if ($pixel.R -eq 31 -and $pixel.G -eq 31 -and $pixel.B -eq 31) { $fill++ }
            if ($pixel.R -eq 46 -and $pixel.G -eq 46 -and $pixel.B -eq 46) { $outline++ }
            if ($pixel.B -gt 120 -and $pixel.B -gt $pixel.R + 50) { $blue++ }
        }
    }
    if ($fill -lt 5000 -or $outline -lt 100 -or $blue -gt 0) { throw "Picker style mismatch: fill=$fill outline=$outline blue=$blue" }
} finally { $image.Dispose() }
Press @(0x1B) 'Escape: restore Chat View'
Wait-Until { [VerifyNative]::IsWindowVisible($transcript) } 'chat transcript restored on Escape'
Snapshot 'restored'
Press @(0x12, 0x57) 'Alt+W: reopen links'
Wait-Until { -not [VerifyNative]::IsWindowVisible($transcript) } 'picker reopened above chat'
Press @(0x28) 'Down: select second link'
Snapshot 'second-selection'
Press @(0x0D) 'Enter: open selected second link'
Wait-Until { $state = Read-Session; $state.tabs[$state.active_tab].PSObject.Properties['burl'] -and $state.tabs[$state.active_tab].burl -ceq $second -and [VerifyNative]::DockedPaneWindow($script:window) -ne [IntPtr]::Zero } 'selected second URL opened in a native browser pane' 60
Wait-Until { [VerifyNative]::IsWindowVisible($transcript) } 'chat restored after Enter'
Snapshot 'after'
$result.checks += @{ name = 'link-picker'; theme = 'amoled'; transcriptHidden = $true; escapeRestored = $true; enterRestored = $true; selectedUrl = $second; fillPixels = $fill; outlinePixels = $outline; bluePixels = $blue; version = $ExpectedVersion }
