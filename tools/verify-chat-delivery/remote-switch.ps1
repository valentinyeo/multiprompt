if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Remote switch proof runs only on GitHub Windows' }
Add-Type -Path "$PSScriptRoot/remote-switch.cs"
function Switch-Palette([string]$Query) {
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x4B) 'Ctrl+K: open switch proof command'
    foreach ($letter in $Query.ToCharArray()) { [ChatDeliveryDesktop]::Type([uint16][char]::ToUpperInvariant($letter)) }
    [void](Wait-For 'switch proof command selected' { (Read-Shared "$settings/debug.log").Substring($offset) -match ('\[palette\] ready chars=' + $Query.Length + ' count=1 target=\d+') })
    Press @(0x0D) 'Enter: run switch proof command'
}
[void](Wait-For 'complete long remote conversation loaded' {
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x30) 'Ctrl+0: measure loaded remote history'
    $m = [regex]::Matches((Read-Shared "$settings/debug.log").Substring($offset), '\[chatfont\] pt=\d+ blocks=(\d+) content_h=\d+')
    if ($m.Count -gt 0 -and [int]$m[$m.Count - 1].Groups[1].Value -ge 2002) { $script:switchInitialBlocks = [int]$m[$m.Count - 1].Groups[1].Value; $true }
} 120)
Bind-Transcript
Switch-Palette 'chat view select all'
Press @(0x11, 0x43) 'Ctrl+C: verify complete rendered remote history'
$copied = [Windows.Forms.Clipboard]::GetText()
[IO.File]::WriteAllText("$caseDir/long-history-copied.txt", $copied)
$messages = @([regex]::Matches($copied, 'IGSH954 message \d{4}') | ForEach-Object { $_.Value } | Select-Object -Unique)
if ($messages.Count -ne 2000 -or $messages[0] -ne 'IGSH954 message 0000' -or $messages[-1] -ne 'IGSH954 message 1999') { throw 'Long remote conversation was not completely rendered' }
Press @(0x1B) 'Esc: clear copied conversation'
Switch-Palette 'new cmd'
[void](Wait-For 'local and second-host tabs published' {
    $published = @((Get-Content "$settings/inbox-default.json" -Raw | ConvertFrom-Json).shells)
    $published.Count -eq 2 -and @($published | Where-Object { $_.kind -eq 0 }).Count -eq 1
})
$expectedShells = 2
Switch-Palette 'chat view on everywhere'
Bind-Transcript
Shell-Run @('turn', '99')
Press @(0x11, 0x09) 'Ctrl+Tab: prepare unread remote visit'
Bind-Transcript
[void](Wait-For 'new remote messages applied' {
    $offset = (Read-Shared "$settings/debug.log").Length
    Press @(0x11, 0x30) 'Ctrl+0: verify appended messages'
    $m = [regex]::Matches((Read-Shared "$settings/debug.log").Substring($offset), '\[chatfont\] pt=\d+ blocks=(\d+) content_h=\d+')
    $m.Count -gt 0 -and [int]$m[$m.Count - 1].Groups[1].Value -ge ($script:switchInitialBlocks + 2)
} 30)
[void](Scroll-Transcript 120)
[void](Scroll-Transcript -240)
Shot 'remote-switch-unread-visit'
Press @(0x11, 0x09) 'Ctrl+Tab: leave read remote visit'
Bind-Transcript
$observation.messages = $messages.Count
$observation.switches = [Collections.Generic.List[object]]::new()
function Measure-CPU([scriptblock]$Action, [int]$MinimumMs) {
    Doctor
    $app.Refresh()
    $cpuStart = $app.TotalProcessorTime.TotalMilliseconds
    $timer = [Diagnostics.Stopwatch]::StartNew()
    & $Action
    [void](Wait-For 'measurement interval completed' { $timer.ElapsedMilliseconds -ge $MinimumMs } 10)
    $elapsed = $timer.Elapsed.TotalMilliseconds
    $app.Refresh()
    $cpuMs = $app.TotalProcessorTime.TotalMilliseconds - $cpuStart
    @{elapsedMs=$elapsed; cpuMs=$cpuMs; cpuPercent=100 * $cpuMs / $elapsed}
}
function Measure-Frames([scriptblock]$Action, [int]$MinimumMs) {
    $view = [IntPtr]$views[0].Current.NativeWindowHandle
    $sampler = [RemoteSwitchFrames]::new($view, $app.Id)
    try { $sample = Measure-CPU $Action $MinimumMs }
    finally { $frames = @($sampler.Finish()); $sampler.Dispose() }
    if ($frames.Count -eq 0) { throw 'Actual transcript paint samples missing' }
    $sample.frames = $frames
    $sample
}
function Switch-Sample([int[]]$Keys, [bool]$Workspace, [bool]$Probe) {
    $offset = (Read-Shared "$settings/debug.log").Length
    $workspaceBefore = (Get-Content "$settings/session.json" -Raw | ConvertFrom-Json).active_workspace
    $action = {
        [ChatDeliveryDesktop]::Chord($Keys)
        [void](Wait-For 'switched conversation painted' { (Read-Shared "$settings/debug.log").Substring($offset) -match '\[switch\] chat painted in \d+ ms, browser pending \(shell \d+\)' } 5)
    }
    $sample = if ($Probe) { Measure-Frames $action 250 } else { Measure-CPU $action 250 }
    $log = (Read-Shared "$settings/debug.log").Substring($offset)
    $paint = [regex]::Matches($log, '\[switch\] chat painted in (\d+) ms, browser pending \(shell (\d+)\)')
    if ($paint.Count -ne 1) { throw 'Each sample requires exactly one painted session switch' }
    $sample.switchMs = [int]$paint[0].Groups[1].Value
    $sample.shell = [int]$paint[0].Groups[2].Value
    if ($Workspace) {
        if ($log -notmatch 'switchToWorkspace: \d+ -> \d+') { throw 'Each workspace sample requires an actual workspace switch' }
        $sample.workspaceBefore = $workspaceBefore
        $sample.workspaceAfter = (Get-Content "$settings/session.json" -Raw | ConvertFrom-Json).active_workspace
        if ($sample.workspaceBefore -eq $sample.workspaceAfter) { throw 'Workspace did not change' }
    }
    $sample
}
$observation.idleBefore = Measure-CPU {} 2000
for ($i = 0; $i -lt 20; $i++) {
    $sample = Switch-Sample @(0x11, 0x09) $false $false
    $sample.return = Switch-Sample @(0x11, 0x09) $false $false
    $sample.probe = Switch-Sample @(0x11, 0x09) $false $true
    $sample.mode = 'session'
    $sample.index = $i
    $observation.switches.Add($sample)
    Save $observation "$caseDir/observation.json"
}
Press @(0x11, 0x57) 'Ctrl+W: close the owned local fixture tab'
$expectedShells = 1
[void](Wait-For 'local fixture tab closed' { @((Get-Content "$settings/inbox-default.json" -Raw | ConvertFrom-Json).shells).Count -eq 1 })
Press @(0x11, 0x4E) 'Ctrl+N: create the local fixture workspace'
$expectedShells = 2
[void](Wait-For 'two distinct saved workspaces' {
    $saved = Get-Content "$settings/session.json" -Raw | ConvertFrom-Json
    $slots = @($saved.tabs | ForEach-Object { if ($_.PSObject.Properties['workspace']) { [int]$_.workspace } else { 0 } } | Select-Object -Unique)
    $saved.workspace_count -eq 2 -and @($saved.tabs).Count -eq 2 -and $slots.Count -eq 2
})
Switch-Palette 'chat view on everywhere'
Bind-Transcript
for ($i = 0; $i -lt 20; $i++) {
    $keys = if ($i % 2 -eq 0) { @(0x12, 0x25) } else { @(0x12, 0x27) }
    $reverse = if ($i % 2 -eq 0) { @(0x12, 0x27) } else { @(0x12, 0x25) }
    $sample = Switch-Sample $keys $true $false
    $sample.return = Switch-Sample $reverse $true $false
    $sample.probe = Switch-Sample $keys $true $true
    $sample.mode = 'workspace'
    $sample.index = $i
    $observation.switches.Add($sample)
    Save $observation "$caseDir/observation.json"
}
$observation.idleAfter = Measure-CPU {} 2000
Bind-Transcript
Shot 'remote-switch-complete'
Save $observation "$caseDir/observation.json"
