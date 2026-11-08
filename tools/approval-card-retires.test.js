const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function body(file, name) {
  const source = fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  const end = source.indexOf('\n}', start);
  assert.ok(end > start, name);
  return source.slice(start, end + 2);
}

function dismissal() {
  const sync = body('src/chat_session.zig', 'chatLiveSyncCard');
  const start = sync.indexOf('live.cardDismissed(shell_id)');
  assert.ok(start >= 0, 'the card sync reads the resolved request');
  return { sync, start, branch: sync.slice(start) };
}

test('IGSH-1870 a resolved approval retires the answered card as well as an unanswered one', () => {
  const { branch } = dismissal();
  assert.doesNotMatch(branch, /presentation\.state == \.pending\)/, 'an answered card stays pinned when only pending cards retire');
  assert.match(branch, /if \(presentation\.state != \.absent\) \{\s*presentation\.state = \.absent;/, 'every shown card becomes absent once its request resolves');
});

test('IGSH-1870 the resolution is consumed even when another chat owns the shared permission menu', () => {
  const { sync, start } = dismissal();
  const fallback = sync.slice(sync.indexOf('return;\n    }\n', sync.indexOf('live.approvalMenu(')) + 1, start);
  assert.doesNotMatch(fallback, /g_chat_permission_sid != shell_id/, 'a menu owned by another chat must not keep this chat card alive');
  assert.doesNotMatch(fallback, /g_chat_permission\.count == 0\) return/, 'an already cleared menu must not keep the card alive');
});

test('IGSH-1870 the live stream marks the card dismissed only for the request it answers', () => {
  const live = fs.readFileSync(path.join(__dirname, '..', 'src/chat_live.zig'), 'utf8');
  const start = live.indexOf('std.mem.eql(u8, kind, "approval.resolved")');
  assert.ok(start >= 0);
  const branch = live.slice(start, live.indexOf('"turn.ended"', start));
  assert.match(branch, /std\.mem\.eql\(u8, self\.request\.idSlice\(\), strOf\(payload, "request_id"\)\)/);
  assert.match(branch, /self\.card_dismissed = true;/);
});
