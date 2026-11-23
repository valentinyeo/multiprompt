const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

function python(program) {
  const input = `outer = {}\nexec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)\nr = {}\nexec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)\n${program}`;
  const result = spawnSync(process.env.PYTHON || 'python3', ['-'], { input, cwd: root, encoding: 'utf8', timeout: 120000, maxBuffer: 8 * 1024 * 1024 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /RESUME_FRESH_PASS/);
}

test('resume child exits before ready starts fresh start and delivers a held send to the new child', () => {
  python(String.raw`
import io, json, selectors, tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
sid = '11111111-2222-4333-8444-555555555555'
r['host_mark_pane'] = lambda *args: True
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    provider, tmux = 'claude', 'same-chat'
    paths = r['host_paths'](provider, sid)
    r['host_write'](paths['config'], dict(enabled=True, tmux=tmux, cwd=directory))
    transcript = Path(directory) / 'chat.jsonl'
    transcript.write_text(''.join(
        json.dumps(dict(type='user', message=dict(role='user', content=[dict(type='text', text='User line ' + str(i))]))) + '\\n' +
        json.dumps(dict(type='assistant', message=dict(role='assistant', content=[dict(type='text', text='Assistant line ' + str(i))]))) + '\\n'
        for i in range(3)))
    state = dict(native_session=sid)
    r['host_write'](paths['state'], state)
    class Agent:
        def __init__(self, tag, native):
            self.tag = tag
            self.pid = 100 if tag == 'old' else 101
            self.stdin = io.BytesIO()
            self.frames = []
            if tag == 'new':
                self.frames = [
                    json.dumps(dict(type='system', subtype='init', session_id=native)).encode() + b'\\n',
                    json.dumps(dict(type='assistant', message=dict(id='handover-ack', role='assistant', content=[dict(type='text', text='Read the handover.')] ))).encode() + b'\\n',
                    json.dumps(dict(type='result', subtype='success')).encode() + b'\\n',
                ]
            self.stdout = SimpleNamespace(read1=lambda size: self.frames.pop(0) if self.frames else (b'' if tag == 'old' else b'\\n'))
        def wait(self, timeout=None):
            return 0
        def kill(self):
            pass
    old = Agent('old', sid)
    steps = ['agent', 'agent']
    class Selector:
        def __enter__(self): return self
        def __exit__(self, *args): pass
        def register(self, *args): pass
        def unregister(self, *args): pass
        def select(self, timeout):
            if not steps:
                session['stop'] = True
                return []
            kind = steps.pop(0)
            return [(SimpleNamespace(data=kind), None)]
    launched = []
    def start(*args):
        native = r['host_session_state'](provider, sid).get('context_session')
        agent = Agent('new', native)
        launched.append(agent)
        return agent
    session = dict(state=r['host_session_state'](provider, sid))
    r['host_session_reset'](session, old)
    with patch.object(selectors, 'DefaultSelector', Selector), patch.dict(r, conversation_path=lambda *a: transcript, host_agent_start=start, host_attempt=lambda *args: dict(status='claimed')):
        r['host_loop'](provider, sid, tmux, session, object(), old)
    assert session['state'].get('resume_fresh_tried')
    assert launched
    session['state'].pop('fresh_start', None)
    session['agent'] = launched[-1]
    session['ready'] = True
    session['inflight'] = None
    session['turn'] = None
    with patch.dict(r, host_attempt=lambda *args: dict(status='claimed')):
        reply = r['host_handle_request'](provider, sid, tmux, session, dict(op='deliver', id='held-after-resume', attempt='one', epoch=1, text='Finish after fresh start'))
    assert reply['status'] == 'sent', reply
    assert 'Finish after fresh start' in launched[-1].stdin.getvalue().decode()
    saved = r['host_read'](paths['root'] / next(paths['root'].glob('*.handover-*.json')).name)
    assert 'could not resume' in saved['text'] or 'User line' in saved['text'] or 'Assistant line' in saved['text'], saved['text'][:200]
    if session.get('db'):
        session['db'].close()
print('RESUME_FRESH_PASS')
`);
});

test('an oversize resume transcript starts fresh start with a generated handover before the child runs', () => {
  python(String.raw`
import json, tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
sid = '22222222-3333-4444-8555-666666666666'
r['host_mark_pane'] = lambda *args: True
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    r['HOST_RESUME_TRANSCRIPT_LIMIT'] = 64
    provider, tmux = 'claude', 'big-chat'
    paths = r['host_paths'](provider, sid)
    r['host_write'](paths['config'], dict(enabled=True, tmux=tmux, cwd=directory))
    transcript = Path(directory) / 'big.jsonl'
    line = (json.dumps(dict(type='assistant', message=dict(role='assistant', content=[dict(type='text', text='Tail context from the huge log')]))) + '\\n').encode()
    transcript.write_bytes(b'x' * 64 + b'\\n' + line)
    state = dict(native_session=sid)
    r['host_write'](paths['state'], state)
    launched = []
    class Agent:
        pid = 77
        stdin = None
        stdout = None
        def wait(self, timeout=None): return 0
    def start(*args):
        launched.append(r['host_claude_argv'](provider, sid, ['claude']))
        cmd = launched[-1]
        assert '--resume' not in cmd and '--session-id' in cmd, cmd
        return Agent()
    session_holder = {}
    def loop(provider, sid, tmux, session, server, agent):
        session_holder.update(session=session)
        fresh = session['state']['fresh_start']
        assert fresh['phase'] == 'resume'
        saved = r['host_read'](paths['root'] / fresh['file'])
        assert saved['text'].strip()
        return
    r['host_mark_pane'] = lambda *args: True
    r['host_reap_agent'] = lambda *args: False
    with patch.dict(r, conversation_path=lambda provider, native, cwd: transcript if native == sid else None, host_agent_start=start, host_loop=loop):
        assert r['host_main'](provider, sid) == 0
    assert launched
    session = session_holder['session']
    assert session['state'].get('resume_fresh_tried')
    if session.get('db'):
        session['db'].close()
print('RESUME_FRESH_PASS')
`);
});

test('a second failed resume marks the held send not sent instead of leaving busy dots', () => {
  python(String.raw`
import io, json, selectors, tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
sid = '33333333-4444-5555-8666-777777777777'
with tempfile.TemporaryDirectory() as directory:
    r['HOME'] = Path(directory)
    provider, tmux = 'claude', 'fail-twice'
    paths = r['host_paths'](provider, sid)
    r['host_write'](paths['config'], dict(enabled=True, tmux=tmux, cwd=directory))
    transcript = Path(directory) / 'small.jsonl'
    transcript.write_text(json.dumps(dict(type='user', message=dict(role='user', content=[dict(type='text', text='old')]))) + '\\n')
    state = dict(native_session=sid, resume_fresh_tried=True,
                 fresh_start=dict(phase='resume', file='saved.json', started=1))
    handover = paths['root'] / 'saved.json'
    handover.parent.mkdir(parents=True, exist_ok=True)
    r['host_write'](handover, dict(text='Handover body'))
    r['host_write'](paths['state'], state)
    r['host_write'](paths['owner'], dict(owner='host', pid=999))
    r['host_fresh_prepare'](provider, sid, state)
    class Agent:
        pid = 55
        def __init__(self):
            self.stdin = io.BytesIO()
            self.stdout = SimpleNamespace(read1=lambda size: b'')
        def wait(self, timeout=None): return 0
        def kill(self): pass
    agent = Agent()
    steps = ['agent']
    class Selector:
        def __enter__(self): return self
        def __exit__(self, *args): pass
        def register(self, *args): pass
        def unregister(self, *args): pass
        def select(self, timeout):
            if not steps:
                return []
            return [(SimpleNamespace(data=steps.pop(0)), None)]
    facts = []
    r['host_apply'] = lambda *args: facts.append(args[-1]) or True
    session = dict(state=r['host_session_state'](provider, sid))
    pending = [dict(id='stuck-send', attempt='one', epoch=1, accepted=False)]
    reset = r['host_session_reset']
    def keep_sends(session, agent=None):
        reset(session, agent)
        session['sends'] = list(pending)
        session['ready'] = False
    r['host_session_reset'] = keep_sends
    keep_sends(session, agent)
    with patch.object(selectors, 'DefaultSelector', Selector), patch.dict(r, conversation_path=lambda *a: transcript, host_attempt=lambda *args: dict(status='claimed')):
        r['host_loop'](provider, sid, tmux, session, object(), agent)
    assert any(item[0].get('kind') == 'not_sent' and item[0].get('id') == 'stuck-send' for item in facts), facts
    if session.get('db'):
        session['db'].close()
print('RESUME_FRESH_PASS')
`);
});