$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'probe-native-version.ps1')

$evidence = Join-Path $env:RUNNER_TEMP 'probe-native-version-test'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null

$ok = Invoke-NativeVersionProbe -FilePath (Get-Command pwsh).Source -Arguments '-version' -Evidence $evidence
if ($ok.ExitCode -ne 0) { throw "A working program reported exit $($ok.ExitCode)" }
if ($ok.Line -notmatch '^PowerShell \d') { throw "A working program reported '$($ok.Line)' as its first line" }

$script = Join-Path $evidence 'three-lines.cmd'
@('@echo off', 'echo line one', 'ping -n 2 127.0.0.1 >nul', 'echo line two', 'ping -n 2 127.0.0.1 >nul', 'echo line three', 'echo boom 1>&2', 'exit /b 3') | Set-Content -Path $script
$cmd = (Get-Command cmd.exe).Source
$failed = Invoke-NativeVersionProbe -FilePath $cmd -Arguments @('/c', $script) -Evidence $evidence
if ($failed.ExitCode -ne 3) { throw "A program that exits 3 was reported as $($failed.ExitCode)" }
if ($failed.Line -ne 'line one') { throw "A program whose first line is 'line one' reported '$($failed.Line)'" }
if ($failed.Lines.Count -ne 3) { throw "A program that printed 3 lines had $($failed.Lines.Count) captured" }
if ($failed.ErrorText -notmatch 'boom') { throw "A program that printed 'boom' on stderr had '$($failed.ErrorText)' captured" }

& $cmd /c exit 7
if ($LASTEXITCODE -ne 7) { throw "The control program exited $LASTEXITCODE instead of 7" }
$stale = Invoke-NativeVersionProbe -FilePath $cmd -Arguments @('/c', $script) -Evidence $evidence
if ($stale.ExitCode -ne 3) { throw "After a program exited 7, a program that exits 3 was reported as $($stale.ExitCode)" }

$naive = (& $cmd /c $script 2>$null | Select-Object -First 1)
$naiveCode = $LASTEXITCODE
Write-Host "The truncated pipeline reported '$naiveCode' for a program that exits 3; the process probe reported 3"
if ($null -ne $naiveCode -and $naiveCode -eq 3) { throw 'The truncated pipeline now reports the real exit code; the install scripts no longer need this control' }

Write-Host 'The FFmpeg version probe reports the real exit code, every line and the stderr of the program it runs'
