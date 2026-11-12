Add-Type -AssemblyName UIAutomationClientsideProviders
$nativeProviders = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'UIAutomationClientsideProviders' } | Select-Object -First 1
[System.Windows.Automation.ClientSettings]::RegisterClientSideProviderAssembly($nativeProviders.GetName())

$serverProcess = $null
$dependencyRoot = Join-Path $env:RUNNER_TEMP ('servers-python-' + [guid]::NewGuid().ToString('N'))
$serverRoot = Join-Path $scratch 'disposable-server'
$keyRoot = Join-Path $env:APPDATA 'ZigShell/ssh-key'
$oldPythonPath = $env:PYTHONPATH

function Servers-Window([string]$Class) {
    $candidate = [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2)
    [uint32]$ownerPid = 0
    [void][VerifyNative]::GetWindowThreadProcessId($candidate, [ref]$ownerPid)
    if ($ownerPid -eq $process.Id -and [VerifyNative]::Class($candidate) -eq $Class) { return $candidate }
    return [IntPtr]::Zero
}

function Servers-Control([string]$Id, [string]$Name = '') {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle([VerifyNative]::GetForegroundWindow())
    $property = if ($Name) { [System.Windows.Automation.AutomationElement]::NameProperty } else { [System.Windows.Automation.AutomationElement]::AutomationIdProperty }
    $value = if ($Name) { $Name } else { $Id }
    $condition = New-Object System.Windows.Automation.PropertyCondition($property, $value)
    $element = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
    if ($null -eq $element -or $element.Current.ProcessId -ne $process.Id) { throw "Missing owned Servers control: $value" }
    return $element
}

function Servers-Click([string]$Id, [string]$Name = '') {
    Assert-Foreground
    $element = Servers-Control $Id $Name
    if ((Servers-Window 'MultipromptSettings') -ne [IntPtr]::Zero) {
        for ($attempt = 0; $attempt -lt 16 -and -not $element.Current.HasKeyboardFocus; $attempt++) {
            Press @(0x09) ('Tab: bring Settings control into view: ' + $Name)
        }
        if (-not $element.Current.HasKeyboardFocus) { throw "Settings control did not receive keyboard focus: $Name" }
    }
    if (-not $element.Current.IsEnabled -or $element.Current.IsOffscreen) { throw 'Servers control is not usable' }
    $rect = New-Object VerifyNative+Rect
    $handle = [IntPtr]$element.Current.NativeWindowHandle
    if (-not [VerifyNative]::GetClientRect($handle, [ref]$rect)) { throw 'Servers control has no rectangle' }
    [VerifyNative]::ClickClient($handle, [int](($rect.Right - $rect.Left) / 2), [int](($rect.Bottom - $rect.Top) / 2))
}

function Servers-Text {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($script:serversWindow)
    $nodes = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    return (@($nodes | ForEach-Object { $_.Current.Name }) -join "`n")
}

function Servers-Ready {
    return (Servers-Control '320').Current.IsEnabled
}

