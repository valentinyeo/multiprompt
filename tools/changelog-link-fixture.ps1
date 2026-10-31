if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows') { throw 'GitHub Windows only' }
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Text;
public static class LinkFixtureNative {
    [DllImport("shlwapi.dll", CharSet=CharSet.Unicode)] static extern int AssocQueryString(uint flags, uint str, string assoc, string extra, StringBuilder output, ref uint size);
    [DllImport("shell32.dll")] public static extern void SHChangeNotify(uint evt, uint flags, IntPtr a, IntPtr b);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hwnd, out Rect rect);
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    public static string Query(uint kind) {
        uint size = 0; AssocQueryString(0x1000, kind, "https", "open", null, ref size);
        if (size == 0 || size > 32768) return null;
        var text = new StringBuilder((int)size);
        return AssocQueryString(0x1000, kind, "https", "open", text, ref size) == 0 ? text.ToString() : null;
    }
}
'@
$script:linkCreated = @(); $script:linkBefore = @{}; $script:linkKey = $null; $script:linkAck = $null; $script:linkPath = $null
function Start-LinkFixture {
    $result.registryRestored = $false
    $result.limitations = @('Receipt proves native URL dispatch, not authenticated page loading', 'Manifest index requires selected-version screenshot review', 'Other ticket links are audited as data, not clicked')
    $result.audit = Read-Json "$Output/changelog-audit.json"
    if (-not $result.audit.rejected) { throw 'Synthetic generator guard did not pass' }
    $userChoice = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice')
    try { $choice = if ($userChoice) { $userChoice.GetValue('ProgId') } else { $null } } finally { if ($userChoice) { $userChoice.Dispose() } }
    $effective = [LinkFixtureNative]::Query(20)
    if (-not $effective -or ($choice -and $choice -ine $effective) -or $effective -notmatch '^[A-Za-z0-9_.-]+$') { throw 'HTTPS association target unknown or inconsistent' }
    $result.association = @{progId=$effective; userChoicePresent=[bool]$choice; queriedProgId=$true; commandVerified=$false}
    $script:linkPath = "Software\Classes\$effective\shell\open\command"
    $root = [Microsoft.Win32.Registry]::CurrentUser
    $parts = $linkPath.Split('\'); $path = ''
    foreach ($part in $parts) {
        $path = if ($path) { "$path\$part" } else { $part }
        $key = $root.OpenSubKey($path)
        if ($key) { $key.Dispose() } else { $key = $root.CreateSubKey($path); $key.Dispose(); $script:linkCreated += $path }
    }
    $script:linkKey = $root.OpenSubKey($linkPath, $true)
    foreach ($name in @('', 'DelegateExecute')) {
        $exists = $linkKey.GetValueNames() -contains $name
        $script:linkBefore[$name] = if ($exists) { @{exists=$true; value=$linkKey.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames); kind=$linkKey.GetValueKind($name)} } else { @{exists=$false} }
    }
    $merged = [Microsoft.Win32.Registry]::ClassesRoot.OpenSubKey("$effective\shell\open\command")
    try { $delegate = $merged -and ($merged.GetValueNames() -contains 'DelegateExecute') } finally { if ($merged) { $merged.Dispose() } }
    $script:linkExe = [IO.Path]::GetFullPath((Join-Path $profile 'link-receiver.exe')); $script:linkReceipt = "$profile/link-receipt.txt"
    $script:linkNonce = [guid]::NewGuid().ToString('N'); $eventName = 'Local\ChangelogProof-' + $linkNonce
    $created = $false
    $script:linkAck = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $eventName, [ref]$created)
    if (-not $created) { throw 'Receiver event already exists' }
    $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    & $csc /nologo /target:winexe "/out:$linkExe" "$PSScriptRoot/changelog-receiver.cs"
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $linkExe)) { throw 'Receiver compilation failed' }
    $command = '"{0}" "{1}" "%1" "{2}" "{3}"' -f $linkExe, $linkReceipt, $eventName, $linkNonce
    $linkKey.SetValue('', $command, [Microsoft.Win32.RegistryValueKind]::String)
    if ($delegate) { $linkKey.SetValue('DelegateExecute', '', [Microsoft.Win32.RegistryValueKind]::String) }
    [LinkFixtureNative]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
    $queried = [LinkFixtureNative]::Query(1)
    if ([LinkFixtureNative]::Query(20) -ine $effective -or -not $queried -or $queried -cne $command) { throw 'HTTPS fixture command or association not effective' }
    $result.association.commandVerified = $true
}
function Receive-Link([string]$Expected, [string]$Name) {
    [void](Wait-For 'native URL receipt' { Test-Path -LiteralPath $linkReceipt } 30)
    $lines = [IO.File]::ReadAllLines($linkReceipt, [Text.Encoding]::UTF8)
    if ($lines.Count -ne 3 -or $lines[2] -cne $linkNonce -or $lines[1] -notmatch '^\d+$') { throw 'Invalid receiver receipt' }
    $receiver = Get-Process -Id ([int]$lines[1]); $receiverMatches = $false
    try {
        $receiverMatches = [IO.Path]::GetFullPath($receiver.Path) -ieq $linkExe
        if (-not $receiverMatches -or -not $job.Contains($receiver)) { throw 'Receiver is not in owned app job' }
        $observed = if ($lines[0] -cmatch '^https://app\.hypertask\.ai/detail/project-2060/\d+$') { $lines[0] } else { '[noncanonical]' }
        $result.receipts += @{input=$Name; expected=$Expected; observed=$observed; pid=$receiver.Id; nonceMatched=$true; owned=$true}
        if ($lines[0] -cne $Expected) { throw 'Native URL differs from manifest' }
        [void]$linkAck.Set()
        if (-not $receiver.WaitForExit(10000) -or $receiver.ExitCode -ne 0) { throw 'Receiver did not exit after acknowledgement' }
        Shot "changelog-$Name-after-receipt"
    } finally {
        if ($receiverMatches) { [void]$linkAck.Set(); [void]$receiver.WaitForExit(10000) }
        $receiver.Dispose()
    }
    Remove-Item -LiteralPath $linkReceipt
}
function Prepare-LinkReceipt {
    if (Test-Path -LiteralPath $linkReceipt) { throw 'Receiver receipt is not fresh' }
    [void]$linkAck.Reset()
}
function Stop-LinkFixture {
    if ($linkAck) { [void]$linkAck.Set(); $linkAck.Dispose(); $script:linkAck = $null }
    if (-not $linkPath) { return }; $restoreFailed = $false
    if ($linkKey) {
        foreach ($name in @('', 'DelegateExecute')) {
            if (-not $linkBefore.ContainsKey($name)) { continue }
            $before = $linkBefore[$name]
            try { if ($before.exists) { $linkKey.SetValue($name, $before.value, $before.kind) } else { $linkKey.DeleteValue($name, $false) } } catch { $restoreFailed = $true; $result.cleanupErrors += "Restore association value: $($_.Exception.Message)" }
        }
        try { $linkKey.Flush() } catch { $restoreFailed = $true; $result.cleanupErrors += "Flush association key: $($_.Exception.Message)" }; $linkKey.Dispose(); $script:linkKey = $null
    }
    [array]::Reverse($linkCreated)
    foreach ($path in $linkCreated) {
        try {
            $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($path)
            if ($key) { try { if ($key.SubKeyCount -ne 0 -or $key.ValueCount -ne 0) { throw 'Owned association key not empty' } } finally { $key.Dispose() }; [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKey($path) }
        } catch { $restoreFailed = $true; $result.cleanupErrors += "Remove owned association key: $($_.Exception.Message)" }
    }
    [LinkFixtureNative]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
    $check = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($linkPath)
    try {
        foreach ($name in $linkBefore.Keys) {
            $before = $linkBefore[$name]; $exists = $check -and ($check.GetValueNames() -contains $name)
            if ([bool]$exists -ne $before.exists) { throw 'Association value presence not restored' }
            if ($exists -and ($check.GetValueKind($name) -ne $before.kind -or -not [System.Collections.StructuralComparisons]::StructuralEqualityComparer.Equals($check.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames), $before.value))) { throw 'Association value not restored' }
        }
    } finally { if ($check) { $check.Dispose() } }
    if ($restoreFailed) { throw 'Association restoration operation failed' }; $result.registryRestored = $true
}
