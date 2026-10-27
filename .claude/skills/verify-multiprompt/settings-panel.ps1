function Settings-Window {
    $candidate = [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2)
    if ([VerifyNative]::Class($candidate) -ne 'MultipromptSettings') { return [IntPtr]::Zero }
    [uint32]$settingsPid = 0
    [void][VerifyNative]::GetWindowThreadProcessId($candidate, [ref]$settingsPid)
    if ($settingsPid -ne $process.Id) { throw 'Settings belongs to another process' }
    return $candidate
}

function Settings-Control([string]$Name, [System.Windows.Automation.ControlType]$Type = [System.Windows.Automation.ControlType]::Button, [IntPtr]$RootWindow = $script:settingsWindow) {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($RootWindow)
    $nameCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name)
    $typeCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $Type)
    $condition = New-Object System.Windows.Automation.AndCondition($nameCondition, $typeCondition)
    $element = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
    if ($null -eq $element -or $element.Current.ProcessId -ne $process.Id) { throw "Missing accessible Settings control: $Name" }
    return $element
}

function Click-Setting([string]$Name, [IntPtr]$RootWindow = $script:settingsWindow) {
    Doctor
    Assert-Foreground
    $element = Settings-Control $Name -RootWindow $RootWindow
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

function Settings-KeyWindow {
    $candidate = [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2)
    if ([VerifyNative]::Class($candidate) -ne 'MultipromptSettingsKey') { return [IntPtr]::Zero }
    [uint32]$keyPid = 0
    [void][VerifyNative]::GetWindowThreadProcessId($candidate, [ref]$keyPid)
    if ($keyPid -ne $process.Id) { throw 'Key dialog belongs to another process' }
    return $candidate
}

function Fill-SettingKey([string]$Name, [string]$Fixture, [switch]$Append, [switch]$Cancel) {
    Click-Setting $Name
    Wait-Until { (Settings-KeyWindow) -ne [IntPtr]::Zero } ('separate password dialog for ' + $Name)
    $keyWindow = Settings-KeyWindow
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($keyWindow)
    $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Edit)
    $element = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
    if ($null -eq $element -or -not $element.Current.IsPassword) { throw "Settings key is not a password field: $Name" }
    $handle = [IntPtr]$element.Current.NativeWindowHandle
    Assert-Foreground
    [VerifyNative]::ClickClient($handle, 8, 8)
    if ($Append) { Press @(0x23) ('End: append to the loaded isolated ' + $Name) }
    else { Press @(0x11, 0x41) ('Select isolated fixture in ' + $Name) }
    Type-Text $Fixture
    if ($Cancel) { Press @(0x1B) ('Escape: cancel isolated ' + $Name) }
    else { Click-Setting 'Save' -RootWindow $keyWindow }
    Wait-Until { -not [VerifyNative]::IsWindowVisible($keyWindow) -and (Settings-Window) -eq $script:settingsWindow } ('return to Settings after ' + $Name)
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
    $content = New-Object VerifyNative+Rect
    if (-not [VerifyNative]::GetWindowRect($script:settingsWindow, [ref]$content)) { throw 'Settings content geometry unavailable' }
    $pixels = [SettingsPanelPixels]::Check((Join-Path $Evidence 'settings-panel.png'), (Join-Path $Evidence 'settings-backdrop.png'), ($content.Left - $frame.Left), ($content.Top - $frame.Top), ($content.Right - $content.Left), ($content.Bottom - $content.Top), ($origin.X - $frame.Left), ($content.Left - $origin.X))
    Save-Json $pixels 'settings-panel-pixels.json'
    $result.checks += @{ name = 'settings-centred-painted-panel'; passed = $true; pixels = $pixels }

    foreach ($name in @('Close Settings', 'Theme', 'Small', 'Normal', 'Large', 'Terminal details', 'Dictation key', 'Screencast2 upload key', 'Release notes')) {
        $null = Settings-Control $name
    }
    $result.checks += @{ name = 'settings-accessible-controls'; passed = $true; keyRows = 2; ownerPid = $process.Id }
    if ((Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -cne 'settings-dictation-before' -or
        (Get-Content -LiteralPath $uploadConfig -Raw) -notmatch 'upload_secret = "settings-upload-before"') { throw 'Opening Settings changed existing keys' }
    $result.checks += @{ name = 'settings-opening-keeps-keys'; passed = $true }


    foreach ($theme in @(@{ name = 'Light'; value = 'light'; index = 3 }, @{ name = 'Mid'; value = 'mid'; index = 2 }, @{ name = 'AMOLED'; value = 'amoled'; index = 4 }, @{ name = 'Edge gray'; value = 'edgegray'; index = 5 }, @{ name = 'Multiprompt'; value = 'multiprompt'; index = 6 }, @{ name = 'System'; value = 'system'; index = 0 }, @{ name = 'Dark'; value = 'dark'; index = 1 })) {
        Click-Setting 'Theme'
        Press @(0x24) 'Home: first existing theme'
        for ($step = 0; $step -lt $theme.index; $step++) { Press @(0x28) 'Down: existing theme choice' }
        Press @(0x0D) ('Enter: select ' + $theme.name)
        Wait-Until { (Test-Path -LiteralPath $themeFile) -and (Get-Content -LiteralPath $themeFile -Raw).Trim() -eq $theme.value } ('persisted existing theme: ' + $theme.name)
        $result.checks += @{ name = ('settings-theme-' + $theme.value); passed = $true; savedTheme = $theme.value }
    }
    Click-Setting 'Terminal details'
    Wait-Until { $state = Read-Session; -not $state.tabs[0].cv } 'existing terminal view choice saved'
    Click-Setting 'Large'
    Wait-Until { (Read-Session).chat_font_pt -eq 16 } 'chat font changes even while the terminal is selected'
    $result.checks += @{ name = 'settings-chat-font-in-terminal'; passed = $true; points = 16 }
    Click-Setting 'Small'
    Wait-Until { $state = Read-Session; $state.chat_font_pt -eq 12 } 'small chat font persists'
    Click-Setting 'Large'
    Click-Setting 'Normal'
    Wait-Until { $state = Read-Session; -not $state.PSObject.Properties['chat_font_pt'] -or $state.chat_font_pt -eq 14 } 'chat font reset persists'
    Click-Setting 'Terminal details'
    Wait-Until { (Read-Session).tabs[0].cv } 'existing chat view choice restored'
    $result.checks += @{ name = 'settings-existing-terminal-choice'; passed = $true; restoredChat = $true }

    Fill-SettingKey 'Dictation key' 'settings-cancelled' -Cancel
    Fill-SettingKey 'Screencast2 upload key' 'settings-cancelled' -Cancel
    if ((Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -cne 'settings-dictation-before' -or
        (Get-Content -LiteralPath $uploadConfig -Raw) -notmatch 'upload_secret = "settings-upload-before"') { throw 'Cancelling a key dialog changed its existing store' }
    $result.checks += @{ name = 'settings-key-cancel'; passed = $true; unchangedStores = 2 }
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
    Fill-SettingKey 'Dictation key' '-reloaded' -Append
    Fill-SettingKey 'Screencast2 upload key' '-reloaded' -Append
    Wait-Until { (Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -ceq 'settings-dictation-after-reloaded' } 'reopened dictation field loaded its existing value'
    Wait-Until { (Get-Content -LiteralPath $uploadConfig -Raw) -match 'upload_secret = "settings-upload-after-reloaded"' } 'reopened upload field loaded its existing value'
    $result.checks += @{ name = 'settings-reopen-existing-values'; passed = $true; reloadedKeys = 2 }
    Press @(0x1B) 'Escape: close Settings'
    Wait-Until { -not [VerifyNative]::IsWindowVisible($script:settingsWindow) } 'Settings dismissed with Escape'
    Wait-ChatFocus 'Edit' 'settings-focus-restored'
    Open-Settings
    Assert-Foreground
    [VerifyNative]::ClickClient($script:settingsWindow, 4, 4)
    Wait-Until { -not [VerifyNative]::IsWindowVisible($script:settingsWindow) } 'clicking the dimmed content dismisses Settings'
    Wait-ChatFocus 'Edit' 'settings-outside-focus-restored'
    $result.checks += @{ name = 'settings-outside-dismissal'; passed = $true }
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
