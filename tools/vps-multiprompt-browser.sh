#!/usr/bin/env bash

set -uo pipefail

port="${ZSB_PORT:-19548}"

json_string() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]), end="")' "$1" 2>/dev/null || {
    local s="${1//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '"%s"' "$s"
  }
}

json_error() {
  local code="$1"
  local message="$2"
  local hint="${3:-}"
  printf '{"ok":false,"error":%s,"message":%s' "$(json_string "$code")" "$(json_string "$message")"
  if [ -n "${sess:-}" ]; then
    printf ',"session":%s' "$(json_string "$sess")"
  fi
  printf ',"port":%s' "$port"
  if [ -n "$hint" ]; then
    printf ',"hint":%s' "$(json_string "$hint")"
  fi
  printf '}\n'
}

print_help() {
  if [ -n "${1:-}" ]; then
    case "$1" in
      text|get-text|snapshot|links)
        local unit=characters default_limit=2000
        if [ "$1" = links ]; then unit=links; default_limit=50; fi
        printf 'usage: zsb %s [--limit N | --full] [--tab ID]\n' "$1"
        printf '  --limit N  Maximum %s (default: %s)\n' "$unit" "$default_limit"
        printf '  --full     No practical limit\n  --tab ID   Read a tab in this session by ID, title, or URL match\n'
        printf '  Without --tab, read the target:true tab from zsb tabs (which may not be active).\n'
        return
        ;;
      navigate) echo 'usage: zsb navigate <url> [--new-tab]  (reuses only the untouched agent-created target; otherwise opens a background tab; --new-tab always creates; --activate is ignored)'; return ;;
      workspace-list) echo 'usage: zsb workspace-list (JSON workspaces, groups, tabs and host names; no session context needed)'; return ;;
      session-open) echo 'usage: zsb session-open --workspace <name> --group <name> --host <host name> --tmux <session> --name <tab title>'
        echo '  Names match exactly. Opens an existing remote tmux session in the background; never activates.'
        echo '  --tmux accepts 1-63 letters, digits, hyphens, underscores or dots.'
        echo '  --name accepts 1-63 UTF-16 units, without control characters.'
        echo '  An existing tab for the same host/session in any workspace returns existing:true and its workspace name without changes.'
        return ;;
      selftest) echo 'usage: zsb selftest (JSON summary plus human result; nonzero on failure)'; return ;;
      pane-info) echo 'usage: zsb pane-info (hosting multiprompt tab, active, visible, windowId)'; return ;;
      reset) echo 'usage: zsb reset (reconnect bridge and clear stuck CDP sessions; keeps the pane open)'; return ;;
      extension-reload) echo 'usage: zsb extension-reload (reload unpacked extension code; no app restart)'; return ;;
      tabs) echo 'usage: zsb tabs [--close ID]'; return ;;
      url) echo 'usage: zsb url [--tab ID]'; return ;;
      find) echo 'usage: zsb find <text> [--tab ID]'; return ;;
      click) echo 'usage: zsb click <selector> [--tab ID]'; return ;;
      screenshot) echo 'usage: zsb screenshot [-o FILE | --output FILE] [--tab ID]'; return ;;
      console) echo 'usage: zsb console [-n N | --limit N] [--clear]'; return ;;
      routing-audit) echo 'usage: zsb routing-audit [--limit N | --full]'; return ;;
      resolve-window) echo 'usage: zsb resolve-window [--match TEXT] [--focused]'; return ;;
      cdp)
        cat <<'CDP_HELP'
usage: zsb cdp <method> [params-json]
Send a Chrome DevTools Protocol command. Params must be a JSON object.

Examples:
  zsb cdp Page.enable
  zsb cdp Runtime.evaluate '{"expression":"document.title"}'
