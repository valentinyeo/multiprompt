const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const main = fs.readFileSync('src/main.zig', 'utf8');
const composer = fs.readFileSync('src/chat_composer.zig', 'utf8');
const tracker = fs.readFileSync('src/list_input.zig', 'utf8');

function hoverGuard(source, list) {
  const assignment = list === 'palette' ? 'app_state.g_search_sel = hovered_row;' : 'app_state.g_chat_ac.sel = idx;';
  const guard = `list_input.${list}.hover()`;
  assert.ok(source.includes(guard), `${list} hover must consult the shared movement tracker`);
  assert.ok(source.indexOf(guard) < source.indexOf(assignment), `${list} movement guard must precede selection`);
}

for (const [list, file, source, start, end] of [
  ['palette', 'palette-hover.zig', main, '            if (app_state.g_search_active and (wp & MK_LBUTTON) == 0', '            if (app_state.g_browser_dragging'],
  ['skills', 'skills-hover.zig', composer, '        WM_MOUSEMOVE => {', '        WM_LBUTTONDOWN => {'],
]) {
  test(`${list} rejects stationary hover using the shared rule, unlike master`, () => {
    const baseline = fs.readFileSync(`tools/fixtures/IGSH-836/${file}`, 'utf8');
    assert.throws(() => hoverGuard(baseline, list), { code: 'ERR_ASSERTION' });
    const from = source.indexOf(start);
    assert.notEqual(from, -1);
    const to = source.indexOf(end, from);
    assert.ok(to > from);
    hoverGuard(source.slice(from, to), list);
  });
}

test('both lists reanchor on keyboard navigation and opening, not repaint', () => {
  for (const message of ['WM_APP_SEARCH_MOVE', 'WM_APP_SEARCH_CHAR', 'WM_APP_SEARCH_BACKSPACE']) {
    assert.ok(main.includes(`${message} => {\n            list_input.palette.keyboard();`));
  }
  assert.match(main, /g_search_active = true;\s*list_input\.palette\.keyboard\(\);/);
  assert.match(composer, /fn chatAcMove\(amount: i32\) void \{\s*list_input\.skills\.keyboard\(\);/);
  assert.match(composer, /if \(!app_state\.g_chat_ac\.open\) list_input\.skills\.keyboard\(\);/);
  assert.match(composer, /g_chat_ac\.open and \(msg == WM_KEYDOWN or msg == 0x0102\)\) list_input\.skills\.keyboard\(\);/);
  assert.match(tracker, /win32\.GetCursorPos\(&point\)/);
  assert.doesNotMatch(tracker, /GET_X|GET_Y|ScreenToClient|WM_PAINT/);
  assert.match(tracker, /@abs\(@as\(i64, point\.x\) - anchor\.x\) < 3 and @abs\(@as\(i64, point\.y\) - anchor\.y\) < 3/);
});

test('click and confirmation still use their explicit chosen rows', () => {
  assert.match(main, /g_search_sel = clicked_row;[\s\S]*?PostMessageW\(app_state\.g_main_hwnd, WM_APP_SEARCH_CONFIRM/);
  assert.match(main, /WM_APP_SEARCH_CONFIRM => \{[\s\S]*?const target = app_state\.g_search_results\[app_state\.g_search_sel\];/);
  const click = composer.slice(composer.indexOf('        WM_LBUTTONDOWN => {'), composer.indexOf('        WM_MOUSEWHEEL => {'));
  assert.doesNotMatch(click, /list_input/);
  assert.match(click, /g_chat_ac\.sel = row \+ app_state\.g_chat_ac\.top;[\s\S]*?chatAcAccept\(\)/);
  assert.match(composer, /fn chatAcAccept\(\) bool \{[\s\S]*?entries\[app_state\.g_chat_ac\.idx\[app_state\.g_chat_ac\.sel\]\]/);
});
