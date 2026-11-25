import base64
import json
import os
import pwd
from pathlib import Path
import subprocess
import sys

if os.environ.get("SSH_ORIGINAL_COMMAND") == "ready":
    print("OWNER_PROOF_KEY_READY")
    sys.exit(0)

ROOT = Path(__file__).resolve().parent


def repo_root():
    for candidate in (ROOT,) + tuple(ROOT.parents):
        if (candidate / "src/chat_history_reader.py").is_file() and (candidate / "src/mp_zsb.sh").is_file():
            return candidate
    raise SystemExit("owner browser proof needs a checkout of this repository beside " + str(ROOT))


REPO = repo_root()
CONFIG = json.loads((ROOT / "proof-config.json").read_text())
SESSION = CONFIG["session"]
OWNER = CONFIG["user"]
OWNER_HOME = pwd.getpwnam(OWNER).pw_dir
ENDPOINT = "/tmp/mp-browser-" + str(os.getuid()) + "/control.sock"
SID = "mubo286-proof"
BOOTSTRAP = ('import base64,sys;s=base64.b64decode(sys.stdin.buffer.readline()).decode();'
             'exec(compile(s,"<agent-host>","exec"),dict(__name__="__main__",READER_SOURCE=s))')
REGISTER = ('import json,sys\nfrom pathlib import Path\n'
            'outer={"__name__":"proof_reader"}\n'
            'exec(compile(sys.stdin.read(),"reader","exec"),outer)\n'
            'runtime={}\nexec(compile(outer["READER_SOURCE"],"runtime","exec"),runtime)\n'
            'runtime["HOME"]=Path(sys.argv[1])\n'
            'runtime["host_write"](runtime["host_paths"]("claude",sys.argv[5])["config"],'
            'dict(enabled=True,cwd=sys.argv[2],tmux=sys.argv[3]))\n'
            'path=runtime["host_owner_session_register"]("claude",sys.argv[5],sys.argv[4])\n'
            'print(json.dumps(dict(path=str(path) if path else None,endpoint=runtime["host_owner_browser_endpoint"]())))')
SOURCES = (("MP_SEND_SOURCE", "src/mp_send.py"), ("FEEDBACK_SOURCE", "src/multibot_feedback.py"),
           ("MP_FRESH_SOURCE", "src/mp_fresh.py"), ("MP_HELPER_SOURCE", "src/mp_helper.py"),
           ("MP_SHELL_SOURCE", "src/mp_shell.py"), ("MP_SESSIONS_SOURCE", "src/mp_sessions.py"),
           ("MP_LAYOUT_SOURCE", "src/mp_layout.mjs"), ("ZSB_SOURCE", "src/mp_zsb.sh"))
READER = (REPO / "src/chat_history_reader.py").read_text()


def bundle():
    prelude = "".join("%s = '%s'\n" % (name, base64.b64encode((REPO / file).read_bytes()).decode())
                      for name, file in SOURCES if (REPO / file).is_file())
    return prelude + READER


def install_runtime():
    feed = base64.b64encode(bundle().encode()).decode() + "\n" + json.dumps(dict(id=1, op="engine_info")) + "\n"
    result = subprocess.run(["sudo", "-n", "-H", "-u", OWNER, "python3", "-u", "-c", BOOTSTRAP, "--serve"],
                            input=feed, capture_output=True, text=True, timeout=180)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    link = Path(OWNER_HOME) / ".multiprompt-runtime/zsb"
    check = subprocess.run(["sudo", "-n", "-u", OWNER, "test", "-x", str(link)])
    if check.returncode:
        raise RuntimeError("the owner runtime did not publish zsb")


def register(session):
    result = subprocess.run(["python3", "-c", REGISTER, str(Path.home()), OWNER_HOME, session, OWNER, SID],
                            input=READER, capture_output=True, text=True, timeout=120)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return json.loads(result.stdout.strip().splitlines()[-1])


def command(*args, target=SESSION, success=True):
    env = ["HOME=" + OWNER_HOME, "USER=" + OWNER, "LOGNAME=" + OWNER, "MULTIBOT_PROVIDER=claude",
           "MULTIBOT_SESSION=" + target, "ZSB_SESSION=" + target, "MULTIPROMPT_TAB=" + target,
           "ZSB_SOCKET=" + ENDPOINT,
           "PATH=" + OWNER_HOME + "/.multiprompt-runtime:/usr/local/bin:/usr/bin:/bin"]
    result = subprocess.run(["sudo", "-n", "-H", "-u", OWNER, "/usr/bin/env", "-i", *env, "zsb", *args],
                            capture_output=True, text=True, timeout=120)
    if success and result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result


install_runtime()
registration = register(SESSION)
if registration["endpoint"] != ENDPOINT or not registration["path"]:
    raise RuntimeError("owner browser delegation did not register this chat: " + json.dumps(registration))
uid = int(subprocess.check_output(["sudo", "-n", "-u", OWNER, "id", "-u"], text=True))
private = subprocess.run(["sudo", "-n", "-u", OWNER, "test", "-x", str(Path.home())]).returncode != 0
assert private
command("open", "http://127.0.0.1:19283/")
before = command("text", "--full").stdout
assert SESSION in before and "Not clicked" in before, before
command("click", "#proof-button")
after = command("text", "--full").stdout
assert "Clicked" in after, after
foreign = command("text", target="foreign-proof-1130", success=False)
global_command = command("workspace-list", success=False)
assert foreign.returncode and global_command.returncode
assert json.loads(foreign.stdout)["error"] == "owner_scope_denied"
assert json.loads(global_command.stdout)["error"] == "owner_scope_denied"
shot = "/tmp/" + SESSION + "-pane.png"
try:
    command("screenshot", "-o", shot)
    image = subprocess.check_output(["sudo", "-n", "-u", OWNER, "cat", shot])
    assert image.startswith(b"\x89PNG\r\n\x1a\n") and len(image) > 1000
finally:
    subprocess.run(["sudo", "-n", "-u", OWNER, "rm", "-f", shot], check=True)
Path(registration["path"]).unlink(missing_ok=True)
print(json.dumps({"ok": True, "uid": uid, "session": SESSION, "before": before, "after": after,
                  "foreignDenied": True, "globalDenied": True, "credentialsPrivate": private,
                  "endpoint": registration["endpoint"],
                  "screenshot": base64.b64encode(image).decode()}))
