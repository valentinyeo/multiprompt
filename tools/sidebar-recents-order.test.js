const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const sidebar = fs.readFileSync(path.join(__dirname, "..", "src", "sidebar.zig"), "utf8");

function between(start, end) {
  const a = sidebar.indexOf(start);
  const b = sidebar.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `${start} .. ${end}`);
  return sidebar.slice(a, b).replaceAll("app_state.", "");
}

test("Recents sorts by the chat you used last and ignores agent activity", () => {
  const key = between("fn sidebarUseKey(", "pub inline fn effPinnedTop(");
  assert.match(key, /shells\[i\]\.last_viewed/, "opening a chat must set its place");
  assert.match(key, /shells\[i\]\.last_used/, "sending in a chat must set its place");
  assert.doesNotMatch(key, /last_active|needs_attention|activity/, "a bot reply alone must not move a chat");
});

test("Pinned keeps the drag order while Recents follows use", () => {
  const blocks = between("fn sidebarBlockBefore(", "fn buildSortedOrder(");
  assert.match(blocks, /if \(a\.is_group != b\.is_group\) return a\.is_group;/, "groups stay above ungrouped rows");
  assert.match(blocks, /if \(a\.is_group\) return a\.pos < b\.pos;/, "group blocks keep their order");
  assert.match(blocks, /if \(a\.tier == \.pinned\) return a\.pos < b\.pos;/, "dragging still orders Pinned");
  assert.match(blocks, /if \(a\.used != b\.used\) return a\.used > b\.used;/, "Recents follows the use key");
  assert.doesNotMatch(blocks, /needs_attention|is_active/, "a blue dot or a working agent must not reorder the sidebar");
});