try {
    & python -m pip install --disable-pip-version-check --target $dependencyRoot 'paramiko==3.5.1'
    if ($LASTEXITCODE -ne 0) { throw 'Disposable SSH protocol server dependency failed' }
    $env:PYTHONPATH = $dependencyRoot
    New-Item -ItemType Directory -Force $serverRoot | Out-Null
    $bash = 'C:\Program Files\Git\bin\bash.exe'
    if (-not (Test-Path $bash)) { throw 'Git Bash is required for the disposable POSIX server home' }
    $serverScript = (Resolve-Path (Join-Path $PSScriptRoot '../../../tools/verify-servers/server.py')).Path
    $serverProcess = Start-Process -FilePath (Get-Command python.exe).Source -ArgumentList @(('"' + $serverScript + '"'), ('"' + $serverRoot + '"'), ('"' + $bash + '"')) -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $Evidence 'server.stdout.log') -RedirectStandardError (Join-Path $Evidence 'server.stderr.log')
    Wait-Until {
        $portPath = Join-Path $serverRoot 'port.txt'
        (Test-Path $portPath) -and [IO.File]::ReadAllText($portPath) -match '^\d{1,5}$'
    } 'disposable loopback SSH protocol server port' 30
    $port = (Get-Content (Join-Path $serverRoot 'port.txt') -Raw).Trim()
    if ($port -notmatch '^\d{1,5}$') { throw 'Invalid disposable server port' }

    Press @(0x11, 0xBC) 'Ctrl+Comma: Settings'
    Wait-Until { (Servers-Window 'MultipromptSettings') -ne [IntPtr]::Zero } 'Settings'
    Servers-Click '' 'Servers'
    Wait-Until { (Servers-Window 'MultipromptSettingsServers') -ne [IntPtr]::Zero } 'Servers from Settings'
    $script:serversWindow = Servers-Window 'MultipromptSettingsServers'
    Wait-Until { Servers-Ready } 'key creation completed'
    if ((Servers-Text) -match 'Connected') { throw 'Isolated profile unexpectedly has a connected server' }
    Snapshot 'servers-settings'
    Servers-Click '2'
    Wait-Until { (Servers-Window 'MultipromptSettings') -ne [IntPtr]::Zero } 'back to Settings'
    Press @(0x1B) 'Escape: close Settings'
    Wait-Until { [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window } 'main window after Settings'
    Palette 'Servers' '4004'
    Press @(0x0D) 'Enter: Servers from Ctrl+K'
    Wait-Until { (Servers-Window 'MultipromptSettingsServers') -ne [IntPtr]::Zero } 'Servers from Ctrl+K'
    $script:serversWindow = Servers-Window 'MultipromptSettingsServers'
    Wait-Until { Servers-Ready } 'Servers ready'
    $result.checks += @{ name = 'servers-both-entry-points'; passed = $true }

    $timer = [Diagnostics.Stopwatch]::StartNew()
    $values = @('Disposable server', '127.0.0.1', 'verify', $port)
    for ($i = 0; $i -lt $values.Count; $i++) {
        Servers-Click ([string](330 + $i))
        Type-Text $values[$i]
    }
    Servers-Click '320'
    Wait-Until { (Servers-Ready) -and (Servers-Text) -match 'Needs setup' } 'added server needs one-time setup'
    Servers-Click '300'
    Wait-Until { (Servers-Ready) -and (Servers-Text) -match 'Failed: the key is not on the server yet' } 'plain missing-key error before setup'
    Snapshot 'servers-missing-key'
    $result.checks += @{ name = 'servers-plain-failure'; passed = $true }
    $paste = [VerifyNative]::EditText([IntPtr](Servers-Control '334').Current.NativeWindowHandle)
    if (-not $paste.StartsWith('umask 077 && mkdir -p ~/.ssh')) { throw 'Missing server setup line' }
    $pasteProcess = New-Object Diagnostics.Process
    $pasteProcess.StartInfo.FileName = $bash
    $pasteProcess.StartInfo.Arguments = '--noprofile --norc -s'
    $pasteProcess.StartInfo.UseShellExecute = $false
    $pasteProcess.StartInfo.CreateNoWindow = $true
    $pasteProcess.StartInfo.RedirectStandardInput = $true
    $pasteProcess.StartInfo.EnvironmentVariables['HOME'] = $serverRoot.Replace('\', '/')
    [void]$pasteProcess.Start()
    try {
        $pasteProcess.StandardInput.WriteLine($paste)
        $pasteProcess.StandardInput.Close()
        if (-not $pasteProcess.WaitForExit(10000)) { $pasteProcess.Kill(); throw 'One-time paste timed out' }
        if ($pasteProcess.ExitCode -ne 0) { throw 'One-time paste failed' }
    } finally { $pasteProcess.Dispose() }
    Servers-Click '300'
    Wait-Until { (Servers-Ready) -and (Servers-Text) -match 'Connected\. Multibot signs in with its own key\.' } 'own-key connected after paste'
    $timer.Stop()
    $seconds = $timer.Elapsed.TotalSeconds
    if ($seconds -ge 120) { throw "Add-to-connected exceeded two minutes: $seconds seconds" }
    Snapshot 'action'
    $ssh = Join-Path $env:WINDIR 'System32/OpenSSH/ssh.exe'
    $key = Join-Path $keyRoot 'multibot_ed25519'
    $probeArgs = @('-F', 'none', '-n', '-i', $key, '-o', 'IdentitiesOnly=yes', '-o', 'IdentityAgent=none', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=5', '-p', $port, 'verify@127.0.0.1', 'true')
    & $ssh @probeArgs 2>&1 | Out-File (Join-Path $Evidence 'before-remove-probe.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Positive control: real OpenSSH did not authenticate with the app key' }
    $result.checks += @{ name = 'servers-add-test'; passed = $true; seconds = $seconds; budgetSeconds = 120; realOpenSsh = $true }

    Servers-Click '310'
    Wait-Until { (Servers-Window 'MultiPromptDialog') -ne [IntPtr]::Zero } 'removal confirmation'
    Press @(0x27) 'Right: select Remove, not Cancel'
    Press @(0x0D) 'Enter: confirm disposable-server removal'
    Wait-Until { (Servers-Window 'MultipromptSettingsServers') -ne [IntPtr]::Zero -and (Servers-Ready) -and (Servers-Text) -match "Removed\. Multibot's key is off that server\." } 'removal reports remote revocation'
    $ErrorActionPreference = 'Continue'
    try {
        & $ssh @probeArgs 2>&1 | Out-File (Join-Path $Evidence 'after-remove-probe.txt')
        $revokedExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = 'Stop' }
    if ($revokedExit -ne 255 -or (Get-Content (Join-Path $Evidence 'after-remove-probe.txt') -Raw) -notmatch 'Permission denied') { throw 'Revoked key must fail authentication, not merely lose its connection' }
    if ([IO.File]::ReadAllText((Join-Path $serverRoot '.ssh/authorized_keys')).Contains((Get-Content ($key + '.pub') -Raw).Split(' ')[1])) { throw 'Removed key remains authorized' }
    Snapshot 'servers-removed'
    $events = @(Get-Content (Join-Path $serverRoot 'events.jsonl') | ForEach-Object { $_ | ConvertFrom-Json })
    if (@($events | Where-Object { $_.event -eq 'command' -and $_.kind -eq 'remove' -and $_.exit -eq 0 }).Count -ne 1) { throw 'Expected exactly one successful app-issued removal command' }
    Save-Json @{ events = $events; revokedExit = $revokedExit; addSeconds = $seconds; boundary = 'Real released app and Windows OpenSSH; disposable Paramiko SSH protocol endpoint and Git Bash POSIX home; no live user server modified' } 'servers-proof.json'
    $result.checks += @{ name = 'servers-remove-revokes'; passed = $true; revokedExit = $revokedExit }
    Servers-Click '2'
    Wait-Until { (Servers-Window 'MultipromptSettings') -ne [IntPtr]::Zero } 'Settings after removal'
    Press @(0x1B) 'Escape: close Settings'
    Wait-Until { [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window } 'main window restored'
    Snapshot 'after'
} finally {
    if ($null -ne $serverProcess) {
        if (-not $serverProcess.HasExited) { $serverProcess.Kill(); $serverProcess.WaitForExit() }
        $serverProcess.Dispose()
    }
    foreach ($path in @((Join-Path $keyRoot 'multibot_ed25519'), (Join-Path $keyRoot 'multibot_ed25519.pub'))) {
        if (Test-Path $path) { Remove-Item -LiteralPath $path -Force }
    }
    $env:PYTHONPATH = $oldPythonPath
    if (Test-Path $dependencyRoot) { Remove-Item -LiteralPath $dependencyRoot -Recurse -Force }
}
