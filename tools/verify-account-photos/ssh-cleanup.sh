#!/usr/bin/env bash
set -euo pipefail
: "${FIXTURE:?Missing fixture directory}"
: "${EVIDENCE:?Missing evidence directory}"
state="$FIXTURE/owned-processes.tsv"
identity() {
    local pid=$1 stat
    stat=$(sudo cat "/proc/$pid/stat" 2>/dev/null) || return 1
    stat=${stat##*) }
    read -r -a fields <<< "$stat"
    printf '%s\t%s\t%s\n' "$pid" "${fields[19]}" "$(sudo readlink "/proc/$pid/exe")"
}
matches() {
    local pid=$1 started=$2 executable=$3 current
    current=$(identity "$pid") || return 1
    [[ "$current" == "$pid"$'\t'"$started"$'\t'"$executable" ]]
}
if [[ ${1:-} == record ]]; then
    mkdir -p "$FIXTURE"
    : > "$state"
    if [[ -s "$FIXTURE/sshd.pid" && -f "$FIXTURE/sshd_config" ]]; then
        pid=$(cat "$FIXTURE/sshd.pid")
        [[ "$pid" =~ ^[0-9]+$ ]]
        cmd=$(sudo cat "/proc/$pid/cmdline" | tr '\0' ' ')
        [[ "$cmd" == *"$FIXTURE/sshd_config"* ]]
        root=$(identity "$pid")
        [[ "$root" == *$'\t'/usr/sbin/sshd* ]]
        printf '%s\n' "$root" >> "$state"
        tmux_pid=$(sudo -u valentin tmux display-message -p '#{pid}' 2>/dev/null)
        [[ "$tmux_pid" =~ ^[0-9]+$ && "$tmux_pid" != "$pid" ]]
        root=$(identity "$tmux_pid")
        [[ "$root" == *$'\t'/usr/bin/tmux* ]]
        printf '%s\n' "$root" >> "$state"
    else
        exit 1
    fi
    exit 0
fi
[[ ${1:-} == stop ]]
mkdir -p "$EVIDENCE"
failed=0
survivors=0
verified_roots=0
owned=$(mktemp "$FIXTURE/cleanup.XXXXXX")
trap 'rm -f "$owned"' EXIT
if [[ -f "$state" ]]; then
    while IFS=$'\t' read -r pid started executable; do
        [[ -n "$pid" ]] || continue
        if ! matches "$pid" "$started" "$executable"; then failed=1; continue; fi
        verified_roots=$((verified_roots + 1))
        queue=("$pid")
        while ((${#queue[@]})); do
            current=${queue[0]}
            queue=("${queue[@]:1}")
            identity "$current" >> "$owned" || true
            while read -r child; do [[ -z "$child" ]] || queue+=("$child"); done < <(pgrep -P "$current" || true)
        done
    done < "$state"
    tac "$owned" | while IFS=$'\t' read -r pid started executable; do
        if matches "$pid" "$started" "$executable"; then sudo kill -KILL "$pid" 2>/dev/null || true; fi
    done
    for attempt in {1..40}; do
        survivors=0
        while IFS=$'\t' read -r pid started executable; do
            if matches "$pid" "$started" "$executable"; then survivors=$((survivors + 1)); fi
        done < "$owned"
        [[ $survivors -eq 0 ]] && break
        sleep 0.25
    done
else
    failed=1
fi
keys_removed=true
for key in "$FIXTURE/user-key" "$FIXTURE/user-key.pub" "$FIXTURE/host-key" "$FIXTURE/host-key.pub"; do
    if ! rm -f -- "$key" || [[ -e "$key" || -L "$key" ]]; then keys_removed=false; fi
done
if [[ $survivors -ne 0 || $verified_roots -ne 2 || $keys_removed != true ]]; then failed=1; fi
if [[ $failed -eq 0 ]]; then status=passed; else status=failed; fi
printf '{"status":"%s","owned_survivors":%s,"verified_roots":%s,"keys_removed":%s}\n' "$status" "$survivors" "$verified_roots" "$keys_removed" > "$EVIDENCE/ssh-cleanup.json"
[[ $failed -eq 0 ]]
