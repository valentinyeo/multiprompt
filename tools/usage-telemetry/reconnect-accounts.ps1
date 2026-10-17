[CmdletBinding()]
param(
    [switch]$LoadFunctionsOnly,
    [ValidateSet('', 'claude-primary', 'claude-secondary')]
    [string]$AccountId = '',
    [switch]$ForceLogin
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$localConfig = Join-Path $PSScriptRoot 'config.local.json'
$exampleConfig = Join-Path $PSScriptRoot 'config.example.json'
$configPath = if (Test-Path -LiteralPath $localConfig) {
    $localConfig
} else {
    $exampleConfig
}
$snapshotPath = Join-Path $env:APPDATA 'ZigShell\usage-telemetry.json'
$collectorPath = Join-Path $repoRoot 'zig-out\bin\multiprompt.exe'

function Resolve-LocalPath([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $Value }
    if ($Value -eq '~') { return $env:USERPROFILE }
    if ($Value.StartsWith('~/') -or $Value.StartsWith('~\')) {
        return Join-Path $env:USERPROFILE $Value.Substring(2)
    }
    return [System.IO.Path]::GetFullPath($Value)
}

function Read-ClaudeCredential([string]$ConfigDir) {
    $path = Join-Path $ConfigDir '.credentials.json'
    if (-not (Test-Path -LiteralPath $path)) {
        return [pscustomobject]@{ Path = $path; Present = $false; RefreshPresent = $false; RefreshUsable = $false; FutureExpiry = $false }
    }
    try {
        $parsed = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $oauth = $parsed.claudeAiOauth
        $tokenPresent = $null -ne $oauth.PSObject.Properties['accessToken'] -and
            -not [string]::IsNullOrWhiteSpace([string]$oauth.accessToken)
        $refreshPresent = $null -ne $oauth.PSObject.Properties['refreshToken'] -and
            -not [string]::IsNullOrWhiteSpace([string]$oauth.refreshToken)
        $refreshExpiresAt = 0L
        $refreshExpiryPresent = $null -ne $oauth.PSObject.Properties['refreshTokenExpiresAt'] -and
            [long]::TryParse([string]$oauth.refreshTokenExpiresAt, [ref]$refreshExpiresAt)
        $refreshUsable = $refreshPresent -and
            (-not $refreshExpiryPresent -or $refreshExpiresAt -gt ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + 60000))
        $expiresAt = 0L
        $expiryPresent = $null -ne $oauth.PSObject.Properties['expiresAt'] -and
            [long]::TryParse([string]$oauth.expiresAt, [ref]$expiresAt)
        return [pscustomobject]@{
            Path = $path
            Present = $tokenPresent
            RefreshPresent = $refreshPresent
            RefreshUsable = $refreshUsable
            FutureExpiry = $tokenPresent -and $expiryPresent -and $expiresAt -gt ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + 60000)
        }
    } catch {
        return [pscustomobject]@{ Path = $path; Present = $false; RefreshPresent = $false; RefreshUsable = $false; FutureExpiry = $false }
    }
}

function Read-TelemetrySnapshot {
    if (-not (Test-Path -LiteralPath $snapshotPath)) { return $null }
    try { return Get-Content -LiteralPath $snapshotPath -Raw | ConvertFrom-Json } catch { return $null }
}

function Find-TelemetryAccountRow($Snapshot, [string]$AccountId) {
    if ($null -eq $Snapshot) { return $null }
    return $Snapshot.accounts | Where-Object id -eq $AccountId | Select-Object -First 1
}

function Get-ClipboardText {
    try {
        return [string](Get-Clipboard -Raw -Format Text -ErrorAction Stop)
    } catch {
        return ''
    }
}

