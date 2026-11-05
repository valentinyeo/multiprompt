param([Parameter(Mandatory)][string]$Request)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Hosted Windows only' }
Add-Type -AssemblyName System.Drawing
Add-Type -Path "$PSScriptRoot/../verify-chat-delivery/desktop.cs"
Add-Type -ReferencedAssemblies System, System.Core, System.Drawing -Path "$PSScriptRoot/../../.claude/skills/verify-multiprompt/control-native.cs"
$value = Get-Content $Request -Raw | ConvertFrom-Json
$main = [IntPtr][long]$value.hwnd
if ([ChatDeliveryDesktop]::Window([uint32]$value.pid) -ne $main -or [ChatDeliveryDesktop]::GetForegroundWindow() -ne $main -or [ChatDeliveryDesktop]::Focus($main)[1] -ne [long]$value.focus) { throw 'Native input ownership or focus changed' }
if ($value.kind -ceq 'keys') {
    [VerifyNative]::Chord([int[]]$value.keys)
} elseif ($value.kind -ceq 'text') {
    [VerifyNative]::Text([string]$value.text)
} else { throw 'Invalid native input kind' }
