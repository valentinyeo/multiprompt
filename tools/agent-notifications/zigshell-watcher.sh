#!/bin/bash

set -uo pipefail

NOTIFY_PORT=19548
POLL_INTERVAL=3
IDLE_THRESHOLD=10
ACTIVE_RESEND=15
DEBOUNCE_POLLS=2
AGENT_RECHECK=60
TITLE_ENABLED=1
AGENT_REBROADCAST=120
LOG_FILE="${HOME}/.local/share/zigshell-watcher.log"
LOG_MAX=500

mkdir -p "$(dirname "$LOG_FILE")"
if [[ -f "$LOG_FILE" ]]; then
    lc=$(wc -l < "$LOG_FILE")
    if (( lc > LOG_MAX )); then
        tail -n $(( LOG_MAX / 2 )) "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
fi

log() { printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >> "$LOG_FILE" 2>/dev/null || true; }

notify() {
    local msg="$1"
    timeout 1 bash -c 'printf "%s" "$1" >/dev/tcp/localhost/'"$NOTIFY_PORT" _ "$msg" 2>/dev/null || true
}

MARKER_MAX_AGE=604800
marker_fresh() {
    local safe="${1//\//_}"
    local f="/tmp/zigshell-semantic-$safe" m marker_agent mode
    [[ -f "$f" ]] || return 1
    read -r marker_agent mode < "$f" || true
    if [[ -n "$marker_agent" ]]; then
        [[ "$marker_agent" == "${session_agent[$1]:-none}" ]] || return 1
    else
        [[ "${session_agent[$1]:-none}" == "claude" || "${session_agent[$1]:-none}" == "codex" ]] || return 1
    fi
    m=$(stat -c %Y "$f" 2>/dev/null) || return 1
    (( $(date +%s) - m < MARKER_MAX_AGE ))
}

full_hook_fresh() {
    marker_fresh "$1" || return 1
    local safe="${1//\//_}" agent mode
    read -r agent mode < "/tmp/zigshell-semantic-$safe" || true
    [[ "$mode" == "full" ]]
}

semantic_title() {
    local s="$1" t="$2"
    case "$t" in
        "✳ "*) t="${t#✳ }" ;;
        "✳"*)  t="${t#✳}" ;;
        *) echo ""; return ;;
    esac
    t="${t#"${t%%[![:space:]]*}"}"; t="${t%"${t##*[![:space:]]}"}"
    [[ -z "$t" || "$t" == "Claude Code" || "$t" == "$s" ]] && { echo ""; return; }
    t=$(printf '%s' "$t" | tr -cd '\40-\176')
    t="${t#"${t%%[![:space:]]*}"}"; t="${t%"${t##*[![:space:]]}"}"
    [[ -z "$t" ]] && { echo ""; return; }
    printf '%.80s' "$t"
}

agent_from_argv() {
    local arg
    for arg in "$@"; do
        [[ "$arg" == -* ]] && continue
        case "$arg" in
            */cursor-agent/versions/*/index.js) echo cursor; return ;;
            */pi-coding-agent/*/cli.js) echo pi; return ;;
            */@openai/codex/*/codex.js) echo codex; return ;;
            */node|*/bun|*/agent|node|bun|agent) continue ;;
        esac
        break
    done
    echo none
}

detect_agent() {
    local session="$1" pane_cmd pane_pid
    pane_cmd=$(tmux display-message -p -t "$session" '#{pane_current_command}' 2>/dev/null) || { echo none; return; }
    case "$pane_cmd" in
        claude|codex|pi|hax|grok) echo "$pane_cmd"; return ;;
    esac
    pane_pid=$(tmux display-message -p -t "$session" '#{pane_pid}' 2>/dev/null) || { echo none; return; }
    local all_pids="$pane_pid" level_pids="$pane_pid" depth new_pids p kids
    for depth in 1 2 3; do
        new_pids=""
        for p in $level_pids; do
            kids=$(pgrep -P "$p" 2>/dev/null | tr '\n' ' ') || continue
            new_pids="$new_pids $kids"
        done
        [[ -z "${new_pids// /}" ]] && break
        all_pids="$all_pids $new_pids"
        level_pids="$new_pids"
    done
    local pid comm found
    local -a args
    for pid in $all_pids; do
        comm=$(cat "/proc/$pid/comm" 2>/dev/null) || continue
        case "$comm" in
            claude|codex|pi|hax|grok) echo "$comm"; return ;;
        esac
        args=()
        mapfile -d '' -t args < "/proc/$pid/cmdline" 2>/dev/null || continue
        found=$(agent_from_argv "${args[@]}")
        [[ "$found" != none ]] && { echo "$found"; return; }
    done
    echo none
}

declare -A prev_hash=()
declare -A change_streak=()
declare -A state=()
declare -A last_change=()
declare -A last_active_sent=()
declare -A session_agent=()
declare -A last_agent_check=()
declare -A seen=()
declare -A last_title=()
last_rebroadcast=$(date +%s)

log "started pid=$$ port=$NOTIFY_PORT signal=content-hash debounce=${DEBOUNCE_POLLS}"

