import assert from 'node:assert/strict';
import { test } from 'node:test';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { inspect } from './chat-reactions-proof.mjs';
import { assertPaintedGrowth, assertSecondBadge, assertSourceGrowth, codeGrowth, expectedReaction } from './chat-popup-growth-proof.mjs';

const area = { left: 0, top: 0, right: 400, bottom: 380 };
const popup = { left: 50, top: 140, right: 190, bottom: 250 };
function fixture(grown = false, badge = false) {
  const image = { width: 400, height: 380, pixels: Buffer.alloc(400 * 380 * 4) };
  const fill = (left, top, right, bottom, color) => {
    for (let y = top; y < bottom; y++) for (let x = left; x < right; x++) image.pixels.writeUIntLE(color, (y * image.width + x) * 4, 3);
  };
  fill(0, 0, 400, 380, 0x202020);
  fill(200, 10, 360, 45, 0x555555);
  fill(20, 60, 250, 116, 0x444444);
  if (grown) {
    fill(20, 122, 250, 190, 0x484848);
    fill(32, 132, 43, 144, 0xffffff);
  }
  const top = grown ? 210 : 180;
  fill(20, top, 250, top + 60, 0x444444);
  if (badge) {
    fill(28, top + 64, 68, top + 86, 0x585858);
    fill(42, top + 70, 53, top + 80, 0xffffff);
  }
  return { image, fill };
}

test('native popup occlusion cannot hide real earlier-body growth', () => {
  const before = fixture(), grown = fixture(true);
  grown.fill(popup.left, popup.top, popup.right, popup.bottom, 0x484848);
  assertPaintedGrowth(before.image, grown.image, area, popup);
});

test('a painted native menu alone cannot substitute for history repaint', () => {
  const before = fixture(), unchanged = fixture();
  unchanged.fill(popup.left, popup.top, popup.right, popup.bottom, 0x484848);
  assert.throws(() => assertPaintedGrowth(before.image, unchanged.image, area, popup));
});

test('a taller prose bubble cannot substitute for a separate code panel', () => {
  const unchanged = fixture();
  unchanged.fill(20, 116, 250, 160, 0x444444);
  assert.throws(() => assertPaintedGrowth(fixture().image, unchanged.image, area, popup));
});

test('an empty panel cannot substitute for painted code content', () => {
  const grown = fixture(true);
  grown.fill(32, 132, 43, 144, 0x484848);
  assert.throws(() => assertPaintedGrowth(fixture().image, grown.image, area, popup));
});

test('popup must leave the earlier reply observable', () => {
  assert.throws(() => assertPaintedGrowth(fixture().image, fixture(true).image, area, { ...popup, left: 20 }));
});

test('growth cannot replace the clicked second reply with a differently sized body', () => {
  const grown = fixture(true);
  grown.fill(20, 270, 250, 310, 0x444444);
  assert.throws(() => assertPaintedGrowth(fixture().image, grown.image, area, popup));
});

test('painted badge under the second same-prefix reply is accepted', () => {
  assertSecondBadge(inspect(fixture(true, true).image, area));
});

for (const [name, mutate] of [
  ['badge attached to the earlier code reply', f => { f.fill(28, 274, 68, 296, 0x202020); f.fill(20, 210, 250, 270, 0x202020); f.fill(20, 238, 250, 298, 0x444444); f.fill(28, 194, 68, 216, 0x585858); f.fill(42, 200, 53, 210, 0xffffff); }],
  ['extra ordinary reaction bubble', f => f.fill(20, 320, 250, 355, 0x555555)],
  ['extra pending reaction bubble', f => f.fill(20, 320, 250, 355, 0x3a3a3a)],
  ['unpainted badge glyph', f => f.fill(42, 280, 53, 290, 0x585858)],
]) test(`reject ${name}`, () => {
  const f = fixture(true, true); mutate(f);
  assert.throws(() => assertSecondBadge(inspect(f.image, area)));
});

function sources() {
  const prefix = 'Same first words ' + 'for this example '.repeat(8);
  const before = [{ type: 'user', uuid: 'user', message: { role: 'user', content: 'start the reaction session' } }];
  for (const [id, suffix] of [['msg_first', 'FIRST REPLY'], ['msg_second', 'SECOND REPLY']]) before.push({ type: 'assistant', uuid: id + '-event', message: { role: 'assistant', id, content: [{ type: 'text', text: prefix + '\n' + suffix }] } });
  const after = structuredClone(before);
  after[1].message.content[0].text += codeGrowth;
  return { before, after };
}

test('source update grows only the earlier provider event', () => {
  const { before, after } = sources();
  assertSourceGrowth(before, after);
  assert.match(expectedReaction, /\[mp:983056b4a6c7ffef\]$/);
});

for (const [name, mutate] of [
  ['changed clicked provider identity', after => { after[2].message.id = 'msg_first'; }],
  ['changed earlier event identity', after => { after[1].uuid = 'new-provider-event'; }],
  ['changed clicked quote', after => { after[2].message.content[0].text += 'changed'; }],
  ['reordered provider events', after => { [after[1], after[2]] = [after[2], after[1]]; }],
  ['no fenced code added', after => { after[1].message.content[0].text = after[1].message.content[0].text.replace(codeGrowth, ''); }],
]) test(`reject ${name}`, () => {
  const { before, after } = sources(); mutate(after);
  assert.throws(() => assertSourceGrowth(before, after));
});

