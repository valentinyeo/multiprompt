function Get-GuardSessionIds($Session, [int]$Count) {
    if ($null -eq $Session -or $null -eq $Session.PSObject.Properties['tabs'] -or $Session.tabs -isnot [array] -or $Session.tabs.Count -ne $Count) { return $null }
    $ids = @{}
    foreach ($tab in $Session.tabs) {
        if ($null -eq $tab -or $null -eq $tab.PSObject.Properties['shell_id'] -or $null -eq $tab.PSObject.Properties['cv']) { return $null }
        if ($tab.shell_id -isnot [int] -and $tab.shell_id -isnot [long]) { return $null }
        if ($tab.shell_id -le 0 -or $tab.cv -isnot [bool] -or -not $tab.cv -or $ids.ContainsKey("$($tab.shell_id)")) { return $null }
        $ids["$($tab.shell_id)"] = $true
    }
    return $ids
}

function Get-GuardPaintedId([string]$Text, $Ids, [array]$OrderedIds) {
    $match = [regex]::Match($Text, '(?s)hook: Ctrl\+Tab shift=0 -> NEXT_TAB.*?switchToShell: (\d+) -> (\d+) ')
    $paint = [regex]::Match($Text, '\[switch\] chat content shown shell=(\d+) blocks=([1-9]\d*)\b')
    $timing = [regex]::Match($Text, 'switch-timing: to=(\d+)\b')
    if (-not $match.Success -or -not $paint.Success -or -not $timing.Success -or $match.Groups[1].Value -eq $match.Groups[2].Value) { return $null }
    $id = $paint.Groups[1].Value
    $index = [int]$match.Groups[2].Value
    if (-not $Ids.ContainsKey($id)) { throw "Painted unexpected shell $id" }
    if ($index -ge $OrderedIds.Count -or $timing.Groups[1].Value -ne "$index" -or "$($OrderedIds[$index])" -ne $id) { throw 'Painted shell does not match completed switch' }
    return $id
}
