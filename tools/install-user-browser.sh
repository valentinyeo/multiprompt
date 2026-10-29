#!/usr/bin/env bash
set -euo pipefail
endpoint=${1:?owner browser socket path required}
[[ $endpoint == /tmp/mp-browser-*/control.sock ]] || exit 64
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
install -d "$HOME/.local/bin" "${XDG_CONFIG_HOME:-$HOME/.config}/multiprompt"
install -m 755 "$root/vps-multiprompt-browser.sh" "$HOME/.local/bin/multiprompt-browser"
ln -sfn multiprompt-browser "$HOME/.local/bin/zsb"
printf '%s\n' "$endpoint" > "${XDG_CONFIG_HOME:-$HOME/.config}/multiprompt/browser-socket"
printf 'Own browser access installed\n'
