$fixture = Get-Content (Join-Path $PSScriptRoot '../../../tools/fixtures/SOFT-2445/archived-cards.json') -Raw | ConvertFrom-Json
$root = Join-Path $env:APPDATA 'ZigShell'
New-Item -ItemType Directory -Force $root | Out-Null
$archive = @()
$details = @()
foreach ($row in $fixture) {
    $archive += @{ name = $row.name; tmux_session = $row.session; host = $row.host; ai_agent = 1 }
    $session = [int[]]::new(64)
    $sessionBytes = [Text.Encoding]::UTF8.GetBytes($row.session)
    [Array]::Copy($sessionBytes, $session, $sessionBytes.Length)
    $preview = [int[]]::new(96)
    $previewBytes = [Text.Encoding]::UTF8.GetBytes($row.preview)
    [Array]::Copy($previewBytes, $preview, $previewBytes.Length)
    $details += @{ host = $row.host; session = $session; len = $sessionBytes.Length; starred = $false; preview = $preview; preview_len = $previewBytes.Length; last_active = [DateTime]::UtcNow.AddMinutes(-$row.minutes).ToFileTimeUtc() }
}
ConvertTo-Json -InputObject $archive -Depth 6 | Set-Content -Encoding utf8NoBOM (Join-Path $root 'archive.json')
ConvertTo-Json -InputObject $details -Depth 6 | Set-Content -Encoding utf8NoBOM (Join-Path $root 'all-sessions.json')
