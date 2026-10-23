param([string]$Root = '.')

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$rootPath = [IO.Path]::GetFullPath($Root)
$inventoryPath = Join-Path $PSScriptRoot 'powershell-host-names.json'
$inventory = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json
$automaticNames = @{}
foreach ($name in $inventory.automaticVariables) { $automaticNames[$name] = $true }
$aliasNames = @{}
foreach ($name in $inventory.aliases) { $aliasNames[$name] = $true }
$diagnostics = New-Object 'System.Collections.Generic.List[string]'

function Add-VariableDiagnostic($Variable, [string]$Kind, [string]$File) {
    $name = $Variable.VariablePath.UserPath
    if ($name.Contains(':') -or -not $automaticNames.ContainsKey($name)) { return }
    $line = $Variable.Extent.StartLineNumber
    $diagnostics.Add(('{0}:{1} {2} ${3} shadows a read-only PowerShell automatic variable; rename it (e.g. ${4}) and update its references' -f $File, $line, $Kind, $name, 'SessionId'))
}

function Get-AssignmentVariables($Target) {
    if ($Target -is [System.Management.Automation.Language.VariableExpressionAst]) {
        $Target
    } elseif ($Target -is [System.Management.Automation.Language.AttributedExpressionAst]) {
        Get-AssignmentVariables $Target.Child
    } elseif ($Target -is [System.Management.Automation.Language.ArrayLiteralAst]) {
        foreach ($element in $Target.Elements) { Get-AssignmentVariables $element }
    } elseif ($Target -is [System.Management.Automation.Language.ParenExpressionAst]) {
        foreach ($element in $Target.Pipeline.PipelineElements) {
            if ($element -is [System.Management.Automation.Language.CommandExpressionAst]) { Get-AssignmentVariables $element.Expression }
        }
    }
}

$tracked = & git -C $rootPath ls-files -z -- '*.ps1' '*.psm1'
if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate tracked PowerShell files' }
$files = @(($tracked -join "`n") -split "`0" | Where-Object { $_ })
foreach ($file in $files) {
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $rootPath $file), [ref]$tokens, [ref]$parseErrors)
    foreach ($parseError in $parseErrors) {
        $diagnostics.Add(("{0}:{1} PowerShell parse error: {2}; fix the syntax before checking host names" -f $file, $parseError.Extent.StartLineNumber, $parseError.Message))
    }
    $nodes = $ast.FindAll({ param($Node)
        $Node -is [System.Management.Automation.Language.ParameterAst] -or
        $Node -is [System.Management.Automation.Language.AssignmentStatementAst] -or
        $Node -is [System.Management.Automation.Language.ForEachStatementAst] -or
        $Node -is [System.Management.Automation.Language.UnaryExpressionAst] -or
        $Node -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $true)
    foreach ($node in $nodes) {
        if ($node -is [System.Management.Automation.Language.ParameterAst]) {
            Add-VariableDiagnostic $node.Name 'parameter' $file
        } elseif ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) {
            foreach ($variable in @(Get-AssignmentVariables $node.Left)) { Add-VariableDiagnostic $variable 'assignment target' $file }
        } elseif ($node -is [System.Management.Automation.Language.ForEachStatementAst]) {
            Add-VariableDiagnostic $node.Variable 'foreach target' $file
        } elseif ($node -is [System.Management.Automation.Language.UnaryExpressionAst]) {
            if ($node.TokenKind.ToString() -in @('PlusPlus', 'MinusMinus', 'PostfixPlusPlus', 'PostfixMinusMinus')) {
                foreach ($variable in @(Get-AssignmentVariables $node.Child)) { Add-VariableDiagnostic $variable 'increment target' $file }
            }
        } elseif ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
            $name = ($node.Name -split ':')[-1]
            if ($aliasNames.ContainsKey($name)) {
                $diagnostics.Add(("{0}:{1} function {2} is hidden by the Windows PowerShell {2} alias; rename the helper (e.g. Move-Pointer) and update its calls" -f $file, $node.Extent.StartLineNumber, $node.Name))
            }
        }
    }
}
if ($diagnostics.Count -gt 0) {
    foreach ($diagnostic in $diagnostics) { [Console]::Error.WriteLine($diagnostic) }
    exit 1
}
Write-Output ("PowerShell host names OK: {0} tracked scripts" -f $files.Count)
