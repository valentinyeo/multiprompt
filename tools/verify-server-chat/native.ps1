function Invoke-ServerNative {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Evidence,
        [Parameter(Mandatory)][string]$Name,
        [int]$TimeoutSeconds = 0
    )
    $commandLine = ($Arguments | ForEach-Object {
        if ($_ -ne '' -and $_ -notmatch '[\s"]') { $_ }
        else { '"' + ($_ -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"' }
    }) -join ' '
    [IO.File]::WriteAllText((Join-Path $Evidence "$Name.command-line.txt"), $commandLine)
    $stdout = Join-Path $Evidence "$Name.stdout.log"
    $stderr = Join-Path $Evidence "$Name.stderr.log"
    $process = Start-Process -FilePath (Get-Command $FilePath).Source -ArgumentList $commandLine -RedirectStandardOutput $stdout -RedirectStandardError $stderr -NoNewWindow -PassThru
    try {
        $null = $process.Handle
        if ($TimeoutSeconds -gt 0) {
            if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
                $process.Kill()
                [void]$process.WaitForExit(10000)
                [IO.File]::WriteAllText((Join-Path $Evidence "$Name.exit-code.txt"), 'timeout')
                throw "$Name did not finish in $TimeoutSeconds seconds; see $stderr"
            }
        } else {
            $process.WaitForExit()
        }
        [IO.File]::WriteAllText((Join-Path $Evidence "$Name.exit-code.txt"), [string]$process.ExitCode)
        if ($process.ExitCode -ne 0) { throw "$Name exited $($process.ExitCode); see $stderr" }
        return [IO.File]::ReadAllText($stdout)
    } finally {
        $process.Dispose()
    }
}
