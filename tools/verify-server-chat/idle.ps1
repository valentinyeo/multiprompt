function Read-SshLogins([string]$Name) {
    $text = Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'cat', '/tmp/mp-ci-sshd.log') -Evidence $Evidence -Name $Name
    return @([regex]::Matches($text, 'Accepted publickey for mpverify')).Count
}
function Measure-SshIdle([string]$Name, [int]$Seconds = 210) {
    Doctor
    $before = Read-SshLogins "$Name-before"
    $started = [ChatDeliveryDesktop]::GetTickCount64()
    $timer = [Diagnostics.Stopwatch]::StartNew()
    Start-Sleep -Seconds $Seconds
    $timer.Stop()
    $finished = [ChatDeliveryDesktop]::GetTickCount64()
    Doctor
    $after = Read-SshLogins "$Name-after"
    $spawns = @(Get-ChildItem "$Evidence/ssh-spawns/*.txt" | ForEach-Object {
        $lines = [IO.File]::ReadAllLines($_.FullName)
        if ([long]$lines[0] -ge $started -and [long]$lines[0] -le $finished) {
            $command = $lines[1]
            if ($command -notmatch '(?:^|\s)-(?:V|G)(?:\s|$)') {
                $caller = if ($command -match 'tmux list-clients') { 'reconnect-probe' }
                    elseif ($command -match 'token-ladder/status.json') { 'usage-card' }
                    elseif ($command -match 'base64.b64decode') { 'chat-transport-bootstrap' }
                    elseif ($command -match 'while IFS= read') { 'capacity-channel' }
                    elseif ($command -match 'tmux list-sessions') { 'capacity-fallback' }
                    elseif ($command -match 'MP_RELAY') { 'reader-relay-bootstrap' }
                    elseif ($command -match '(?:^|\s)-N(?:\s|$)') { 'notification-forward' }
                    else { 'other' }
                @{ pid = $_.BaseName; tick = [long]$lines[0]; caller = $caller; command = $command }
            }
        }
    })
    $proof = @{ name = $Name; seconds = $timer.Elapsed.TotalSeconds; logins = $after - $before;
        logins_per_hour = ($after - $before) * 3600 / $timer.Elapsed.TotalSeconds;
        ssh_spawns = $spawns.Count; callers = @($spawns | Group-Object { $_.caller } | ForEach-Object { @{ caller = $_.Name; count = $_.Count } });
        spawns = $spawns; passed = ($after - $before -eq 0 -and $spawns.Count -eq 0);
        boundary = 'Real Windows OpenSSH to runner-owned sshd; transparent argv-counting wrapper; no harness SSH during observation' }
    Save $proof "$Evidence/$Name.json"
    Shot $Name
    Write-Host ($proof | ConvertTo-Json -Depth 8)
    if (-not $proof.passed) { throw "Idle SSH login bound exceeded; see $Name.json" }
}
function Verify-SshRecovery {
    $before = Read-SshLogins 'drop-before'
    $owned = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'count-ssh.exe' -and $_.ParentProcessId -eq $app.Id -and $_.CommandLine -match 'base64.b64decode' -and $_.CommandLine -match '(?:^|\s)remote-1(?:\s|$)' })
    if ($owned.Count -ne 1) { throw "Expected one server-chat transport before dropping the link, found $($owned.Count)" }
    $links = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'ssh.exe' -and $_.ParentProcessId -eq $owned[0].ProcessId })
    if ($links.Count -ne 1) { throw 'The counting wrapper must own one real SSH process' }
    $actions.Add(@{ input = 'drop runner-owned SSH transport'; pid = $links[0].ProcessId; at = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() })
    Stop-Process -Id $links[0].ProcessId -Force
    Send-Line 'windows reconnect proof'
    [void](Wait-For 'server receipt after dropped SSH link' { $snapshot = Server-Snapshot 'reconnect-server'; @($snapshot.inputs | Where-Object { $_.text -ceq 'windows reconnect proof' }).Count -eq 1 })
    [void](Wait-For 'reply after dropped SSH link' { (Copy-Chat 'reconnect-copied').Contains('Server received: windows reconnect proof') })
    $after = Read-SshLogins 'drop-after'
    Save @{ passed = $true; old_transport = $links[0].ProcessId; new_logins = $after - $before } "$Evidence/reconnect.json"
    Shot 'reconnect'
    Measure-SshIdle 'idle-after-reconnect'
}
