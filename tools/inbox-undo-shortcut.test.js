const assert = require("assert");
const fs = require("fs");
const path = require("path");

const source = require('./app-source').readAppSource();

const hookStart = source.indexOf("fn keyboardHookProc(");
const hookEnd = source.indexOf("\nfn pointOverActiveShell", hookStart);
assert.notStrictEqual(hookStart, -1, "keyboard hook is missing");
assert.notStrictEqual(hookEnd, -1, "could not isolate keyboard hook");
const hook = source.slice(hookStart, hookEnd);
assert.match(
  hook,
  /kb\.vkCode == 0x5A[\s\S]*?PostMessageW\(g_main_hwnd, WM_APP_INBOX_KEY, 29, 0\)/,
  "Alt+Z must dispatch the existing one-level Waiting undo",
);

const hideStart = source.indexOf("fn hideActiveTabUntilAttention(");
const hideEnd = source.indexOf("\nfn markShellUnread", hideStart);
assert.notStrictEqual(hideStart, -1, "Alt+E hide function is missing");
const hide = source.slice(hideStart, hideEnd);
assert.match(hide, /const was_att = shells\[idx\]\.needs_attention/,
  "Alt+E must retain the session's prior blue-dot state");
assert.strictEqual((hide.match(/rememberInboxArchiveUndo\(/g) || []).length, 2,
  "both successful Alt+E advance paths must populate undo, but the no-other-tab failure path must not");

const archiveStart = source.indexOf("fn inboxArchiveRow(");
const archiveEnd = source.indexOf("\nfn inboxUndoLastArchive", archiveStart);
assert.notStrictEqual(archiveStart, -1, "Inbox archive function is missing");
assert.match(source.slice(archiveStart, archiveEnd), /rememberInboxArchiveUndo\(owner, row\.sid, row\.att\)/,
  "Inbox e/Alt+E must share the same undo slot as session-view Alt+E");
assert.match(source.slice(archiveStart, archiveEnd), /rememberPendingInboxArchive\(owner, row\.sid\)/,
  "Inbox archive must filter the stale published row while the owner handles the request");
assert.match(source.slice(archiveStart, archiveEnd), /publishInboxStateNow\(\)/,
  "local Inbox archive must publish before the next refresh");
assert.match(source.slice(source.indexOf("fn loadInboxFile("), source.indexOf("fn inboxRowLess(")),
  /archive_rules\.hidePendingInboxArchive\(hwnd_val, @truncate\(sid\)/,
  "Inbox reload must skip still-published archived rows");
assert.match(source.slice(source.indexOf("WM_APP_INBOX_ARCHIVE, WM_APP_INBOX_MARKUNREAD"), source.indexOf("WM_APP_SESSION_INTERACTED =>")),
  /msg == WM_APP_INBOX_ARCHIVE or msg == WM_APP_INBOX_UNARCHIVE\)[\s\S]*?publishInboxStateNow\(\)/,
  "the owning window must publish archive/undo synchronously");

assert.match(
  source,
  /WM_APP_INBOX_KEY => \{[\s\S]*?else if \(wp == 29\)[\s\S]*?inboxUndoLastArchive\(hwnd\)/,
  "Alt+Z must work even when the Inbox overlay is closed",
);
assert.match(source, /\.a = "Alt\+Z", \.b = "Undo the most recent move to Waiting"/,
  "the native shortcut overlay must advertise Alt+Z");

console.log("PASS: Alt+Z universally undoes the most recent move to Waiting");
