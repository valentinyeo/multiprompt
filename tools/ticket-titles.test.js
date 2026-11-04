const { test } = require('node:test');
const assert = require('node:assert/strict');

const load = () => import('./ticket-titles.mjs');

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
