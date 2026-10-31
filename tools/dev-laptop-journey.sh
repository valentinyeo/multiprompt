#!/usr/bin/env bash
set -u

readonly DEV_CLASS='MultipromptDevWindow'

lh_shell() { lh shell "$1" --timeout "${2:-30}"; }

foreground_is_dev() {
    local answer
    answer=$(lh_shell "Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class MpFg {
    [DllImport(\"user32.dll\")] public static extern IntPtr GetForegroundWindow();
    [DllImport(\"user32.dll\")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
}
'@; \$h = [MpFg]::GetForegroundWindow(); \$b = New-Object Text.StringBuilder 256; [MpFg]::GetClassName(\$h, \$b, 256) | Out-Null; \$b.ToString()" 20 | tr -d '\r')
    [[ $answer == "$DEV_CLASS" ]]
}

send_keys() {
    if ! foreground_is_dev; then
        echo "abort: the dev window is not in front, refusing to type" >&2
        exit 3
    fi
    lh_shell "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('$1'); 'sent'" 20 >/dev/null
}

type_text() {
    if ! foreground_is_dev; then
        echo "abort: the dev window is not in front, refusing to type" >&2
        exit 3
    fi
    local escaped
    escaped=$(printf '%s' "$1" | sed 's/[+^%~(){}[\]]/{\0}/g')
    lh_shell "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('$escaped'); 'typed'" 20 >/dev/null
}

ctrl_t_journey() {
    local before after reply
    before=$(lh_shell "& tmux ls -F '#{session_name}' 2>\$null | Sort-Object" 20 | tr -d '\r')
    send_keys '^t'
    sleep 4
    type_text 'say ok'
    send_keys '{ENTER}'
    local waited=0
    while (( waited < 90 )); do
        sleep 5
        waited=$((waited + 5))
        after=$(lh_shell "& tmux ls -F '#{session_name}' 2>\$null | Sort-Object" 20 | tr -d '\r')
        local new_sessions
        new_sessions=$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | grep -c .)
        reply=$(lh_shell "Get-ChildItem \"\$env:USERPROFILE\\.claude\\projects\" -Recurse -Filter '*.jsonl' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Desc | Select-Object -First 1 | % { (Get-Content \$_.FullName -Tail 6) -join \"\`n\" }" 30 | tr -d '\r')
        if printf '%s' "$reply" | grep -qi 'ok'; then
            echo "journey ctrl-t: reply seen after ${waited}s"
            echo "new tmux sessions: ${new_sessions}"
            printf '%s\n' "$after" | grep -vFxf <(printf '%s\n' "$before") | sed 's/^/created: /'
            return 0
        fi
    done
    echo "journey ctrl-t: no reply within 90s" >&2
    return 1
}

case "${1:-ctrl-t}" in
    ctrl-t) ctrl_t_journey ;;
    *) echo "unknown journey: $1" >&2; exit 2 ;;
esac
