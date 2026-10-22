const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = require('./app-source').readAppSource();

test("PINNED and RECENTS are drop targets without stealing custom-group state", () => {
  const start = source.indexOf("fn sidebarTierForDrop(hit: HitTarget) ?SidebarTier {");
  assert.notEqual(start, -1, "sidebar drag handling needs one shared tier resolver");
  const end = source.indexOf("\n}", start);
  const helper = source.slice(start, end + 2);

  assert.match(helper, /\.section => \|tier\| tier/,
    "dropping on a section label must select that tier");
  assert.match(helper, /\.tab => \|idx\| if \(idx < shell_count and tabGroupId\(idx\) == 0\) shellSidebarTier\(idx\) else null/,
    "only ungrouped session rows should inherit a global pin tier");
  const groupStart = source.indexOf("fn tabGroupId(idx: usize) u32 {");
  assert.notEqual(groupStart, -1);
  const groupHelper = source.slice(groupStart, source.indexOf("\n}", groupStart) + 2);
  assert.match(groupHelper, /return if \(g_starred_workspace\) shells\[idx\]\.starred_group_id else shells\[idx\]\.group_id;/,
    "drop targets must use the group membership of the current workspace");
  assert.match(helper, /\.header => null/,
    "a group header is a membership target and must preserve pin and lock state");
});

test("sidebar mouse movement changes pin state without changing lock state", () => {
  const start = source.indexOf("const logical_my_drag = my + g_sidebar_scroll;", source.indexOf("WM_MOUSEMOVE =>"));
  const end = source.indexOf("if (target_opt) |target|", start);
  assert.notEqual(start, -1);
  assert.notEqual(end, -1);
  const dragRouting = source.slice(start, end);

  assert.match(dragRouting, /sidebarTierForDrop\(ht\)/,
    "mouse drag must resolve the tier for PINNED and RECENTS");
  assert.doesNotMatch(dragRouting, /\.locked => \{/,
    "lock is a close guard, not a draggable section");
  assert.match(dragRouting, /\.pinned => \{\s*shells\[drag_src\]\.pinned_top = true/,
    "dragging into PINNED must pin the session");
  assert.match(dragRouting, /\.recent => \{\s*shells\[drag_src\]\.pinned_top = false/,
    "dragging into RECENTS must unpin the session");
  assert.doesNotMatch(dragRouting, /shells\[drag_src\]\.locked = false/,
    "pin changes must preserve the independent close guard");
  assert.match(dragRouting, /\.tab => \|t\| if \(!drag_section_only\)/,
    "auto-sort drags must change tier without converting the sidebar to manual order");
});
