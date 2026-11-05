const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const { spawn, spawnSync } = require('node:child_process');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

function runtime() {
  const outer = spawnSync('python3', ['-c', `import sys;o={};exec(compile(sys.stdin.read(),'r','exec'),o);sys.stdout.write(o['READER_SOURCE'])`], { input: source, encoding: 'utf8' });
  assert.equal(outer.status, 0, outer.stderr);
  return outer.stdout;
}

function serveWith(home, engineSha, activeSha) {
  fs.mkdirSync(path.join(home, '.multiprompt-runtime'), { recursive: true });
  fs.writeFileSync(path.join(home, '.multiprompt-runtime', 'active.json'), JSON.stringify({ protocol: 1, generation: 1, sha256: activeSha }));
  const program = `ENGINE_INFO = ${JSON.stringify({ protocol: 1, generation: 1, sha256: engineSha })}\n` + runtime();
  const file = path.join(home, 'serve.py');
  fs.writeFileSync(file, program);
  const child = spawn('python3', ['-u', file, '--serve'], { env: { ...process.env, HOME: home }, stdio: ['pipe', 'ignore', 'pipe'] });
  return new Promise(resolve => {
    const timer = setTimeout(() => { child.kill(); resolve('alive'); }, 6000);
    child.on('exit', () => { clearTimeout(timer); resolve('exited'); });
  });
}

test('a serve link retires once another runtime becomes active, and stays while it is current', async () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'serve-retire-'));
  try {
    const a = 'a'.repeat(64);
    assert.equal(await serveWith(home, a, 'b'.repeat(64)), 'exited', 'superseded serve link must exit so the desktop reconnects on the active runtime');
    assert.equal(await serveWith(home, a, a), 'alive', 'current serve link must keep running');
  } finally {
    fs.rmSync(home, { recursive: true, force: true });
  }
});
