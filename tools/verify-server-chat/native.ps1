function Invoke-ServerNative {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Evidence,
        [Parameter(Mandatory)][string]$Name
    )
    $commandLine = ($Arguments | ForEach-Object { '"' + ($_ -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"' }) -join ' '
    $stdout = Join-Path $Evidence "$Name.stdout.log"
    $stderr = Join-Path $Evidence "$Name.stderr.log"
    $process = Start-Process -FilePath (Get-Command $FilePath).Source -ArgumentList $commandLine -RedirectStandardOutput $stdout -RedirectStandardError $stderr -NoNewWindow -PassThru
    try {
        $null = $process.Handle
        $process.WaitForExit()
        [IO.File]::WriteAllText((Join-Path $Evidence "$Name.exit-code.txt"), [string]$process.ExitCode)
        if ($process.ExitCode -ne 0) { throw "$Name exited $($process.ExitCode); see $stderr" }
        return [IO.File]::ReadAllText($stdout)
    } finally {
        $process.Dispose()
    }
}
