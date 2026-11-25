set -euo pipefail
evidence=$1
if [[ -f /tmp/mp-ci-sshd.log ]]; then
    cp /tmp/mp-ci-sshd.log "$evidence/sshd.log"
fi
mkdir -p "$evidence/linux-host"
for file in /home/mpverify/.local/state/multiprompt/agent-host/*.{log,json}; do
    if [[ -f "$file" ]]; then cp "$file" "$evidence/linux-host/"; fi
done
for user in mpverify mpverify2 mpverify3; do
    id "$user" >/dev/null 2>&1 && pkill -u "$user" || true
done
if [[ -f /tmp/mp-ci-sshd.pid ]]; then
    kill "$(cat /tmp/mp-ci-sshd.pid)"
fi