CDP_HELP
        return ;;
      open) echo 'usage: zsb open [url]'; return ;;
      sidebar|status|doctor|back|forward|reload|active-tab|shoturl|native|version|browser-drop-gesture)
        printf 'usage: zsb %s\n' "$1"; return ;;
      activate) echo 'usage: zsb activate <tabId> [--target-only]'; return ;;
      close-tab) echo 'usage: zsb close-tab <id|match>'; return ;;
      tab) echo 'usage: zsb tab close <id|match>'; return ;;
      insert) echo 'usage: zsb insert <text>'; return ;;
      eval|script) printf 'usage: zsb %s <js> [--tab ID]\n' "$1"; return ;;
      key) echo 'usage: zsb key <combo>'; return ;;
      cursor) echo 'usage: zsb cursor [on|off|move X Y|click X Y]'; return ;;
      profile-clone) echo 'usage: zsb profile-clone <src> <dst>'; return ;;
      create-pane-window) echo 'usage: zsb create-pane-window <url> [--app] [--bounds L T W H]'; return ;;
      theme) echo 'usage: zsb theme <name>'; return ;;
      protect-window) echo 'usage: zsb protect-window [--shell-id N] [--owner-pid N]'; return ;;
      manifest) echo 'usage: zsb manifest <exe> <extension-id>'; return ;;
      type) echo 'usage: zsb type [--tab ID] [--keys] <text> | <selector> <text>'; return ;;
    esac
  fi
  cat <<'EOF'
usage: zsb <command> [args] (also: multiprompt-browser)

Commands and flags:
  workspace-list                    List workspaces, groups, tabs and host names as JSON
  session-open --workspace NAME --group NAME --host HOST --tmux SESSION --name TITLE
                                    Attach a remote tmux tab in the background, idempotently
  open <url>                         Open a browser pane for this session
  navigate <url> [--new-tab]         Reuse only untouched agent target; otherwise append; --new-tab always creates
  tabs [--close ID]                  List tabs or close one
  reset                             Reconnect bridge and clear stuck CDP sessions (keeps pane open)
  extension-reload                  Reload unpacked extension code (no app restart)
  active-tab | activate <id> | close-tab <id> | tab close <id>
  url [--tab ID]                    Read a tab URL
  text [--limit N | --full] [--tab ID]      Read visible text (default: 2000 chars)
  snapshot [--limit N | --full] [--tab ID]  Read page state (default: 2000 chars)
  links [--limit N | --full] [--tab ID]     Read links (default: 50 links)
  find <text> [--tab ID]            Find text in the target tab
  click <selector> [--tab ID]       Click an element
  type [--keys] <text> | <selector> <text>  Type into the page
  key <combo>                       Send a key combination
  screenshot [-o FILE | --output FILE] [--tab ID]
  console [-n N | --limit N] [--clear]
  routing-audit [--limit N | --full]
  resolve-window [--match TEXT] [--focused]
  selftest                          Verify page read/type/click/screenshot and visible hosting tab
  pane-info                         Ask the app for hosting tab name, active, visible, windowId
  status | doctor | back | forward | reload | shoturl
  cursor [on | off | move X Y | click X Y]
  insert <text> | eval <code> | cdp <method> [params-json]

Unqualified reads and actions use the target:true tab in zsb tabs, not necessarily active:true.
Use zsb <command> --help or -h for local command help without contacting the browser.
Remote recovery: reconnect SSH/tmux, open or rebind this session's pane, then run zsb status.
EOF
}

if [ "$#" -eq 0 ]; then
  print_help >&2
  exit 2
fi

case "${1:-}" in
  help|--help|-h)
    print_help
    exit 0
    ;;
esac
if [ "${2:-}" = "--help" ] || [ "${2:-}" = "-h" ]; then
  print_help "$1"
  exit 0
fi
if { [ "$1" = tab ] && [ "${2:-}" = close ]; } || { [ "$1" = tabs ] && [ "${2:-}" = --close ]; }; then
  if [ "${3:-}" = "--help" ] || [ "${3:-}" = "-h" ]; then
    print_help "$1"
    exit 0
  fi
fi

sess=""
fallback_sess="${ZSB_SESSION:-}"
if [ "$1" = "workspace-list" ] || [ "$1" = "session-open" ]; then
  sess="workspace"
elif [ -n "${TMUX:-}" ]; then
  sess="$(tmux display-message -p '#S' 2>/dev/null || true)"
fi
if [ -z "$sess" ]; then
  sess="$fallback_sess"
fi
if [ -z "$sess" ]; then
  json_error "no_session" "cannot determine session (set ZSB_SESSION or run inside tmux)" "Run multiprompt-browser inside the multiprompt-owned tmux/SSH tab, or set ZSB_SESSION."
  exit 1
fi

