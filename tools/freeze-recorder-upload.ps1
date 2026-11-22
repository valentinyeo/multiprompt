param([Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string]$Evidence)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Upload journey requires isolated Windows CI' }
$repo = (Resolve-Path "$PSScriptRoot/..").Path
$work = Join-Path $env:RUNNER_TEMP ('report-service-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $work, $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
$hostName = 'account.multiprompt.dev'
$server = $null
$hosts = "$env:SystemRoot/System32/drivers/etc/hosts"
$originalHosts = [IO.File]::ReadAllText($hosts)
$cert = $null
try {
    $cert = New-SelfSignedCertificate -DnsName $hostName -CertStoreLocation Cert:\LocalMachine\My -NotAfter (Get-Date).AddDays(1)
    $password = [guid]::NewGuid().ToString('N')
    $secure = ConvertTo-SecureString $password -AsPlainText -Force
    [void](Export-PfxCertificate -Cert $cert -FilePath "$work/service.pfx" -Password $secure)
    [void](Export-Certificate -Cert $cert -FilePath "$work/service.cer")
    [void](Import-Certificate -FilePath "$work/service.cer" -CertStoreLocation Cert:\LocalMachine\Root)
    [IO.File]::AppendAllText($hosts, "`n127.0.0.1 $hostName`n")
    $server = Start-Process node -ArgumentList "`"$repo/service/journey/server.mjs`"", '--port=443', "--pfx=`"$work/service.pfx`"", "--pfxpass=$password", "--state=`"$work/state.json`"", '--reports=true' -PassThru -RedirectStandardOutput "$Evidence/service.log" -RedirectStandardError "$Evidence/service.err.log"
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    while (!(Test-Path "$work/state.json")) {
        if ($server.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw 'Report service did not start' }
        Start-Sleep -Milliseconds 200
    }
    & "$PSScriptRoot/freeze-recorder-journey.ps1" -Exe $Exe -Evidence $Evidence -AccountState "$work/state.json" -Service "https://$hostName"
} finally {
    if ($server -and !$server.HasExited) { Stop-Process -Id $server.Id -Force }
    [IO.File]::WriteAllText($hosts, $originalHosts)
    if ($cert) {
        Remove-Item "Cert:/LocalMachine/My/$($cert.Thumbprint)" -ErrorAction SilentlyContinue
        Remove-Item "Cert:/LocalMachine/Root/$($cert.Thumbprint)" -ErrorAction SilentlyContinue
    }
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
