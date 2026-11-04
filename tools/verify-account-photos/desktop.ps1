param([Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string]$Evidence)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'GitHub Windows only' }
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
Add-Type -AssemblyName System.Drawing, System.Windows.Forms, System.Security
Add-Type -Path "$PSScriptRoot/../verify-chat-delivery/desktop.cs"
Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -Path "$PSScriptRoot/../../.claude/skills/verify-multiprompt/control-native.cs"
[void][ChatDeliveryDesktop]::SetThreadDpiAwarenessContext([IntPtr](-4))
$config = $env:PHOTO_PROOF_CREDENTIAL | ConvertFrom-Json
Remove-Item Env:PHOTO_PROOF_CREDENTIAL
$client = Get-Content "$PSScriptRoot/../../src/account_client.zig" -Raw
$origin = [regex]::Match($client, 'pub const origin = "([^"]+)"').Groups[1].Value
if (!$origin.StartsWith('https://')) { throw 'Account origin missing' }
$profile = Join-Path $env:RUNNER_TEMP ('account-picture-' + [guid]::NewGuid().ToString('N'))
$env:APPDATA = Join-Path $profile 'roaming'
$env:LOCALAPPDATA = Join-Path $profile 'local'
$env:USERPROFILE = Join-Path $profile 'home'
$env:HOME = $env:USERPROFILE
$env:ZIGSHELL_DEBUG = '1'
$env:IGSH_246 = '0'
$env:PATH = (Split-Path $Exe) + ';' + $env:PATH
Remove-Item Env:MULTIPROMPT_NO_LOGIN -ErrorAction SilentlyContinue
$settings = Join-Path $env:APPDATA 'ZigShell'
New-Item -ItemType Directory -Force $settings, $env:LOCALAPPDATA, $env:USERPROFILE, (Join-Path $env:USERPROFILE 'Desktop'), (Join-Path $env:USERPROFILE 'Documents') | Out-Null
$credentialPath = Join-Path $settings 'account-device.dat'
$sessionPath = Join-Path $settings 'session-picture-proof.json'
$logPath = Join-Path $settings 'debug.log'
$bytes = [Text.Encoding]::UTF8.GetBytes((@{ refresh_token = $config.desktop_refresh_token } | ConvertTo-Json -Compress))
[IO.File]::WriteAllBytes($credentialPath, [Security.Cryptography.ProtectedData]::Protect($bytes, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser))
[Array]::Clear($bytes, 0, $bytes.Length)
$config = $null
$job = $null
$app = $null
$main = [IntPtr]::Zero
$result = @{ status = 'failed'; cleanup = 'pending'; error = $null }
function Save($Object, [string]$Name) { [IO.File]::WriteAllText((Join-Path $Evidence $Name), ($Object | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false)) }
function Wait-For([string]$Name, [scriptblock]$Check, [int]$Seconds = 60) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do { $value = & $Check; if ($value) { return $value }; Start-Sleep -Milliseconds 150 } while ($timer.Elapsed.TotalSeconds -lt $Seconds)
    throw "Timed out: $Name"
}
function Log {
    if (!(Test-Path $logPath)) { return '' }
    $stream = [IO.File]::Open($logPath, 'Open', 'Read', 'ReadWrite')
    $reader = [IO.StreamReader]::new($stream)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function Fetch([string]$Path) {
    try {
        $stored = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($credentialPath), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        $login = [Text.Encoding]::UTF8.GetString($stored) | ConvertFrom-Json
        [Array]::Clear($stored, 0, $stored.Length)
        if (!$login.PSObject.Properties['access_token']) { return $null }
        return Invoke-RestMethod -Uri ($origin + $Path) -UserAgent 'multiprompt-account' -Headers @{ Authorization = 'Bearer ' + $login.access_token; 'X-Layout-Features' = 'bot_photo' } -TimeoutSec 15
    } catch { return $null }
}
function Shot([string]$Name) {
    $bounds = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = [Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bitmap.Size); $bitmap.Save((Join-Path $Evidence "$Name.png")) } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Press([int[]]$Keys) {
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $main) { throw 'App does not own keyboard' }
    $opensPalette = $Keys.Count -eq 2 -and $Keys[0] -eq 0x11 -and $Keys[1] -eq 0x4b
    $offset = if ($opensPalette) { (Log).Length } else { 0 }
    [VerifyNative]::Chord($Keys)
    if ($opensPalette) {
        [void](Wait-For 'palette opened' { $trace = Log; $trace.Length -ge $offset -and $trace.Substring($offset) -match '\[palette\] ready chars=0 count=[1-9]\d*' })
    }
}
function Query([string]$Text, [int]$Target) {
    $offset = (Log).Length
    [VerifyNative]::Text($Text)
    [void](Wait-For 'palette selection' { $trace = Log; $trace.Length -ge $offset -and $trace.Substring($offset) -match ("\[palette\] ready chars=" + $Text.Length + " count=[1-9]\d* target=" + $Target + "(?:\r?\n|$)") })
}
try {
    $imagePath = Join-Path $profile 'picture.png'
    $image = [Drawing.Bitmap]::new(256, 256)
    $graphics = [Drawing.Graphics]::FromImage($image)
    try { $graphics.Clear([Drawing.Color]::Lime); $graphics.FillRectangle([Drawing.Brushes]::Blue, 128, 128, 128, 128); $image.Save($imagePath, [Drawing.Imaging.ImageFormat]::Png) } finally { $graphics.Dispose(); $image.Dispose() }
    $job = [VerifyJob]::new()
    $app = $job.Start($Exe, $profile, (Join-Path $profile 'stdout.log'), (Join-Path $profile 'stderr.log'), '--single-window --name picture-proof --no-window-restore')
    $main = Wait-For 'owned main window' {
        if ($app.HasExited) { throw ('App exited before its main window: ' + $app.ExitCode) }
        $window = [ChatDeliveryDesktop]::Window([uint32]$app.Id)
        if ($window -ne [IntPtr]::Zero) { $window }
    }
    [void](Wait-For 'session restoration' { (Log) -match 'launch step=browser' })
    [void](Wait-For 'phone readiness' {
        $reply = Fetch '/v1/layout'
        if ($reply) { @($reply.layout.tabs | Where-Object { $_.tmux_session -ceq 'runner-1' -and $_.name -ceq 'Phone ready' }).Count -eq 1 }
    } 1500)
    $index = Wait-For 'synced picture session' {
        try {
            $tabs = @((Get-Content $sessionPath -Raw | ConvertFrom-Json).tabs)
            for ($i = 0; $i -lt $tabs.Count; $i++) { if ($tabs[$i].PSObject.Properties['tmux_session'] -and $tabs[$i].tmux_session -ceq 'runner-1' -and $tabs[$i].name -ceq 'Phone ready') { return @{ value = $i } } }
        } catch {}
    }
    [void](Wait-For 'owned foreground' { [ChatDeliveryDesktop]::FocusOwnedWindow($main, [uint32]$app.Id, $main) })
    Press @(0x11, 0x4b); Query 'phone ready' $index.value; Press @(0x0d)
    Shot 'desktop-before'
    Press @(0x11, 0x4b); Query 'bot face' 7187; Press @(0x0d)
    Query 'upload image' 7193; Press @(0x0d)
    $dialog = Wait-For 'owned image picker' {
        $window = [ChatDeliveryDesktop]::GetForegroundWindow()
        if ($window -ne [IntPtr]::Zero -and [ChatDeliveryDesktop]::Owner($window) -eq [uint32]$app.Id -and [ChatDeliveryDesktop]::Class($window) -eq '#32770') { $window }
    }
    [Windows.Forms.Clipboard]::SetText($imagePath)
    [ChatDeliveryDesktop]::Chord(@(0x12, 0x4e))
    [ChatDeliveryDesktop]::Chord(@(0x11, 0x41))
    [ChatDeliveryDesktop]::Chord(@(0x11, 0x56))
    if ([ChatDeliveryDesktop]::GetForegroundWindow() -ne $dialog) { throw 'Image picker lost ownership' }
    $uploadedAt = [DateTimeOffset]::UtcNow
    [ChatDeliveryDesktop]::Chord(@(0x0d))
    [void](Wait-For 'desktop picture import' { (Log) -match '\[bot-photo\] import=ok' })
    $prefix = [Text.Encoding]::UTF8.GetBytes("ZigShell bot avatar v1`0remote`0")
    $identity = $prefix + [byte[]]@(0) + [Text.Encoding]::UTF8.GetBytes('runner-1')
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $digest = ([BitConverter]::ToString($sha.ComputeHash($identity))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
    $picture = Wait-For 'account picture' { $reply = Fetch ("/v1/bot-photos/$digest"); if ($reply -and $reply.png) { $reply } }
    $decoded = [Convert]::FromBase64String($picture.png)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = ([BitConverter]::ToString($sha.ComputeHash($decoded))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
    $cloud = Fetch '/v1/layout'
    $tab = @($cloud.layout.tabs | Where-Object { $_.tmux_session -ceq 'runner-1' })
    if ($tab.Count -ne 1 -or !$tab[0].PSObject.Properties['photo'] -or $tab[0].photo -le 0) { throw 'Account picture revision missing' }
    if (([DateTimeOffset]::UtcNow - $uploadedAt).TotalSeconds -gt 60) { throw 'Account upload exceeded one minute' }
    Shot 'desktop-after'
    $result.status = 'passed'
    $result.uploaded_at = $uploadedAt.ToString('o')
    $result.account_picture_sha256 = $hash
    $result.photo_revision = $tab[0].photo
    $result.app_sha256 = (Get-FileHash $Exe -Algorithm SHA256).Hash.ToLowerInvariant()
} catch {
    $result.error = $_.Exception.Message
    try { Shot 'desktop-failure' } catch {}
} finally {
    if ($job) { $stopped = $job.Stop(); $result.cleanup = $stopped.ActiveProcesses; $job.Dispose() } else { $result.cleanup = 0 }
    Save $result 'desktop.json'
    if (Test-Path $profile) { Remove-Item -Recurse -Force $profile }
}
if ($result.status -ne 'passed' -or $result.cleanup -ne 0) { throw 'Live desktop picture proof failed' }
