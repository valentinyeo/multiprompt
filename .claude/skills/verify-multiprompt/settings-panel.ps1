function Settings-Window {
    $candidate = [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2)
    if ([VerifyNative]::Class($candidate) -ne 'MultipromptSettings') { return [IntPtr]::Zero }
    [uint32]$settingsPid = 0
    [void][VerifyNative]::GetWindowThreadProcessId($candidate, [ref]$settingsPid)
    if ($settingsPid -ne $process.Id) { throw 'Settings belongs to another process' }
    return $candidate
}

function Settings-Control([string]$Name, [System.Windows.Automation.ControlType]$Type = [System.Windows.Automation.ControlType]::Button) {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:settingsWindow)
    $nameCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name)
    $typeCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $Type)
    $condition = New-Object System.Windows.Automation.AndCondition($nameCondition, $typeCondition)
    $element = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
    if ($null -eq $element -or $element.Current.ProcessId -ne $process.Id) { throw "Missing accessible Settings control: $Name" }
    return $element
}

function Click-Setting([string]$Name) {
    Doctor
    Assert-Foreground
    $element = Settings-Control $Name
    $handle = [IntPtr]$element.Current.NativeWindowHandle
    $rect = New-Object VerifyNative+Rect
    if (-not [VerifyNative]::GetClientRect($handle, [ref]$rect)) { throw "Missing Settings control rectangle: $Name" }
    Record ('Click Settings: ' + $Name)
    [VerifyNative]::ClickClient($handle, [int](($rect.Right - $rect.Left) / 2), [int](($rect.Bottom - $rect.Top) / 2))
}

function Open-Settings {
    Press @(0x11, 0xBC) 'Ctrl+Comma: open Settings'
    Wait-Until { (Settings-Window) -ne [IntPtr]::Zero } 'centred Settings panel opened through its keyboard shortcut'
    $script:settingsWindow = Settings-Window
}

function Fill-SettingKey([string]$Name, [string]$Fixture) {
    $element = Settings-Control $Name ([System.Windows.Automation.ControlType]::Edit)
    if (-not $element.Current.IsPassword) { throw "Settings key is not a password field: $Name" }
    $handle = [IntPtr]$element.Current.NativeWindowHandle
    Assert-Foreground
    [VerifyNative]::ClickClient($handle, 8, 8)
    Press @(0x11, 0x41) ('Select isolated fixture in ' + $Name)
    Type-Text $Fixture
    Press @(0x09) ('Tab: save isolated ' + $Name)
}

