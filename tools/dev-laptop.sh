#!/usr/bin/env bash
set -u

evidence="${DEV_RIG_EVIDENCE:-./dev-rig-evidence}"

dev_dir() {
    lh_shell "\$d = Join-Path \$env:LOCALAPPDATA 'MultipromptDev'; New-Item -ItemType Directory -Force -Path \$d | Out-Null; \$d" 30 | tr -d '\r'
}
readonly DEV_EXE='multiprompt-dev.exe'

usage() {
    cat >&2 <<'USAGE'
usage: tools/dev-laptop.sh install [run-id|latest]
       tools/dev-laptop.sh place
       tools/dev-laptop.sh journey ctrl-t
       tools/dev-laptop.sh shot <name>
       tools/dev-laptop.sh cleanup <term names...>

Installs the dev build on Valentin's laptop, parks it on the second monitor and drives one journey.
Never touches multiprompt.exe.
USAGE
    exit 2
}

lh_shell() { lh shell "$1" --timeout "${2:-30}"; }

windows_path() { printf '%s' "$1" | sed 's#\\#/#g'; }

find_run() {
    local wanted="${1:-latest}"
    if [[ $wanted == latest ]]; then
        gh run list --workflow dev-build.yml --limit 1 --json databaseId -q '.[0].databaseId'
    else
        printf '%s' "$wanted"
    fi
}

