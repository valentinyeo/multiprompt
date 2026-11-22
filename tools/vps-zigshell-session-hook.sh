#!/usr/bin/env bash
set +e

input="$(cat 2>/dev/null)"
sid="$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
cwd="$(printf '%s' "$input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"

tmux_session=""
if [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
  tmux_session="$(tmux display-message -p '#S' 2>/dev/null || true)"
fi
[ -z "$tmux_session" ] && exit 0
[ -z "$sid" ] && exit 0

payload="SESSION:${tmux_session}:${sid}:${cwd}"
for port in 19548 19549 19550 19551 19552; do
  timeout 1 bash -c "printf '%s' \"$payload\" >/dev/tcp/127.0.0.1/$port" 2>/dev/null && break
done
exit 0
