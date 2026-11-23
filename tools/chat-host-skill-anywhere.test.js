const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

test('SOFT-3086 the agent receives slash skills exactly where the user typed them', () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'skill-position-'));
  try {
    const program = String.raw`
import io, json, sys
from pathlib import Path
from types import SimpleNamespace
outer = {}
exec(compile(sys.stdin.read(), 'reader', 'exec'), outer)
r = {'__name__': 'probe'}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
home = Path(sys.argv[1])
skill = home / '.claude' / 'plugins' / 'cache' / 'market' / 'pstack' / '1.0' / 'skills' / 'poteto-mode'
skill.mkdir(parents=True)
(skill / 'SKILL.md').write_text('---\nname: poteto-mode\ndisable-model-invocation: true\n---\n')
own = home / '.claude' / 'skills' / 'house-rules'
own.mkdir(parents=True)
(own / 'SKILL.md').write_text('x')
project = home / 'work'
(project / '.claude' / 'commands').mkdir(parents=True)
(project / '.claude' / 'commands' / 'ship.md').write_text('x')
r['host_config'] = lambda *args: dict(cwd=str(project))
cases = [
    'why is this not done via /house-rules ?',
    'fix the pile up /pstack:poteto-mode',
    'runners /house-rules should stay /pstack:poteto-mode',
    'please /ship it',
    'keep  /house-rules\t exactly',
    'first line\n/house-rules',
    ' /house-rules',
    '/pstack:poteto-mode already first',
    '/house-rules',
    '/ship it',
    'open /home/user/file and /pstack:missing-skill',
    'see https://x.test/a:b and /tmp',
]
for fresh in (False, True):
    for text in cases:
        stream = io.BytesIO()
        session = dict(state=dict(fresh_start=fresh), agent=SimpleNamespace(stdin=stream))
        assert r['host_claude_write']('claude', 'fixture', session, 'message-token', text)
        sent = json.loads(stream.getvalue())
        assert sent['type'] == 'user', sent
        assert sent['message'] == dict(role='user', content=[dict(type='text', text=text)]), (text, sent)
print('slash positions and whitespace preserved in agent input')
`;
    const result = spawnSync('python3', ['-c', program, home], { input: source, encoding: 'utf8', timeout: 30000, env: { ...process.env, HOME: home } });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.match(result.stdout, /slash positions and whitespace preserved in agent input/);
  } finally {
    fs.rmSync(home, { recursive: true, force: true });
  }
});
