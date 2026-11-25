set -euo pipefail
evidence=$1
rm -f /home/mpverify/.pi/agent/auth.json /home/mpverify/.codex/auth.json
if [[ -f /tmp/mp-ci-sshd.log ]]; then
    cp /tmp/mp-ci-sshd.log "$evidence/sshd.log"
fi
mkdir -p "$evidence/linux-host"
for file in /home/mpverify/.local/state/multiprompt/agent-host/*.{log,json,jsonl}; do
    if [[ -f "$file" ]]; then cp "$file" "$evidence/linux-host/"; fi
done
pkill -u mpverify || true
if [[ -f /tmp/mp-ci-sshd.pid ]]; then
    kill "$(cat /tmp/mp-ci-sshd.pid)"
fi
