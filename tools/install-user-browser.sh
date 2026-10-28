#!/usr/bin/env bash
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
endpoint_dir="/tmp/mp-notify-$(id -u)"
if [ -e "$endpoint_dir" ] && { [ -L "$endpoint_dir" ] || [ ! -d "$endpoint_dir" ] || [ "$(stat -c %u "$endpoint_dir")" != "$(id -u)" ]; }; then
  printf '%s\n' 'Browser tunnel directory belongs to another user.' >&2
  exit 1
fi
mkdir -p -m 700 "$endpoint_dir"
chmod 700 "$endpoint_dir"
mkdir -p "$HOME/.local/bin" "$HOME/.local/state/multiprompt"
install -m 755 "$source_dir/vps-multiprompt-browser.sh" "$HOME/.local/bin/multiprompt-browser"
install -m 755 "$source_dir/vps-zsb.sh" "$HOME/.local/bin/zsb"
printf '1\n' > "$HOME/.local/state/multiprompt/browser-v1"
printf '%s\n' 'Own browser access installed; reconnect this user in Multiprompt.'
