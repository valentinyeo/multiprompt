import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export function verify(dir) {
  const read = file => JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8').replace(/^\uFEFF/, ''));
  const observed = read('fresh-skills/observation.json');
  const doctor = read('fresh-skills/doctor.json');
  const cleanup = read('cleanup.json');
  assert.equal(observed.error, null);
  assert.ok(doctor.pid > 0 && doctor.chat && doctor.sha256.length === 64);
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  assert.ok(observed.skills.newSkillMs > 0 && observed.skills.newSkillMs <= 5000);
  assert.equal(observed.skills.selected, '/verify-yak ');
  assert.equal(observed.skills.accepted, '/verify-alpha ');
  assert.equal(observed.skills.reload, true);
  const requests = fs.readFileSync(path.join(dir, 'fresh-skills/stand-in/completion.jsonl'), 'utf8').trim().split('\n').map(JSON.parse);
  assert.ok(requests[0].names.includes('verify-zebra'));
  assert.ok(!requests[0].names.includes('verify-alpha'));
  assert.ok(requests.slice(1).some(row => row.names.includes('verify-alpha')));
  assert.ok(requests.some(row => row.names.includes('verify-beta')));
  for (const name of ['fresh-skills-before', 'fresh-skills-refreshed', 'fresh-skills-after']) assert.ok(fs.statSync(path.join(dir, name + '.png')).size > 1000);
  return { feature: 'chat-skills', status: 'passed', agentBoundary: 'Real skill discovery and native composer; SSH transport and agent screen are isolated stand-ins', skills: observed.skills };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const dir = process.argv[2];
  const result = verify(dir);
  fs.writeFileSync(path.join(dir, 'result.json'), JSON.stringify(result, null, 2) + '\n');
  console.log('CHAT_SKILLS_PROOF_OK');
}
