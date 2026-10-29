#!/usr/bin/env bash
set -euo pipefail
: "${CLOUDFLARE_ACCOUNT_ID:?required}" "${CEO_AGENT:?required}" "${CRASH_BOARD_COMMAND:?required}" "${CRASH_GH_COMMAND:?required}"
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
install -d "$HOME/.local/share/multiprompt-crash-tickets" "$HOME/.config/multiprompt" "$HOME/.config/systemd/user"
for file in crash-report-tickets.py crash-reports.py; do
  install -m 644 "$root/service/$file" "$HOME/.local/share/multiprompt-crash-tickets/$file"
done
install -m 644 "$root/service/crash-report-tickets.service" "$HOME/.config/systemd/user/"
install -m 644 "$root/service/crash-report-tickets.timer" "$HOME/.config/systemd/user/"
python3 - <<'PY'
import json
import os
from pathlib import Path
path = Path.home() / '.config/multiprompt/crash-report-tickets.env'
path.touch(mode=0o600, exist_ok=True)
path.chmod(0o600)
path.write_text('\n'.join(name + '=' + json.dumps(os.environ[name]) for name in ('CLOUDFLARE_ACCOUNT_ID', 'CEO_AGENT', 'CRASH_BOARD_COMMAND', 'CRASH_GH_COMMAND', 'CRASH_CI_RUN') if os.environ.get(name)) + '\n')
PY
systemctl --user daemon-reload
systemctl --user enable --now crash-report-tickets.timer
printf 'Automatic desktop report triage installed\n'
