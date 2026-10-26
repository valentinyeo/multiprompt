$captures = @()
function Save-SkillPill([string]$Name, [string]$Theme, [IntPtr]$Control, [bool]$Expected) {
    Snapshot $Name
    $frame = New-Object VerifyNative+Rect
    $client = New-Object VerifyNative+Rect
    $origin = New-Object VerifyNative+Point
    if (-not [VerifyNative]::GetWindowRect($script:window, [ref]$frame) -or -not [VerifyNative]::GetClientRect($Control, [ref]$client) -or -not [VerifyNative]::ClientToScreen($Control, [ref]$origin)) { throw 'Skill pill control geometry unavailable' }
    [VerifyNative]::Bmp((Join-Path $Evidence ($Name + '.png')), (Join-Path $Evidence ($Name + '.bmp')))
    return @{ name = $Name; theme = $Theme; expected = $Expected; rect = @{ left = $origin.X + $client.Left - $frame.Left; top = $origin.Y + $client.Top - $frame.Top; right = $origin.X + $client.Right - $frame.Left; bottom = $origin.Y + $client.Bottom - $frame.Top } }
}
foreach ($theme in @('dark', 'light')) {
    Select-Theme $theme ('skill-theme-' + $theme)
    $beforeTabs = @((Read-Session).tabs).Count
    Palette 'new cmd'
    Press @(0x0D) 'Enter: new isolated shell for skill colors'
    Wait-Until {
        $state = Read-Session
        @($state.tabs).Count -eq $beforeTabs + 1 -and $state.tabs[$state.active_tab].kind -eq 'cmd'
    } 'fresh CMD tab saved'
    $state = Read-Session
    Wait-WorkspaceSurface $state.active_workspace $state.active_tab $false
    $ready = Join-Path $scratch ($theme + '-skill-console-ready.txt')
    Type-Text ('echo ready>"' + $ready + '"')
    Press @(0x0D) 'Enter: verify the new console accepts real keyboard input'
    Wait-Until { (Test-Path $ready) -and (Get-Content $ready -Raw).Trim() -eq 'ready' } 'new console executed readiness command'
    Press @(0x12, 0x43) 'Alt+C: open Chat View'
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    $editCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
    $transcriptCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
    Wait-Until {
        $script:pillEdit = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $editCondition)
        $script:pillTranscript = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $transcriptCondition)
        $null -ne $script:pillEdit -and $null -ne $script:pillTranscript -and -not $script:pillEdit.Current.IsOffscreen
    } 'owned composer and transcript visible'
    $edit = [IntPtr]$script:pillEdit.Current.NativeWindowHandle
    $thread = [IntPtr]$script:pillTranscript.Current.NativeWindowHandle
    foreach ($control in @($edit, $thread)) {
        if ([VerifyNative]::GetAncestor($control, 2) -ne $script:window) { throw 'Skill pill surface belongs to another window' }
    }
    [VerifyNative]::ClickClient($edit, 8, 8)
    Assert-ChatTyping '/not-a-real-skill arguments stay normal' ($theme + '-unknown')
    $captures += Save-SkillPill ($theme + '-unknown-draft') $theme $edit $false
    Press @(0x11, 0x41) 'Ctrl+A: replace unknown slash text'
    Press @(0x08) 'Backspace: clear unknown slash text'
    Assert-ChatTyping 'ordinary message without a skill' ($theme + '-plain')
    $captures += Save-SkillPill ($theme + '-plain-draft') $theme $edit $false
    Press @(0x11, 0x0D) 'Ctrl+Enter: send ordinary message'
    Wait-Until { [VerifyNative]::EditText($edit) -ceq '' } 'ordinary message left composer'
    $captures += Save-SkillPill ($theme + '-plain-sent') $theme $thread $false
    Assert-ChatTyping '/pill-proof arguments stay normal' ($theme + '-skill')
    $captures += Save-SkillPill ($theme + '-skill-draft') $theme $edit $true
    if ($theme -eq 'dark') { Snapshot 'action' }
    Press @(0x11, 0x0D) 'Ctrl+Enter: send known skill message'
    Wait-Until { [VerifyNative]::EditText($edit) -ceq '' } 'known skill message left composer'
    $captures += Save-SkillPill ($theme + '-skill-sent') $theme $thread $true
}
Snapshot 'after'
Save-Json @{ captures = $captures; boundary = 'A real discovered skill file in the isolated home, native keyboard input and local CMD delivery; no external AI provider or remote skill execution.' } 'skill-pill.json'
& node (Join-Path $PSScriptRoot '../../../tools/chat-skill-pill-proof.mjs') $Evidence
$summary = Get-Content (Join-Path $Evidence 'skill-pill-summary.json') -Raw | ConvertFrom-Json
$result.checks += @{ name = 'IGSH-928 skill pill pixels'; passed = $summary.passed; captures = $summary.checks }
if ($LASTEXITCODE -ne 0 -or -not $summary.passed) { throw 'IGSH-928 skill pill pixels failed' }
