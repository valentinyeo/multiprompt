const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const load = async () => {
  assert.ok(fs.existsSync(path.join(__dirname, 'ticket-titles.mjs')), 'ticket title module exists');
  return import('./ticket-titles.mjs');
};

test('ticket records preserve authoritative Unicode titles', async () => {
  const { ticketRecord, ticketLine } = await load();
  assert.equal(ticketLine(ticketRecord('IGSH-1681', 'What’s new: full ticket titles')), 'IGSH-1681 What’s new: full ticket titles');
  for (const title of ['', ' ', ' bad', 'bad\nline', 'Checks and fixes, no visible change']) {
    assert.throws(() => ticketRecord('IGSH-1681', title), /title/);
  }
  assert.throws(() => ticketRecord('IGSH-0', 'Title'), /ticket ID/);
});

test('only missing titles are fetched and invalid responses fail closed', async () => {
  const { resolveTicketTitles } = await load();
  const calls = [];
  const request = async (url, options) => {
    calls.push([url, options]);
    return { ok: true, json: async () => ({ success: true, tasks: [{ boardId: 2060, ticketNumber: 'IGSH-2', title: 'Second title' }] }) };
  };
  assert.deepEqual(await resolveTicketTitles(['IGSH-1', 'IGSH-2', 'IGSH-2'], { 'IGSH-1': 'First title' }, 'token', request), { 'IGSH-1': 'First title', 'IGSH-2': 'Second title' });
  assert.equal(calls.length, 1);
  assert.match(calls[0][0], /ticket_number=IGSH-2$/);
  assert.equal(calls[0][1].redirect, 'error');
  await assert.rejects(resolveTicketTitles(['IGSH-3'], {}, '', request), /Missing title/);
  await assert.rejects(resolveTicketTitles(['IGSH-3'], {}, 'token', request), /Unresolved title/);
  await assert.rejects(resolveTicketTitles(['IGSH-1'], { 'IGSH-1': '' }, '', request), /title/);
});

test('a board 2060 ticket renumbered to SOFT still resolves under its IGSH id', async () => {
  const { resolveTicketTitles } = await load();
  const request = async () => ({ ok: true, json: async () => ({ success: true, tasks: [{ boardId: 2060, ticketNumber: 'SOFT-1920', title: 'Renamed board title' }] }) });
  assert.deepEqual(await resolveTicketTitles(['IGSH-1920'], {}, 'token', request), { 'IGSH-1920': 'Renamed board title' });
  const wrong = async () => ({ ok: true, json: async () => ({ success: true, tasks: [{ boardId: 2060, ticketNumber: 'SOFT-1921', title: 'Other' }] }) });
  await assert.rejects(resolveTicketTitles(['IGSH-1920'], {}, 'token', wrong), /Unresolved title for IGSH-1920/);
});
