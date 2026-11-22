const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

test('a live chat loads its history from the folder its host runs in, whatever folder the app sends', () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'history-cwd-'));
  try {
    const program = String.raw`
import json, sys
from pathlib import Path
outer = {}
exec(compile(sys.stdin.read(), 'reader', 'exec'), outer)
r = {'__name__': 'probe'}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
home = Path(sys.argv[1])
real = home / 'projects' / 'real'
real.mkdir(parents=True)
sid = '11111111-2222-4333-8444-555555555555'
folder = home / '.claude' / 'projects' / str(real).replace('/', '-')
folder.mkdir(parents=True)
(folder / (sid + '.jsonl')).write_text(json.dumps(dict(type='user', sessionId=sid, cwd=str(real), uuid='u1', timestamp='2026-11-05T00:00:00Z', message=dict(role='user', content='hello from the host folder'))) + '\n')
r['host_write'](r['host_paths']('claude', sid)['config'], dict(enabled=True, cwd=str(real)))
for sent in ('~/projects/real', str(home / 'projects' / 'elsewhere'), ''):
    out = r['response'](dict(id=1, sid=sid, tmux='live-abc', cwd=sent, codex=False, offset=0, cached_sid='', inode=0))
    assert 'hello from the host folder' in out, (sent, out[:300])
print('history follows the host folder')
`;
    const result = spawnSync('python3', ['-c', program, home], { input: source, encoding: 'utf8', timeout: 30000, env: { ...process.env, HOME: home } });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.match(result.stdout, /history follows the host folder/);
  } finally {
    fs.rmSync(home, { recursive: true, force: true });
  }
});
