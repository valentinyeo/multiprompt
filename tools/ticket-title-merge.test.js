const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { canonicalTicketId, parseTicketId } = require('./ticket-id.js');

const root = path.resolve(__dirname, '..');

function holdsOneTitleLine(content) {
  const line = content.replace(/\r?\n$/, '');
  return line !== '' && !/[\r\n]/.test(line);
}

test('the title catalog is one file per ticket and nothing else', () => {
  assert.equal(fs.existsSync(path.join(root, 'tools/ticket-titles.json')), false, 'shared catalog file is gone');
  const dir = path.join(root, 'tools/ticket-titles');
  assert.ok(fs.statSync(dir).isDirectory(), 'catalog is a directory');
  for (const name of fs.readdirSync(dir)) {
    const ticket = parseTicketId(name.slice(0, -'.txt'.length));
    assert.ok(ticket, `${name} names a known ticket`);
    assert.equal(name, `${canonicalTicketId(ticket.id)}.txt`, `${name} is the canonical file name for its ticket`);
    assert.ok(holdsOneTitleLine(fs.readFileSync(path.join(dir, name), 'utf8')), `${name} holds one title line`);
  }
});

test('a title file is one non-empty line with or without one final newline', () => {
  assert.equal(holdsOneTitleLine('Open the saved chat'), true, 'no final newline is valid');
  assert.equal(holdsOneTitleLine('Open the saved chat\n'), true, 'one final newline is valid');
  assert.equal(holdsOneTitleLine('Open the saved chat\r\n'), true, 'one final CRLF is valid');
  assert.equal(holdsOneTitleLine('Open the saved chat\nRename it\n'), false, 'two lines are invalid');
  assert.equal(holdsOneTitleLine('Open the saved chat\nRename it'), false, 'two lines without a final newline are invalid');
  assert.equal(holdsOneTitleLine(''), false, 'an empty file is invalid');
  assert.equal(holdsOneTitleLine('\n'), false, 'a blank line is invalid');
  assert.equal(holdsOneTitleLine('\n\n'), false, 'a file of blank lines is invalid');
});

test('the loader reads a title file that ends without a newline', async () => {
  const mod = await import('./ticket-titles.mjs');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'title-newline-'));
  try {
    fs.writeFileSync(path.join(dir, mod.ticketTitleFile('IGSH-90003')), 'A title with no final newline');
    const titles = mod.loadTicketTitles(require('node:url').pathToFileURL(`${dir}/`));
    assert.equal(titles['IGSH-90003'], 'A title with no final newline');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
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