for (const [name, observation] of [
  ['missing popup artifacts', null],
  ['native popup target moved', { error: 'IGSH975_POPUP_TARGET_MOVED: wrong reply' }],
]) test(`CLI cannot retain the original journey success after ${name}`, () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh975-popup-oracle-'));
  try {
    fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify({ status: 'passed', feature: 'chat-reactions' }));
    fs.mkdirSync(path.join(root, 'popup-growth'));
    if (observation) fs.writeFileSync(path.join(root, 'popup-growth/observation.json'), JSON.stringify(observation));
    const script = fileURLToPath(new URL('./chat-popup-growth-proof.mjs', import.meta.url));
    const result = spawnSync(process.execPath, [script, root], { encoding: 'utf8' });
    assert.equal(result.status, 1, result.stdout + result.stderr);
    const proof = JSON.parse(fs.readFileSync(path.join(root, 'result.json'), 'utf8'));
    assert.equal(proof.status, 'failed');
    assert.equal(proof.popupGrowth, false);
    assert.ok(proof.error);
  } finally { fs.rmSync(root, { recursive: true, force: true }); }
});

function completeEvidence(root, mutate = () => {}) {
  const { before, after } = sources();
  const files = {
    'result.json': { status: 'passed', feature: 'chat-reactions' },
    'build.json': { sha256: 'a'.repeat(64), version: '0.28.946' },
    'popup-growth/area.json': area,
    'popup-growth/menu.json': popup,
    'popup-growth/observation.json': { error: null, composerText: 'popup growth draft stays', restartComposerText: 'popup growth draft stays', popupBefore: 81, popupAfter: 81, menuOwnerPid: 111, menuOpenedMs: 1000, growthPaintedMs: 1200, menuClickMs: 1300, reactionText: expectedReaction },
    'popup-growth/stand-in/growth.jsonl': [{ ms: 1100, operation: 'earlier reply gained code', reference: 'msg_first', target: 'msg_second' }],
    'popup-growth/stand-in/reaction-before.jsonl': before,
    'popup-growth/stand-in/reaction-after.jsonl': after,
    'popup-growth/transcript.jsonl': [...after, { type: 'queue-operation', operation: 'enqueue', content: expectedReaction }, { type: 'attachment', attachment: { prompt: expectedReaction } }],
    'popup-growth/menu-doctor.json': { pid: 111, sha256: 'a'.repeat(64), version: '0.28.946', chat: true },
    'popup-growth/doctor.json': { pid: 222, sha256: 'a'.repeat(64), version: '0.28.946', chat: true },
    'popup-growth/restart-process-tree.json': { ActiveProcesses: 0, TotalProcesses: 1 },
    'popup-growth/cleanup.json': { remaining_owned_processes: 0, scratch_removed: true },
  };
  const grown = fixture(true);
  grown.fill(popup.left, popup.top, popup.right, popup.bottom, 0x484848);
  const frames = { before: fixture().image, grown: grown.image, pending: fixture(true, true).image, delivered: fixture(true, true).image, restart: fixture(true, true).image };
  mutate(files, frames);
  for (const [name, value] of Object.entries(files)) {
    const file = path.join(root, name);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, name.endsWith('.jsonl') ? value.map(row => JSON.stringify(row)).join('\n') + '\n' : JSON.stringify(value));
  }
  for (const [name, image] of Object.entries(frames)) {
    const header = Buffer.alloc(54);
    header.write('BM'); header.writeUInt32LE(54 + image.pixels.length, 2); header.writeUInt32LE(54, 10);
    header.writeUInt32LE(40, 14); header.writeInt32LE(image.width, 18); header.writeInt32LE(-image.height, 22);
    header.writeUInt16LE(1, 26); header.writeUInt16LE(32, 28);
    fs.writeFileSync(path.join(root, `popup-growth-${name}.bmp`), Buffer.concat([header, image.pixels]));
  }
}

for (const [name, mutate] of [
  ['complete synthetic evidence', null],
  ['different popup after growth', files => { files['popup-growth/observation.json'].popupAfter = 82; }],
  ['source growth after menu click', files => { files['popup-growth/stand-in/growth.jsonl'][0].ms = 1400; }],
  ['changed target wire reference', files => { files['popup-growth/transcript.jsonl'][3].content = expectedReaction.replace('983056b4a6c7ffef', '6d8e353d25c5fe23'); }],
  ['duplicate transport enqueue', files => { files['popup-growth/transcript.jsonl'].push({ type: 'queue-operation', operation: 'enqueue', content: expectedReaction }); }],
  ['restart without a new process', files => { files['popup-growth/doctor.json'].pid = 111; }],
  ['wrong restarted executable hash', files => { files['popup-growth/doctor.json'].sha256 = 'b'.repeat(64); }],
  ['owned restart processes left running', files => { files['popup-growth/restart-process-tree.json'].ActiveProcesses = 1; }],
  ['source updated without painted code', (_, frames) => { frames.grown = fixture().image; }],
]) test(`full CLI ${mutate ? 'rejects' : 'accepts'} ${name}`, () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh975-popup-complete-'));
  try {
    completeEvidence(root, mutate || undefined);
    const script = fileURLToPath(new URL('./chat-popup-growth-proof.mjs', import.meta.url));
    const result = spawnSync(process.execPath, [script, root], { encoding: 'utf8' });
    assert.equal(result.status, mutate ? 1 : 0, result.stdout + result.stderr);
    const proof = JSON.parse(fs.readFileSync(path.join(root, 'result.json'), 'utf8'));
    assert.equal(proof.status, mutate ? 'failed' : 'passed');
    assert.equal(proof.popupGrowth, !mutate);
  } finally { fs.rmSync(root, { recursive: true, force: true }); }
});