function Test-ClaudeAuthorizationCode([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    return $Value.Trim() -match '\A[A-Za-z0-9_-]{20,}#[A-Za-z0-9_-]{20,}\z'
}

function Get-ClaudePublicAccountLabel([string]$Id) {
    if ($Id -eq 'claude-primary') { return 'Primary' }
    if ($Id -eq 'claude-secondary') { return 'Secondary' }
    return 'Claude'
}

function Show-ClaudeAuthorizationCodeDialog([string]$AccountLabel) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Claude telemetry login: $AccountLabel"
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.ClientSize = New-Object System.Drawing.Size(540, 176)
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ShowInTaskbar = $true

    $instruction = New-Object System.Windows.Forms.Label
    $instruction.AutoSize = $false
    $instruction.Location = New-Object System.Drawing.Point(16, 14)
    $instruction.Size = New-Object System.Drawing.Size(508, 40)
    $instruction.Text = 'Paste the authorization code copied from the browser. Ctrl+V works in this field.'
    $form.Controls.Add($instruction)

    $codeBox = New-Object System.Windows.Forms.TextBox
    $codeBox.Location = New-Object System.Drawing.Point(16, 58)
    $codeBox.Size = New-Object System.Drawing.Size(508, 25)
    $codeBox.UseSystemPasswordChar = $true
    $codeBox.ShortcutsEnabled = $true
    $codeBox.TabIndex = 0
    $form.Controls.Add($codeBox)

    $errorLabel = New-Object System.Windows.Forms.Label
    $errorLabel.AutoSize = $false
    $errorLabel.Location = New-Object System.Drawing.Point(16, 88)
    $errorLabel.Size = New-Object System.Drawing.Size(508, 22)
    $errorLabel.ForeColor = [System.Drawing.Color]::Firebrick
    $form.Controls.Add($errorLabel)

    $submit = New-Object System.Windows.Forms.Button
    $submit.Text = 'Submit'
    $submit.Location = New-Object System.Drawing.Point(348, 124)
    $submit.Size = New-Object System.Drawing.Size(84, 30)
    $submit.TabIndex = 1
    $form.Controls.Add($submit)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Location = New-Object System.Drawing.Point(440, 124)
    $cancel.Size = New-Object System.Drawing.Size(84, 30)
    $cancel.TabIndex = 2
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancel)

    $submit.Add_Click({
        $candidate = $codeBox.Text.Trim()
        if (Test-ClaudeAuthorizationCode $candidate) {
            $form.Tag = $candidate
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Close()
        } else {
            $errorLabel.Text = 'That value is not a complete Claude authorization code.'
            $codeBox.SelectAll()
            $codeBox.Focus()
        }
    })
    $form.AcceptButton = $submit
    $form.CancelButton = $cancel
    $form.Add_Shown({ $codeBox.Focus() })

    try {
        $result = $form.ShowDialog()
        if ($result -eq [System.Windows.Forms.DialogResult]::OK -and $form.Tag -is [string]) {
            return ([string]$form.Tag).Trim()
        }
        return ''
    } finally {
        $form.Dispose()
    }
}

