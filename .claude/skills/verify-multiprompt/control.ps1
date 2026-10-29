param(
    [Parameter(Mandatory=$true)][ValidateSet('settings-panel', 'appearance', 'app-icon', 'sessions', 'session-restore', 'tmux-binding', 'workspaces', 'workspace-focus', 'inbox', 'command-palette', 'link-picker', 'session-open', 'favorites-groups', 'chat-first-paint', 'chat-send-latency', 'browser-switch-speed', 'chat-switch-speed', 'browser-pane-stuck', 'browser-pane-locked', 'browser-corners', 'group-rail', 'pane-layout', 'title-bar', 'window-controls', 'chat-tables', 'chat-code-font', 'chat-working', 'chat-composer-text', 'chat-skill-pill', 'chat-options', 'composer-buttons', 'chat-dictation', 'safe-updates', 'chat-view', 'chat-view-everywhere', 'chat-focus', 'chat-delivery', 'chat-messages-only', 'chat-full-history', 'browser-emulation', 'status-card', 'palette-order', 'browser-own-profile', 'remind-me', 'tab-names', 'session-tabs', 'relaunch-saved-sessions')][string]$Feature,
    [Parameter(Mandatory=$true)][string]$Exe,
    [Parameter(Mandatory=$true)][string]$ExpectedVersion,
    [Parameter(Mandatory=$true)][string]$ExpectedHash,
    [Parameter(Mandatory=$true)][string]$Evidence
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Run only on a GitHub Windows runner through verify.yml' }
$shapeProof = $env:CHAT_SHAPE_PROOF -eq '1'
$shapeProfile = $env:CHAT_SWITCH_PROFILE -eq '1'
if ($shapeProof -and $Feature -ne 'chat-switch-speed') { throw 'Shape proof requires the chat-switch-speed journey' }
if ($shapeProfile -and -not $shapeProof -and $env:CHAT_SWITCH_PROOF -ne '1') { throw 'Switch profiling requires a native switching journey' }
switch ($Feature) {
        'app-icon' {
            & "$PSScriptRoot/../../../tools/verify-app-icon/drive.ps1" -Exe $Exe -ExpectedVersion $ExpectedVersion -ExpectedHash $ExpectedHash -Evidence $Evidence
            return
        }
        'chat-full-history' {
            & "$PSScriptRoot/../../../tools/verify-chat-delivery/drive.ps1" -Feature $Feature -Exe $Exe -Ssh "$(Split-Path $Exe)/ssh.exe" -ExpectedVersion $ExpectedVersion -ExpectedHash $ExpectedHash -Evidence $Evidence
            if ($LASTEXITCODE -ne 0) { throw 'Full-session history verification failed' }
            return
        }
        'chat-messages-only' {
            & "$PSScriptRoot/../../../tools/verify-chat-delivery/drive.ps1" -Feature $Feature -Exe $Exe -Ssh "$(Split-Path $Exe)/ssh.exe" -ExpectedVersion $ExpectedVersion -ExpectedHash $ExpectedHash -Evidence $Evidence
            if ($LASTEXITCODE -ne 0) { throw 'Messages-only verification failed' }
            return
        }
        'chat-delivery' {
            & "$PSScriptRoot/../../../tools/verify-chat-delivery/drive.ps1" -Exe $Exe -Ssh "$(Split-Path $Exe)/ssh.exe" -ExpectedVersion $ExpectedVersion -ExpectedHash $ExpectedHash -Evidence $Evidence
            if ($LASTEXITCODE -ne 0) { throw 'Chat delivery verification failed' }
            return
        }
        'safe-updates' {
            if ((Get-FileHash $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Executable checksum mismatch before update journey' }
            if (-not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($Exe)).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable version mismatch before update journey' }
            & "$PSScriptRoot/../../../tools/update-release-journey.ps1" -Exe $Exe -Evidence $Evidence
            return
        }
}

Write-Host 'Launch: loading native verification helpers'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, WindowsBase, System.Drawing
Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -TypeDefinition (Get-Content (Join-Path $PSScriptRoot 'control-native.cs') -Raw)

switch ($Feature) {
        'browser-emulation' {
            $Evidence = [IO.Path]::GetFullPath($Evidence)
            New-Item -ItemType Directory -Force $Evidence | Out-Null
            $browserJob = New-Object VerifyJob
            $driver = $null
            try {
                $node = (Get-Command node.exe -ErrorAction Stop).Source
                $scriptPath = (Resolve-Path '.claude/skills/verify-multiprompt/browser-emulation.mjs').Path
                $driver = $browserJob.Start($node, $pwd.Path, (Join-Path $Evidence 'stdout.log'), (Join-Path $Evidence 'stderr.log'), ('"' + $scriptPath + '"'))
                if (-not $driver.WaitForExit(600000)) { throw 'Browser verification timed out' }
                if ($driver.ExitCode -ne 0) { throw ('Browser verification failed: ' + (Get-Content (Join-Path $Evidence 'stderr.log') -Raw)) }
            } finally {
                try {
                    $beforeStop = $browserJob.ReadAccounting()
                    $stopped = $browserJob.Stop()
                    @{ totalProcesses = $stopped.TotalProcesses; activeBeforeStop = $beforeStop.ActiveProcesses; activeAfterStop = $stopped.ActiveProcesses } | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $Evidence 'process-tree.json')
                } finally {
                    if ($null -ne $driver) { $driver.Dispose() }
                    $browserJob.Dispose()
                }
            }
            Write-Output 'VERIFIED browser-emulation with real native CLI and zero active job processes'
            return
        }
}

$Evidence = [IO.Path]::GetFullPath($Evidence)
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$scratch = Join-Path $env:RUNNER_TEMP ('multiprompt-verify-' + [guid]::NewGuid().ToString('N'))
$process = $null
$job = $null
$warmupJob = $null
$warmup = $null
$switchNativeRegistry = $null
$switchExtensionRoot = $null
$script:pinnedNotifyListeners = @()
$script:uploadReceiver = $null
$script:uploadReceiverDir = $null
$script:window = [IntPtr]::Zero
$script:actions = New-Object System.Collections.ArrayList
$script:scratchLinks = @()
$result = [ordered]@{ feature = $Feature; status = 'failed'; version = $ExpectedVersion; sha256 = $ExpectedHash; checks = @(); offlineLogin = $true; cleanup = 'pending' }
$original = @{}
$originalFontSmoothing = $null

. (Join-Path $PSScriptRoot 'control-library.ps1')
try {
    if ($Feature -in @('title-bar', 'window-controls')) {
        Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -Path (Join-Path $PSScriptRoot 'title-bar-native.cs')
        [CaptionProof]::SetDpi([int]$env:CAPTION_DPI)
    }
    if ($Feature -eq 'chat-composer-text') {
        $originalFontSmoothing = [VerifyNative]::FontSmoothing()
        [VerifyNative]::FontSmoothing($false)
    }
    if ((Get-FileHash $Exe -Algorithm SHA256).Hash -ne $ExpectedHash) { throw 'Executable checksum mismatch before launch' }
    $bytes = [IO.File]::ReadAllBytes($Exe)
    if (-not [Text.Encoding]::ASCII.GetString($bytes).Contains("MPVERSION=$ExpectedVersion;")) { throw 'Executable build/version marker mismatch' }
    foreach ($name in @('APPDATA', 'LOCALAPPDATA', 'USERPROFILE', 'HOME', 'MULTIPROMPT_NO_LOGIN', 'ZIGSHELL_DEBUG', 'IGSH_246', 'MULTIPROMPT_DICTATION_FIXTURE')) {
        $original[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    if ($Feature -in @('browser-switch-speed', 'chat-switch-speed', 'browser-own-profile')) {
        $chrome = & node (Join-Path $PSScriptRoot 'browser-switch-chrome.mjs')
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $chrome)) { throw 'Pinned Chrome for Testing executable unavailable' }
    }
    if ($Feature -eq 'title-bar') {
        $chrome = & node (Join-Path $PSScriptRoot 'browser-switch-chrome.mjs')
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $chrome)) { throw 'Pinned caption browser executable unavailable' }
    }
    foreach ($directory in @('roaming', 'local', 'profile')) { New-Item -ItemType Directory -Force (Join-Path $scratch $directory) | Out-Null }
    $env:APPDATA = Join-Path $scratch 'roaming'
    $env:LOCALAPPDATA = Join-Path $scratch 'local'
    if ($Feature -ne 'browser-own-profile') { $env:USERPROFILE = Join-Path $scratch 'profile' }
    $env:HOME = Join-Path $scratch 'profile'
    if ($Feature -eq 'status-card') {
        $usageCollector = [Threading.Mutex]::new($false, 'Local\MultipromptUsageTelemetryLaunch')
        $usageRoot = Join-Path $env:APPDATA 'ZigShell'
        New-Item -ItemType Directory -Force $usageRoot | Out-Null
        Copy-Item (Join-Path $PSScriptRoot '../../../tools/fixtures/IGSH-908/usage-telemetry.json') (Join-Path $usageRoot 'usage-telemetry.json')
        $usagePaceSnapshot = $null
        if ($env:VERIFY_USAGE_PACE_FILE) {
            Copy-Item $env:VERIFY_USAGE_PACE_FILE (Join-Path $Evidence 'pace-source.json')
            $usagePaceSnapshot = Get-Content $env:VERIFY_USAGE_PACE_FILE -Raw | ConvertFrom-Json
            $usageSourceTs = $usagePaceSnapshot.ts
            $usagePaceSnapshot.ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            Save-Json $usagePaceSnapshot 'pace-replayed.json'
            Copy-Item (Join-Path (Split-Path $Exe) 'usage-ssh.exe') (Join-Path $scratch 'usage-ssh.exe')
            Copy-Item (Join-Path $Evidence 'pace-replayed.json') (Join-Path $scratch 'usage-pace.json')
            [IO.File]::WriteAllText((Join-Path $usageRoot 'ssh-path.txt'), (Join-Path $scratch 'usage-ssh.exe'))
        }
    }
    if ($Feature -eq 'chat-skill-pill') {
        $skillRoot = Join-Path $env:USERPROFILE '.claude/skills/pill-proof'
        New-Item -ItemType Directory -Force $skillRoot | Out-Null
        [IO.File]::WriteAllText((Join-Path $skillRoot 'SKILL.md'), "---`nname: pill-proof`ndescription: isolated skill color proof`n---`nReply with the given text.")
    }
    if ($Feature -in @('browser-switch-speed', 'chat-switch-speed', 'browser-own-profile')) {
        $extensionSource = if ($shapeProof -and $env:VERIFY_EXTENSION_ROOT) { $env:VERIFY_EXTENSION_ROOT } else { Join-Path $PSScriptRoot '../../../extension' }
        $extension = Join-Path $env:USERPROFILE 'Documents/GitHub/zigshell/extension'
        $extensionRoot = [IO.Path]::GetFullPath((Split-Path $extension))
        $extensionRootExisted = Test-Path -LiteralPath $extensionRoot
        if (-not $extensionRootExisted) {
            New-Item -ItemType Directory -Path $extensionRoot | Out-Null
            $switchExtensionRoot = (Resolve-Path -LiteralPath $extensionRoot).Path
        }
        Copy-Item $extensionSource $extension -Recurse
        $manifestPath = Join-Path $extension 'manifest.json'
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $publicKey = 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDQp16XVv5KtjSlsEqMuPshm2xYXIvCx5DIAvNpHvxVpg2xJylPEsBoMC3pNeqqz9qG3g9MHQx7X08ItIevQXaOEWBrX7ZVHHXzoQBnlQ/LZbcSkpFucyNItAURMUCGg8XpwuAXi+rFcMkBcib6IpHklkAk97Kxc3NTevJ8TNSUewIDAQAB'
        $manifest | Add-Member -NotePropertyName key -NotePropertyValue $publicKey -Force
        $manifest | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 $manifestPath
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $digest = $sha.ComputeHash([Convert]::FromBase64String($publicKey)) } finally { $sha.Dispose() }
        $extensionId = -join ($digest[0..15] | ForEach-Object { [char](97 + ($_ -shr 4)); [char](97 + ($_ -band 15)) })
        $nativeManifest = Join-Path $scratch 'native-host.json'
        @{ name = 'com.zigshell.bridge'; description = 'Synthetic switch timing bridge'; path = (Join-Path (Split-Path $Exe) 'zigshell-bridge.exe'); type = 'stdio'; allowed_origins = @("chrome-extension://$extensionId/") } | ConvertTo-Json | Set-Content -Encoding UTF8 $nativeManifest
        $registry = 'HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.zigshell.bridge'
        if (Test-Path $registry) { throw 'Switch timing requires an unregistered disposable native host' }
        $switchNativeRegistry = $registry
        New-Item -Path $registry -Force | Out-Null
        Set-Item -Path $registry -Value $nativeManifest
        $edge = $chrome
        $profile = Join-Path $env:LOCALAPPDATA 'ZigShell/ChromeUserData'
        $config = Join-Path $env:APPDATA 'ZigShell'
        New-Item -ItemType Directory -Force $config | Out-Null
        [IO.File]::WriteAllText((Join-Path $config 'chrome-exe.txt'), $chrome)
        [IO.File]::WriteAllText((Join-Path $config 'browser-engine.txt'), 'chrome')
        Save-Json @{ extensionId = $extensionId; version = $manifest.version; installed = $true; executable = $chrome; configuration = 'chrome-exe.txt + browser-engine.txt' } 'switch-extension.json'
    }
    if ($Feature -eq 'title-bar') {
        $edge = $chrome
        $profile = Join-Path $env:LOCALAPPDATA 'ZigShell/ChromeUserData'
        $config = Join-Path $env:APPDATA 'ZigShell'
        New-Item -ItemType Directory -Force $config, (Join-Path $profile 'Default') | Out-Null
        [IO.File]::WriteAllText((Join-Path $config 'chrome-exe.txt'), $chrome)
        [IO.File]::WriteAllText((Join-Path $config 'browser-engine.txt'), 'chrome')
        $scheme = if ($env:CAPTION_BROWSER_THEME -eq 'light') { 1 } else { 2 }
        @{ browser = @{ theme = @{ color_scheme = $scheme } } } | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $profile 'Default/Preferences')
    }
    $paletteUsageFixture = Join-Path $PSScriptRoot '../../../tools/fixtures/IGSH-612/palette-usage.tsv'
    if ($Feature -eq 'palette-order') {
        $config = Join-Path $env:APPDATA 'ZigShell'
        New-Item -ItemType Directory -Force $config | Out-Null
        Copy-Item $paletteUsageFixture (Join-Path $config 'palette-usage.tsv')
    }
    $env:MULTIPROMPT_DICTATION_FIXTURE = $null
    if ($Feature -eq 'chat-dictation') {
        $fixture = (Resolve-Path (Join-Path $PSScriptRoot '../../../tools/fixtures/IGSH-812')).Path
        $audioHash = (Get-FileHash (Join-Path $fixture 'goforward.pcm') -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($audioHash -cne 'f15c60ec54059d8b66e410d0064945a0b0a04ea56e1ddca1958e493c0cf70e71') { throw 'Recorded dictation PCM checksum mismatch' }
        $env:MULTIPROMPT_DICTATION_FIXTURE = $fixture
        $result.dictationBoundary = @{ audio = 'recorded CMUSphinx goforward.pcm'; sha256 = $audioHash; provider = 'offline provider-format response replay, not live Deepgram recognition'; microphoneHardware = $false }
    }
    if ($Feature -eq 'browser-own-profile') {
        for ($port = 19548; $port -le 19559; $port++) {
            $pinned = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $port)
            $pinned.Start()
            $script:pinnedNotifyListeners += $pinned
        }
        $script:uploadReceiverDir = Join-Path $Evidence 'upload-receiver'
        New-Item -ItemType Directory -Force $script:uploadReceiverDir | Out-Null
        $receiverPortFile = Join-Path $script:uploadReceiverDir 'port.txt'
        $script:uploadReceiver = Start-Process -FilePath node -ArgumentList @((Join-Path $PSScriptRoot '../../../tools/screenshot-upload-receiver.mjs'), $receiverPortFile, $script:uploadReceiverDir, 'verify-only-upload-secret') -PassThru -WindowStyle Hidden
        Wait-Until { Test-Path -LiteralPath $receiverPortFile -PathType Leaf } 'local upload receiver listening' 30
        $uploadConfigDir = Join-Path $env:LOCALAPPDATA 'screencast2-go'
        New-Item -ItemType Directory -Force $uploadConfigDir | Out-Null
        [IO.File]::WriteAllText((Join-Path $uploadConfigDir 'config.toml'), "api_base_url = `"http://127.0.0.1:$((Get-Content -LiteralPath $receiverPortFile -Raw).Trim())`"`nupload_secret = `"verify-only-upload-secret`"`n")
        New-Item -ItemType File -Force (Join-Path $script:uploadReceiverDir 'uploads.jsonl') | Out-Null
    }
    $env:IGSH_246 = '0'
    $env:MULTIPROMPT_NO_LOGIN = '1'
    $env:ZIGSHELL_DEBUG = '1'
    if ($Feature -eq 'tmux-binding') {
        $bindingState = Join-Path $scratch 'binding-state'
        New-Item -ItemType Directory -Force $bindingState, (Join-Path $scratch 'roaming/ZigShell') | Out-Null
        $bindingDocument = @{ name = 'tmux-binding'; binding = $true; bindingStatus = $true; generation = '1700:123:$7'; mode = 'busy'; suggestion = ''; sessions = @('workspace') }
        [IO.File]::WriteAllText((Join-Path $bindingState 'state.json'), ($bindingDocument | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
        $env:MP_VERIFY_PYTHON = (Get-Command python.exe).Source
        $env:MP_VERIFY_BOUNDARY = (Resolve-Path (Join-Path $PSScriptRoot '../../../tools/verify-chat-delivery/boundary.py')).Path
        $env:MP_VERIFY_STATE = $bindingState
        $env:PATH = (Split-Path $Exe) + ';' + $env:PATH
        [IO.File]::WriteAllText((Join-Path $scratch 'roaming/ZigShell/ssh-path.txt'), (Join-Path (Split-Path $Exe) 'ssh.exe'))
        $bindingSeed = @{ active_tab = 0; single_window = $true; tabs = @(@{ kind = 'vps2'; name = 'workspace'; manual = $true; pid = 0 }) }
        [IO.File]::WriteAllText((Join-Path $scratch 'roaming/ZigShell/session.json'), ($bindingSeed | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
        Save-Json $bindingSeed 'seed-session.json'
        $result.seedBoundary = 'One saved bare SSH tab with no terminal binding. Only SSH is replaced by an owned console showing an existing named terminal session. The real app resolves its public pane-info request, adopts, saves and restores its binding; command receipts prove five exact reattachments and no session creation. No live server, credentials or real Claude are used.'
    }
    if ($Feature -in @('chat-switch-speed', 'chat-options')) {
        $remoteState = Join-Path $scratch 'remote-state'
        New-Item -ItemType Directory -Force -Path $remoteState, (Join-Path $scratch 'roaming/ZigShell') | Out-Null
        $remoteNames = @(if ($Feature -eq 'chat-options') { 'verify-agent-1' } else { 1..5 | ForEach-Object { "verify-agent-$_" } })
        $remotePanes = [ordered]@{}
        $remoteSids = [ordered]@{}
        for ($i = 0; $i -lt $remoteNames.Count; $i++) {
            $remotePanes[$remoteNames[$i]] = 4300 + $i
            $remoteSids[$remoteNames[$i]] = ('a1b2c3d4-0927-4000-8000-0000000009{0:D2}' -f $i)
        }
        $remoteDocument = [ordered]@{ name = 'chat-switch-speed'; fake = $true; mode = 'idle'; suggestion = 'Try asking about the next step'; sessions = $remoteNames; panes = $remotePanes; sids = $remoteSids; home = (Join-Path $scratch 'profile'); procRoot = ([IO.Path]::GetPathRoot($scratch) + 'proc') }
        [IO.File]::WriteAllText((Join-Path $remoteState 'state.json'), (ConvertTo-Json -InputObject $remoteDocument -Depth 6), (New-Object Text.UTF8Encoding($false)))
        $env:MP_VERIFY_PYTHON = (Get-Command python.exe).Source
        $env:MP_VERIFY_BOUNDARY = (Resolve-Path (Join-Path $PSScriptRoot '../../../tools/verify-chat-delivery/boundary.py')).Path
        $env:MP_VERIFY_STATE = $remoteState
        $env:PATH = (Split-Path $Exe) + ';' + $env:PATH
        [IO.File]::WriteAllText((Join-Path $scratch 'roaming/ZigShell/ssh-path.txt'), (Join-Path (Split-Path $Exe) 'ssh.exe'))
        if ($shapeProof) {
            $shapeFile = (Resolve-Path (Join-Path $PSScriptRoot '../../../tools/fixtures/IGSH-1040/chat-shapes.json')).Path
            & $env:MP_VERIFY_PYTHON $env:MP_VERIFY_BOUNDARY shell seed-shapes $shapeFile
            if ($LASTEXITCODE -ne 0) { throw 'Measured-shape transcript seeding failed' }
            Copy-Item -LiteralPath $shapeFile (Join-Path $Evidence 'chat-shapes.json')
            Copy-Item -LiteralPath (Join-Path $remoteState 'chat-shape-manifest.json') (Join-Path $Evidence 'chat-shape-manifest.json')
        } elseif ($Feature -eq 'chat-options') {
            & $env:MP_VERIFY_PYTHON $env:MP_VERIFY_BOUNDARY shell seed-many 1
        } else {
            & $env:MP_VERIFY_PYTHON $env:MP_VERIFY_BOUNDARY shell seed-many 400
        }
        if ($LASTEXITCODE -ne 0) { throw 'Remote transcript seeding failed' }
        if ($Feature -eq 'chat-options') {
            $remoteDocument.name = 'chat-options'
            $remoteDocument.mode = 'busy'
            $remoteDocument.sid = $remoteSids['verify-agent-1']
            $remoteDocument.transcript = Join-Path $remoteDocument.home ('.claude/projects/C--verify-work0/' + $remoteDocument.sid + '.jsonl')
            [IO.File]::WriteAllText((Join-Path $remoteState 'state.json'), (ConvertTo-Json -InputObject $remoteDocument -Depth 6), (New-Object Text.UTF8Encoding($false)))
            & $env:MP_VERIFY_PYTHON $env:MP_VERIFY_BOUNDARY shell busy
            if ($LASTEXITCODE -ne 0) { throw 'Question input boundary failed' }
            & $env:MP_VERIFY_PYTHON $env:MP_VERIFY_BOUNDARY shell plain-list
            if ($LASTEXITCODE -ne 0) { throw 'Ordinary list fixture failed' }
        }
        $remoteTabs = @($remoteNames | ForEach-Object { @{ kind = 'tmux'; name = ('Remote ' + $_); manual = $true; tmux_host = 0; tmux_session = $_; cv = $false; pid = 0 } })
        $remoteSeedJson = ConvertTo-Json -InputObject @{ active_tab = 0; single_window = $false; chat_active = $false; tabs = $remoteTabs } -Depth 6
        [IO.File]::WriteAllText((Join-Path $scratch 'roaming/ZigShell/session.json'), $remoteSeedJson, (New-Object Text.UTF8Encoding($false)))
        Set-Content -Encoding UTF8 -LiteralPath (Join-Path $Evidence 'seed-session.json') -Value $remoteSeedJson
        $result.seedBoundary = 'The harness writes the saved-tab file once before the first launch: stand-in tmux tabs on a stand-in SSH host, each backed by a seeded Claude transcript of 400 question and answer rounds with tool calls, code blocks and tables. Only SSH is replaced; transcript reading, caching, layout and switching run in the real app.'
    }
    if ($Feature -eq 'tab-names') {
        $seedFolder = Join-Path $scratch 'GitHub'
        New-Item -ItemType Directory -Force -Path $seedFolder, (Join-Path $scratch 'roaming/ZigShell') | Out-Null
        $seedNames = @('Mini Boss CEO', 'HT Product Lead', 'inne Chief of Staff')
        $seedTabs = @()
        for ($i = 0; $i -lt $seedNames.Count; $i++) { $seedTabs += @{ kind = 'cmd'; name = $seedNames[$i]; cwd = $seedFolder; shell_id = ($i + 1) } }
        $seedJson = ConvertTo-Json -InputObject @{ active_tab = 0; single_window = $true; tabs = $seedTabs } -Depth 6
        [IO.File]::WriteAllText((Join-Path $scratch 'roaming/ZigShell/session.json'), $seedJson, (New-Object Text.UTF8Encoding($false)))
        Set-Content -Encoding UTF8 -LiteralPath (Join-Path $Evidence 'seed-session.json') -Value $seedJson
        $result.seedBoundary = 'The harness writes the saved-tab file once before the first launch: three CMD tabs with names that carry no manual or semantic flag, all in one folder named GitHub. Nothing else is seeded and the app is never edited or driven through a setter.'
    }
    $job = New-Object VerifyJob
    if ($Feature -eq 'session-restore') {
        $process = $job.Start($Exe, $scratch, (Join-Path $Evidence 'stdout.log'), (Join-Path $Evidence 'stderr.log'), '--single-window')
    } elseif ($Feature -in @('browser-own-profile', 'tab-names')) {
        $process = $job.Start($Exe, $scratch, (Join-Path $Evidence 'stdout.log'), (Join-Path $Evidence 'stderr.log'), '--single-window')
    } elseif ($Feature -eq 'relaunch-saved-sessions') {
        $relaunchSeed = New-RelaunchSeed
        New-Item -ItemType Directory -Force (Join-Path $scratch 'roaming/ZigShell') | Out-Null
        [IO.File]::WriteAllText((Join-Path $scratch 'roaming/ZigShell/session.json'), (ConvertTo-Json -InputObject $relaunchSeed.document -Depth 8), (New-Object Text.UTF8Encoding $false))
        Save-Json $relaunchSeed.document 'seed-session.json'
        $process = $job.Start($Exe, $scratch, (Join-Path $Evidence 'stdout.log'), (Join-Path $Evidence 'stderr.log'), '--single-window')
    } else {
        $process = $job.Start($Exe, $scratch, (Join-Path $Evidence 'stdout.log'), (Join-Path $Evidence 'stderr.log'))
    }
    Wait-Until {
        $process.Refresh()
        $script:window = $process.MainWindowHandle
        $state = Read-Inbox
        $script:window -ne [IntPtr]::Zero -and $null -ne $state -and @($state.shells).Count -gt 0
    } 'owned main window and initialized CMD session' 60
    if ($Feature -in @('browser-pane-stuck', 'pane-layout', 'browser-pane-locked', 'browser-switch-speed', 'chat-switch-speed', 'chat-first-paint', 'browser-corners', 'window-controls')) {
        if ($Feature -notin @('browser-switch-speed', 'chat-switch-speed')) {
            $edge = Join-Path ${env:ProgramFiles(x86)} 'Microsoft/Edge/Application/msedge.exe'
            $profile = Join-Path $env:LOCALAPPDATA 'ZigShell/EdgeUserData'
        }
        if (-not (Test-Path -LiteralPath $edge)) { throw 'Browser setup requires the configured browser executable' }
        $warmupJob = New-Object VerifyJob
        $arguments = '--user-data-dir="' + $profile + '" --profile-directory=Default --no-first-run --no-default-browser-check --disable-notifications --disable-background-mode --app="data:text/html,<title>Multiprompt verification browser ready</title>"'
        if ($Feature -in @('browser-switch-speed', 'chat-switch-speed')) { $arguments += ' --load-extension="' + $extension + '" --disable-extensions-except="' + $extension + '" --silent-debugger-extension-api' }
        $warmup = $warmupJob.Start($edge, $scratch, (Join-Path $Evidence 'browser-setup.stdout.log'), (Join-Path $Evidence 'browser-setup.stderr.log'), $arguments)
        Wait-Until {
            $warmup.Refresh()
            if ($warmup.HasExited) { throw 'Browser setup process exited before readiness' }
            $warmup.MainWindowHandle -ne [IntPtr]::Zero -and $warmup.MainWindowTitle -match '^Multiprompt verification browser ready'
        } 'isolated browser rendered setup page before the pane adoption deadline starts' 60
        if ($Feature -in @('browser-switch-speed', 'chat-switch-speed')) { Wait-SwitchNativeHost }
        [void][VerifyNative]::ShowWindow($warmup.MainWindowHandle, 0)
        Save-Json @{ pid = $warmup.Id; ready = $true; timeoutSeconds = 60 } 'browser-setup.json'
    }
    if ($Feature -eq 'title-bar') {
        $warmupJob = New-Object VerifyJob
        $arguments = '--user-data-dir="' + $profile + '" --profile-directory=Default --no-first-run --no-default-browser-check --disable-notifications --disable-background-mode --app="data:text/html,<title>Multiprompt caption browser ready</title>"'
        if ($env:CAPTION_BROWSER_THEME -eq 'dark') { $arguments += ' --force-dark-mode' }
        $warmup = $warmupJob.Start($chrome, $scratch, (Join-Path $Evidence 'browser-setup.stdout.log'), (Join-Path $Evidence 'browser-setup.stderr.log'), $arguments)
        Wait-Until {
            $warmup.Refresh()
            if ($warmup.HasExited) { throw 'Caption browser setup exited before readiness' }
            $warmup.MainWindowHandle -ne [IntPtr]::Zero -and $warmup.MainWindowTitle -match '^Multiprompt caption browser ready'
        } 'isolated browser rendered the requested caption theme' 60
        [void][VerifyNative]::ShowWindow($warmup.MainWindowHandle, 0)
        Save-Json @{ pid = $warmup.Id; executable = $chrome; browserTheme = $env:CAPTION_BROWSER_THEME; dpi = [int]$env:CAPTION_DPI } 'caption-browser-setup.json'
    }
    if ($Feature -eq 'appearance') {
        Doctor
        $maximized = [VerifyNative]::IsZoomed($script:window)
        Save-Json @{ hwnd = $script:window.ToInt64(); maximized = $maximized } 'startup-maximized.json'
        if (-not $maximized) { throw 'IGSH-587: main window did not start maximized' }
        $result.checks += @{ name = 'startup-maximized'; maximized = $maximized }
        Snapshot 'startup-maximized'
    }
    [void][VerifyNative]::ShowWindow($script:window, 9)
    [void][VerifyNative]::MoveWindow($script:window, 10, 10, 1000, 650, $true)
    [void][VerifyNative]::SetForegroundWindow($script:window)
    Wait-Until { [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window } 'foreground main window'
    Doctor
    Record 'Launch complete; read-only Doctor passed'
    Snapshot 'before'
    Write-Host "Drive: $Feature"
    $driveFeature = $Feature
    switch ($Feature) {
        'composer-buttons' { $driveFeature = 'chat-view' }
    }
    switch ($driveFeature) {
        'settings-panel' {
            . (Join-Path $PSScriptRoot 'settings-panel.ps1')
        }
        'chat-working' {
            . (Join-Path $PSScriptRoot 'chat-working.ps1')
        }
        'title-bar' {
            . (Join-Path $PSScriptRoot 'title-bar.ps1')
        }
        'window-controls' {
            . (Join-Path $PSScriptRoot 'window-controls.ps1')
        }
        'palette-order' {
            . (Join-Path $PSScriptRoot 'control-feature-palette-order.ps1')
        }
        'chat-view-everywhere' {
            . (Join-Path $PSScriptRoot 'control-feature-chat-view-everywhere.ps1')
        }
        'chat-send-latency' {
            . (Join-Path $PSScriptRoot 'control-feature-chat-send-latency.ps1')
        }
        'chat-focus' {
            . (Join-Path $PSScriptRoot 'control-feature-chat-focus.ps1')
        }
        'appearance' {
            . (Join-Path $PSScriptRoot 'control-feature-appearance.ps1')
        }
        'chat-dictation' {
            . (Join-Path $PSScriptRoot 'control-feature-chat-dictation.ps1')
        }
        'chat-tables' {
            . (Join-Path $PSScriptRoot 'control-feature-chat-tables.ps1')
        }
        'chat-skill-pill' {
            . (Join-Path $PSScriptRoot 'chat-skill-pill.ps1')
        }
        'chat-options' {
            . (Join-Path $PSScriptRoot 'chat-options.ps1')
        }
        'chat-composer-text' {
            . (Join-Path $PSScriptRoot 'control-feature-chat-composer-text.ps1')
        }
        'chat-code-font' {
            . (Join-Path $PSScriptRoot 'control-feature-chat-code-font.ps1')
        }
        'sessions' {
            . (Join-Path $PSScriptRoot 'control-feature-sessions.ps1')
        }
        'session-restore' {
            . (Join-Path $PSScriptRoot 'control-feature-session-restore.ps1')
        }
        'workspaces' { . (Join-Path $PSScriptRoot 'workspace-switcher.ps1') }
        'tab-names' {
            . (Join-Path $PSScriptRoot 'control-feature-tab-names.ps1')
        }
        'favorites-groups' {
            . (Join-Path $PSScriptRoot 'control-feature-favorites-groups.ps1')
        }
        'tmux-binding' { . (Join-Path $PSScriptRoot 'tmux-binding.ps1') }
        'relaunch-saved-sessions' {
            . (Join-Path $PSScriptRoot 'control-feature-relaunch-saved-sessions.ps1')
        }
        'session-open' {
            . (Join-Path $PSScriptRoot 'control-feature-session-open.ps1')
        }
        'workspace-focus' {
            . (Join-Path $PSScriptRoot 'control-feature-workspace-focus.ps1')
        }
        'chat-view' {
            . (Join-Path $PSScriptRoot 'control-feature-chat-view.ps1')
        }
        'inbox' {
            . (Join-Path $PSScriptRoot 'control-feature-inbox.ps1')
        }
        'remind-me' {
            . (Join-Path $PSScriptRoot 'control-feature-remind-me.ps1')
        }
        'session-tabs' {
            . (Join-Path $PSScriptRoot 'control-feature-session-tabs.ps1')
        }
        'group-rail' {
            . (Join-Path $PSScriptRoot 'control-feature-group-rail.ps1')
        }
        'pane-layout' {
            . (Join-Path $PSScriptRoot 'control-feature-pane-layout.ps1')
        }
        'chat-first-paint' {
            . (Join-Path $PSScriptRoot 'control-feature-chat-first-paint.ps1')
        }
        'browser-switch-speed' {
            . (Join-Path $PSScriptRoot 'control-feature-browser-switch-speed.ps1')
        }
        'browser-corners' {
            . "$PSScriptRoot/browser-corners.ps1"
        }
        'browser-pane-locked' {
            . (Join-Path $PSScriptRoot 'control-feature-browser-pane-locked.ps1')
        }
        'browser-pane-stuck' {
            . (Join-Path $PSScriptRoot 'control-feature-browser-pane-stuck.ps1')
        }
        'browser-own-profile' {
            . (Join-Path $PSScriptRoot 'control-feature-browser-own-profile.ps1')
        }
        'status-card' {
            . (Join-Path $PSScriptRoot 'control-feature-status-card.ps1')
        }
        'link-picker' {
            . "$PSScriptRoot/link-picker.ps1"
        }
        'command-palette' {
            . (Join-Path $PSScriptRoot 'control-feature-command-palette.ps1')
        }
        'chat-switch-speed' {
            . (Join-Path $PSScriptRoot 'control-feature-chat-switch-speed.ps1')
        }
    }
    if ($Feature -in @('title-bar', 'window-controls')) {
        if (-not $result.windowControls.closed -or -not $process.HasExited) { throw 'Window control journey did not prove normal close' }
    } else { Doctor }
    $result.status = 'passed'
} catch {
    $result.error = $_.Exception.Message
    if ($script:window -ne [IntPtr]::Zero) {
        try { Snapshot 'failure' } catch { $result.captureError = $_.Exception.Message }
    }
} finally {
    try {
        try {
            if ($null -ne $process -and -not $process.HasExited) {
                Record 'Cleanup: close owned app before stopping its job-owned process tree'
                [void]$process.CloseMainWindow()
                [void]$process.WaitForExit(10000)
            }
        } finally {
            try {
                if ($null -ne $job) {
                    $beforeStop = $job.ReadAccounting()
                    $stopped = $job.Stop()
                    Save-Json @{ totalProcesses = $stopped.TotalProcesses; activeBeforeStop = $beforeStop.ActiveProcesses; activeAfterStop = $stopped.ActiveProcesses } 'process-tree.json'
                    Record 'Cleanup: owned process tree stopped; job active process count is zero'
                }
                if ($null -ne $warmupJob) {
                    $warmupStopped = $warmupJob.Stop()
                    Save-Json @{ activeAfterStop = $warmupStopped.ActiveProcesses } 'browser-setup-process-tree.json'
                }
                Release-ScratchConsoleFonts $scratch
            } finally {
                if ($null -ne $switchNativeRegistry) {
                    Remove-Item -LiteralPath $switchNativeRegistry -Recurse -Force
                    $switchNativeRegistry = $null
                }
                if ($null -ne $switchExtensionRoot) {
                    Remove-Item -LiteralPath $switchExtensionRoot -Recurse -Force
                    $switchExtensionRoot = $null
                }
                foreach ($pinned in $script:pinnedNotifyListeners) { $pinned.Stop() }
                $script:pinnedNotifyListeners = @()
                if ($null -ne $script:uploadReceiver -and -not $script:uploadReceiver.HasExited) { $script:uploadReceiver.Kill() }
                if (Test-Path $scratch) {
                    Prepare-ScratchEvidence $scratch
                    $data = Join-Path $Evidence 'data'
                    New-Item -ItemType Directory -Force $data | Out-Null
                    $deadline = [DateTime]::UtcNow.AddSeconds(20)
                    while ($true) {
                        try { Copy-Item (Join-Path $scratch '*') $data -Recurse -Force; break } catch {
                            if ([DateTime]::UtcNow -ge $deadline) { throw }
                            Start-Sleep -Milliseconds 200
                        }
                    }
                }
            }
        }
        Remove-ScratchPath $scratch
        $result.cleanup = 'owned process tree stopped; scratch copied to evidence/data then removed'
        $result.scratchRemoved = -not (Test-Path $scratch)
        if (-not $result.scratchRemoved) { throw 'Scratch directory still exists' }
        Write-Output $result.cleanup
        if ($result.status -eq 'passed') {
            foreach ($name in @('before.png', 'action.png', 'after.png', 'doctor.json', 'actions.json')) {
                if (-not (Test-Path (Join-Path $Evidence $name))) { throw "Evidence lost during cleanup: $name" }
            }
        }
    } catch {
        $result.status = 'failed'
        $result.cleanup = $_.Exception.Message
    }
    if ($null -ne $warmup) { $warmup.Dispose() }
    if ($null -ne $warmupJob) { $warmupJob.Dispose() }
    if ($null -ne $job) { $job.Dispose() }
    if ($null -ne $process) { $process.Dispose() }
    if ($null -ne $usageCollector) { $usageCollector.Dispose() }
    foreach ($name in $original.Keys) { [Environment]::SetEnvironmentVariable($name, $original[$name], 'Process') }
    if ($null -ne $originalFontSmoothing) { [VerifyNative]::FontSmoothing([bool]$originalFontSmoothing) }
    if ($Feature -in @('title-bar', 'window-controls') -and ('CaptionProof' -as [type])) {
        try { [CaptionProof]::RestoreDpi() } catch { $result.status = 'failed'; $result.dpiCleanupError = $_.Exception.Message }
    }
    Save-Json $result 'result.json'
}
if ($result.status -ne 'passed') { throw ('Verification failed: ' + ($result | ConvertTo-Json -Depth 8 -Compress)) }
Write-Output "VERIFIED $Feature with real input and retained evidence"
exit 0
