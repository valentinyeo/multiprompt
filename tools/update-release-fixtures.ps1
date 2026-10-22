param([Parameter(Mandatory=$true)][string]$Root)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:OS -ne 'Windows_NT') { throw 'Fixtures run only in GitHub Windows' }
New-Item -ItemType Directory -Force $Root | Out-Null
$publicKeyPath = [IO.Path]::GetFullPath("$PSScriptRoot/../src/release_signing_public_key.txt")
$originalPublicKey = [IO.File]::ReadAllText($publicKeyPath)
try {
    [IO.File]::WriteAllText($publicKeyPath, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=`n")
    $placeholder = Start-Process zig.exe -ArgumentList 'build -Drelease=true' -Wait -PassThru -RedirectStandardError "$Root/placeholder-error.txt"
    if ($placeholder.ExitCode -eq 0 -or (Get-Content "$Root/placeholder-error.txt" -Raw) -notmatch 'Release signing public key is still the all-zero placeholder') { throw 'Release build did not reject the fake public key loudly' }
} finally {
    [IO.File]::WriteAllText($publicKeyPath, $originalPublicKey)
}
Write-Host 'Release placeholder rejected; ordinary tests remain buildable'

$source = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
class UpdateFixture {
    static int Main(string[] args) {
        string exe = Process.GetCurrentProcess().MainModule.FileName;
        if (args.Length > 0 && (args[0] == "--verify-release-manifest" || args[0] == "--stop-update-helpers")) {
            string command = args[0];
            for (int i = 1; i < args.Length; i++) command += " \"" + args[i] + "\"";
            var child = Process.Start(new ProcessStartInfo(Environment.GetEnvironmentVariable("MULTIPROMPT_TEST_VERIFIER"), command) { UseShellExecute = false });
            child.WaitForExit();
            return child.ExitCode;
        }
        if (args.Length > 0 && args[0] == "--usage-telemetry") {
            using (var mutex = new Mutex(true, "Local\\MultipromptUsageTelemetry"))
            using (var stop = new EventWaitHandle(false, EventResetMode.ManualReset, "Local\\MultipromptUsageTelemetryStop")) {
                File.WriteAllText(exe + ".telemetry-ready", "ready");
                stop.WaitOne();
                mutex.ReleaseMutex();
            }
            return 0;
        }
        File.AppendAllText(exe + ".starts", String.Join("|", args) + "\n");
        if (Environment.GetEnvironmentVariable("MULTIPROMPT_TEST_BROKEN") == "1") return 1;
        for (int i = 0; i + 1 < args.Length; i++) {
            if (args[i] == "--update-ready") { using (var e = EventWaitHandle.OpenExisting(args[i + 1])) e.Set(); }
        }
        Thread.Sleep(300000);
        return 0;
    }
}
'@
Add-Type -TypeDefinition $source -OutputAssembly "$Root/fixture.exe" -OutputType ConsoleApplication
Add-Type -TypeDefinition 'class UpdateBroken { static int Main() { return 1; } }' -OutputAssembly "$Root/broken.exe" -OutputType ConsoleApplication
New-Item -ItemType Directory -Force "$Root/extension/themes/current" | Out-Null
[IO.File]::WriteAllText("$Root/extension/manifest.json", '{"version":"2.0.0"}')
[IO.File]::WriteAllText("$Root/extension/themes/current/manifest.json", '{"version":"9.0.0"}')
Compress-Archive -Path "$Root/extension/*" -DestinationPath "$Root/extension.zip"
node "$PSScriptRoot/update-release-fixtures.mjs" $Root
if ($LASTEXITCODE -ne 0) { throw 'Could not sign throwaway fixtures' }
