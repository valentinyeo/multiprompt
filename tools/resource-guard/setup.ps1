$ErrorActionPreference = 'Stop'
$zip = "$env:RUNNER_TEMP/zig.zip"
Invoke-WebRequest https://ziglang.org/download/0.16.0/zig-x86_64-windows-0.16.0.zip -OutFile $zip
if ((Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant() -ne '68659eb5f1e4eb1437a722f1dd889c5a322c9954607f5edcf337bc3684a75a7e') { throw 'Zig checksum mismatch' }
tar -xf $zip -C $env:RUNNER_TEMP
if ($LASTEXITCODE -ne 0) { throw 'Zig extraction failed' }
$zigDir = "$env:RUNNER_TEMP/zig-x86_64-windows-0.16.0"
$zigDir | Out-File -Append -Encoding utf8 $env:GITHUB_PATH
$zig = "$zigDir/zig.exe"
New-Item -ItemType Directory -Force fixture-bin,baseline-bin | Out-Null
& $zig cc -target x86_64-windows-gnu -municode -o fixture-bin/ssh.exe tools/verify-chat-delivery/launcher.c
if ($LASTEXITCODE -ne 0) { throw 'Fixture compile failed' }
& $zig cc -target x86_64-windows-gnu -municode -mwindows -o fixture-bin/tmux.exe tools/verify-chat-delivery/launcher.c
if ($LASTEXITCODE -ne 0) { throw 'tmux fixture compile failed' }
$tag = (Get-Content tools/resource-guard/limits.json -Raw | ConvertFrom-Json).baselineTag
if ($tag -notmatch '^v\d+\.\d+\.\d+$') { throw 'Invalid baseline tag' }
gh release download $tag --repo $env:GITHUB_REPOSITORY --pattern multiprompt-x64.exe --pattern zigshell-bridge-x64.exe --pattern "SHA256SUMS.txt*" --dir baseline-bin
if ($LASTEXITCODE -ne 0) { throw 'Baseline download failed' }
node tools/resource-guard/verify-baseline.mjs
if ($LASTEXITCODE -ne 0) { throw 'Baseline signature or checksum invalid' }
Copy-Item baseline-bin/zigshell-bridge-x64.exe baseline-bin/zigshell-bridge.exe