if [ "$1" = "selftest" ]; then
  if [ "$#" -ne 1 ]; then print_help selftest >&2; exit 2; fi
  python3 - "$sess" "$port" "${BASH_SOURCE[0]}" <<'PY_SELFTEST'
import base64
import datetime
import html
import json
import os
import subprocess
import struct
import sys
import time
import urllib.parse
import uuid

session, port, wrapper = sys.argv[1:]
stamp = datetime.datetime.now(datetime.timezone.utc).isoformat()
title = f"zsb selftest {session} {stamp}"
marker = "zsb-selftest-" + uuid.uuid4().hex
page = (f"<!doctype html><title>{html.escape(title)}</title>"
        f"<h1>{html.escape(title)}</h1><p>{marker}</p>"
        '<input id="zsb-input" aria-label="Selftest input">'
        '''<button id="zsb-button" onclick="document.getElementById('zsb-result').textContent='clicked'">Test click</button>'''
        '<p id="zsb-result">not clicked</p>')
# Extensions cannot script data: pages, so build the test page on a real site.
url = "https://example.com/?" + marker
summary = {"ok": False, "session": session, "title": title, "tab_name": None,
           "active": False, "visible": False, "steps": {}}
tab_id = None
window_id = None


def request(*args):
    # Use the same validated transport as ordinary CLI commands.
    run = subprocess.run(["bash", wrapper, *args], capture_output=True, text=True,
                         env={**os.environ, "TMUX": "", "ZSB_SESSION": session, "ZSB_PORT": port})
    if run.returncode:
        raise ValueError(run.stderr.strip().removeprefix("multiprompt-browser: "))
    raw = run.stdout
    if args[0] == "open" and raw.strip() == "ok":
        return {}
    reply = json.loads(raw)
    result = reply.get("result", reply)
    if args[0] == "tabs" and isinstance(result, dict) and result.get("tabs") == []:
        if not reply.get("extensionVersion"):
            raise ValueError("extension outdated, reload it in chrome://extensions (empty session pane tab list)")
        raise ValueError("empty session pane tab list: bound browser window has no tabs; reopen/rebind it")
    if isinstance(result, dict) and result.get("error"):
        raise ValueError(str(result["error"]))
    return result


def tabs():
    result = request("tabs")
    return result if isinstance(result, list) else result["tabs"]


def find_test_tab():
    try:
        matches = [tab for tab in tabs() if url in (tab.get("url"), tab.get("pendingUrl"))]
        if len(matches) == 1:
            return matches[0]
        problem = f"tabs found {len(matches)} tabs matching marker URL {url}"
    except (ValueError, KeyError, TypeError, AttributeError, OSError) as exc:
        problem = f"tabs failed: {exc}"
    try:
        active = request("active-tab")
        pane = request("pane-info")
        # issue: active-tab reports the session's target tab; agent tabs are
        # never activated, so the browser's active flag is not required.
        if (url in (active.get("url"), active.get("pendingUrl")) and
                active.get("windowId") == pane.get("windowId") and
                isinstance(active.get("id"), int) and active["id"] > 0 and
                isinstance(pane.get("windowId"), int) and pane["windowId"] > 0):
            return active
        problem += (f"; pane active-tab did not match marker URL (id={active.get('id')}, "
                    f"url={active.get('url')!r}, active={active.get('active')}, "
                    f"windowId={active.get('windowId')}, pane windowId={pane.get('windowId')})")
    except (ValueError, KeyError, TypeError, AttributeError, OSError) as exc:
        problem += f"; active-tab fallback failed: {exc}"
    raise ValueError(f"cannot locate selftest tab: {problem}")


def step(name, action):
    try:
        details = action() or {}
        summary["steps"][name] = {"pass": True, **details}
    except Exception as exc:
        summary["steps"][name] = {"pass": False, "error": str(exc)}


def open_page():
    global tab_id, window_id
    request("open", url)
    tab = find_test_tab()
    tab_id, window_id = str(tab["id"]), tab["windowId"]
    # zsb eval takes one expression, so chain with commas.
    build = ("(document.title=" + json.dumps(title) + ",document.body.innerHTML=" + json.dumps(page) +
             ",document.title)")
    for _ in range(20):
        try:
            if request("eval", build, "--tab", tab_id) == title:
                break
        except ValueError:
            pass
        time.sleep(0.5)
    tab = find_test_tab()
    if tab.get("title") != title or tab.get("target") is False:
        raise ValueError("selftest page is not this session's target browser tab")
    return {"tab_id": tab_id, "windowId": window_id}


