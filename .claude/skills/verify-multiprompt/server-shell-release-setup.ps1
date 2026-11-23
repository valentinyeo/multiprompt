. "$PSScriptRoot/../../../tools/verify-server-chat/native.ps1"
$serverProofStarted = $true
& "$PSScriptRoot/../../../tools/verify-server-chat/start.ps1" -Profile $scratch -Evidence $Evidence
$serverProofSettings = Join-Path $scratch 'roaming/ZigShell'
$serverProofRepo = (Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'wslpath', '-a', $env:GITHUB_WORKSPACE) -Evidence $Evidence -Name 'shell-repo-path').Trim()
$serverProofSsh = "$env:SystemRoot/System32/OpenSSH/ssh.exe"
function Read-ProofServer([string]$Command, [string]$Name) {
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Command))
    Invoke-ServerNative -FilePath $serverProofSsh -Arguments @('-F', "$serverProofSettings/ssh-key/config", '-o', 'ConnectTimeout=10', 'remote-1', "echo $encoded | base64 -d | timeout 30s bash") -Evidence $Evidence -Name $Name
}
$fixture = "$serverProofRepo/.claude/skills/verify-multiprompt/server-shell-release-fixture.py"
$fixtureResult = Read-ProofServer "python3 $fixture $serverProofRepo" 'shell-fixture'
Save-Json ($fixtureResult | ConvertFrom-Json) 'shell-fixture.json'
$env:PATH = (Split-Path $serverProofSsh) + ';' + $env:PATH
$seedJson = '{"active_tab":0,"single_window":true,"shared_server_connection":true,"tabs":[{"kind":"tmux","name":"Proof shell","manual":true,"tmux_host":0,"tmux_session":"proof-shell","cv":false,"shell_id":1,"used":1795000000,"pid":0}]}'
[IO.File]::WriteAllText((Join-Path $serverProofSettings 'session.json'), $seedJson, (New-Object Text.UTF8Encoding($false)))
Save-Json ($seedJson | ConvertFrom-Json) 'seed-session.json'
$result.seedBoundary = 'Runner-owned WSL Linux OpenSSH and real tmux. One saved tmux shell tab on the fixture proof-shell session is seeded only before launch; the plain server shell tab is opened through Ctrl+K. Shell processes, clipboard, wheel scroll, signals, layout and the server session are real; no user machine is involved.'
