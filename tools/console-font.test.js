const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const state = read('src/app_state.zig');
const consoleSource = read('src/console.zig');
const main = read('src/main.zig').split('pub fn main(init: std.process.Init) void {')[1];

const oldFonts = [
  'CaskaydiaCove NFM',
  'CaskaydiaCove NFM SemiBold',
  'JetBrainsMono NFM',
  'JetBrainsMono NFM SemiBold',
  'FiraCode Nerd Font Mono',
  'FiraCode Nerd Font Mono SemBd',
  'Hack Nerd Font Mono',
];

test('both bundled Nordwand Mono faces and their OFL license are embedded', () => {
  for (const file of ['NordwandMono-Regular.ttf', 'NordwandMono-Bold.ttf', 'LICENSE-NordwandMono.txt']) {
    assert.ok(fs.statSync(path.join(root, 'src/fonts', file)).size > 0, file);
    assert.ok(consoleSource.includes(`@embedFile("fonts/${file}")`), file);
  }
  assert.match(read('src/fonts/LICENSE-NordwandMono.txt'), /SIL Open Font License, Version 1\.1/);
  for (const face of ['Regular', 'Bold']) {
    const bytes = fs.readFileSync(path.join(root, `src/fonts/NordwandMono-${face}.ttf`));
    assert.equal(bytes.readUInt32BE(0), 0x00010000);
    assert.ok(bytes.includes(Buffer.from('Nordwand Mono', 'utf16le').swap16()));
  }
});

