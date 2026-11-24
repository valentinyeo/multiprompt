import base64
import hashlib
import json
import os
from pathlib import Path
import pwd
import shutil
import socket
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
BRIDGE = 'mpbridge'
OWNER = 'mpowner'
SESSION = 'live-mubo286'
FOREIGN = 'live-notmine'
HOST = socket.gethostname()
PAGE = 'https://example.com/mubo-286-owner-pane'
STALE_COPY = '#!/bin/sh\necho stale-copy-answered\nexit 3\n'
TOOLS = ('mp-zsb', 'zsb', 'multiprompt-browser')
BOOTSTRAP = 'import base64,sys;s=base64.b64decode(sys.stdin.buffer.readline()).decode();exec(compile(s,"<agent-host>","exec"),dict(__name__="__main__",READER_SOURCE=s))'

FAKE_APP = r'''
import base64
import json
import os
from pathlib import Path
import socket

host = os.environ["FAKE_HOST"]
session = os.environ["FAKE_SESSION"]
log = Path(os.environ["FAKE_LOG"])
directory = Path("/tmp/mp-notify-" + str(os.getuid()))
directory.mkdir(mode=0o700, exist_ok=True)
directory.chmod(0o700)
endpoint = directory / "mp-fake-app.sock"
if endpoint.exists():
    endpoint.unlink()
server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(str(endpoint))
server.listen(16)
screens = {}
layout = {"ok": True, "workspaces": [{"name": "W", "tabs": [
    {"id": 11, "host": host, "tmux": session},
    {"id": 12, "host": host, "tmux": "owner-terminal-chat"}], "groups": []}]}


def answer(conn, message):
    if message.startswith(b"ZSBWHO:"):
        name = bytes.fromhex(message[7:].split(b"\n", 1)[0].decode())
        conn.sendall((json.dumps(dict(has_tab=name == session.encode(), idle_ms=0, host=host)) + "\n").encode())
        return
    if not message.startswith(b"ZSB:"):
        return
    wire = message[4:].rstrip(b"\n")
    name, payload = wire.split(b":", 1)
    args = base64.b64decode(payload, validate=True).decode().rstrip("\x1f").split("\x1f")
    with log.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps({"session": name.decode(), "args": args}) + "\n")
    if args[0] == "workspace-list":
        conn.sendall((json.dumps(layout) + "\n").encode())
        return
    if args[0] == "open":
        conn.sendall(b"ok")
        return
    page = screens.setdefault(name, {"pane": "pane-" + name.decode(), "url": "", "text": ""})
    if args[0] == "navigate":
        page["url"] = args[1]
        page["text"] = page["pane"] + " loaded " + args[1]
        reply = {"ok": True, "result": {}}
    elif args[0] in ("text", "get-text", "snapshot"):
        reply = {"ok": True, "result": {"text": page["text"], "url": page["url"]}}
    else:
        reply = {"ok": True, "result": {"ok": True, "pane": page["pane"], "url": page["url"]}}
    conn.sendall((json.dumps(reply) + "\n").encode())


while True:
    client, _ = server.accept()
    with client:
        data = bytearray()
        while b"\n" not in data and len(data) < 65536:
            chunk = client.recv(4096)
            if not chunk:
                break
            data.extend(chunk)
        answer(client, bytes(data))
'''

STALE_LISTENER = r'''
import socket
server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(("127.0.0.1", 0))
server.listen(4)
print(server.getsockname()[1], flush=True)
while True:
    client, _ = server.accept()
    client.recv(4096)
    client.close()
'''

DRIVER = r'''
import json
from pathlib import Path
import sys
import types
outer = {}
exec(compile(Path(sys.argv[1]).read_text(), "reader", "exec"), outer)
runtime = {}
exec(compile(outer["READER_SOURCE"], "runtime", "exec"), runtime)
runtime["HOME"] = Path(sys.argv[2])
runtime["host_write"](runtime["host_paths"]("claude", "mubo-286")["config"],
                      dict(enabled=True, cwd=sys.argv[3], tmux=sys.argv[4]))
path = runtime["host_owner_session_register"]("claude", "mubo-286", sys.argv[5])
captured = {}
def popen(args, **kwargs):
    captured["args"] = args
    return types.SimpleNamespace(pid=1, stdin=None, stdout=None)
runtime["subprocess"].Popen = popen
runtime["subprocess"].run = lambda *args, **kwargs: types.SimpleNamespace(returncode=0)
runtime["host_agent_start"]("claude", "mubo-286")
launch = captured.get("args") or []
print(json.dumps(dict(endpoint=runtime["host_owner_browser_endpoint"](),
                      registry=str(path) if path else None,
                      session=runtime["host_chat_name"]("claude", "mubo-286"),
                      delegation=[value for value in launch if value.split("=", 1)[0] in
                                  ("ZSB_SOCKET", "ZSB_SESSION", "MULTIBOT_SESSION", "MULTIPROMPT_TAB", "HOME")],
                      owner=launch[4] if len(launch) > 4 else None)))
'''

