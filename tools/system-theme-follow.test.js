const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const app = require('./app-source').readAppSource();

test("System theme resolves the Windows app color preference", () => {
  assert.match(app, /RegOpenCurrentUser\(KEY_QUERY_VALUE, &current_user\)/);
  assert.match(app, /Themes\\\\Personalize"\),\s+L\("AppsUseLightTheme"\)/);
  assert.match(app, /fn resolveSystemThemeFlags\(\) void \{\s+g_light_theme = windowsAppsUseLightTheme\(\);/);
});

test("System remains the persisted preference while Edge receives a concrete theme", () => {
  assert.match(app, /fn themePreferenceToken\(\) \[\]const u8 \{\s+return if \(g_system_theme\) "system" else currentThemeToken\(\);/);
  assert.match(app, /const tok = themePreferenceToken\(\);/);
  assert.match(app, /indexOf\(u8, s, "system"\)[\s\S]{0,120}?g_system_theme = true;\s+resolveSystemThemeFlags\(\);/);
  assert.match(app, /appendBrowserWideAscii\(params, pos, currentThemeToken\(\)\)/);
});

test("theme palette offers System independently of fixed themes", () => {
  assert.match(app, /const SEARCH_THEME_SYSTEM_OFFSET: usize = 4009/);
  assert.match(app, /const theme_ids = \[_\]usize\{ SEARCH_THEME_SYSTEM_OFFSET,/);
  assert.match(app, /SEARCH_THEME_SYSTEM_OFFSET => L\("System"\)/);
  assert.match(app, /if \(g_system_theme\) \(if \(g_light_theme\) L\("System Light"\) else L\("System Dark"\)\)/);
  assert.match(app, /SEARCH_THEME_SYSTEM_OFFSET => \.system,/);
  assert.match(fs.readFileSync(path.join(root, "src/main.zig"), "utf8"), /if \(theme_choice\) \|choice\| \{\s+@import\("themes.zig"\)\.choose\(choice\);/);
  assert.match(app, /g_system_theme = choice == \.system;[\s\S]{0,180}?resolveSystemThemeFlags\(\);/);
});

test("Windows theme notifications reskin the full app and isolated Edge", () => {
  const refresh = app.match(/fn refreshSystemTheme\(hwnd: HANDLE\) void \{([\s\S]*?)\n\}/)?.[1] ?? "";
  assert.match(refresh, /if \(!g_system_theme\) return;/);
  assert.match(refresh, /resetFontCache\(\);/);
  assert.match(refresh, /applyTitleBarTheme\(\);/);
  assert.match(refresh, /applyConsoleThemeToAllShells\(\);/);
  assert.match(refresh, /refreshBrowserEdgeMasks\(\);/);
  assert.match(refresh, /syncEdgeProfileTheme\(\);/);
  assert.match(app, /WM_SETTINGCHANGE, WM_THEMECHANGED => \{\s+refreshSystemTheme\(hwnd\);/);
});

test("System theme polling repairs a missed Windows broadcast", () => {
  assert.match(app, /const TIMER_SYSTEM_THEME: usize = 25/);
  assert.match(app, /if \(wp == TIMER_SYSTEM_THEME\) \{\s+refreshSystemTheme\(hwnd\);\s+return 0;/);
  assert.match(app, /setCoalescableTimerInterval\(hwnd, TIMER_SYSTEM_THEME, 1000\)/);
});
