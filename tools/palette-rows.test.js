const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const state = read('src/app_state.zig');
const palette = read('src/command_palette.zig');
const sidebar = read('src/sidebar.zig');
const main = read('src/main.zig');

function offsets(text) {
  return new Map([...text.matchAll(/pub const (SEARCH_\w+_OFFSET): usize = (\d+);/g)]
    .map(([, name, value]) => [name, Number(value)]));
}

function uniqueOffsets(values) {
  const names = new Map();
  for (const [name, value] of values) {
    names.set(value, [...(names.get(value) || []), name]);
  }
  const collisions = [...names].filter(([, group]) => group.length > 1);
  assert.equal(collisions.length, 0, collisions.map(([value, group]) =>
    `SEARCH offsets collide at ${value}: ${group.join(', ')}`).join('\n'));
}

function comparisons(text, variable, values) {
  const found = new Set();
  const comparison = new RegExp(`\\b${variable}\\s*(?:==|>=|<=|>|<)\\s*(SEARCH_\\w+_OFFSET)\\b`, 'g');
  for (const [, name] of text.matchAll(comparison)) found.add(name);
  const range = new RegExp(`\\b${variable}\\s*(>=|>)\\s*(SEARCH_\\w+_OFFSET)\\s+and\\s+${variable}\\s*(<=|<)\\s*(SEARCH_\\w+_OFFSET)\\b(?!\\s*\\+)`, 'g');
  for (const [, lowerOp, lower, upperOp, upper] of text.matchAll(range)) {
    for (const [name, value] of values) {
      if ((lowerOp === '>=' ? value >= values.get(lower) : value > values.get(lower)) &&
          (upperOp === '<=' ? value <= values.get(upper) : value < values.get(upper))) found.add(name);
    }
  }
  const switches = new RegExp(`switch\\s*\\(${variable}\\)\\s*\\{([^]*?)\\n\\s*\\}`, 'g');
  for (const [, body] of text.matchAll(switches)) {
    for (const [, names] of body.matchAll(/((?:SEARCH_\w+_OFFSET\s*(?:\.\.\.\s*SEARCH_\w+_OFFSET)?\s*,?\s*)+) =>/g)) {
      for (const name of names.match(/SEARCH_\w+_OFFSET/g)) found.add(name);
      const bounds = names.match(/(SEARCH_\w+_OFFSET)\s*\.\.\.\s*(SEARCH_\w+_OFFSET)/);
      if (bounds) {
        for (const [name, value] of values) {
          if (value >= values.get(bounds[1]) && value <= values.get(bounds[2])) found.add(name);
        }
      }
    }
  }
  return found;
}

function painted(text, values) {
  const start = text.indexOf('const result_idx = app_state.g_search_results[ri];');
  assert.notEqual(start, -1, 'palette paint loop');
  text = text.slice(start);
  const definitions = new Map([...text.matchAll(/const (is_\w+) = ([^;]+);/g)]
    .map(([, name, expression]) => [name, expression]));
  text = text.replace(/const is_\w+ = [^;]+;/g, '');
  const conditions = [...text.matchAll(/\bif\s*\(([^{};]+?)\)/g)].map(([, condition]) => condition);
  const reached = new Set();
  for (let i = 0; i < conditions.length; i++) {
    for (const [, name] of conditions[i].matchAll(/(?<!!)\b(is_\w+)\b/g)) {
      if (!reached.has(name) && definitions.has(name)) {
        reached.add(name);
        conditions.push(definitions.get(name));
      }
    }
  }
  const switches = [...text.matchAll(/switch\s*\(result_idx\)\s*\{[^]*?\n\s*\}/g)].map(([body]) => body);
  return comparisons([...conditions, ...switches].join('\n'), 'result_idx', values);
}

function checkRows(paletteText, paintText, confirmText, values) {
  const rows = new Set([...paletteText.matchAll(/\bg_search_results\[[^\]]+\]\s*=\s*(SEARCH_\w+_OFFSET)\s*;/g)]
    .map(([, name]) => name));
  assert.ok(rows.size > 0, 'palette rows were found');
  const paint = painted(paintText, values);
  const confirm = comparisons(confirmText, 'target', values);
  for (const name of rows) {
    assert.ok(values.has(name), `${name} must be declared in src/app_state.zig`);
    assert.ok(paint.has(name), `Ctrl+K row ${name} is added in src/command_palette.zig but never painted in src/sidebar.zig paint (it falls through to the shell-row branch and crashes, see b2cefed); add an is_x branch`);
    assert.ok(confirm.has(name), `Ctrl+K row ${name} is added in src/command_palette.zig but never handled in src/main.zig confirm; add a target comparison and handler`);
  }
}

const values = offsets(state);
const confirmStart = main.indexOf('WM_APP_SEARCH_CONFIRM => {');
assert.notEqual(confirmStart, -1, 'palette confirm message');
const confirm = main.slice(confirmStart, main.indexOf('\n        WM_', confirmStart + 1));