RUNTIME_PROBE = r'''
import hashlib
import json
import os
from pathlib import Path
runtime = Path(os.path.expanduser("~/.multiprompt-runtime"))
report = {}
for name in os.environ["PROBE_TOOLS"].split(","):
    link = runtime / name
    entry = {"symlink": link.is_symlink()}
    if entry["symlink"]:
        target = runtime / os.readlink(link)
        entry["sha256"] = hashlib.sha256(target.read_bytes()).hexdigest()
        entry["executable"] = os.access(link, os.X_OK)
    report[name] = entry
print(json.dumps(report))
'''


def sudo(*args, **kwargs):
    return subprocess.run(['sudo', '-n', *args], capture_output=True, text=True, **kwargs)


def socket_ready(path):
    return sudo('test', '-S', str(path)).returncode == 0


def account(name):
    try:
        return pwd.getpwnam(name)
    except KeyError:
        return None


class OwnerChatBrowserTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.created = []
        cls.processes = []
        cls.registry = None
        cls.runtime = None
        cls.install = None
        cls.driver = None
        if shutil.which('sudo') is None or sudo('true').returncode:
            raise unittest.SkipTest('needs root or passwordless sudo to create a second OS user')
        for name in (BRIDGE, OWNER):
            if account(name) is None:
                result = sudo('useradd', '-m', '-s', '/bin/bash', name)
                if result.returncode:
                    raise unittest.SkipTest('cannot create a second OS user: ' + (result.stderr or result.stdout))
                cls.created.append(name)
        cls.bridge = account(BRIDGE)
        cls.owner = account(OWNER)
        cls.temp = Path(tempfile.mkdtemp(prefix='mubo286-owner-'))
        for name, body in (('user_browser.py', (ROOT / 'tools/agent-notifications/user_browser.py').read_text()),
                           ('mp_notify_relay.py', (ROOT / 'tools/agent-notifications/mp_notify_relay.py').read_text()),
                           ('fake_app.py', FAKE_APP), ('stale_listener.py', STALE_LISTENER),
                           ('driver.py', DRIVER), ('probe.py', RUNTIME_PROBE),
                           ('chat_history_reader.py', (ROOT / 'src/chat_history_reader.py').read_text())):
            path = cls.temp / name
            path.write_text(body)
            path.chmod(0o644)
        cls.temp.chmod(0o755)
        cls.log = cls.temp / 'fake-app.log'
        cls.log.write_text('')
        cls.log.chmod(0o666)
        cls.stale_source = cls.temp / 'stale-copy'
        cls.stale_source.write_text(STALE_COPY)
        cls.stale_source.chmod(0o755)
        sudo('chown', '-R', BRIDGE + ':' + BRIDGE, str(cls.temp))
        cls.stale_copy = Path(cls.owner.pw_dir) / '.local/bin/zsb'
        sudo('install', '-d', '-m', '755', '-o', OWNER, '-g', OWNER, str(cls.stale_copy.parent))
        sudo('install', '-m', '755', '-o', OWNER, '-g', OWNER, str(cls.stale_source), str(cls.stale_copy))
        cls.app_socket = Path('/tmp/mp-notify-' + str(cls.bridge.pw_uid) + '/mp-fake-app.sock')
        cls.broker_socket = Path('/tmp/mp-browser-' + str(cls.bridge.pw_uid) + '/control.sock')
        try:
            cls.run_as(BRIDGE, 'fake_app.py', FAKE_HOST=HOST, FAKE_SESSION=SESSION, FAKE_LOG=str(cls.log))
            cls.run_as(BRIDGE, 'user_browser.py', MP_BROWSER_HOST=HOST)
            deadline = time.time() + 30
            while time.time() < deadline and not (socket_ready(cls.app_socket) and socket_ready(cls.broker_socket)):
                time.sleep(0.1)
            if not (socket_ready(cls.app_socket) and socket_ready(cls.broker_socket)):
                raise AssertionError('the owner browser broker or its app socket never came up')
            cls.driver = subprocess.run(['sudo', '-n', '-H', '-u', BRIDGE, 'python3', str(cls.temp / 'driver.py'),
                                         str(cls.temp / 'chat_history_reader.py'), cls.bridge.pw_dir,
                                         cls.owner.pw_dir, SESSION, OWNER],
                                        capture_output=True, text=True, timeout=120)
            if cls.driver.returncode == 0:
                cls.registry = json.loads(cls.driver.stdout.strip().splitlines()[-1])
            source_text = cls.runtime_source()
            feed = base64.b64encode(source_text.encode()).decode() + '\n' + json.dumps({'id': 7, 'op': 'engine_info'}) + '\n'
            cls.install = subprocess.run(['sudo', '-n', '-H', '-u', OWNER, 'python3', '-u', '-c', BOOTSTRAP, '--serve'],
                                         input=feed, capture_output=True, text=True, timeout=120)
            probe = sudo('-H', '-u', OWNER, '/usr/bin/env', 'PROBE_TOOLS=' + ','.join(TOOLS),
                         'python3', str(cls.temp / 'probe.py'))
            cls.runtime = json.loads(probe.stdout.strip().splitlines()[-1]) if probe.returncode == 0 else None
        except BaseException:
            cls.tearDownClass()
            raise

    @classmethod
    def runtime_source(cls):
        sources = (('MP_SEND_SOURCE', 'src/mp_send.py'), ('FEEDBACK_SOURCE', 'src/multibot_feedback.py'),
                   ('MP_FRESH_SOURCE', 'src/mp_fresh.py'), ('MP_HELPER_SOURCE', 'src/mp_helper.py'),
                   ('MP_SHELL_SOURCE', 'src/mp_shell.py'), ('MP_SESSIONS_SOURCE', 'src/mp_sessions.py'),
                   ('MP_LAYOUT_SOURCE', 'src/mp_layout.mjs'), ('ZSB_SOURCE', 'src/mp_zsb.sh'))
        prelude = ''.join("%s = '%s'\n" % (name, base64.b64encode((ROOT / file).read_bytes()).decode())
                          for name, file in sources if (ROOT / file).is_file())
        return prelude + (ROOT / 'src/chat_history_reader.py').read_text()

    @classmethod
    def run_as(cls, user, script, **env):
        home = account(user).pw_dir
        command = ['sudo', '-n', '-H', '-u', user, '/usr/bin/env', '-i', 'HOME=' + home, 'USER=' + user,
                   'PATH=/usr/bin:/bin', *[key + '=' + value for key, value in env.items()],
                   'python3', str(cls.temp / script)]
        process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True)
        cls.processes.append(process)
        return process

    @classmethod
    def tearDownClass(cls):
        for process in getattr(cls, 'processes', []):
            if process.poll() is None:
                process.kill()
                process.wait(10)
            process.stdout.close()
        temp = getattr(cls, 'temp', None)
        if temp is not None:
            sudo('rm', '-rf', str(temp))
        bridge = account(BRIDGE)
        if bridge is not None:
            sudo('rm', '-rf', '/tmp/mp-browser-' + str(bridge.pw_uid), '/tmp/mp-notify-' + str(bridge.pw_uid))
        for name in getattr(cls, 'created', []):
            sudo('pkill', '-9', '-u', name)
            sudo('userdel', '-r', '-f', name)

    def zsb(self, *args, session=SESSION, env=None):
        values = {'HOME': self.owner.pw_dir, 'USER': OWNER,
                  'PATH': self.owner.pw_dir + '/.multiprompt-runtime:/usr/bin:/bin',
                  'MULTIBOT_PROVIDER': 'claude', 'MULTIBOT_SESSION': session, 'ZSB_SESSION': session,
                  'MULTIPROMPT_TAB': session, 'ZSB_SOCKET': str(self.broker_socket), 'ZSB_TIMEOUT': '30'}
        values.update(env or {})
        command = ['sudo', '-n', '-H', '-u', OWNER, '/usr/bin/env', '-i',
                   *[key + '=' + value for key, value in values.items()], 'zsb', *args]
        return subprocess.run(command, capture_output=True, text=True, timeout=120)

    def test_second_user_chat_reaches_its_own_pane(self):
        self.assertIsNotNone(self.install)
        self.assertEqual(self.install.returncode, 0, self.install.stderr or self.install.stdout)
        self.assertIsNotNone(self.runtime, 'the owner runtime published no browser CLI')
        shipped = hashlib.sha256((ROOT / 'src/mp_zsb.sh').read_bytes()).hexdigest()
        for name in TOOLS:
            with self.subTest(tool=name):
                entry = self.runtime[name]
                self.assertTrue(entry['symlink'], name + ' is missing from the current runtime')
                self.assertEqual(entry['sha256'], shipped, name + ' is not the shipped browser CLI')
                self.assertTrue(entry['executable'], name + ' does not run')
        self.assertNotEqual(self.runtime['mp-zsb']['sha256'], hashlib.sha256(STALE_COPY.encode()).hexdigest())
        opened = self.zsb('navigate', PAGE)
        self.assertEqual(opened.returncode, 0, opened.stdout + opened.stderr)
        self.assertNotIn('stale-copy-answered', opened.stdout)
        read = self.zsb('text', '--full')
        self.assertEqual(read.returncode, 0, read.stdout + read.stderr)
        page = json.loads(read.stdout)['result']
        self.assertIn('pane-' + SESSION, page['text'])
        self.assertIn(PAGE, page['text'])
        self.assertEqual(page['url'], PAGE)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertIn({'session': SESSION, 'args': ['navigate', PAGE]}, calls)
        self.assertNotIn('zss-11', self.log.read_text())
        foreign = self.zsb('text', '--full', session=FOREIGN)
        self.assertNotEqual(foreign.returncode, 0)
        self.assertEqual(json.loads(foreign.stdout)['error'], 'owner_scope_denied')

    def test_delegation_registers_the_chat_and_its_relay(self):
        self.assertEqual(self.driver.returncode, 0, self.driver.stderr or self.driver.stdout)
        self.assertIsNotNone(self.registry, 'the delegation path registered no hosted session')
        self.assertEqual(self.registry['endpoint'], str(self.broker_socket))
        self.assertEqual(self.registry['session'], SESSION)
        self.assertEqual(self.registry['owner'], OWNER)
        self.assertIn('ZSB_SOCKET=' + self.registry['endpoint'], self.registry['delegation'])
        self.assertIn('ZSB_SESSION=' + SESSION, self.registry['delegation'])
        self.assertIn('MULTIPROMPT_TAB=' + SESSION, self.registry['delegation'])
        self.assertTrue(self.registry['registry'])
        record = json.loads(sudo('cat', self.registry['registry']).stdout)
        self.assertEqual(record['session'], SESSION)
        self.assertEqual(record['uid'], self.owner.pw_uid)
        self.assertIsInstance(record['at'], (int, float))
        self.assertEqual(sudo('stat', '-c', '%a %U', self.registry['registry']).stdout.split(), ['600', BRIDGE])

    def test_stale_process_on_the_pane_port_is_named_not_tunnel_down(self):
        listener = self.run_as(OWNER, 'stale_listener.py')
        try:
            port = listener.stdout.readline().strip()
            self.assertTrue(port.isdigit(), 'the stale listener never reported its port')
            result = self.zsb('status', env={'ZSB_PORT': port, 'ZSB_SOCKET': '',
                                             'MULTIPROMP_NOTIFY_RELAY_TOKEN': 'stale-holder-test',
                                             'MULTIBOT_SESSION': '', 'MULTIPROMPT_TAB': ''})
        finally:
            listener.kill()
            listener.wait(10)
        reply = json.loads(result.stdout)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(reply['error'], 'port_conflict', result.stdout + result.stderr)
        self.assertGreater(reply['holder']['pid'], 0)
        self.assertIn('stale_listener.py', reply['holder']['command'])
        self.assertIn(str(port), reply['message'])
        self.assertIn('not by the Multiprompt SSH tunnel', reply['message'])

    def test_missing_owner_relay_is_named(self):
        result = self.zsb('status', env={'ZSB_SOCKET': '/tmp/mp-browser-4294967/control.sock'})
        reply = json.loads(result.stdout)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(reply['error'], 'relay_unavailable', result.stdout + result.stderr)
        self.assertIn('/tmp/mp-browser-4294967/control.sock', reply['message'])
        self.assertIn('install-owner-browser.sh', reply['message'])


if __name__ == '__main__':
    unittest.main()
