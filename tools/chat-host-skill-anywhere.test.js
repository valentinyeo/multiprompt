const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

test('a live chat message that names an installed skill anywhere starts with that skill', () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'skill-anywhere-'));
  try {
    const program = String.raw`
import json, sys
from pathlib import Path
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
lead = r['host_claude_lead_skill']
cases = [
    ('fix the pile up /pstack:poteto-mode', None, '/pstack:poteto-mode fix the pile up'),
    ('runners /house-rules should stay /pstack:poteto-mode', None, '/pstack:poteto-mode runners /house-rules should stay'),
    ('runners /house-rules should stay', None, '/house-rules runners should stay'),
    ('please /ship it', str(project), '/ship please it'),
    ('/pstack:poteto-mode already first', None, '/pstack:poteto-mode already first'),
    ('open /home/user/file and /pstack:missing-skill', None, 'open /home/user/file and /pstack:missing-skill'),
    ('see https://x.test/a:b and /tmp', None, 'see https://x.test/a:b and /tmp'),
    ('/pstack:poteto-mode', None, '/pstack:poteto-mode'),
]
for text, cwd, want in cases:
    got = lead(text, cwd)
    assert got == want, (text, got)
print('skills lead the message')
`;
    const result = spawnSync('python3', ['-c', program, home], { input: source, encoding: 'utf8', timeout: 30000, env: { ...process.env, HOME: home } });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.match(result.stdout, /skills lead the message/);
  } finally {
    fs.rmSync(home, { recursive: true, force: true });
  }
});

test('the claude host writes the skill-led text', () => {
  const start = source.indexOf('def host_claude_write(');
  const body = source.slice(start, source.indexOf('\ndef ', start + 5));
  assert.match(body, /host_claude_lead_skill\(text,/);
});
