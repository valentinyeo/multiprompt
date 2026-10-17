$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'reconnect-accounts.ps1') -LoadFunctionsOnly

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    function Get-Item([string]$LiteralPath, [switch]$Force) {
        Microsoft.PowerShell.Management\Get-Item -LiteralPath $LiteralPath -Force
    }
}

function Assert-Equal([object]$Actual, [object]$Expected, [string]$Message) {
    if ($Actual -ne $Expected) {
        throw "$Message (expected $Expected, got $Actual)"
    }
}

function Write-TestCredential([string]$Directory, [long]$AccessExpiry, [long]$RefreshExpiry) {
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    @{
        claudeAiOauth = @{
            accessToken = 'test-access-token'
            refreshToken = 'test-refresh-token'
            expiresAt = $AccessExpiry
            refreshTokenExpiresAt = $RefreshExpiry
        }
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $Directory '.credentials.json') -Encoding utf8
}

$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRoot = Join-Path $tempBase ("multiprompt-telemetry-reconnect-" + [guid]::NewGuid().ToString('N'))
$resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
if (-not $resolvedTestRoot.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to create a reconnect test outside the system temporary directory.'
}

try {
    $now = [DateTimeOffset]::UtcNow
    $nowMs = $now.ToUnixTimeMilliseconds()
    $account = [pscustomobject]@{ Id = 'claude-test'; Label = 'test@example.com'; ConfigDir = $testRoot }
    Write-TestCredential $testRoot ($nowMs - 60000) ($nowMs + 86400000)

    $liveSnapshot = [pscustomobject]@{
        accounts = @([pscustomobject]@{
            id = $account.Id
            status = 'ok'
            error = $null
            lastUpdatedAt = $now.ToString('o')
            quotas = @([pscustomobject]@{ id = 'seven_day'; usedPercent = 4 })
        })
    }
    (Get-Item -Force -LiteralPath (Join-Path $testRoot '.credentials.json')).LastWriteTimeUtc = $now.UtcDateTime.AddMinutes(-2)
    $live = Get-ClaudeAccountAssessment $account $liveSnapshot
    Assert-Equal $live.NeedsLogin $false 'A live row with a usable refresh token reopened OAuth'
    Assert-Equal $live.CredentialChanged $false 'An older credential was marked newer than the live sample'

    $jsonSnapshot = $liveSnapshot | ConvertTo-Json -Depth 6 | ConvertFrom-Json
    $jsonLive = Get-ClaudeAccountAssessment $account $jsonSnapshot
    Assert-Equal $jsonLive.CredentialChanged $false 'A JSON timestamp converted to DateTime was compared through locale text'

    $providerErrorSnapshot = [pscustomobject]@{
        accounts = @([pscustomobject]@{
            id = $account.Id
            status = 'error'
            error = 'ProviderUnavailable'
            lastUpdatedAt = $now.ToString('o')
            quotas = @()
        })
    }
    $providerError = Get-ClaudeAccountAssessment $account $providerErrorSnapshot
    Assert-Equal $providerError.NeedsLogin $false 'A generic provider failure reopened OAuth'

    $credentialPath = Join-Path $testRoot '.credentials.json'
    (Get-Item -Force -LiteralPath $credentialPath).LastWriteTimeUtc = $now.UtcDateTime.AddMinutes(-2)
    $authFailureSnapshot = [pscustomobject]@{
        accounts = @([pscustomobject]@{
            id = $account.Id
            status = 'stale'
            error = 'AuthenticationRequired'
            lastUpdatedAt = $now.ToString('o')
            quotas = @()
        })
    }
    $authFailure = Get-ClaudeAccountAssessment $account $authFailureSnapshot
    Assert-Equal $authFailure.NeedsLogin $true 'An exact authentication failure was not offered OAuth'

    (Get-Item -Force -LiteralPath $credentialPath).LastWriteTimeUtc = $now.UtcDateTime.AddMinutes(2)
    $repaired = Get-ClaudeAccountAssessment $account $authFailureSnapshot
    Assert-Equal $repaired.NeedsLogin $false 'A credential repaired after the stale sample reopened OAuth'
    Assert-Equal $repaired.CredentialChanged $true 'The newer credential was not marked for collector restart'

    $missingAccount = [pscustomobject]@{ Id = 'claude-missing'; Label = 'missing@example.com'; ConfigDir = (Join-Path $testRoot 'missing') }
    $missing = Get-ClaudeAccountAssessment $missingAccount $liveSnapshot
    Assert-Equal $missing.NeedsLogin $true 'A missing credential was treated as current'

    Assert-Equal (Test-ClaudeAuthorizationCode 'short#short') $false 'A short unrelated clipboard value looked like an OAuth code'
    Assert-Equal (Test-ClaudeAuthorizationCode 'abcdefghijklmnopqrstuvwxyz#ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789-') $true 'A valid Claude authorization code was rejected'
    Assert-Equal (Test-ClaudeAuthorizationCode 'abcdefghijklmnopqrstuvwxyz#ABCDEFGHIJKLMNOPQRSTUVWXYZ+0123456789') $false 'A non-base64url clipboard value was accepted'

    @{ claudeAiOauth = @{ accessToken = 'test-access'; refreshToken = 'test-refresh' } } |
        ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $credentialPath -Encoding utf8
    $withoutExpiry = Read-ClaudeCredential $testRoot
    Assert-Equal $withoutExpiry.RefreshUsable $true 'Missing optional expiry fields discarded a renewable credential'
    Assert-Equal $withoutExpiry.Present $true 'Missing optional expiry fields discarded the access token'
    Assert-Equal $withoutExpiry.FutureExpiry $false 'Missing access expiry was treated as a future timestamp'
    $withoutExpiryAssessment = Get-ClaudeAccountAssessment $account $providerErrorSnapshot
    Assert-Equal $withoutExpiryAssessment.NeedsLogin $false 'Optional metadata forced a new login'

    $source = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'reconnect-accounts.ps1') -Raw
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$parseErrors)
    Assert-Equal $parseErrors.Count 0 'Reconnect script has syntax errors'
    $accountAssignment = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left.Extent.Text -eq '$claudeAccounts'
    }, $true)
    $config = '{"accounts":[{"id":"claude-primary","provider":"claude","label":"Primary","email":"you@example.com","configDir":"."},{"id":"claude-secondary","provider":"claude","label":"Secondary","configDir":"."}]}' | ConvertFrom-Json
    . ([scriptblock]::Create($accountAssignment.Extent.Text))
    Assert-Equal $claudeAccounts[0].Email 'you@example.com' 'Configured login email was not carried into the account'
    Assert-Equal $claudeAccounts[1].Email '' 'An account without email did not remain optional'

    $loginBlock = [regex]::Match($source, '(?ms)^        \$loginArguments = .*?^        \$loginProcess = .*?$').Value
    Assert-Equal ([string]::IsNullOrWhiteSpace($loginBlock)) $false 'Login argument construction was not found'
    function Start-Process($FilePath, $ArgumentList, [switch]$NoNewWindow, [switch]$PassThru) {
        return [pscustomobject]@{ Arguments = $ArgumentList }
    }
    $claudeExe = 'claude'
    foreach ($account in $claudeAccounts) {
        . ([scriptblock]::Create($loginBlock))
        $expectedArguments = if ($account.Email) { 'auth|login|--claudeai|--email|you@example.com' } else { 'auth|login|--claudeai' }
        Assert-Equal ($loginProcess.Arguments -join '|') $expectedArguments 'Login arguments used a display label or an unset email'
    }
    $account.Email = '   '
    . ([scriptblock]::Create($loginBlock))
    Assert-Equal ($loginProcess.Arguments -join '|') 'auth|login|--claudeai' 'Whitespace email was passed to Claude'

    Write-Output 'Reconnect account assessment: PASS'
} finally {
    if (Test-Path -LiteralPath $resolvedTestRoot) {
        [System.IO.Directory]::Delete($resolvedTestRoot, $true)
    }
}
