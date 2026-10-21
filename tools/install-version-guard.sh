#!/usr/bin/env bash
check_install_version() {
  local exe="$1" candidate="${2#v}" allow_downgrade="$3"
  installed_version=''
  if ! installed_version=$(lh shell "\$ErrorActionPreference='Stop'; \$exe='$exe';
    \$bytes=[IO.File]::ReadAllBytes(\$exe);
    \$markers=@([regex]::Matches([Text.Encoding]::ASCII.GetString(\$bytes), 'MPVERSION=([0-9]+\.[0-9]+\.[0-9]+);') | ForEach-Object { \$_.Groups[1].Value } | Select-Object -Unique);
    if (\$markers.Count -gt 1) { throw 'ambiguous installed version' }
    if (\$markers.Count -eq 1) { \$markers[0]; exit }
    \$version=[Diagnostics.FileVersionInfo]::GetVersionInfo(\$exe).FileVersion;
    if (\$version -match '^([0-9]+\.[0-9]+\.[0-9]+)(?:\.0)?$') { \$Matches[1]; exit }
    \$titles=@([regex]::Matches([Text.Encoding]::Unicode.GetString(\$bytes), 'multiprompt v([0-9]+\.[0-9]+\.[0-9]+)') | ForEach-Object { \$_.Groups[1].Value } | Select-Object -Unique);
    if (\$titles.Count -ne 1) { throw 'unreadable installed version' }
    \$titles[0]" --timeout 60 | tr -d '\r\n'); then
    installed_version=''
  fi
  if [[ ! "$installed_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    installed_version=unknown
    if [ "$allow_downgrade" = 1 ]; then return 0; fi
    echo 'refusing install: installed version cannot be read (pass --allow-downgrade to override)' >&2
    return 1
  fi
  if [ "$allow_downgrade" = 1 ]; then return 0; fi
  node --input-type=module - "$installed_version" "$candidate" <<'NODE'
const [installed, candidate] = process.argv.slice(2);
const left = installed.split('.').map(BigInt);
const right = candidate.split('.').map(BigInt);
for (let i = 0; i < left.length; i++) {
  if (left[i] < right[i]) process.exit(0);
  if (left[i] > right[i]) break;
}
console.error(`refusing install: installed ${installed} is equal or newer than candidate ${candidate} (pass --allow-downgrade to override)`);
process.exit(1);
NODE
}
