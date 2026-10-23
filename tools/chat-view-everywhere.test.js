const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { readChangelogEntry } = require('./changelog-entry');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const skill = '.claude/skills/verify-multiprompt/';
const model = read('src/chat_view.zig');
const composer = read('src/chat_composer.zig');
const state = read('src/app_state.zig');
const palette = read('src/command_palette.zig');
const main = read('src/main.zig');
const session = read('src/session.zig');
const driver = read(skill + 'control.ps1');
const workflow = read('.github/workflows/verify.yml');
const journey = driver.slice(driver.indexOf("        'chat-view-everywhere' {"), driver.indexOf("        'appearance' {"));

function noGlobalForcing(source) {
  assert.doesNotMatch(source, /\bg_chat_view_mode\b|\bg_chat_view_restore_on\b|\bchat_shell_override\b|SEARCH_CHAT_VIEW_MODE_PER_SESSION_OFFSET/);
}

function bulkContract(source) {
  assert.match(source, /pub fn setEverywhere\(sessions: anytype, on: bool\) void \{\s*for \(sessions\) \|\*session\| \{\s*if \(session.chat_view_lock == \.none\) session.chat_view_on = on;/);
  assert.match(source, /pub fn toggle\(session: anytype\) void \{\s*if \(session.chat_view_lock == \.none\) session.chat_view_on = !session.chat_view_on;/);
  assert.match(source, /pub fn shouldShow\(on: bool, lock: Lock\) bool \{\s*return switch \(lock\) \{\s*\.none => on,\s*\.chat => true,\s*\.shell => false,/);
  assert.match(source, /session.chat_view_lock = lock;\s*session.chat_view_on = shouldShow\(session.chat_view_on, lock\);/);
}

test('ISSUE-611 pure state contracts use one-time writes and persistent session locks, not global forcing', () => {
  bulkContract(model);
  assert.throws(() => bulkContract(model.replace('if (session.chat_view_lock == .none) session.chat_view_on = on;', 'session.chat_view_on = on;')));
  assert.throws(() => bulkContract(model.replace('.none => on,', '.none => true,')));
  assert.throws(() => bulkContract(model.replace('session.chat_view_on = !session.chat_view_on;', 'session.chat_view_on = true;')));
  const files = fs.readdirSync(path.join(root, 'src')).filter(file => file.endsWith('.zig'));
  for (const file of files) noGlobalForcing(read('src/' + file));
  const old = execFileSync('git', ['show', '8a4d05d242b19cb9c6bc5fff8b43909707aed8bf:src/chat_composer.zig'], { cwd: root, encoding: 'utf8' });
  assert.match(old, /g_chat_view_mode/);
  assert.throws(() => noGlobalForcing(old));
});

test('ISSUE-611 native behavior tests and actual toggle and tab-switch paths use the same state model', () => {
  for (const name of ['on everywhere changes all unlocked sessions and skips both locks', 'a later Alt+C toggle sticks across tab switches after on everywhere', 'off everywhere changes unlocked flags without defeating locks']) {
    assert.ok(model.includes(`test "ISSUE-611 ${name}"`));
  }
  assert.match(model, /setEverywhere\(&sessions, true\);\s*toggle\(&sessions\[0\]\);/);
  assert.match(model, /setEverywhere\(&sessions, false\)/);
  assert.match(model, /setLock\(&sessions\[2\], \.none\)/);
  assert.match(composer, /pub const chatViewShouldShowForTab = @import\("chat_view.zig"\).shouldShow/);
  assert.match(composer, /@import\("chat_view.zig"\).toggle\(shell\);\s*if \(shell.chat_view_on\) openChatView\(\) else closeChatView\(\);\s*saveSession\(\);/);
  assert.match(composer, /shell.chat_view_lock != \.none[\s\S]*?return;/);
  assert.match(read('src/console.zig'), /const want_chat = chatViewShouldShowForTab\(app_state.shells\[idx\].chat_view_on, app_state.shells\[idx\].chat_view_lock\)/);
  assert.match(read('src/console.zig'), /\.chat_view_lock = saved_chat_view_lock/);
  assert.match(composer, /test "ISSUE-440 full width respects remembered views and session locks"/);
  assert.match(main, /launch_cache.bindRestoredChat\(\);\s*@import\("chat_composer.zig"\).applySessionView\(\);/);
});

test('ISSUE-611 both persistence writers save locks and the reader migrates old modes with scoped shell overrides', () => {
  for (const file of ['src/session.zig', 'src/workspaces.zig']) {
    assert.match(read(file), /const saved_lock = @import\("chat_view.zig"\).savedLock\(app_state.shells\[i\].chat_view_lock\);\s*@memcpy\(json_buf\[pos \.\. pos \+ saved_lock.len\], saved_lock\);/);
    assert.doesNotMatch(read(file), /const cvm:|const cso =/);
  }
  const reader = read('src/json_reader.zig');
  assert.match(reader, /string\(field\(root, "chat_view_mode"\)\)/);
  assert.match(reader, /if \(std.mem.eql\(u8, mode, "everywhere"\)\) tab.cv = !tab.cso;/);
  assert.match(reader, /if \(std.mem.eql\(u8, mode, "nowhere"\)\) tab.cv = false;/);
  assert.match(reader, /string\(field\(obj, "chat_view_lock"\)\)/);
  assert.match(reader, /tab.cv = @import\("chat_view.zig"\).shouldShow\(tab.cv, tab.chat_view_lock\)/);
  assert.match(session, /app_state.shells\[idx\].chat_view_lock = tab.chat_view_lock;/);
  assert.match(session, /test "ISSUE-611 ISSUE-373 legacy everywhere and nowhere migrate shell overrides once"/);
  assert.match(session, /test "ISSUE-611 session locks survive session write parse and restore"/);
  assert.match(session, /saveSessionTo\(path, 0\)[\s\S]*?readFileAllocWin32\(path, SESSION_JSON_CAPACITY\)[\s\S]*?parseSessionTabs\(bytes, &tabs\)[\s\S]*?restoreBrowserStateFromSavedTab\(@intCast\(i\), &tabs\[i\]\)/);
  assert.match(session, /const locks = \[_\]@import\("chat_view.zig"\).Lock\{ \.shell, \.chat, \.none \}/);
});

test('ISSUE-611 commands are searchable, painted and handled for the active session and exact context tab', () => {
  const sidebar = read('src/sidebar.zig');
  const shortcuts = read('src/shortcuts.zig');
  for (const [suffix, context, label] of [
    ['CHAT', 'CHAT', 'Always Chat View for this session'],
    ['SHELL', 'SHELL', 'Always shell view for this session'],
    ['CLEAR', 'CLEAR', 'Clear Always view for this session'],
  ]) {
    const global = `SEARCH_CHAT_VIEW_LOCK_${suffix}_OFFSET`;
    const tab = `SEARCH_TABCTX_VIEW_${context}`;
    assert.ok(palette.includes(`= ${global};`));
    assert.ok(palette.includes(`= ${tab};`));
    assert.ok(sidebar.includes(`L("${label}")`));
    assert.ok(shortcuts.includes(label));
    assert.ok(main.includes(`target == ${global}`));
    assert.ok(main.includes(`target == ${tab}`));
    assert.match(state, new RegExp(`pub const ${tab}: usize = 71\\d{2};`));
  }
  assert.match(main, /const idx = if \(is_context\) findShellById\(app_state.g_tabctx_sid\)/);
  assert.match(main, /setLock\(&app_state.shells\[ti\], lock\)/);
  assert.match(main, /setEverywhere\(app_state.shells\[0\.\.app_state.shell_count\], target == SEARCH_CHAT_VIEW_MODE_EVERYWHERE_OFFSET\)/);
  assert.match(main, /applySessionView\(\);\s*saveSession\(\);/);
  assert.doesNotMatch(palette, /chat view per tab|Chat View: Per Tab/);
  assert.throws(() => assert.doesNotMatch('chat view per tab', /chat view per tab|Chat View: Per Tab/));
});

function journeyContract(source) {
  assert.ok(source.length > 0);
  const steps = [
    "Focus-Palette 'tab order' 6217", "'Down: Tab Order Manual'", "'Enter: keep creation order for Ctrl+1/2/3'",
    "'manual tab order saved before creating sessions'",
    "Focus-Palette 'new cmd' 2000", "Focus-Palette 'always shell view for this session' 6465",
    "Wait-ChatViews @($false, $false, $false) 2 'locked-shell'",
    "Focus-Palette 'chat view on everywhere' 6346", "Wait-ChatViews @($true, $true, $false) 2 'on-everywhere'",
    "Wait-ChatViews @($true, $true, $false) 0 'session-1-chat'", "Press @(0x12, 0x43)",
    "Wait-ChatViews @($false, $true, $false) 0 'session-1-toggled'",
    "Wait-ChatViews @($false, $true, $false) 1 'session-2-chat'",
    "Wait-ChatViews @($false, $true, $false) 0 'toggle-sticks'",
    "Focus-Palette 'chat view off everywhere' 6347", "Wait-ChatViews @($false, $false, $false) 0 'off-everywhere'",
    '$process.CloseMainWindow()', '$process.WaitForExit(10000)', '$job.Stop()', '$stopped.ActiveProcesses -ne 0',
    '$job.Start($Exe, $scratch,', "'restarted owned window and three restored sessions' 60", 'Doctor',
    "Wait-ChatViews @($false, $false, $false) 0 'restart-session-1'",
    "Wait-ChatViews @($false, $false, $false) 1 'restart-session-2'",
    "Wait-ChatViews @($false, $false, $false) 2 'restart-session-3'",
    "Focus-Palette 'chat view on everywhere' 6346", "'Esc: close known positive palette query'", "'Ctrl+K: reopen empty command palette'", "'empty palette ready for removed-command query'", "Type-Text 'chat view per tab'",
    'ready chars=17 count=0 target=0', "Snapshot 'per-tab-absent'", "Wait-ChatViews @($false, $false, $false) 2 'after'",
    "$result.checks += @{ name = 'chat-view-everywhere-once'",
  ];
  let from = 0;
  for (const step of steps) {
    const at = source.indexOf(step, from);
    assert.ok(at >= from, `missing or misordered ${step}`);
    from = at + step.length;
  }
  assert.match(source, /Join-Path \$scratch 'roaming\/ZigShell\/session\.json\.launch\.json'/);
  assert.match(source, /if \(-not \(Test-Path \$path\)\) \{ return \$false \}/);
  assert.match(source, /\$launch = Get-Content \$path -Raw \| ConvertFrom-Json\s+\$launch\.PSObject\.Properties\['sort_auto'\] -and -not \$launch\.sort_auto/);
  assert.doesNotMatch(source, /Set-Content|WriteAllText|WriteAllBytes|PostMessage|SetEnvironmentVariable/);
}

test('ISSUE-611 Windows journey drives real input, asserts every saved view, restarts safely and proves the removed row absent', () => {
  journeyContract(journey);
  assert.throws(() => journeyContract(journey.replace("Wait-ChatViews @($false, $true, $false) 0 'toggle-sticks'", '')));
  assert.throws(() => journeyContract(journey.replace('ready chars=17 count=0 target=0', 'ready chars=17 count=1 target=6464')));
  assert.throws(() => journeyContract(journey.replace('$stopped.ActiveProcesses -ne 0', '$false')));
  for (const before of ["Focus-Palette 'tab order' 6217", "'Down: Tab Order Manual'", "'manual tab order saved before creating sessions'", "-not $launch.sort_auto"]) {
    assert.throws(() => journeyContract(journey.replace(before, '')));
  }
  const lateOrder = journey.replace("Focus-Palette 'tab order' 6217", '').replace("Focus-Palette 'always shell view for this session' 6465", "Focus-Palette 'tab order' 6217\nFocus-Palette 'always shell view for this session' 6465");
  assert.throws(() => journeyContract(lateOrder));
  assert.match(read('src/launch_cache.zig'), /sort_auto = state\.g_tab_sort_auto/);
  assert.match(read('src/launch_cache.zig'), /state\.g_tab_sort_auto = s\.sort_auto/);

  const wait = driver.slice(driver.indexOf('function Wait-ChatViews('), driver.indexOf('function Read-BrowserPane'));
  for (const required of ['Read-Session', '@($state.tabs).Count -ne 3', '$state.active_tab -ne $Active', '$on -ne $Views[$i]', "$state.tabs[2].chat_view_lock -ceq 'shell'", "PSObject.Properties['chat_view_mode']", "ClassNameProperty, 'ZigShellChatTranscript'", '$visible -eq [int]$Views[$Active]', 'Save-Json (Read-Session)', 'Snapshot $Step']) assert.ok(wait.includes(required), required);
  assert.match(journey, /for \(\$count = 2; \$count -le 3; \$count\+\+\)/);
  assert.match(journey, /@\(\$state.tabs\).Count -eq \$count -and \$state.active_tab -eq \$count - 1/);
});

test('ISSUE-611 feature map, branch Windows tests, PR matrix, documentation and changelog are wired', () => {
  const feature = 'chat-view-everywhere';
  assert.match(driver, /ValidateSet\([^\n]*'chat-view-everywhere'/);
  assert.match(workflow, /FEATURE -notin @\([^\n]*'chat-view-everywhere'/);
  assert.match(workflow, /feature:.*fromJSON\('\[[^\n]*"chat-view-everywhere"/);
  assert.match(workflow, /if: \(env.FEATURE == 'chat-view' \|\| env.FEATURE == 'chat-view-everywhere'\) && env.RELEASE_TAG == ''[\s\S]*?zig build test-main --summary all/);
  assert.ok(workflow.includes('node --test tools/verify-multiprompt.test.js tools/chat-view-everywhere.test.js'));
  const map = read(skill + `features/${feature}.md`);
  assert.deepEqual(map.match(/^## .+$/gm), ['## Sub-features', '## How to get to it (user POV)', '## Driving it with control.ps1', '## Gotchas']);
  assert.ok(read(skill + 'features/README.md').includes(`](${feature}.md)`));
  assert.ok(read(skill + 'SKILL.md').includes(`](features/${feature}.md)`));
  assert.ok(read(skill + 'coverage.md').includes('| IGSH-611 |'));
  assert.match(read('openwiki/operations/keyboard-shortcuts.md'), /switches every unlocked session once/);
  const fragment = readChangelogEntry('IGSH-611');
  assert.match(fragment, /just once/);
  assert.match(fragment, /across restarts/);
  assert.doesNotMatch(fragment, /\.zig|JSON|chat_view_|ISSUE-/);
});
