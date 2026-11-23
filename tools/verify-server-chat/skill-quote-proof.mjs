import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = process.argv[2];

export function verifySkillQuoteEvidence(rootDir) {
  const cfg = JSON.parse(fs.readFileSync(path.join(path.dirname(fileURLToPath(import.meta.url)), 'skill-quote.json'), 'utf8'));
  const text = name => fs.readFileSync(path.join(rootDir, name), 'utf8').replace(/^\uFEFF/, '');
  const json = name => JSON.parse(text(name));
  const copied = text('skill-quote-copied.txt');
  const marker = cfg.marker;
  const command = cfg.command;
  const matches = copied.match(new RegExp(command.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g')) ?? [];
  assert.equal(matches.length, 1, 'Rendered transcript must show the skill command once');
  assert.equal((copied.match(new RegExp(marker.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g')) ?? []).length, 1, 'Quoted marker must appear once in the rendered copy');
  const msgAt = copied.indexOf(command);
  const markerAt = copied.indexOf(marker);
  const replyAt = copied.indexOf('Server received:');
  assert.ok(msgAt >= 0 && markerAt > msgAt && replyAt > markerAt, 'User skill quote must sit above its server reply');
  const tail = copied.substring(copied.lastIndexOf('Server received:'));
  assert.ok((tail.match(new RegExp(marker.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g')) ?? []).length <= 1, 'Skill quote must not remain as a waiting copy below its reply');
  const server = json('skill-quote-server.json');
  const skillRows = server.commands.filter(row => row.content.includes(cfg.requiredTranscriptTags[1]));
  assert.equal(skillRows.length, 1, 'Provider transcript must retain one wrapped command row');
  for (const tag of cfg.requiredTranscriptTags) assert.ok(skillRows[0].content.includes(tag), `Missing transcript tag: ${tag}`);
  assert.ok(skillRows[0].content.includes(marker), 'Provider command-args must retain the quoted block');
  assert.match(skillRows[0].content, /already delivered to it/, 'Provider command-args must retain the mention wire note');
  const post = text('skill-quote-post-send.log');
  assert.match(post, /\[chat\] working timer stopped/, 'Working indicator must stop after the skill quote reply');
  assert.doesNotMatch(post, /\[chat\] working timer stopped[\s\S]*\[chat\] working timer started/, 'Busy dots must not return after the skill quote reply');
  assert.ok(fs.statSync(path.join(rootDir, 'skill-quote.png')).size > 1000);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  verifySkillQuoteEvidence(root);
  console.log('SOFT-3097 skill-quote server chat evidence passed');
}