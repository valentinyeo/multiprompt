const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

test('a message with a /word in a folder the host cannot open is sent as typed', () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'skill-unreadable-'));
  try {
    const program = String.raw`
import sys
from pathlib import Path
outer = {}
exec(compile(sys.stdin.read(), 'reader', 'exec'), outer)
r = {'__name__': 'probe'}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
locked = '/home/other/projects/locked'
real = Path.is_file
def is_file(self):
    if str(self).startswith(locked):
        raise PermissionError(13, 'Permission denied', str(self))
    return real(self)
Path.is_file = is_file
text = 'on vstack copy the skills /do and /deep-work and /responsive-mode pls'
got = r['host_claude_lead_skill'](text, locked)
assert got == text, got
print('sent as typed')
`;
    const result = spawnSync('python3', ['-c', program], { input: source, encoding: 'utf8', timeout: 30000, env: { ...process.env, HOME: home } });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.match(result.stdout, /sent as typed/);
  } finally {
    fs.rmSync(home, { recursive: true, force: true });
  }
});
