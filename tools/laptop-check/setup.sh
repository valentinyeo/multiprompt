#!/usr/bin/env bash
set -euo pipefail
unit=multiprompt-laptop-check
repo=${LAPTOP_CHECK_REPO:-$HOME/projects/multiprompt-laptop-check}
host=${LAPTOP_CHECK_HOST:-laptop2}
agent=${LAPTOP_CHECK_AGENT:-RUNNER 7}

command -v lh >/dev/null || { echo 'lh is required: the routine reaches the laptop through it' >&2; exit 1; }
command -v gh >/dev/null || { echo 'gh is required: the routine reads released tags' >&2; exit 1; }
command -v node >/dev/null || { echo 'node is required: the routine runs on it' >&2; exit 1; }

if [ -d "$repo/.git" ]; then
  git -C "$repo" fetch --depth 1 origin master
  git -C "$repo" checkout -q --detach origin/master
elif [ -e "$repo" ]; then
  echo "refusing to install into existing $repo: it is not a git clone" >&2
  exit 1
else
  git clone --depth 1 https://github.com/valentinyeo/multiprompt.git "$repo"
fi

mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/$unit.service" <<UNIT
[Unit]
Description=Multiprompt release check on the test laptop

[Service]
Type=oneshot
Environment=PATH=$PATH
Environment="LAPTOP_CHECK_AGENT=$agent"
ExecStartPre=-/usr/bin/git -C $repo fetch --depth 1 origin master
ExecStartPre=-/usr/bin/git -C $repo checkout -q --detach origin/master
ExecStart=/usr/bin/env node $repo/tools/laptop-check/run.mjs --host $host
UNIT
cat > "$HOME/.config/systemd/user/$unit.timer" <<UNIT
[Unit]
Description=Check each Multiprompt release on the test laptop

[Timer]
OnBootSec=2min
OnUnitActiveSec=10min
Unit=$unit.service

[Install]
WantedBy=timers.target
UNIT
systemctl --user daemon-reload
systemctl --user enable --now "$unit.timer"

if ! curl -sf -m 5 http://127.0.0.1:8766/machines >/dev/null; then
  echo "warning: local-helper does not answer on 127.0.0.1:8766, so $host reads as offline until it does" >&2
fi
if ! lh machines 2>/dev/null | grep -q "$host"; then
  echo "warning: $host is not a known machine name for lh" >&2
fi

echo "installed $unit.timer for $host; first run: systemctl --user start $unit.service"
