param([switch]$NativePicker, [string]$Receipt)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'GitHub Windows only' }
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$form = [Windows.Forms.Form]::new()
$form.Text = 'Picture picker switch target'
$form.Size = [Drawing.Size]::new(480, 240)
$form.StartPosition = 'CenterScreen'
if ($NativePicker) {
    $form.Add_Shown({
        $dialog = [Windows.Forms.OpenFileDialog]::new()
        $dialog.AutoUpgradeEnabled = $false
        $dialog.Title = 'Upload image'
        $dialog.Filter = 'Images|*.png;*.jpg;*.jpeg'
        $dialog.CheckFileExists = $true
        $dialog.CheckPathExists = $true
        $dialog.RestoreDirectory = $true
        try {
            $answer = $dialog.ShowDialog($form)
            [IO.File]::WriteAllText($Receipt, (@{answer=$answer.ToString(); selected=$dialog.FileName} | ConvertTo-Json))
        } finally { $dialog.Dispose(); $form.Close() }
    })
}
try { [Windows.Forms.Application]::Run($form) } finally { $form.Dispose() }
