const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

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

test('IGSH-1507 storage page reports existing state without writing it', async () => {
  await withReceiver(async base => {
    const response = await fetch(`${base}/signin-storage`);
    assert.equal(response.status, 200);
    assert.match(response.headers.get('content-type'), /^text\/html/);
    const html = await response.text();
    const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
    for (const [value, cookie, expected] of [
      ['synthetic-proof', 'other=x; mp_signin_proof=synthetic-proof', 'mp_signin_proof=synthetic-proof; cookie-match=true'],
      ['synthetic-proof', 'mp_signin_proof=wrong', 'mp_signin_proof=synthetic-proof; cookie-match=false'],
      [null, '', 'mp_signin_proof=null; cookie-match=false'],
    ]) {
      const document = { title: '', get cookie() { return cookie; }, set cookie(_) { throw new Error('cookie write'); } };
      const localStorage = { getItem(key) { assert.equal(key, 'mp_signin_proof'); return value; }, setItem() { throw new Error('storage write'); } };
      vm.runInNewContext(script, { document, localStorage });
      assert.equal(document.title, expected);
    }
    assert.equal((await fetch(`${base}/signin-storage`, { method: 'POST' })).status, 404);
    assert.equal((await fetch(`${base}/other`)).status, 404);
    assert.equal((await fetch(`${base}/api/upload-screenshot`)).status, 404);
  });
});

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
