import base64
import json
import os
import pwd
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent
config = json.loads((ROOT / "proof-config.json").read_text())
session = config["session"]
owner = config["user"]
owner_home = pwd.getpwnam(owner).pw_dir
wrapper = str(ROOT / "vps-multiprompt-browser.sh")
env = {**os.environ, "HOME": owner_home, "TMUX": "", "ZSB_SESSION": session,
       "ZSB_SOCKET": str(ROOT / "browser/control.sock"), "MULTIPROMP_NOTIFY_RELAY_TOKEN": ""}


def command(*args, target=session, success=True):
    result = subprocess.run(["sudo", "-n", "-u", owner, "env",
                             *[key + "=" + value for key, value in env.items()
                               if key in ("HOME", "TMUX", "ZSB_SESSION", "ZSB_SOCKET", "MULTIPROMP_NOTIFY_RELAY_TOKEN")],
                             "ZSB_SESSION=" + target, "bash", wrapper, *args], capture_output=True, text=True, timeout=90)
    if success and result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result


uid = int(subprocess.check_output(["sudo", "-n", "-u", owner, "id", "-u"], text=True))
private = subprocess.run(["sudo", "-n", "-u", owner, "test", "-x", str(Path.home())]).returncode != 0
assert private
command("open", "http://127.0.0.1:19283/")
before = command("text", "--full").stdout
assert session in before and "Not clicked" in before, before
command("click", "#proof-button")
after = command("text", "--full").stdout
assert "Clicked" in after, after
foreign = command("text", target="foreign-proof-1130", success=False)
global_command = command("workspace-list", success=False)
assert foreign.returncode and global_command.returncode
assert json.loads(foreign.stdout)["error"] == "owner_scope_denied"
assert json.loads(global_command.stdout)["error"] == "owner_scope_denied"
shot = "/tmp/" + session + "-pane.png"
try:
    command("screenshot", "-o", shot)
    image = subprocess.check_output(["sudo", "-n", "-u", owner, "cat", shot])
    assert image.startswith(b"\x89PNG\r\n\x1a\n") and len(image) > 1000
finally:
    subprocess.run(["sudo", "-n", "-u", owner, "rm", "-f", shot], check=True)
print(json.dumps({"ok": True, "uid": uid, "session": session,
                  "before": before, "after": after, "foreignDenied": True,
                  "globalDenied": True, "credentialsPrivate": private,
                  "screenshot": base64.b64encode(image).decode()}))
