$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:OS -ne 'Windows_NT') { throw 'Run update tests only on GitHub Windows' }
. "$PSScriptRoot/../src/update_release.ps1" -Mode Library

function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Refuses([scriptblock]$Action, [string]$Message) {
    $refused = $false
    try { & $Action } catch { $refused = $true }
    Assert $refused $Message
}

$root = Join-Path $env:RUNNER_TEMP ('update-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
try {
    Add-Type -TypeDefinition 'using System; using System.Threading; class UpdateOld { static void Main(string[] args) { System.IO.File.AppendAllText(System.Diagnostics.Process.GetCurrentProcess().MainModule.FileName + ".starts", "start\n"); if (args.Length == 2) { using (var e = EventWaitHandle.OpenExisting(args[1])) { e.Set(); } Thread.Sleep(2500); } } }' -OutputAssembly "$root/old.exe" -OutputType ConsoleApplication
    Add-Type -TypeDefinition 'class UpdateBroken { static int Main() { return 1; } }' -OutputAssembly "$root/broken.exe" -OutputType ConsoleApplication
    [IO.File]::AppendAllText("$root/broken.exe", "MPVERSION=1.10.0;")
    Copy-Item "$root/old.exe" "$root/app.exe"
    $target = [IO.Path]::GetFullPath("$root/app.exe")
    $dir = "$target.update"
    New-Item -ItemType Directory -Path $dir | Out-Null
    $oldHash = (Get-FileHash $target).Hash
    $brokenHash = (Get-FileHash "$root/broken.exe").Hash
    $script:fixture = "$root/broken.exe"
    $script:release = [pscustomobject]@{
        tag_name = 'v1.10.0'; draft = $false; prerelease = $false; author = @{ login = 'github-actions[bot]' }
        assets = @(@{ name = 'multiprompt-x64.exe'; browser_download_url = 'https://github.com/valentinyeo/multiprompt/releases/download/v1.10.0/multiprompt-x64.exe' }, @{ name = 'SHA256SUMS.txt'; browser_download_url = 'https://github.com/valentinyeo/multiprompt/releases/download/v1.10.0/SHA256SUMS.txt' })
    }
    function Invoke-RestMethod { param($Uri, $Headers, $TimeoutSec) return $script:release }
    function Invoke-WebRequest {
        param($Uri, $Headers, [switch]$UseBasicParsing, $TimeoutSec, $OutFile)
        if ($Uri.EndsWith('SHA256SUMS.txt')) { [IO.File]::WriteAllText($OutFile, "$script:sum  multiprompt-x64.exe`n") } else { Copy-Item $script:fixture $OutFile -Force }
    }

    Assert ((Get-ReleaseVersion 'v1.10.0') -gt (Get-ReleaseVersion '1.9.999')) 'Numeric version comparison'
    Assert ((Get-ReleaseVersion '1.2.3') -eq (Get-ReleaseVersion 'v1.2.3')) 'Equal versions'
    Assert ((Get-ReleaseVersion '2.0.0') -gt (Get-ReleaseVersion '1.999.999')) 'Major comparison'
    foreach ($invalid in @('1.2', '1.2.3-beta', '1.2.3.4', '01.2.3', 'v1.2.3;bad')) { Refuses { Get-ReleaseVersion $invalid } 'Invalid version accepted' }
    Write-Host 'version comparison passed'

    $script:sum = '0' * 64
    Refuses { Save-Update $target '1.9.0' 'x64' } 'Checksum mismatch accepted'
    Assert (-not (Test-Path "$dir/ready.txt")) 'Mismatched download marked ready'
    Assert ((Get-FileHash $target).Hash -eq $oldHash) 'Mismatch modified installation'
    Write-Host 'checksum mismatch refused'

    $script:release.author.login = 'untrusted-user'
    Refuses { Save-Update $target '1.9.0' 'x64' } 'Untrusted author accepted'
    $script:release.author.login = 'github-actions[bot]'
    $script:release.assets[0].browser_download_url = 'https://example.com/untrusted.exe'
    Refuses { Save-Update $target '1.9.0' 'x64' } 'External asset URL accepted'
    $script:release.assets[0].browser_download_url = 'https://github.com/valentinyeo/multiprompt/releases/download/v1.10.0/multiprompt-x64.exe'
    $script:sum = $brokenHash
    Assert (-not (Save-Update $target '2.0.0' 'x64')) 'Downgrade staged'
    Assert (-not (Save-Update $target '1.10.0' 'x64')) 'Equal release staged'
    Assert (Save-Update $target '1.9.0' 'x64') 'Verified update was not staged'
    Assert ((Get-FileHash $target).Hash -eq $oldHash) 'Background check replaced running installation'
    Assert (-not (Test-Path "$target.starts")) 'Background check launched the app'
    Assert (-not (Test-Path "$target.previous.exe")) 'Background check installed without consent'
    Assert (Test-Path "$dir/ready.txt") 'Background check did not publish readiness'
    Write-Host 'no automatic restart while running passed'

    Refuses { Install-Update $target 'x64' '' '2.0.0' } 'Stale staged downgrade accepted'
    Assert ((Get-FileHash $target).Hash -eq $oldHash) 'Stale update modified installation'
    Copy-Item "$root/broken.exe" "$target.previous.exe"
    $lockedBackup = [IO.File]::Open("$target.previous.exe", [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
    try { Refuses { Install-Update $target 'x64' '' '1.9.0' } 'Locked backup was overwritten' } finally { $lockedBackup.Dispose() }
    Assert ((Get-FileHash $target).Hash -eq $oldHash) 'Backup failure changed the installed executable'
    Assert ((Get-Content "$target.starts" -Raw) -eq "start`n") 'Backup failure did not restart the untouched app'
    Get-Process | Where-Object { $_.Path -eq $target } | ForEach-Object { $null = $_.WaitForExit(5000) }
    Remove-Item "$target.starts", "$target.previous.exe" -Force
    Write-Host 'backup failure resumes the previous app passed'

    Refuses { Install-Update $target 'x64' '' '1.9.0' } 'Broken update reported success'
    Assert ((Get-FileHash $target).Hash -eq $oldHash) 'Previous executable not restored'
    Assert ((Get-Content "$target.starts" -Raw) -eq "start`n") 'Rollback did not start the previous executable exactly once'
    Assert ((Get-FileHash "$target.previous.exe").Hash -eq $oldHash) 'Previous executable not retained'
    Assert ((Get-FileHash "$dir/failed.exe").Hash -eq $brokenHash) 'Failed executable not quarantined'
    Assert ((Get-Content "$dir/rejected.txt" -Raw) -eq 'v1.10.0') 'Failed version not suppressed'
    Assert (-not (Save-Update $target '1.9.0' 'x64')) 'Failed version retried'
    Assert (-not (Test-Path "$dir/ready.txt")) 'Failed version remains ready'
    Write-Host 'rollback after failed start passed'
    Write-Host 'UPDATE BEHAVIOR PASSED'
} finally {
    Get-Process | Where-Object { $_.Path -eq $target } | ForEach-Object { $null = $_.WaitForExit(5000) }
    Remove-Item -LiteralPath $root -Recurse -Force
}