function Initialize-ConsoleInputWriter {
    if ('ZigShell.ConsoleInputWriter' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace ZigShell {
    public static class ConsoleInputWriter {
        private const ushort KEY_EVENT = 0x0001;
        private const ushort VK_PACKET = 0x00E7;
        private const uint GENERIC_READ = 0x80000000;
        private const uint GENERIC_WRITE = 0x40000000;
        private const uint FILE_SHARE_READ = 0x00000001;
        private const uint FILE_SHARE_WRITE = 0x00000002;
        private const uint OPEN_EXISTING = 3;

        [StructLayout(LayoutKind.Explicit, CharSet = CharSet.Unicode, Size = 16)]
        private struct KeyEventRecord {
            [FieldOffset(0)] public int KeyDown;
            [FieldOffset(4)] public ushort RepeatCount;
            [FieldOffset(6)] public ushort VirtualKeyCode;
            [FieldOffset(8)] public ushort VirtualScanCode;
            [FieldOffset(10)] public char UnicodeChar;
            [FieldOffset(12)] public uint ControlKeyState;
        }

        [StructLayout(LayoutKind.Explicit, Size = 20)]
        private struct InputRecord {
            [FieldOffset(0)] public ushort EventType;
            [FieldOffset(4)] public KeyEventRecord KeyEvent;
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr CreateFileW(
            string fileName,
            uint desiredAccess,
            uint shareMode,
            IntPtr securityAttributes,
            uint creationDisposition,
            uint flagsAndAttributes,
            IntPtr templateFile);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool WriteConsoleInputW(
            IntPtr consoleInput,
            InputRecord[] buffer,
            uint length,
            out uint written);

        [DllImport("kernel32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CloseHandle(IntPtr handle);

        public static bool Write(string text) {
            if (String.IsNullOrEmpty(text)) return false;
            IntPtr input = CreateFileW(
                "CONIN$",
                GENERIC_READ | GENERIC_WRITE,
                FILE_SHARE_READ | FILE_SHARE_WRITE,
                IntPtr.Zero,
                OPEN_EXISTING,
                0,
                IntPtr.Zero);
            if (input == new IntPtr(-1)) return false;
            try {
                InputRecord[] records = new InputRecord[text.Length * 2];
                for (int i = 0; i < text.Length; i++) {
                    KeyEventRecord key = new KeyEventRecord {
                        KeyDown = 1,
                        RepeatCount = 1,
                        VirtualKeyCode = VK_PACKET,
                        VirtualScanCode = 0,
                        UnicodeChar = text[i],
                        ControlKeyState = 0
                    };
                    records[i * 2] = new InputRecord { EventType = KEY_EVENT, KeyEvent = key };
                    key.KeyDown = 0;
                    records[i * 2 + 1] = new InputRecord { EventType = KEY_EVENT, KeyEvent = key };
                }
                uint written;
                return WriteConsoleInputW(input, records, (uint)records.Length, out written) &&
                    written == records.Length;
            } finally {
                CloseHandle(input);
            }
        }
    }
}
'@
}

function Send-ClaudeAuthorizationCode([string]$Value) {
    if (-not (Test-ClaudeAuthorizationCode $Value)) { return $false }
    Initialize-ConsoleInputWriter
    return [ZigShell.ConsoleInputWriter]::Write($Value.Trim() + [char]13)
}

function Test-CredentialNewerThanTelemetry($Account, $Snapshot) {
    $credentialPath = Join-Path $Account.ConfigDir '.credentials.json'
    if (-not (Test-Path -LiteralPath $credentialPath)) { return $false }
    if ($null -eq $Snapshot) { return $true }
    $row = Find-TelemetryAccountRow $Snapshot $Account.Id
    if ($null -eq $row -or $null -eq $row.lastUpdatedAt -or [string]::IsNullOrWhiteSpace([string]$row.lastUpdatedAt)) { return $true }
    try {
        $sampleAt = if ($row.lastUpdatedAt -is [DateTime]) {
            ([DateTime]$row.lastUpdatedAt).ToUniversalTime()
        } elseif ($row.lastUpdatedAt -is [DateTimeOffset]) {
            ([DateTimeOffset]$row.lastUpdatedAt).UtcDateTime
        } else {
            [DateTimeOffset]::Parse([string]$row.lastUpdatedAt).UtcDateTime
        }
        return (Get-Item -LiteralPath $credentialPath).LastWriteTimeUtc -gt $sampleAt
    } catch {
        return $true
    }
}

function Get-ClaudeAccountAssessment($Account, $Snapshot) {
    $credential = Read-ClaudeCredential $Account.ConfigDir
    $row = Find-TelemetryAccountRow $Snapshot $Account.Id
    $errorName = if ($null -ne $row) { [string]$row.error } else { '' }
    $authenticationFailure = $null -ne $row -and
        [string]$row.status -eq 'stale' -and
        @('AuthenticationRequired', 'CredentialsMissing') -contains $errorName
    $credentialChanged = ($credential.FutureExpiry -or $credential.RefreshUsable) -and
        (Test-CredentialNewerThanTelemetry $Account $Snapshot)
    $reusableCredential = $credential.FutureExpiry -or $credential.RefreshUsable
    $needsLogin = -not $reusableCredential -or ($authenticationFailure -and -not $credentialChanged)
    return [pscustomobject]@{
        Account = $Account
        Credential = $credential
        Row = $row
        AuthenticationFailure = $authenticationFailure
        CredentialChanged = $credentialChanged
        NeedsLogin = $needsLogin
    }
}

function Request-TelemetryRefresh([bool]$RestartExisting) {
    if (-not (Test-Path -LiteralPath $collectorPath)) { return $false }
    if ($RestartExisting) {
        $expectedDirectory = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($collectorPath))
        Get-CimInstance Win32_Process | Where-Object {
            $_.Name -like 'multiprompt*.exe' -and
            ($_.Name -like 'multiprompt-telemetry*.exe' -or
             $_.CommandLine -match '^\s*(?:"[^"]+"|\S+)\s+"?--usage-telemetry"?(?:\s|$)')
        } | ForEach-Object {
            try {
                if (-not $_.ExecutablePath -or
                    [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($_.ExecutablePath)) -ne $expectedDirectory) { return }
                $collector = Get-Process -Id $_.ProcessId -ErrorAction Stop
                Stop-Process -Id $collector.Id -Force
                $collector.WaitForExit(5000)
            } catch {
            }
        }
    }
    Start-Process -FilePath $collectorPath -ArgumentList '--usage-telemetry' -WorkingDirectory (Split-Path -Parent $collectorPath) -WindowStyle Hidden
    return $true
}

if ($LoadFunctionsOnly) { return }

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$claudeAccounts = @($config.accounts | Where-Object { $_.provider -eq 'claude' } | ForEach-Object {
    [pscustomobject]@{
        Id = [string]$_.id
        Label = [string]$_.label
        Email = if ($null -ne $_.PSObject.Properties['email']) { [string]$_.email } else { '' }
        ConfigDir = Resolve-LocalPath ([string]$_.configDir)
    }
})
if ($claudeAccounts.Count -eq 0) {
    throw 'No Claude telemetry accounts are configured.'
}
if (-not [string]::IsNullOrWhiteSpace($AccountId)) {
    $claudeAccounts = @($claudeAccounts | Where-Object Id -eq $AccountId)
    if ($claudeAccounts.Count -eq 0) {
        throw "Claude telemetry account '$AccountId' is not configured."
    }
}

$snapshot = Read-TelemetrySnapshot
$affected = @()
foreach ($account in $claudeAccounts) {
    $assessment = Get-ClaudeAccountAssessment $account $snapshot
    if ($ForceLogin -or $assessment.NeedsLogin) { $affected += $assessment }
}

if ($affected.Count -eq 0) {
    Write-Host 'All Claude telemetry accounts already have a current login.' -ForegroundColor Green
    $credentialChanged = @($claudeAccounts | Where-Object { Test-CredentialNewerThanTelemetry $_ $snapshot }).Count -gt 0
    Request-TelemetryRefresh -RestartExisting $credentialChanged | Out-Null
    if ($credentialChanged) {
        Write-Host 'A newer Claude login was found; refreshing the native telemetry collector once.' -ForegroundColor Cyan
    }
    Read-Host 'Press Enter to close'
    exit 0
}

Write-Host 'Reconnect Claude Telemetry' -ForegroundColor Cyan
if ($ForceLogin -and $affected.Count -eq 1) {
    Write-Host 'This action signs in exactly one selected account, even when its stored refresh token still looks reusable.'
} else {
    Write-Host 'Only the accounts listed below will open a Claude login. They are handled sequentially.'
}
Write-Host 'NO TERMINAL PASTE NEEDED.' -ForegroundColor Yellow
Write-Host 'In the browser, switch to the correct account and copy the code.' -ForegroundColor Yellow
Write-Host 'Paste it into the masked native field. The clipboard watcher remains available as a fallback.' -ForegroundColor Yellow
foreach ($item in $affected) {
    Write-Host "  - $(Get-ClaudePublicAccountLabel $item.Account.Id)" -ForegroundColor Yellow
}
Write-Host ''

$originalConfigDir = $env:CLAUDE_CONFIG_DIR
$results = @()
try {
    foreach ($item in $affected) {
        $account = $item.Account
        $latestSnapshot = Read-TelemetrySnapshot
        $latest = Get-ClaudeAccountAssessment $account $latestSnapshot
        if (-not $ForceLogin -and -not $latest.NeedsLogin) {
            $results += [pscustomobject]@{
                Id = $account.Id
                Label = $account.Label
                Success = $true
                LoginAttempted = $false
                CredentialChanged = $latest.CredentialChanged
            }
            Write-Host "  $($account.Label): already current; login skipped" -ForegroundColor Green
            continue
        }
        $publicLabel = Get-ClaudePublicAccountLabel $account.Id
        Write-Host "Signing in $publicLabel..." -ForegroundColor Cyan
        $env:CLAUDE_CONFIG_DIR = $account.ConfigDir
        if ($ForceLogin) {
            Write-Host '  Clearing only this selected Claude profile before login...' -ForegroundColor DarkGray
            & claude auth logout
        }
        $clipboardBeforeLogin = (Get-ClipboardText).Trim()
        $loginStartedAt = [DateTime]::UtcNow
        $claudeExe = (Get-Command claude -CommandType Application).Source
        $loginArguments = @('auth', 'login', '--claudeai')
        if (-not [string]::IsNullOrWhiteSpace($account.Email)) {
            $loginArguments += @('--email', $account.Email)
        }
        $loginProcess = Start-Process -FilePath $claudeExe -ArgumentList $loginArguments -NoNewWindow -PassThru
        $credentialArrived = $false
        $clipboardSubmitted = $false
        $manualCode = Show-ClaudeAuthorizationCodeDialog $publicLabel
        if (-not [string]::IsNullOrWhiteSpace($manualCode)) {
            if (Send-ClaudeAuthorizationCode $manualCode) {
                $clipboardSubmitted = $true
                Write-Host '  Authorization code submitted from the native field.' -ForegroundColor DarkGray
            } else {
                [System.Windows.Forms.MessageBox]::Show(
                    'The code was valid, but Windows could not write it to the Claude login console. The clipboard watcher will remain active.',
                    'Claude telemetry login',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                ) | Out-Null
            }
        }
        $loginDeadline = [DateTime]::UtcNow.AddMinutes(10)
        while (-not $loginProcess.HasExited -and [DateTime]::UtcNow -lt $loginDeadline) {
            Start-Sleep -Seconds 1
            if (-not $clipboardSubmitted) {
                $clipboardNow = (Get-ClipboardText).Trim()
                if ($clipboardNow -ne $clipboardBeforeLogin -and (Test-ClaudeAuthorizationCode $clipboardNow)) {
                    if (Send-ClaudeAuthorizationCode $clipboardNow) {
                        $clipboardSubmitted = $true
                        Write-Host '  Fresh browser code detected and submitted.' -ForegroundColor DarkGray
                    }
                }
            }
            $credentialPath = Join-Path $account.ConfigDir '.credentials.json'
            if (Test-Path -LiteralPath $credentialPath) {
                $credentialArrived = (Get-Item -LiteralPath $credentialPath).LastWriteTimeUtc -ge $loginStartedAt -and
                    (Read-ClaudeCredential $account.ConfigDir).FutureExpiry
                if ($credentialArrived) { break }
            }
            $loginProcess.Refresh()
        }
        if ($credentialArrived -and -not $loginProcess.HasExited) {
            Stop-Process -Id $loginProcess.Id -Force
            $loginProcess.WaitForExit(5000)
        }
        $exitCode = if ($credentialArrived) { 0 } elseif ($loginProcess.HasExited) { $loginProcess.ExitCode } else { 1 }
        $verified = Read-ClaudeCredential $account.ConfigDir
        $success = ($credentialArrived -or $exitCode -eq 0) -and $verified.FutureExpiry
        $results += [pscustomobject]@{
            Id = $account.Id
            Label = $account.Label
            Success = $success
            LoginAttempted = $true
            CredentialChanged = $success
        }
        if ($success) {
            Write-Host "  ${publicLabel}: credential verified" -ForegroundColor Green
        } else {
            Write-Host "  ${publicLabel}: login did not produce a current credential" -ForegroundColor Red
        }
    }
} finally {
    $env:CLAUDE_CONFIG_DIR = $originalConfigDir
}

$restartExisting = @($results | Where-Object { $_.Success -and ($_.LoginAttempted -or $_.CredentialChanged) }).Count -gt 0
$refreshRequested = Request-TelemetryRefresh -RestartExisting $restartExisting
if ($refreshRequested) {
    Write-Host ''
    Write-Host 'Refreshing the native telemetry snapshot...' -ForegroundColor Cyan
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    do {
        Start-Sleep -Seconds 2
        $snapshot = Read-TelemetrySnapshot
        $pending = @($results | Where-Object Success | Where-Object {
            $id = $_.Id
            $row = Find-TelemetryAccountRow $snapshot $id
            $null -eq $row -or @('loading', 'error', 'stale') -contains [string]$row.status
        })
    } while ($pending.Count -gt 0 -and [DateTime]::UtcNow -lt $deadline)
}

Write-Host ''
$snapshot = Read-TelemetrySnapshot
foreach ($result in $results) {
    $row = Find-TelemetryAccountRow $snapshot $result.Id
    $state = if (-not $result.Success) {
        'FAILED'
    } elseif ($null -ne $row -and $row.status -eq 'ok') {
        'LIVE'
    } elseif ($null -ne $row -and $row.status -eq 'retrying') {
        'RETRY'
    } else {
        'WAIT'
    }
    $color = if ($state -eq 'LIVE') { 'Green' } elseif ($state -eq 'FAILED') { 'Red' } else { 'Yellow' }
    Write-Host "$($result.Label): $state" -ForegroundColor $color
}
Write-Host ''
Write-Host 'No credential values were printed or written to the telemetry snapshot.' -ForegroundColor DarkGray
Read-Host 'Press Enter to close'
