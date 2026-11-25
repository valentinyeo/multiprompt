function Invoke-NativeVersionProbe {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Evidence
    )
    $resolved = (Get-Command $FilePath).Source
    $commandLine = ($Arguments | ForEach-Object {
        if ($_ -ne '' -and $_ -notmatch '[\s"]') { $_ }
        else { '"' + ($_ -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"' }
    }) -join ' '
    $label = [IO.Path]::GetFileNameWithoutExtension($resolved)
    $stdout = Join-Path $Evidence "$label.stdout.log"
    $stderr = Join-Path $Evidence "$label.stderr.log"
    $process = Start-Process -FilePath $resolved -ArgumentList $commandLine -RedirectStandardOutput $stdout -RedirectStandardError $stderr -NoNewWindow -PassThru
    try {
        $null = $process.Handle
        $process.WaitForExit()
        $exitCode = $process.ExitCode
    } finally {
        $process.Dispose()
    }
    $lines = @(Get-Content -LiteralPath $stdout -ErrorAction SilentlyContinue)
    $errors = @(Get-Content -LiteralPath $stderr -ErrorAction SilentlyContinue)
    [pscustomobject]@{
        ExitCode = $exitCode
        Line = $(if ($lines.Count) { [string]$lines[0] } else { '' })
        Lines = $lines
        ErrorText = ($errors -join "`n")
    }
}
