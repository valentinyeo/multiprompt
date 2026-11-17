param(
    [Parameter(Mandatory=$true)][string]$Root,
    [Parameter(Mandatory=$true)][string]$HomePath,
    [string]$Evidence = ''
)
$ErrorActionPreference = 'Stop'
$arguments = @('--root', $Root, '--home', $HomePath, '--settings', (Join-Path $env:APPDATA 'ZigShell'))
if ($Evidence) { $arguments += @('--evidence', $Evidence) }
& python "$PSScriptRoot/seed-profile.py" @arguments
if ($LASTEXITCODE -ne 0) { throw 'Real-size profile generation failed' }
