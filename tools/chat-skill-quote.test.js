const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

const skillWire = '/pstack:poteto-help why did this arrive as plain text?\n> the earlier answer\n\nand a following line';
const plainWire = '> the earlier answer\n\nmy answer';
const midSentenceWire = 'why is this not done via /valentin-mode ?';

test('MUBO-457, MUBO-491 a hosted chat starts a skill above a quote or mid-sentence, idle or busy', () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'skill-quote-'));
  try {
    const program = String.raw`
import io, json, sys
from types import SimpleNamespace
outer = {}
exec(compile(sys.stdin.read(), 'reader', 'exec'), outer)
r = {'__name__': 'probe'}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)

def deliver(session, text):
    stream = io.BytesIO()
    session['agent'] = SimpleNamespace(stdin=stream)
    assert r['host_claude_write']('claude', 'fixture', session, 'message-token', text)
    return json.loads(stream.getvalue())

def agent_text(payload):
    assert payload['type'] == 'user', payload
    return payload['message']['content'][0]['text']

skill, plain, mid = sys.argv[1], sys.argv[2], sys.argv[3]
idle = dict(state=dict())
busy = dict(state=dict(), turn='t-1', sends=[dict(id='mp-old', text='an earlier question')],
            inflight=dict(id='mp-old'))
for session in (idle, busy):
    text = agent_text(deliver(session, skill))
    assert text.startswith('/pstack:poteto-help why did this arrive as plain text?\n> the earlier answer'), text
    assert text.endswith('and a following line'), text
for session in (idle, busy):
    text = agent_text(deliver(session, plain))
    assert text == plain, text
for session in (idle, busy):
    text = agent_text(deliver(session, mid))
    assert text == mid, text
    assert '/valentin-mode' in text.split(), text
print('SKILL_QUOTE_SKILL_FIRST')
`;
    const run = spawnSync('python3', ['-c', program, skillWire, plainWire, midSentenceWire], { input: source, encoding: 'utf8', timeout: 30000, env: { ...process.env, HOME: home } });
    assert.equal(run.status, 0, run.stderr || run.stdout);
    assert.match(run.stdout, /SKILL_QUOTE_SKILL_FIRST/);
  } finally {
    fs.rmSync(home, { recursive: true, force: true });
  }
});