def read_page():
    result = request("text", "--full", "--tab", tab_id)
    if marker not in result.get("text", "") or title not in result.get("text", ""):
        raise ValueError("text read did not return this selftest page")


def type_input():
    request("type", "--tab", tab_id, "#zsb-input", marker)
    value = request("eval", "document.getElementById('zsb-input').value", "--tab", tab_id)
    if value != marker:
        raise ValueError("input value did not match typed text")


def click_button():
    request("click", "#zsb-button", "--tab", tab_id)
    result = request("eval", "document.getElementById('zsb-result').textContent", "--tab", tab_id)
    if result != "clicked":
        raise ValueError("button result did not change to clicked")


def screenshot():
    result = request("screenshot", "--tab", tab_id)
    data = result.get("data")
    if result.get("dataUrl", "").startswith("data:image/png;base64,"):
        data = result["dataUrl"].split(",", 1)[1]
    png = base64.b64decode(data or "", validate=True)
    if len(png) < 33 or png[:8] != b"\x89PNG\r\n\x1a\n" or png[12:16] != b"IHDR":
        raise ValueError("screenshot did not contain PNG bytes")
    width, height = struct.unpack(">II", png[16:24])
    if not width or not height:
        raise ValueError("screenshot has empty dimensions")
    return {"bytes": len(png), "width": width, "height": height}


def hosting():
    info = request("pane-info")
    summary.update({"tab_name": info.get("tab_name"), "active": info.get("active") is True,
                    "visible": info.get("visible") is True})
    if not isinstance(summary["tab_name"], str) or not summary["tab_name"]:
        raise ValueError("app did not report a hosting tab name")
    if window_id is not None and info.get("windowId") != window_id:
        raise ValueError("app hosting window differs from the tested pane")
    if not summary["active"] or not summary["visible"]:
        raise ValueError("hosting multiprompt tab is not active and visible")
    if tab_id is not None and find_test_tab().get("target") is False:
        raise ValueError("selftest browser tab is no longer this session's target")


def close_page():
    global tab_id
    # open may have created the page before its verification failed.
    if tab_id is None:
        matches = [tab for tab in tabs() if tab.get("url") == url]
        if not matches:
            return {"not_created": True}
        if len(matches) != 1:
            raise ValueError("ambiguous cleanup; refusing to close unrelated tabs")
        tab_id = str(matches[0]["id"])
    request("close-tab", tab_id)
    if any(str(tab["id"]) == tab_id for tab in tabs()):
        raise ValueError("selftest tab still exists after close")


try:
    step("open", open_page)
    for name, action in [("text", read_page), ("type", type_input),
                         ("click", click_button), ("screenshot", screenshot)]:
        if tab_id is None:
            summary["steps"][name] = {"pass": False, "skipped": "open did not identify a test tab"}
        else:
            step(name, action)
    step("hosting", hosting)
finally:
    step("close", close_page)
summary["ok"] = all(result["pass"] for result in summary["steps"].values())
print(json.dumps(summary, ensure_ascii=False, separators=(",", ":")))
state = "visible" if summary["visible"] else "not visible"
name = json.dumps(summary["tab_name"], ensure_ascii=False)
if summary["ok"]:
    print(f"PASS: pane for {session} is on tab {name} ({state})")
else:
    failed = next((step, result) for step, result in summary["steps"].items() if not result["pass"])
    print(f"FAIL: {failed[0]}: {failed[1].get('error') or failed[1].get('skipped')}")
sys.exit(0 if summary["ok"] else 1)
PY_SELFTEST
  exit "$?"
fi

