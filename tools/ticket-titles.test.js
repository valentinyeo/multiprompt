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

test('SOFT inputs reuse canonical catalog entries and fetch each ticket once', async () => {
  const { ticketRecord, ticketTitleFile, resolveTicketTitles } = await load();
  assert.deepEqual(ticketRecord('SOFT-2489', 'Saved chats'), { id: 'IGSH-2489', title: 'Saved chats' });
  assert.equal(ticketTitleFile('SOFT-2489'), 'IGSH-2489.txt');
  assert.deepEqual(await resolveTicketTitles(['SOFT-2489'], { 'IGSH-2489': 'Saved chats' }), { 'IGSH-2489': 'Saved chats' });
  assert.deepEqual(await resolveTicketTitles(['IGSH-2489'], { 'SOFT-2489': 'Saved chats' }), { 'IGSH-2489': 'Saved chats' });
  let calls = 0;
  const request = async () => {
    calls++;
    return { ok: true, json: async () => ({ success: true, tasks: [{ boardId: 2060, ticketNumber: 'SOFT-2489', uniqueIndex: 2489, title: 'Saved chats' }] }) };
  };
  assert.deepEqual(await resolveTicketTitles(['SOFT-2489', 'IGSH-2489'], {}, 'token', request), { 'IGSH-2489': 'Saved chats' });
  assert.equal(calls, 1);
  for (const task of [
    { boardId: 11514, ticketNumber: 'SOFT-2489' },
    { boardId: 2060, ticketNumber: 'HYCI-2489' },
    { boardId: 2060, ticketNumber: 'SOFT-2488' },
    { boardId: 2060, ticketNumber: 'SOFT-2489', uniqueIndex: 2488 },
  ]) {
    await assert.rejects(resolveTicketTitles(['SOFT-2489'], {}, 'token', async () => ({ ok: true, json: async () => ({ success: true, tasks: [{ title: 'Wrong ticket', ...task }] }) })), /Unresolved title for IGSH-2489/);
  }
});

test('SOFT title files load under the canonical ID and conflicting aliases fail', async t => {
  const { loadTicketTitles } = await load();
  const os = require('node:os');
  const { pathToFileURL } = require('node:url');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ticket-titles-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const url = pathToFileURL(`${dir}${path.sep}`);
  fs.writeFileSync(path.join(dir, 'SOFT-2489.txt'), 'Saved chats\n');
  assert.deepEqual(loadTicketTitles(url), { 'IGSH-2489': 'Saved chats' });
  fs.writeFileSync(path.join(dir, 'IGSH-2489.txt'), 'Saved chats\n');
  assert.deepEqual(loadTicketTitles(url), { 'IGSH-2489': 'Saved chats' });
  fs.writeFileSync(path.join(dir, 'IGSH-2489.txt'), 'Different title\n');
  assert.throws(() => loadTicketTitles(url), /Conflicting titles for IGSH-2489/);
});

test('a board 2060 ticket renumbered to SOFT still resolves under its IGSH id', async () => {
  const { resolveTicketTitles } = await load();
  const request = async () => ({ ok: true, json: async () => ({ success: true, tasks: [{ boardId: 2060, ticketNumber: 'SOFT-1920', title: 'Renamed board title' }] }) });
  assert.deepEqual(await resolveTicketTitles(['IGSH-1920'], {}, 'token', request), { 'IGSH-1920': 'Renamed board title' });
  const wrong = async () => ({ ok: true, json: async () => ({ success: true, tasks: [{ boardId: 2060, ticketNumber: 'SOFT-1921', title: 'Other' }] }) });
  await assert.rejects(resolveTicketTitles(['IGSH-1920'], {}, 'token', wrong), /Unresolved title for IGSH-1920/);
});
