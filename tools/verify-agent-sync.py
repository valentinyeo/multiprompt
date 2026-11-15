import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import shutil
import subprocess
import threading
import time
from urllib.parse import urlparse

AGENT = "11111111-1111-4111-8111-111111111111"
OTHER = "22222222-2222-4222-8222-222222222222"
EXACT_NAME = 'Renamed & "exact" café'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--cli", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    if os.environ.get("GITHUB_ACTIONS") != "true" or not os.environ.get("XDG_RUNTIME_DIR"):
        raise RuntimeError("run this journey on GitHub Linux with an isolated user manager")
    args.evidence.mkdir(parents=True, exist_ok=True)
    home = Path.home()
    names = home / ".local/state/multiprompt/chat-names.json"
    remote = {AGENT: "Hypertask before", OTHER: "Unrelated agent"}
    requests = []
    result = dict(status="failed", checks=[], boundary="Real reader protocol, installer, official Hypertask CLI and systemd user timer; loopback HTTP replaces only the Hypertask service. No desktop or live account is exercised.")

    class Api(BaseHTTPRequestHandler):
        def log_message(self, *values):
            pass

        def reply(self, code, data):
            body = json.dumps(data).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if urlparse(self.path).path != "/api/mcp/admin/agents":
                self.reply(404, dict(success=False))
                return
            requests.append(dict(method="GET", path=self.path, at=time.monotonic()))
            self.reply(200, dict(success=True, agents=[dict(id=key, display_name=value) for key, value in remote.items()], nextCursor=None))

        def do_PATCH(self):
            body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            identity = self.path.removeprefix("/api/mcp/agents/")
            if identity not in remote or set(body) != {"display_name"}:
                self.reply(400, dict(success=False))
                return
            requests.append(dict(method="PATCH", path=self.path, body=body, at=time.monotonic()))
            remote[identity] = body["display_name"]
            self.reply(200, dict(success=True, agent=dict(id=identity, display_name=remote[identity])))

    server = ThreadingHTTPServer(("127.0.0.1", 0), Api)
    thread = threading.Thread(target=server.serve_forever)
    thread.start()

    def run(command, expected=0, **kwargs):
        done = subprocess.run([str(part) for part in command], capture_output=True, text=True, timeout=30, **kwargs)
        if done.returncode != expected:
            raise AssertionError(f"{command[0]} returned {done.returncode}, expected {expected}: {done.stdout} {done.stderr}")
        return done.stdout

    def systemctl(*values):
        return run(["systemctl", "--user", *values])

    def check(message, condition):
        if not condition:
            raise AssertionError(message)
        result["checks"].append(message)

    def publish(name):
        payload = dict(id=1, op="chat_names", names=[dict(tmux="journey-chat", name=name), dict(tmux="journey-unlinked", name="Unlinked chat")])
        output = run(["python3", args.root / "src/chat_history_reader.py", "--serve"], input=json.dumps(payload) + "\n")
        replies = [json.loads(line) for line in output.splitlines() if line.startswith("{")]
        check("The production chat_names protocol accepted the published name", any(reply.get("id") == 1 and reply.get("result", {}).get("status") == "ok" for reply in replies))

    def wait_for(predicate, seconds):
        deadline = time.monotonic() + seconds
        while not predicate():
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise AssertionError("the installed timer did not deliver the expected HTTP rename before its deadline")
            threading.Event().wait(min(0.1, remaining))

    try:
        bin_dir = home / ".local/bin"
        bin_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(args.cli, bin_dir / "hypertask")
        config = home / ".hypertask/config.json"
        config.parent.mkdir(parents=True, exist_ok=True)
        config.write_text(json.dumps(dict(token="journey-fixture", managementKey="journey-fixture", apiUrl=f"http://127.0.0.1:{server.server_port}/api", error_reports=False)))
        publish("Chat before")
        run(["sh", "-x", args.root / "tools/install-mp-talk.sh"])
        sync = bin_dir / "mp-agent-sync"
        check("The talk installer exposes the mp-agent-sync command", sync.is_file())
        installed = home / ".local/share/multiprompt-talk/mp_agent_sync.py"
        check("The installed sync matches the selected source revision", installed.read_bytes() == (args.root / "src/mp_agent_sync.py").read_bytes())
        systemctl("stop", "mp-agent-sync.timer", "mp-agent-sync.service")
        run([sync, "link", "--tmux", "journey-chat", "--id", AGENT])
        refused = subprocess.run([str(sync), "link", "--tmux", "journey-unlinked", "--id", AGENT], capture_output=True, text=True, timeout=30)
        check("No two chats can link the same agent id", refused.returncode == 1 and "clash" in refused.stderr)
        stored = json.loads(names.read_text())
        check("The chat stores its one agent id in the entry and @agents map", stored["journey-chat"].get("agent") == AGENT and stored["@agents"].get("journey-chat") == AGENT)
        corrupt = json.loads(json.dumps(stored))
        corrupt["@agents"]["journey-unlinked"] = AGENT
        names.write_text(json.dumps(corrupt))
        patches = lambda: [request for request in requests if request["method"] == "PATCH"]
        before = len(patches())
        remote[AGENT] = "Hypertask before"
        output = run([sync], expected=1)
        check("A legacy shared-id clash blocks every HTTP rename", "clash\t" in output and len(patches()) == before)
        names.write_text(json.dumps(stored))
        output = run([sync, "--dry-run"])
        check("Dry-run and unlinked chats leave Hypertask unchanged", "rename\tChat before" in output and "unlinked\tUnlinked chat" in output and len(patches()) == before and remote[AGENT] == "Hypertask before")
        systemctl("start", "mp-agent-sync.timer")
        wait_for(lambda: remote[AGENT] == "Chat before", 60)
        first = patches()[-1]["at"]
        publish(EXACT_NAME)
        renamed_at = time.monotonic()
        stored = json.loads(names.read_text())
        check("Publishing a renamed chat preserves its stored agent id", stored["journey-chat"].get("agent") == AGENT and stored["@agents"].get("journey-chat") == AGENT)
        wait_for(lambda: remote[AGENT] == EXACT_NAME, 60)
        elapsed = time.monotonic() - renamed_at
        interval = patches()[-1]["at"] - first
        check("The real 50-second timer renames the linked Hypertask agent within a minute", elapsed < 60 and 40 <= interval <= 60)
        check("The HTTP rename uses the stored id and the exact published chat name", patches()[-1]["path"] == f"/api/mcp/agents/{AGENT}" and patches()[-1]["body"] == dict(display_name=EXACT_NAME))
        systemctl("stop", "mp-agent-sync.timer", "mp-agent-sync.service")
        count = len(patches())
        output = run([sync])
        check("Repeating sync does not rename again or touch unlinked or unrelated agents", len(patches()) == count and remote[OTHER] == "Unrelated agent" and "unlinked\tUnlinked chat" in output)
        result.update(status="passed", renameSeconds=elapsed, pollSeconds=interval)
    except Exception as error:
        result["error"] = str(error)
    finally:
        cleanup = subprocess.run(["systemctl", "--user", "disable", "--now", "mp-agent-sync.timer"], capture_output=True, text=True, timeout=30)
        stopped = subprocess.run(["systemctl", "--user", "stop", "mp-agent-sync.service"], capture_output=True, text=True, timeout=30)
        units = home / ".config/systemd/user"
        installed = home / ".local/share/multiprompt-talk/mp_agent_sync.py"
        doctor = dict(source=str(args.root), installedHash=hashlib.sha256(installed.read_bytes()).hexdigest() if installed.exists() else None, cliHash=hashlib.sha256(args.cli.read_bytes()).hexdigest(), timer=(units / "mp-agent-sync.timer").read_text() if (units / "mp-agent-sync.timer").exists() else None)
        doctor["environment"] = {key: os.environ.get(key) for key in ("HOME", "PATH", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_RUNTIME_DIR")}
        journal = subprocess.run(["journalctl", "--user", "-u", "mp-agent-sync.service", "--no-pager"], capture_output=True, text=True, timeout=30)
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
        result["cleanup"] = "Owned timer and service stopped; loopback server closed" if not thread.is_alive() and (cleanup.returncode == 0 and stopped.returncode == 0 or not installed.exists()) else "failed"
        if result["cleanup"] == "failed":
            result["status"] = "failed"
        for filename, value in (("result.json", result), ("doctor.json", doctor), ("requests.json", requests)):
            (args.evidence / filename).write_text(json.dumps(value, indent=2) + "\n")
        (args.evidence / "journal.txt").write_text(journal.stdout + journal.stderr)
        if names.exists():
            shutil.copy2(names, args.evidence / "chat-names.json")
    print(json.dumps(result, indent=2))
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
