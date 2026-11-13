#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
share="${XDG_DATA_HOME:-$HOME/.local/share}/multiprompt-talk"
bin="${MP_TALK_BIN:-$HOME/.local/bin}"
mkdir -p "$share" "$bin"
cp "$here/src/mp_send.py" "$here/src/mp_sessions.py" "$here/src/mp_helper.py" "$share/"
for pair in mp-send:mp_send.py mp-sessions:mp_sessions.py mp-helper:mp_helper.py; do
  name=${pair%%:*}
  file=${pair#*:}
  printf '#!/bin/sh\nexec python3 "%s/%s" "$@"\n' "$share" "$file" > "$bin/$name"
  chmod 755 "$bin/$name"
done
echo "installed mp-send, mp-sessions and mp-helper into $bin"