send_zsb() {
  python3 - "$sess" "$port" "$@" <<'PY_REQUEST'
import base64
import json
import socket
import sys
import os
import time

session, port, *args = sys.argv[1:]
fix = "Restart/reconnect multiprompt and this SSH session; if it persists, reload the multiprompt extension in the browser (chrome://extensions)."


def fail(code, message, reply=None):
    message = " ".join(str(message).split())
    print("multiprompt-browser: " + message, file=sys.stderr)
    print(json.dumps(reply if reply is not None else
                     {"ok": False, "error": code, "message": message,
                      "session": session, "port": int(port)}))
    sys.exit(1)


if args[0] == "workspace-list":
    if len(args) != 1:
        fail("bad_args", "usage: zsb workspace-list")
elif args[0] == "session-open":
    flags = {"--workspace", "--group", "--host", "--tmux", "--name"}
    values = {}
    if len(args) != 11:
        fail("bad_args", "session-open requires --workspace, --group, --host, --tmux and --name")
    for flag, value in zip(args[1::2], args[2::2]):
        if flag not in flags or flag in values or not value or any(ord(c) < 32 or 127 <= ord(c) <= 159 for c in value):
            fail("bad_args", "session-open requires each named flag once, with nonempty values and no control characters")
        values[flag] = value
    tmux = values["--tmux"]
    if len(tmux) > 63 or any(not (c.isascii() and (c.isalnum() or c in "-_.")) for c in tmux):
        fail("invalid_tmux", "tmux session must contain 1-63 letters, digits, hyphens, underscores or dots")
    if len(values["--name"].encode("utf-16-le")) // 2 > 63:
        fail("invalid_name", "tab title must contain 1-63 UTF-16 units without control characters")
    if any(len(value.encode()) > 256 for value in values.values()):
        fail("bad_args", "session-open argument too long")

try:
    timeout = float(os.environ.get("ZSB_TIMEOUT_SECONDS", "90"))
    if not 0 < timeout <= 300:
        raise ValueError()
except ValueError:
    fail("bad_timeout", "ZSB_TIMEOUT_SECONDS must be greater than 0 and at most 300")
deadline = time.monotonic() + timeout
payload = base64.b64encode(("\x1f".join(args) + "\x1f").encode()).decode()
try:
    sock = socket.create_connection(("127.0.0.1", int(port)), timeout=min(5, timeout))
except OSError:
    fail("tunnel_down", "multiprompt app not reachable (SSH tunnel down). Reconnect this SSH/tmux session from multiprompt.")
try:
    with sock:
        sock.settimeout(max(0.001, deadline - time.monotonic()))
        sock.sendall(f"ZSB:{session}:{payload}\n".encode())
        chunks, size = [], 0
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise socket.timeout()
            sock.settimeout(remaining)
            chunk = sock.recv(65536)
            if not chunk:
                break
            size += len(chunk)
            if size > 16 * 1024 * 1024:
                fail("reply_too_large", "multiprompt reply exceeded 16 MiB. Retry with a smaller output limit.")
            chunks.append(chunk)
except socket.timeout:
    fail("reply_timeout", "multiprompt app/bridge exceeded the command deadline (timeout); run zsb reset to reconnect without reopening the pane. " + fix)
except OSError:
    fail("connection_closed", "multiprompt connection closed before the reply completed (app stopped or bridge changed). " + fix)
raw = b"".join(chunks).decode(errors="replace")
if not raw.strip():
    fail("empty_reply", "multiprompt app not reachable: tunnel accepted the request but closed without a reply (app stopped or bridge changed). " + fix)
# The app's pane handoff and WebView2 actions use a literal acknowledgement.
if raw.strip() == "ok" and args[0] in {"open", "sidebar", "navigate", "back", "forward", "reload"}:
    print(raw.rstrip())
    sys.exit(0)
try:
    reply = json.loads(raw)
except ValueError:
    first = raw.strip().splitlines()[0][:160]
    if first.startswith(("multiprompt-browser [--window", "usage:")):
        fail("bad_args", f"the bridge rejected the arguments of '{args[0]}' and printed its usage ({first}). Check the command and its flags; the app and pane are fine.")
    fail("invalid_reply", f"multiprompt app/bridge returned an invalid reply (possibly interrupted by an update). Reply started with: {first}. " + fix)
if not isinstance(reply, dict) or not isinstance(reply.get("ok"), bool):
    fail("invalid_reply", "multiprompt app/bridge returned an invalid reply (possibly incompatible versions). " + fix)
loaded, bridge = reply.get("extensionVersion"), reply.get("bridgeVersion")
if loaded and bridge and loaded != bridge and args[0] != "extension-reload":
    fail("version_mismatch", f"extension version {loaded} does not match bridge {bridge}: reload the extension in chrome://extensions; if it persists, install matching bridge/extension versions.")
if reply.get("tunnel") == "down":
    fail("tunnel_down", "multiprompt app not reachable (SSH tunnel down). Reconnect this SSH/tmux session from multiprompt.")
if reply.get("pane") == "closed":
    fail("pane_closed", "browser pane closed: open/rebind the browser pane for this exact multiprompt tab.")
if reply["ok"] is not True:
    message = reply.get("message") or reply.get("error") or "multiprompt command failed"
    hint = reply.get("hint") or ("Use zsb workspace-list to find workspace, group and host names." if args[0] in {"workspace-list", "session-open"} else "Reload the multiprompt extension in the browser or reopen/rebind this session's browser pane.")
    fail(reply.get("error", "command_failed"), f"{message}. {hint}", reply)
result = reply.get("result", {})
if args[0] == "tabs" and len(args) == 1:
    tabs = result.get("tabs") if isinstance(result, dict) else result
    if tabs == []:
        try:
            parts = tuple(int(part) for part in loaded.split("."))
            current = len(parts) == 3 and parts >= (1, 0, 54)
        except (ValueError, AttributeError):
            current = False
        message = ("empty session pane tab list: reopen/rebind this pane" if current else
                   "extension outdated, reload it in chrome://extensions (requires extension 1.0.54 or newer)")
        fail("pane_tabs_empty" if current else "extension_outdated", message,
             {"ok": False, "error": "pane_tabs_empty" if current else "extension_outdated",
              "message": message, "extensionVersion": loaded})
print(raw.rstrip())
PY_REQUEST
}

