$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'GitHub Windows only' }
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$form = [Windows.Forms.Form]::new()
$form.Text = 'Picture picker switch target'
$form.Size = [Drawing.Size]::new(480, 240)
$form.StartPosition = 'CenterScreen'
try { [Windows.Forms.Application]::Run($form) } finally { $form.Dispose() }
