const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { readChangelogEntry } = require('./changelog-entry');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const readIfPresent = file => (fs.existsSync(path.join(root, file)) ? read(file) : '');

const state = read('src/app_state.zig');
const reader = read('src/json_reader.zig');
const session = read('src/session.zig');
const palette = read('src/command_palette.zig');
const sidebar = read('src/sidebar.zig');
const avatar = read('src/bot_avatar.zig');
const picture = readIfPresent('src/bot_picture.zig');
const words = read('src/ui_words.zon');
const shortcuts = read('src/shortcuts.zig');
const main = read('src/main.zig');
const doc = read('openwiki/operations/keyboard-shortcuts.md');

function scalars(text) {
  return [...text.matchAll(/pub const (SEARCH_\w+): usize = (\d+);/g)].map(([, name, value]) => ({ name, value: Number(value) }));
}

function functionBlock(text, prefix) {
  const start = text.indexOf(prefix);
  assert.notEqual(start, -1, `missing ${prefix}`);
  const open = text.indexOf('{', start);
  let depth = 1;
  let end = open + 1;
  for (; depth && end < text.length; end++) {
    if (text[end] === '{') depth++;
    if (text[end] === '}') depth--;
  }
  assert.equal(depth, 0, `unbalanced ${prefix}`);
  return text.slice(start, end);
}

test('the picture id is stored per tab and survives the session file', () => {
  assert.match(state, /face: \?u8 = null,\n {4}color: \?u8 = null,\n {4}picture: u64 = 0,/);
  assert.match(state, /picture: u64 = 0,/);
  const writer = functionBlock(session, 'pub fn saveSessionTo(');
  assert.match(writer, /,\\"picture\\":\{d\}/);
  assert.match(writer, /app_state\.shells\[i\]\.picture != 0/);
  assert.match(reader, /tab\.picture = uintDefault\(obj, "picture", 0\);/);
  assert.match(session, /shell\.picture = tab\.picture;/);
  assert.match(session, /app_state\.shells\[idx\]\.picture = tabs\[t\]\.picture;/);
});

test('a moved or absorbed tab keeps its picture', () => {
  const workspaces = read('src/workspaces.zig');
  assert.match(workspaces, /appearance_transfer\.picture = shell\.picture;/);
  assert.match(workspaces, /app_state\.shells\[idx\]\.picture = tabs\[t\]\.picture;/);
  assert.match(workspaces, /,\\"picture\\":\{d\}/);
  assert.match(state, /pub const AppearanceTabTransfer = extern struct \{[^}]*picture: u64,/);
  assert.match(main, /new_shell\.picture = extended\.picture;/);
});