test('font registration is visible to separate conhost processes and balanced on exit', () => {
  assert.match(consoleSource, /AddFontResourceExW\(@ptrCast\(path\), 0, null\)/);
  assert.doesNotMatch(consoleSource, /FR_PRIVATE|AddFontMemResourceEx/);
  assert.match(consoleSource, /RemoveFontResourceExW\(@ptrCast\(&fonts\.paths\[i\]\), 0, null\)/);
  assert.match(consoleSource, /if \(registered\)/);
  for (const fn of ['AddFontResourceExW', 'RemoveFontResourceExW']) {
    assert.ok(read('src/win32.zig').includes(`pub extern "gdi32" fn ${fn}`));
  }
  const registration = main.indexOf('registerBundledConsoleFonts()');
  assert.ok(registration >= 0);
  for (const startup of ['CreateWindowExW(', 'accountBootstrap(hwnd)', 'restoreSession()', 'spawnShell(.cmd)', 'if (app_state.g_adopt_hwnd)']) {
    assert.ok(main.indexOf(startup) > registration, startup);
  }
  assert.match(main, /defer @import\("console\.zig"\)\.unregisterBundledConsoleFonts\(&console_fonts\)/);
  assert.match(read('src/session.zig'), /reclaimShell\(/);
});

test('font cache uses Unicode local app data paths and skips same-sized files', () => {
  assert.match(consoleSource, /GetEnvironmentVariableW\(L\("LOCALAPPDATA"\)/);
  assert.match(consoleSource, /L\("\\\\ZigShell\\\\fonts"\)/);
  assert.match(consoleSource, /GetFileSizeEx\(existing, &size\) != 0 and size == file\[1\]\.len/);
  assert.match(consoleSource, /if \(!cached\)/);
  assert.match(consoleSource, /written == file\[1\]\.len/);
  assert.doesNotMatch(consoleSource.slice(consoleSource.indexOf('pub fn registerBundledConsoleFonts'), consoleSource.indexOf('fn applyThemedConsoleFont')), /RegSet|RegCreate/);
});

test('saved font indices retain their meaning and Nordwand is appended', () => {
  const fonts = [...state.match(/pub const DEV_CONSOLE_FONTS = \[_\]\[\]const u8\{([\s\S]*?)\n\};/)[1].matchAll(/"([^"]+)"/g)].map(m => m[1]);
  assert.deepEqual(fonts, [...oldFonts, 'Nordwand Mono']);
});

test('one switch selects the default by name for runtime and embedded theme', () => {
  assert.match(state, /pub const ISSUE_441 = true;/);
  assert.match(state, /pub const DEFAULT_CONSOLE_FONT = if \(ISSUE_441\) "Nordwand Mono" else "JetBrainsMono NFM";/);
  assert.match(state, /std\.mem\.eql\(u8, face, DEFAULT_CONSOLE_FONT\)/);
  assert.match(state, /g_dev_font_idx: usize = DEFAULT_CONSOLE_FONT_IDX/);
  assert.match(state, /"console_font": "\n\+\+ DEFAULT_CONSOLE_FONT \+\+\n\s*\\\\",/);
  assert.match(read('src/themes.zig'), /setWideAscii\(&app_state\.g_dev_theme\.console_font, app_state\.DEFAULT_CONSOLE_FONT\)/);
  const themeExpression = state.match(/pub const DEFAULT_DEV_THEME_JSON =([\s\S]*?)\n;/)[1];
  const parts = themeExpression.split('++ DEFAULT_CONSOLE_FONT ++').map(part => part.split('\n')
    .filter(line => /^\s*\\\\/.test(line)).map(line => line.replace(/^\s*\\\\/, '')).join('\n'));
  assert.equal(parts.length, 2);
  for (const face of ['Nordwand Mono', 'JetBrainsMono NFM']) {
    const theme = JSON.parse(parts.join(face));
    assert.equal(theme.fonts.console_font, face);
    assert.equal(theme.fonts.console_font_height, 18);
    assert.equal(theme.fonts.console_font_weight, 700);
  }
  const restore = read('src/session.zig');
  assert.match(restore, /if \(app_state\.ISSUE_441 and font == 2\) app_state\.DEFAULT_CONSOLE_FONT_IDX else @intCast\(font\)/);
  assert.match(restore, /DEV_CONSOLE_FONTS\[app_state\.g_dev_font_idx\]/);
});

test('console height and weight stay unchanged and readback logs once without verbose mode', () => {
  assert.match(state, /"console_font_height": 18/);
  assert.match(state, /"console_font_weight": 700/);
  const readback = consoleSource.slice(consoleSource.indexOf('var f2: CONSOLE_FONT_INFOEX'));
  assert.match(readback, /base_font_h == 0/);
  assert.match(readback, /if \(GetCurrentConsoleFontEx\(h, 0, &f2\) != 0\) \{\s*var log_font = true;/);
  assert.match(readback, /if \(app_state\.shells\[si\]\.pid == pid\) \{\s*log_font = !app_state\.shells\[si\]\.console_font_logged;\s*if \(log_font\) app_state\.shells\[si\]\.console_font_logged = true;\s*break;/);
  assert.match(readback, /if \(log_font\) \{\s*var face_buf:/);
  assert.match(readback, /utf16LeToUtf8\(&face_buf, std\.mem\.sliceTo\(&f2\.FaceName, 0\)\)/);
  assert.match(readback, /"\[consolefont\] pid=\{d\} face=\{s\} h=\{d\}", \.\{ pid, face_buf\[0\.\.face_len\], f2\.dwFontSize\.y \}/);
  assert.ok(readback.indexOf('[consolefont] pid={d} face={s} h={d}') < readback.indexOf('if (verboseLoggingEnabled())'));
  assert.match(read('src/diagnostics.zig'), /if \(!verboseLoggingEnabled\(\) and !std\.mem\.startsWith\(u8, msg, "\[consolefont\] "\)\) return;/);
});

test('spawn and respawn apply the console theme before hiding and parenting the window', () => {
  for (const name of ['spawnShellWithSession', 'respawnShellInPlace']) {
    const start = consoleSource.indexOf(`pub fn ${name}(`);
    assert.ok(start >= 0, name);
    const end = consoleSource.indexOf('\npub fn ', start + 1);
    const body = consoleSource.slice(start, end < 0 ? undefined : end);
    const apply = body.indexOf('applyBlackConsoleBackground(pi.dwProcessId)');
    const hide = body.indexOf('ShowWindow(cmd_hwnd, SW_HIDE)');
    const parent = body.indexOf('SetParent(cmd_hwnd, app_state.g_main_hwnd)');
    assert.ok(apply >= 0 && hide > apply && parent > hide, name);
    assert.equal(body.match(/applyBlackConsoleBackground\(pi\.dwProcessId\)/g).length, 1, name);
  }
});

test('Chat View keeps Consolas and IBM Plex Sans', () => {
  const render = read('src/chat_render.zig');
  assert.match(render, /L\("Consolas"\)/);
  assert.match(render, /L\("IBM Plex Sans"\)/);
  assert.match(read('src/chat_composer.zig'), /L\("IBM Plex Sans"\)/);
  assert.doesNotMatch(render + read('src/chat_composer.zig'), /Nordwand/);
});

test('CI runs the console font regression', () => {
  const build = read('build.zig');
  assert.match(build, /const console_font_tests = b\.addSystemCommand\(&\.\{ \"node\", \"--test\", \"tools\/console-font\.test\.js\" \}\);/);
  assert.match(build, /test_step\.dependOn\(&console_font_tests\.step\)/);
  assert.match(build, /vps_test_step\.dependOn\(&console_font_tests\.step\)/);
  assert.match(read('.github/workflows/test.yml'), /run: zig build test --summary all/);
  assert.match(read('.github/workflows/test.yml'), /run: zig build test-vps --summary all/);
});