while true; do
    now=$(date +%s)
    seen=()

    if ! sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null); then
        prev_hash=(); change_streak=(); state=(); last_change=()
        last_active_sent=(); session_agent=(); last_agent_check=(); last_title=()
        sleep "$POLL_INTERVAL"
        continue
    fi

    while IFS= read -r sname; do
        [[ -z "$sname" ]] && continue
        seen["$sname"]=1

        hash=$(tmux capture-pane -p -t "$sname" 2>/dev/null | md5sum | cut -d' ' -f1) || continue
        [[ -z "$hash" ]] && continue

        ptitle=$(tmux display-message -p -t "$sname" '#{pane_title}' 2>/dev/null || true)
        sem=$(semantic_title "$sname" "$ptitle")
        if [[ -n "$sem" && "$sem" != "${last_title[$sname]:-}" ]]; then
            last_title["$sname"]="$sem"
            (( TITLE_ENABLED )) && notify "TITLE:${sname}:${sem}"
            log "TITLE:${sname}:${sem}"
        fi


        if [[ -z "${prev_hash[$sname]:-}" ]]; then
            prev_hash["$sname"]="$hash"
            change_streak["$sname"]=0
            state["$sname"]="idle"
            last_change["$sname"]=0
            last_active_sent["$sname"]=0
            last_agent_check["$sname"]=0

            agent=$(detect_agent "$sname")
            session_agent["$sname"]="$agent"
            last_agent_check["$sname"]="$now"
            if [[ "$agent" != "none" ]]; then
                notify "AGENT:${sname}:${agent}"
                log "AGENT:${sname}:${agent} new-session"
            fi
            continue
        fi

        changed=0
        [[ "$hash" != "${prev_hash[$sname]}" ]] && changed=1
        prev_hash["$sname"]="$hash"

        cur_state="${state[$sname]:-idle}"
        last_sent="${last_active_sent[$sname]:-0}"

        if [[ "$cur_state" == "idle" ]]; then
            if (( changed )); then
                streak=$(( ${change_streak[$sname]:-0} + 1 ))
                change_streak["$sname"]="$streak"
                if (( streak >= DEBOUNCE_POLLS )); then
                    state["$sname"]="active"
                    last_change["$sname"]="$now"
                    kind="${session_agent[$sname]:-none}"
                    if [[ "$kind" != "claude" ]]; then
                        fresh=$(detect_agent "$sname")
                        if [[ "$fresh" != "$kind" ]]; then
                            session_agent["$sname"]="$fresh"
                            last_agent_check["$sname"]="$now"
                            if [[ "$fresh" != "none" ]]; then
                                notify "AGENT:${sname}:${fresh}"
                                log "AGENT:${sname}:${fresh} (transition recheck; was ${kind})"
                            fi
                            kind="$fresh"
                        fi
                    fi
                    if full_hook_fresh "$sname"; then
                        :
                    else
                        if [[ "$kind" == "claude" || "$kind" == "codex" ]] && ! marker_fresh "$sname"; then
                            log "HEURISTIC (no marker):${sname}"
                        fi
                        if (( now - last_sent >= ACTIVE_RESEND )); then
                            notify "ACTIVE:${sname}"
                            last_active_sent["$sname"]="$now"
                            log "ACTIVE:${sname}"
                        fi
                    fi
                fi
            else
                change_streak["$sname"]=0
            fi
        else
            if (( changed )); then
                last_change["$sname"]="$now"
                k="${session_agent[$sname]:-none}"
                if (( now - last_sent >= ACTIVE_RESEND )); then
                    if ! full_hook_fresh "$sname"; then
                        notify "ACTIVE:${sname}"
                        last_active_sent["$sname"]="$now"
                        log "ACTIVE:${sname}"
                    fi
                fi
            else
                quiet=$(( now - ${last_change[$sname]:-$now} ))
                if (( quiet >= IDLE_THRESHOLD )); then
                    state["$sname"]="idle"
                    change_streak["$sname"]=0
                    last_change["$sname"]=0
                    k="${session_agent[$sname]:-none}"
                    if [[ "$k" == "claude" ]] && marker_fresh "$sname"; then
                        log "SUPPRESS-DONE:${sname} (claude; hook owns)"
                    elif [[ "$k" != "none" ]] && marker_fresh "$sname"; then
                        log "SUPPRESS-DONE:${sname} (codex; notify owns)"
                    else
                        notify "DONE:${sname}"
                        log "DONE:${sname} (quiet ${quiet}s)"
                    fi
                fi
            fi
        fi

        lc="${last_agent_check[$sname]:-0}"
        if (( now - lc >= AGENT_RECHECK )); then
            new_agent=$(detect_agent "$sname")
            last_agent_check["$sname"]="$now"
            old_agent="${session_agent[$sname]:-none}"
            if [[ "$new_agent" != "$old_agent" ]]; then
                session_agent["$sname"]="$new_agent"
                if [[ "$new_agent" != "none" ]]; then
                    notify "AGENT:${sname}:${new_agent}"
                    log "AGENT:${sname}:${new_agent} (was ${old_agent})"
                fi
            fi
        fi

    done <<< "$sessions"

    for sname in "${!state[@]}"; do
        if [[ -z "${seen[$sname]:-}" ]]; then
            unset "prev_hash[$sname]" "change_streak[$sname]" "state[$sname]" \
                  "last_change[$sname]" "last_active_sent[$sname]" \
                  "session_agent[$sname]" "last_agent_check[$sname]" \
                  "last_title[$sname]"
            log "DROP:${sname}"
        fi
    done

    if (( now - last_rebroadcast >= AGENT_REBROADCAST )); then
        last_rebroadcast="$now"
        rb_count=0
        for sname in "${!session_agent[@]}"; do
            kind="${session_agent[$sname]:-none}"
            [[ "$kind" == "none" ]] && continue
            notify "AGENT:${sname}:${kind}"
            rb_count=$(( rb_count + 1 ))
        done
        for sname in "${!last_title[@]}"; do
            t="${last_title[$sname]:-}"
            [[ -n "$t" && "$TITLE_ENABLED" == "1" ]] && notify "TITLE:${sname}:${t}"
        done
        log "REBROADCAST ${rb_count} agents + ${#last_title[@]} titles"
    fi

    sleep "$POLL_INTERVAL"
done
