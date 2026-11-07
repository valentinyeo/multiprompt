function New-GuardStage([string]$Exe, [string]$Profile, [string]$Root) {
    $exePath = (Resolve-Path -LiteralPath $Exe).Path
    $bridgePath = Join-Path (Split-Path -Parent $exePath) 'zigshell-bridge.exe'
    $configPath = Join-Path $Root 'tools/usage-telemetry/config.example.json'
    $helperPath = Join-Path $Root 'tools/usage-telemetry/kimi-usage.py'
    foreach ($path in @($exePath, $bridgePath, $configPath, $helperPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required staging file missing: $path" }
    }
    $bin = Join-Path $Profile 'app/bin'
    $telemetry = Join-Path $Profile 'tools/usage-telemetry'
    New-Item -ItemType Directory -Force $bin, $telemetry | Out-Null
    $files = @{}
    foreach ($item in @(
        @('exe', $exePath, (Join-Path $bin 'multiprompt.exe')),
        @('bridge', $bridgePath, (Join-Path $bin 'zigshell-bridge.exe')),
        @('config', $configPath, (Join-Path $telemetry 'config.example.json')),
        @('helper', $helperPath, (Join-Path $telemetry 'kimi-usage.py'))
    )) {
        Copy-Item -LiteralPath $item[1] -Destination $item[2] -Force
        $inputHash = (Get-FileHash -LiteralPath $item[1] -Algorithm SHA256).Hash
        $stagedHash = (Get-FileHash -LiteralPath $item[2] -Algorithm SHA256).Hash
        if ($inputHash -ne $stagedHash) { throw "Staging hash mismatch: $($item[0])" }
        $files[$item[0]] = @{ inputPath=$item[1]; inputSha256=$inputHash; stagedPath=$item[2]; stagedSha256=$stagedHash }
    }
    return $files
}
