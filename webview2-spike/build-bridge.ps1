param([string]$SdkRoot = $env:WEBVIEW2_SDK_ROOT)

$ErrorActionPreference = "Stop"
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $dir
$sdk = if ($SdkRoot) { $SdkRoot } else { Join-Path $dir "webview2-sdk\build\native" }
$out = Join-Path $root "zig-out\bin"

New-Item -ItemType Directory -Force $out | Out-Null


& zig c++ (Join-Path $dir "webview2_bridge.cpp") `
    -I (Join-Path $sdk "include") `
    -I $dir `
    (Join-Path $sdk "x64\WebView2Loader.dll.lib") `
    -lole32 -luser32 -lgdi32 `
    -shared -std=c++17 -O2 `
    -Wno-nullability-completeness `
    -Wno-unused-command-line-argument `
    -o (Join-Path $out "webview2_bridge.dll")

if ($LASTEXITCODE -ne 0) { throw "WebView2 bridge build failed: $LASTEXITCODE" }
Copy-Item (Join-Path $sdk "x64\WebView2Loader.dll") (Join-Path $out "WebView2Loader.dll") -Force
Write-Host "Staged WebView2 DEV bridge in $out"
