const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { openRequests, blockedRequests, describeRequest } = require('./permission-requests.mjs');

const fixture = name => fs.readFileSync(path.join(__dirname, 'fixtures', 'MUBO-282', name), 'utf8');
const chat = { id: 'chat-one', title: 'Migrations', host: 'example-host' };

test('MUBO-282 an auto mode step with no answer is an open request', () => {
  const rows = openRequests([{ ...chat, transcript: fixture('auto-open-request.jsonl') }]);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].chat, 'chat-one');
  assert.equal(rows[0].tool, 'Bash');
  assert.equal(rows[0].toolUseId, 'toolu_EXAMPLE_AUTO_OPEN');
  assert.equal(rows[0].mode, 'auto');
  assert.match(rows[0].detail, /psql -c 'drop table old_events'/);
  assert.match(rows[0].why, /auto mode safety check/i);
});

test('MUBO-282 answering a request closes it', () => {
  assert.deepEqual(openRequests([{ ...chat, transcript: fixture('auto-answered-request.jsonl') }]), []);
});

test('MUBO-282 a step the auto mode classifier refused is closed and reported as blocked', () => {
  const rows = [{ ...chat, transcript: fixture('auto-blocked.jsonl') }];
  assert.deepEqual(openRequests(rows), []);
  const blocked = blockedRequests(rows);
  assert.equal(blocked.length, 1);
  assert.equal(blocked[0].toolUseId, 'toolu_EXAMPLE_AUTO_BLOCKED');
  assert.match(blocked[0].why, /unauthorized access/);
});

test('MUBO-282 a bypass chat never asks, so it never lists', () => {
  const bypass = fixture('auto-open-request.jsonl').replace('"auto"', '"bypassPermissions"');
  assert.deepEqual(openRequests([{ ...chat, transcript: bypass }]), []);
});

test('MUBO-282 the newest request comes first and plain words name it', () => {
  const older = { ...chat, id: 'chat-older', transcript: fixture('auto-open-request.jsonl').replace('2026-01-01T00:00:00.000Z', '2025-12-31T00:00:00.000Z') };
  const newer = { ...chat, id: 'chat-newer', transcript: fixture('auto-open-request.jsonl') };
  const rows = openRequests([older, newer]);
  assert.deepEqual(rows.map(row => row.chat), ['chat-newer', 'chat-older']);
  assert.equal(describeRequest(rows[0]), 'Migrations wants to run a command. It is waiting for your yes because the auto mode safety check wants your yes before it runs.');
});

test('MUBO-282 reading twice gives the same rows', () => {
  const chats = [{ ...chat, transcript: fixture('auto-open-request.jsonl') }];
  assert.deepEqual(openRequests(chats), openRequests(chats));
});