test('every SEARCH offset has a unique numeric value', () => {
  assert.ok(values.size > 0);
  uniqueOffsets(values);
  assert.throws(() => uniqueOffsets(offsets('pub const SEARCH_A_OFFSET: usize = 1;\npub const SEARCH_B_OFFSET: usize = 1;')),
    /SEARCH_A_OFFSET, SEARCH_B_OFFSET/);
});

test('IGSH-820 removed lock commands cannot return or reuse the per-tab ID', () => {
  for (const name of values.keys()) assert.doesNotMatch(name, /SEARCH_CHAT_VIEW_LOCK_|SEARCH_LOCK_SESSION_OFFSET|SEARCH_TABCTX_LOCK|SEARCH_TABCTX_VIEW_/);
  assert.ok(![...values.values()].includes(6345));
});

test('every directly added Ctrl+K row is painted and confirmed', () => {
  checkRows(palette, sidebar, confirm, values);
});

test('imports and unused classifiers cannot hide missing paint or confirm branches', () => {
  const row = 'g_search_results[0] = SEARCH_VOICE_STOP_OFFSET;';
  const missingPaint = sidebar.replace('} else if (is_voice_stop) {', '} else if (false) {');
  assert.notEqual(missingPaint, sidebar);
  assert.throws(() => checkRows(row, missingPaint, confirm, values), /SEARCH_VOICE_STOP_OFFSET.*never painted/);
  assert.throws(() => checkRows(row, sidebar, 'const SEARCH_VOICE_STOP_OFFSET = @import("app_state.zig").SEARCH_VOICE_STOP_OFFSET;', values),
    /SEARCH_VOICE_STOP_OFFSET.*never handled/);
});

test('bounded comparisons and switch ranges cover intermediate row offsets', () => {
  const sample = new Map([['SEARCH_A_OFFSET', 1], ['SEARCH_B_OFFSET', 2], ['SEARCH_C_OFFSET', 3]]);
  assert.ok(comparisons('target >= SEARCH_A_OFFSET and target <= SEARCH_C_OFFSET', 'target', sample).has('SEARCH_B_OFFSET'));
  assert.ok(comparisons('switch (target) {\nSEARCH_A_OFFSET ... SEARCH_C_OFFSET => {},\n}', 'target', sample).has('SEARCH_B_OFFSET'));
  assert.ok(!comparisons('target >= SEARCH_A_OFFSET', 'target', sample).has('SEARCH_B_OFFSET'));
});


test('ISSUE-265 Stop is painted, searchable and dispatched for the exact context tab', () => {
  assert.match(state, /pub const SEARCH_TABCTX_CHAT_STOP: usize = 7119;/);
  assert.match(palette, /g_search_results\[app_state.g_search_result_count\] = SEARCH_TABCTX_CHAT_STOP/);
  assert.match(palette, /target == SEARCH_TABCTX_CHAT_STOP\) return "chat view stop the agent interrupt escape"/);
  assert.match(sidebar, /result_idx == SEARCH_TABCTX_CHAT_STOP\) L\("Chat View: Stop the agent"\)/);
  assert.match(confirm, /target >= SEARCH_TABCTX_RECONNECT and target <= SEARCH_TABCTX_FAVORITE\) or target == SEARCH_TABCTX_CHAT_STOP or/);
  assert.match(confirm, /target == SEARCH_TABCTX_CHAT_STOP\) \{\s*_ = @import\("chat_send.zig"\).chatStopAgent\(ti\)/);
});


