set -euo pipefail
repo=$1
public=$2
id mpverify >/dev/null 2>&1 || useradd -m -s /bin/bash mpverify
passwd -d mpverify >/dev/null
install -d -m 700 -o mpverify -g mpverify /home/mpverify/.ssh
install -m 600 -o mpverify -g mpverify "$public" /home/mpverify/.ssh/authorized_keys
mkdir -p /run/sshd
ssh-keygen -A
cat > /tmp/mp-ci-sshd.conf <<'CONFIG'
Port 2222
ListenAddress 127.0.0.1
HostKey /etc/ssh/ssh_host_ed25519_key
PidFile /tmp/mp-ci-sshd.pid
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers mpverify
UsePAM no
LogLevel VERBOSE
Subsystem sftp internal-sftp
CONFIG
/usr/sbin/sshd -t -f /tmp/mp-ci-sshd.conf
/usr/sbin/sshd -f /tmp/mp-ci-sshd.conf -E /tmp/mp-ci-sshd.log
runuser -u mpverify -- env HOME=/home/mpverify python3 "$repo/tools/verify-server-chat/seed.py" "$repo"
