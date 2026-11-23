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
Never touches multibot.exe.
USAGE
    exit 2
}

lh_shell() { lh shell "$1" --timeout "${2:-30}"; }
hc() { lh shell "$1" --timeout "${2:-30}"; }

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
    local swapped
    swapped=$(lh_shell "\$dir = '$dir'; Get-Process -Name 'multiprompt-dev' -ErrorAction SilentlyContinue | Where-Object { \$_.Path -and \$_.Path.StartsWith(\$dir) } | ForEach-Object { \$_.Kill(); \$_.WaitForExit(5000) }; \$exe = Join-Path \$dir '$DEV_EXE'; if (Test-Path \$exe) { Move-Item -Force \$exe (Join-Path \$dir ('multiprompt-dev.old-' + [DateTime]::UtcNow.Ticks + '.exe')) }; Move-Item (Join-Path \$dir 'multiprompt-dev.new.exe') \$exe; Get-ChildItem \$dir -Filter 'multiprompt-dev.old-*.exe' | Remove-Item -Force -ErrorAction SilentlyContinue; 'installed-sha=' + (Get-FileHash \$exe -Algorithm SHA256).Hash.ToLower()" 60)
    echo "$swapped"
    grep -q "installed-sha=$sha" <<<"$swapped" || { echo "laptop exe does not match run $run" >&2; exit 1; }
    rm -rf "$dir"
    echo "installed run $run"
}

place_window() {
    local dir
    dir=$(dev_dir)
    lh_shell "\$dir = '$dir'; \$exe = Join-Path \$dir '$DEV_EXE'; if (-not (Get-Process -Name 'multiprompt-dev' -ErrorAction SilentlyContinue)) { Start-Process -FilePath \$exe -WorkingDirectory \$dir }; Start-Sleep -Seconds 3; 'started'" 60
    local pid h
    pid=$(hc "(Get-Process -Name 'multiprompt-dev' -ErrorAction SilentlyContinue | Select-Object -First 1).Id" 20 | tr -d '\r\n')
    if [[ -z $pid ]]; then echo 'dev-not-running' >&2; return 1; fi
    local place_cs='using System; using System.Text; using System.Runtime.InteropServices; public class MpPlace { public delegate bool Proc(IntPtr h, IntPtr l); [DllImport("user32.dll")] public static extern bool EnumWindows(Proc p, IntPtr l); [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid); [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n); [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h); [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r); [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f); public struct RECT { public int Left, Top, Right, Bottom; } public static IntPtr Found = IntPtr.Zero; public static string Do(uint want) { EnumWindows((h, l) => { uint pid; GetWindowThreadProcessId(h, out pid); var c = new StringBuilder(64); GetClassName(h, c, 64); if (pid == want && IsWindowVisible(h) && c.ToString() == "ZigShell") { Found = h; return false; } return true; }, IntPtr.Zero); if (Found == IntPtr.Zero) return "window-missing"; SetWindowPos(Found, IntPtr.Zero, -2560, -493, 2048, 1280, 0x0040); RECT r; GetWindowRect(Found, out r); return "placed " + Found + " rect=" + r.Left + "," + r.Top + "," + (r.Right - r.Left) + "x" + (r.Bottom - r.Top); } }'
    hc "\$d = '$place_cs'; Add-Type -TypeDefinition \$d; [MpPlace]::Do($pid)" 45 | tail -1
}

shot() {
    local name="${1:-dev-window}"
    local out
    out=$(lh_shell "\$d = @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
public class MpShot {
    public delegate bool Proc(IntPtr h, IntPtr l);
    [DllImport(\"user32.dll\")] public static extern bool EnumWindows(Proc p, IntPtr l);
    [DllImport(\"user32.dll\")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport(\"user32.dll\")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport(\"user32.dll\")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport(\"user32.dll\")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    public struct RECT { public int Left, Top, Right, Bottom; }
    public static string Save(string path, uint want) {
        var h = IntPtr.Zero;
        EnumWindows((w, l) => { uint pid; GetWindowThreadProcessId(w, out pid); if (pid == want && IsWindowVisible(w)) { h = w; return false; } return true; }, IntPtr.Zero);
        if (h == IntPtr.Zero) return \"window-missing\";
        RECT r; if (!GetWindowRect(h, out r)) return \"no-rect\";
        var bmp = new Bitmap(r.Right - r.Left, r.Bottom - r.Top);
        using (var g = Graphics.FromImage(bmp)) { var hdc = g.GetHdc(); PrintWindow(h, hdc, 0); g.ReleaseHdc(hdc); }
        bmp.Save(path, System.Drawing.Imaging.ImageFormat.Png);
        return \"saved \" + path;
    }
}
'@; Add-Type -TypeDefinition \$d -ReferencedAssemblies System.Drawing; \$p = (Get-Process -Name 'multiprompt-dev' -ErrorAction SilentlyContinue | Select-Object -First 1).Id; if (-not \$p) { 'dev-not-running' } else { [MpShot]::Save(\"\$env:TEMP\\$name.png\", [uint32]\$p) }" 45)
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
