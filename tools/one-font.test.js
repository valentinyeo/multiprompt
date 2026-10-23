const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const allowed = /^(?:Hack|IBM Plex Sans(?: (?:Medm|SmBld|Regular|Italic|Medium|Medium Italic|SemiBold|Bold|Bold Italic))?|Nordwand Mono(?: MP SemiBold| (?:Regular|SemiBold|Bold))?|Segoe UI (?:Symbol|Emoji)|Segoe Fluent Icons|Segoe MDL2 Assets)$/;
const knownFace = /^(?:Inter(?: .*)?|Segoe UI(?: .*)?|Consolas(?: .*)?|Cascadia.*|JetBrains.*|Arial(?: .*)?|Calibri(?: .*)?|Tahoma|Verdana|Courier.*|Lucida.*|Caskaydia.*|FiraCode.*|Hack(?: Nerd.*)?|IBM Plex(?: [A-Z][A-Za-z]*){1,4}|Nordwand Mono(?: [A-Z][A-Za-z]*){0,3})$/;

function literals(source) {
  return [...source.matchAll(/"((?:\\.|[^"\\])*)"/g)].map(m => ({ value: m[1], offset: m.index }));
}

function violations(source) {
  const bad = new Set();
  for (const { value, offset } of literals(source)) {
    const line = source.slice(source.lastIndexOf('\n', offset) + 1, offset);
    const assignment = /(?:\b\w*(?:face|font_family|font_name)\w*|\bfont|\b(?:UI|MONO)_\w*FACE)\s*(?::[^=]+)?=\s*(?:L\(|std\.unicode\.utf8ToUtf16LeStringLiteral\()?$/i.test(line);
    const faceCopy = /(?:setWideAscii|utf8ToUtf16LeStringLiteral|@memcpy)\([^;\n]*(?:font|FaceName)[^;\n]*,\s*(?:L\()?$/i.test(line);
    if (value.endsWith('.zig')) continue;
    if ((knownFace.test(value) || assignment || faceCopy) && !allowed.test(value)) bad.add(value);
  }
  const calls = /\b(?:CreateFontW|create)\s*\(/g;
  for (const match of source.matchAll(calls)) {
    let depth = 1;
    let start = match.index + match[0].length;
    let arg = start;
    let args = 1;
    let string = false;
    for (let i = start; i < source.length && depth; i++) {
      const c = source[i];
      if (string && c === '\\') { i++; continue; }
      if (c === '"') { string = !string; continue; }
      if (string) continue;
      if ('([{'.includes(c)) depth++;
      if (')]}'.includes(c)) depth--;
      if (c === ',' && depth === 1) { arg = i + 1; args++; }
      if (depth === 0 && args === 14) {
        for (const { value } of literals(source.slice(arg, i))) {
          if (!value.endsWith('.zig') && !allowed.test(value)) bad.add(value);
        }
      }
    }
  }
  for (const match of source.matchAll(/(?:"(?:title|subtitle|close|console)_font"\s*:\s*"([^"\n]+)"|(?:DEV_CONSOLE_FONTS|lfFaceName|FontName)\s*=\s*[^;]*;)/g)) {
    if (match[1] && !allowed.test(match[1])) bad.add(match[1]);
    if (!match[1]) for (const { value } of literals(match[0])) if (!value.endsWith('.zig') && !allowed.test(value)) bad.add(value);
  }
  return [...bad];
}

function zigFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const full = path.join(directory, entry.name);
    return entry.isDirectory() ? zigFiles(full) : entry.name.endsWith('.zig') ? [full] : [];
  });
}

const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('every Zig source requests only the approved UI, mono and glyph families', () => {
  const bad = zigFiles(path.join(root, 'src')).flatMap(file => violations(fs.readFileSync(file, 'utf8')).map(face => `${path.relative(root, file)}: ${face}`));
  assert.deepEqual(bad, []);
});

test('scanner rejects literals, UTF-16 names, theme JSON, LOGFONT and unknown GDI faces', () => {
  for (const source of [
    'CreateFontW(18, 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 0, 0, L("Papyrus"));',
    'const face = "Arial";',
    'const face = std.unicode.utf8ToUtf16LeStringLiteral("Inter");',
    'setWideAscii(&theme.title_font, "Tahoma");',
    '@memcpy(lf.lfFaceName[0..7], L("Verdana"));',
    '"subtitle_font": "Segoe UI"',
    'const DEV_CONSOLE_FONTS = .{ "Cascadia Mono" };',
    'const face = "Unbundled Family";',
    'const lfFaceName = "Papyrus";',
    'const font = L("Unbundled Family");',
    'const face = std.unicode.utf8ToUtf16LeStringLiteral("Papyrus");',
    'setWideAscii(&theme.title_font, "Unbundled Family");',
    '@memcpy(lf.lfFaceName[0..7], L("Papyrus"));',
  ]) assert.notEqual(violations(source).length, 0, source);
  assert.deepEqual(violations('CreateFontW(18, 0, 0, 0, 600, 0, 0, 0, 0, 0, 0, 0, 0, L("IBM Plex Sans SmBld"));'), []);
  assert.deepEqual(violations('const face = "IBM Plex Sans Medm";'), []);
  assert.deepEqual(violations('const SHELL_FACE = MONO_FACE;'), []);
  assert.deepEqual(violations('const MONO_FACE = "Nordwand Mono MP SemiBold";'), []);
  assert.match(read('src/fonts.zig'), /MONO_FACE = "Nordwand Mono MP SemiBold"/);
  assert.deepEqual(violations('L("Segoe UI Symbol"); L("Segoe UI Emoji");'), []);
  assert.deepEqual(violations('const face = L("Segoe Fluent Icons");'), []);
  assert.deepEqual(violations('const face = L("Segoe MDL2 Assets");'), []);
});

test('all genuine face files and both OFL licenses ship together', () => {
  for (const name of ['IBMPlexSans-Regular', 'IBMPlexSans-Italic', 'IBMPlexSans-Medium', 'IBMPlexSans-MediumItalic', 'IBMPlexSans-SemiBold', 'IBMPlexSans-Bold', 'IBMPlexSans-BoldItalic', 'NordwandMono-SemiBold']) {
    const bytes = fs.readFileSync(path.join(root, `src/fonts/${name}.ttf`));
    assert.equal(bytes.readUInt32BE(0), 0x00010000, name);
    assert.match(read('src/fonts.zig'), new RegExp(`@embedFile\\("fonts/${name}\\.ttf"\\)`));
  }
  for (const name of ['OFL.txt', 'LICENSE-NordwandMono.txt']) assert.match(read(`src/fonts/${name}`), /SIL Open Font License, Version 1\.1/i);
});

test('startup privately registers all faces before windows and sign-in and releases them', () => {
  const source = read('src/fonts.zig');
  assert.match(source, /AddFontMemResourceEx/);
  assert.match(source, /RemoveFontMemResourceEx/);
  const main = read('src/main.zig').split('pub fn main(init: std.process.Init) void {')[1];
  const registration = main.indexOf('@import("fonts.zig").register()');
  assert.ok(registration >= 0 && registration < main.indexOf('parseSyncAuthCallbackArg()'));
  assert.ok(registration < main.indexOf('CreateWindowExW('));
  assert.match(main, /defer @import\("fonts\.zig"\)\.unregister\(\)/);
  const users = zigFiles(path.join(root, 'src')).filter(file => fs.readFileSync(file, 'utf8').includes('AddFontMemResourceEx('));
  assert.deepEqual(users.map(file => path.basename(file)).sort(), ['fonts.zig', 'win32.zig']);
});

test('all UI creation uses the real-weight mapper and never a stock GUI font', () => {
  for (const file of zigFiles(path.join(root, 'src'))) {
    if (['fonts.zig', 'win32.zig'].includes(path.basename(file))) continue;
    const source = fs.readFileSync(file, 'utf8');
    assert.doesNotMatch(source, /@import\("win32\.zig"\)\.(?:CreateFontW|MessageBoxW|TrackPopupMenu|GetOpenFileNameW|CredUIPromptForCredentialsW)/, file);
    assert.doesNotMatch(source, /GetStockObject\(DEFAULT_GUI_FONT\)/, file);
  }
  const fonts = read('src/fonts.zig');
  assert.match(fonts, /UI_SEMIBOLD_FACE = "IBM Plex Sans SmBld"/);
  assert.match(fonts, /if \(mono\) 600/);
  assert.match(fonts, /if \(mono\) 0 else italic/);
  assert.match(fonts, /if \(mono\) 1 else charset/);
  assert.match(fonts, /GDI selects the authentic embedded face/);
  assert.match(fonts, /GetFontData/);
  assert.match(read('src/account_desktop.zig'), /L\(@import\("fonts\.zig"\)\.UI_FACE\)/);
});

test('native controls, dialogs and owner-drawn popup menus explicitly use Plex', () => {
  for (const name of ['rename', 'browser_pane']) assert.match(read(`src/${name}.zig`), /setControlFont\(app_state\.g_edit_hwnd\)/);
  for (const name of ['snippets', 'inbox', 'chat_composer']) assert.match(read(`src/${name}.zig`), /SendMessageW\([^;]*(?:WM_SETFONT|0x0030)/);
  const fonts = read('src/fonts.zig');
  assert.match(fonts, /EnumChildWindows\(hwnd, &setDialogChildFont/);
  assert.match(fonts, /SendMessageW\(hwnd, 0x0030/);
  assert.match(fonts, /ModifyMenuW/);
  assert.match(fonts, /SelectObject\(item\.dc, controlFont\(\)\)/);
  assert.match(read('src/main.zig'), /menuMessage\(msg, lp\)/);
  assert.match(read('src/main.zig'), /menuChar\(wp\)/);
  for (const name of ['rename', 'snippets', 'chat_composer']) assert.match(read(`src/${name}.zig`), /editMessage\(hwnd, app_state\.g_main_hwnd, msg, lp\)/);
  assert.match(read('src/chat_render.zig'), /@import\("fonts\.zig"\)\.openFileName/);
  assert.match(read('src/account_desktop.zig'), /@import\("fonts\.zig"\)\.promptForCredentials/);
});

test('CI includes both structural regressions and authentic Windows GDI selection', () => {
  const build = read('build.zig');
  assert.match(build, /"node", "--test", "tools\/one-font\.test\.js"/);
  assert.match(build, /test_step\.dependOn\(&one_font_tests\.step\)/);
  assert.match(build, /vps_test_step\.dependOn\(&one_font_tests\.step\)/);
  assert.match(build, /b\.path\("src\/fonts\.zig"\)/);
  assert.match(build, /test_step\.dependOn\(&b\.addRunArtifact\(font_tests\)\.step\)/);
});

function chatMetricPolicy(render) {
  const measurements = render.split('\n').filter(line => line.includes('DrawTextW(') && line.includes('L("Ag")'));
  assert.equal(measurements.length, 3);
  for (const measurement of measurements) assert.match(measurement, /chatLineHeight\(DrawTextW\(/);
  assert.equal(measurements.filter(line => line.includes('DrawTextW(hdc,')).length, 2);
  assert.equal(measurements.filter(line => line.includes('DrawTextW(self.hdc,')).length, 1);
  assert.match(render, /pub fn lineHeight\(self: \*TableMeasureBackend\) i32 \{[^]*?return chatLineHeight\(DrawTextW\(self\.hdc/);
}

test('Chat View uses grayscale Regular body text, real Bold emphasis and unchanged centralized leading', () => {
  const fonts = read('src/fonts.zig');
  assert.match(fonts, /UI_MEDIUM_FACE = "IBM Plex Sans Medm"/);
  assert.match(fonts, /CHAT_QUALITY: w\.DWORD = 4;/);
  assert.match(fonts, /CHAT_LINE_HEIGHT_PERMILLE: i32 = 1000;/);
  assert.match(fonts, /medium and weight < 600\) 500/);
  assert.match(fonts, /actual_weight == 500\) L\(UI_MEDIUM_FACE\)/);
  for (const file of ['chat_render', 'chat_composer']) {
    const source = read(`src/${file}.zig`);
    assert.match(source, /@import\("fonts\.zig"\)\.chat\(/);
    assert.match(source, /const chatLineHeight = @import\("fonts\.zig"\)\.chatLineHeight/);
    for (const request of source.split('\n').filter(line => line.includes('CreateFontW('))) {
      assert.match(request, /CHAT_QUALITY/);
      assert.match(request, /MONO_FACE/);
    }
  }
  assert.match(fonts, /body_weight: i32 = 400/);
  assert.match(fonts, /bold_weight: i32 = 700/);
  assert.match(fonts, /quality: w\.DWORD = CHAT_QUALITY/);
  assert.match(read('src/chat_composer.zig'), /\.chat\(-uiScaled\(app_state\.g_chat_font_pt\), false, false, false, \.\{\}\)/);
  const render = read('src/chat_render.zig');
  assert.match(render, /style\.bold or level > 0, style\.italic, false, \.\{\}/);
  chatMetricPolicy(render);
  assert.match(read('src/chat_composer.zig'), /chatLineHeight\(one\.bottom - one\.top\)/);
});

test('IGSH-436 cached table metrics still reject bypassing centralized leading', () => {
  const render = read('src/chat_render.zig');
  const regression = render.replace('return chatLineHeight(DrawTextW(self.hdc,', 'return (DrawTextW(self.hdc,');
  assert.notEqual(regression, render);
  assert.throws(() => chatMetricPolicy(regression), assert.AssertionError);
});
