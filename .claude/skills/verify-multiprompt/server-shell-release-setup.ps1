. "$PSScriptRoot/../../../tools/verify-server-chat/native.ps1"
$serverProofStarted = $true
& "$PSScriptRoot/../../../tools/verify-server-chat/start.ps1" -Profile $scratch -Evidence $Evidence
$serverProofSettings = Join-Path $scratch 'roaming/ZigShell'
$serverProofRepo = (Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'wslpath', '-a', $env:GITHUB_WORKSPACE) -Evidence $Evidence -Name 'shell-repo-path').Trim()
$serverProofSsh = "$env:SystemRoot/System32/OpenSSH/ssh.exe"
function Read-ProofServer([string]$Command, [string]$Name, [int]$DeadlineSeconds = 45) {
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Command))
    $arguments = @('-F', "$serverProofSettings/ssh-key/config", '-o', 'ConnectTimeout=10', '-o', 'BatchMode=yes', '-o', 'ServerAliveInterval=5', '-o', 'ServerAliveCountMax=2', 'remote-1', "echo $encoded | base64 -d | timeout 30s bash")
    $commandLine = ($arguments | ForEach-Object {
        if ($_ -ne '' -and $_ -notmatch '[\s"]') { $_ }
        else { '"' + ($_ -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"' }
    }) -join ' '
    [IO.File]::WriteAllText((Join-Path $Evidence "$Name.command-line.txt"), $commandLine)
    $stdout = Join-Path $Evidence "$Name.stdout.log"
    $stderr = Join-Path $Evidence "$Name.stderr.log"
    $process = Start-Process -FilePath (Get-Command $serverProofSsh).Source -ArgumentList $commandLine -RedirectStandardOutput $stdout -RedirectStandardError $stderr -NoNewWindow -PassThru
    try {
        $null = $process.Handle
        if (-not $process.WaitForExit($DeadlineSeconds * 1000)) {
            try { $process.Kill() } catch {}
            throw ($Name + ' timed out after ' + $DeadlineSeconds + ' s; see ' + $stderr)
        }
        [IO.File]::WriteAllText((Join-Path $Evidence "$Name.exit-code.txt"), [string]$process.ExitCode)
        if ($process.ExitCode -ne 0) { throw ($Name + ' exited ' + $process.ExitCode + '; see ' + $stderr) }
        return [IO.File]::ReadAllText($stdout)
    } finally {
        $process.Dispose()
    }
}
$script:proofLastHostsSync = [DateTime]::MinValue
function Proof-SyncKnownHosts {
    $now = [DateTime]::UtcNow
    if (($now - $script:proofLastHostsSync).TotalSeconds -lt 2) { return }
    $script:proofLastHostsSync = $now
    $knownHosts = Join-Path $scratch 'home/.ssh/known_hosts'
    $scanName = 'shell-known-hosts-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $scan = (Invoke-ServerNative -FilePath "$env:SystemRoot/System32/OpenSSH/ssh-keyscan.exe" -Arguments @('-p', '2222', '-t', 'ed25519', '127.0.0.1') -Evidence $Evidence -Name $scanName).Trim()
    $lines = @($scan -split "`n" | Where-Object { $_.Trim() })
    if ($lines.Count -eq 0) { throw 'host key scan returned no entries for the runner server' }
    New-Item -ItemType Directory -Force (Split-Path $knownHosts) | Out-Null
    [IO.File]::WriteAllText($knownHosts, ($lines -join "`n") + "`n")
    New-Item -ItemType Directory -Force "$env:USERPROFILE/.ssh" -ErrorAction SilentlyContinue | Out-Null
    [IO.File]::WriteAllText("$env:USERPROFILE/.ssh/known_hosts", ($lines -join "`n") + "`n")
    Save-Json @{ knownHosts = $knownHosts; lines = $lines.Count; at = [DateTime]::UtcNow.ToString('o') } 'shell-known-hosts.json'
}

$fixture = "$serverProofRepo/.claude/skills/verify-multiprompt/server-shell-release-fixture.py"
$fixtureResult = Read-ProofServer "python3 $fixture $serverProofRepo" 'shell-fixture'
Save-Json ($fixtureResult | ConvertFrom-Json) 'shell-fixture.json'
$env:PATH = (Split-Path $serverProofSsh) + ';' + $env:PATH
$seedJson = '{"active_tab":0,"single_window":true,"shared_server_connection":true,"tabs":[{"kind":"tmux","name":"Proof shell","manual":true,"tmux_host":0,"tmux_session":"proof-shell","cv":false,"shell_id":1,"used":1795000000,"pid":0}]}'
[IO.File]::WriteAllText((Join-Path $serverProofSettings 'session.json'), $seedJson, (New-Object Text.UTF8Encoding($false)))
Save-Json ($seedJson | ConvertFrom-Json) 'seed-session.json'
$result.seedBoundary = 'Runner-owned WSL Linux OpenSSH and real tmux. One saved tmux shell tab on the fixture proof-shell session is seeded only before launch; the plain server shell tab is opened through Ctrl+K. Shell processes, clipboard, wheel scroll, signals, layout and the server session are real; no user machine is involved.'