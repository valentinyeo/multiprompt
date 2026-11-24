#!/usr/bin/env bash
set -euo pipefail
repo=$1
install -m 755 "$repo/tools/verify-server-chat/provider.py" /usr/local/bin/claude
state=/home/mpverify/.local/state/multiprompt
install -d -m 700 -o mpverify -g mpverify "$state"
printf '1\n' | install -m 600 -o mpverify -g mpverify /dev/stdin "$state/relay-v1"
