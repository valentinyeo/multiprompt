const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const { execFile } = require('node:child_process');

const runUrl = 'https://github.com/valentinyeo/multiprompt/actions/runs/40229944919';
const secret = 'board-credential-for-test';

async function fakeBoard(t, initial = {}) {
  const state = { section: 'Done', comments: [], calls: [], pages: false, failComment: false, ...initial };
  const sections = [{ id: 1, section_title: 'Todo' }, { id: 2, section_title: 'Done' }];
  const server = http.createServer((req, res) => {
    let raw = '';
    req.on('data', chunk => { raw += chunk; });
    req.on('end', () => {
      const url = new URL(req.url, 'http://board.test');
      const body = raw ? JSON.parse(raw) : null;
      state.calls.push({ method: req.method, path: url.pathname, query: Object.fromEntries(url.searchParams), body, auth: req.headers.authorization });
      const reply = (status, json) => { res.writeHead(status, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(json)); };
      if (req.headers.authorization !== `Bearer ${secret}`) return reply(401, { success: false });
      if (req.method === 'GET' && url.pathname === '/tasks') return reply(200, { success: true, tasks: [{ ticketNumber: url.searchParams.get('ticket_number'), section: state.section, boardId: 2060 }] });
      if (req.method === 'GET' && url.pathname === '/projects/2060/sections') return reply(200, { success: true, sections });
      if (req.method === 'POST' && url.pathname === '/tasks/update') { state.section = sections.find(section => section.id === body.sectionId).section_title; return reply(200, { success: true }); }
      if (req.method === 'GET' && url.pathname === '/comments') {
        if (state.pages && !url.searchParams.get('cursor')) return reply(200, { success: true, comments: [], has_more: true, nextCursor: 'next' });
        return reply(200, { success: true, comments: state.comments, has_more: false, nextCursor: null });
      }
      if (req.method === 'POST' && url.pathname === '/comments') {
        if (state.failComment) return reply(500, { success: false });
        state.comments.push({ text: body.text, kind: body.kind });
        return reply(200, { success: true });
      }
      return reply(404, { success: false });
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => server.close());
  const base = `http://127.0.0.1:${server.address().port}`;
  const run = (args = ['IGSH-837', runUrl, 'appearance'], env = {}) => new Promise((resolve, reject) => {
    execFile(process.execPath, [path.join(__dirname, 'auto-revert-board.js'), ...args], { env: { PATH: process.env.PATH, HYPERTASK_AGENT_TOKEN: secret, HYPERTASK_API_BASE: base, ...env }, encoding: 'utf8' }, (error, stdout, stderr) => error ? reject(Object.assign(error, { stderr })) : resolve(stdout));
  });
  return { state, run };
}

test('a Done ticket moves to Todo with one comment and a retry posts no second comment', async t => {
  const board = await fakeBoard(t);
  assert.match(await board.run(), /reopened/);
  assert.match(await board.run(), /already reopened/);
  assert.equal(board.state.section, 'Todo');
  assert.equal(board.state.comments.length, 1);
  assert.equal(board.state.comments[0].kind, 'qa');
  assert.match(board.state.comments[0].text, /appearance/);
  assert.ok(board.state.comments[0].text.includes(runUrl));
  assert.equal(board.state.calls.filter(call => call.path === '/tasks/update').length, 1);
});

for (const section of ['Doing', 'AI Review', 'Todo']) test(`active ${section} work stays where it is`, async t => {
  const board = await fakeBoard(t, { section });
  await board.run();
  assert.equal(board.state.section, section);
  assert.equal(board.state.comments.length, 1);
  assert.equal(board.state.calls.filter(call => call.path === '/tasks/update').length, 0);
});

test('a comment failure after the move is retried without moving again', async t => {
  const board = await fakeBoard(t, { failComment: true });
  await assert.rejects(board.run());
  assert.equal(board.state.section, 'Todo');
  board.state.failComment = false;
  await board.run();
  assert.equal(board.state.comments.length, 1);
  assert.equal(board.state.calls.filter(call => call.path === '/tasks/update').length, 1);
});

test('an existing comment on a later page prevents a duplicate', async t => {
  const board = await fakeBoard(t);
  await board.run();
  board.state.pages = true;
  assert.match(await board.run(), /already reopened/);
  assert.equal(board.state.comments.length, 1);
  assert.ok(board.state.calls.some(call => call.path === '/comments' && call.query.cursor === 'next'));
});

test('a wrong credential fails without changing the board and never prints it', async t => {
  const board = await fakeBoard(t);
  await assert.rejects(board.run(undefined, { HYPERTASK_AGENT_TOKEN: 'wrong-credential' }), error => {
    assert.ok(!error.stderr.includes('wrong-credential'));
    return /failed with status 401/.test(error.stderr);
  });
  assert.equal(board.state.section, 'Done');
  assert.equal(board.state.comments.length, 0);
});

test('a missing credential or bad arguments fail before any board call', async t => {
  const board = await fakeBoard(t);
  await assert.rejects(board.run(undefined, { HYPERTASK_AGENT_TOKEN: '' }), error => /HYPERTASK_AGENT_TOKEN is not set/.test(error.stderr));
  await assert.rejects(board.run(['not-a-ticket', runUrl, 'appearance']), error => /Usage/.test(error.stderr));
  await assert.rejects(board.run(['IGSH-837', 'https://example.com/run', 'appearance']), error => /Usage/.test(error.stderr));
  assert.equal(board.state.calls.length, 0);
});

test('the workflow gives the board step only its own agent secret and GitHub calls use the job token', () => {
  const workflow = fs.readFileSync(path.join(__dirname, '..', '.github', 'workflows', 'auto-revert-master.yml'), 'utf8');
  assert.match(workflow, /HYPERTASK_AGENT_TOKEN: \$\{\{ secrets\.HYPERTASK_AGENT_TOKEN \}\}/);
  assert.match(workflow, /GH_TOKEN: \$\{\{ github\.token \}\}/);
  assert.ok(!/secrets\.(?!HYPERTASK_AGENT_TOKEN\b)/.test(workflow));
  assert.ok(!/valentinyeo\//.test(workflow));
});

test('no poller, timer or unit file is left in the repository', () => {
  const root = path.join(__dirname, '..');
  assert.ok(!fs.existsSync(path.join(root, 'tools', 'systemd')));
  const docs = fs.readFileSync(path.join(root, 'openwiki', 'operations', 'build-and-install.md'), 'utf8');
  assert.ok(!/multiprompt-revert-board|systemctl/.test(docs));
});
