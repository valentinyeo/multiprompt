const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

function parseFrames(text) {
  const frames = [];
  const byId = new Map();
  for (const line of text.trim().split(/\r?\n/)) {
    const [type, ...v] = line.split('\t');
    if (type === 'frame') {
      const keys = ['id', 'tick', 'active', 'cache', 'dirty', 'scroll', 'height', 'pad', 'opening', 'x', 'y', 'width', 'viewport', 'scrolledUp', 'hold', 'layouts'];
      if (v.length !== keys.length) throw new Error('Incomplete frame header');
      const frame = Object.fromEntries(keys.map((key, i) => [key, Number(v[i])]));
      frame.blocks = [];
      frames.push(frame);
      byId.set(v[0], frame);
    } else if (type === 'block') {
      const [id, index, message, offset, start, length, left, top, right, bottom] = v;
      const frame = byId.get(id);
      if (!frame) throw new Error('Block without frame');
      frame.blocks.push({ index: Number(index), message, offset, start: Number(start), length: Number(length), left: Number(left), top: Number(top), right: Number(right), bottom: Number(bottom) });
    } else if (type === 'end') {
      const frame = byId.get(v[0]);
      if (!frame) throw new Error('End without frame');
      frame.end = Number(v[1]);
    } else throw new Error(`Unknown frame record ${type}`);
  }
  if (!frames.length) throw new Error('No actual paints recorded');
  for (let i = 0; i < frames.length; i++) {
    if (frames[i].id !== i + 1 || !frames[i].end) throw new Error('Missing or incomplete successful paint');
  }
  return frames;
}

function image(directory, frame) {
  const filename = `paint-${String(frame.id).padStart(6, '0')}.bmp`;
  const bytes = fs.readFileSync(path.join(directory, filename));
  if (bytes.toString('ascii', 0, 2) !== 'BM' || bytes.readInt32LE(18) !== frame.width || bytes.readInt32LE(22) !== -frame.viewport || bytes.length !== 54 + frame.width * frame.viewport * 4) throw new Error(`Invalid paint image ${filename}`);
  return bytes;
}

function rows(bytes, frame, block) {
  const found = new Map();
  const left = Math.max(0, block.left - frame.x + 12);
  const right = Math.min(frame.width, block.right - frame.x - 12);
  if (right - left < 32) return found;
  for (let y = Math.max(0, block.top - frame.y + 8); y < Math.min(frame.viewport, block.bottom - frame.y - 8); y++) {
    const row = bytes.subarray(54 + (y * frame.width + left) * 4, 54 + (y * frame.width + right) * 4);
    let changes = 0;
    for (let x = 4; x < row.length; x += 4) if (!row.subarray(x, x + 3).equals(row.subarray(0, 3))) changes++;
    if (changes < 12) continue;
    const hash = crypto.createHash('sha256').update(row).digest('hex');
    if (found.has(hash)) found.set(hash, null);
    else found.set(hash, frame.y + y);
  }
  return found;
}

function movements(previous, current, beforeImage, afterImage) {
  const moved = [];
  const key = b => `${b.message}:${b.offset}:${b.start}`;
  const old = new Map(previous.blocks.map(b => [key(b), b]));
  for (const block of current.blocks) {
    const before = old.get(key(block));
    if (!before) continue;
    const dx = block.left - before.left;
    const dy = block.top - before.top;
    const rowMoves = [];
    if (block.right - block.left === before.right - before.left) {
      const a = rows(beforeImage, previous, before);
      const b = rows(afterImage, current, block);
      for (const [hash, from] of a) {
        const to = b.get(hash);
        if (from != null && to != null && from !== to) rowMoves.push({ from, to, dy: to - from });
      }
    }
    if (dx || dy || rowMoves.length) moved.push({ message: block.message, offset: block.offset, start: block.start, dx, dy, rows: rowMoves });
  }
  if (!current.blocks.some(b => old.has(key(b))) && previous.blocks.length && current.blocks.length) moved.push({ replacedViewport: true, before: previous.blocks[0], after: current.blocks[0] });
  return moved;
}

function replay(directory, phases) {
  const frames = parseFrames(fs.readFileSync(path.join(directory, 'frames.tsv'), 'utf8'));
  for (const frame of frames) image(directory, frame);
  const observations = [];
  for (const phase of phases) {
    if (!phase.end || phase.end - phase.start < 3000) throw new Error(`Incomplete observation ${phase.name}`);
    const samples = frames.filter(f => f.tick >= phase.start && f.tick <= phase.end && f.active === phase.shell);
    if (!samples.length || !samples.some(f => f.blocks.length && f.cache === phase.shell)) throw new Error(`Missing target paint for ${phase.name}`);
    const painted = samples.filter(f => f.blocks.length);
    if (!/^(open|switch)-/.test(phase.name)) {
      const prior = frames.findLast(f => f.tick < phase.start && f.active === phase.shell && f.blocks.length);
      if (!prior) throw new Error(`Missing pre-action frame for ${phase.name}`);
      painted.unshift(prior);
    }
    const moves = [];
    for (let i = 1; i < painted.length; i++) {
      const a = painted[i - 1];
      const b = painted[i];
      const changes = movements(a, b, image(directory, a), image(directory, b));
      if (changes.length) moves.push({ from: a.id, to: b.id, tick: b.tick, sinceFirstPaint: b.tick - painted[0].tick, scrollBefore: a.scroll, scrollAfter: b.scroll, changes });
    }
    const wrongSession = painted.filter(f => f.cache !== phase.shell).map(f => f.id);
    observations.push({ ...phase, paints: samples.map(f => f.id), first: painted[0].id, moves, wrongSession, status: phase.policy === 'stable' && (moves.length || wrongSession.length) ? 'failed' : 'passed' });
  }
  if (!observations.length) throw new Error('No user actions observed');
  return { status: observations.some(p => p.status === 'failed') ? 'failed' : 'passed', frameCount: frames.length, observations };
}

module.exports = { parseFrames, movements, replay };
if (require.main === module) {
  const [directory, phases, output] = process.argv.slice(2);
  try {
    const result = replay(directory, JSON.parse(fs.readFileSync(phases, 'utf8').replace(/^\uFEFF/, '')));
    fs.writeFileSync(output, JSON.stringify(result, null, 2) + '\n');
    console.log(JSON.stringify({ status: result.status, frames: result.frameCount, movements: result.observations.map(p => ({ name: p.name, status: p.status, moved: p.moves.length })) }));
    if (result.status !== 'passed') process.exitCode = 1;
  } catch (error) {
    fs.writeFileSync(output, JSON.stringify({ status: 'incomplete', error: error.message }) + '\n');
    throw error;
  }
}
