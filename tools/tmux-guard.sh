#!/usr/bin/env bash

set -u

readonly real_tmux=/usr/bin/tmux
kill_server=false
explicit_socket=false
expect_socket_value=false

for arg in "$@"; do
    if $expect_socket_value; then
        explicit_socket=true
        expect_socket_value=false
        continue
    fi

    case "$arg" in
        -L|-S)
            expect_socket_value=true
            ;;
        -L?*|-S?*)
            explicit_socket=true
            ;;
        kill-server|kill-ser*)
            kill_server=true
            ;;
    esac
done

if $kill_server && [[ ${MULTIPROMPT_ALLOW_TMUX_KILL_SERVER:-} != 1 ]]; then
    if [[ -n ${TMUX:-} || $explicit_socket == false ]]; then
        cat >&2 <<'EOF'
BLOCKED: unsafe tmux kill-server

This command can terminate every multiprompt session on the VPS.

For an isolated test server, unset inherited TMUX and use an explicit socket:
  socket="mp-test-$$"
  env -u TMUX tmux -L "$socket" new-session -d -s test
  env -u TMUX tmux -L "$socket" kill-server

For an intentional production shutdown only:
  MULTIPROMPT_ALLOW_TMUX_KILL_SERVER=1 tmux kill-server
EOF
        exit 64
    fi
fi

exec "$real_tmux" "$@"
