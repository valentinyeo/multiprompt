param([Parameter(Mandatory)][string]$Profile, [Parameter(Mandatory)][string]$Evidence)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/native.ps1"
$settings = Join-Path $Profile 'roaming/ZigShell'
$keyDir = Join-Path $settings 'ssh-key'
New-Item -ItemType Directory -Force $keyDir, "$Profile/home/.ssh", "$Profile/local", $Evidence | Out-Null
$user = [Security.Principal.WindowsIdentity]::GetCurrent().User
$acl = [Security.AccessControl.DirectorySecurity]::new()
$acl.SetOwner($user)
$acl.SetAccessRuleProtection($true, $false)
$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($user, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
Set-Acl -LiteralPath $keyDir -AclObject $acl
$key = Join-Path $keyDir 'multibot_ed25519'
$ssh = "$env:SystemRoot/System32/OpenSSH/ssh.exe"
[void](Invoke-ServerNative -FilePath "$env:SystemRoot/System32/OpenSSH/ssh-keygen.exe" -Arguments @('-q', '-t', 'ed25519', '-N', '', '-f', $key) -Evidence $Evidence -Name 'ssh-keygen')
$fileAcl = [Security.AccessControl.FileSecurity]::new()
$fileAcl.SetOwner($user)
$fileAcl.SetAccessRuleProtection($true, $false)
$fileAcl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($user, 'FullControl', 'Allow'))
Set-Acl -LiteralPath $key -AclObject $fileAcl
$actual = Get-Acl -LiteralPath $key
$rules = @($actual.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
if (-not $actual.AreAccessRulesProtected -or $rules.Count -ne 1 -or $rules[0].IdentityReference.Value -ne $user.Value) { throw 'SSH private key is not restricted to the runner user' }
@{ owner = $user.Value; protected = $actual.AreAccessRulesProtected; rules = @($rules | ForEach-Object { @{ sid = $_.IdentityReference.Value; rights = [string]$_.FileSystemRights } }) } | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 "$Evidence/key-acl.json"
$repo = (Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'wslpath', '-a', $env:GITHUB_WORKSPACE) -Evidence $Evidence -Name 'start-repo-path').Trim()
$public = (Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'wslpath', '-a', "$key.pub") -Evidence $Evidence -Name 'public-key-path').Trim()
$serverMode = if ($env:REAL_PI_PROOF -eq '1') { 'real-pi' } else { 'deterministic' }
$started = Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'bash', "$repo/tools/verify-server-chat/start.sh", $repo, $public, $serverMode) -Evidence $Evidence -Name 'server-start'
Write-Host $started
$config = @"
Host remote-1
  HostName 127.0.0.1
  Port 2222
  User mpverify
  IdentityFile "$($key.Replace('\', '/'))"
  IdentitiesOnly yes
  IdentityAgent none
  BatchMode yes
  StrictHostKeyChecking yes
  UserKnownHostsFile "$((Join-Path $Profile 'home/.ssh/known_hosts').Replace('\', '/'))"
"@
[IO.File]::WriteAllText("$keyDir/config", $config)
$known = Invoke-ServerNative -FilePath "$env:SystemRoot/System32/OpenSSH/ssh-keyscan.exe" -Arguments @('-p', '2222', '-t', 'ed25519', '127.0.0.1') -Evidence $Evidence -Name 'ssh-keyscan'
if (-not $known.Trim()) { throw 'Runner server host key scan returned no key' }
[IO.File]::WriteAllText("$Profile/home/.ssh/known_hosts", ($known -join "`n") + "`n")
New-Item -ItemType Directory -Force "$env:USERPROFILE/.ssh" | Out-Null
[IO.File]::WriteAllText("$env:USERPROFILE/.ssh/known_hosts", ($known -join "`n") + "`n")
$warm = Invoke-ServerNative -FilePath $ssh -Arguments @('-F', "$keyDir/config", 'remote-1', 'uname -s && tmux -V && python3 --version') -Evidence $Evidence -Name 'ssh-preflight'
if ($warm -notmatch '(?s)Linux.*tmux.*Python') { throw "Real Windows OpenSSH preflight output is invalid: $warm" }
$warm | Set-Content -Encoding UTF8 "$Evidence/ssh-preflight.txt"
[IO.File]::WriteAllText("$settings/ssh-path.txt", $ssh)
[IO.File]::WriteAllText("$keyDir/servers.txt", "v1`nconnected`t1`t2222`t0`t127.0.0.1`tmpverify`tRunner Linux`t`nremoved`t0`t22`t0`t`t`t`t`nremoved`t0`t22`t0`t`t`t`t`n")
