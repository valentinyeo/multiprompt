param([string]$LauncherPath = 'harness/ssh.exe')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:OS -ne 'Windows_NT') { throw 'The boundary launcher builds only on GitHub Windows' }
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path $vswhere)) { throw "vswhere not found at $vswhere" }
$visualStudio = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $visualStudio) { throw 'No Visual Studio C++ toolchain on this runner' }
$vcvars = Join-Path $visualStudio 'VC\Auxiliary\Build\vcvars64.bat'
if (-not (Test-Path $vcvars)) { throw "vcvars64 not found at $vcvars" }
New-Item -ItemType Directory -Force (Split-Path $LauncherPath) | Out-Null
$source = (Resolve-Path 'tools/verify-chat-delivery/launcher.c').Path
$target = Join-Path (Resolve-Path (Split-Path $LauncherPath)).Path (Split-Path $LauncherPath -Leaf)
$command = 'call "{0}" >nul && cl /nologo /O2 /MT "{1}" /Fe:"{2}"' -f $vcvars, $source, $target
& cmd.exe /c $command
if ($LASTEXITCODE -ne 0) { throw 'Boundary launcher build failed' }
if (-not (Test-Path $target)) { throw "Boundary launcher missing at $target" }
Write-Host "built $target"
