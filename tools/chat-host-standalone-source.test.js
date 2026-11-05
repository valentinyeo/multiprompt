const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

test('a standalone host still has its reader source for another-user starts', () => {
  const outer = spawnSync('python3', ['-c', `import sys;o={};exec(compile(sys.stdin.read(),'r','exec'),o);sys.stdout.write(o['READER_SOURCE'])`], { input: source, encoding: 'utf8' });
  assert.equal(outer.status, 0, outer.stderr);
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'standalone-reader-'));
  const runtime = path.join(directory, 'reader.py');
  fs.writeFileSync(runtime, outer.stdout);
  const program = String.raw`
import sys
r = {'__name__': 'standalone', '__file__': sys.argv[1]}
exec(compile(open(sys.argv[1]).read(), sys.argv[1], 'exec'), r)
assert 'READER_SOURCE' not in r
text = r['host_reader_source']()
assert text == open(sys.argv[1]).read(), 'standalone source missing'
r['READER_SOURCE'] = 'embedded'
assert r['host_reader_source']() == 'embedded'
print('standalone source available')
`;
  const result = spawnSync('python3', ['-c', program, runtime], { encoding: 'utf8', timeout: 30000 });
  fs.rmSync(directory, { recursive: true, force: true });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /standalone source available/);
});
