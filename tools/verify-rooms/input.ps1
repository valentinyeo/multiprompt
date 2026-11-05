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
} elseif ($value.kind -ceq 'click-composer') {
    $room = [VerifyNative]::FindWindowEx($main, [IntPtr]::Zero, 'MultiPromptRoomView', 'Room')
    if ($room -eq [IntPtr]::Zero -or ![VerifyNative]::IsWindowVisible($room)) { throw 'Room is not visible' }
    $composer = [ChatDeliveryDesktop]::Composer($room)
    if ($composer -eq [IntPtr]::Zero -or $composer.ToInt64() -ne [long]$value.target -or [ChatDeliveryDesktop]::Class($composer) -cne 'Edit') { throw 'Composer changed before click' }
    $bounds = New-Object ChatDeliveryDesktop+Rect
    if (![ChatDeliveryDesktop]::GetClientRect($composer, [ref]$bounds)) { throw 'Composer geometry unavailable' }
    [ChatDeliveryDesktop]::PressClient($composer, [uint32]$value.pid, [int](($bounds.Right - $bounds.Left) / 2), [int](($bounds.Bottom - $bounds.Top) / 2))
} else { throw 'Invalid native input kind' }
