#!/usr/bin/env bash
set -euo pipefail
only_ext=0
allow_downgrade=0
bench=''
release=''
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/install-version-guard.sh"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --extension-only) only_ext=1; shift ;;
    --allow-downgrade) allow_downgrade=1; shift ;;
    --bench|--release)
      if [ "$#" -lt 2 ] || [[ "$2" = --* ]]; then echo "missing $1 value" >&2; exit 1; fi
      if [ "$1" = --bench ]; then bench="$2"; else release="$2"; fi
      shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done
if [ -z "$release" ]; then
  echo 'usage: tools/install-laptop1.sh [--extension-only] [--allow-downgrade] --release <vX.Y.Z|latest> [--bench <results.json>]' >&2
  exit 1
fi
if [ "$only_ext" = 0 ] && [ -z "$bench" ]; then
  echo 'refusing to install: pass --bench <results.json> from a default-config PASS of node tools/chat-bench/run.mjs --exe <the multiprompt.exe to install>' >&2
  exit 1
fi
repo=valentinyeo/multiprompt
if [ "$release" = latest ]; then
  release=$(gh release view -R "$repo" --json tagName --jq .tagName)
fi
if [[ ! "$release" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo 'invalid release tag' >&2; exit 1; fi
download_dir=$(mktemp -d)
checked_pc=0
staged_pc=0
check_no_zig() {
  local state
  if ! state=$(lh shell "if (Get-Process zig -ErrorAction SilentlyContinue) { 'ZIG_RUNNING' } else { 'ZIG_CLEAR' }" --timeout 60 | tr -d '\r\n '); then
    echo 'refusing install: laptop process check failed' >&2; return 1
  fi
  if [ "$state" != ZIG_CLEAR ]; then echo 'refusing install: running zig process on laptop or process check failed' >&2; return 1; fi
}
finish() {
  local status=$?
  trap - EXIT
  if [ "$staged_pc" = 1 ]; then
    if ! lh shell "Remove-Item '$upload_pc' -Recurse -Force -ErrorAction SilentlyContinue" --timeout 60; then status=1; fi
  fi
  if [ "$checked_pc" = 1 ]; then
    if ! check_no_zig; then status=1;
    elif [ "$status" = 0 ]; then echo "NO_ZIG_ON_LAPTOP $release"; fi
  fi
  rm -rf -- "$download_dir"
  exit "$status"
}
trap 'finish' EXIT
assets=(multiprompt-extension.zip)
if [ "$only_ext" = 0 ]; then assets+=(multiprompt-x64.exe zigshell-bridge-x64.exe); fi
gh api "repos/$repo/releases/tags/$release" > "$download_dir/release.json"
patterns=(--pattern SHA256SUMS.txt)
for asset in "${assets[@]}"; do patterns+=(--pattern "$asset"); done
gh release download "$release" -R "$repo" --dir "$download_dir" "${patterns[@]}"
node --input-type=module - "$download_dir" "$release" "${assets[@]}" <<'NODE'
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
const [dir, tag, ...names] = process.argv.slice(2);
const metadata = JSON.parse(fs.readFileSync(path.join(dir, 'release.json'), 'utf8'));
if (metadata.tag_name !== tag || metadata.draft) throw new Error('Release metadata does not match published tag');
const sha = name => createHash('sha256').update(fs.readFileSync(path.join(dir, name))).digest('hex');
for (const name of ['SHA256SUMS.txt', ...names]) {
  const matches = metadata.assets.filter(asset => asset.name === name);
  if (matches.length !== 1 || matches[0].digest !== `sha256:${sha(name)}`) throw new Error(`GitHub asset digest mismatch: ${name}`);
}
const sums = new Map();
for (const line of fs.readFileSync(path.join(dir, 'SHA256SUMS.txt'), 'utf8').trim().split(/\r?\n/)) {
  const match = line.match(/^([a-f0-9]{64}) [ *]([^/\\]+)$/);
  if (!match || sums.has(match[2])) throw new Error('Invalid SHA256SUMS.txt');
  sums.set(match[2], match[1]);
}
for (const name of ['multiprompt-x64.exe', 'multiprompt-arm64.exe', 'zigshell-bridge-x64.exe', 'zigshell-bridge-arm64.exe', 'multiprompt-extension.zip']) {
  if (!sums.has(name)) throw new Error(`Missing SHA256SUMS.txt entry: ${name}`);
}
for (const name of names) {
  if (sums.get(name) !== sha(name)) throw new Error(`SHA256SUMS.txt mismatch: ${name}`);
}
NODE
if [ "$only_ext" = 0 ]; then
  receipt_sha=$(sha256sum "$download_dir/multiprompt-x64.exe" | cut -d' ' -f1)
  node --input-type=module - "$bench" "$download_dir/multiprompt-x64.exe" "$download_dir/results-local.json" <<'NODE'
import fs from 'node:fs';
const [input, exe, output] = process.argv.slice(2);
try {
  const receipt = JSON.parse(fs.readFileSync(input, 'utf8'));
  receipt.exe = exe;
  fs.writeFileSync(output, JSON.stringify(receipt));
} catch (error) {
  console.error(`RECEIPT_REJECTED: ${error.message}`);
  process.exitCode = 1;
}
NODE
  node "$script_dir/chat-bench/receipt.mjs" "$download_dir/results-local.json" "$receipt_sha"
fi
check_no_zig
checked_pc=1
profile=$(lh shell '$env:USERPROFILE' --timeout 60 | tr -d '\r\n')
if [[ ! "$profile" =~ ^[A-Za-z]:\\Users\\[A-Za-z0-9._-]+$ ]]; then echo 'refusing install: unexpected laptop user folder' >&2; exit 1; fi
app="$profile\\Documents\\GitHub\\zigshell"
if [ "$only_ext" = 0 ]; then
  check_install_version "$app\\zig-out\\bin\\multiprompt.exe" "$release" "$allow_downgrade"
fi
upload_pc="$app\\release-upload-$(basename "$download_dir")"
staged_pc=1
lh shell "\$ErrorActionPreference='Stop'; New-Item -ItemType Directory -Force '$upload_pc' | Out-Null" --timeout 60
upload() {
  local name="$1" part pc_sha expected_sha
  mkdir "$download_dir/chunks"
  base64 -w0 "$download_dir/$name" | split -b 45000 -d -a 6 - "$download_dir/chunks/"
  lh shell "\$ErrorActionPreference='Stop'; New-Item -ItemType Directory -Force '$upload_pc\\$name.parts' | Out-Null" --timeout 60
  for part in "$download_dir/chunks/"*; do
    lh write "$upload_pc\\$name.parts\\$(basename "$part").b64" --binary "$(base64 -w0 "$part")"
  done
  lh shell "\$ErrorActionPreference='Stop'; \$parts=Get-ChildItem '$upload_pc\\$name.parts' -Filter '*.b64' | Sort-Object Name;
    \$text=(\$parts | ForEach-Object { [IO.File]::ReadAllText(\$_.FullName) }) -join '';
    [IO.File]::WriteAllBytes('$upload_pc\\$name', [Convert]::FromBase64String(\$text));
    Remove-Item '$upload_pc\\$name.parts' -Recurse -Force" --timeout 60
  pc_sha=$(lh shell "(Get-FileHash '$upload_pc\\$name' -Algorithm SHA256).Hash" --timeout 60 | tr -d '\r\n ')
  expected_sha=$(sha256sum "$download_dir/$name" | cut -d' ' -f1)
  if [ "${pc_sha,,}" != "$expected_sha" ]; then echo "PC copy hash mismatch: $name" >&2; exit 1; fi
  rm -rf -- "$download_dir/chunks"
}
for asset in "${assets[@]}"; do upload "$asset"; done
if [ "$only_ext" = 0 ]; then
  lh shell "\$ErrorActionPreference='Stop'; \$b='$app\\zig-out\\bin'; \$s='$upload_pc'; \$t=Get-Date -Format HHmmss;
    \$v='v$installed_version';
    Rename-Item \"\$b\\multiprompt.exe\" \"multiprompt-stable-\$v-\$t.exe\"; Copy-Item \"\$s\\multiprompt-x64.exe\" \"\$b\\multiprompt.exe\";
    Rename-Item \"\$b\\zigshell-bridge.exe\" \"zigshell-bridge-old-\$t.exe\" -ErrorAction SilentlyContinue; Copy-Item \"\$s\\zigshell-bridge-x64.exe\" \"\$b\\zigshell-bridge.exe\" -Force;
    Get-ChildItem \"\$b\\multiprompt-stable-v*.exe\" | Sort LastWriteTime -Descending | Select -Skip 5 | Remove-Item;
    Get-ChildItem \"\$b\\zigshell-bridge-old-*.exe\" | Remove-Item -ErrorAction SilentlyContinue; 'app installed, backup of ' + \$v" --timeout 60
fi
lh shell "\$ErrorActionPreference='Stop'; Expand-Archive '$upload_pc\\multiprompt-extension.zip' '$upload_pc\\extension' -Force;
  \$s='$upload_pc\\extension'; \$d='$app\\extension';
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
  finish
fi
bridge_call extension-reload >/dev/null || true
for _ in 1 2 3 4 5 6; do
  sleep 4
  got=$(loaded_version)
  if [ "$got" = "$want" ]; then
    echo "EXTENSION_OK $want"
    if [ "$only_ext" = 0 ]; then echo "app installed, bench receipt $receipt_sha"; fi
    finish
  fi
done
echo "EXTENSION_MISMATCH want=$want got=${got:-none}: reload the extension in chrome://extensions" >&2
exit 1
