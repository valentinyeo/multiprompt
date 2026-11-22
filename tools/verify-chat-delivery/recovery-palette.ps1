function Test-RecoveryPaletteSelection([string]$LogTail, [int]$QueryLength, [int]$Target) {
    $records = [regex]::Matches($LogTail, '\[palette\] ready chars=(\d+) count=(\d+) target=(\d+)(?!\d)')
    if ($records.Count -eq 0) { return $false }
    $record = $records[$records.Count - 1]
    return $record.Groups[1].Value -eq [string]$QueryLength -and
        $record.Groups[2].Value -match '^[0-9]*[1-9][0-9]*$' -and
        $record.Groups[3].Value -eq [string]$Target
}
