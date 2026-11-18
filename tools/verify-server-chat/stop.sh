set -euo pipefail
evidence=$1
if [[ -f /tmp/mp-ci-sshd.log ]]; then
    cp /tmp/mp-ci-sshd.log "$evidence/sshd.log"
fi
mkdir -p "$evidence/linux-host"
if [[ -f /home/mpverify/server-chat-fixture.json ]]; then
    cp /home/mpverify/server-chat-fixture.json "$evidence/server-chat-fixture.json"
fi
for file in /home/mpverify/.claude/projects/*/*.jsonl; do
    if [[ -f "$file" ]]; then cp "$file" "$evidence/linux-host/"; fi
done
for file in /home/mpverify/.local/state/multiprompt/agent-host/*.{log,json}; do
    if [[ -f "$file" ]]; then cp "$file" "$evidence/linux-host/"; fi
done
pkill -u mpverify || true
if [[ -f /tmp/mp-ci-sshd.pid ]]; then
    kill "$(cat /tmp/mp-ci-sshd.pid)"
fi
