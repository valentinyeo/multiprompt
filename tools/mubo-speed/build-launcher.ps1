param([string]$LauncherPath = 'harness/ssh.exe')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:OS -ne 'Windows_NT') { throw 'The boundary launcher builds only on GitHub Windows' }
$zig = '0.16.0'
$sha = '68659eb5f1e4eb1437a722f1dd889c5a322c9954607f5edcf337bc3684a75a7e'
if (-not (Get-Command zig -ErrorAction SilentlyContinue)) {
    $zip = "$env:RUNNER_TEMP/zig-$zig.zip"
    Invoke-WebRequest "https://ziglang.org/download/$zig/zig-x86_64-windows-$zig.zip" -OutFile $zip
    if ((Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sha) { throw 'Zig checksum mismatch' }
    tar -xf $zip -C $env:RUNNER_TEMP
    if ($LASTEXITCODE -ne 0) { throw 'Zig extraction failed' }
    "$env:RUNNER_TEMP/zig-x86_64-windows-$zig" | Out-File -Append -Encoding utf8 $env:GITHUB_PATH
    $env:PATH = "$env:RUNNER_TEMP/zig-x86_64-windows-$zig;$env:PATH"
}
New-Item -ItemType Directory -Force (Split-Path $LauncherPath) | Out-Null
zig cc -target x86_64-windows-gnu -municode -O2 tools/verify-chat-delivery/launcher.c -o $LauncherPath
if ($LASTEXITCODE -ne 0) { throw 'Boundary launcher build failed' }
Write-Host "built $((Resolve-Path $LauncherPath).Path)"
