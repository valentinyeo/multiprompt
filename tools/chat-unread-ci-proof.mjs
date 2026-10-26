import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { dividerPixels } from './chat-messages-only-proof.mjs';
import { readBmp } from './chat-code-font-proof.mjs';

const root = path.resolve(process.argv[2]);
const json = file => JSON.parse(fs.readFileSync(path.join(root, file), 'utf8').replace(/^\uFEFF/, ''));
try {
  const observation = json('messages-only/observation.json');
  const cleanup = json('cleanup.json');
  const build = json('build.json');
  const doctors = [json('doctor.json')].flat();
  assert.equal(observation.error, null);
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  assert.equal(doctors.length, 1);
  assert.equal(doctors[0].identity.version, build.version);
  assert.equal(doctors[0].identity.sha256.toLowerCase(), build.sha256.toLowerCase());
  assert.equal(observation.newMessages.passed, true);
  assert.equal(observation.unreadDivider.passed, true);
  assert.equal(observation.activeDivider.count, 0);
  const active = dividerPixels(readBmp(path.join(root, 'unread-active-session.bmp')), observation.transcript, 0, 0);
  assert.ok(typeof observation.focusedReplyText === 'string' && observation.focusedReplyText.includes('IGSH871 focused revisit arrival.'), 'The actual focused reply must be rendered before no-divider evidence');
  assert.equal(observation.revisitActiveDivider.count, 0);
  dividerPixels(readBmp(path.join(root, 'unread-active-revisit.bmp')), observation.transcript, 0, 0);
  const boundary = json('messages-only/unread-divider.json');
  const rows = fs.readFileSync(path.join(root, 'messages-only/app-cache-reopened.jsonl'), 'utf8').trim().split(/\r?\n/).slice(1).map(line => JSON.parse(line));
  const read = rows.findIndex(row => row.id === boundary.readId);
  assert.ok(read >= 0);
  const firstUnread = rows.slice(read + 1).find(row => row.role === 'user' || row.role === 'assistant');
  assert.equal(firstUnread.id, boundary.firstUnreadId);
  assert.equal(firstUnread.offset, boundary.unreadOffset);
  assert.equal(boundary.reopened.offset, firstUnread.offset);
  assert.ok(boundary.reopened.y < boundary.reopened.messageY);
  for (const phase of ['reopened', 'bottom', 'sent']) {
    assert.equal(boundary[phase].count, 1);
    assert.equal(boundary[phase].unknown, 0);
  }
  assert.equal(boundary.bottom.marker, boundary.marker);
  assert.equal(boundary.sent.marker, boundary.beforeSend.marker);
  assert.equal(boundary.sent.offset, boundary.beforeSend.offset);
  assert.equal(boundary.allRead.count, 0);
  assert.equal(json('messages-only/restart-process-tree.json').ActiveProcesses, 0);
  const divider = dividerPixels(readBmp(path.join(root, 'unread-divider-reopened.bmp')), boundary.transcript, boundary.transcript.top + boundary.reopened.lineY - boundary.reopened.scroll, 1);
  dividerPixels(readBmp(path.join(root, 'unread-divider-all-read.bmp')), boundary.transcript, 0, 0);
  const actions = json('actions.json');
  assert.ok(actions.some(action => action.input === 'two new arrivals while reading' && action.state.count === 2 && action.state.visible === 1 && action.state.up === 1));
  assert.ok(actions.some(action => action.input === 'Ctrl+Tab: return to the unread tab'));
  const badgeImage = readBmp(path.join(root, 'new-messages-visible.bmp'));
  const transcript = observation.badgeTranscript;
  let blue = 0;
  for (let y = transcript.top + transcript.height - 100; y < transcript.top + transcript.height; y++) {
    for (let x = transcript.left + transcript.width - 60; x < transcript.left + transcript.width; x++) {
      const color = badgeImage.pixels.readUIntLE((y * badgeImage.width + x) * 4, 3);
      const red = color >> 16;
      const green = (color >> 8) & 255;
      const blueChannel = color & 255;
      if (red < 130 && green > 110 && blueChannel > 210) blue++;
    }
  }
  assert.ok(blue > 20, 'Count badge must actually be painted on the jump button');
  fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify({feature: 'chat-unread', status: 'passed', version: build.version, sha256: build.sha256, active, divider, badge: {count: 2, bluePixels: blue, transcript}, cleanup, agentBoundary: 'scripted provider transcript through real persistent reader; no AI provider called'}, null, 2));
  console.log('RELEASED_UNREAD_JOURNEY_OK');
} catch (error) {
  fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify({feature: 'chat-unread', status: 'failed', error: error.stack}, null, 2));
  console.error(error);
  process.exitCode = 1;
}