install_build() {
    local run
    run=$(find_run "${1:-latest}")
    [[ -n $run ]] || { echo 'no dev build run found' >&2; exit 1; }
    local dir
    dir=$(mktemp -d)
    gh run download "$run" --pattern 'multiprompt-dev*' -D "$dir" >/dev/null || { echo "run $run has no dev artifact" >&2; exit 1; }
    local downloaded
    downloaded=$(find "$dir" -name 'multiprompt-dev.exe' | head -1)
    [[ -n $downloaded ]] || { echo "run $run artifact has no multiprompt-dev.exe" >&2; exit 1; }
    local sha
    sha=$(sha256sum "$downloaded" | cut -d' ' -f1)
    echo "run=$run exe=$(basename "$downloaded") sha=$sha"
    local dir
    dir=$(dev_dir)
    echo "laptop dev dir: $dir"
    local payload
    payload=$(base64 -w0 "$downloaded")
    local total=${#payload}
    local chunk=120000
    local index=0
    while (( index * chunk < total )); do
        lh write "$dir\\chunk.$index.b64" "${payload:$((index * chunk)):$chunk}" >/dev/null || { echo "chunk $index upload failed" >&2; exit 1; }
        index=$((index + 1))
    done
    echo "uploaded $index chunk(s)"
    lh_shell "\$dir = '$dir'; \$files = Get-ChildItem \$dir -Filter 'chunk.*.b64' | Sort-Object { [int](\$_.Name -replace '\\D','') }; \$b64 = (\$files | ForEach-Object { (Get-Content \$_.FullName -Raw).Trim() }) -join ''; [IO.File]::WriteAllBytes((Join-Path \$dir 'multiprompt-dev.new.exe'), [Convert]::FromBase64String(\$b64)); \$files | Remove-Item -Force; (Get-Item (Join-Path \$dir 'multiprompt-dev.new.exe')).Length" 120
    lh_shell "\$dir = '$dir'; Get-Process -Name 'multiprompt-dev' -ErrorAction SilentlyContinue | Where-Object { \$_.Path -and \$_.Path.StartsWith(\$dir) } | ForEach-Object { \$_.Kill(); \$_.WaitForExit(5000) }; Move-Item -Force (Join-Path \$dir 'multiprompt-dev.new.exe') (Join-Path \$dir '$DEV_EXE'); 'stopped-and-replaced'" 60
    rm -rf "$dir"
    echo "installed run $run"
}

place_window() {
    local dir
    dir=$(dev_dir)
    lh_shell "\$dir = '$dir'; \$exe = Join-Path \$dir '$DEV_EXE'; if (-not (Get-Process -Name 'multiprompt-dev' -ErrorAction SilentlyContinue)) { Start-Process -FilePath \$exe -WorkingDirectory \$dir }; Start-Sleep -Seconds 3; 'started'" 60
    lh_shell "\$d = @'
using System;
using System.Runtime.InteropServices;
public class MpWindow {
    [DllImport(\"user32.dll\")] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport(\"user32.dll\")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport(\"user32.dll\")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport(\"user32.dll\")] public static extern bool SetForegroundWindow(IntPtr h);
}
'@; Add-Type -TypeDefinition \$d; \$h = [MpWindow]::FindWindow('MultipromptDevWindow', \$null); if (\$h -eq [IntPtr]::Zero) { 'window-missing' } else { [MpWindow]::ShowWindow(\$h, 3) | Out-Null; [MpWindow]::SetWindowPos(\$h, [IntPtr]::Zero, -2560, -493, 2048, 1280, 0x0040) | Out-Null; [MpWindow]::SetForegroundWindow(\$h) | Out-Null; 'placed ' + \$h }" 45
}

shot() {
    local name="${1:-dev-window}"
    local out
    out=$(lh_shell "\$d = @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
public class MpShot {
    [DllImport(\"user32.dll\")] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport(\"user32.dll\")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport(\"user32.dll\")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    public struct RECT { public int Left, Top, Right, Bottom; }
    public static string Save(string path) {
        var h = FindWindow(\"MultipromptDevWindow\", null);
        if (h == IntPtr.Zero) return \"window-missing\";
        RECT r; if (!GetWindowRect(h, out r)) return \"no-rect\";
        var bmp = new Bitmap(r.Right - r.Left, r.Bottom - r.Top);
        using (var g = Graphics.FromImage(bmp)) { var hdc = g.GetHdc(); PrintWindow(h, hdc, 0); g.ReleaseHdc(hdc); }
        bmp.Save(path, System.Drawing.Imaging.ImageFormat.Png);
        return \"saved \" + path;
    }
}
'@; Add-Type -TypeDefinition \$d; [MpShot]::Save(\"\$env:TEMP\\$name.png\")" 45)
    echo "$out"
    mkdir -p "$evidence"
    local local_png="$evidence/$name.png"
    : > "$local_png.b64"
    local offset=0 chunk_b64=0
    while :; do
        chunk_b64=$(lh_shell "\$p = Join-Path \$env:TEMP '$name.png'; if (-not (Test-Path \$p)) { '' } else { \$b = [IO.File]::ReadAllBytes(\$p); \$take = [Math]::Min(150000, [Math]::Max(0, \$b.Length - $offset)); if (\$take -le 0) { '' } else { [Convert]::ToBase64String(\$b, $offset, \$take) } }" 45 | tr -d '\r\n')
        [[ -z $chunk_b64 ]] && break
        printf '%s' "$chunk_b64" >> "$local_png.b64"
        offset=$((offset + 150000))
    done
    if [[ -s $local_png.b64 ]]; then
        base64 -d "$local_png.b64" > "$local_png" && rm -f "$local_png.b64" && echo "screenshot: $local_png"
    else
        echo "no screenshot bytes came back from the laptop" >&2
        return 1
    fi
}

cleanup() {
    local names=("$@")
    [[ ${#names[@]} -eq 0 ]] && return 0
    local list
    list=$(printf "'%s'," "${names[@]}")
    lh_shell "foreach (\$n in @(${list%,})) { & tmux kill-session -t \"=\$n:\" 2>\$null }; 'cleaned'" 45
}

case "${1:-}" in
    install) shift; install_build "${1:-latest}" ;;
    place) place_window ;;
    shot) shift; shot "${1:-dev-window}" ;;
    journey) shift; exec "$(dirname "$0")/dev-laptop-journey.sh" "${1:-ctrl-t}" ;;
    cleanup) shift; cleanup "$@" ;;
    *) usage ;;
esac
