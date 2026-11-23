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
$seed = @{ active_tab = 1; single_window = $true; shared_server_connection = $true; tabs = @(
    @{ kind = 'tmux'; name = 'Runner server chat'; manual = $true; tmux_host = 0; tmux_session = 'live-ci'; csid = 'a1b2c3d4-2567-4000-8000-000000002567'; cv = $false; shell_id = 1; used = 1795000000; pid = 0 },
    @{ kind = 'tmux'; name = 'Server shell proof'; manual = $true; tmux_host = 0; tmux_session = 'proof-shell'; cv = $false; shell_id = 2; used = 1795000001; pid = 0 }
) }
[IO.File]::WriteAllText((Join-Path $serverProofSettings 'session.json'), ($seed | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
Save-Json $seed 'seed-session.json'
$result.seedBoundary = 'Runner-owned WSL Linux OpenSSH and real tmux, reused from server-chat. Two saved tabs seeded only before launch. Only the paid provider is deterministic; shell processes, clipboard, signals, restart, server session identity and folders are real.'
