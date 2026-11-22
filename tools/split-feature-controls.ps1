param([string]$Path, [string]$Output)
$tokens = $null
$errors = $null
$tree = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$parsedFiles = 0
foreach ($file in Get-ChildItem -LiteralPath (Split-Path $Path) -Filter 'control*.ps1') {
    $fileTokens = $null
    $fileErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$fileTokens, [ref]$fileErrors)
    if ($fileErrors.Count) { throw ($fileErrors | Out-String) }
    $parsedFiles++
}
$switches = @($tree.FindAll({ param($node) $node -is [System.Management.Automation.Language.SwitchStatementAst] -and $node.Condition.Extent.Text -in @('$Feature', '$driveFeature') }, $true))
$main = $switches[0]
foreach ($item in $switches) {
    if (($item.Extent.EndOffset - $item.Extent.StartOffset) -gt ($main.Extent.EndOffset - $main.Extent.StartOffset)) { $main = $item }
}
$clauses = @($main.Clauses | ForEach-Object {
    $body = $_.Item2
    $returns = @($body.FindAll({ param($node) $node -is [System.Management.Automation.Language.ReturnStatementAst] }, $true))
    [ordered]@{ name = $_.Item1.Extent.Text; start = $body.Extent.StartOffset; end = $body.Extent.EndOffset; line = $body.Extent.StartLineNumber; returns = @($returns | ForEach-Object { $cursor = $_.Parent; $nested = $false; while ($null -ne $cursor -and $cursor -ne $body) { if ($cursor -is [System.Management.Automation.Language.ScriptBlockAst] -or $cursor -is [System.Management.Automation.Language.FunctionDefinitionAst]) { $nested = $true }; $cursor = $cursor.Parent }; @{ line = $_.Extent.StartLineNumber; nested = $nested } }) }
})
[ordered]@{ parsedFiles = $parsedFiles; switches = $switches.Count; ranges = @($switches | ForEach-Object { @{ start = $_.Extent.StartOffset; end = $_.Extent.EndOffset; line = $_.Extent.StartLineNumber; type = $_.GetType().FullName } }); start = $main.Extent.StartOffset; end = $main.Extent.EndOffset; clauses = $clauses } | ConvertTo-Json -Depth 10 | Set-Content -Encoding utf8 $Output
