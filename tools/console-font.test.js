const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const state = read('src/app_state.zig');
const consoleSource = read('src/console.zig');
const main = read('src/main.zig').split('pub fn main(init: std.process.Init) void {')[1];

test('the bundled shell font and its license are embedded and GDI can match its face for conhost', () => {
  assert.match(consoleSource, /@import\("fonts\.zig"\)\.MONO_SEMIBOLD \}/);
  assert.ok(consoleSource.includes('@embedFile("fonts/LICENSE-NordwandMono.txt")'));
  assert.match(read('src/fonts/LICENSE-NordwandMono.txt'), /SIL Open Font License, Version 1\.1/i);
  const bytes = fs.readFileSync(path.join(root, 'src/fonts/NordwandMono-SemiBold.ttf'));
  assert.equal(bytes.readUInt32BE(0), 0x00010000);
  const tables = {};
  for (let i = 0; i < bytes.readUInt16BE(4); i++) {
    const record = 12 + i * 16;
    tables[bytes.toString('ascii', record, record + 4)] = bytes.readUInt32BE(record + 8);
  }
  const names = [];
  for (let i = 0; i < bytes.readUInt16BE(tables.name + 2); i++) {
    const record = tables.name + 6 + i * 12;
    if (bytes.readUInt16BE(record) !== 3 || bytes.readUInt16BE(record + 6) !== 1) continue;
    const start = tables.name + bytes.readUInt16BE(tables.name + 4) + bytes.readUInt16BE(record + 10);
    names.push(Buffer.from(bytes.subarray(start, start + bytes.readUInt16BE(record + 8))).swap16().toString('utf16le'));
  }
  assert.deepEqual(names, ['Nordwand Mono MP SemiBold']);
  assert.equal(bytes.readUInt16BE(tables['OS/2'] + 4), 600);
  assert.equal(bytes.readUInt32BE(tables['OS/2'] + 78) & 1, 1);
  assert.equal(bytes.readUInt32BE(tables['OS/2'] + 82) >>> 30, 3);
  assert.match(read('src/fonts.zig'), /SHELL_FACE = MONO_FACE;/);
  assert.match(read('src/fonts.zig'), /SHELL_WEIGHT = 600;/);
  assert.equal(fs.existsSync(path.join(root, 'src/fonts/Hack-Regular.ttf')), false);
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

test('font cache uses Unicode local app data paths, content-named font files and skips same-sized files', () => {
  assert.match(consoleSource, /"NordwandMono-SemiBold-\{x:0>16\}\.ttf", \.\{std\.hash\.Wyhash\.hash\(0, @import\("fonts\.zig"\)\.MONO_SEMIBOLD\)\}/);
  assert.match(consoleSource, /GetEnvironmentVariableW\(L\("LOCALAPPDATA"\)/);
  assert.match(consoleSource, /L\("\\\\ZigShell\\\\fonts"\)/);
  assert.match(consoleSource, /GetFileSizeEx\(existing, &size\) != 0 and size == file\[1\]\.len/);
  assert.match(consoleSource, /if \(!cached\)/);
  assert.match(consoleSource, /written == file\[1\]\.len/);
  assert.doesNotMatch(consoleSource.slice(consoleSource.indexOf('pub fn registerBundledConsoleFonts'), consoleSource.indexOf('fn applyThemedConsoleFont')), /RegSet|RegCreate/);
});

test('all saved indices migrate to the shell font without changing size', () => {
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
  const theme = JSON.parse(parts.join('Nordwand Mono MP SemiBold'));
  for (const key of ['title_font', 'subtitle_font', 'close_font']) assert.equal(theme.fonts[key], 'IBM Plex Sans');
  assert.equal(theme.fonts.console_font, 'Nordwand Mono MP SemiBold');
  assert.equal(theme.fonts.console_font_height, 18);
  assert.equal(theme.fonts.console_font_weight, 600);
});

test('console height stays unchanged, weight is SemiBold and readback logs once without verbose mode', () => {
  assert.match(state, /"console_font_height": 18/);
  assert.match(state, /"console_font_weight": 600/);
  assert.match(consoleSource, /themed\.FontWeight = @import\("fonts\.zig"\)\.SHELL_WEIGHT/);
  assert.match(consoleSource, /std\.mem\.span\(L\(@import\("fonts\.zig"\)\.SHELL_FACE\)\)/);
  assert.match(consoleSource, /if \(i == 0\)/);
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

test('spawn and worker respawn apply the console theme before revealing the window', () => {
  for (const name of ['spawnShellWithSession']) {
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
  const worker = consoleSource.slice(consoleSource.indexOf('fn startupShellWorker('), consoleSource.indexOf('fn discardStartupShell('));
  assert.ok(worker.indexOf('ShowWindow(job.hwnd, SW_HIDE)') < worker.indexOf('SetParent(job.hwnd, job.owner)'));
  const complete = consoleSource.slice(consoleSource.indexOf('pub fn finishStartupShell('));
  assert.ok(complete.indexOf('applyBlackConsoleBackground(job.pid)') < complete.indexOf('showShellConsole(idx, SW_SHOW'));
  const reconnect = consoleSource.slice(consoleSource.indexOf('pub fn respawnShellInPlace('), consoleSource.indexOf('pub fn markSshTabDisconnected('));
  assert.match(reconnect, /Thread\.spawn\([^;]*startupShellWorker/);
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


test('the shell font payload is the reproducible generator output and only it is registered for conhost', () => {
  const digest = require('node:crypto').createHash('sha256');
  digest.update(fs.readFileSync(path.join(root, 'src/fonts/NordwandMono-SemiBold.ttf')));
  assert.equal(digest.digest('hex'), 'dada384b7332520a6bdc2af15c27a927a5161b68f0f7022f2fb7d591255f0370');
  assert.match(read('tools/fonts/add-terminal-glyphs.py'), /ulCodePageRange1 = CODE_PAGE_RANGE1/);
  assert.match(read('THIRD_PARTY_NOTICES.md'), /OEM 437/);
  assert.doesNotMatch(read('THIRD_PARTY_NOTICES.md'), /Hack/);
  const registration = consoleSource.slice(consoleSource.indexOf('pub fn registerBundledConsoleFonts'), consoleSource.indexOf('pub fn unregisterBundledConsoleFonts'));
  assert.doesNotMatch(registration, /Hack|NordwandMono-Regular|NordwandMono-Bold/);
  assert.match(read('src/fonts.zig'), /MONO_SEMIBOLD = @embedFile\("fonts\/NordwandMono-SemiBold.ttf"\)/);
});

test('mintty requests the shell font outside the developer theme too', () => {
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
