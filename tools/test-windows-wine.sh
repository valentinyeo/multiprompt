#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
zig=$(command -v "${ZIG:-/home/owner/zig/zig}")
export ZIG="$zig" ZIG_EXE="$zig"
export PATH="$(dirname "$zig"):$PATH"
lock=${MP_WINE_LOCK:-/tmp/multiprompt-wine.lock}

exec 9>"$lock"
flock -w 3600 9

gdiplus_dir=${MP_WINE_GDIPLUS_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/multiprompt/gdiplus}
if [[ ! -f "$gdiplus_dir/gdiplus.dll" ]]; then
    printf '%s\n' 'Microsoft x64 gdiplus.dll missing: see openwiki/operations/build-and-install.md' >&2
    exit 2
fi
export WINEPREFIX=${MP_WINE_TEST_PREFIX:-${XDG_CACHE_HOME:-$HOME/.cache}/multiprompt/wine-tests}
mkdir -p "$WINEPREFIX"
if [[ ! -d "$WINEPREFIX/drive_c/windows/system32" ]]; then
    wineboot -u
fi
cp --remove-destination "$gdiplus_dir/gdiplus.dll" "$WINEPREFIX/drive_c/windows/system32/gdiplus.dll"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:+$WINEDLLOVERRIDES;}gdiplus=n"

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

display=()
if [[ -z "${DISPLAY:-}" ]]; then
    if ! command -v xvfb-run >/dev/null 2>&1; then
        printf '%s\n' 'xvfb-run missing: install xvfb for headless Windows tests (see openwiki/operations/build-and-install.md)' >&2
        exit 2
    fi
    display=(xvfb-run -a)
fi

runner=()
if systemd-run --user --scope -q -p MemoryMax=12G -p CPUQuota=400% true >/dev/null 2>&1; then
    runner=(systemd-run --user --scope -q -p MemoryMax=12G -p CPUQuota=400%)
fi
if [[ -d tools/public-export ]]; then
    if ! "${runner[@]}" nice -n 15 node --test tools/public-export.test.js; then
        printf '%s\n' 'public-export would fail in CI: re-clean every changed pinned source in tools/public-export/overlay and update its pin in tools/public-export/manifest.json' >&2
        exit 1
    fi
fi
if ! "${runner[@]}" nice -n 15 "$zig" build -Dtarget=aarch64-windows-gnu -p "$shim/arm64" --summary none; then
    printf '%s\n' 'build-arm64 would fail in CI: fix the ARM64 compile error above; pointer casts from GetProcAddress need @ptrCast(@alignCast(...))' >&2
    exit 1
fi
"${runner[@]}" nice -n 15 "${display[@]}" "$zig" build test-desktop -Dtarget=x86_64-windows-gnu -fwine -j4 --summary all "$@"
"${runner[@]}" nice -n 15 "$zig" build test-vps --summary all
