const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

function read(name) {
  return fs.readFileSync(path.join(__dirname, "..", "src", name), "utf8");
}

function body(source, signature, next) {
  const start = source.indexOf(signature);
  assert.notEqual(start, -1, signature);
  const end = source.indexOf(next, start + signature.length);
  assert.notEqual(end, -1, next);
  return source.slice(start, end);
}

test("IGSH-1820 Inbox archive ignores pin state", () => {
  const sidebar = read("sidebar.zig");
  const archive = body(sidebar, "fn recordInboxArchive(", "fn archiveHasNewContentSnapshot(");
  assert.doesNotMatch(archive, /rejectPinnedSessionClose/);
  const hide = body(sidebar, "fn hideActiveTabUntilAttention(", "fn userPresentOnSelectedTab(");
  assert.doesNotMatch(hide, /rejectPinnedSessionClose/);
  const inbox = read("inbox.zig");
  assert.match(inbox, /test "IGSH-1820 E archives a pinned Inbox session and a blue dot brings a live session back"/);
  assert.match(inbox, /handleInboxKey\(null, 24\)/);
  assert.match(inbox, /shells\[0\]\.pinned_top = true/);
  assert.match(inbox, /!inboxPublishesShell\(&app_state\.shells\[0\]\)/);
  assert.match(inbox, /setBlueDot\(0, \.manual, false\)/);
});
