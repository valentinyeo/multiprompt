#!/bin/bash

tmpr="$(mktemp 2>/dev/null || echo /tmp/zs_ram.$$)"
{
    tmux list-panes -a -F "P #{pane_pid} #{session_id}" 2>/dev/null
    ps -eo pid=,ppid=,rss=,args= 2>/dev/null | awk '{print "Q", $0}'
} | awk '
    $1 == "P" { sid[$2] = $3; next }              # pane_pid -> session_id
    $1 == "Q" {
        rss[$2] = $4; par[$2] = $3
        cmd = ""
        for (i = 5; i <= NF; i++) cmd = cmd (cmd == "" ? "" : " ") $i
        args[$2] = cmd
        next
    }
    END {
        for (pp in sid) ram[sid[pp]] += rss[pp]                       # pane pid
        for (pid in par) {
            pp = par[pid]
            if (pp in sid) {
                ram[sid[pp]] += rss[pid]
                if (args[pid] ~ /\/cursor-agent\/versions\/[^/]+\/index\.js/) agent[sid[pp]] = "cursor"
            }
        }
        for (s in ram) print s "|" int(ram[s] / 1024) "|" agent[s]
    }
' > "$tmpr"

declare -A RAM
declare -A AGENT
while IFS='|' read -r s m a; do
    RAM["$s"]="$m"
    AGENT["$s"]="$a"
done < "$tmpr"
rm -f "$tmpr"

tmux list-sessions -F "#{session_id}|#{session_name}|#{session_activity}|#{session_path}|#{pane_current_command}|#{pane_title}" 2>/dev/null |
    while IFS='|' read -r sid name act path command title; do
        if [ -n "${AGENT[$sid]}" ]; then command="${AGENT[$sid]}"; fi
        echo "$name|${act:-0}|${RAM[$sid]:-0}|$path|$command|$title"
    done
