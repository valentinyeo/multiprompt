const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const state = read('src/app_state.zig');
const consoleSource = read('src/console.zig');
const main = read('src/main.zig').split('pub fn main(init: std.process.Init) void {')[1];

test('upstream Hack Regular and Bold and their complete license are embedded', () => {
  for (const file of ['Hack-Regular.ttf', 'Hack-Bold.ttf', 'LICENSE-Hack.md']) {
    assert.ok(fs.statSync(path.join(root, 'src/fonts', file)).size > 0, file);
    assert.ok((consoleSource + read('src/fonts.zig')).includes(`@embedFile("fonts/${file}")`), file);
  }
  assert.match(read('src/fonts/LICENSE-Hack.md'), /Bitstream Vera Sans Mono Copyright/);
  assert.match(read('src/fonts/LICENSE-Hack.md'), /MIT License/);
  for (const face of ['Regular', 'Bold']) {
    const bytes = fs.readFileSync(path.join(root, `src/fonts/Hack-${face}.ttf`));
    assert.equal(bytes.readUInt32BE(0), 0x00010000);
    const tableCount = bytes.readUInt16BE(4);
    let nameOffset;
    for (let i = 0; i < tableCount; i++) {
      const record = 12 + i * 16;
      if (bytes.toString('ascii', record, record + 4) === 'name') nameOffset = bytes.readUInt32BE(record + 8);
    }
    assert.notEqual(nameOffset, undefined);
    const names = [];
    for (let i = 0; i < bytes.readUInt16BE(nameOffset + 2); i++) {
      const record = nameOffset + 6 + i * 12;
      if (bytes.readUInt16BE(record) !== 3 || bytes.readUInt16BE(record + 6) !== 1) continue;
      const start = nameOffset + bytes.readUInt16BE(nameOffset + 4) + bytes.readUInt16BE(record + 10);
      names.push(Buffer.from(bytes.subarray(start, start + bytes.readUInt16BE(record + 8))).swap16().toString('utf16le'));
    }
    assert.ok(names.length > 0);
    assert.ok(names.every(name => name === 'Hack'));
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

test('all saved indices migrate to Hack without changing size', () => {
  assert.match(state, /DEV_CONSOLE_FONTS = \[_\]\[\]const u8\{DEFAULT_CONSOLE_FONT\}/);
  assert.match(state, /DEFAULT_CONSOLE_FONT = @import\("fonts\.zig"\)\.SHELL_FACE/);
  assert.match(read('src/fonts.zig'), /MONO_FACE = "Nordwand Mono MP SemiBold"/);
  const restore = read('src/session.zig');
  assert.match(restore, /app_state\.g_dev_font_idx = app_state\.DEFAULT_CONSOLE_FONT_IDX/);
  assert.doesNotMatch(restore, /font < DEV_CONSOLE_FONTS\.len/);
  assert.match(restore, /size >= 8 and size <= 40/);
  assert.match(read('src/themes.zig'), /parseThemeFontField\(json, "console_font", &app_state\.g_dev_theme\.console_font\)/);
  assert.match(read('src/themes.zig'), /setWideAscii\(out, app_state\.DEFAULT_CONSOLE_FONT\)/);
  assert.match(read('src/themes.zig'), /test "IGSH-443/);
  assert.match(read('build.zig'), /vps_test_step\.dependOn\(&run_shell_font_migration_tests\.step\)/);
  assert.match(read('build.zig'), /test_step\.dependOn\(&run_shell_font_migration_tests\.step\)/);
});

test('the embedded theme names only bundled fonts and preserves its console height', () => {
  assert.match(state, /g_dev_font_idx: usize = DEFAULT_CONSOLE_FONT_IDX/);
  const expression = state.match(/pub const DEFAULT_DEV_THEME_JSON =([\s\S]*?)\n;/)[1];
  const parts = expression.split('++ DEFAULT_CONSOLE_FONT ++').map(part => part.split('\n')
    .filter(line => /^\s*\\\\/.test(line)).map(line => line.replace(/^\s*\\\\/, '')).join('\n'));
  assert.equal(parts.length, 2);
  const theme = JSON.parse(parts.join('Hack'));
  for (const key of ['title_font', 'subtitle_font', 'close_font']) assert.equal(theme.fonts[key], 'IBM Plex Sans');
  assert.equal(theme.fonts.console_font, 'Hack');
  assert.equal(theme.fonts.console_font_height, 18);
  assert.equal(theme.fonts.console_font_weight, 400);
});

test('console height stays unchanged, weight is Regular and readback logs once without verbose mode', () => {
  assert.match(state, /"console_font_height": 18/);
  assert.match(state, /"console_font_weight": 400/);
  assert.match(consoleSource, /themed\.FontWeight = @import\("fonts\.zig"\)\.SHELL_WEIGHT/);
  assert.match(consoleSource, /std\.mem\.span\(L\(@import\("fonts\.zig"\)\.SHELL_FACE\)\)/);
  assert.match(consoleSource, /if \(i < 2\)/);
  const readback = consoleSource.slice(consoleSource.indexOf('var f2: CONSOLE_FONT_INFOEX'));
  assert.match(readback, /base_font_h == 0/);
  assert.match(readback, /if \(GetCurrentConsoleFontEx\(h, 0, &f2\) != 0\) \{\s*var log_font = true;/);
  assert.match(readback, /if \(app_state\.shells\[si\]\.pid == pid\) \{\s*log_font = !app_state\.shells\[si\]\.console_font_logged;\s*if \(log_font\) app_state\.shells\[si\]\.console_font_logged = true;\s*break;/);
  assert.match(readback, /if \(log_font\) \{\s*var face_buf:/);
  assert.match(readback, /utf16LeToUtf8\(&face_buf, std\.mem\.sliceTo\(&f2\.FaceName, 0\)\)/);
  assert.match(readback, /"\[consolefont\] pid=\{d\} face=\{s\} h=\{d\}", \.\{ pid, face_buf\[0\.\.face_len\], f2\.dwFontSize\.y \}/);
  assert.ok(readback.indexOf('[consolefont] pid={d} face={s} h={d}') < readback.indexOf('if (verboseLoggingEnabled())'));
  assert.match(read('src/diagnostics.zig'), /if \(!verboseLoggingEnabled\(\) and !std\.mem\.startsWith\(u8, msg, "\[consolefont\] "\) and !std\.mem\.startsWith\(u8, msg, "\[focus-trace\] "\)\) return;/);
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

test('Chat View uses the bundled mono face for code and Plex for prose', () => {
  const render = read('src/chat_render.zig');
  assert.match(render, /L\(@import\("fonts\.zig"\)\.MONO_FACE\)/);
  assert.match(render, /@import\("fonts\.zig"\)\.chat\(/);
  assert.match(read('src/chat_composer.zig'), /@import\("fonts\.zig"\)\.chat\(/);
  assert.match(read('src/fonts.zig'), /options.body_weight == 500\) L\(UI_MEDIUM_FACE\)/);
});

test('CI runs the console font regression', () => {
  const build = read('build.zig');
  assert.match(build, /const console_font_tests = b\.addSystemCommand\(&\.\{ \"node\", \"--test\", \"tools\/console-font\.test\.js\" \}\);/);
  assert.match(build, /test_step\.dependOn\(&console_font_tests\.step\)/);
  assert.match(build, /vps_test_step\.dependOn\(&console_font_tests\.step\)/);
  assert.match(build, /test_step\.dependOn\(&console_font_lifecycle_tests\.step\)/);
  assert.match(build, /vps_test_step\.dependOn\(&console_font_lifecycle_tests\.step\)/);
  assert.match(read('.github/workflows/test.yml'), /run: zig build test --summary all/);
  assert.match(read('.github/workflows/test.yml'), /run: zig build test-vps --summary all/);
});


test('Hack payloads match pinned upstream hashes and are not registered privately for conhost', () => {
  const crypto = require('node:crypto');
  const hashes = {
    'Hack-Regular.ttf': '15f55cc0c85a2988d2b4b3a8cdb5d77fdfbaf319e1bb5309d725db9818fb7125',
    'Hack-Bold.ttf': '5bbf531eff7f8a0c2559c9a0656718e2828a012a9b1f60b5f54006d59a4de8d4',
  };
  for (const [file, hash] of Object.entries(hashes)) {
    assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(root, 'src/fonts', file))).digest('hex'), hash);
    assert.ok(read('THIRD_PARTY_NOTICES.md').includes(hash));
  }
  const registration = consoleSource.slice(consoleSource.indexOf('pub fn registerBundledConsoleFonts'), consoleSource.indexOf('pub fn unregisterBundledConsoleFonts'));
  assert.doesNotMatch(registration, /Nordwand/);
  assert.match(read('src/fonts.zig'), /MONO_SEMIBOLD = @embedFile\("fonts\/NordwandMono-SemiBold.ttf"\)/);
});

test('mintty requests Hack outside the developer theme too', () => {
  const launch = consoleSource.slice(consoleSource.indexOf('mintty.exe'), consoleSource.indexOf('pub fn spawnShell('));
  assert.ok(launch.indexOf('"Font", std.mem.span(L(@import("fonts.zig").SHELL_FACE))') < launch.indexOf('if (devThemeOn())'));
  assert.ok(launch.includes('"FontHeight", minttyFontHeightFromConsoleHeight()'));
});

test('ISSUE-508 shell cap preserves the pre-Hack effective width', () => {
  const pane = read('src/browser_pane.zig');
  const column = pane.slice(pane.indexOf('pub fn centeredConsoleColumn('), pane.indexOf('\ntest "centeredConsoleColumn'));
  const cap = Number(column.match(/var w = @min\(DEV_SHELL_COLS \* cell_w, uiScaled\((\d+)\)\) \+ 4;/)?.[1]);
  const cols = Number(state.match(/pub const DEV_SHELL_COLS: i32 = (\d+);/)[1]);
  const height = Number(state.match(/"console_font_height": (\d+)/)[1]);
  const bytes = fs.readFileSync(path.join(root, 'src/fonts/NordwandMono-SemiBold.ttf'));
  const tables = {};
  for (let i = 0; i < bytes.readUInt16BE(4); i++) {
    const record = 12 + i * 16;
    tables[bytes.toString('ascii', record, record + 4)] = bytes.readUInt32BE(record + 8);
  }
  const advance = bytes.readUInt16BE(tables.hmtx);
  const cellHeight = bytes.readUInt16BE(tables['OS/2'] + 74) + bytes.readUInt16BE(tables['OS/2'] + 76);
  const oldCellWidth = Math.round(height * advance / cellHeight);
  assert.equal(oldCellWidth, 8);
  assert.equal(cap, cols * oldCellWidth);
  assert.equal(cap + 4, 804);
  assert.match(column, /const avail = client_right - sidebar_w - edge_pad \* 2;/);
  assert.match(column, /if \(w > avail\) w = avail;/);
  assert.match(column, /sidebar_w \+ edge_pad \+ @divTrunc\(avail - w, 2\)/);
});

test('ISSUE-508 full width remains per-session and bypasses the shell cap without changing Chat View', () => {
  const layout = read('src/window_layout.zig');
  const full = layout.indexOf('if (app_state.shells[app_state.active_shell].full_width)');
  const centered = layout.indexOf('const col = centeredConsoleColumn(', full);
  assert.ok(full >= 0 && centered > full);
  const branch = layout.slice(full, centered);
  assert.match(branch, /const fw_w = rc.right - SIDEBAR_W\(\);/);
  assert.match(branch, /verifyShellWindowSize\(sh0, SIDEBAR_W\(\), fw_top, fw_w, fw_h\);\s*return;/);
  const chat = read('src/chat_composer.zig');
  assert.match(chat, /const full_width = app_state\.ISSUE_440_FULL_WIDTH_CHAT and app_state\.active_shell < app_state\.shell_count and app_state\.shells\[app_state\.active_shell\]\.full_width;/);
  assert.match(chat, /if \(full_width\) col\.width else uiScaled\(760\)/);
});
