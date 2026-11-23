#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
python_tools="mp-send:mp_send.py mp-fresh:mp_fresh.py mp-sessions:mp_sessions.py mp-helper:mp_helper.py mp-shell:mp_shell.py multibot-feedback:multibot_feedback.py"
node_tools="mp-layout:mp-layout.mjs"
script=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")

usage() {
  cat <<'EOF'
usage: install-mp-talk.sh [--check] [--user NAME]...

  no options   install every Multibot tool into this account
  --check      print each tool as ok, missing or broken; exit 1 when one is unusable
  --user NAME  repeat the command for another server account; needs password-free sudo
EOF
}

mode=install
users=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check) mode=check ;;
    --user)
      shift
      if [ $# -eq 0 ] || [ -z "$1" ]; then
        echo "install-mp-talk: --user needs an account name" >&2
        exit 2
      fi
      users="$users $1"
      ;;
    -h | --help) usage; exit 0 ;;
    *)
      echo "install-mp-talk: unknown argument $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ -n "$users" ]; then
  status=0
  for user in $users; do
    if [ "$mode" = check ]; then
      sudo -n -H -u "$user" -- /bin/sh "$script" --check || status=1
    else
      sudo -n -H -u "$user" -- /bin/sh "$script" || status=1
    fi
  done
  exit $status
fi

share="${XDG_DATA_HOME:-$HOME/.local/share}/multiprompt-talk"
bin="${MP_TALK_BIN:-$HOME/.local/bin}"

tool_names() {
  for pair in $python_tools $node_tools; do
    printf '%s\n' "${pair%%:*}"
  done
}

if [ "$mode" = check ]; then
  missing=0
  for name in $(tool_names); do
    if [ ! -x "$bin/$name" ]; then
      echo "$(id -un) $name missing at $bin/$name"
      missing=1
      continue
    fi
    if ! /bin/sh -l -c '"$0" --help' "$bin/$name" >/dev/null 2>&1; then
      echo "$(id -un) $name broken at $bin/$name"
      missing=1
      continue
    fi
    echo "$(id -un) $name ok"
  done
  exit $missing
fi

mkdir -p "$share" "$bin"
for pair in $python_tools; do
  cp "$here/src/${pair#*:}" "$share/"
done
cp "$here/src/mp_sessions_health.py" "$share/"
cp "$here/src/mp_tab_state.py" "$share/"
for pair in $node_tools; do
  cp "$here/tools/${pair#*:}" "$share/"
done

for pair in $python_tools; do
  name=${pair%%:*}
  file=${pair#*:}
  printf '#!/bin/sh\nexec python3 "%s/%s" "$@"\n' "$share" "$file" >"$bin/$name"
  chmod 755 "$bin/$name"
done
for pair in $node_tools; do
  name=${pair%%:*}
  file=${pair#*:}
  printf '#!/bin/sh\nexec node "%s/%s" "$@"\n' "$share" "$file" >"$bin/$name"
  chmod 755 "$bin/$name"
done

echo "installed every Multibot tool into $bin"
