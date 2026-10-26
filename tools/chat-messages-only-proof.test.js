const test = require('node:test');
const assert = require('node:assert/strict');

const geometry = {
  transcript: { left: 10, top: 40, width: 320, height: 150 },
  rows: { left: 10, top: 10, width: 320, height: 28 },
  working: { left: 10, top: 190, width: 320, height: 14 },
};

function frame(rows = true, messages = true, working = false) {
  const width = 360;
  const height = 220;
  const pixels = Buffer.alloc(width * height * 4, 24);
  for (const [paint, rect] of [[messages, geometry.transcript], [rows, geometry.rows], [working, geometry.working]]) {
    if (!paint) continue;
    for (let y = rect.top + 5; y < Math.min(rect.top + 20, rect.top + rect.height); y++) {
      for (let x = rect.left + 20; x < rect.left + 180; x++) {
        const i = (y * width + x) * 4;
        pixels[i] = 60 + x % 160;
        pixels[i + 1] = 70 + y % 160;
        pixels[i + 2] = 90;
      }
    }
  }
  return { width, height, pixels };
}

test('IGSH-816 rejects the old-oracle input with footer rows still painted in CLEAN', async () => {
  const { compareCleanChat } = await import('./chat-messages-only-proof.mjs');
  assert.throws(() => compareCleanChat(frame(), frame(), frame(), geometry), /CLEAN chat ON still paints status\/outbox\/footer rows/);
});

test('IGSH-816 accepts the same messages with only footer rows removed and ignores alpha', async () => {
  const { compareCleanChat } = await import('./chat-messages-only-proof.mjs');
  const on = frame(false);
  for (let i = 3; i < on.pixels.length; i += 4) on.pixels[i] = 255;
  const result = compareCleanChat(frame(), on, frame(), geometry);
  assert.equal(result.messages.changedPixels, 0);
  assert.equal(result.rows.onInk, 0);
  assert.ok(result.rows.offInk > 0);
  assert.equal(result.working.onInk, 0);
  assert.equal(result.working.offInk, 0);
});

