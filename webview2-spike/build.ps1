
param([switch]$Run)

$ErrorActionPreference = "Stop"
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path



$sdk  = "$dir\webview2-sdk\build\native"
$inc  = "$sdk\include"
$lib  = "$sdk\x64\WebView2Loader.dll.lib"
$dll  = "$sdk\x64\WebView2Loader.dll"
$src  = "$dir\main.cpp"
$out  = "$dir\webview2-spike.exe"
$dlld = "$dir\WebView2Loader.dll"

if (-not (Test-Path $src)) { throw "main.cpp not found at $src" }
if (-not (Test-Path $lib)) { throw "WebView2Loader.dll.lib not found — run fetch-sdk.ps1 first" }

Write-Host "Building $out ..."

& zig c++ $src `
    -I $inc `
    -I $dir `
    $lib `
    -lole32 -luser32 -lgdi32 `
    -mwindows `
    -std=c++17 `
    -O2 `
    -Wno-nullability-completeness `
    -Wno-unused-command-line-argument `
    -o $out

if ($LASTEXITCODE -ne 0) {
    throw "zig c++ failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $dlld)) {
    Copy-Item $dll $dlld
    Write-Host "Copied WebView2Loader.dll next to the exe."
}

Write-Host "Build succeeded: $out"

if ($Run) {
    Write-Host "Launching..."
    Start-Process $out
}
