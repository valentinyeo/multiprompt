const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const program = String.raw`
import base64, importlib.util, json, subprocess, sys
from pathlib import Path
from types import SimpleNamespace

home = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("mp_complete", sys.argv[2])
complete = importlib.util.module_from_spec(spec)
spec.loader.exec_module(complete)
complete.HOME = home

people = {"inne": SimpleNamespace(pw_name="inne", pw_uid=1002, pw_dir="/home/inne"),
          "root": SimpleNamespace(pw_name="root", pw_uid=0, pw_dir="/root")}

def lookup(name):
    return people[name]

own = complete.owner_for_cwd
assert own("/home/inne/projects/app", home, lookup) == "inne"
assert own("/home/inne", home, lookup) == "inne"
assert own("/home/inne/projects/app", "/home/inne", lookup) is None
assert own("/home/root/x", home, lookup) is None
assert own("relative/projects/app", home, lookup) is None
assert own("/home/../etc", home, lookup) is None
assert own("/srv/home/inne/x", home, lookup) is None
try:
    own("/home/ghost/x", home, lookup)
except KeyError:
    raise AssertionError("a missing account must not raise")

frame = "@mp\t7\tslash\tok\t/home/inne/projects/app\t1\nS\tdo\t\tRun the task\n@@MP_END@@\n"
script = Path(sys.argv[2]).read_bytes()
calls = []

class Done:
    def __init__(self, returncode, stdout):
        self.returncode = returncode
        self.stdout = stdout

def fake_run(argv, **kwargs):
    calls.append((list(argv), kwargs))
    return Done(0, frame.encode())

def delegated_answer(line, cwd, supplied):
    candidates = [cwd]
    if supplied not in (None, "-") and str(supplied) != str(cwd):
        candidates.append(supplied)
    for candidate in candidates:
        user = own(str(candidate), home, lookup)
        if user is None:
            continue
        encoded = base64.b64encode(line.rstrip("\n").encode("utf-8")).decode("ascii")
        try:
            result = complete.subprocess.run(["sudo", "-n", "-H", "-u", user, "--", "python3", "-", "--once", encoded],
                                             input=script, capture_output=True, timeout=6, check=False)
        except (OSError, complete.subprocess.SubprocessError):
            return None
        end = (complete.END + "\n").encode("ascii")
        if result.returncode == 0 and result.stdout.endswith(end):
            return result.stdout.decode("utf-8", "replace")
        return None
    return None

real_claude_rows = complete.claude_rows
real_resolve_cwd = complete.resolve_cwd
real_answer_as_owner = complete.answer_as_owner
subprocess.run = fake_run
complete.subprocess.run = fake_run
complete.answer_as_owner = delegated_answer
complete.owner_for_cwd = lambda cwd, home=None: own(cwd, home, lookup)
complete.claude_rows = lambda cwd: ("ok", [("S", "login-only", "", "")])
complete.resolve_cwd = lambda session, supplied: Path("/home/inne/projects/app")
answer = complete.request("7\tslash\tclaude\t-\t/home/inne/projects/app\t\n")
assert answer == frame, answer
argv = calls[0][0]
assert argv[:6] == ["sudo", "-n", "-H", "-u", "inne", "--"], argv
assert argv[6:8] == ["python3", "-"], argv
assert argv[8] == "--once", argv
assert base64.b64decode(argv[9]).decode() == "7\tslash\tclaude\t-\t/home/inne/projects/app\t", argv
assert calls[0][1]["timeout"] <= 6, calls[0][1]

calls.clear()
complete.resolve_cwd = lambda session, supplied: home
login = complete.request(f"8\tslash\tclaude\t-\t{home}\t\n")
assert calls == [], "the login user's own chat must not ask another account"
assert "\tok\t" in login and "login-only" in login, login

import pathlib
blocked = "/home/inne/projects/app"
real_is_dir = pathlib.Path.is_dir
def guarded_is_dir(self):
    if str(self) == blocked:
        raise PermissionError(13, "Permission denied", str(self))
    return real_is_dir(self)
pathlib.Path.is_dir = guarded_is_dir
complete.resolve_cwd = real_resolve_cwd
assert complete.usable_dir(blocked) is False, "an unreadable folder must not raise"
assert complete.usable_dir(home) is True, home
assert str(complete.resolve_cwd("-", blocked)) == str(home), "an unreadable folder falls back to the login home"
calls.clear()
subprocess.run = fake_run
complete.subprocess.run = fake_run
complete.answer_as_owner = delegated_answer
whole = complete.request(f"12\tslash\tclaude\t-\t{blocked}\t\n")
assert whole == frame, whole
argv = calls[0][0]
assert argv[:5] == ["sudo", "-n", "-H", "-u", "inne"], argv
pathlib.Path.is_dir = real_is_dir

calls.clear()
complete.answer_as_owner = delegated_answer
def refused(argv, **kwargs):
    calls.append((list(argv), kwargs))
    return Done(1, b"")
subprocess.run = refused
complete.subprocess.run = refused
complete.resolve_cwd = lambda session, supplied: Path("/home/inne/projects/app")
fallback = complete.request("9\tslash\tclaude\t-\t/home/inne/projects/app\t\n")
assert calls, "sudo must be attempted before reporting owner failure"
assert "\terror\t" in fallback, fallback
assert "login-only" not in fallback, fallback

subprocess.run = fake_run
complete.subprocess.run = fake_run
complete.answer_as_owner = delegated_answer
complete.claude_rows = real_claude_rows
complete.warm_async = lambda: None
complete.cache_key = lambda: ["cold"]
complete.read_json = lambda path: {}
complete.project_and_plugins = lambda cwd, settings: [("S", "do", "", "Run the task")]
status, rows = complete.claude_rows(Path("/home/inne/projects/app"))
assert status == "loading", status
assert ("S", "do", "", "Run the task") in rows, rows
complete.read_json = lambda path: {"key": ["cold"], "at": 99999999999, "commands": []}
status, rows = complete.claude_rows(Path("/home/inne/projects/app"))
assert status == "ok" and ("S", "do", "", "Run the task") in rows, (status, rows)
print("the menu asks the account that runs the chat")
`;

test('SOFT-3053 the slash menu asks the account that runs the chat', { skip: process.platform === 'win32' ? 'owner sudo contract is covered on Linux and in test_mp_complete.py' : false }, () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'skill-owner-'));
  try {
    const result = spawnSync('python3', ['-c', program, home, path.join(root, 'tools/agent-notifications/mp_complete.py')], {
      input: '', encoding: 'utf8', timeout: 60000, env: { ...process.env, HOME: home },
    });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.match(result.stdout, /the menu asks the account that runs the chat/);
  } finally {
    fs.rmSync(home, { recursive: true, force: true });
  }
});
