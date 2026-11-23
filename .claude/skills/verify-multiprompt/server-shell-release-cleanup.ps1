if (Get-Variable serverProofStarted -ErrorAction SilentlyContinue) {
    try {
        $linuxEvidence = (Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'wslpath', '-a', $Evidence) -Evidence $Evidence -Name 'shell-evidence-path').Trim()
        [void](Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'bash', "$serverProofRepo/tools/verify-server-chat/stop.sh", $linuxEvidence) -Evidence $Evidence -Name 'shell-server-stop')
    } finally {
        try {
            [void](Invoke-ServerNative -FilePath wsl.exe -Arguments @('--terminate', 'Ubuntu-24.04') -Evidence $Evidence -Name 'shell-wsl-terminate')
        } finally {
            Remove-Item -LiteralPath (Join-Path $scratch 'roaming/ZigShell/ssh-key') -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
