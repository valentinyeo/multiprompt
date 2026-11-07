import test, { before } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
let fileLatencyWarning;
before(async () => {
  assert.ok(fs.existsSync(new URL('./resource-warning-ticket.mjs', import.meta.url)), 'Resource warning ticket handler must ship');
  ({ fileLatencyWarning } = await import('./resource-warning-ticket.mjs'));
});

const runUrl = 'https://github.com/valentinyeo/multiprompt/actions/runs/123';
const sha = 'a'.repeat(40);
const warning = { status: 'warning', worstMs: 1200, limitMs: 1000 };
const title = 'Multi Bot messages are slow to send';
const names = ['CI', 'Hypertask CI', 'Multiprompt', 'brain-medium'];
const labels = names.map((name, i) => ({ name, id: `00000000-0000-0000-0000-00000000000${i + 1}` }));

function fakeApi(pages = [[]]) {
  const calls = [];
  const api = async (method, path, body) => {
    calls.push({ method, path, body });
    const url = new URL(path, 'https://example.test');
    if (url.pathname === '/tasks/search') {
      assert.equal(url.searchParams.get('project_id'), '11514');
      assert.equal(url.searchParams.get('status'), 'Normal');
      const index = Number(url.searchParams.get('cursor') || 0);
      return { tasks: pages[index], nextCursor: index + 1 < pages.length ? String(index + 1) : null };
    }
    if (path === '/projects/11514/labels') return { labels };
    if (path === '/projects/11514/sections') return { sections: [{ id: 7, section_title: 'Backlog' }] };
    if (path === '/tasks/create') return { task: { ticketNumber: 'HYCI-999' } };
    throw new Error('Unexpected request');
  };
  return { api, calls };
}

const run = (api, result = warning, extra = {}) => fileLatencyWarning({ api, result, runUrl, sha, ...extra });

test('healthy and unmeasured results make no calls', async () => {
  const api = () => { throw new Error('Unexpected call'); };
  for (const result of [{ status: 'pass' }, { status: 'unmeasured' }, { status: 'warning', worstMs: null, limitMs: 1 }, { status: 'warning', worstMs: 1, limitMs: 1 }]) {
    assert.deepEqual(await run(api, result), { outcome: 'skipped' });
  }
});

test('warning creates a backlog ticket with existing labels and evidence', async () => {
  const { api, calls } = fakeApi();
  assert.equal((await run(api)).outcome, 'created');
  const post = calls.find(call => call.method === 'POST');
  assert.equal(post.path, '/tasks/create');
  assert.equal(post.body.project_id, 11514);
  assert.equal(post.body.section_id, 7);
  assert.equal(post.body.title, title);
  assert.deepEqual(post.body.labels, labels.map(label => label.id));
  assert.ok(post.body.description.includes(runUrl));
  assert.ok(post.body.description.includes('1200 ms'));
});

test('open warning is reused without writes', async () => {
  const task = { title, section: 'Backlog', ticketNumber: 'HYCI-1' };
  const { api, calls } = fakeApi([[task]]);
  assert.deepEqual(await run(api), { outcome: 'existing', task });
  assert.equal(calls.length, 1);
});

test('a completed ticket does not prevent a fresh ticket', async () => {
  const { api, calls } = fakeApi([[{ title, section: 'Done' }]]);
  assert.equal((await run(api)).outcome, 'created');
  assert.equal(calls.filter(call => call.method === 'POST').length, 1);
});

test('searches every page before deciding', async () => {
  const { api, calls } = fakeApi([[{ title, section: 'Done' }], [{ title, section: 'Doing' }]]);
  assert.equal((await run(api)).outcome, 'existing');
  assert.equal(calls.length, 2);
});

test('propagates API failures', async () => {
  const error = new Error('offline');
  await assert.rejects(run(async () => { throw error; }), error);
});

test('rejects untrusted evidence before any API call', async () => {
  const api = () => { throw new Error('Unexpected call'); };
  await assert.rejects(run(api, warning, { runUrl: 'https://example.com' }), /Invalid run URL/);
  await assert.rejects(run(api, warning, { sha: 'abc' }), /Invalid run URL/);
});

test('fails instead of creating missing labels', async () => {
  const fake = fakeApi();
  const api = async (method, path, body) => path.endsWith('/labels') ? { labels: labels.slice(1) } : fake.api(method, path, body);
  await assert.rejects(run(api), /Required label unavailable/);
  assert.equal(fake.calls.some(call => call.method === 'POST'), false);
});
