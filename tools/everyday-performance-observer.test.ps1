param([Parameter(Mandatory)][string]$Evidence)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'Observer proof requires GitHub-hosted Windows' }
New-Item -ItemType Directory -Force $Evidence | Out-Null
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type -Path "$PSScriptRoot/verify-chat-delivery/desktop.cs", "$PSScriptRoot/everyday-performance.cs" -ReferencedAssemblies System, System.Core, System.Drawing, System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ObserverSaveBoundary {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern bool MoveFileEx(string source, string destination, uint flags);
    public static int Error;
    public static bool Replace(string source, string destination) {
        bool result = MoveFileEx(source, destination, 9);
        Error = result ? 0 : Marshal.GetLastWin32Error();
        return result;
    }
}
'@
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile("$PSScriptRoot/everyday-performance.ps1", [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw 'Measurement script did not parse' }
$definition = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Read-State' }, $true)
if ($null -eq $definition) { throw 'Missing production observer Read-State' }
. ([scriptblock]::Create($definition.Extent.Text))
$settings = Join-Path $env:RUNNER_TEMP ('observer-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $settings | Out-Null
$script:replaceSucceeded = $false
function ConvertFrom-Json {
    param([Parameter(ValueFromPipeline)][string]$InputObject)
    process {
        $script:replaceSucceeded = [ObserverSaveBoundary]::Replace("$settings/next.json", "$settings/session.json")
        Microsoft.PowerShell.Utility\ConvertFrom-Json -InputObject $InputObject
    }
}
try {
    [IO.File]::WriteAllText("$settings/session.json", '{"active_tab":0}')
    [IO.File]::WriteAllText("$settings/next.json", '{"active_tab":1}')
    $observed = Read-State
    $stored = Microsoft.PowerShell.Utility\ConvertFrom-Json -InputObject ([EverydayPerformance]::Tail("$settings/session.json", 0))
    @{ replaceSucceeded=$script:replaceSucceeded; error=[ObserverSaveBoundary]::Error; observedTab=$observed.active_tab; storedTab=$stored.active_tab; availableBytes=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($settings)).AvailableFreeSpace } | ConvertTo-Json | Set-Content "$Evidence/observer.json"
    if (-not $script:replaceSucceeded -or $stored.active_tab -ne 1) { throw "The observer blocked an atomic save; Win32 error $([ObserverSaveBoundary]::Error)" }
} finally {
    Remove-Item -LiteralPath $settings -Recurse -Force
}
