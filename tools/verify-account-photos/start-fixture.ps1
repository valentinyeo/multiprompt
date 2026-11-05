$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'GitHub Windows only' }
if (!$env:PHOTO_PROOF_CREDENTIAL) { throw 'Missing fixture credential' }
$config = $env:PHOTO_PROOF_CREDENTIAL | ConvertFrom-Json
foreach ($name in @('account_id', 'desktop_device_id', 'android_device_id', 'desktop_refresh_token', 'android_refresh_token')) {
    $value = [string]$config.$name
    if (!$value -or $value -match '[\r\n]') { throw 'Invalid fixture credential' }
    Write-Output ('::add-mask::' + $value.Replace('%', '%25'))
}
if ($config.account_id -cne 'journey@example.com' -or $config.desktop_device_id -cne 'journey-device' -or $config.android_device_id -cne 'journey-device-b' -or $config.desktop_refresh_token -ceq $config.android_refresh_token) { throw 'Unexpected fixture identity' }
$work = Join-Path $env:RUNNER_TEMP 'account-photo-fixture'
if (Test-Path $work) { throw 'Fixture directory already exists' }
New-Item -ItemType Directory $work | Out-Null
$configPath = Join-Path $work 'credential.json'
[IO.File]::WriteAllText($configPath, $env:PHOTO_PROOF_CREDENTIAL, [Text.UTF8Encoding]::new($false))
Remove-Item Env:PHOTO_PROOF_CREDENTIAL
$config = $null
$statePath = Join-Path $work 'processes.json'
$owned = [Collections.Generic.List[object]]::new()
function Save-Process($Process, [string]$ExpectedPath) {
    $Process.Refresh()
    $owned.Add([ordered]@{ pid = $Process.Id; path = $ExpectedPath; started = $Process.StartTime.ToUniversalTime().Ticks })
    [IO.File]::WriteAllText($statePath, (ConvertTo-Json -InputObject @($owned.ToArray()) -Compress), [Text.UTF8Encoding]::new($false))
}
$cloudflared = Join-Path $work 'cloudflared.exe'
Invoke-WebRequest 'https://github.com/cloudflare/cloudflared/releases/download/2026.10.7/cloudflared-windows-amd64.exe' -OutFile $cloudflared
if ((Get-FileHash $cloudflared -Algorithm SHA256).Hash.ToLowerInvariant() -cne '2493dbc168923bb3e59e5e7716f71deced92992eea9acd6e9d74f84ac7751343') { throw 'Cloudflared checksum mismatch' }
$nodePath = (Get-Command node -CommandType Application | Select-Object -First 1).Source
$serverPath = (Resolve-Path 'service/journey/server.mjs').Path
$server = Start-Process -FilePath $nodePath -ArgumentList @(('"' + $serverPath + '"'), '--port=18787', '--bind=127.0.0.1', ('--config="' + $configPath + '"')) -PassThru -RedirectStandardOutput (Join-Path $work 'service.out') -RedirectStandardError (Join-Path $work 'service.err')
Save-Process $server $nodePath
$timer = [Diagnostics.Stopwatch]::StartNew()
do {
    if ($server.HasExited) { throw 'Fixture exited during startup' }
    if ((Test-Path (Join-Path $work 'service.out')) -and (Get-Content (Join-Path $work 'service.out') -Raw) -match 'journey service ready') { break }
    Start-Sleep -Seconds 1
} while ($timer.Elapsed.TotalSeconds -lt 90)
if ($timer.Elapsed.TotalSeconds -ge 90) { throw 'Fixture startup timed out' }
$tunnel = Start-Process -FilePath $cloudflared -ArgumentList @('tunnel', '--no-autoupdate', '--protocol', 'http2', '--url', 'http://127.0.0.1:18787') -PassThru -RedirectStandardOutput (Join-Path $work 'tunnel.out') -RedirectStandardError (Join-Path $work 'tunnel.err')
Save-Process $tunnel $cloudflared
$timer.Restart()
$endpoint = $null
do {
    if ($tunnel.HasExited -or $server.HasExited) { throw 'Fixture or tunnel exited during startup' }
    $log = Get-Content (Join-Path $work 'tunnel.err') -Raw -ErrorAction SilentlyContinue
    if ($log) {
        $match = [regex]::Match($log, 'https://[a-z0-9-]+\.trycloudflare\.com')
        if ($match.Success) { $endpoint = $match.Value; break }
    }
    Start-Sleep -Seconds 1
} while ($timer.Elapsed.TotalSeconds -lt 120)
if (!$endpoint) { throw 'Tunnel endpoint timed out' }
New-Item -ItemType Directory -Force 'picture-endpoint' | Out-Null
[IO.File]::WriteAllText((Join-Path $PWD 'picture-endpoint/endpoint.txt'), $endpoint, [Text.UTF8Encoding]::new($false))
