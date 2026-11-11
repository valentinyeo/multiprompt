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

test('IGSH-1507 plain Chrome skips first-run and default-browser prompts', () => {
  const body = functionBody(read('src/browser_signin.zig'), 'plainProfileLaunch');
  const command = body.match(/std\.fmt\.bufPrint\(out, "((?:\\.|[^"\\])*)"/);
  assert.ok(command, 'plain Chrome launch must format a command line');
  for (const flag of ['--no-first-run', '--no-default-browser-check']) {
    assert.ok(command[1].split(' ').includes(flag), `plain Chrome must include ${flag}`);
  }
});

test('IGSH-1507 a rejected Google sign-in page turns the controlled pane into a plain window', () => {
  const pane = read('src/browser_pane.zig');
  assert.match(pane, /const browser_signin = @import\("browser_signin\.zig"\);|@import\("browser_signin\.zig"\)/);
  assert.match(pane, /pub fn signInGoogleForShell\(idx: u32\) bool \{/);
  const body = functionBody(pane, 'signInGoogleForShell');
  assert.match(body, /browser_signin\.plainProfileLaunch\(&cmd_buf, exe, dir, browserProfile\(\)\)/,
    'the plain window must reuse the verified executable and tab own profile directory');
  assert.match(body, /closeBrowserForShell\(@intCast\(i\)\);/, 'all managed panes sharing the profile must close');
  assert.match(body, /std\.mem\.eql\(u8, &app_state\.shells\[i\]\.browser_profile_token, &profile\)/);
  const worker = functionBody(pane, 'browserSigninWorker');
  assert.ok(worker.indexOf('WaitForSingleObject(job.process, 15_000)') < worker.indexOf('CreateProcessW('),
    'the actual controlled process must exit before starting plain Chrome');
  assert.match(worker, /WaitForSingleObject\(pi\.hProcess, 250\)/, 'the reservation must outlive plain Chrome');
  const launch = functionBody(pane, 'launchBrowserForShellEx');
  assert.match(launch, /browserSigninProfileBusy\(launch_engine, launch_profile\)/, 'same-profile relaunch must be blocked');
  assert.match(body, /browser_enabled = false;/, 'the pane must not relaunch the controlled browser straight away');
  const hook = pane.slice(pane.indexOf('fn offerPlainSigninForRejectedPage('), pane.indexOf('fn offerPlainSigninForRejectedPage(') + 400);
  assert.match(hook, /browser_signin\.rejectedSigninUrl\(url\)/, 'the rejected page must be recognised from the pane URL');
  assert.match(pane, /if \(offerPlainSigninForRejectedPage\(idx, url\)\) \{/, 'the URL poll must offer the plain sign-in');
});

test('IGSH-1507 global Ctrl+K exposes sign-in for the active own-profile tab', () => {
  const palette = read('src/command_palette.zig');
  const generalBrowserActions = palette.slice(palette.indexOf('var show_browser_toggle'));
  assert.match(generalBrowserActions, /browserProfileToken\(app_state\.active_shell\)/);
  assert.match(generalBrowserActions, /g_search_results\[app_state\.g_search_result_count\] = SEARCH_TABCTX_GOOGLE_SIGNIN/);
  const main = read('src/main.zig');
  const branch = main.slice(main.indexOf('if (target == SEARCH_TABCTX_GOOGLE_SIGNIN) {'), main.indexOf('if (target == SEARCH_TABCTX_ADOPT_HOST) {'));
  assert.match(branch, /g_tabctx_sid == 0 and app_state\.active_shell < app_state\.shell_count/);
  assert.match(branch, /app_state\.shells\[app_state\.active_shell\]\.shell_id/);
});

test('IGSH-1507 hosted sign-in proof checks the actual Chrome owner with two same-profile panes', () => {
  const control = read('.claude/skills/verify-multiprompt/control-feature-browser-own-profile.ps1');
  assert.match(control, /Two distinct managed panes must share the same controlled Chrome process and profile/);
  assert.match(control, /Focus-Palette 'sign in to google' 7191/);
  assert.match(control, /Get-PaneUserDataDir \$handle/);
  assert.match(control, /\$script:signinWindow\.browser\.commandLine -match/);
  assert.match(control, /Sign-in window is owned by a controlled Chrome process/);
  assert.match(control, /original controlled Chrome process exited/);
  assert.match(control, /Unrelated profile process exited during sign-in/);
  assert.match(control, /Reopened browser lost the sign-in profile/);
});

test('IGSH-1507 hosted no-control oracle rejects pipes, ports and automation flags', () => {
  const control = read('.claude/skills/verify-multiprompt/control-feature-browser-own-profile.ps1');
  const match = control.match(/\$script:signinWindow\.browser\.commandLine -match '([^']+)'/);
  assert.ok(match, 'actual owning-process command line must be checked');
  const oracle = new RegExp(match[1].replace('(?i)', ''), 'i');
  for (const flag of [...CONTROL_FLAGS, '--remote-debugging-port=9222', '--remote-debugging-port=0', '--enable-automation']) {
    assert.equal(oracle.test(`chrome.exe --user-data-dir=fixture ${flag}`), true, flag);
  }
  assert.equal(oracle.test('chrome.exe --user-data-dir=fixture --profile-directory=Default --new-window https://accounts.google.com'), false);
  assert.match(control, /Plain sign-in window uses another Chrome profile directory/);
  assert.match(control, /standalone Chrome reads synthetic storage and matching cookie/);
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
