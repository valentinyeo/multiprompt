#!/bin/bash
set -u
s=$1; agent=$2; max=${3:-260}
[[ $s =~ ^mp-ac-test-[A-Za-z0-9_-]+$ ]] || { echo "scratch session required" >&2; exit 2; }
case "$agent" in
  claude) sel=$'\x1b\\[38;5;153m' ;;
  codex)  sel=$'\x1b\\[1m\x1b\\[38;5;6m/' ;;
  *) echo "agent must be claude or codex" >&2; exit 2 ;;
esac
tmux send-keys -t "$s" C-e; for _ in 1 2 3 4; do tmux send-keys -t "$s" C-k C-u; done
sleep 0.3
tmux send-keys -t "$s" -l "/"; sleep 0.5
first=""
for i in $(seq 1 "$max"); do
  row=$(tmux capture-pane -p -e -t "$s" | grep -- "$sel" | head -1 | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^ *//')
  name=${row%% *}
  [[ -z "$first" ]] && first=$name
  [[ $i -gt 1 && "$name" == "$first" ]] && break
  printf '%s\n' "$row"
  tmux send-keys -t "$s" Down; sleep 0.03
done
tmux send-keys -t "$s" C-e; for _ in 1 2 3 4; do tmux send-keys -t "$s" C-k C-u; done
