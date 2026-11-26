set -euo pipefail
repo=$1
public=$2
id mpverify >/dev/null 2>&1 || useradd -m -s /bin/bash mpverify
passwd -d mpverify >/dev/null
install -d -m 700 -o mpverify -g mpverify /home/mpverify/.ssh
install -m 600 -o mpverify -g mpverify "$public" /home/mpverify/.ssh/authorized_keys
if [[ ${3:-} == idle ]]; then
    for user in mpverify mpverify2 mpverify3; do
        id "$user" >/dev/null 2>&1 || useradd -m -s /bin/bash "$user"
        passwd -d "$user" >/dev/null
        install -d -m 700 -o "$user" -g "$user" "/home/$user/.ssh" "/home/$user/.local" "/home/$user/.local/state" "/home/$user/.local/state/multiprompt"
        install -m 600 -o "$user" -g "$user" "$public" "/home/$user/.ssh/authorized_keys"
        runuser -u "$user" -- touch "/home/$user/.local/state/multiprompt/relay-v1"
    done
fi
mkdir -p /run/sshd
ssh-keygen -A
cat > /tmp/mp-ci-sshd.conf <<'CONFIG'
Port 2222
ListenAddress 127.0.0.1
HostKey /etc/ssh/ssh_host_ed25519_key
KexAlgorithms curve25519-sha256
PidFile /tmp/mp-ci-sshd.pid
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers mpverify mpverify2 mpverify3
UsePAM no
LogLevel VERBOSE
Subsystem sftp internal-sftp
CONFIG
/usr/sbin/sshd -t -f /tmp/mp-ci-sshd.conf
/usr/sbin/sshd -f /tmp/mp-ci-sshd.conf -E /tmp/mp-ci-sshd.log
runuser -u mpverify -- env HOME=/home/mpverify python3 "$repo/tools/verify-server-chat/check-locks.py"
runuser -u mpverify -- env HOME=/home/mpverify python3 "$repo/tools/verify-server-chat/seed.py" "$repo"
