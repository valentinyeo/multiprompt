$check = @{ name = 'skill-menu-links'; passed = $false; fixture = 'plain-proof + valentin-mode junction under the isolated USERPROFILE' }
$result.checks += $check
$editCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'Edit')
$transcriptCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'ZigShellChatTranscript')
Press @(0x12, 0x43) 'Alt+C: open Chat View on the initial CMD session'
Wait-Until {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:window)
    $script:skillEdit = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $editCondition)
    $script:skillTranscript = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $transcriptCondition)
    $null -ne $script:skillEdit -and $null -ne $script:skillTranscript -and -not $script:skillEdit.Current.IsOffscreen
} 'owned Chat View composer is visible' 30
$edit = [IntPtr]$script:skillEdit.Current.NativeWindowHandle
if ([VerifyNative]::GetAncestor($edit, 2) -ne $script:window -or [VerifyNative]::Class($edit) -cne 'Edit') { throw 'Skill menu composer is not owned by the verified app' }
[VerifyNative]::ClickClient($edit, 8, 8)
$log = Join-Path $scratch 'roaming/ZigShell/debug.log'
$start = (Read-SharedText $log).Length
Press @(0x11, 0x4B) 'Ctrl+K: open command palette'
Retry-PaletteOpen $log $start
Type-Text 'skills'
Wait-Until {
    $rows = [regex]::Matches((Read-SharedText $log).Substring($start), '\[palette\] rows chars=6 count=\d+ ids=([^\r\n]+)')
    $rows.Count -gt 0 -and @($rows[$rows.Count - 1].Groups[1].Value.Trim() -split ' ') -contains '6308'
} 'command palette lists the Skills menu' 20
Press @(0x0D) 'Enter: open the Skills list'
$skillsOffset = (Read-SharedText $log).Length
Wait-Until {
    $rows = [regex]::Matches((Read-SharedText $log).Substring($skillsOffset), '\[palette\] rows chars=0 count=\d+ ids=([^\r\n]+)')
    if ($rows.Count -eq 0) { return $false }
    @($rows[$rows.Count - 1].Groups[1].Value.Trim() -split ' ' | Where-Object { [int]$_ -ge 4100 -and [int]$_ -lt 4300 }).Count -ge 2
} 'Skills list shows both discovered skill folders' 20
Snapshot 'skill-menu-skills'
Type-Text 'valentin'
Wait-Until {
    $rows = [regex]::Matches((Read-SharedText $log).Substring($skillsOffset), '\[palette\] rows chars=8 count=\d+ ids=([^\r\n]+)')
    if ($rows.Count -eq 0) { return $false }
    $ids = @($rows[$rows.Count - 1].Groups[1].Value.Trim() -split ' ' | Where-Object { [int]$_ -ge 4100 -and [int]$_ -lt 4300 })
    $ids.Count -eq 1
} 'filtered Skills list shows only the linked skill folder' 20
Snapshot 'skill-menu-linked'
Press @(0x0D) 'Enter: choose the linked valentin-mode skill'
Wait-Until { [VerifyNative]::EditText($edit) -ceq '/valentin-mode ' } 'composer holds the linked skill name' 20
Snapshot 'action'
Press @(0x11, 0x41) 'Ctrl+A: select the inserted skill name'
Press @(0x08) 'Backspace: clear the composer draft'
Wait-Until { [VerifyNative]::EditText($edit) -ceq '' } 'composer draft cleared'
Snapshot 'after'
$check.passed = $true
$check.composer = '/valentin-mode '
$check.linked = 'valentin-mode'
$check.plain = 'plain-proof'
Save-Json $check 'skill-menu.json'
