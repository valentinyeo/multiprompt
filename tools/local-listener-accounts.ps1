$ErrorActionPreference = 'Stop'
$account = 'mp' + [Guid]::NewGuid().ToString('N').Substring(0, 16)
$directory = Join-Path $env:RUNNER_TEMP ('local-listeners-' + [Guid]::NewGuid().ToString('N'))
$clientDirectory = Join-Path $env:PUBLIC ('local-listeners-' + [Guid]::NewGuid().ToString('N'))
$helper = $null
$created = $false
try {
    New-Item -ItemType Directory $directory, $clientDirectory | Out-Null
    $secret = ConvertTo-SecureString ('Aa1!' + [Guid]::NewGuid().ToString('N') + [Guid]::NewGuid().ToString('N')) -AsPlainText -Force
    $user = New-LocalUser -Name $account -Password $secret -AccountNeverExpires
    $created = $true
    Add-LocalGroupMember -SID 'S-1-5-32-545' -Member $user
    $credential = [PSCredential]::new("$env:COMPUTERNAME\$account", $secret)
    & icacls $clientDirectory /grant "*$($user.SID.Value):(OI)(CI)M" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Client folder access failed' }
    $clientScript = Join-Path $clientDirectory 'client.ps1'
    @'
param([int]$Port, [string]$Request, [string]$Expected)
[Console]::WriteLine('started')
$ErrorActionPreference = 'Stop'
$client = $null
try {
    $client = [System.Net.Sockets.TcpClient]::new()
    $client.ReceiveTimeout = 10000
    $client.SendTimeout = 10000
    $client.Connect('127.0.0.1', $Port)
    [Console]::WriteLine('connected')
    $stream = $client.GetStream()
    $bytes = [Convert]::FromBase64String($Request)
    $count = 0
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $buffer = [byte[]]::new(4096)
        $count = $stream.Read($buffer, 0, $buffer.Length)
    } catch {
        $cause = $_.Exception
        while ($cause -and $cause -isnot [System.Net.Sockets.SocketException]) { $cause = $cause.InnerException }
        $closedErrors = @([System.Net.Sockets.SocketError]::ConnectionReset, [System.Net.Sockets.SocketError]::ConnectionAborted, [System.Net.Sockets.SocketError]::Shutdown)
        if ($Expected -ne 'closed' -or -not $cause -or $cause.SocketErrorCode -notin $closedErrors) { throw }
        $count = -1
    }
    if ($Expected -eq 'reply') {
        if ($count -le 0) { throw 'Expected listener reply' }
    } elseif ($count -gt 0) {
        throw 'Unexpected listener reply'
    }
} catch {
    [Console]::Error.WriteLine($_.Exception.ToString())
    $cause = $_.Exception
    while ($cause) {
        [Console]::Error.WriteLine("$($cause.GetType().FullName): $($cause.Message)")
        if ($cause -is [System.Net.Sockets.SocketException]) {
            [Console]::Error.WriteLine("SocketErrorCode: $($cause.SocketErrorCode)")
        }
        $cause = $cause.InnerException
    }
    exit 1
} finally {
    if ($client) { $client.Dispose() }
}
exit 0
'@ | Set-Content -Encoding utf8 $clientScript
    $warmupOut = Join-Path $clientDirectory 'warmup.out'
    $warmupErr = Join-Path $clientDirectory 'warmup.err'
    $warmupOptions = @{ FilePath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"; ArgumentList = '-NoProfile -NonInteractive -Command "exit 0"'; PassThru = $true; WorkingDirectory = $clientDirectory; RedirectStandardOutput = $warmupOut; RedirectStandardError = $warmupErr; Credential = $credential; LoadUserProfile = $true }
    $warmup = $null
    $warmupClock = [Diagnostics.Stopwatch]::StartNew()
    try {
        $warmup = Start-Process @warmupOptions
        if (-not $warmup.WaitForExit(180000)) { throw 'Account warm-up did not finish within 180 seconds' }
        $warmup.WaitForExit()
        if ($warmup.ExitCode -ne 0) { throw "Account warm-up failed (exit=$($warmup.ExitCode))" }
    } catch {
        foreach ($log in @($warmupOut, $warmupErr)) {
            Write-Host "--- $log ---"
            if (Test-Path $log) { Write-Host (Get-Content $log -Raw) }
            else { Write-Host '(not written)' }
        }
        throw
    } finally {
        $warmupClock.Stop()
        Write-Host ('Account warm-up took {0:N1} seconds' -f $warmupClock.Elapsed.TotalSeconds)
        if ($warmup) {
            if (-not $warmup.HasExited) { Stop-Process -Id $warmup.Id -Force }
            $warmup.Dispose()
        }
    }
    $env:IGSH664_LISTENER_DIR = $directory
    $helper = Start-Process -FilePath (Resolve-Path 'zig-out/bin/local-listener-helper.exe') -PassThru -RedirectStandardOutput (Join-Path $directory 'helper.out') -RedirectStandardError (Join-Path $directory 'helper.err')
    Remove-Item Env:IGSH664_LISTENER_DIR
    $portsFile = Join-Path $directory 'ports'
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while (-not (Test-Path $portsFile)) {
        if ($helper.HasExited) { throw (Get-Content (Join-Path $directory 'helper.err') -Raw) }
        if ([DateTime]::UtcNow -ge $deadline) { throw 'Listener ports were not written' }
        Start-Sleep -Milliseconds 20
    }
    $ports = @(Get-Content $portsFile | ForEach-Object { [int]$_ })
    if ($ports.Count -ne 2 -or $ports[0] -le 0 -or $ports[1] -le 0) { throw 'Expected both listener ports' }
    $requests = @(("SHOT:0:https://example.invalid/a`n"), ("ZSB:workspace:d29ya3NwYWNlLWxpc3Q=`n"))
    $index = 0
    foreach ($identity in @('other', 'same')) {
        for ($i = 0; $i -lt $ports.Count; $i++) {
            $expected = if ($identity -eq 'same' -and $i -eq 1) { 'reply' } else { 'closed' }
            $request = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($requests[$i]))
            $arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$clientScript`" -Port $($ports[$i]) -Request $request -Expected $expected"
            $clientOut = Join-Path $clientDirectory "client-$index.out"
            $clientErr = Join-Path $clientDirectory "client-$index.err"
            $options = @{ FilePath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"; ArgumentList = $arguments; PassThru = $true; WorkingDirectory = $clientDirectory; RedirectStandardOutput = $clientOut; RedirectStandardError = $clientErr }
            if ($identity -eq 'other') { $options.Credential = $credential; $options.LoadUserProfile = $true }
            $process = $null
            try {
                $process = Start-Process @options
                if (-not $process.WaitForExit(60000)) { throw 'Client did not finish within 60 seconds' }
                $process.WaitForExit()
                if ($process.ExitCode -ne 0) { throw "Client exchange failed (account=$identity, port=$($ports[$i]), expected=$expected, exit=$($process.ExitCode))" }
            } catch {
                foreach ($log in @($clientOut, $clientErr, (Join-Path $directory 'helper.out'), (Join-Path $directory 'helper.err'))) {
                    Write-Host "--- $log ---"
                    if (Test-Path $log) { Write-Host (Get-Content $log -Raw) }
                    else { Write-Host '(not written)' }
                }
                throw
            } finally {
                if ($process) {
                    if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
                    $process.Dispose()
                }
            }
            $decisionFile = Join-Path $directory "decision-$index"
            $deadline = [DateTime]::UtcNow.AddSeconds(5)
            while (-not (Test-Path $decisionFile)) {
                if ([DateTime]::UtcNow -ge $deadline) { throw 'Listener decision was not written' }
                Start-Sleep -Milliseconds 20
            }
            $decision = if ($identity -eq 'other') { 'rejected' } else { 'accepted' }
            $actualDecision = Get-Content $decisionFile -Raw
            if ($actualDecision -cne "$($ports[$i]):$decision") { throw "Listener decision did not match account (file=$decisionFile, expected=$($ports[$i]):$decision, actual=[$actualDecision])" }
            $index++
        }
        if ($identity -eq 'other') { Write-Host 'IGSH664_OTHER_USER_REJECTED' }
        else { Write-Host 'IGSH664_SAME_USER_ACCEPTED' }
    }
    Set-Content (Join-Path $directory 'done') 'done'
    if (-not $helper.WaitForExit(10000)) { throw 'Listener helper did not finish' }
    if ($helper.ExitCode -ne 0) { throw (Get-Content (Join-Path $directory 'helper.err') -Raw) }
} finally {
    Remove-Item Env:IGSH664_LISTENER_DIR -ErrorAction SilentlyContinue
    try {
        if ($helper) {
            if (-not $helper.HasExited) { Stop-Process -Id $helper.Id -Force }
            $helper.Dispose()
        }
    } finally {
        try {
            if ($created) { Remove-LocalUser -Name $account }
        } finally {
            Remove-Item $directory, $clientDirectory -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