test('ISSUE-266 permission actions have all three surfaces and exact context dispatch', () => {
  const shortcuts = read('src/shortcuts.zig');
  for (const [tag, label, key, action] of [
    ['ALLOW', 'Allow', 'Y', 'allow'], ['ALWAYS', 'Always allow', 'O', 'always'], ['DENY', 'Deny', 'D', 'deny'],
  ]) {
    const offset = `SEARCH_CHAT_${tag}_OFFSET`;
    const value = values.get(offset);
    for (const [name, other] of values) {
      if (name !== offset) assert.notEqual(value, other, `${offset} collides with ${name}`);
    }
    const workspaceDelete = values.get("SEARCH_WORKSPACE_DELETE_OFFSET");
    const maxWorkspaces = Number(state.match(/pub const MAX_WORKSPACES: usize = (\d+);/)[1]);
    assert.ok(value < workspaceDelete || value >= workspaceDelete + maxWorkspaces, "Permission commands must not use workspace deletion row IDs");
    assert.match(palette, new RegExp(`g_search_results\\[app_state.g_search_result_count\\] = ${offset};`));
    assert.match(palette, new RegExp(`g_search_results\\[app_state.g_search_result_count\\] = SEARCH_TABCTX_CHAT_${tag};`));
    assert.ok(sidebar.includes(`L("Chat View: ${label}")`));
    assert.match(confirm, new RegExp(`target == SEARCH_TABCTX_CHAT_${tag}\\) \\{\\s*_ = @import\\("chat_send.zig"\\).chatPermissionAnswer\\(ti, \\.${action}\\)`));
    assert.ok(shortcuts.includes(`Alt+${key} in Chat View`));
  }
  assert.match(main, /WM_APP_CHAT_PERMISSION => \{\s*if \(wp < 3\) _ = @import\("chat_send.zig"\).chatPermissionAnswer/);
  assert.match(shortcuts, /kb.vkCode == 0x59 or kb.vkCode == 0x4F or kb.vkCode == 0x44/);
});

test('ISSUE-266 permission button labels use the agent option text rather than fixed action labels', () => {
  const layout = read('src/window_layout.zig');
  const paint = layout.slice(layout.indexOf('fn paintChatPermission('), layout.indexOf('\npub fn paintChatView('));
  assert.match(paint, /g_chat_permission\.optionText\(action\)/);
  assert.match(paint, /DrawTextW\(hdc, text\.ptr, @intCast\(text\.len\)/);
});

function topLevelSearchRows(text) {
  const start = text.indexOf('pub fn updateSearchResults() void {');
  assert.notEqual(start, -1, 'updateSearchResults');
  let body = text.slice(start, text.indexOf('\n}\n', start));
  for (;;) {
    const mode = body.search(/\n    if \(app_state\.g_search_\w+_mode\) \{/);
    if (mode < 0) break;
    const end = body.indexOf('\n    }', mode + 1);
    assert.notEqual(end, -1, 'submenu block end');
    body = body.slice(0, mode) + body.slice(end + 6);
  }
  return new Set([...body.matchAll(/\bg_search_results\[[^\]]+\]\s*=\s*(SEARCH_\w+_OFFSET)\b/g)].map(([, name]) => name));
}

function groupOfSource(text) {
  const start = text.indexOf('pub fn paletteGroupOf(target: usize) ?u8 {');
  assert.notEqual(start, -1, 'paletteGroupOf');
  return text.slice(start, text.indexOf('\n}\n', start));
}

test('IGSH-612 every top-level Ctrl+K row belongs to a palette group', () => {
  const sessionRows = palette.match(/fn paletteRowIsSession\(target: usize\) bool \{[^}]*\}/);
  assert.ok(sessionRows, 'paletteRowIsSession');
  const mapped = comparisons(groupOfSource(palette) + '\n' + sessionRows[0], 'target', values);
  const rows = topLevelSearchRows(palette);
  assert.ok(rows.has('SEARCH_SHELL_DIAG_OFFSET') && rows.has('SEARCH_NEW_CLAUDE_CHAT_OFFSET') && rows.has('SEARCH_SHELLS_MENU_OFFSET'), 'top-level rows were found');
  assert.ok(!rows.has('SEARCH_SKILLS_BACK_OFFSET'), 'submenu rows are excluded');
  const missing = [...rows].filter(name => !mapped.has(name));
  assert.deepEqual(missing, [], `Ctrl+K rows without a group in paletteGroupOf: ${missing.join(', ')}`);
  const broken = palette.replace(', SEARCH_SHELL_DIAG_OFFSET => 4', ' => 4');
  assert.notEqual(broken, palette);
  assert.ok(!comparisons(groupOfSource(broken), 'target', values).has('SEARCH_SHELL_DIAG_OFFSET'));
});

test('IGSH-612 empty Ctrl+K groups rows and keeps selection off headers', () => {
  assert.match(palette, /groupEmptyPaletteResults\(lead\);/);
  assert.match(palette, /\[palette\] rows chars=\{d\} count=\{d\} ids=/);
  assert.match(main, /if \(paletteRowIsHeader\(target\)\) return 0;/);
  assert.match(main, /stepOverPaletteHeaders\(/);
  assert.equal(Number(state.match(/pub const SEARCH_PALETTE_HEADER_OFFSET: usize = (\d+);/)[1]), 11000);
});

test('IGSH-1081 Reconnect is named consistently in Ctrl+K and tab actions', () => {
  const globalRow = sidebar.slice(sidebar.indexOf('} else if (is_reconnect) {'), sidebar.indexOf('} else if (is_singlewin) {'));
  assert.match(globalRow, /L\("Reconnect"\)/);
  const contextRow = sidebar.slice(sidebar.indexOf('const tc_label:'), sidebar.indexOf('const tc_shortcut:'));
  assert.match(contextRow, /L\("Reconnect"\)/);
  assert.ok(!contextRow.includes('Start new session'), 'an ended server session uses the same Reconnect row');
  assert.match(palette, /SEARCH_RECONNECT_OFFSET => "reattach tab"/);
  assert.match(palette, /SEARCH_TABCTX_RECONNECT => "reattach tab"/);
  assert.match(read('src/shortcuts.zig'), /Ctrl\+Shift\+R", \.b = "Reattach active SSH\/tmux tab"/);
  assert.match(main, /if \(target == SEARCH_RECONNECT_OFFSET\) \{[^]*?WM_APP_RECONNECT/);
  assert.match(palette, /"reconnect", "reconnect tab", "reattach"/);
});
