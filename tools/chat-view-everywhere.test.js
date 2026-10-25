const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const skill = '.claude/skills/verify-multiprompt/';
const model = read('src/chat_view.zig');
const driver = read(skill + 'control.ps1');
const workflow = read('.github/workflows/verify.yml');
const restart = driver.slice(driver.indexOf('function Restart-ChatView('), driver.indexOf('function Wait-ChatFocus('));
const journey = driver.slice(driver.indexOf("        'chat-view-everywhere' {"), driver.indexOf("        'chat-focus' {"));

function bulkContract(source) {
  assert.match(source, /pub fn setEverywhere\(sessions: anytype, on: bool\) void \{\s*for \(sessions\) \|\*session\| \{\s*session.chat_view_on = on;/);
  assert.match(source, /pub fn toggle\(session: anytype\) void \{\s*session.chat_view_on = !session.chat_view_on;/);
  assert.match(source, /pub fn shouldShow\(on: bool\) bool \{\s*return on;/);
  assert.doesNotMatch(source, /chat_view_lock|pub const Lock|pub fn setLock|pub fn savedLock/);
}

test('IGSH-820 everywhere and normal toggles never depend on pinning or locks', () => {
  bulkContract(model);
  assert.throws(() => bulkContract(model.replace('session.chat_view_on = on;', 'if (!session.pinned_top) session.chat_view_on = on;')));
  assert.throws(() => bulkContract(model.replace('session.chat_view_on = !session.chat_view_on;', 'session.chat_view_on = true;')));
  const composer = read('src/chat_composer.zig');
  assert.match(composer, /@import\("chat_view.zig"\).toggle\(shell\);\s*if \(shell.chat_view_on\) openChatView\(\) else closeChatView\(\);\s*saveSession\(\);/);
  for (const file of ['src/console.zig', 'src/chat_composer.zig', 'src/clipboard.zig']) assert.doesNotMatch(read(file), /chat_view_lock/);
});

test('IGSH-820 old session fixture and both persistence writers ignore removed lock state', () => {
  for (const file of ['src/session.zig', 'src/workspaces.zig']) {
    const source = read(file);
    assert.doesNotMatch(source, /const saved_lock|\.locked|\.chat_view_lock|const cvm:|const cso =/);
    assert.match(source, /if \(app_state.shells\[i\].pinned_top\)/);
  }
  const reader = read('src/json_reader.zig');
  assert.doesNotMatch(reader, /"locked"|"chat_view_lock"/);
  assert.match(reader, /if \(std.mem.eql\(u8, mode, "everywhere"\)\) tab.cv = !tab.cso;/);
  assert.match(reader, /if \(std.mem.eql\(u8, mode, "nowhere"\)\) tab.cv = false;/);
  const fixture = JSON.parse(read('src/fixtures/json-reader/session-pre-IGSH-820.json'));
  assert.ok(fixture.tabs.some(tab => tab.locked && tab.chat_view_lock === 'shell' && tab.pinned_top && tab.cv));
  assert.ok(fixture.tabs.some(tab => tab.locked && tab.chat_view_lock === 'chat' && !tab.pinned_top && !tab.cv));
  assert.ok(read('src/session.zig').includes('test "IGSH-820 pre-change session ignores locks and preserves pinned tabs"'));
});

test('IGSH-820 commands expose pin protection and bulk views without removed rows', () => {
  for (const file of ['src/app_state.zig', 'src/main.zig', 'src/command_palette.zig', 'src/sidebar.zig', 'src/shortcuts.zig']) {
    assert.doesNotMatch(read(file), /SEARCH_CHAT_VIEW_LOCK_|SEARCH_TABCTX_VIEW_|SEARCH_LOCK_SESSION_OFFSET|SEARCH_TABCTX_LOCK|Always Chat View for this session|Always shell view for this session|Clear Always view for this session/);
  }
  const main = read('src/main.zig');
  assert.match(main, /setEverywhere\(app_state.shells\[0\.\.app_state.shell_count\], target == SEARCH_CHAT_VIEW_MODE_EVERYWHERE_OFFSET\)/);
  assert.match(main, /applySessionView\(\);\s*saveSession\(\);/);
  const shortcuts = read('src/shortcuts.zig');
  assert.match(shortcuts, /Pin to Top/);
  assert.match(shortcuts, /protect it from closing or archiving/);
});

function journeyContract(source, restartSource = restart) {
  const steps = [
    "Focus-Palette 'tab order' 6217", "'manual tab order saved before creating sessions'",
    "Focus-Palette 'new cmd' 2000", "Focus-Palette 'pin to top' 6293",
    "Wait-ChatViews @($false, $false, $false) 2 'pinned-shell'",
    "Press @(0x11, 0x57)", "Wait-ChatViews @($false, $false, $false) 2 'pinned-close-refused'",
    "Press @(0x12, 0x43) 'Alt+C: pinned session can enter Chat View'",
    '$toggleReady = [DateTime]::UtcNow.AddMilliseconds(1600)',
    "Wait-ChatViews @($false, $false, $true) 2 'pinned-toggle-chat'",
    "Wait-Until { [DateTime]::UtcNow -ge $toggleReady } 'Alt+C debounce elapsed before pinned shell toggle'",
    "Press @(0x12, 0x43) 'Alt+C: pinned session can return to shell'",
    '$toggleReady = [DateTime]::UtcNow.AddMilliseconds(1600)',
    "Wait-ChatViews @($false, $false, $false) 2 'pinned-toggle-shell'",
    "Focus-Palette 'chat view on everywhere' 6346", "Wait-ChatViews @($true, $true, $true) 2 'on-everywhere'",
    "Press @(0x11, 0x31)",
    "Wait-Until { [DateTime]::UtcNow -ge $toggleReady } 'Alt+C debounce elapsed before session 1 toggle'",
    "Press @(0x12, 0x43) 'Alt+C: session 1 back to shell'",
    "Wait-ChatViews @($false, $true, $true) 0 'session-1-toggled'",
    "Press @(0x11, 0x32)", "Wait-ChatViews @($false, $true, $true) 1 'session-2-chat'",
    "Press @(0x11, 0x31)", "Wait-ChatViews @($false, $true, $true) 0 'toggle-sticks'",
    "Focus-Palette 'chat view off everywhere' 6347", "Wait-ChatViews @($false, $false, $false) 0 'off-everywhere'",
    "Press @(0x11, 0x33)", "Wait-ChatViews @($false, $false, $false) 2 'pinned-after-off'",
    "Focus-Palette 'unpin from top' 6293",
    "Wait-ChatViews @($false, $false, $false) 2 'unpinned-before-restart' $false", 'Restart-ChatView 3',
    "Wait-ChatViews @($false, $false, $false) 0 'restart-session-1' $false",
    "Wait-ChatViews @($false, $false, $false) 1 'restart-session-2' $false",
    "Wait-ChatViews @($false, $false, $false) 2 'restart-session-3' $false",
    "foreach ($query in @('chat view per tab', 'lock session', 'always chat view for this session', 'always shell view for this session', 'clear always view for this session'))",
    "Focus-Palette 'chat view on everywhere' 6346", "'Esc: close known positive palette query'", 'Type-Text $query',
    '$query.Length + " count=0 target=0', "Wait-ChatViews @($false, $false, $false) 2 'after' $false",
  ];
  let from = 0;
  for (const step of steps) {
    const at = source.indexOf(step, from);
    assert.ok(at >= from, `missing or misordered ${step}`);
    from = at + step.length;
  }
  for (const token of ['$process.CloseMainWindow()', '$process.WaitForExit(10000)', '$job.Stop()', '$stopped.ActiveProcesses -ne 0', '$job.Start($Exe, $scratch,', 'Doctor']) assert.ok(restartSource.includes(token), token);
  assert.match(restartSource, /Wait-Until \{\s+Doctor\s+\[VerifyNative\]::BringToForeground\(\$script:window\)\s+\[VerifyNative\]::GetAncestor\(\[VerifyNative\]::GetForegroundWindow\(\), 2\) -eq \$script:window\s+\} 'restarted app foreground'\s+Doctor/);
  const debounce = Number(read('src/app_state.zig').match(/BROWSER_TOGGLE_DEBOUNCE_MS: u32 = (\d+)/)[1]);
  const waits = [...source.matchAll(/AddMilliseconds\((\d+)\)/g)];
  assert.equal(waits.length, 2);
  for (const wait of waits) assert.ok(Number(wait[1]) > debounce);
  assert.doesNotMatch(source, /Set-Content|WriteAllText|WriteAllBytes|PostMessage|SetEnvironmentVariable/);
}

test('IGSH-820 Windows journey checks pinned toggles, refused Ctrl+W, all views and removed commands', () => {
  journeyContract(journey);
  for (const step of ["Wait-ChatViews @($false, $false, $true) 2 'pinned-toggle-chat'", "Wait-ChatViews @($false, $false, $false) 2 'pinned-close-refused'", "Wait-Until { [DateTime]::UtcNow -ge $toggleReady } 'Alt+C debounce elapsed before pinned shell toggle'", "Wait-Until { [DateTime]::UtcNow -ge $toggleReady } 'Alt+C debounce elapsed before session 1 toggle'", '$query.Length + " count=0 target=0', "Focus-Palette 'unpin from top' 6293"]) assert.throws(() => journeyContract(journey.replace(step, '')));
  assert.throws(() => journeyContract(journey.replaceAll('AddMilliseconds(1600)', 'AddMilliseconds(100)')));
  assert.throws(() => journeyContract(journey.replace("@($false, $false, $false) 2 'pinned-toggle-shell'", "@($false, $false, $false) 0 'pinned-toggle-shell'")));
  assert.throws(() => journeyContract(journey, restart.replace('$stopped.ActiveProcesses -ne 0', '$false')));
  const wait = driver.slice(driver.indexOf('function Wait-ChatViews('), driver.indexOf('function Read-BrowserPane'));
  for (const required of ['Read-Session', '@($state.tabs).Count -ne 3', '$state.active_tab -ne $Active', '$on -ne $Views[$i]', "PSObject.Properties['chat_view_lock']", "PSObject.Properties['locked']", "$state.tabs[2].PSObject.Properties['pinned_top']", '$pin -eq $Pinned', "ClassNameProperty, 'ZigShellChatTranscript'", '$visible -eq [int]$Views[$Active]', 'Save-Json (Read-Session)', 'Snapshot $Step']) assert.ok(wait.includes(required), required);
});

test('IGSH-820 pinned view expectations follow serialized shell order and the debounced Alt+C route', () => {
  const session = read('src/session.zig');
  const save = session.slice(session.indexOf('pub fn saveSessionTo('), session.indexOf('pub fn saveSession('));
  assert.match(save, /for \(0\.\.app_state\.shell_count\) \|i\|/);
  assert.match(save, /if \(i == app_state\.active_shell[^\n]*active_tab = written_tabs;/);
  assert.match(save, /if \(app_state\.shells\[i\]\.pinned_top\)/);
  assert.match(save, /if \(app_state\.shells\[i\]\.chat_view_on and/);
  const shortcuts = read('src/shortcuts.zig');
  assert.match(shortcuts, /kb\.vkCode == 0x43[\s\S]*?claimBrowserTogglePress\(true, kb\.time, &app_state\.g_chat_toggle_chord_held, &app_state\.g_chat_toggle_last_event_time\)[\s\S]*?PostMessageW\(app_state\.g_main_hwnd, WM_APP_CHAT_TOGGLE, 0, 0\)/);
  assert.match(read('src/main.zig'), /WM_APP_CHAT_TOGGLE => \{\s*toggleChatView\(\);/);
});

test('IGSH-820 native refused-action tests, maps and existing Windows journey are wired', () => {
  const main = read('src/main.zig');
  for (const title of [
    'IGSH-820 pinned tab refuses close',
    'IGSH-820 pinned tab refuses Ctrl+W',
    'IGSH-820 pinned tab refuses archive',
    'IGSH-820 pinned tab refuses end session',
    'IGSH-820 pinned tab refuses group close atomically',
    'IGSH-820 pinned tab refuses workspace close atomically',
    'IGSH-820 pinned tab refuses Inbox archive',
  ]) assert.ok(main.includes(`test "${title}"`), title);
  assert.match(workflow, /feature:.*fromJSON\('\[[^\n]*"chat-view-everywhere"/);
  assert.match(workflow, /if: \(env.FEATURE == 'chat-view' \|\| env.FEATURE == 'chat-view-everywhere'\) && env.RELEASE_TAG == ''(?:(?!\r?\n      - )[\s\S])*?zig build test-main/m);
  for (const name of ['chat-view-everywhere']) {
    assert.deepEqual(read(skill + `features/${name}.md`).match(/^## .+$/gm), ['## Sub-features', '## How to get to it (user POV)', '## Driving it with control.ps1', '## Gotchas']);
    assert.ok(read(skill + 'features/README.md').includes(`](${name}.md)`));
  }
  assert.match(read('openwiki/operations/keyboard-shortcuts.md'), /Switch every session once/);
  assert.match(read(skill + 'coverage.md'), /\| IGSH-820 \|/);
});
