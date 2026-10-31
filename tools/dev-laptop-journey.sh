#!/usr/bin/env bash
set -u

readonly DEV_NAME='multiprompt-dev'
evidence="${DEV_RIG_EVIDENCE:-./dev-rig-evidence}"

hc() { lh shell "$1" --timeout "${2:-30}"; }

dev_pid() {
    hc "(Get-Process -Name '$DEV_NAME' -ErrorAction SilentlyContinue | Select-Object -First 1).Id" 20 | tr -d '\r\n'
}

dev_hwnd() {
    hc "\$d = @'
using System; using System.Text; using System.Runtime.InteropServices;
public class MpF {
  public delegate bool Proc(IntPtr h, IntPtr l);
  [DllImport(\"user32.dll\")] public static extern bool EnumWindows(Proc p, IntPtr l);
  [DllImport(\"user32.dll\")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport(\"user32.dll\")] public static extern bool IsWindowVisible(IntPtr h);
  public static IntPtr Found = IntPtr.Zero;
  public static string Do(uint want) {
    EnumWindows((h, l) => { uint pid; GetWindowThreadProcessId(h, out pid); if (pid == want && IsWindowVisible(h)) { Found = h; return false; } return true; }, IntPtr.Zero);
    return Found.ToString();
  }
}
'@; Add-Type -TypeDefinition \$d; \$p = Get-Process -Name '$DEV_NAME' -ErrorAction SilentlyContinue | Select-Object -First 1; if (-not \$p) { '0' } else { [MpF]::Do(\$p.Id) }" 30 | tr -d '\r\n'
}

foreground_is_dev() {
    local pid answer
    pid=$(dev_pid)
    [[ -z $pid ]] && return 1
    answer=$(hc "\$d = @'
using System; using System.Runtime.InteropServices;
public class MpG {
  [DllImport(\"user32.dll\")] public static extern IntPtr GetForegroundWindow();
  [DllImport(\"user32.dll\")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
}
'@; Add-Type -TypeDefinition \$d; \$p = 0; [MpG]::GetWindowThreadProcessId([MpG]::GetForegroundWindow(), [ref]\$p) | Out-Null; \$p" 20 | tr -d '\r\n')
    [[ $answer == "$pid" ]]
}

guard() {
    if ! foreground_is_dev; then
        echo "ABORT: the dev window does not own the foreground, nothing was typed" >&2
        return 1
    fi
}

send_keys() {
    guard || return 1
    hc "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('$1'); 'ok'" 20 >/dev/null
}

type_text() {
    guard || return 1
    local escaped
    escaped=$(printf '%s' "$1" | sed 's/[+^%~(){}[\]]/{\0}/g')
    hc "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('$escaped'); 'ok'" 30 >/dev/null
}

readonly FOREGROUND_CS="using System; using System.Runtime.InteropServices; public class MpFg {
  [DllImport(\"user32.dll\")] static extern IntPtr GetForegroundWindow();
  [DllImport(\"user32.dll\")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport(\"user32.dll\")] static extern uint GetCurrentThreadId();
  [DllImport(\"user32.dll\", SetLastError=true)] static extern bool AttachThreadInput(uint from, uint to, bool attach);
  [DllImport(\"user32.dll\")] static extern bool BringWindowToTop(IntPtr h);
  [DllImport(\"user32.dll\")] static extern IntPtr SetForegroundWindow(IntPtr h);
  [DllImport(\"user32.dll\")] static extern bool AllowSetForegroundWindow(uint pid);
  [DllImport(\"user32.dll\")] static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport(\"user32.dll\")] static extern bool ShowWindow(IntPtr h, int c);
  public static uint ForegroundPid() { uint p; GetWindowThreadProcessId(GetForegroundWindow(), out p); return p; }
  public static void BringToForeground(IntPtr hwnd) {
    uint pid; uint foregroundThread = GetWindowThreadProcessId(GetForegroundWindow(), out pid);
    uint currentThread = GetCurrentThreadId(); uint targetPid; uint targetThread = GetWindowThreadProcessId(hwnd, out targetPid);
    bool attached = foregroundThread != 0 && foregroundThread != currentThread && AttachThreadInput(currentThread, foregroundThread, true);
    bool attachedTarget = targetThread != 0 && targetThread != currentThread && targetThread != foregroundThread && AttachThreadInput(currentThread, targetThread, true);
    keybd_event(0x12, 0, 0, UIntPtr.Zero);
    try { AllowSetForegroundWindow(targetPid); BringWindowToTop(hwnd); SetForegroundWindow(hwnd); }
    finally { keybd_event(0x12, 0, 2, UIntPtr.Zero); if (attachedTarget) AttachThreadInput(currentThread, targetThread, false); if (attached) AttachThreadInput(currentThread, foregroundThread, false); }
  }
}"

focus_dev() {
    local h
    h=$(dev_hwnd)
    [[ -z $h || $h == 0 ]] && { echo "dev window missing" >&2; return 1; }
    hc "\$d = @'
$FOREGROUND_CS
'@; Add-Type -TypeDefinition \$d; \$h = [IntPtr]$h; [MpFg]::ShowWindow(\$h, 3) | Out-Null; [MpFg]::BringToForeground(\$h); Start-Sleep -Milliseconds 400; 'fg=' + [MpFg]::ForegroundPid()" 45 | tail -1
}

shot() {
    local name="$1" h offset=0 chunk
    h=$(dev_hwnd)
    mkdir -p "$evidence"
    local png="$evidence/$name.png"
    hc "\$d = @'
using System; using System.Drawing; using System.Runtime.InteropServices;
public class MpP {
  [DllImport(\"user32.dll\")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport(\"user32.dll\")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  public struct RECT { public int Left, Top, Right, Bottom; }
  public static string Go(IntPtr h, string path) {
    RECT r; if (!GetWindowRect(h, out r)) return \"no-rect\";
    var bmp = new Bitmap(r.Right - r.Left, r.Bottom - r.Top);
    using (var g = Graphics.FromImage(bmp)) { var dc = g.GetHdc(); PrintWindow(h, dc, 0); g.ReleaseHdc(dc); }
    bmp.Save(path, System.Drawing.Imaging.ImageFormat.Png);
    return \"ok\";
  }
}
'@; Add-Type -TypeDefinition \$d; [MpP]::Go([IntPtr]$h, \"\$env:TEMP\\$name.png\")" 60 >/dev/null
    : > "$png.b64"
    while :; do
        chunk=$(hc "\$p = Join-Path \$env:TEMP '$name.png'; if (-not (Test-Path \$p)) { '' } else { \$b = [IO.File]::ReadAllBytes(\$p); \$take = [Math]::Min(150000, [Math]::Max(0, \$b.Length - $offset)); if (\$take -le 0) { '' } else { [Convert]::ToBase64String(\$b, $offset, \$take) } }" 60 | tr -d '\r\n')
        [[ -z $chunk ]] && break
        printf '%s' "$chunk" >> "$png.b64"
        offset=$((offset + 150000))
    done
    if [[ -s $png.b64 ]]; then
        base64 -d "$png.b64" > "$png" && rm -f "$png.b64"
        echo "screenshot: $png"
        sc2-upload "$png" 2>/dev/null | tail -1
    fi
}

server_transcripts() {
    find "$HOME/.claude/projects" -name '*.jsonl' -newermt '-90 seconds' 2>/dev/null | head -20
}

newest_transcript_since() {
    local since="$1"
    find "$HOME/.claude/projects" -name '*.jsonl' -newermt "@$since" 2>/dev/null | xargs -r ls -t 2>/dev/null | head -1
}

turns() {
    local path="$1"
    [[ -f $path ]] || { echo "0 0"; return; }
    python3 - "$path" <<'PY'
import json, sys
users = assistants = 0
last_assistant = ""
for line in open(sys.argv[1], errors="replace"):
    line = line.strip()
    if not line:
        continue
    try:
        row = json.loads(line)
    except ValueError:
        continue
    kind = row.get("type")
    content = (row.get("message") or {}).get("content")
    if kind == "user" and not row.get("isSidechain"):
        text = content if isinstance(content, str) else "".join(b.get("text", "") for b in content if isinstance(b, dict))
        if text.strip():
            users += 1
    elif kind == "assistant" and isinstance(content, list):
        text = "".join(b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text")
        if text.strip():
            assistants += 1
            last_assistant = text.strip()
print(users, assistants, last_assistant.replace("\n", " ")[:120])
PY
}

wait_turns() {
    local path="$1" want_users="$2" want_assistants="$3" timeout="${4:-90}"
    local waited=0 users assistants
    while (( waited < timeout )); do
        read -r users assistants _ <<<"$(turns "$path")"
        if (( users >= want_users && assistants >= want_assistants )); then
            return 0
        fi
        sleep 5
        waited=$((waited + 5))
    done
    return 1
}

case_result() {
    local name="$1" status="$2" detail="$3"
    printf '%s %s %s\n' "$status" "$name" "$detail" | tee -a "$evidence/stress.log"
}

new_chat() {
    focus_dev || return 1
    send_keys '^t' || return 1
    sleep 6
    guard || return 1
}

stress() {
    mkdir -p "$evidence"
    : > "$evidence/stress.log"
    local started sid transcript
    local fails=0

    started=$(date +%s)
    if ! new_chat; then case_result case1-first-message FAIL "no dev chat started"; return 1; fi
    type_text 'say ok'
    send_keys '{ENTER}'
    transcript=""
    local waited=0
    while (( waited < 60 )); do
        transcript=$(newest_transcript_since "$started")
        [[ -n $transcript ]] && break
        sleep 3
        waited=$((waited + 3))
    done
    if [[ -z $transcript ]]; then
        case_result case1-first-message FAIL "no transcript appeared"
        shot stress-case1-fail
        fails=$((fails + 1))
    elif wait_turns "$transcript" 1 1 90; then
        case_result case1-first-message PASS "reply: $(turns "$transcript" | cut -d' ' -f3-)"
    else
        case_result case1-first-message FAIL "no reply within 90s in $transcript"
        shot stress-case1-fail
        fails=$((fails + 1))
    fi

    local i users assistants
    for i in $(seq 1 10); do
        type_text "message $i please reply"
        send_keys '{ENTER}'
        if ! wait_turns "$transcript" $((i + 1)) $((i + 1)) 90; then
            case_result case2-ten-messages FAIL "stalled at message $i"
            shot "stress-case2-fail-$i"
            fails=$((fails + 1))
            break
        fi
    done
    read -r users assistants _ <<<"$(turns "$transcript")"
    if (( users >= 11 && assistants >= 11 )); then
        case_result case2-ten-messages PASS "users=$users assistants=$assistants"
    else
        case_result case2-ten-messages FAIL "users=$users assistants=$assistants"
        fails=$((fails + 1))
    fi

    local base_users=$users base_assistants=$assistants
    for i in 1 2 3; do
        type_text "burst $i"
        send_keys '{ENTER}'
        sleep 1
    done
    if wait_turns "$transcript" $((base_users + 3)) $((base_assistants + 3)) 120; then
        case_result case3-burst PASS "three burst messages delivered"
    else
        read -r users assistants _ <<<"$(turns "$transcript")"
        case_result case3-burst FAIL "users=$users assistants=$assistants after burst"
        shot stress-case3-fail
        fails=$((fails + 1))
    fi

    local long_text
    long_text=$(python3 -c "print('line one of a long message. ' * 120)")
    read -r users assistants _ <<<"$(turns "$transcript")"
    type_text "$long_text"
    send_keys '{ENTER}'
    if wait_turns "$transcript" $((users + 1)) $((assistants + 1)) 120; then
        case_result case4-long-message PASS "long message delivered"
    else
        case_result case4-long-message FAIL "long message did not complete"
        shot stress-case4-fail
        fails=$((fails + 1))
    fi

    read -r users assistants _ <<<"$(turns "$transcript")"
    focus_dev || true
    send_keys '^t'   # next tab
    sleep 3
    send_keys '^{t}' # back
    sleep 2
    if wait_turns "$transcript" $((users)) $((assistants)) 20; then
        case_result case6-tab-switch PASS "chat still loaded after switching tabs"
    else
        case_result case6-tab-switch FAIL "chat did not come back after tab switch"
        shot stress-case6-fail
        fails=$((fails + 1))
    fi

    focus_dev || true
    send_keys '%c'   # Alt+C toggles Chat View
    sleep 2
    send_keys '%c'
    sleep 2
    type_text 'after terminal view'
    send_keys '{ENTER}'
    if wait_turns "$transcript" $((users + 1)) $((assistants + 1)) 90; then
        case_result case7-terminal-view PASS "chat works after the terminal view"
    else
        case_result case7-terminal-view FAIL "no reply after the terminal view"
        shot stress-case7-fail
        fails=$((fails + 1))
    fi

    local pid
    pid=$(dev_pid)
    if [[ -n $pid ]]; then
        local children
        children=$(hc "Get-CimInstance Win32_Process | Where-Object { \$_.ParentProcessId -eq $pid -and \$_.Name -match '^(ssh|plink)' } | ForEach-Object { \$_.ProcessId }" 30 | tr -d '\r')
        for child in $children; do
            hc "Stop-Process -Id $child -Force; 'killed $child'" 20 >/dev/null
            break
        done
        read -r users assistants _ <<<"$(turns "$transcript")"
        type_text 'after reconnect'
        send_keys '{ENTER}'
        if wait_turns "$transcript" $((users + 1)) $((assistants + 1)) 150; then
            case_result case9-reconnect PASS "delivered after the ssh child was killed"
        else
            case_result case9-reconnect FAIL "message lost after killing the ssh child"
            shot stress-case9-fail
            fails=$((fails + 1))
        fi
    else
        case_result case9-reconnect FAIL "dev process vanished"
        fails=$((fails + 1))
    fi

    printf 'fails=%d\n' "$fails" | tee -a "$evidence/stress.log"
    (( fails == 0 ))
}

case "${1:-ctrl-t}" in
    stress) stress ;;
    ctrl-t)
        focus_dev || exit 1
        send_keys '^t'
        sleep 6
        type_text 'say ok'
        send_keys '{ENTER}'
        shot dev-ctrl-t
        ;;
    focus) focus_dev ;;
    shot) shot "${2:-dev-window}" ;;
    *) echo "unknown journey: $1" >&2; exit 2 ;;
esac