orig_args=("$@")
if [ "${orig_args[0]}" = "screenshot" ]; then
  output_path=""
  stripped_args=()
  i=0
  while [ "$i" -lt "${#orig_args[@]}" ]; do
    arg="${orig_args[$i]}"
    if [ "$arg" = "-o" ] || [ "$arg" = "--output" ]; then
      i=$((i + 1))
      if [ "$i" -ge "${#orig_args[@]}" ]; then
        echo "multiprompt-browser: screenshot $arg requires a file path" >&2
        exit 2
      fi
      output_path="${orig_args[$i]}"
    else
      stripped_args+=("$arg")
    fi
    i=$((i + 1))
  done

  if [ -n "$output_path" ]; then
    response="$(send_zsb "${stripped_args[@]}")"
    rc=$?
    if [ "$rc" -ne 0 ]; then
      printf '%s\n' "$response"
      exit "$rc"
    fi
    tmp_response="$(mktemp)"
    printf '%s' "$response" > "$tmp_response"
    python3 - "$output_path" "$tmp_response" <<'PY'
import base64
import json
import pathlib
import sys

out_path = sys.argv[1]
response_path = pathlib.Path(sys.argv[2])
raw = response_path.read_text(errors="replace").strip()

try:
    obj = json.loads(raw)
except Exception as exc:
    print(f"multiprompt-browser: screenshot returned non-JSON ({exc}): {raw[:240]}", file=sys.stderr)
    sys.exit(1)

if not obj.get("ok"):
    print(raw, file=sys.stderr)
    sys.exit(1)

result = obj.get("result") or {}
data = result.get("data")
data_url = result.get("dataUrl")
if data_url:
    prefix = "data:image/png;base64,"
    if not data_url.startswith(prefix):
        print("multiprompt-browser: screenshot returned a non-PNG data URL", file=sys.stderr)
        sys.exit(1)
    data = data_url[len(prefix):]

if not data:
    print("multiprompt-browser: screenshot response did not include PNG data", file=sys.stderr)
    sys.exit(1)

try:
    png = base64.b64decode(data, validate=True)
except Exception as exc:
    print(f"multiprompt-browser: screenshot PNG base64 decode failed: {exc}", file=sys.stderr)
    sys.exit(1)

pathlib.Path(out_path).parent.mkdir(parents=True, exist_ok=True)
pathlib.Path(out_path).write_bytes(png)
report = {"ok": True, "path": out_path, "bytes": len(png)}
via = result.get("via") or ("Page.captureScreenshot" if result.get("data") else "")
if via:
    report["via"] = via
print(json.dumps(report, separators=(",", ":")))
PY
    rc=$?
    rm -f "$tmp_response"
    exit "$rc"
  fi
fi

send_zsb "${orig_args[@]}"
