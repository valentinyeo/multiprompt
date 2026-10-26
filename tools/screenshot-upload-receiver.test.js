const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const receiver = path.join(__dirname, 'screenshot-upload-receiver.mjs');
const png = Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), Buffer.from('payload')]);

async function withReceiver(run) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'receiver-'));
  const portFile = path.join(dir, 'port.txt');
  const child = spawn(process.execPath, [receiver, portFile, dir, 'secret-1'], { stdio: 'ignore' });
  try {
    for (let i = 0; i < 100 && !fs.existsSync(portFile); i += 1) await new Promise(resolve => setTimeout(resolve, 50));
    const base = `http://127.0.0.1:${fs.readFileSync(portFile, 'utf8')}`;
    await run(base, dir);
  } finally {
    child.kill();
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

const upload = (base, body, secret = 'secret-1') =>
  fetch(`${base}/api/upload-screenshot`, { method: 'POST', headers: { Authorization: `Bearer ${secret}` }, body });

test('IGSH-894 each accepted PNG upload gets the next numbered link and is counted', async () => {
  await withReceiver(async (base, dir) => {
    const first = await (await upload(base, png)).json();
    const second = await (await upload(base, png)).json();
    assert.deepEqual(first, { success: true, url: 'https://example.invalid/shot-1.png' });
    assert.equal(second.url, 'https://example.invalid/shot-2.png');
    const lines = fs.readFileSync(path.join(dir, 'uploads.jsonl'), 'utf8').trim().split('\n');
    assert.equal(lines.length, 2);
  });
});

test('IGSH-894 uploads with a wrong secret or without a PNG are refused and not counted', async () => {
  await withReceiver(async (base, dir) => {
    assert.equal((await upload(base, png, 'wrong')).status, 401);
    assert.equal((await upload(base, Buffer.from('not an image'))).status, 400);
    assert.equal(fs.existsSync(path.join(dir, 'uploads.jsonl')), false);
  });
});
