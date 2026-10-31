#!/usr/bin/env bash
set -u

readonly DRIVER="$(dirname "$0")/dev-laptop-driver.ps1"

send_driver() {
    local action="$1" value="${2:-}"
    local payload
    payload=$(python3 - "$DRIVER" "$action" "$value" <<'PY'
import base64, sys
path, action, value = sys.argv[1], sys.argv[2], sys.argv[3]
body = open(path, encoding='utf-8').read()
args = "-Action '%s'" % action
if value != '':
    args += " -Value @'\n%s\n'@" % value
script = body.replace("param([string]$Action = 'rects', [string]$Value = '')", "param([string]$Action = 'rects', [string]$Value = '')", 1)
full = script + "\n# dispatched\n" + "& { " + args + " }\n"
sys.stdout.write(base64.b64encode(full.encode('utf-16-le')).decode())
PY
)
    lh shell "powershell -NoProfile -EncodedCommand $payload" --timeout 120
}

case "${1:-}" in
    rects|launch|place|focus|guard|shot|png|sshpids|killssh|stopdev) send_driver "$1" "${2:-}" ;;
    keys|type|clip|clipimg) send_driver "$1" "${2:-}" ;;
    *) echo "usage: $0 rects|launch|place|focus|guard|keys <spec>|type <text>|clip <text>|clipimg <path>|shot <name>|png <name>|sshpids|killssh|stopdev" >&2; exit 2 ;;
esac
