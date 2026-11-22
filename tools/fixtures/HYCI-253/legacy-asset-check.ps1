function Get-ReleaseVersion([string]$Text) {
    if ($Text -notmatch '^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') { throw 'Invalid release version' }
    return [version]($Text.TrimStart('v'))
}

function Get-ReleaseAsset($Release, [string]$Name) {
    if ($Release.draft -or $Release.prerelease -or $Release.author.login -cne 'github-actions[bot]') { throw 'Untrusted release author or channel' }
    $null = Get-ReleaseVersion $Release.tag_name
    $assets = @($Release.assets | Where-Object { $_.name -ceq $Name })
    if ($assets.Count -ne 1) { throw 'Missing or duplicate release asset' }
    $expected = "https://github.com/valentinyeo/multiprompt/releases/download/$($Release.tag_name)/$Name"
    if ($assets[0].browser_download_url -cne $expected) { throw 'Untrusted asset URL' }
    return $assets[0]
}
