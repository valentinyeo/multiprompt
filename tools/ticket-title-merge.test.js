const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');

test('the title catalog is one file per ticket and nothing else', () => {
  assert.equal(fs.existsSync(path.join(root, 'tools/ticket-titles.json')), false, 'shared catalog file is gone');
  const dir = path.join(root, 'tools/ticket-titles');
  assert.ok(fs.statSync(dir).isDirectory(), 'catalog is a directory');
  for (const name of fs.readdirSync(dir)) {
    assert.match(name, /^(?:IGSH|HYCI)-[1-9]\d*\.txt$/);
    assert.equal(fs.readFileSync(path.join(dir, name), 'utf8').split('\n').length, 2, `${name} holds one title line`);
  }
});

test('two branches that add different ticket titles merge with no conflict', async () => {
  const mod = await import('./ticket-titles.mjs');
  assert.equal(typeof mod.ticketTitleFile, 'function', 'one loader owns the catalog layout');
  assert.equal(typeof mod.loadTicketTitles, 'function');
  const fileA = path.join('tools/ticket-titles', mod.ticketTitleFile('IGSH-90001'));
  const fileB = path.join('tools/ticket-titles', mod.ticketTitleFile('IGSH-90002'));
  assert.notEqual(fileA, fileB);

  const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'title-merge-'));
  try {
    const git = (...args) => execFileSync('git', args, { cwd: repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
    git('init', '-b', 'master');
    git('config', 'user.name', 'Merge Test');
    git('config', 'user.email', 'merge@example.invalid');
    git('config', 'commit.gpgsign', 'false');
    fs.mkdirSync(path.join(repo, 'tools'));
    fs.cpSync(path.join(root, 'tools/ticket-titles'), path.join(repo, 'tools/ticket-titles'), { recursive: true });
    git('add', '.');
    git('commit', '-m', 'base');
    for (const [branch, file, title] of [['a', fileA, 'First added title'], ['b', fileB, 'Second added title']]) {
      git('checkout', '-q', '-b', branch, 'master');
      fs.writeFileSync(path.join(repo, file), `${title}\n`);
      git('add', '.');
      git('commit', '-m', branch);
    }
    git('checkout', '-q', 'a');
    git('merge', '--no-edit', 'b');
    const merged = mod.loadTicketTitles(require('node:url').pathToFileURL(path.join(repo, 'tools/ticket-titles/')));
    assert.equal(merged['IGSH-90001'], 'First added title');
    assert.equal(merged['IGSH-90002'], 'Second added title');
  } finally {
    fs.rmSync(repo, { recursive: true, force: true });
  }
});
