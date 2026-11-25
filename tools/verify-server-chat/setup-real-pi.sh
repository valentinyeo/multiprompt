set -euo pipefail
repo=$1
summary_out=$2
node_version="v22.23.5"
pi_version="1.5.0"
codex_version="0.169.0"
vstack_commit="2af5980314a2b1bfbdb773a3129f5a8772a2b3ad"
tmp_dir=$(mktemp -d /tmp/mp-real-pi-XXXXXX)
chmod 700 "$tmp_dir"
trap 'rm -rf "$tmp_dir"' EXIT
umask 077
cat > "$tmp_dir/codex-auth-source.json"
chmod 600 "$tmp_dir/codex-auth-source.json"
umask 022
id mpverify >/dev/null 2>&1 || useradd -m -s /bin/bash mpverify
passwd -d mpverify >/dev/null
if ! command -v node >/dev/null 2>&1 || [[ "$(node -v 2>/dev/null || true)" != "$node_version" ]]; then
    apt-get update -qq </dev/null >/dev/null
    apt-get install -y -qq curl xz-utils git ca-certificates </dev/null >/dev/null
    curl -fsSL "https://nodejs.org/dist/${node_version}/node-${node_version}-linux-x64.tar.xz" -o "$tmp_dir/node.tar.xz" </dev/null
    curl -fsSL "https://nodejs.org/dist/${node_version}/SHASUMS256.txt" -o "$tmp_dir/SHASUMS256.txt" </dev/null
    expected_sha=$(awk "/node-${node_version}-linux-x64\\.tar\\.xz$/ {print \$1}" "$tmp_dir/SHASUMS256.txt")
    actual_sha=$(sha256sum "$tmp_dir/node.tar.xz" | awk '{print $1}')
    if [[ -z "$expected_sha" || "$expected_sha" != "$actual_sha" ]]; then
        echo "Node tarball checksum mismatch" >&2
        exit 1
    fi
    tar -xJf "$tmp_dir/node.tar.xz" -C /usr/local --strip-components=1
fi
npm install -g --no-audit --no-fund "@earendil-works/pi-coding-agent@${pi_version}" "@openai/codex@${codex_version}" </dev/null >/dev/null
actual_pi=$(pi --version | tr -d '\r\n')
if [[ "$actual_pi" != "$pi_version" ]]; then
    echo "Unexpected Pi version: $actual_pi" >&2
    exit 1
fi
install -d -m 755 -o mpverify -g mpverify /home/mpverify/.local /home/mpverify/.local/share /home/mpverify/.local/share/zigshell
install -m 644 -o mpverify -g mpverify "$repo/src/mp_complete.py" /home/mpverify/.local/share/zigshell/mp_complete.py
rm -rf /home/mpverify/.local/share/vstack
runuser -u mpverify -- env -i HOME=/home/mpverify USER=mpverify LOGNAME=mpverify PATH=/usr/local/bin:/usr/bin:/bin \
    git clone --quiet https://github.com/valentinyeo/vstack.git /home/mpverify/.local/share/vstack </dev/null
runuser -u mpverify -- env -i HOME=/home/mpverify USER=mpverify LOGNAME=mpverify PATH=/usr/local/bin:/usr/bin:/bin \
    git -C /home/mpverify/.local/share/vstack checkout --quiet "$vstack_commit" </dev/null
actual_vstack=$(runuser -u mpverify -- env -i HOME=/home/mpverify PATH=/usr/local/bin:/usr/bin:/bin \
    git -C /home/mpverify/.local/share/vstack rev-parse HEAD </dev/null)
if [[ "$actual_vstack" != "$vstack_commit" ]]; then
    echo "Pinned vstack commit mismatch" >&2
    exit 1
fi
runuser -u mpverify -- env -i HOME=/home/mpverify USER=mpverify LOGNAME=mpverify PATH=/usr/local/bin:/usr/bin:/bin \
    bash /home/mpverify/.local/share/vstack/install </dev/null >/dev/null
install -d -m 700 -o mpverify -g mpverify /home/mpverify/.pi /home/mpverify/.pi/agent /home/mpverify/.codex
summary=$(runuser -u mpverify -- env -i HOME=/home/mpverify USER=mpverify LOGNAME=mpverify PATH=/usr/local/bin:/usr/bin:/bin \
    python3 "$repo/tools/verify-server-chat/pi-auth-adapter.py" \
    --pi-auth-out /home/mpverify/.pi/agent/auth.json \
    --codex-auth-out /home/mpverify/.codex/auth.json < "$tmp_dir/codex-auth-source.json")
rm -f "$tmp_dir/codex-auth-source.json"
printf '%s\n' "$summary" > "$summary_out"
printf '%s\n' "$summary"
