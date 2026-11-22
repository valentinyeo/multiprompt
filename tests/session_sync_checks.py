import base64
import concurrent.futures
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def source(path):
    return (ROOT / path).read_text()


def server_program():
    src = source("src/session_layout_sync.zig")
    block = src.split("pub const server_script =\n", 1)[1].split("\n;", 1)[0]
    program = "\n".join(line.strip()[2:] for line in block.splitlines()) + "\n"
    command = json.loads(re.search(r'pub const remote_command = (".*");', src)[1])
    return program, command


def document(tabs=(), workspaces=("Other",)):
    return {"schema": 1, "revision": 0,
            "workspaces": [{"name": name} for name in workspaces], "tabs": list(tabs)}


def tab(session="one", host=0, name="A", workspace="Other"):
    return {"kind": "tmux", "name": name, "tmux_session": session,
            "tmux_host": host, "workspace": workspace}


def transport():
    program, command = server_program()
    compile(program, "server_script", "exec")
    with tempfile.TemporaryDirectory(prefix="mp-layout-test-") as tmp:
        env = dict(os.environ, HOME=tmp)
        path = Path(tmp) / ".local/share/multiprompt/layout.json"

        def run(mode, value=None, fault=None):
            body = b"" if value is None else json.dumps(value).encode()
            actual = program
            if fault:
                actual = fault + "\n" + actual
            wire = base64.b64encode(actual.encode()) + b"\n" + body
            return subprocess.run(["bash", "-c", command + mode], input=wire,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                  env=env, timeout=25)

        def publish(value):
            result = run("publish", value)
            assert result.returncode == 0, result.stderr.decode()
            assert result.stdout.startswith(b"MP_LAYOUT_PUBLISHED:")
            return json.loads(path.read_bytes())

        original = tab(name='Kraków 🚀 "quote" \\ slash')
        first = publish(document([original, tab(host=1), tab(host=2)]))
        assert first["revision"] == 1 and first["tabs"][0] == original
        assert path.stat().st_mode & 0o777 == 0o600
        assert path.parent.stat().st_mode & 0o777 == 0o700
        pulled = run("pull")
        assert pulled.returncode == 0 and json.loads(pulled.stdout) == first
        second = publish(document([tab(name="renamed", workspace="Product"), tab("two", workspace="Product")], ("Product",)))
        assert second["revision"] == 2
        assert len(second["tabs"]) == 4
        assert second["tabs"][0]["name"] == "renamed"
        assert [w["name"] for w in second["workspaces"]] == ["Product", "Other"]
        assert second["tabs"][1]["tmux_session"] == "two"
        reordered = publish(document([tab("two"), tab()], ("Other",)))
        assert [t["tmux_session"] for t in reordered["tabs"][:2]] == ["two", "one"]
        before = publish(document())
        assert len(before["tabs"]) == 4

        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            replies = list(pool.map(lambda n: run("publish", document([tab(f"parallel-{n}")])), range(8)))
        assert all(r.returncode == 0 for r in replies)
        revisions = [int(r.stdout.decode().split(":")[1]) for r in replies]
        assert sorted(revisions) == list(range(before["revision"] + 1, before["revision"] + 9))
        final = json.loads(path.read_bytes())
        assert len(final["tabs"]) == 12
        assert final["revision"] == max(revisions)

        bad_values = []
        for field in ("pid", "hwnd", "password", "private_key", "window_position"):
            bad = document([tab()])
            bad["tabs"][0][field] = "must not sync"
            bad_values.append(bad)
        bad = document([tab()]); bad["tabs"][0]["tmux_host"] = 3; bad_values.append(bad)
        bad = document([tab()]); bad["tabs"][0]["tmux_session"] = "x'; touch pwn"; bad_values.append(bad)
        bad = document([tab()]); bad["tabs"][0]["workspace"] = "Missing"; bad_values.append(bad)
        bad_values += [document([tab(), tab()]), document([], ("Other", "Other"))]
        bad = document(); bad["schema"] = 2; bad_values.append(bad)
        bad = document(); bad["revision"] = -1; bad_values.append(bad)
        bad = document([tab(name="x" * 65)]); bad_values.append(bad)
        bad = document([tab(name="secret\ncommand")]); bad_values.append(bad)
        unchanged = path.read_bytes()
        for bad in bad_values:
            result = run("publish", bad)
            assert result.returncode != 0 and b"MP_LAYOUT_PUBLISHED:" not in result.stdout
            assert path.read_bytes() == unchanged
        fault = "import os\ndef fail_replace(*args): raise OSError('injected disk failure')\nos.replace = fail_replace"
        assert run("publish", document([tab("fault")]), fault).returncode != 0
        assert path.read_bytes() == unchanged
        assert not list(path.parent.glob(".layout-*"))
        path.write_text("{broken")
        assert run("publish", document([tab("cannot-clobber")])).returncode != 0
        assert path.read_text() == "{broken"
        assert run("pull").returncode != 0
        path.unlink()
        assert run("pull").returncode != 0
    print("SSH layout transaction verified")



if __name__ == "__main__":
    transport()
