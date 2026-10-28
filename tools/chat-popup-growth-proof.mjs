import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readBmp } from './chat-code-font-proof.mjs';
import { inspect } from './chat-reactions-proof.mjs';

const prefix = 'Same first words ' + 'for this example '.repeat(8);
export const expectedReaction = `👍 to: ${prefix.trim().slice(0, 80)} [mp:983056b4a6c7ffef]`;
export const codeGrowth = '\n\n```zig\nconst popup_growth = true;\n```\n';

export function assertSecondBadge(frame) {
  assert.ok(frame.agent.length >= 3, 'both same-prefix replies and the new code panel remain visible');
  assert.equal(frame.user.length, 1, 'reaction adds no ordinary bubble');
  assert.equal(frame.dim.length, 0, 'reaction adds no pending bubble');
  assert.equal(frame.pill.length, 1, 'exactly one reaction badge');
  const [first, code, second, next] = frame.agent, [pill] = frame.pill;
  assert.ok(first.bottom < code.top && code.bottom < second.top, 'earlier reply has a separate code panel before the clicked reply');
  assert.ok(pill.top > second.top && pill.bottom <= second.bottom && second.bottom - pill.bottom <= 16 && (!next || pill.bottom < next.top), 'badge belongs to the clicked second reply');
  assert.ok(pill.left >= second.left && pill.right <= second.right, 'badge stays within its reply');
  assert.ok(pill.right - pill.left < 100 && pill.bottom - pill.top < 40 && pill.ink > 8, 'small painted badge, not an empty box');
}

export function assertPaintedGrowth(beforeImage, grownImage, area, popup) {
  const before = inspect(beforeImage, area);
  assert.equal(before.agent.length, 2, 'two replies before opening the popup');
  assert.equal(before.pill.length, 0, 'no prior reaction');

  assert.ok(popup.right > popup.left && popup.bottom > popup.top, 'real popup rectangle');
  const pixels = Buffer.from(grownImage.pixels);
  const background = grownImage.pixels.readUIntLE((area.top * grownImage.width + area.left) * 4, 3);
  for (let y = Math.max(0, popup.top); y < Math.min(grownImage.height, popup.bottom); y++) {
    for (let x = Math.max(0, popup.left); x < Math.min(grownImage.width, popup.right); x++) pixels.writeUIntLE(background, (y * grownImage.width + x) * 4, 3);
  }
  const painted = inspect({ ...grownImage, pixels }, area, true);
  const bodies = painted.agent;
  assert.equal(bodies.length, 3, 'unoccluded edges identify both prose replies and the added code panel');
  assert.ok(bodies[0].bottom < bodies[1].top && bodies[1].bottom < bodies[2].top, 'new code panel paints between the earlier prose and clicked reply');
  assert.ok(bodies[1].bottom - bodies[1].top >= 32 && bodies[1].ink > 8, 'new code panel has height and actual foreground ink');
  assert.ok(Math.abs((bodies[0].bottom - bodies[0].top) - (before.agent[0].bottom - before.agent[0].top)) <= 6, 'earlier prose body remains unchanged');
  assert.ok(bodies[2].right >= before.agent[1].right - 3, 'clicked reply remains observable beside the popup');
  return { before: before.agent, grown: bodies };
}

