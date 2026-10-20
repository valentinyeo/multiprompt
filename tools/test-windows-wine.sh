#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
zig=$(command -v "${ZIG:-/home/owner/zig/zig}")
export ZIG="$zig" ZIG_EXE="$zig"
export PATH="$(dirname "$zig"):$PATH"
lock=${MP_WINE_LOCK:-/tmp/multiprompt-wine.lock}

exec 9>"$lock"
flock -w 3600 9

shim=$(mktemp -d)
trap 'rm -rf "$shim"' EXIT
export PATH="$shim:$PATH"
if ! command -v python >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
    ln -s "$(command -v python3)" "$shim/python"
fi
if ! command -v pwsh >/dev/null 2>&1; then
    pwsh=${MP_PWSH:-$HOME/.local/opt/powershell/pwsh}
    if [[ ! -x "$pwsh" ]]; then
        printf '%s\n' 'pwsh missing: install PowerShell to ~/.local/opt/powershell (see openwiki/operations/build-and-install.md)' >&2
        exit 2
    fi
    ln -s "$pwsh" "$shim/pwsh"
fi

runner=()
if systemd-run --user --scope -q -p MemoryMax=12G -p CPUQuota=400% true >/dev/null 2>&1; then
    runner=(systemd-run --user --scope -q -p MemoryMax=12G -p CPUQuota=400%)
fi
"${runner[@]}" nice -n 15 "$zig" build test-desktop -Dtarget=x86_64-windows-gnu -fwine -j4 --summary all "$@"
"${runner[@]}" nice -n 15 "$zig" build test-vps --summary all
