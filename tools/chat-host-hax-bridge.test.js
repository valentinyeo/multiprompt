const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

const fakeHax = String.raw`#!/usr/bin/env python3
import json, os, sys, time, uuid
from pathlib import Path
args = sys.argv[1:]
resume = next((a.split('=', 1)[1] for a in args if a.startswith('--resume=')), None)
text = sys.stdin.read()
if text == 'hello':
    deadline = time.monotonic() + 10
    while not Path(os.environ['HAX_BRIDGE_TEST_RELEASE']).exists():
        if time.monotonic() > deadline:
            raise RuntimeError('Test prompt was never released')
        time.sleep(0.01)
sid = resume or str(uuid.uuid4())
for record in (dict(type='session', id=sid), dict(kind='user', text=text),
               dict(kind='tool_call', call_id='c1', tool_name='bash', arguments='{"command":"true"}'),
               dict(kind='tool_result', call_id='c1', output='ok'),
               dict(kind='assistant', text='resumed=' + str(bool(resume)) + ' args=' + ' '.join(a for a in args if not a.startswith('--resume'))),
               dict(type='result', outcome='complete', session_id=sid)):
    print(json.dumps(record), flush=True)
`;

test('hax bridge runs one turn per prompt, resumes the same hax chat, and refuses a prompt mid-run', () => {
  const extract = spawnSync('python3', ['-c', `import sys;o={};exec(compile(sys.stdin.read(),'r','exec'),o);r={'__name__':'x'};exec(compile(o['READER_SOURCE'],'rt','exec'),r);sys.stdout.write(r['HOST_HAX_BRIDGE'])`], { input: source, encoding: 'utf8' });
  assert.equal(extract.status, 0, extract.stderr);
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'hax-bridge-'));
  try {
    const hax = path.join(directory, 'hax');
    fs.writeFileSync(hax, fakeHax, { mode: 0o755 });
    const bridge = path.join(directory, 'bridge.py');
    const holdCompletedWorker = String.raw`
import threading
release = threading.Event()
starts = 0
class HeldThread(threading.Thread):
    def start(self):
        global starts
        starts += 1
        self.first = starts == 1
        if starts == 2:
            release.set()
        super().start()
    def run(self):
        super().run()
        if self.first:
            release.wait(10)
threading.Thread = HeldThread
`;
    fs.writeFileSync(bridge, holdCompletedWorker + extract.stdout);
    const driver = String.raw`
import json, os, subprocess, sys
from pathlib import Path
release = Path(sys.argv[1] + '.release')
release.unlink(missing_ok=True)
p = subprocess.Popen(['python3', '-u', sys.argv[1], sys.argv[2], '--provider=codex'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, env=dict(os.environ, HAX_BRIDGE_TEST_RELEASE=str(release)))
def send(o):
    p.stdin.write(json.dumps(o) + '\n'); p.stdin.flush()
def until_end():
    seen = []
    for line in p.stdout:
        event = json.loads(line); seen.append(event)
        if event['type'] == 'bridge_busy':
            raise AssertionError('bridge_busy_after_completion')
        if event['type'] == 'bridge_end':
            return seen
try:
    send(dict(type='prompt', id='first', message='hello'))
    start = json.loads(p.stdout.readline())
    assert start['type'] == 'bridge_start'
    send(dict(type='prompt', id='blocked', message='not yet'))
    busy = json.loads(p.stdout.readline())
    assert busy == dict(type='bridge_busy', id='blocked'), busy
    release.touch()
    first = [start] + until_end()
    send(dict(type='prompt', id='second', message='again'))
    second = until_end()
    p.stdin.close(); p.wait(timeout=10)
    print(json.dumps(dict(first=first, second=second)))
finally:
    if p.poll() is None:
        p.terminate(); p.wait(timeout=10)
`;
    const result = spawnSync('python3', ['-c', driver, bridge, hax], { encoding: 'utf8', timeout: 30000 });
    assert.equal(result.status, 0, result.stderr);
    const { first, second } = JSON.parse(result.stdout);
    assert.equal(first[0].type, 'bridge_start', 'a run starts before any hax record');
    const reply = turn => turn.filter(e => e.type === 'hax' && e.record.kind === 'assistant').map(e => e.record.text)[0];
    assert.equal(reply(first), 'resumed=False args=--provider=codex --json');
    assert.equal(reply(second), 'resumed=True args=--provider=codex --json', 'second prompt resumes the hax chat');
    assert.equal(first.at(-1).outcome, 'complete');
    assert.equal(first.at(-1).session, second.at(-1).session, 'both turns share one hax session');
    assert.ok(first.some(e => e.type === 'hax' && e.record.kind === 'tool_call'), 'tool calls pass through');
    fs.writeFileSync(bridge, holdCompletedWorker + fs.readFileSync(path.join(__dirname, 'fixtures/igsh-1763/bridge-before.py'), 'utf8'));
    const red = spawnSync('python3', ['-c', driver, bridge, hax], { encoding: 'utf8', timeout: 30000 });
    assert.equal(red.status, 1, red.stderr);
    assert.match(red.stderr, /bridge_busy_after_completion/);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('the host refuses a second hax message while a run is active, so it stays queued', () => {
  const deliver = source.slice(source.indexOf('if provider != "claude" and not session.get("ready"):'));
  assert.match(deliver.slice(0, 400), /if provider == "hax" and \(session\["turn"\] is not None or session\["sends"\]\):\n\s+return dict\(status="busy", reason="hax_run_active"\)/);
});
