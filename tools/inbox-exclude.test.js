const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const source = require('./app-source').readAppSource();
const jsonReader = fs.readFileSync(path.join(__dirname, "..", "src", "json_reader.zig"), "utf8");
const slice = (start, end) => source.slice(source.indexOf(start), source.indexOf(end, source.indexOf(start)));

test('Inbox exclusion survives save, restore, reconnect, workspace moves, and tab transfers', () => {
  assert.match(source, /inbox_excluded: bool = false/);
  assert.equal((source.match(/const ix = ",\\"inbox_excluded\\":true"/g) || []).length, 2);
  assert.match(jsonReader, /"inbox_excluded"/);
  assert.match(jsonReader, /@field\(tab, key\) = boolTrue\(obj, key\)/);
  for (const text of ['shell.inbox_excluded = tab.inbox_excluded',
    'shells[idx].inbox_excluded = tab.inbox_excluded',
    'shells[idx].inbox_excluded = tabs[t].inbox_excluded',
    '.inbox_excluded = saved_inbox_excluded',
    'transfer.inbox_excluded = if (shell.inbox_excluded) 1 else 0',
    'new_shell.inbox_excluded = transfer.inbox_excluded != 0']) {
    assert.ok(source.includes(text), text);
  }
});

test('excluded tabs leave Inbox, badge, and cached auto-advance without losing sidebar attention', () => {
  assert.match(slice('fn publishInboxStateNow()', 'fn deleteInboxStateFile'), /if \(!inboxPublishesShell\(&shells\[i\]\)\) continue/);
  assert.match(slice('fn paintInboxButton(', 'fn paintWorkspaceStrip('), /needs_attention and !shells\[i\]\.muted and inboxPublishesShell\(&shells\[i\]\)/);
  assert.match(slice('fn inboxRowVisible(', 'fn inboxListTop('), /shells\[idx\]\.inbox_excluded\) return false/);
  assert.match(slice('fn toggleInboxExcluded(', 'fn publishInboxStateNow()'), /publishInboxStateNow\(\);\s*loadInboxModel\(\)/);
  assert.doesNotMatch(slice('fn toggleInboxExcluded(', 'fn publishInboxStateNow()'), /needs_attention\s*=|activity\s*=|eta_deadline_tick\s*=/);
});

test('both palette bands classify, draw, and dispatch the toggle on the correct tab', () => {
  assert.match(source, /const SEARCH_INBOX_EXCLUDE_OFFSET: usize = 6319;/);
  assert.match(source, /const SEARCH_TABCTX_INBOX_EXCLUDE: usize = 7116;/);
  assert.match(source, /const is_inbox_exclude = result_idx == SEARCH_INBOX_EXCLUDE_OFFSET/);
  for (const name of ['newwin', 'openall', 'new_shell', 'tmux_inactive']) {
    const line = source.split('\n').find(row => row.includes(`const is_${name} =`));
    assert.match(line, /!is_inbox_exclude/);
  }
  assert.match(source, /else if \(is_inbox_exclude\) \{[\s\S]*?Inbox: Show This Session Again/);
  assert.match(source, /result_idx == SEARCH_TABCTX_INBOX_EXCLUDE\) \(if \(tc_excluded\)/);
  assert.match(source, /target <= SEARCH_TABCTX_FAVORITE\) \{/);
  assert.match(source, /target == SEARCH_INBOX_EXCLUDE_OFFSET\) \{\s*toggleInboxExcluded\(active_shell\)/);
  assert.match(source, /target == SEARCH_TABCTX_INBOX_EXCLUDE\) \{\s*toggleInboxExcluded\(ti\)/);
  assert.match(source, /\.a = "Ctrl\+K -> Inbox: Never Show This Session"/);
  const wiki = fs.readFileSync(path.join(__dirname, '..', 'openwiki', 'operations', 'keyboard-shortcuts.md'), 'utf8');
  assert.match(wiki, /Inbox: Never Show This Session/);
});
