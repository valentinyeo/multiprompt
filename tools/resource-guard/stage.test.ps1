$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'GitHub Windows only' }
. "$PSScriptRoot/stage.ps1"
function Check($condition, $message) { if (-not $condition) { throw $message } }
$base = Join-Path $env:RUNNER_TEMP ('guard-stage-test-' + [guid]::NewGuid().ToString('N'))
try {
    $root = Join-Path $base 'source'
    $telemetry = Join-Path $root 'tools/usage-telemetry'
    $shallow = Join-Path $base 'baseline-bin'
    $deep = Join-Path $base 'candidate/zig-out/bin'
    New-Item -ItemType Directory -Force $telemetry, $shallow, $deep | Out-Null
    Set-Content "$telemetry/config.example.json" 'public example'
    Set-Content "$telemetry/kimi-usage.py" 'public helper'
    Set-Content "$shallow/multiprompt-x64.exe" 'baseline app'
    Set-Content "$shallow/zigshell-bridge.exe" 'baseline bridge'
    Set-Content "$deep/multibot.exe" 'candidate app'
    Set-Content "$deep/zigshell-bridge.exe" 'candidate bridge'
    $a = New-GuardStage "$shallow/multiprompt-x64.exe" "$base/profile-a" $root
    $b = New-GuardStage "$deep/multibot.exe" "$base/profile-b" $root
    foreach ($stage in @($a, $b)) {
        $profile = Split-Path (Split-Path (Split-Path $stage.exe.stagedPath -Parent) -Parent) -Parent
        Check ($stage.exe.stagedPath -eq (Join-Path $profile 'app/bin/multibot.exe')) 'Executable layout differs'
        Check ($stage.config.stagedPath -eq (Join-Path $profile 'tools/usage-telemetry/config.example.json')) 'Telemetry lookup differs'
        foreach ($name in @('exe', 'bridge', 'config', 'helper')) {
            Check ($stage[$name].inputSha256 -eq $stage[$name].stagedSha256) "Hash mismatch: $name"
            Check ((Get-FileHash $stage[$name].stagedPath).Hash -eq (Get-FileHash $stage[$name].inputPath).Hash) "Wrong payload: $name"
        }
    }
    Check ($a.exe.inputPath -eq (Resolve-Path "$shallow/multiprompt-x64.exe").Path -and $b.exe.inputPath -eq (Resolve-Path "$deep/multibot.exe").Path) 'Executable provenance differs'
    Check ($a.bridge.inputPath -eq (Join-Path $shallow 'zigshell-bridge.exe') -and $b.bridge.inputPath -eq (Join-Path $deep 'zigshell-bridge.exe')) 'Bridge provenance differs'
    Check ($a.exe.stagedSha256 -ne $b.exe.stagedSha256 -and $a.bridge.stagedSha256 -ne $b.bridge.stagedSha256) 'Distinct payloads lost'
    Check ($a.config.stagedSha256 -eq $b.config.stagedSha256 -and $a.helper.stagedSha256 -eq $b.helper.stagedSha256) 'Telemetry environment differs'
    foreach ($missing in @("$deep/zigshell-bridge.exe", "$telemetry/config.example.json", "$telemetry/kimi-usage.py")) {
        $saved = "$missing.saved"
        Move-Item $missing $saved
        $failed = $false
        try { New-GuardStage "$deep/multibot.exe" "$base/missing" $root | Out-Null } catch { $failed = $_.Exception.Message -like '*Required staging file missing*' }
        Move-Item $saved $missing
        Check $failed "Missing file did not fail: $missing"
    }
    $failed = $false
    try { New-GuardStage "$deep/absent.exe" "$base/missing" $root | Out-Null } catch { $failed = $true }
    Check $failed 'Missing executable did not fail'
} finally {
    if (Test-Path $base) { Remove-Item $base -Recurse -Force }
}
