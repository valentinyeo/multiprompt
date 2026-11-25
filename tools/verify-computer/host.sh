#!/usr/bin/env bash
set -euo pipefail
work="${1:?usage: host.sh <workdir> <github-output-file>}"
output="${2:?usage: host.sh <workdir> <github-output-file>}"
repo="${GITHUB_WORKSPACE:-$(pwd)}"
desk=desk
vnc_port=5900
viewer_port=6080
desktop_geometry=1280x800x24
marker_colour='#123456'
done_file=/tmp/verify-computer-done

mkdir -p "$work"
chmod 755 "$work"
sudo rm -f "$done_file"

password="$(head -c 64 /dev/urandom | base64 | LC_ALL=C tr -dc 'A-Za-z0-9' | cut -c1-8)"
echo "::add-mask::$password"
[ "${#password}" -eq 8 ] || { echo 'password generation failed'; exit 1; }

sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
    xvfb x11vnc xdotool openbox xterm x11-xserver-utils python3-pip >/dev/null
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends python3-websockify >/dev/null 2>&1; then
    sudo python3 -m pip install --break-system-packages --quiet 'websockify==0.12.0'
fi
python3 -c 'import websockify.websocketproxy' || { echo 'websockify module missing'; exit 1; }

if ! id -u "$desk" >/dev/null 2>&1; then
    sudo useradd --create-home --shell /bin/bash "$desk"
fi
sudo passwd -l "$desk" >/dev/null
sudo install -d -m 700 -o "$desk" -g "$desk" "/home/$desk/.vnc"

sudo x11vnc -storepasswd "$password" "/home/$desk/.vnc/passwd" >/dev/null 2>&1
sudo chown "$desk:$desk" "/home/$desk/.vnc/passwd"
sudo chmod 600 "/home/$desk/.vnc/passwd"
[ "$(sudo stat -c '%s' "/home/$desk/.vnc/passwd")" = 8 ] || { echo 'VNC password file is not eight bytes'; exit 1; }

sudo install -d -m 755 /usr/local/lib/verify-computer
sudo install -d -m 755 /usr/local/lib/verify-computer/web
printf '<title>verify-computer</title>\n' | sudo tee /usr/local/lib/verify-computer/web/index.html >/dev/null
sudo install -m 644 -o root -g root "$repo/tools/verify-computer/websockify-desktop.py" /usr/local/lib/verify-computer/websockify-desktop.py

sudo tee /etc/systemd/system/xvfb-desktop.service >/dev/null <<UNIT
[Unit]
Description=Disposable X desktop for the Computer view journey
After=network.target

[Service]
Type=simple
User=$desk
Environment=HOME=/home/$desk
ExecStart=/usr/bin/Xvfb :0 -screen 0 $desktop_geometry -nolisten tcp
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
UNIT

sudo tee /etc/systemd/system/x11vnc.service >/dev/null <<UNIT
[Unit]
Description=Disposable loopback VNC server for the Computer view journey
After=xvfb-desktop.service
Requires=xvfb-desktop.service

[Service]
Type=simple
User=$desk
Environment=HOME=/home/$desk
ExecStart=/usr/bin/x11vnc -norc -display :0 -localhost -rfbport $vnc_port -rfbauth /home/$desk/.vnc/passwd -forever -shared -noxdamage
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
UNIT

sudo tee /etc/systemd/system/novnc-desktop.service >/dev/null <<UNIT
[Unit]
Description=Disposable loopback noVNC websocket for the Computer view journey
After=xvfb-desktop.service x11vnc.service
Requires=x11vnc.service

[Service]
Type=simple
User=$desk
Environment=HOME=/home/$desk
ExecStart=/usr/bin/python3 /usr/local/lib/verify-computer/websockify-desktop.py
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
UNIT

printf 'desk ALL=(root) NOPASSWD: /usr/bin/systemctl stop novnc-desktop.service, /usr/bin/systemctl start novnc-desktop.service\n' | sudo tee /etc/sudoers.d/desk-verify >/dev/null
sudo chmod 440 /etc/sudoers.d/desk-verify

sudo install -d -m 700 -o "$desk" -g "$desk" "/home/$desk/.ssh"
sudo tee /etc/ssh/sshd_config.d/60-verify-computer.conf >/dev/null <<'CONF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
AllowUsers desk
AuthorizedKeysFile .ssh/authorized_keys
CONF
sudo systemctl reload ssh 2>/dev/null || sudo systemctl restart ssh

sudo systemctl daemon-reload
sudo systemctl enable --now xvfb-desktop.service
sudo systemctl enable --now x11vnc.service
sudo systemctl enable --now novnc-desktop.service
sleep 2

sudo runuser -u "$desk" -- env HOME="/home/$desk" DISPLAY=:0 nohup openbox >"$work/openbox.log" 2>&1 &
sleep 2
sudo runuser -u "$desk" -- env HOME="/home/$desk" DISPLAY=:0 nohup xterm -geometry 200x60+0+0 -bg "$marker_colour" -fg '#ffffff' -fa Monospace -fs 12 -e sh -c "cat > /home/$desk/typed.txt" >"$work/xterm.log" 2>&1 &
sleep 2

sudo install -m 644 -o root -g root "$repo/src/computer/discover.py" /tmp/verify-computer-discover.py
printf "main(True,'%s')\n" "$desk" | sudo tee -a /tmp/verify-computer-discover.py >/dev/null
sudo runuser -u "$desk" -- env HOME="/home/$desk" python3 -u /tmp/verify-computer-discover.py </dev/null >"$work/discovery.json"
python3 - "$work/discovery.json" <<'CHECK'
import json, sys
data = json.load(open(sys.argv[1], encoding='utf-8'))
assert data['version'] == 1, data
assert data['viewer_port'] == 6080, data
assert len(data['desktop']) == 64, data
assert data['display'] == ':0', data
assert data['password'], data
print('host discovery accepted desktop ' + data['desktop'])
CHECK
rm -f "$work/discovery.json"

