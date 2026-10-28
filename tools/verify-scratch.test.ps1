$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$driver = Join-Path $PSScriptRoot '../.claude/skills/verify-multiprompt/control-library.ps1'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($driver, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
foreach ($name in @('Test-VanishedScratchItem', 'Prepare-ScratchEvidence', 'Remove-ScratchPath')) {
    $definition = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $true)
    if ($null -eq $definition) { throw "Missing production function $name" }
    . ([scriptblock]::Create($definition.Extent.Text))
}

$oldPrepare = @'
function Prepare-ScratchEvidence([string]$Path) {
    $blockedAttributes = [IO.FileAttributes]::ReadOnly -bor [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System
    foreach ($entry in Get-ChildItem -LiteralPath $Path -Force) {
        if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            $script:scratchLinks += @{ path = $entry.FullName.Substring($scratch.Length + 1); attributes = $entry.Attributes.ToString(); linkType = $entry.LinkType; target = @($entry.Target) }
            Save-Json @($script:scratchLinks) 'scratch-links.json'
            $entry.Delete()
            Record 'Cleanup: recorded and unlinked scratch reparse point without traversing its target'
        } else {
            $entry.Attributes = $entry.Attributes -band (-bnot $blockedAttributes)
            if ($entry -is [IO.DirectoryInfo]) { Prepare-ScratchEvidence $entry.FullName }
        }
    }
}
'@
$prepare = ${function:Prepare-ScratchEvidence}
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('verify-scratch-' + [guid]::NewGuid().ToString('N'))
$script:vanish = $null
function Get-ChildItem {
    param([string]$LiteralPath, [switch]$Force, [switch]$Recurse)
    $entries = @(Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath $LiteralPath -Force:$Force -Recurse:$Recurse)
    if ($null -ne $script:vanish) {
        [IO.File]::Delete($script:vanish)
        $script:vanish = $null
    }
    return $entries
}

try {
    New-Item -ItemType Directory -Path $scratch | Out-Null
    $lock = Join-Path $scratch 'lockfile'
    $kept = Join-Path $scratch 'remaining.txt'
    [IO.File]::WriteAllText($kept, 'remaining')
    [IO.File]::SetAttributes($kept, [IO.FileAttributes]::ReadOnly)
    . ([scriptblock]::Create($oldPrepare))
    [IO.File]::WriteAllText($lock, 'lock')
    $script:vanish = $lock
    $rejected = $false
    try { Prepare-ScratchEvidence $scratch } catch {
        if (-not (Test-VanishedScratchItem $_ $lock)) { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw 'ISSUE-559 baseline failed to reproduce the vanished lockfile exception' }
    Write-Output 'ISSUE-559 old cleanup rejected: file vanished after enumeration before Attributes assignment'

    ${function:Prepare-ScratchEvidence} = $prepare
    [IO.File]::SetAttributes($kept, [IO.FileAttributes]::ReadOnly)
    [IO.File]::WriteAllText($lock, 'lock')
    $script:vanish = $lock
    Prepare-ScratchEvidence $scratch
    if (Test-Path -LiteralPath $lock) { throw 'ISSUE-559 lockfile did not vanish' }
    if (([IO.File]::GetAttributes($kept) -band [IO.FileAttributes]::ReadOnly) -ne 0) { throw 'ISSUE-559 preparation skipped a surviving file' }
    foreach ($exception in @(
        (New-Object System.Management.Automation.ItemNotFoundException 'missing'),
        (New-Object IO.FileNotFoundException 'missing'),
        (New-Object IO.DirectoryNotFoundException 'missing')
    )) {
        $failure = New-Object System.Management.Automation.ErrorRecord $exception, 'missing', ([System.Management.Automation.ErrorCategory]::ObjectNotFound), $lock
        if (-not (Test-VanishedScratchItem $failure $lock)) { throw 'ISSUE-559 missing path was not tolerated' }
        if (Test-VanishedScratchItem $failure $kept) { throw 'ISSUE-559 existing path was silently ignored' }
    }
    $denied = New-Object System.Management.Automation.ErrorRecord (New-Object UnauthorizedAccessException 'denied'), 'denied', ([System.Management.Automation.ErrorCategory]::PermissionDenied), $lock
    if (Test-VanishedScratchItem $denied $lock) { throw 'ISSUE-559 permission failure was silently ignored' }
    Remove-ScratchPath $scratch
    if (Test-Path -LiteralPath $scratch) { throw 'ISSUE-559 scratch survived removal' }

    New-Item -ItemType Directory -Path $scratch | Out-Null
    [IO.File]::WriteAllText($kept, 'locked')
    $handle = [IO.File]::Open($kept, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $reported = $false
        try { Remove-ScratchPath $scratch 1 } catch {
            if ($_.Exception.Message -notlike '*Scratch cleanup left paths:*' -or -not $_.Exception.Message.Contains($kept)) { throw }
            $reported = $true
        }
        if (-not $reported -or -not (Test-Path -LiteralPath $kept)) { throw 'ISSUE-559 real leftover was not reported' }
    } finally { $handle.Dispose() }
    Write-Output 'ISSUE-559 production cleanup passed vanished-file, surviving-file, permission and locked-leftover checks'
} finally {
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}