test('pictures live in one local folder and never in the account layout', () => {
  assert.match(picture, /pub fn storeDir\(buf: \*\[512\]u8\) \?\[\]const u8 \{/);
  assert.match(picture, /GetEnvironmentVariableA\("APPDATA", buf, 512\)/);
  assert.match(picture, /const pictures_dir = "\\\\ZigShell\\\\bot-pictures";/);
  assert.match(picture, /win32MakeDir\(buf\[0 \.\. appdata_len \+ pictures_dir\.len\]\)/);
  assert.match(picture, /pub fn filePath\(id: u64, buf: \*\[640\]u8\) \?\[\]const u8 \{/);
  assert.match(picture, /\{s\}\\\\\{x:0>16\}\.img/);
  assert.match(picture, /pub fn exists\(id: u64\) bool \{/);
  assert.doesNotMatch(picture, /accountSetAppearance|account_layout|account_desktop/);
});

test('both palette rows have their own routing ids outside every other SEARCH value', () => {
  const all = scalars(state);
  const byName = new Map(all.map(entry => [entry.name, entry.value]));
  assert.equal(byName.get('SEARCH_BOT_PICTURE_UPLOAD'), 7193);
  assert.equal(byName.get('SEARCH_BOT_PICTURE_RESET'), 7194);
  assert.notEqual(byName.get('SEARCH_BOT_PICTURE_UPLOAD'), byName.get('SEARCH_BOT_PICTURE_RESET'));
  for (const { name, value } of all) {
    if (name === 'SEARCH_BOT_PICTURE_UPLOAD' || name === 'SEARCH_BOT_PICTURE_RESET') continue;
    assert.notEqual(value, 7193, `${name} collides with the upload row`);
    assert.notEqual(value, 7194, `${name} collides with the reset row`);
  }
  assert.ok(byName.get('SEARCH_BOT_PICTURE_RESET') < byName.get('SEARCH_CUSTOMCMD_OFFSET'));
});

test('the bot look submenu offers Upload image and gates Reset picture on a real picture', () => {
  const submenu = functionBlock(palette, 'pub fn updateSearchResults() void {');
  const back = submenu.indexOf('app_state.g_search_results[0] = SEARCH_TABCTX_BACK;');
  const upload = submenu.indexOf('app_state.g_search_results[app_state.g_search_result_count] = app_state.SEARCH_BOT_PICTURE_UPLOAD;');
  const reset = submenu.indexOf('app_state.g_search_results[app_state.g_search_result_count] = app_state.SEARCH_BOT_PICTURE_RESET;');
  const choices = submenu.indexOf('for (labels, 0..) |label, i| {');
  assert.ok(back >= 0 && upload > back && reset > upload && choices > reset, 'rows go after Back and before the choices');
  const gate = submenu.slice(upload, reset);
  assert.match(gate, /picture != 0/);
  assert.match(gate, /has_picture and/);
  assert.match(submenu.slice(back, upload), /bot_upload_image \+\+ " picture photo avatar file"/);
  assert.match(submenu.slice(upload, reset), /bot_reset_picture \+\+ " remove clear photo avatar auto face"/);
  assert.match(submenu, /preferFirstFilteredResultAfterBack\(\);/);
  assert.match(palette, /if \(target == app_state\.SEARCH_BOT_PICTURE_UPLOAD\) return words\.bot_upload_image \+\+ " picture photo avatar file";/);
  assert.match(palette, /if \(target == app_state\.SEARCH_BOT_PICTURE_RESET\) return words\.bot_reset_picture \+\+ " remove clear photo avatar auto face";/);
});

test('the palette paints both rows as plain text without an avatar preview', () => {
  const paint = functionBlock(sidebar, 'pub fn paintSidebar(');
  assert.match(paint, /result_idx == app_state\.SEARCH_BOT_PICTURE_UPLOAD or result_idx == app_state\.SEARCH_BOT_PICTURE_RESET/);
  assert.match(paint, /else if \(result_idx == app_state\.SEARCH_BOT_PICTURE_UPLOAD\) ui_words\.bot_upload_image else ui_words\.bot_reset_picture/);
  const branch = paint.slice(paint.indexOf('result_idx == app_state.SEARCH_TABCTX_BOT_FACE'), paint.indexOf('} else if (is_tabctx) {'));
  assert.match(branch, /const shell_index = if \(\(face_choice or color_choice\)/);
});

test('the avatar draws the picture before the circle mask and falls back to the face', () => {
  const draw = functionBlock(avatar, 'pub fn draw(');
  const pictureAt = draw.indexOf('@import("bot_picture.zig").drawInto(surface, circle, appearance.picture)');
  const resolveAt = draw.indexOf('smooth.resolveRounded(');
  assert.ok(pictureAt > 0 && resolveAt > pictureAt, 'the picture is drawn before the rounded mask resolves');
  assert.match(draw, /const circle = headBounds\(\.circle, /);
  assert.match(draw, /if \(!picture\) \{/);
  assert.match(draw.slice(draw.indexOf('if (!picture) {')), /rounded\(surface, vb, visor\);/);
  assert.match(draw, /samples, if \(picture\) circle else head\)/);
  assert.match(avatar, /pub fn forShell\(shell: \*const state\.Shell\) Appearance \{\n {4}var appearance = forShellWithFace\(shell, shell\.face\);\n {4}appearance\.picture = shell\.picture;/);
  assert.match(avatar, /pub const Appearance = struct \{\n {4}face: u8,\n {4}color: u8,\n {4}picture: u64 = 0,/);
  assert.doesNotMatch(functionBlock(avatar, 'pub fn forShellWithFace('), /picture/);
});

test('upload opens a Windows file picker limited to png and jpeg under twenty megabytes', () => {
  const choose = functionBlock(picture, 'pub fn choose(shell_id: u32) void {');
  assert.match(choose, /@import\("fonts\.zig"\)\.openFileName\(&ofn\)/);
  assert.match(choose, /L\("Images \(\*\.png;\*\.jpg;\*\.jpeg\)\\x00\*\.png;\*\.jpg;\*\.jpeg\\x00All files\\x00\*\.\*\\x00"\)/);
  assert.match(choose, /ofn\.hwndOwner = app_state\.g_main_hwnd;/);
  assert.match(choose, /ofn\.Flags = 0x00001000 \| 0x00000800 \| 0x00000008 \| 0x00000004;/);
  assert.match(choose, /if \(@import\("fonts\.zig"\)\.openFileName\(&ofn\) == 0\) return;/);
  assert.match(picture, /pub const MAX_SOURCE_BYTES: usize = 20 \* 1024 \* 1024;/);
  assert.match(choose, /readFileAllocWin32\(utf8_buf\[0\.\.utf8_len\], MAX_SOURCE_BYTES\)/);
  assert.match(choose, /bitmap_from_file\(wide, &image\)/);
  assert.match(choose, /source_w > MAX_EDGE or source_h > MAX_EDGE/);
  assert.match(choose, /showHeaderNoticeAscii|refuse\(\)/);
  assert.match(picture, /showHeaderNoticeAscii\(words\.bot_picture_error, 4000, true\)/);
  assert.match(choose, /win32OpenWrite\(dest\)/);
  assert.match(choose, /win32WriteAll\(handle, bytes\)/);
  assert.match(choose, /app_state\.shells\[idx\]\.picture = id;/);
});

test('reset clears the picture, saves the session and leaves the face and colour alone', () => {
  const reset = functionBlock(picture, 'pub fn reset(shell_id: u32) void {');
  assert.match(reset, /app_state\.shells\[idx\]\.picture = 0;/);
  assert.match(reset, /save\(\);/);
  assert.match(reset, /invalidate\(\);/);
  assert.doesNotMatch(reset, /face =|color =/);
  assert.match(picture, /@import\("launch_cache\.zig"\)\.changed\(\);/);
  assert.match(picture, /@import\("session\.zig"\)\.getSessionPath\(&path_buf\)/);
  assert.match(picture, /@import\("session\.zig"\)\.saveSessionTo\(path, null\)/);
  assert.match(picture, /@import\("inbox\.zig"\)\.findShellById\(shell_id\)/);
});

test('both rows are confirmed only for an eligible bot and after the palette closes', () => {
  const confirm = main.slice(main.indexOf('WM_APP_SEARCH_CONFIRM => {'));
  const start = confirm.indexOf('if (target == app_state.SEARCH_BOT_PICTURE_UPLOAD or target == app_state.SEARCH_BOT_PICTURE_RESET) {');
  const choices = confirm.indexOf('if (app_state.g_bot_look_mode != .none and\n');
  assert.ok(start >= 0 && choices > start, 'the picture rows are handled before the face and colour choices');
  const handler = confirm.slice(start, choices);
  assert.match(handler, /const shell_id = app_state\.g_bot_look_sid;/);
  assert.match(handler, /@import\("bot_look\.zig"\)\.eligible\(shell_idx\)/);
  assert.match(handler, /SendMessageW\(hwnd, WM_APP_SEARCH_CLOSE, 0, 0\);/);
  assert.match(handler, /@import\("bot_picture\.zig"\)\.choose\(shell_id\);/);
  assert.match(handler, /@import\("bot_picture\.zig"\)\.reset\(shell_id\);/);
  assert.match(handler, /InvalidateRect\(hwnd, null, 1\);/);
});

test('the words, the shortcut row and the generated list are current', () => {
  assert.match(words, /\.bot_upload_image = "Upload image",/);
  assert.match(words, /\.bot_reset_picture = "Reset picture",/);
  assert.match(words, /\.bot_picture_error = "Could not read that picture",/);
  assert.match(shortcuts, /\.\{ \.a = "Ctrl\+K → Bot face → Upload image", \.b = "[^"]*Reset picture[^"]*", \.header = false \},/);
  assert.ok(doc.includes('| Ctrl+K → Bot face → Upload image |'), 'run node tools/shortcuts-doc.mjs');
  assert.match(doc, /Both pages start with Upload image/);
});

test('the changelog fragment is a plain sentence for the user', () => {
  const text = readChangelogEntry('IGSH-1424', root).trim();
  assert.ok(text.length > 20);
  assert.doesNotMatch(text, /IGSH|\.zig|\.md|SEARCH_|Appearance|bot_picture|palette/i);
  assert.match(text, /picture/i);
});
