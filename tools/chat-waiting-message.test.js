const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const { pathToFileURL } = require('node:url');

const root = path.resolve(__dirname, '..');

test('accepted proof selects the exact transcript command among multiple matches', () => {
  const driver = fs.readFileSync(path.join(root, 'tools/verify-chat-delivery/drive.ps1'), 'utf8');
  const accepted = driver.slice(driver.indexOf("} elseif ($isAccepted) {"), driver.indexOf("} elseif ($isSendStays) {"));
  const match = accepted.match(/Wait-For 'select-all command ready'[^\n]+-match \('([^']+)' \+ \$query\.Length \+ '([^']+)'\)/);
  assert.ok(match, 'accepted proof must check the typed query and selected target');
  const ready = new RegExp(match[1] + 'chat view select all'.length + match[2]);
  assert.equal(ready.test('[palette] ready chars=20 count=2 target=6364\n'), true);
  assert.equal(ready.test('[palette] ready chars=20 count=2 target=6366\n'), false);
  assert.equal(ready.test('[palette] ready chars=20 count=0 target=6364\n'), false);
  assert.equal(ready.test('[palette] ready chars=19 count=2 target=6364\n'), false);
  assert.equal(ready.test('[palette] ready chars=20 count=2 target=63640\n'), false);
  assert.match(accepted, /Press @\(0x0D\) 'Enter: select transcript'/);
  assert.match(accepted, /Press @\(0x11, 0x43\) 'Ctrl\+C: copy transcript'/);
  assert.match(accepted, /Matches\(\$takenCopy, \[regex\]::Escape\(\$plan\.text\)\)\.Count -ne 1/);
});

test('accepted fixture passes production buffer handoff to the busy fake agent', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'accepted-tmux-'));
  try {
    const transcript = path.join(dir, 'transcript.jsonl');
    fs.writeFileSync(transcript, '');
    fs.writeFileSync(path.join(dir, 'state.json'), JSON.stringify({ name: 'accepted-message', fake: true, mode: 'busy', sid: 'session', transcript }));
    fs.writeFileSync(path.join(dir, 'claude.json'), JSON.stringify({ mode: 'busy', box: '', queue: [], suggestion: '' }));
    const script = path.join(root, 'tools/verify-chat-delivery/boundary.py');
    const env = { ...process.env, MP_VERIFY_STATE: dir };
    const run = (args, input = '') => spawnSync('python3', [script, 'tmux', ...args], { env, input, encoding: 'utf8' });
    const name = `mp-send-${'a'.repeat(32)}`;
    const load = run(['load-buffer', '-b', name, '-'], 'waiting message');
    assert.equal(load.status, 0, load.stderr);
    const paste = run(['paste-buffer', '-p', '-d', '-b', name, '-t', '=verify-agent:']);
    assert.equal(paste.status, 0, paste.stderr);
    const enter = run(['send-keys', '-t', '=verify-agent:', 'Enter']);
    assert.equal(enter.status, 0, enter.stderr);
    assert.deepEqual(JSON.parse(fs.readFileSync(path.join(dir, 'claude.json'), 'utf8')).queue, ['waiting message']);
    const events = fs.readFileSync(transcript, 'utf8').trim().split('\n').map(JSON.parse);
    assert.equal(events.filter(event => event.type === 'queue-operation' && event.operation === 'enqueue' && event.content === 'waiting message').length, 1);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('refusal control targets legacy delivery evidence, not Claude queue evidence', () => {
  const source = fs.readFileSync(path.join(root, 'src/chat_send.zig'), 'utf8');
  const start = source.indexOf('pub fn chatEchoMatchActive(');
  const end = source.indexOf('\n}', start);
  const match = source.slice(start, end);
  const legacy = 'const facts = chatEchoDeliveryEvidence(e);';
  assert.equal(match.split(legacy).length - 1, 1);
  const mutated = match.replace(legacy, 'const facts: chat_echo.DeliveryEvidence = .{};');
  assert.match(mutated, /if \(e\.message_v1[^]*chatEchoDeliveryEvidence\(app_state\.g_chat_outbox\.items\[i\]\)/);
  assert.match(mutated, /const facts: chat_echo\.DeliveryEvidence = \.\{\};\s+refused = facts\.refused;/);
});

test('waiting and started echoes use their protocol phase for brightness', () => {
  const source = fs.readFileSync(path.join(root, 'src/chat_render.zig'), 'utf8');
  const match = source.match(/if \((e\.state == \.delivered[^\n]+)\) chatDimQueuedBubble\(hdc, bubble\);/);
  assert.ok(match);
  const expression = match[1]
    .replace('e.state == .delivered', "e.state === 'delivered'")
    .replace('!e.host_confirmed', '!e.host_confirmed')
    .replace('e.delivery_watch.removed_ms == 0', 'e.removed_ms === 0')
    .replace('!std.mem.eql(u8, std.mem.sliceTo(&e.message_phase, 0), "started")', "e.message_phase !== 'started'")
    .replaceAll(' and ', ' && ');
  const dim = new Function('e', `return ${expression};`);
  const echo = { state: 'delivered', host_confirmed: false, removed_ms: 0, message_phase: 'accepted' };
  assert.equal(dim(echo), true);
  assert.equal(dim({ ...echo, message_phase: 'started' }), false);
  assert.equal(dim({ ...echo, host_confirmed: true }), false);
  assert.equal(dim({ ...echo, removed_ms: 1 }), false);
});

test('pixel oracle rejects a missing or dim taken bubble', async () => {
  const { queuedBubble, normalBubble, countMessageBubbles, evaluateFrames } = await import(pathToFileURL(path.join(root, 'tools/chat-accepted-proof.mjs')));
  assert.equal(typeof countMessageBubbles, 'function');
  function image(fill, top) {
    const result = { width: 400, height: 220, pixels: Buffer.alloc(400 * 220 * 4, 24) };
    for (let y = top; y < top + 50; y++) for (let x = 180; x < 370; x++) {
      result.pixels.writeUIntLE(y > top + 15 && y < top + 30 && x % 3 === 0 ? 0xeeeeee : fill, (y * 400 + x) * 4, 3);
    }
    return result;
  }
  const area = { left: 0, right: 400, top: 0, bottom: 220 };
  const bubble = queuedBubble(image(0x323232, 50), area);
  assert.equal(normalBubble(image(0x323232, 50), bubble), false);
  assert.equal(normalBubble(image(0x4d4d4d, 90), bubble), false);
  assert.equal(normalBubble(image(0x4d4d4d, 50), bubble), true);
  const duplicate = image(0x4d4d4d, 50);
  const second = image(0x4d4d4d, 130);
  second.pixels.copy(duplicate.pixels, 130 * 400 * 4, 130 * 400 * 4, 180 * 400 * 4);
  assert.equal(countMessageBubbles(image(0x4d4d4d, 50), area, bubble), 1);
  assert.equal(countMessageBubbles(duplicate, area, bubble), 2);
  const dimDuplicate = image(0x323232, 130);
  dimDuplicate.pixels.copy(duplicate.pixels, 130 * 400 * 4, 130 * 400 * 4, 180 * 400 * 4);
  assert.equal(countMessageBubbles(duplicate, area, bubble), 2);
  const frames = [{ ms: 1050, normal: false, dots: true }, { ms: 1200, normal: true, dots: true }];
  assert.equal(evaluateFrames(frames, 1000), 200);
  assert.throws(() => evaluateFrames([{ ms: 2100, normal: true, dots: true }], 1000));
  assert.throws(() => evaluateFrames([{ ms: 1200, normal: true, dots: false }], 1000));
});
