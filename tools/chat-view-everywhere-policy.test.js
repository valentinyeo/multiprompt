const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const git = args => execFileSync('git', args, { cwd: root, encoding: 'utf8' });

function changedFiles() {
  return [...new Set([
    ...git(['diff', '--name-only', '-z', 'HEAD']).split('\0'),
    ...git(['ls-files', '--others', '--exclude-standard', '-z']).split('\0'),
  ].filter(Boolean))];
}

test('ISSUE-611 changed code has no comments and the oracle rejects a positive control', async () => {
  const { tokenize, languageFor } = await import('./strip-comments.mjs');
  assert.equal(tokenize('const value = 1; // forbidden\n', 'zig').comments.filter(comment => !comment.reason).length, 1);
  assert.equal(tokenize('# forbidden\n$value = 1\n', 'powershell').comments.filter(comment => !comment.reason).length, 1);
  let checked = 0;
  for (const file of new Set(['src/chat_view.zig', 'tools/chat-view-everywhere-policy.test.js', ...changedFiles()])) {
    const source = fs.readFileSync(path.join(root, file), 'utf8');
    const language = languageFor(file, source);
    if (!language) continue;
    const comments = tokenize(source, language).comments.filter(comment => !comment.reason);
    assert.equal(comments.length, 0, file);
    checked++;
  }
  assert.ok(checked > 0);
});

test('ISSUE-611 diff has no whitespace errors or version bumps', () => {
  assert.equal(git(['diff', '--check']), '');
  for (const file of changedFiles()) {
    assert.doesNotMatch(file, /(?:^|\/)APP_VERSION$|\.ver$/);
    const source = fs.readFileSync(path.join(root, file), 'utf8');
    assert.doesNotMatch(source, /[\t ]+\r?$/m, file);
  }
  assert.doesNotMatch(git(['diff', '--unified=0', '--', 'src']), /^\+[^+].*APP_VERSION\s*=/m);
});
