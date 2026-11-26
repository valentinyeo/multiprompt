set -euo pipefail
action=$1
here=$(cd "$(dirname "$0")" && pwd)
target=/usr/local/bin/python3
config=/tmp/mp-room-drop-receipt.json
state=/tmp/mp-room-drop-receipt-state.json
log=/tmp/mp-room-drop-receipt-log.jsonl
case "$action" in
  install)
    install -m 755 "$here/rooms-drop-receipt.py" "$target"
    rm -f "$config" "$state" "$log"
    touch "$config" "$state" "$log"
    chmod 666 "$config" "$state" "$log"
    ;;
  arm)
    case "$2" in
      ''|*[!A-Za-z0-9_-]*) echo 'arm needs a plain marker' >&2; exit 2 ;;
    esac
    printf '{"text":"%s"}' "$2" > "$config"
    rm -f "$state"
    : > "$log"
    ;;
  read)
    cat "$state"
    ;;
  log)
    cat "$log"
    ;;
  remove)
    rm -f "$target" "$config" "$state" "$log"
    ;;
  *)
    exit 2
    ;;
esac
