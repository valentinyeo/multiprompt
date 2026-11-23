param([Parameter(Mandatory=$true)][string]$First, [Parameter(Mandatory=$true)][string]$Second, [string]$Root = "$env:RUNNER_TEMP/executable-rename", [string]$Evidence = "$env:RUNNER_TEMP/rename-proof")
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:OS -ne 'Windows_NT') { throw 'Run executable migration only on GitHub Windows' }
$First = (Resolve-Path $First).Path
$Second = (Resolve-Path $Second).Path
$Root = [IO.Path]::GetFullPath($Root)
function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Version([string]$File) {
    $markers = @([regex]::Matches([Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($File)), 'MPVERSION=(\d+\.\d+\.\d+);') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
    Assert ($markers.Count -eq 1) 'Expected one executable version'
    return $markers[0]
}
function Stop-OwnedApps {
    Get-Process | Where-Object { $image = $_.Path; $image -and $image.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object {
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        $null = $_.WaitForExit(5000)
    }
}
function Running([string]$File) { return @(Get-Process | Where-Object { $image = $_.Path; $image -ieq $File }) }
function Select-Release([string]$Version) {
    $script:folder = Join-Path $Root "fixtures/v$Version"
    $script:release = [pscustomobject]@{
        tag_name = "v$Version"; draft = $false; prerelease = $false; author = @{ login = 'github-actions[bot]' }
        assets = @(Get-ChildItem -LiteralPath $script:folder -File | ForEach-Object { @{ name = $_.Name; browser_download_url = "https://github.com/valentinyeo/multiprompt/releases/download/v$Version/$($_.Name)" } })
    }
}
function Invoke-RestMethod { param($Uri, $Headers, $TimeoutSec) return $script:release }
function Invoke-WebRequest {
    param($Uri, $Headers, [switch]$UseBasicParsing, $TimeoutSec, $OutFile)
    Copy-Item -LiteralPath (Join-Path $script:folder ([IO.Path]::GetFileName($Uri))) -Destination $OutFile -Force
}
function Apply([string]$Script, [string]$File, [string]$Current, [string]$Waiting = '', [int]$ExpectedExit = 0) {
    $arguments = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(' --single-window --no-window-restore --name "Rename Desk"'))
    $process = Start-Process powershell.exe -ArgumentList "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$Script`" -Mode Apply -Exe `"$File`" -Current $Current -Arch x64 -WaitPids `"$Waiting`" -LaunchArguments $arguments" -PassThru
    if ($Waiting) { Stop-Process -Id ([int]$Waiting) -Force }
    Assert ($process.WaitForExit(90000)) 'Updater did not finish'
    Assert ($process.ExitCode -eq $ExpectedExit) 'Updater returned an unexpected migration result'
}
function Launch-Link([string]$Link, [string]$Target) {
    $name = 'Local\RenameLink-' + [guid]::NewGuid().ToString('N')
    $event = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::ManualReset, $name)
    try {
        $shortcut = $shell.CreateShortcut($Link)
        $shortcut.Arguments = '--single-window --no-window-restore --name "Rename Desk" --update-ready ' + $name
        $shortcut.Save()
        $shell.Run('"' + $Link + '"', 1, $false) | Out-Null
        Assert ($event.WaitOne(30000)) 'Old shortcut did not open a responsive app'
        Assert ((Running $Target).Count -eq 1) 'Shortcut did not launch the new executable'
    } finally { $event.Dispose() }
}
$original = @{}
foreach ($name in @('APPDATA', 'LOCALAPPDATA', 'USERPROFILE', 'HOME', 'MULTIPROMPT_NO_LOGIN', 'IGSH_246', 'MULTIPROMPT_TEST_VERIFIER', 'MULTIPROMPT_RENAME_FIRST', 'MULTIPROMPT_RENAME_SECOND')) { $original[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$checks = New-Object System.Collections.ArrayList
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$runName = 'SOFT-1966-' + [guid]::NewGuid().ToString('N')
$success = $false
try {
    New-Item -ItemType Directory -Force "$Root/install", "$Root/roaming/ZigShell", "$Root/local", "$Root/profile/Documents/GitHub/zigshell/extension", $Evidence | Out-Null
    $env:APPDATA = "$Root/roaming"
    $env:LOCALAPPDATA = "$Root/local"
    $env:USERPROFILE = "$Root/profile"
    $env:HOME = $env:USERPROFILE
    $env:MULTIPROMPT_NO_LOGIN = '1'
    $env:IGSH_246 = '0'
    $env:MULTIPROMPT_TEST_VERIFIER = $First
    $env:MULTIPROMPT_RENAME_FIRST = $First
    $env:MULTIPROMPT_RENAME_SECOND = $Second
    & "$PSScriptRoot/update-release-fixtures.ps1" -Root "$Root/fixtures"
    Assert ($LASTEXITCODE -eq 0) 'Could not create signed migration fixtures'
    $firstVersion = Version $First
    $secondVersion = Version $Second
    $legacy = [IO.Path]::GetFullPath("$Root/install/multiprompt.exe")
    $canonical = [IO.Path]::GetFullPath("$Root/install/multibot.exe")
    Copy-Item "$Root/fixtures/fixture.exe" $legacy
    $legacyUpdater = [IO.Path]::GetFullPath("$PSScriptRoot/fixtures/SOFT-1966/legacy-update.ps1")
    $currentUpdater = [IO.Path]::GetFullPath("$PSScriptRoot/../src/update_release.ps1")
    $shell = New-Object -ComObject WScript.Shell
    $pin = "$Root/old-taskbar-pin.lnk"
    $shortcut = $shell.CreateShortcut($pin)
    $shortcut.TargetPath = $legacy
    $shortcut.Save()
    . $legacyUpdater -Mode Library
    Select-Release $firstVersion
    $old = Start-Process $legacy -ArgumentList '--name "Rename Desk"' -PassThru
    Assert (Save-Update $legacy '0.0.0' 'x64') 'Frozen old updater could not stage the new release'
    Assert (-not (Test-Path $canonical)) 'Background staging migrated without consent'
    Apply $legacyUpdater $legacy '0.0.0' $old.Id.ToString()
    Assert ((Get-FileHash $canonical).Hash -eq (Get-FileHash $First).Hash) 'Old updater did not migrate to multibot.exe'
    $apps = Running $canonical
    Assert ($apps.Count -eq 1 -and $apps[0].ProcessName -ceq 'multibot') 'New app process is not named multibot'
    $command = (Get-CimInstance Win32_Process -Filter "ProcessId = $($apps[0].Id)").CommandLine
    Assert ($command.Contains('--name "Rename Desk"')) 'Migration lost workspace arguments'
    foreach ($redirect in (Running $legacy)) { Assert ($redirect.WaitForExit(15000)) 'Legacy redirect stayed running after the updater exited' }
    [void]$checks.Add('frozen old updater migrates after one relaunch with original arguments')
    Stop-OwnedApps
    Launch-Link $pin $canonical
    [void]$checks.Add('unchanged taskbar shortcut opens multibot.exe')
    Stop-OwnedApps
    $name = 'Local\RenameAutostart-' + [guid]::NewGuid().ToString('N')
    $event = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::ManualReset, $name)
    try {
        if (-not (Test-Path $runKey)) { New-Item -Path $runKey -Force | Out-Null }
        New-ItemProperty -Path $runKey -Name $runName -Value ('"' + $legacy + '" --single-window --no-window-restore --update-ready ' + $name) -PropertyType String -Force | Out-Null
        $shell.Run((Get-ItemPropertyValue -Path $runKey -Name $runName), 1, $false) | Out-Null
        Assert ($event.WaitOne(30000)) 'Old autostart entry did not report ready'
        Assert ((Running $canonical).Count -eq 1) 'Old autostart entry did not launch multibot.exe'
    } finally { $event.Dispose() }
    [void]$checks.Add('unchanged autostart command opens multibot.exe')
    Stop-OwnedApps
    $aliasHash = (Get-FileHash $legacy).Hash
    . $currentUpdater -Mode Library
    Select-Release $secondVersion
    Assert (Save-Update $canonical $firstVersion 'x64') 'Following update was not staged'
    Assert ((Get-Content "$canonical.update/ready.txt" -Raw).EndsWith('multibot-x64.exe')) 'Following update used the old asset name'
    Apply $currentUpdater $canonical $firstVersion
    Assert ((Get-FileHash $canonical).Hash -eq (Get-FileHash $Second).Hash) 'Following update did not install'
    Assert ((Running $canonical).Count -eq 1) 'Following update did not open multibot.exe'
    Stop-OwnedApps
    Launch-Link $pin $canonical
    Assert ((Get-FileHash $canonical).Hash -eq (Get-FileHash $Second).Hash) 'Old redirect downgraded the new executable'
    Assert ((Get-FileHash $legacy).Hash -eq $aliasHash) 'Old pinned path was removed or replaced'
    [void]$checks.Add('following update installs and old shortcut never downgrades it')
    Stop-OwnedApps
    New-Item -ItemType Directory -Force "$Root/blocked" | Out-Null
    $blockedLegacy = [IO.Path]::GetFullPath("$Root/blocked/multiprompt.exe")
    $blockedTarget = [IO.Path]::GetFullPath("$Root/blocked/multibot.exe")
    Copy-Item $First $blockedLegacy
    Copy-Item "$Root/fixtures/fixture.exe" $blockedTarget
    [IO.File]::AppendAllText($blockedTarget, 'MPVERSION=0.0.1;')
    $locked = [IO.File]::Open($blockedTarget, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
    $name = 'Local\RenameBlocked-' + [guid]::NewGuid().ToString('N')
    $event = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::ManualReset, $name)
    try {
        $fallback = Start-Process $blockedLegacy -ArgumentList "--single-window --no-window-restore --update-ready $name" -PassThru
        Assert ($event.WaitOne(30000)) 'Blocked migration did not keep the old path usable'
        Assert (-not $fallback.HasExited) 'Blocked migration exited the working app'
    } finally { $locked.Dispose(); $event.Dispose() }
    Stop-OwnedApps
    $retry = "$Root/retry.lnk"
    $shortcut = $shell.CreateShortcut($retry)
    $shortcut.TargetPath = $blockedLegacy
    $shortcut.Save()
    Launch-Link $retry $blockedTarget
    Assert ((Get-FileHash $blockedTarget).Hash -eq (Get-FileHash $First).Hash) 'Migration did not recover after a transient file lock'
    [void]$checks.Add('blocked move keeps the app usable and retries on the next launch')
    Stop-OwnedApps
    New-Item -ItemType Directory -Force "$Root/failed-start" | Out-Null
    $failedLegacy = [IO.Path]::GetFullPath("$Root/failed-start/multiprompt.exe")
    Copy-Item "$Root/fixtures/fixture.exe" $failedLegacy
    $oldHash = (Get-FileHash $failedLegacy).Hash
    Copy-Item "$Root/fixtures/broken.exe" "$Root/failed-start/multibot.exe"
    [IO.File]::AppendAllText("$Root/failed-start/multibot.exe", 'MPVERSION=999.0.0;')
    . $legacyUpdater -Mode Library
    Select-Release $firstVersion
    Assert (Save-Update $failedLegacy '0.0.0' 'x64') 'Failed-start control did not stage'
    Apply $legacyUpdater $failedLegacy '0.0.0' '' 1
    Assert ((Get-FileHash $failedLegacy).Hash -eq $oldHash) 'Frozen updater did not restore the original executable after failed readiness'
    Assert ((Running $failedLegacy).Count -eq 1) 'Frozen updater did not reopen the original app'
    [void]$checks.Add('failed redirected startup rolls back and reopens the original install')
    $success = $true
} finally {
    Stop-OwnedApps
    Remove-ItemProperty -Path $runKey -Name $runName -ErrorAction SilentlyContinue
    foreach ($name in $original.Keys) { [Environment]::SetEnvironmentVariable($name, $original[$name], 'Process') }
    @{ success = $success; checks = @($checks); firstSha256 = (Get-FileHash $First).Hash; secondSha256 = (Get-FileHash $Second).Hash; cleanup = 'owned processes stopped; temporary autostart removed' } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Evidence 'executable-rename.json')
}
