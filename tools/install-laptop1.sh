#!/usr/bin/env bash
set -euo pipefail
only_ext=0
bench=''
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
while [ "$#" -gt 0 ]; do
  case "$1" in
    --extension-only) only_ext=1; shift ;;
    --bench)
      if [ "$#" -lt 2 ] || [[ "$2" = --* ]]; then echo 'missing --bench <results.json>' >&2; exit 1; fi
      bench="$2"; shift 2 ;;
    --*) echo "unknown option: $1" >&2; exit 1 ;;
    *) break ;;
  esac
done
if [ "$#" -gt 1 ]; then echo 'expected one PC source directory' >&2; exit 1; fi
src="${1:-C:\\Users\\user\\Documents\\GitHub\\zigshell-mp725}"
app='C:\Users\user\Documents\GitHub\zigshell'

if [ "$only_ext" = 0 ]; then
  if [ -z "$bench" ]; then
    echo 'refusing to install: pass --bench <results.json> from a default-config PASS of node tools/chat-bench/run.mjs --exe <the multiprompt.exe to install>' >&2
    exit 1
  fi
  receipt_info=$(node -e 'const r=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); console.log(r.exe); console.log(r.binary?.exeSha256)' "$bench")
  mapfile -t receipt_fields <<< "$receipt_info"
  exe="${receipt_fields[0]}"
  receipt_sha="${receipt_fields[1]:-}"
  node "$script_dir/chat-bench/receipt.mjs" "$bench" "$receipt_sha"
  fragments=$(lh shell "(Get-ChildItem '$src\\changelog.d' -Filter *.md -ErrorAction SilentlyContinue | ? Name -ne 'README.md' | Measure-Object).Count" --timeout 60 | tr -d '\r\n ')
  if [ "$fragments" -gt 0 ]; then
    echo "source has unstamped changelog.d fragments; run node tools/version-stamp.mjs release and build from the stamped origin/master" >&2
    exit 1
  fi
  upload_dir=$(mktemp -d)
  trap 'rm -rf -- "$upload_dir"' EXIT
  base64 -w0 "$exe" | split -b 45000 -d -a 6 - "$upload_dir/"
  upload_pc="$src\\zig-out\\bin\\bench-upload"
  lh shell "Remove-Item '$upload_pc' -Recurse -Force -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force '$upload_pc' | Out-Null" --timeout 60
  for part in "$upload_dir/"*; do
    lh write "$upload_pc\\$(basename "$part").b64" --binary "$(base64 -w0 "$part")"
  done
  lh shell "\$parts=Get-ChildItem '$upload_pc' -Filter '*.b64' | Sort-Object Name;
    \$text=(\$parts | ForEach-Object { [IO.File]::ReadAllText(\$_.FullName) }) -join '';
    [IO.File]::WriteAllBytes('$src\\zig-out\\bin\\multiprompt-benched.exe', [Convert]::FromBase64String(\$text));
    Remove-Item '$upload_pc' -Recurse -Force" --timeout 60
  pc_sha=$(lh shell "(Get-FileHash '$src\\zig-out\\bin\\multiprompt-benched.exe' -Algorithm SHA256).Hash" --timeout 60 | tr -d '\r\n ')
  if [ "${pc_sha,,}" != "${receipt_sha,,}" ]; then
    echo 'PC copy hash mismatch' >&2
    exit 1
  fi
  lh shell "\$b='$app\\zig-out\\bin'; \$s='$src\\zig-out\\bin'; \$t=Get-Date -Format HHmmss;
    \$v=(Select-String -Path \"\$b\\multiprompt.exe\" -Pattern 'multiprompt v0\.\d+\.\d+' -Encoding Unicode -List).Matches[0].Value -replace 'multiprompt ','';
    Rename-Item \"\$b\\multiprompt.exe\" \"multiprompt-stable-\$v-\$t.exe\"; Copy-Item \"\$s\\multiprompt-benched.exe\" \"\$b\\multiprompt.exe\";
    Rename-Item \"\$b\\zigshell-bridge.exe\" \"zigshell-bridge-old-\$t.exe\" -ErrorAction SilentlyContinue; Copy-Item \"\$s\\zigshell-bridge.exe\" \"\$b\\zigshell-bridge.exe\" -Force;
    Get-ChildItem \"\$b\\multiprompt-stable-v*.exe\" | Sort LastWriteTime -Descending | Select -Skip 5 | Remove-Item;
    Get-ChildItem \"\$b\\zigshell-bridge-old-*.exe\" | Remove-Item -ErrorAction SilentlyContinue; 'app installed, backup of ' + \$v" --timeout 60
fi

lh shell "\$s='$src\\extension'; \$d='$app\\extension';
  Get-ChildItem \$s -Recurse -File | ? { \$_.FullName -notlike '*\\themes\\current\\*' } | % {
    \$t = \$_.FullName.Replace(\$s, \$d); New-Item -ItemType Directory -Force (Split-Path \$t) | Out-Null; Copy-Item \$_.FullName \$t -Force };
  'extension files ' + (Get-Content \"\$d\\manifest.json\" -Raw | ConvertFrom-Json).version" --timeout 60

want=$(lh shell "(Get-Content '$app\\extension\\manifest.json' -Raw | ConvertFrom-Json).version" | tr -d '\r\n ')
bridge_call() {
  lh shell "\$p = Start-Process '$app\\zig-out\\bin\\zigshell-bridge.exe' -ArgumentList '$1' -NoNewWindow -PassThru -RedirectStandardOutput \"\$env:TEMP\\mp-install.txt\" -RedirectStandardError \"\$env:TEMP\\mp-install-err.txt\";
    if (-not \$p.WaitForExit(35000)) { \$p.Kill() }; Get-Content \"\$env:TEMP\\mp-install.txt\",\"\$env:TEMP\\mp-install-err.txt\" -Raw" --timeout 45
}
loaded_version() { bridge_call tabs | grep -o '"extensionVersion":"[0-9.]*"' | head -1 | cut -d'"' -f4 || true; }
got=$(loaded_version)
if [ "$got" != "$want" ]; then got=$(loaded_version); fi
if [ "$got" = "$want" ]; then
  echo "EXTENSION_OK $want self-healed"
  if [ "$only_ext" = 0 ]; then echo "app installed, bench receipt $receipt_sha"; fi
  exit 0
fi
bridge_call extension-reload >/dev/null || true
for _ in 1 2 3 4 5 6; do
  sleep 4
  got=$(loaded_version)
  if [ "$got" = "$want" ]; then
    echo "EXTENSION_OK $want"
    if [ "$only_ext" = 0 ]; then echo "app installed, bench receipt $receipt_sha"; fi
    exit 0
  fi
done
echo "EXTENSION_MISMATCH want=$want got=${got:-none}: reload the extension in chrome://extensions" >&2
exit 1
