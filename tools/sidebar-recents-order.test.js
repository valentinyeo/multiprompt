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

const main = fs.readFileSync(path.join(__dirname, "..", "src", "main.zig"), "utf8");

function block(source, start, end) {
  const a = source.indexOf(start);
  const b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `${start} .. ${end}`);
  return source.slice(a, b);
}

test("A click under the pointer keeps its row in place until the pointer leaves the sidebar", () => {
  const key = between("fn sidebarUseKey(", "pub inline fn effPinnedTop(");
  assert.match(key, /if \(!g_sidebar_order_frozen\) return sidebarLiveUseKey\(i\);/, "a thawed sidebar follows the live use key");
  assert.match(key, /return shells\[i\]\.frozen_use_key\.\?;/, "a frozen sidebar answers from the snapshot, not from the click");
  assert.match(key, /for \(0\.\.shell_count\) \|i\| shells\[i\]\.frozen_use_key = sidebarLiveUseKey\(i\);/, "freezing snapshots every row before the click lands");
  assert.match(key, /for \(0\.\.shell_count\) \|i\| shells\[i\]\.frozen_use_key = null;/, "thawing drops the snapshot so rows reorder");
  const down = block(main, "WM_LBUTTONDOWN => {", "headerClick(mx, my)");
  assert.match(down, /freezeSidebarOrder\(\)/, "a press in the sidebar freezes the order before the chat switch stamps the row");
  const move = block(main, "WM_MOUSEMOVE => {", "const room_hover");
  assert.match(move, /pointer_in_sidebar/, "the whole sidebar counts, not only a hovered row");
  assert.match(move, /freezeSidebarOrder\(\)/, "entering the sidebar freezes the order");
  assert.match(move, /thawSidebarOrder\(\)/, "leaving the sidebar releases it");
  const leave = block(main, "0x02A3 => {", "WM_MOUSEMOVE => {");
  assert.match(leave, /thawSidebarOrder\(\)/, "pointer leaving the window releases the order");
});
