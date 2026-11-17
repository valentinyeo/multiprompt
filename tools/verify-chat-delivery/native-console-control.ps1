param([Parameter(Mandatory)][string]$Evidence)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Use the GitHub Windows desktop runner' }
New-Item -ItemType Directory -Force "$Evidence/windows" | Out-Null
Add-Type -Path "$PSScriptRoot/native-console-recorder.cs" -ReferencedAssemblies System.Drawing, System.Windows.Forms
Add-Type -Path "$PSScriptRoot/native-console-control.cs"
$recorder = [NativeConsoleRecorder]::new("$Evidence/windows")
function Wait-Control([scriptblock]$Check) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    do {
        if (& $Check) { return }
        Start-Sleep -Milliseconds 20
    } while ($watch.Elapsed.TotalSeconds -lt 10)
    throw 'Native console positive control event missing'
}
try {
    $handles = [NativeConsoleControl]::Create()
    Wait-Control { (Get-Content "$Evidence/windows/windows.tsv" -Raw) -match 'window\tshow\t[^\r\n]+\tZigShellChatTranscript\t' }
    $start = [NativeConsoleControl]::GetTickCount64()
    [NativeConsoleControl]::Flash()
    Wait-Control {
        $events = @(Get-Content "$Evidence/windows/windows.tsv" | ForEach-Object { $fields = $_ -split "`t"; if ($fields[0] -eq 'window' -and $fields[4] -eq $handles[1] -and [long]$fields[2] -ge $start) { $fields[1] } })
        'show' -in $events -and 'hide' -in $events
    }
    $end = [NativeConsoleControl]::GetTickCount64()
    @{pid=$PID; hwnd=$handles[0]} | ConvertTo-Json | Set-Content -Encoding UTF8 "$Evidence/doctor.json"
    ConvertTo-Json -InputObject @(@{name='native-child-console-positive-control'; start=$start; end=$end}) | Set-Content -Encoding UTF8 "$Evidence/position-phases.json"
} finally {
    [NativeConsoleControl]::Close()
    $recorder.Dispose()
}
& node "$PSScriptRoot/native-console.test.cjs" $Evidence
$result = Get-Content "$Evidence/native-console.json" -Raw | ConvertFrom-Json
$caught = @($result.flashes | Where-Object { $_.console.hwnd -eq $handles[1] -and $_.console.parent -eq $handles[0] -and $_.phase -eq 'native-child-console-positive-control' })
if ($LASTEXITCODE -ne 1 -or $result.status -ne 'failed' -or $caught.Count -eq 0) { throw 'Observer missed a real native child-console flash' }
Write-Output 'Native console hook positive control passed'
