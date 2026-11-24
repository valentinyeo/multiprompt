import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export function verify(dir) {
  const read = file => JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8').replace(/^\uFEFF/, ''));
  const text = file => fs.readFileSync(path.join(dir, file), 'utf8');
  const observed = read('pin-skill/observation.json');
  const doctor = read('pin-skill/doctor.json');
  const cleanup = read('cleanup.json');
  assert.equal(observed.error, null);
  assert.ok(doctor.pid > 0 && doctor.chat && doctor.sha256.length === 64);
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  assert.match(text('pin-skill/chat-pins.txt'), /^0:verify-agent\tverify-zebra$/m);
  const log = text('pin-skill/debug.log');
  assert.match(log, /\[palette\] ready chars=11 count=\d+ target=7136(?:\s|$)/);
  assert.match(log, /\[palette\] ready chars=5 count=\d+ target=7137(?:\s|$)/);
  const raw = text('pin-skill/agent-buffer.jsonl');
  assert.ok(raw.includes('[Pinned skill: verify-zebra'));
  assert.ok(raw.includes(observed.pin.typed));
  const view = text('pin-skill/chat-view-copied.txt');
  assert.ok(view.includes(observed.pin.typed));
  assert.ok(!view.includes('[Pinned skill:'));
  for (const name of ['tab-palette-pin-row', 'tab-palette-unpin-row', 'pin-sent-message']) assert.ok(fs.statSync(path.join(dir, name + '.png')).size > 1000);
  return { feature: 'chat-pin', status: 'passed', agentBoundary: 'Real tab palette, real transcript render and the real reader; SSH transport and agent screen are isolated stand-ins', pin: { skill: 'verify-zebra', typed: observed.pin.typed } };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const dir = process.argv[2];
  const result = verify(dir);
  fs.writeFileSync(path.join(dir, 'result.json'), JSON.stringify(result, null, 2) + '\n');
  console.log('CHAT_PIN_PROOF_OK');
}