export function assertSourceGrowth(before, after) {
  assert.equal(before.length, 3);
  assert.equal(after.length, before.length);
  const [, first, second] = before;
  assert.ok(first.uuid && second.uuid);
  assert.equal(first.type, 'assistant');
  assert.equal(second.type, 'assistant');
  assert.equal(first.message.id, 'msg_first');
  assert.equal(second.message.id, 'msg_second');
  assert.equal(first.message.content[0].text, prefix + '\nFIRST REPLY');
  assert.equal(second.message.content[0].text, prefix + '\nSECOND REPLY');
  const expected = structuredClone(before);
  expected[1].message.content[0].text += codeGrowth;
  assert.deepEqual(after, expected, 'only the earlier reply gains code; clicked provider event and order stay identical');
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = process.argv[2];
  const json = file => JSON.parse(fs.readFileSync(path.join(root, file), 'utf8').replace(/^\uFEFF/, ''));
  const events = file => fs.readFileSync(path.join(root, file), 'utf8').trim().split(/\r?\n/).filter(Boolean).map(JSON.parse);
  const image = stage => readBmp(path.join(root, `popup-growth-${stage}.bmp`));
  const mode = process.argv[3];
  if (mode === '--locate') {
    const area = json('popup-growth/area.json');
    const frame = inspect(image('before'), area);
    assert.equal(frame.agent.length, 2, 'fixture replies painted');
    const target = frame.agent[1];
    console.log(JSON.stringify({ x: target.left + 30, y: target.top + 20 }));
  } else if (mode === '--growth') {
    const area = json('popup-growth/area.json');
    const proof = assertPaintedGrowth(image('before'), image('grown'), area, json('popup-growth/menu.json'));
    fs.writeFileSync(path.join(root, 'popup-growth/growth-proof.json'), JSON.stringify(proof, null, 2));
    console.log('POPUP_CODE_GROWTH_PAINTED');
  } else if (mode === '--frame') {
    const area = json('popup-growth/area.json');
    assertSecondBadge(inspect(image(process.argv[4]), area));
  } else {
    const resultFile = path.join(root, 'result.json');
    try {
      const observation = json('popup-growth/observation.json');
      assert.equal(observation.error, null);
      const area = json('popup-growth/area.json');
      assert.equal(observation.composerText, 'popup growth draft stays');
      assert.equal(observation.restartComposerText, observation.composerText);
      assert.ok(observation.popupBefore !== 0 && observation.popupBefore === observation.popupAfter);
      const growth = events('popup-growth/stand-in/growth.jsonl');
      assert.equal(growth.length, 1);
      assert.equal(growth[0].operation, 'earlier reply gained code');
      assert.equal(growth[0].reference, 'msg_first');
      assert.equal(growth[0].target, 'msg_second');
      assert.equal(observation.reactionText, expectedReaction);
      assert.ok(observation.menuOpenedMs > 0);
      assert.ok(observation.menuOpenedMs <= growth[0].ms && growth[0].ms <= observation.growthPaintedMs && observation.growthPaintedMs <= observation.menuClickMs, 'source and real repaint precede the click while the same popup is open');
      assertSourceGrowth(events('popup-growth/stand-in/reaction-before.jsonl'), events('popup-growth/stand-in/reaction-after.jsonl'));
      assertPaintedGrowth(image('before'), image('grown'), area, json('popup-growth/menu.json'));
      const transcript = events('popup-growth/transcript.jsonl');
      assert.deepEqual(transcript.filter(event => event.type === 'queue-operation' && event.operation === 'enqueue').map(event => event.content), [expectedReaction], 'exactly one transport message targets the captured second reply');
      assert.equal(transcript.filter(event => event.type === 'attachment' && event.attachment?.prompt === expectedReaction).length, 1);
      for (const stage of ['pending', 'delivered', 'restart']) assertSecondBadge(inspect(image(stage), area));
      const build = json('build.json');
      for (const file of ['popup-growth/menu-doctor.json', 'popup-growth/doctor.json']) {
        const doctor = json(file);
        assert.equal(doctor.sha256.toLowerCase(), build.sha256.toLowerCase());
        assert.equal(doctor.version, build.version);
      }
      const menuDoctor = json('popup-growth/menu-doctor.json'), restoredDoctor = json('popup-growth/doctor.json');
      assert.equal(menuDoctor.pid, observation.menuOwnerPid);
      assert.notEqual(restoredDoctor.pid, menuDoctor.pid, 'restart must use a new owned process');
      assert.equal(menuDoctor.chat, true);
      assert.equal(restoredDoctor.chat, true);
      const stopped = json('popup-growth/restart-process-tree.json');
      assert.equal(stopped.ActiveProcesses, 0);
      assert.ok(stopped.TotalProcesses > 0);
      const cleanup = json('popup-growth/cleanup.json');
      assert.equal(cleanup.remaining_owned_processes, 0);
      assert.equal(cleanup.scratch_removed, true);
      const result = json('result.json');
      assert.equal(result.status, 'passed', 'original reaction journey also passed');
      fs.writeFileSync(path.join(root, 'popup-growth-proof.json'), JSON.stringify({ status: 'passed', expected: expectedReaction, earlierCodeGrowthPainted: true, samePopupBeforeClick: true, transportCount: 1, sameSecondTargetAfterRestart: true }, null, 2));
      fs.writeFileSync(resultFile, JSON.stringify({ ...result, popupGrowth: true }, null, 2));
      console.log('POPUP_GROWTH_TARGET_PROVEN');
    } catch (error) {
      const result = fs.existsSync(resultFile) ? json('result.json') : {};
      fs.writeFileSync(resultFile, JSON.stringify({ ...result, status: 'failed', popupGrowth: false, error: error.message }, null, 2));
      throw error;
    }
  }
}
