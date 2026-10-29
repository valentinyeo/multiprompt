$ownerProof = $env:OWNER_BROWSER_PROOF | ConvertFrom-Json
if ($ownerProof.session -notmatch '^mp-proof-[a-z0-9-]+$') { throw 'Expected an isolated proof session' }
$log = Join-Path $scratch 'roaming/ZigShell/debug.log'
$listeners = [regex]::Matches((Read-SharedText $log), 'notify-listener: tunnel-inbound listening port=(\d+) err=0')
if ($listeners.Count -eq 0) { throw 'Owned browser listener missing' }
$ownerPort = [int]$listeners[$listeners.Count - 1].Groups[1].Value
if (@(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort $ownerPort | Where-Object { $_.OwningProcess -eq $process.Id }).Count -ne 1) { throw 'Browser listener does not belong to the verified app' }
Palette 'move to group'
Press @(0x0D) 'Enter: group menu'
Type-Text 'new group'
Press @(0x0D) 'Enter: create proof group'
Wait-Until { $state = Read-Session; @($state.groups).Count -gt 0 } 'owner browser proof group'
$layout = Invoke-Zsb @('workspace-list') $ownerPort 'owner-layout'
$workspace = @($layout.workspaces | Where-Object { $_.active })[0]
$group = @($workspace.groups | Where-Object { @($_.tabs).Count -gt 0 })[-1]
if (-not $group.name) { throw 'Owner proof group not listed' }
$created = Invoke-Zsb @('session-open', '--workspace', $workspace.name, '--group', $group.name, '--host', 'remote-1', '--tmux', $ownerProof.session, '--name', 'Owner browser proof') $ownerPort 'owner-open-tab'
if (-not $created.created -or $created.tab -le 0) { throw 'Owner proof tab not created' }
Press @(0x11, 0x32) 'Ctrl+2: select owner proof tab'
Wait-Until { (Read-Inbox).active_shell_id -eq $created.tab } 'owner proof tab selected'
$pageRoot = Join-Path $scratch 'owner-page'
New-Item -ItemType Directory -Force $pageRoot | Out-Null
[IO.File]::WriteAllText((Join-Path $pageRoot 'index.html'), ('<!doctype html><title>Owner browser proof</title><h1>' + $ownerProof.session + '</h1><button id="proof-button" onclick="document.getElementById(''proof-result'').textContent=''Clicked''">Click</button><p id="proof-result">Not clicked</p>'))
$pageJob = New-Object VerifyJob
$remote = $null
$key = Join-Path $env:RUNNER_TEMP 'owner-browser-key'
try {
$pageServer = $pageJob.Start((Get-Command python.exe).Source, $pageRoot, (Join-Path $Evidence 'owner-page.stdout.log'), (Join-Path $Evidence 'owner-page.stderr.log'), '-m http.server 19283 --bind 127.0.0.1')
Wait-Until { try { (Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1:19283/').Content.Contains($ownerProof.session) } catch { $false } } 'owner proof web page'
$known = Join-Path $scratch 'owner-known-hosts'
[IO.File]::WriteAllText($known, $ownerProof.knownHost + "`n")
$ssh = Join-Path $env:WINDIR 'System32/OpenSSH/ssh.exe'
$arguments = '-o BatchMode=yes -o StrictHostKeyChecking=yes -o ExitOnForwardFailure=yes -o StreamLocalBindUnlink=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o "UserKnownHostsFile=' + $known + '" -i "' + $key + '" -R "' + $ownerProof.tunnel + ':127.0.0.1:' + $ownerPort + '" ' + $ownerProof.target + ' proof'
$remote = Start-Process -FilePath $ssh -ArgumentList $arguments -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $Evidence 'owner-browser-live.json') -RedirectStandardError (Join-Path $Evidence 'owner-browser-ssh.log')
    if (-not $remote.WaitForExit(180000)) { throw 'Owner browser proof did not finish' }
    if ($remote.ExitCode -ne 0) { throw 'Owner browser proof SSH command failed' }
    $proof = Get-Content (Join-Path $Evidence 'owner-browser-live.json') -Raw | ConvertFrom-Json
    if (-not $proof.ok -or $proof.uid -le 0 -or $proof.session -cne $ownerProof.session -or $proof.before -notlike '*Not clicked*' -or $proof.after -notlike '*Clicked*' -or -not $proof.foreignDenied -or -not $proof.globalDenied -or -not $proof.credentialsPrivate) { throw 'Owner browser command proof incomplete' }
    [IO.File]::WriteAllBytes((Join-Path $Evidence 'owner-browser-pane.png'), [Convert]::FromBase64String($proof.screenshot))
    $proof | Add-Member -NotePropertyName screenshotSha256 -NotePropertyValue (Get-FileHash (Join-Path $Evidence 'owner-browser-pane.png') -Algorithm SHA256).Hash.ToLowerInvariant()
    $proof | Add-Member -NotePropertyName appVersion -NotePropertyValue $ExpectedVersion
    $proof | Add-Member -NotePropertyName appSha256 -NotePropertyValue $ExpectedHash
    $proof | Add-Member -NotePropertyName releaseTag -NotePropertyValue $env:RELEASE_TAG
    $proof.PSObject.Properties.Remove('screenshot')
    Save-Json $proof 'owner-browser-live.json'
    Snapshot 'owner-browser-desktop'
    $result.checks += @{ name = 'real Unix owner opens reads clicks hosted browser'; session = $proof.session; uid = $proof.uid; tab = $created.tab; foreignDenied = $proof.foreignDenied; globalDenied = $proof.globalDenied; credentialsPrivate = $proof.credentialsPrivate }
} finally {
    if ($null -ne $remote) {
        if (-not $remote.HasExited) { Stop-Process -Id $remote.Id -Force }
        $remote.Dispose()
    }
    $null = $pageJob.Stop()
    $pageJob.Dispose()
    Remove-Item -LiteralPath $key, ($key + '.pub') -Force -ErrorAction SilentlyContinue
}
