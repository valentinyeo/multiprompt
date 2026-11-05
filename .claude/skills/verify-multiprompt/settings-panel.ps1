Add-Type -AssemblyName UIAutomationClientsideProviders
$nativeProviders = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'UIAutomationClientsideProviders' } | Select-Object -First 1
[System.Windows.Automation.ClientSettings]::RegisterClientSideProviderAssembly($nativeProviders.GetName())

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
    for ($attempt = 0; $attempt -lt 12 -and -not $element.Current.HasKeyboardFocus; $attempt++) {
        Press @(0x09) ('Tab: bring Settings control into view: ' + $Name)
    }
    if (-not $element.Current.HasKeyboardFocus) { throw "Settings control did not receive keyboard focus: $Name" }
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
    [VerifyNative]::Text($Fixture)
    if ($Cancel) { Press @(0x1B) ('Escape: cancel isolated ' + $Name) }
    else { Click-Setting 'Save' -RootWindow $keyWindow }
    Wait-Until { -not [VerifyNative]::IsWindowVisible($keyWindow) -and (Settings-Window) -eq $script:settingsWindow } ('return to Settings after ' + $Name)
}

$environmentPath = 'HKCU:\Environment'
$originalKey = Get-ItemProperty -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY -ErrorAction SilentlyContinue
$hadKey = $null -ne $originalKey -and $null -ne $originalKey.PSObject.Properties['DEEPGRAM_API_KEY']
$oldValue = if ($hadKey) { [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment').GetValue('DEEPGRAM_API_KEY', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) } else { $null }
$oldKind = if ($hadKey) { [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment').GetValueKind('DEEPGRAM_API_KEY') } else { $null }
$uploadDir = Join-Path $env:LOCALAPPDATA 'screencast2-go'
$uploadConfig = Join-Path $uploadDir 'config.toml'
$themeFile = Join-Path $env:APPDATA 'ZigShell\theme-mode.txt'
New-Item -ItemType Directory -Force $uploadDir | Out-Null
[IO.File]::WriteAllText($uploadConfig, "[upload]`napi_base_url = `"https://example.invalid`"`nupload_secret = `"settings-upload-before`"`n[capture]`nquality = 91`n")
if (-not (Test-Path -LiteralPath $environmentPath)) { New-Item -Path $environmentPath | Out-Null }
try {
    Remove-ItemProperty -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY -ErrorAction SilentlyContinue
    Wait-Until { $state = Read-Session; $null -ne $state -and @($state.tabs).Count -gt 0 } 'initial existing session saved'
    $initial = Read-Session
    if ($initial.tabs[0].PSObject.Properties['cv'] -and $initial.tabs[0].cv) { throw 'Expected the initial terminal before key editing' }
    Open-Settings
    $null = Settings-Control 'Dictation key'
    Fill-SettingKey 'Dictation key' 'settings-cancelled' -Cancel
    if (Get-ItemProperty -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY -ErrorAction SilentlyContinue) { throw 'Cancelling an unset key configured it' }
    Snapshot 'settings-key-unset'
    Add-Type -AssemblyName System.Windows.Forms
    Click-Setting 'Dictation key'
    Wait-Until { (Settings-KeyWindow) -ne [IntPtr]::Zero } 'dictation key sheet'
    $keyWindow = Settings-KeyWindow
    [System.Windows.Forms.Clipboard]::SetText(('Token: "' + ('A' * 40) + '"'))
    Press @(0x11, 0x41) 'Select key'
    Press @(0x11, 0x56) 'Paste wrapped synthetic key'
    Click-Setting 'Save' -RootWindow $keyWindow
    Wait-Until { -not [VerifyNative]::IsWindowVisible($keyWindow) } 'wrapped key saved'
    if ((Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -cne ('a' * 40)) { throw 'Wrapped key was not normalized before persistence' }
    [System.Windows.Forms.Clipboard]::Clear()
    $result.checks += @{ name = 'settings-key-normalization'; passed = $true }

    Fill-SettingKey 'Dictation key' 'settings-dictation-before-zzzzzzzzzz'
    Wait-Until { (Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -ceq 'settings-dictation-before-zzzzzzzzzz' } 'dictation key replaced without Chat View'
    foreach ($mode in @('401', '403')) {
        [IO.File]::WriteAllText((Join-Path $script:keyProviderDir 'mode.txt'), $mode)
        Click-Setting 'Dictation key'
        Wait-Until { (Settings-KeyWindow) -ne [IntPtr]::Zero } 'key sheet for rejection'
        $keyWindow = Settings-KeyWindow
        Press @(0x11, 0x41) 'Select key for rejection'
        [VerifyNative]::Text('settings-rejected-zzzzzzzzzzzzzzzzzz')
        Click-Setting 'Save' -RootWindow $keyWindow
        Wait-Until { $null -ne (Settings-Control 'Deepgram rejected this key.' -Type ([System.Windows.Automation.ControlType]::Text) -RootWindow $keyWindow) } 'inline rejection'
        if ((Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -cne 'settings-dictation-before-zzzzzzzzzz') { throw 'Rejected key changed the stored key' }
        Snapshot ('settings-key-rejected-' + $mode)
        [IO.File]::WriteAllText((Join-Path $script:keyProviderDir 'mode.txt'), '400')
        $edit = ([System.Windows.Automation.AutomationElement]::FromHandle($keyWindow)).FindFirst([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Edit)))
        [VerifyNative]::ClickClient([IntPtr]$edit.Current.NativeWindowHandle, 8, 8)
        Press @(0x11, 0x41) 'Correct rejected key'
        $correctedKey = 'settings-corrected-' + $mode + '-zzzzzzzzzzzzzzzzzz'
        [VerifyNative]::Text($correctedKey)
        Click-Setting 'Save' -RootWindow $keyWindow
        Wait-Until { -not [VerifyNative]::IsWindowVisible($keyWindow) } 'corrected key saved'
        if ((Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -cne $correctedKey) { throw 'Corrected key was not persisted' }
        Fill-SettingKey 'Dictation key' 'settings-dictation-before-zzzzzzzzzz'
        if ((Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -cne 'settings-dictation-before-zzzzzzzzzz') { throw 'Baseline key was not restored through Settings' }
    }
    Click-Setting 'Dictation key'
    Wait-Until { (Settings-KeyWindow) -ne [IntPtr]::Zero } 'key sheet for malformed key'
    $keyWindow = Settings-KeyWindow
    Press @(0x11, 0x41) 'Select key for malformed input'
    [VerifyNative]::Text('short')
    Click-Setting 'Save' -RootWindow $keyWindow
    Wait-Until { $null -ne (Settings-Control 'Enter a valid dictation key.' -Type ([System.Windows.Automation.ControlType]::Text) -RootWindow $keyWindow) } 'inline format error'
    if ((Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -cne 'settings-dictation-before-zzzzzzzzzz') { throw 'Malformed key changed the stored key' }
    Snapshot 'settings-key-malformed'
    Press @(0x1B) 'Cancel malformed key'
    Wait-Until { (Settings-Window) -eq $script:settingsWindow } 'return after malformed key'
    foreach ($mode in @('429', '503', 'offline')) {
        [IO.File]::WriteAllText((Join-Path $script:keyProviderDir 'mode.txt'), $mode)
        $requestsBeforeUnknown = [int](Get-Content (Join-Path $script:keyProviderDir 'requests.txt') -Raw)
        Fill-SettingKey 'Dictation key' 'settings-unknown-zzzzzzzzzzzzzzzzzz'
        if ([int](Get-Content (Join-Path $script:keyProviderDir 'requests.txt') -Raw) -ne ($requestsBeforeUnknown + 1)) { throw 'Unknown case did not reach offline provider' }
        if ((Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -cne 'settings-unknown-zzzzzzzzzzzzzzzzzz') { throw 'Unknown provider result did not save key' }
    }
    [IO.File]::WriteAllText((Join-Path $script:keyProviderDir 'mode.txt'), 'redirect')
    Fill-SettingKey 'Dictation key' 'settings-redirect-zzzzzzzzzzzzzzzzzz'
    if ([int](Get-Content (Join-Path $script:keyProviderDir 'redirects-sent.txt') -Raw) -ne 1) { throw 'Redirect response was not sent' }
    if ([int](Get-Content (Join-Path $script:keyProviderDir 'redirect-targets.txt') -Raw) -ne 0 -or (Get-Content (Join-Path $script:keyProviderDir 'redirect-authorization.txt') -Raw).Trim() -ne 'false') { throw 'Key check followed the redirect' }
    if ((Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -cne 'settings-redirect-zzzzzzzzzzzzzzzzzz') { throw 'Redirect status did not follow Android save policy' }
    [IO.File]::WriteAllText((Join-Path $script:keyProviderDir 'mode.txt'), '400')
    Fill-SettingKey 'Dictation key' 'settings-dictation-before-zzzzzzzzzz'
    $longKey = 'z' * 512
    Fill-SettingKey 'Dictation key' $longKey
    if ((Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -cne $longKey) { throw 'Maximum length key was not persisted intact' }
    if ([int](Get-Content (Join-Path $script:keyProviderDir 'length.txt') -Raw) -ne 512) { throw 'Maximum length key did not reach the provider intact' }
    Click-Setting 'Dictation key'
    Wait-Until { (Settings-KeyWindow) -ne [IntPtr]::Zero } 'maximum length key reopened'
    $keyWindow = Settings-KeyWindow
    Press @(0x23) 'End of reloaded maximum length key'
    Press @(0x08) 'Remove one character from reloaded key'
    Click-Setting 'Save' -RootWindow $keyWindow
    Wait-Until { -not [VerifyNative]::IsWindowVisible($keyWindow) } 'reloaded long key saved'
    if ((Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -cne ('z' * 511)) { throw 'Maximum length key did not reload intact' }

    Fill-SettingKey 'Dictation key' 'settings-dictation-before-zzzzzzzzzz'
    [IO.File]::WriteAllText((Join-Path $script:keyProviderDir 'mode.txt'), '400:3000')
    $requestsBeforeDelay = if (Test-Path (Join-Path $script:keyProviderDir 'requests.txt')) { [int](Get-Content (Join-Path $script:keyProviderDir 'requests.txt') -Raw) } else { 0 }
    Click-Setting 'Dictation key'
    Wait-Until { (Settings-KeyWindow) -ne [IntPtr]::Zero } 'key sheet for cancel race'
    $keyWindow = Settings-KeyWindow
    Press @(0x11, 0x41) 'Select key for delayed request'
    [VerifyNative]::Text('settings-delayed-zzzzzzzzzzzzzzzzzzz')
    Click-Setting 'Save' -RootWindow $keyWindow
    Wait-Until { -not (Settings-Control 'Save' -RootWindow $keyWindow).Current.IsEnabled } 'Save disabled while checking'
    Wait-Until { [int](Get-Content (Join-Path $script:keyProviderDir 'requests.txt') -Raw) -gt $requestsBeforeDelay } 'delayed provider request received'
    $saveControl = Settings-Control 'Save' -RootWindow $keyWindow
    $saveHandle = [IntPtr]$saveControl.Current.NativeWindowHandle
    $saveRect = New-Object VerifyNative+Rect
    $keyOrigin = New-Object VerifyNative+Point
    if (-not [VerifyNative]::GetWindowRect($saveHandle, [ref]$saveRect) -or -not [VerifyNative]::ClientToScreen($keyWindow, [ref]$keyOrigin)) { throw 'Missing disabled Save geometry' }
    if ($saveControl.Current.IsEnabled) { throw 'Save became enabled before duplicate click' }
    [VerifyNative]::ClickClient($keyWindow, [int](($saveRect.Left + $saveRect.Right) / 2 - $keyOrigin.X), [int](($saveRect.Top + $saveRect.Bottom) / 2 - $keyOrigin.Y))
    Start-Sleep -Milliseconds 200
    if ([int](Get-Content (Join-Path $script:keyProviderDir 'requests.txt') -Raw) -ne ($requestsBeforeDelay + 1)) { throw 'Duplicate save sent another request' }
    Press @(0x1B) 'Cancel delayed request'
    Wait-Until { (Settings-Window) -eq $script:settingsWindow } 'cancel returns immediately'
    [IO.File]::WriteAllText((Join-Path $script:keyProviderDir 'mode.txt'), '400')
    Fill-SettingKey 'Dictation key' 'settings-corrected-zzzzzzzzzzzzzzzzz'
    Start-Sleep -Seconds 4
    if ((Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -cne 'settings-corrected-zzzzzzzzzzzzzzzzz') { throw 'Cancelled request overwrote the later key' }
    Fill-SettingKey 'Dictation key' 'settings-dictation-before-zzzzzzzzzz'
    foreach ($closeMethod in @('button', 'alt-f4')) {
        [IO.File]::WriteAllText((Join-Path $script:keyProviderDir 'mode.txt'), '400:4000')
        $requestsBeforeClose = [int](Get-Content (Join-Path $script:keyProviderDir 'requests.txt') -Raw)
        Click-Setting 'Dictation key'
        Wait-Until { (Settings-KeyWindow) -ne [IntPtr]::Zero } 'key sheet for close race'
        $keyWindow = Settings-KeyWindow
        Press @(0x11, 0x41) 'Select key for close race'
        [VerifyNative]::Text('settings-close-race-zzzzzzzzzzzzzzzz')
        Click-Setting 'Save' -RootWindow $keyWindow
        Wait-Until { [int](Get-Content (Join-Path $script:keyProviderDir 'requests.txt') -Raw) -eq ($requestsBeforeClose + 1) } 'close race request received'
        if ($closeMethod -eq 'button') { Click-Setting 'Cancel' -RootWindow $keyWindow }
        else { Press @(0x12, 0x73) 'Alt+F4: close pending key sheet' }
        Wait-Until { (Settings-Window) -eq $script:settingsWindow } 'close pending key sheet'
        Click-Setting 'Dictation key'
        Wait-Until { (Settings-KeyWindow) -ne [IntPtr]::Zero } 'reopen key sheet without submitting'
        $idleWindow = Settings-KeyWindow
        if ((Test-Path (Join-Path $script:keyProviderDir 'delayed-completed.txt')) -and [int](Get-Content (Join-Path $script:keyProviderDir 'delayed-completed.txt') -Raw) -eq ($requestsBeforeClose + 1)) { throw 'Key sheet reopened after the delayed completion' }
        Wait-Until { (Test-Path (Join-Path $script:keyProviderDir 'delayed-completed.txt')) -and [int](Get-Content (Join-Path $script:keyProviderDir 'delayed-completed.txt') -Raw) -eq ($requestsBeforeClose + 1) } 'cancelled worker response sent'
        Start-Sleep -Milliseconds 500
        if ((Settings-KeyWindow) -ne $idleWindow -or -not [VerifyNative]::IsWindowVisible($idleWindow) -or -not (Settings-Control 'Save' -RootWindow $idleWindow).Current.IsEnabled) { throw 'Late completion changed the reopened key sheet' }
        if ((Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -cne 'settings-dictation-before-zzzzzzzzzz') { throw 'Closed request changed the stored key' }
        Press @(0x23) 'End of idle reloaded key'
        [VerifyNative]::Text('-idle')
        [IO.File]::WriteAllText((Join-Path $script:keyProviderDir 'mode.txt'), '400')
        Click-Setting 'Save' -RootWindow $idleWindow
        Wait-Until { (Settings-Window) -eq $script:settingsWindow } 'save idle reloaded key'
        if ((Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -cne 'settings-dictation-before-zzzzzzzzzz-idle') { throw 'Late completion changed the reopened field' }
        Fill-SettingKey 'Dictation key' 'settings-dictation-before-zzzzzzzzzz'
    }
    [IO.File]::WriteAllText((Join-Path $script:keyProviderDir 'mode.txt'), '400')
    if (Test-Path (Join-Path $script:keyProviderDir 'invalid.txt')) { throw 'Offline provider received an invalid request' }
    $result.checks += @{ name = 'settings-key-validation'; passed = $true; rejected = @('401','403'); unknown = @('429','503','offline'); redirectTargetRequests = 0; cancelRace = $true; idleReopen = @('button','alt-f4') }
    $initial = Read-Session
    if ($initial.tabs[0].PSObject.Properties['cv'] -and $initial.tabs[0].cv) { throw 'Editing Settings keys opened Chat View' }
    Snapshot 'settings-key-replaced-terminal'
    $result.checks += @{ name = 'settings-key-outside-chat'; passed = $true; unsetCancelPreserved = $true; savedAndReplaced = $true; chatOpened = $false }
    Click-Setting 'Close Settings'
    Wait-Until { -not [VerifyNative]::IsWindowVisible($script:settingsWindow) } 'Settings key proof returned to the terminal'
    $session = Read-Session
    if (-not ($session.tabs[0].PSObject.Properties['cv'] -and $session.tabs[0].cv)) {
        Press @(0x12, 0x43) 'Alt+C: show the chat behind Settings'
        Wait-Until { $state = Read-Session; $state.tabs[0].PSObject.Properties['cv'] -and $state.tabs[0].cv } 'chat visible behind Settings'
    }
    Snapshot 'settings-backdrop'
    Open-Settings
    Snapshot 'settings-panel'
    Snapshot 'action'
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
    foreach ($name in @('Theme', 'Small', 'Normal', 'Large', 'Terminal details', 'Dictation key', 'Screencast2 upload key', 'Release notes', 'Close Settings')) {
        Press @(0x09) ('Tab: focus ' + $name)
        Wait-Until { (Settings-Control $name).Current.HasKeyboardFocus } ('native tab focus: ' + $name)
    }
    Press @(0x10, 0x09) 'Shift+Tab: previous Settings control'
    Wait-Until { (Settings-Control 'Release notes').Current.HasKeyboardFocus } 'native reverse tab focus'
    Press @(0x09) 'Tab: return to round close control'
    $result.checks += @{ name = 'settings-native-focus-order'; passed = $true; tabControls = 9; reverseTab = $true }

    if ((Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -cne 'settings-dictation-before-zzzzzzzzzz' -or
        (Get-Content -LiteralPath $uploadConfig -Raw) -notmatch 'upload_secret = "settings-upload-before"') { throw 'Opening Settings changed existing keys' }
    $result.checks += @{ name = 'settings-opening-keeps-keys'; passed = $true }


    foreach ($theme in @(@{ name = 'Light'; value = 'light'; index = 3 }, @{ name = 'Mid'; value = 'mid'; index = 2 }, @{ name = 'AMOLED'; value = 'amoled'; index = 4 }, @{ name = 'Edge gray'; value = 'edgegray'; index = 5 }, @{ name = 'Multiprompt'; value = 'multiprompt'; index = 6 }, @{ name = 'System'; value = 'system'; index = 0 }, @{ name = 'Dark'; value = 'dark'; index = 1 })) {
        Click-Setting 'Theme'
        Press @(0x28) 'Down: enter the native theme list'
        Press @(0x24) 'Home: first existing theme'
        for ($step = 0; $step -lt $theme.index; $step++) { Press @(0x28) 'Down: existing theme choice' }
        Press @(0x0D) ('Enter: select ' + $theme.name)
        Wait-Until { (Test-Path -LiteralPath $themeFile) -and (Get-Content -LiteralPath $themeFile -Raw).Trim() -eq $theme.value } ('persisted existing theme: ' + $theme.name)
        $result.checks += @{ name = ('settings-theme-' + $theme.value); passed = $true; savedTheme = $theme.value }
    }
    Click-Setting 'Terminal details'
    Wait-Until { $state = Read-Session; -not ($state.tabs[0].PSObject.Properties['cv'] -and $state.tabs[0].cv) } 'existing terminal view choice saved'
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
    if ((Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -cne 'settings-dictation-before-zzzzzzzzzz' -or
        (Get-Content -LiteralPath $uploadConfig -Raw) -notmatch 'upload_secret = "settings-upload-before"') { throw 'Cancelling a key dialog changed its existing store' }
    $result.checks += @{ name = 'settings-key-cancel'; passed = $true; unchangedStores = 2 }
    Fill-SettingKey 'Dictation key' 'settings-dictation-after-zzzzzzzzzz'
    Wait-Until { (Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -ceq 'settings-dictation-after-zzzzzzzzzz' } 'dictation key persisted in its existing registry value'
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
    Wait-Until { (Get-ItemPropertyValue -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY) -ceq 'settings-dictation-after-zzzzzzzzzz-reloaded' } 'reopened dictation field loaded its existing value'
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
    Snapshot 'after'
    $result.checks += @{ name = 'settings-release-notes'; passed = $true }
    Save-Json @{ status = 'passed'; checks = @($result.checks | Where-Object { $_.name -like 'settings-*' }); screenshot = 'settings-panel.png' } 'settings-panel-proof.json'
} finally {
    if ($hadKey) { $registry = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true); try { $registry.SetValue('DEEPGRAM_API_KEY', $oldValue, $oldKind) } finally { $registry.Dispose() } }
    else { Remove-ItemProperty -LiteralPath $environmentPath -Name DEEPGRAM_API_KEY -ErrorAction SilentlyContinue }
}
