#!/usr/bin/env bash
set -euo pipefail
stage=false
if [[ ${1:-} == --stage ]]; then stage=true; shift; fi
owner=${1:?owner user required}
name=${2:?session name required}
directory=${3:?absolute owner directory required}
[[ $owner =~ ^[a-z_][a-z0-9_-]*$ && $name =~ ^[a-zA-Z0-9_-]+$ && $directory == /* ]] || exit 64
start_env=${owner^^}_START_DIR
start_env=${start_env//-/_}
printf -v remote 'exec tmux new-session -A -s %q -c %q -e %q -e %q -e %q %q' \
    "$name" "$directory" "MULTIPROMPT_TAB=$name" "ZSB_SESSION=$name" "$start_env=$directory" 'exec bash -l'
printf -v command 'exec ssh -tt %q %q' "$owner@localhost" "$remote"
if ! tmux has-session -t "=$name" 2>/dev/null; then
    tmux new-session -d -s "$name" "$command"
fi
pane=$(tmux display-message -p -t "=$name" '#{pane_id}')
tmux set-option -p -t "$pane" @owner_user "$owner"
tmux set-option -p -t "$pane" @owner_session "$name"
tmux set-option -p -t "$pane" @owner_directory "$directory"
printf -v hook 'respawn-pane -t %q %q' "$pane" "$command"
tmux set-hook -p -t "$pane" 'pane-died[1125]' "$hook"
tmux set-option -p -t "$pane" remain-on-exit on
if [[ $(tmux display-message -p -t "$pane" '#{pane_dead}') == 1 ]]; then
    tmux respawn-pane -t "$pane" "$command"
fi
if ! $stage; then
    if [[ -n ${TMUX:-} ]]; then tmux switch-client -t "=$name"; else tmux attach -t "=$name"; fi
fi
