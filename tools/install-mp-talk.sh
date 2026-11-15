#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
share="${XDG_DATA_HOME:-$HOME/.local/share}/multiprompt-talk"
bin="${MP_TALK_BIN:-$HOME/.local/bin}"
mkdir -p "$share" "$bin"
cp "$here/src/mp_send.py" "$here/src/mp_sessions.py" "$here/src/mp_helper.py" "$here/src/mp_agent_sync.py" "$share/"
for pair in mp-send:mp_send.py mp-sessions:mp_sessions.py mp-helper:mp_helper.py mp-agent-sync:mp_agent_sync.py; do
  name=${pair%%:*}
  file=${pair#*:}
  printf '#!/bin/sh\nexec python3 "%s/%s" "$@"\n' "$share" "$file" > "$bin/$name"
  chmod 755 "$bin/$name"
done
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p "$unit_dir"
cp "$here/tools/mp-agent-sync.service" "$here/tools/mp-agent-sync.timer" "$unit_dir/"
real_home=$HOME
if command -v getent >/dev/null 2>&1; then
  real_home=$(getent passwd "$(id -u)" | awk -F: '{print $6}')
fi
if [ "$HOME" = "$real_home" ] && command -v systemctl >/dev/null 2>&1; then
  runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  if [ -S "$runtime/bus" ]; then
    XDG_RUNTIME_DIR="$runtime" systemctl --user daemon-reload
    XDG_RUNTIME_DIR="$runtime" systemctl --user enable --now mp-agent-sync.timer
  fi
fi
echo "installed mp-send, mp-sessions, mp-helper and mp-agent-sync into $bin"
