#!/usr/bin/env bash
set -euo pipefail
: "${CLOUDFLARE_ACCOUNT_ID:?required}" "${SHIP_SESSION_NAME:?required}" "${CRASH_BOARD_COMMAND:?required}" "${CRASH_GH_COMMAND:?required}"
"$CRASH_BOARD_COMMAND" context --json >/dev/null
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
repo=${CRASH_REPORT_TICKETS_REPO:-$HOME/projects/multiprompt-crash-report-tickets}
if [ -d "$repo/.git" ]; then
  git -C "$repo" fetch --depth 1 origin master
  git -C "$repo" checkout -q --detach origin/master
elif [ -e "$repo" ]; then
  echo "refusing to install into existing $repo: it is not a git clone" >&2
  exit 1
else
  install -d "$(dirname -- "$repo")"
  git clone --depth 1 https://github.com/valentinyeo/multiprompt.git "$repo"
fi
install -d "$HOME/.config/multiprompt" "$HOME/.config/systemd/user"
rm -f "$HOME/.config/systemd/user/crash-report-tickets.service" "$HOME/.config/systemd/user/crash-report-tickets.timer"
sed "s|%h/projects/multiprompt-crash-report-tickets|$repo|g" "$root/service/crash-report-tickets.service" > "$HOME/.config/systemd/user/crash-report-tickets.service"
install -m 644 "$root/service/crash-report-tickets.timer" "$HOME/.config/systemd/user/crash-report-tickets.timer"
python3 - <<'PY'
import json
import os
from pathlib import Path
path = Path.home() / '.config/multiprompt/crash-report-tickets.env'
path.touch(mode=0o600, exist_ok=True)
path.chmod(0o600)
path.write_text('\n'.join(name + '=' + json.dumps(os.environ[name]) for name in ('CLOUDFLARE_ACCOUNT_ID', 'CEO_AGENT', 'SHIP_SESSION_NAME', 'CRASH_BOARD_COMMAND', 'CRASH_GH_COMMAND', 'CRASH_CI_RUN') if os.environ.get(name)) + '\n')
PY
systemctl --user daemon-reload
systemctl --user enable --now crash-report-tickets.timer
printf 'Automatic desktop report triage installed from %s\n' "$repo"
