const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
function verify(root) {
  const cache = fs.readFileSync(path.join(__dirname, '../src/launch_cache.zig'), 'utf8');
  const restore = cache.slice(cache.indexOf('pub fn restore()'), cache.indexOf('pub fn painted('));
  assert.doesNotMatch(restore, /kind\s*!=\s*\.tmux/, 'saved remote history must be restored before connection');
  return require('./chat-instant-proof.cjs').verify(root);
}

function fixture(change) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'instant-chat-'));
  const dir = path.join(root, 'instant-chat');
  fs.mkdirSync(path.join(dir, 'stand-in'), { recursive: true });
  const id = suffix => `desktop-${suffix.repeat(32)}`;
  const data = {
    'cleanup.json': { remaining_owned_processes: 0, scratch_removed: true, evidence_preserved: true },
    'observation.json': { error: null },
    'startup-timing.json': { firstPaintMs: 120, startedMs: 100 },
    'startup-frames.json': [{ ms: 90 }, { ms: 220 }],
    'saved-launch.json': { chat: true, blocks: [{ role: 'assistant' }] },
    'offline-outbox.json': { queues: [{ messages: [{ t: 'preconnect first', wire_id: id('a') }, { t: 'preconnect second', wire_id: id('b') }] }] },
    'crash-process-tree.json': { ActiveProcesses: 0 },
    'crash-receipt.json': { pid: 123, stoppedMs: 300, connectionHeld: true },
    'crash-outbox.json': { queues: [{ messages: [{ t: 'preconnect first', wire_id: id('a') }, { t: 'preconnect second', wire_id: id('b') }] }] },
    'reloaded-receipt.json': { pid: 456, hwnd: 789, startedMs: 400, connectionHeld: true },
    'reloaded-outbox.json': { queues: [{ messages: [{ t: 'preconnect first', wire_id: id('a') }, { t: 'preconnect second', wire_id: id('b') }] }] },
    'store-before.json': [],
    'store-after.json': [{ text: 'preconnect first', id: id('a'), position: 1 }, { text: 'preconnect second', id: id('b'), position: 2 }],
    'delivery-timing.json': { releasedMs: 500, receivedMs: 700 },
  };
  if (change) change(data);
  for (const [name, value] of Object.entries(data)) fs.writeFileSync(path.join(dir, name), JSON.stringify(value));
  fs.writeFileSync(path.join(dir, 'offline-copied.txt'), 'The fake session is ready.');
  fs.writeFileSync(path.join(dir, 'reloaded-copied.txt'), 'preconnect first\npreconnect second');
  fs.writeFileSync(path.join(dir, 'debug.log'), 'launch cached-chat rows=1 active=1 blocks=2');
  fs.writeFileSync(path.join(dir, 'stand-in/connection-waits.jsonl'), '{"ms":400}\n');
  fs.writeFileSync(path.join(root, 'instant-startup.gif'), 'GIF89a');
  const png = Buffer.alloc(1100);
  Buffer.from('89504e470d0a1a0a', 'hex').copy(png);
  for (const frame of ['instant-first-paint', 'instant-buffered', 'instant-reloaded', 'instant-delivered']) fs.writeFileSync(path.join(root, `${frame}.png`), png);
  return { root, close: () => fs.rmSync(root, { recursive: true, force: true }) };
}

test('instant-chat oracle accepts complete startup, outbox and store evidence', () => {
  const f = fixture();
  try { assert.deepEqual(verify(f.root), { firstPaintMs: 120, messages: 2 }); } finally { f.close(); }
});

for (const [name, change] of [
  ['missing crash receipt', data => { delete data['crash-receipt.json']; }],
  ['missing crash outbox', data => { delete data['crash-outbox.json']; }],
  ['missing reload receipt', data => { delete data['reloaded-receipt.json']; }],
  ['missing reload outbox', data => { delete data['reloaded-outbox.json']; }],
  ['reused pid', data => { data['reloaded-receipt.json'].pid = 123; }],
  ['invalid hwnd', data => { data['reloaded-receipt.json'].hwnd = 0; }],
  ['changed crash identity', data => { data['crash-outbox.json'].queues[0].messages[0].wire_id = 'wrong'; }],
  ['changed reload text', data => { data['reloaded-outbox.json'].queues[0].messages[0].t = 'wrong'; }],
  ['early release', data => { data['delivery-timing.json'].releasedMs = 350; }],
  ['reload before crash', data => { data['reloaded-receipt.json'].startedMs = 299; }],
  ['crash connection released', data => { data['crash-receipt.json'].connectionHeld = false; }],
  ['reload connection released', data => { data['reloaded-receipt.json'].connectionHeld = false; }],
  ['remaining crash process', data => { data['crash-process-tree.json'].ActiveProcesses = 1; }],
  ['duplicate wire id with changed text', data => { data['store-after.json'].push({ text: 'other', id: data['store-after.json'][0].id }); }],
  ['slow first paint', data => { data['startup-timing.json'].firstPaintMs = 1000; }],
  ['duplicate message', data => { data['store-after.json'].push(data['store-after.json'][0]); }],
  ['reversed delivery', data => { data['store-after.json'].reverse(); }],
  ['changed message identity', data => { data['store-after.json'][0].id = 'wrong'; }],
  ['delivery before connection', data => { data['store-before.json'] = data['store-after.json']; }],
  ['missing saved blocks', data => { data['saved-launch.json'].blocks = []; }],
]) {
  test(`instant-chat oracle rejects ${name}`, () => {
    const f = fixture(change);
    try { assert.throws(() => verify(f.root)); } finally { f.close(); }
  });
}

test('instant-chat oracle rejects missing reload evidence', () => {
  for (const name of ['instant-chat/crash-process-tree.json', 'instant-chat/reloaded-copied.txt', 'instant-reloaded.png']) {
    const f = fixture();
    try { fs.unlinkSync(path.join(f.root, name)); assert.throws(() => verify(f.root)); } finally { f.close(); }
  }
  for (const text of ['', 'preconnect first', 'preconnect second']) {
    const f = fixture();
    try { fs.writeFileSync(path.join(f.root, 'instant-chat/reloaded-copied.txt'), text); assert.throws(() => verify(f.root)); } finally { f.close(); }
  }
});

test('instant-chat oracle rejects startup banner and missing rendered history', () => {
  for (const [name, text] of [['debug.log', 'Chat sync interrupted'], ['offline-copied.txt', '']]) {
    const f = fixture();
    try {
      fs.appendFileSync(path.join(f.root, 'instant-chat', name), text);
      if (!text) fs.writeFileSync(path.join(f.root, 'instant-chat', name), '');
      assert.throws(() => verify(f.root));
    } finally { f.close(); }
  }
});