curl -fsSL -o "$work/bore.tar.gz" https://github.com/ekzhang/bore/releases/download/v0.6.0/bore-v0.6.0-x86_64-unknown-linux-musl.tar.gz
echo 'e484d1e3acba77169b773f31a5bfb34192d4b660f44a094a658a2522cd2270f7  bore.tar.gz' >"$work/bore.sha256"
(cd "$work" && sha256sum -c bore.sha256 >/dev/null)
tar -C "$work" -xzf "$work/bore.tar.gz"
chmod 755 "$work/bore"

base=$(( 20000 + GITHUB_RUN_ID % 40000 ))
enroll_local=29999
enroll_public=$(( base + 500 ))

setsid "$work/bore" local "$enroll_local" --to bore.pub --port "$enroll_public" >>"$work/enroll.log" 2>&1 &
echo $! >"$work/enroll.pid"
enroll_up=0
for attempt in $(seq 1 20); do
    sleep 1
    if grep -qi 'listening at' "$work/enroll.log"; then enroll_up=1; break; fi
done
if [ "$enroll_up" -ne 1 ]; then
    echo 'the enrollment tunnel did not come up'
    cat "$work/enroll.log"
    exit 1
fi
echo "enrollment tunnel port ${enroll_public}"

sudo python3 - "$work/enrolled_keys" <<'ENROLL' &
import socket, sys
path = sys.argv[1]
server = socket.socket()
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(('127.0.0.1', 29999))
server.listen(4)
server.settimeout(1500)
while True:
    try:
        conn, _ = server.accept()
    except socket.timeout:
        sys.exit(1)
    conn.settimeout(10)
    data = b''
    try:
        while len(data) < 8192:
            piece = conn.recv(4096)
            if not piece:
                break
            data += piece
            if b'\n' in data:
                break
    except socket.timeout:
        pass
    keys = [line.strip() for line in data.decode('utf-8', 'replace').splitlines() if line.strip().startswith('ssh-ed25519 ')]
    if not keys:
        conn.close()
        continue
    with open(path, 'w', encoding='ascii') as handle:
        for key in keys:
            handle.write(key + '\n')
    conn.sendall(b'ok\n')
    conn.close()
    sys.exit(0)
ENROLL

tunnel_port=0
for offset in $(seq 0 15); do
    candidate=$(( base + offset ))
    : >"$work/bore.log"
    setsid "$work/bore" local 22 --to bore.pub --port "$candidate" >>"$work/bore.log" 2>&1 &
    echo $! >"$work/bore.pid"
    for attempt in $(seq 1 10); do
        sleep 1
        if grep -qi 'listening at' "$work/bore.log"; then tunnel_port=$candidate; break; fi
    done
    if [ "$tunnel_port" -gt 0 ]; then break; fi
    kill "$(cat "$work/bore.pid")" 2>/dev/null || true
done
if [ "$tunnel_port" -eq 0 ]; then
    echo 'no free public tunnel port in the reserved range'
    cat "$work/bore.log"
    exit 1
fi
echo "public tunnel port ${tunnel_port}"

enroll_deadline=$(( $(date +%s) + 1500 ))
while [ "$(date +%s)" -lt "$enroll_deadline" ]; do
    if [ -s "$work/enrolled_keys" ]; then break; fi
    sleep 5
done
if [ ! -s "$work/enrolled_keys" ]; then
    echo 'the client never published its public key to the enrollment tunnel'
    exit 1
fi
sudo install -m 600 -o "$desk" -g "$desk" "$work/enrolled_keys" "/home/$desk/.ssh/authorized_keys"
kill "$(cat "$work/enroll.pid")" 2>/dev/null || true
echo 'client public key enrolled; the enrollment tunnel is closed'

ss -ltnp >"$work/host-listeners.txt" 2>&1 || true
grep -E ':(5900|6080)[[:space:]]' "$work/host-listeners.txt" >"$work/desktop-listeners.txt" || true
cat "$work/desktop-listeners.txt"
awk '{ if ($4 ~ /:(5900|6080)$/ && $4 !~ /^127\.0\.0\.1:/ && $4 !~ /^\[::1\]:/) bad = 1 } END { exit bad }' "$work/host-listeners.txt" || {
    echo 'a desktop port is reachable beyond loopback'
    exit 1
}
for want in 5900 6080; do
    grep -q "127\.0\.0\.1:$want" "$work/host-listeners.txt" || { echo "port $want is not listening on loopback"; exit 1; }
done

{
    echo "host_ready=true"
    echo "host_port=$tunnel_port"
    echo "host_user=$desk"
    echo "host_vnc_port=$vnc_port"
    echo "host_viewer_port=$viewer_port"
} >>"$output"

deadline=$(( $(date +%s) + 2000 ))
while [ "$(date +%s)" -lt "$deadline" ]; do
    if [ -f "$done_file" ]; then echo 'client signalled completion'; break; fi
    if ! kill -0 "$(cat "$work/bore.pid")" 2>/dev/null; then echo 'public tunnel exited before the client finished'; exit 1; fi
    sleep 10
done
if [ ! -f "$done_file" ]; then echo 'journey did not finish inside the host time budget'; exit 1; fi
journalctl -u x11vnc.service -u novnc-desktop.service --no-pager -n 40 >"$work/host-services.log" 2>&1 || true
tail -40 "$work/host-services.log" || true