test('IGSH-816 rejects even one retained row pixel and requires the normal rows', async () => {
  const { compareCleanChat } = await import('./chat-messages-only-proof.mjs');
  const on = frame(false);
  on.pixels[(geometry.rows.top * on.width + geometry.rows.left) * 4]++;
  assert.throws(() => compareCleanChat(frame(), on, frame(), geometry), /ON still paints/);
  assert.throws(() => compareCleanChat(frame(false), frame(false), frame(false), geometry), /OFF has no painted/);
  const changed = frame();
  changed.pixels[(geometry.rows.top * changed.width + geometry.rows.left) * 4]++;
  assert.throws(() => compareCleanChat(frame(), frame(false), changed, geometry), /OFF did not restore today's/);
});

test('IGSH-816 rejects message displacement, blank captures and any reintroduced working strip', async () => {
  const { compareCleanChat } = await import('./chat-messages-only-proof.mjs');
  const shifted = frame(false);
  shifted.pixels[(50 * shifted.width + 40) * 4]++;
  assert.throws(() => compareCleanChat(frame(), shifted, frame(), geometry), /messages changed, shifted or are blank/);
  assert.throws(() => compareCleanChat(frame(), frame(false, false), frame(), geometry), /messages changed, shifted or are blank/);
  assert.throws(() => compareCleanChat(frame(true, false), frame(false, false), frame(true, false), geometry), /blank transcript/);
  for (const mode of ['on', 'off']) {
    assert.throws(() => compareCleanChat(frame(), frame(false, true, mode === 'on'), frame(true, true, mode === 'off'), geometry), /still paints the removed working strip/);
  }
  const changedGap = frame();
  changedGap.pixels[(geometry.working.top * changedGap.width + geometry.working.left) * 4]++;
  assert.throws(() => compareCleanChat(changedGap, frame(false), frame(), geometry), /composer gap changed/);
  for (const name of ['rows', 'working']) {
    assert.throws(() => compareCleanChat(frame(), frame(false), frame(), { ...geometry, [name]: { ...geometry[name], left: 350 } }), /out-of-window/);
    assert.throws(() => compareCleanChat(frame(), frame(false), frame(), { ...geometry, [name]: geometry.transcript }), /overlaps messages/);
  }
});

function bmp(image) {
  const bytes = Buffer.alloc(54 + image.pixels.length);
  bytes.write('BM');
  bytes.writeUInt32LE(bytes.length, 2);
  bytes.writeUInt32LE(54, 10);
  bytes.writeUInt32LE(40, 14);
  bytes.writeInt32LE(image.width, 18);
  bytes.writeInt32LE(-image.height, 22);
  bytes.writeUInt16LE(1, 26);
  bytes.writeUInt16LE(32, 28);
  image.pixels.copy(bytes, 54);
  return bytes;
}

test('IGSH-816 default evidence evaluation requires the CLEAN pair and rejects the old passing evidence', async t => {
  const fs = require('node:fs');
  const path = require('node:path');
  const { evaluate } = await import('./chat-messages-only-proof.mjs');
  const messages = [{ role: 'user', text: 'start the fake session' }, { role: 'assistant', text: 'The fake session is ready.' }];
  const tools = Array.from({ length: 12 }, (_, id) => ({ role: 'tool', id, status: 'ok', detail: 'verified', text: id === 0 ? 'TodoWrite' : ['Ran Check app-smoke state', 'Ran Inspect app-smoke run details', 'Ran Read commit statuses on PR head'][id % 3] }));
  const rows = values => [{}, ...values].map(row => JSON.stringify(row)).join('\n');
  const files = new Map([
    ['messages-only/observation.json', JSON.stringify({ error: null, composerText: 'composer stays usable', transcript: geometry.transcript, cleanChat: { rows: geometry.rows, working: geometry.working } })],
    ['messages-only/app-cache-before.jsonl', rows(messages)],
    ['messages-only/app-cache.jsonl', rows([...messages, ...tools])],
    ['messages-only-before-tools.bmp', bmp(frame())],
    ['messages-only-after-tools.bmp', bmp(frame())],
    ['clean-chat-on.bmp', bmp(frame(false))],
    ['clean-chat-off.bmp', bmp(frame())],
  ]);
  const root = path.resolve('synthetic-clean-evidence');
  t.mock.method(fs, 'readFileSync', file => {
    const name = path.relative(root, file).split(path.sep).join('/');
    assert.ok(files.has(name), `missing synthetic evidence: ${name}`);
    return files.get(name);
  });
  assert.equal(evaluate(root, false).cleanChat.rows.onInk, 0);
  const withoutTodo = rows([...messages, ...tools.map(row => row.id === 0 ? { ...row, text: 'Ran Check app-smoke state' } : row)]);
  const withTodo = files.get('messages-only/app-cache.jsonl');
  files.set('messages-only/app-cache.jsonl', withoutTodo);
  assert.throws(() => evaluate(root, false), /TodoWrite/);
  files.set('messages-only/app-cache.jsonl', withTodo);
  files.set('clean-chat-on.bmp', bmp(frame()));
  assert.throws(() => evaluate(root, false), /ON still paints status\/outbox\/footer rows/);
  files.delete('clean-chat-on.bmp');
  assert.throws(() => evaluate(root, false), /missing synthetic evidence/);
  assert.equal(evaluate(root, false, true).cleanChat, null);
  assert.throws(() => evaluate(root, true, true), /complete proof cannot skip CLEAN chat/);
});

test('IGSH-816 extends only the existing messages-only journey using checked palette input', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const read = name => fs.readFileSync(path.join(__dirname, '..', name), 'utf8');
  const driver = read('tools/verify-chat-delivery/drive.ps1');
  const journey = driver.slice(driver.indexOf("Shot 'messages-only-after-tools'"), driver.indexOf('$fillLogStart ='));
  assert.match(journey, /\$workingHeight -ne \$expectedGapHeight/);
  assert.match(journey, /Floor\(14 \* \$statusBounds.Height \/ 28\)/);
  assert.match(journey, /--tools-only[\s\S]*foreach \(\$mode in @\('on', 'off'\)\)/);
  assert.match(journey, /Press @\(0x11, 0x4B\)/);
  assert.match(journey, /foreach \(\$letter in 'clean chat'\.ToCharArray\(\)\) \{ Press/);
  assert.match(journey, /ready chars=10 count=1/);
  assert.match(journey, /Press @\(0x0D\)/);
  assert.match(journey, /Doctor \$true[\s\S]*Properties\['clean_chat'\][\s\S]*\$enabled -ne \(\$mode -eq 'on'\)/);
  assert.match(journey, /Shot "clean-chat-\$mode"[\s\S]*Save \$observation[\s\S]*proof.mjs" \$Evidence\s/);
  assert.doesNotMatch(journey, /Start-Sleep|::(?:Type|Chord|FocusOwnedWindow)|PostMessage|SetFocus|SetWindowText/);
  assert.match(driver, /'messages-only-after-tools', 'clean-chat-on', 'clean-chat-off'/);
  assert.match(read('src/command_palette.zig'), /"chat view toggle CLEAN chat"/);
  assert.match(read('src/command_palette.zig'), /fn labelsMatchQuery[\s\S]*asciiContainsQueryInsensitive\(label, query\)/);
  assert.match(read('src/main.zig'), /WM_APP_SEARCH_CHAR => \{[\s\S]*g_search_sel = 0;/);
  assert.match(read('.github/workflows/verify.yml'), /Parser\]::ParseFile\("\$pwd\/tools\/verify-chat-delivery\/drive.ps1"/);
  assert.match(read('.github/workflows/verify.yml'), /run: node --test[^\n]*tools\/chat-messages-only-proof.test.mjs tools\/chat-messages-only-proof.test.js/);
});

test('IGSH-816 feature map names every CLEAN artifact, exact palette steps and the full gate list', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const read = name => fs.readFileSync(path.join(__dirname, '..', name), 'utf8');
  const map = read('.claude/skills/verify-multiprompt/features/chat-messages-only.md');
  for (const file of ['clean-chat-on.png', 'clean-chat-on.bmp', 'clean-chat-off.png', 'clean-chat-off.bmp']) assert.ok(map.includes(file), file);
  for (const step of ['Ctrl+K', '`clean chat`', 'Enter without an arrow-key selection step', '--tools-only', '--complete', 'background-only', 'permission controls', 'identical', 'off-mode', ['changelog.d', 'IGSH-816-clean-chat.md'].join('/')]) assert.ok(map.toLowerCase().includes(step.toLowerCase()), step);
  const gates = [...map.matchAll(/^(\d+)\. (.+)$/gm)];
  assert.deepEqual(gates.map(([, number]) => Number(number)), Array.from({ length: gates.length }, (_, i) => i + 1));
  assert.equal(gates.length, 10);
  const { readChangelogEntry } = require('./changelog-entry.js');
  assert.match(readChangelogEntry('IGSH-816'), /Choose CLEAN chat[\s\S]*keeping messages and the working indicator/);
});
