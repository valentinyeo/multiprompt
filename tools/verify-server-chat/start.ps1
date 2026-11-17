param([Parameter(Mandatory)][string]$Profile, [Parameter(Mandatory)][string]$Evidence)
$ErrorActionPreference = 'Stop'
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
$env:SERVER_CHAT_KEY = $key
python -c "import os,subprocess; subprocess.run([os.environ['SystemRoot']+'/System32/OpenSSH/ssh-keygen.exe','-q','-t','ed25519','-N','','-f',os.environ['SERVER_CHAT_KEY']],check=True)"
if ($LASTEXITCODE -ne 0) { throw 'Per-run SSH key generation failed' }
$fileAcl = [Security.AccessControl.FileSecurity]::new()
$fileAcl.SetOwner($user)
$fileAcl.SetAccessRuleProtection($true, $false)
$fileAcl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($user, 'FullControl', 'Allow'))
Set-Acl -LiteralPath $key -AclObject $fileAcl
$actual = Get-Acl -LiteralPath $key
$rules = @($actual.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
if (-not $actual.AreAccessRulesProtected -or $rules.Count -ne 1 -or $rules[0].IdentityReference.Value -ne $user.Value) { throw 'SSH private key is not restricted to the runner user' }
@{ owner = $user.Value; protected = $actual.AreAccessRulesProtected; rules = @($rules | ForEach-Object { @{ sid = $_.IdentityReference.Value; rights = [string]$_.FileSystemRights } }) } | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 "$Evidence/key-acl.json"
$repo = (& wsl.exe -d Ubuntu-24.04 -u root -- wslpath -a $env:GITHUB_WORKSPACE).Trim()
$public = (& wsl.exe -d Ubuntu-24.04 -u root -- wslpath -a "$key.pub").Trim()
$runtime = if ($env:VERIFY_APP_REVISION) { "$repo/app-source" } else { $repo }
& wsl.exe -d Ubuntu-24.04 -u root -- bash "$repo/tools/verify-server-chat/start.sh" $repo $public $runtime 2>&1 | Tee-Object "$Evidence/server-start.log"
if ($LASTEXITCODE -ne 0) { throw 'Runner-owned Linux server failed to start' }
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
$known = & "$env:SystemRoot/System32/OpenSSH/ssh-keyscan.exe" -p 2222 -t ed25519 127.0.0.1 2>$null
if ($LASTEXITCODE -ne 0 -or -not $known) { throw 'Runner server host key scan failed' }
[IO.File]::WriteAllText("$Profile/home/.ssh/known_hosts", ($known -join "`n") + "`n")
New-Item -ItemType Directory -Force "$env:USERPROFILE/.ssh" | Out-Null
[IO.File]::WriteAllText("$env:USERPROFILE/.ssh/known_hosts", ($known -join "`n") + "`n")
$warm = & $ssh -F "$keyDir/config" remote-1 'uname -s; tmux -V; python3 --version'
if ($LASTEXITCODE -ne 0 -or ($warm -join ' ') -notmatch 'Linux.*tmux.*Python') { throw "Real Windows OpenSSH preflight failed: $warm" }
$warm | Set-Content -Encoding UTF8 "$Evidence/ssh-preflight.txt"
[IO.File]::WriteAllText("$settings/ssh-path.txt", $ssh)
[IO.File]::WriteAllText("$keyDir/servers.txt", "v1`nconnected`t1`t2222`t0`t127.0.0.1`tmpverify`tRunner Linux`t`nremoved`t0`t22`t0`t`t`t`t`nremoved`t0`t22`t0`t`t`t`t`n")
