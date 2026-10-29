#!/usr/bin/env bash
set -euo pipefail
host=${1:?exact desktop SSH host name required}
[[ $host =~ ^[a-zA-Z0-9_.-]+$ ]] || exit 64
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
install -d "$HOME/.local/share/multiprompt-owner-browser" "$HOME/.config/multiprompt" "$HOME/.config/systemd/user"
for file in user_browser.py mp_notify_relay.py; do
  install -m 644 "$root/agent-notifications/$file" "$HOME/.local/share/multiprompt-owner-browser/$file"
done
install -m 644 "$root/agent-notifications/mp-owner-browser.service" "$HOME/.config/systemd/user/mp-owner-browser.service"
printf 'MP_BROWSER_HOST=%s\n' "$host" > "$HOME/.config/multiprompt/owner-browser.env"
systemctl --user daemon-reload
systemctl --user enable mp-owner-browser.service
systemctl --user restart mp-owner-browser.service
printf 'Scoped owner browser service installed\n'
