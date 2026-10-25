const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { execFileSync } = require('node:child_process');

function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'revert-board-'));
  const input = {
    pulls: [[{ head: { ref: 'auto-revert/40229944919' }, user: { login: 'github-actions[bot]' }, title: 'Revert IGSH-837: IGSH-837 red proof', body: `This reverts commit ${'a'.repeat(40)}.\n\nAuto-Revert-Run: 40229944919\nFailed journeys: appearance\n`, merged_at: null, state: 'open' }]],
    run: { id: 40229944919, path: '.github/workflows/verify.yml', event: 'push', head_branch: 'master', head_sha: 'a'.repeat(40), status: 'completed', conclusion: 'failure', repository: { full_name: 'valentinyeo/multiprompt' }, head_repository: { full_name: 'valentinyeo/multiprompt' } },
    section: 'Done', comments: [], calls: [],
  };
  const state = path.join(root, 'state.json');
  fs.writeFileSync(state, JSON.stringify(input));
  const command = path.join(root, 'fake-command');
  fs.writeFileSync(command, `#!/usr/bin/env node
const fs = require('node:fs');
const args = process.argv.slice(2);
const file = process.env.BOARD_FIXTURE;
const data = JSON.parse(fs.readFileSync(file));
data.calls.push(args);
let result;
if (args[0] === 'api') result = args[1].includes('/pulls?') ? data.pulls : data.run;
else if (args[0] === 'task' && args[1] === 'get') result = { success: true, tasks: [{ section: data.section }] };
else if (args[0] === 'task' && args[1] === 'move') { data.section = args[args.indexOf('--section') + 1]; result = { success: true }; }
else if (args[0] === 'comment' && args[1] === 'list') {
  if (data.brokenPage) result = { success: true, comments: [], has_more: true };
  else if (data.secondPage && !args.includes('--cursor')) result = { success: true, comments: [], has_more: true, nextCursor: 'next' };
  else result = { success: true, comments: data.comments, has_more: false, total: data.comments.length };
} else if (args[0] === 'comment' && args[1] === 'add') {
  if (data.failComment) { process.stderr.write('board unavailable'); process.exit(1); }
  data.comments.push({ text: args[args.indexOf('--text') + 1] }); result = { success: true };
} else throw new Error('Unexpected command: ' + args.join(' '));
fs.writeFileSync(file, JSON.stringify(data));
process.stdout.write(JSON.stringify(result));
`, { mode: 0o700 });
  fs.symlinkSync(command, path.join(root, 'gh'));
  return {
    run: () => execFileSync(process.execPath, [path.join(__dirname, 'auto-revert-board.js')], { env: { ...process.env, PATH: `${root}${path.delimiter}${process.env.PATH}`, CEO_HT: command, BOARD_FIXTURE: state }, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }),
    read: () => JSON.parse(fs.readFileSync(state)),
    update: change => { const data = JSON.parse(fs.readFileSync(state)); change(data); fs.writeFileSync(state, JSON.stringify(data)); },
    close: () => fs.rmSync(root, { recursive: true, force: true }),
  };
}

test('real auto-revert reopens Done and posts the failed journey once across retries', t => {
  const f = fixture(); t.after(f.close);
  f.run(); f.run();
  const data = f.read();
  assert.equal(data.section, 'Todo');
  assert.equal(data.comments.length, 1);
  assert.match(data.comments[0].text, /appearance/);
  assert.match(data.comments[0].text, /40229944919/);
  const call = data.calls.find(args => args[1] === 'add');
  assert.equal(call[call.indexOf('--kind') + 1], 'qa');
  assert.ok(call.includes('--improve'));
});

for (const section of ['Doing', 'AI Review', 'Todo']) test(`active ${section} work stays owned`, t => {
  const f = fixture(); t.after(f.close);
  f.update(d => { d.section = section; }); f.run();
  assert.equal(f.read().section, section);
  assert.equal(f.read().comments.length, 1);
});

test('comment failure retries after the successful reopen', t => {
  const f = fixture(); t.after(f.close);
  f.update(d => { d.failComment = true; });
  assert.throws(f.run); assert.equal(f.read().section, 'Todo');
  f.update(d => { d.failComment = false; }); f.run();
  assert.equal(f.read().comments.length, 1);
});

test('existing comment on later page prevents a duplicate', t => {
  const f = fixture(); t.after(f.close); f.run();
  f.update(d => { d.secondPage = true; }); f.run();
  assert.equal(f.read().comments.length, 1);
});

test('incomplete board comment history fails closed', t => {
  const f = fixture(); t.after(f.close);
  f.update(d => { d.brokenPage = true; });
  assert.throws(f.run);
  assert.equal(f.read().comments.length, 0);
});

for (const [name, change] of [
  ['human-authored pull', d => { d.pulls[0][0].user.login = 'someone'; }],
  ['closed unmerged revert', d => { d.pulls[0][0].state = 'closed'; }],
  ['wrong workflow', d => { d.run.path = '.github/workflows/test.yml'; }],
  ['wrong repository', d => { d.run.head_repository.full_name = 'someone/fork'; }],
  ['successful run', d => { d.run.conclusion = 'success'; }],
  ['wrong target', d => { d.run.head_sha = 'b'.repeat(40); }],
  ['wrong run marker', d => { d.pulls[0][0].body = d.pulls[0][0].body.replace('40229944919', '40229944918'); }],
]) test(`${name} cannot reopen tickets`, t => {
  const f = fixture(); t.after(f.close); f.update(change); f.run();
  assert.equal(f.read().section, 'Done'); assert.equal(f.read().comments.length, 0);
});

test('cancelled master run with a validated bot rollback reopens the task', t => {
  const f = fixture(); t.after(f.close);
  f.update(d => { d.run.conclusion = 'cancelled'; }); f.run();
  assert.equal(f.read().section, 'Todo');
  assert.equal(f.read().comments.length, 1);
});
