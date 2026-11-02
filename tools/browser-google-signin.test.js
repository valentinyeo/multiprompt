const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const { readChangelogEntry } = require('./changelog-entry');

const read = (file) => (fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '');

const CONTROL_FLAGS = ['--remote-debugging-pipe', '--enable-unsafe-extension-debugging', '--disable-sync', '--load-extension'];

const functionBody = (source, name) => {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `missing ${name}`);
  const end = source.indexOf('\n}', start);
  assert.ok(end > start, `missing the end of ${name}`);
  return source.slice(start, end);
};

test('IGSH-1507 the plain sign-in launch keeps the profile and drops every control flag', () => {
  const signin = read('src/browser_signin.zig');
  assert.match(signin, /pub const SIGNIN_URL = "https:\/\/accounts\.google\.com";/);
  assert.match(signin, /pub fn rejectedSigninUrl\(url: \[\]const u8\) bool \{/);
  assert.match(signin, /pub fn plainProfileLaunch\(out: \[\]u8, exe: \[\]const u8, user_data_dir: \[\]const u8, profile_directory: \[\]const u8\) \?\[\]const u8 \{/);
  for (const flag of CONTROL_FLAGS) {
    assert.ok(signin.includes(`"${flag}"`), `${flag} must stay named as a control flag`);
  }
  const body = functionBody(signin, 'plainProfileLaunch');
  assert.match(body, /--user-data-dir=\\"/, 'the plain window must open the same profile directory');
  assert.match(body, /--profile-directory=\{s\}/, 'the plain window must open the same profile');
  assert.match(body, /--new-window \{s\}/, 'the plain window must be a normal browser window');
  for (const flag of CONTROL_FLAGS) {
    assert.ok(!body.includes(flag), `the plain sign-in window must not carry ${flag}`);
  }
  const matcher = functionBody(signin, 'rejectedSigninUrl');
  assert.match(matcher, /signin\/rejected|REJECTED_MARKER/, 'the matcher must look for the Google rejected sign-in page');
  assert.match(matcher, /SIGNIN_HOST/, 'the matcher must pin the Google accounts host');
});

test('IGSH-1507 a rejected Google sign-in page turns the controlled pane into a plain window', () => {
  const pane = read('src/browser_pane.zig');
  assert.match(pane, /const browser_signin = @import\("browser_signin\.zig"\);|@import\("browser_signin\.zig"\)/);
  assert.match(pane, /pub fn signInGoogleForShell\(idx: u32\) bool \{/);
  const body = functionBody(pane, 'signInGoogleForShell');
  assert.match(body, /browser_signin\.plainProfileLaunch\(&cmd_buf, browserExePath\(\), dir, browserProfile\(\)\)/,
    'the plain window must reuse the tab own profile directory');
  assert.match(body, /closeBrowserForShell\(idx\);/, 'the controlled Chrome for this pane must be closed first');
  assert.match(body, /browser_enabled = false;/, 'the pane must not relaunch the controlled browser straight away');
  const hook = pane.slice(pane.indexOf('fn offerPlainSigninForRejectedPage('), pane.indexOf('fn offerPlainSigninForRejectedPage(') + 400);
  assert.match(hook, /browser_signin\.rejectedSigninUrl\(url\)/, 'the rejected page must be recognised from the pane URL');
  assert.match(pane, /if \(offerPlainSigninForRejectedPage\(idx, url\)\) \{/, 'the URL poll must offer the plain sign-in');
});

test('IGSH-1507 Sign in to Google is reachable from Ctrl+K, the tab actions and the shortcut list', () => {
  const state = read('src/app_state.zig');
  assert.match(state, /pub const SEARCH_TABCTX_GOOGLE_SIGNIN: usize = \d+;/);
  const palette = read('src/command_palette.zig');
  assert.match(palette, /if \(target == SEARCH_TABCTX_GOOGLE_SIGNIN\) return "Sign in to Google in this profile";/);
  assert.match(palette, /SEARCH_TABCTX_GOOGLE_SIGNIN => "sign in to google account chrome profile",/);
  assert.match(palette, /app_state\.g_search_results\[app_state\.g_search_result_count\] = SEARCH_TABCTX_GOOGLE_SIGNIN;/);
  assert.match(read('src/main.zig'), /if \(target == SEARCH_TABCTX_GOOGLE_SIGNIN\) \{/);
  assert.match(read('src/sidebar.zig'), /SEARCH_TABCTX_GOOGLE_SIGNIN\) L\(ui_words\.tab_context_google_signin\)/);
  assert.match(read('src/ui_words.zon'), /\.tab_context_google_signin = "Sign in to Google in this profile",/);
  assert.match(read('src/shortcuts.zig'), /Ctrl\+K \\u\{2192\} Sign in to Google in this profile/);
  assert.match(read('openwiki/operations/keyboard-shortcuts.md'), /Sign in to Google in this profile/);
  assert.match(readChangelogEntry('IGSH-1507'), /Google sign-in/);
});