$environmentPath = 'HKCU:\Environment'
$originalKey = Get-ItemProperty -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY -ErrorAction SilentlyContinue
$hadKey = $null -ne $originalKey -and $null -ne $originalKey.PSObject.Properties['DEEPGRAM_API_KEY']
$oldValue = if ($hadKey) { [string]$originalKey.DEEPGRAM_API_KEY } else { $null }
$uploadDir = Join-Path $env:LOCALAPPDATA 'screencast2-go'
$uploadConfig = Join-Path $uploadDir 'config.toml'
$themeFile = Join-Path $env:APPDATA 'ZigShell\theme-mode.txt'
New-Item -ItemType Directory -Force $uploadDir | Out-Null
[IO.File]::WriteAllText($uploadConfig, "[upload]`napi_base_url = `"https://example.invalid`"`nupload_secret = `"settings-upload-before`"`n[capture]`nquality = 91`n")
if (-not (Test-Path -LiteralPath $environmentPath)) { New-Item -Path $environmentPath | Out-Null }
Set-ItemProperty -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY -Value 'settings-dictation-before'
try {
    Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 } 'initial existing session saved'
    $session = Read-Session
    if (-not ($session.tabs[0].PSObject.Properties['cv'] -and $session.tabs[0].cv)) {
        Press @(0x12, 0x43) 'Alt+C: show the chat behind Settings'
        Wait-Until { $state = Read-Session; $state.tabs[0].PSObject.Properties['cv'] -and $state.tabs[0].cv } 'chat visible behind Settings'
    }
    Snapshot 'settings-backdrop'
    Open-Settings
    Snapshot 'settings-panel'
    Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -Path (Join-Path $PSScriptRoot 'settings-panel-native.cs')
    $frame = New-Object VerifyNative+Rect
    $client = New-Object VerifyNative+Rect
    $origin = New-Object VerifyNative+Point
    if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or
        -not [VerifyNative]::GetClientRect($script:window, [ref]$client) -or
        -not [VerifyNative]::ClientToScreen($script:window, [ref]$origin)) { throw 'Settings owner geometry unavailable' }
    $pixels = [SettingsPanelPixels]::Check((Join-Path $Evidence 'settings-panel.png'), (Join-Path $Evidence 'settings-backdrop.png'), ($origin.X - $frame.Left), ($origin.Y - $frame.Top), $client.Right, $client.Bottom)
    Save-Json $pixels 'settings-panel-pixels.json'
    $result.checks += @{ name = 'settings-centred-painted-panel'; passed = $true; pixels = $pixels }

    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:settingsWindow)
    foreach ($name in @('Close Settings', 'System', 'Dark', 'Light', 'Decrease chat font size', 'Reset chat font size', 'Increase chat font size', 'Terminal details', 'Release notes')) {
        $null = Settings-Control $name
    }
    foreach ($name in @('Dictation key', 'Screencast2 upload key')) {
        $field = Settings-Control $name ([System.Windows.Automation.ControlType]::Edit)
        if (-not $field.Current.IsPassword) { throw "Settings exposes a readable key field: $name" }
    }
    $result.checks += @{ name = 'settings-accessible-controls'; passed = $true; maskedKeys = 2; ownerPid = $process.Id }
    if ((Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -cne 'settings-dictation-before' -or
        (Get-Content -LiteralPath $uploadConfig -Raw) -notmatch 'upload_secret = "settings-upload-before"') { throw 'Opening Settings changed existing keys' }
    $result.checks += @{ name = 'settings-opening-keeps-keys'; passed = $true }


    foreach ($theme in @(@{ name = 'Light'; value = 'light' }, @{ name = 'System'; value = 'system' }, @{ name = 'Dark'; value = 'dark' })) {
        Click-Setting $theme.name
        Wait-Until { (Test-Path -LiteralPath $themeFile) -and (Get-Content -LiteralPath $themeFile -Raw).Trim() -eq $theme.value } ('persisted existing theme: ' + $theme.name)
        $result.checks += @{ name = ('settings-theme-' + $theme.value); passed = $true; savedTheme = $theme.value }
    }
    Click-Setting 'Terminal details'
    Wait-Until { $state = Read-Session; -not $state.tabs[0].cv } 'existing terminal view choice saved'
    Click-Setting 'Increase chat font size'
    Wait-Until { (Read-Session).chat_font_pt -eq 15 } 'chat font changes even while the terminal is selected'
    $result.checks += @{ name = 'settings-chat-font-in-terminal'; passed = $true; points = 15 }
    Click-Setting 'Decrease chat font size'
    Wait-Until { $state = Read-Session; -not $state.PSObject.Properties['chat_font_pt'] -or $state.chat_font_pt -eq 14 } 'chat font decreased to existing default'
    Click-Setting 'Increase chat font size'
    Click-Setting 'Reset chat font size'
    Wait-Until { $state = Read-Session; -not $state.PSObject.Properties['chat_font_pt'] -or $state.chat_font_pt -eq 14 } 'chat font reset persists'
    Click-Setting 'Terminal details'
    Wait-Until { (Read-Session).tabs[0].cv } 'existing chat view choice restored'
    $result.checks += @{ name = 'settings-existing-terminal-choice'; passed = $true; restoredChat = $true }

    Fill-SettingKey 'Dictation key' 'settings-dictation-after'
    Wait-Until { (Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -ceq 'settings-dictation-after' } 'dictation key persisted in its existing registry value'
    Fill-SettingKey 'Screencast2 upload key' 'settings-upload-after'
    Wait-Until { (Get-Content -LiteralPath $uploadConfig -Raw) -match 'upload_secret = "settings-upload-after"' } 'upload key persisted in its existing configuration'
    $config = Get-Content -LiteralPath $uploadConfig -Raw
    if ($config -notmatch 'api_base_url = "https://example.invalid"' -or $config -notmatch 'quality = 91') { throw 'Editing the upload key changed unrelated configuration' }
    $result.checks += @{ name = 'settings-existing-key-stores'; passed = $true; maskedKeys = 2; unrelatedValuesPreserved = $true }
    Snapshot 'settings-values'
    Click-Setting 'Close Settings'
    Wait-Until { -not [VerifyNative]::IsWindowVisible($script:settingsWindow) } 'round close button dismisses Settings'
    Open-Settings
    $dictation = Settings-Control 'Dictation key' ([System.Windows.Automation.ControlType]::Edit)
    $upload = Settings-Control 'Screencast2 upload key' ([System.Windows.Automation.ControlType]::Edit)
    if ([VerifyNative]::Title([IntPtr]$dictation.Current.NativeWindowHandle) -cne 'settings-dictation-after' -or
        [VerifyNative]::Title([IntPtr]$upload.Current.NativeWindowHandle) -cne 'settings-upload-after') { throw 'Reopening Settings did not reload the saved key fixtures' }
    $result.checks += @{ name = 'settings-reopen-existing-values'; passed = $true; reloadedKeys = 2 }
    Press @(0x1B) 'Escape: close Settings'
    Wait-Until { -not [VerifyNative]::IsWindowVisible($script:settingsWindow) } 'Settings dismissed with Escape'
    Wait-ChatFocus 'Edit' 'settings-focus-restored'
    Palette 'settings'
    Press @(0x0D) 'Enter: open Settings from the command palette'
    Wait-Until { (Settings-Window) -ne [IntPtr]::Zero } 'Settings opened through its palette entry'
    $script:settingsWindow = Settings-Window
    Snapshot 'settings-palette'
    $result.checks += @{ name = 'settings-keyboard-palette-focus'; passed = $true; shortcut = 'Ctrl+Comma'; palette = 'Settings' }
    Click-Setting 'Release notes'
    Wait-Until { -not [VerifyNative]::IsWindowVisible($script:settingsWindow) } 'existing release notes action leaves Settings'
    Snapshot 'settings-release-notes'
    Press @(0x1B) 'Escape: close existing release notes'
    $result.checks += @{ name = 'settings-release-notes'; passed = $true }
    Save-Json @{ status = 'passed'; checks = @($result.checks | Where-Object { $_.name -like 'settings-*' }); screenshot = 'settings-panel.png' } 'settings-panel-proof.json'
} finally {
    if ($hadKey) { Set-ItemProperty -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY -Value $oldValue }
    else { Remove-ItemProperty -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY -ErrorAction SilentlyContinue }
}
