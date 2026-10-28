const { test } = require('node:test');

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function featureMatrix(source) {
  assert.match(source, /fromJSON\(needs\.journeys\.outputs\.full\)/);
  return require('./verify-features.cjs').discoverFeatures();
}
const { readChangelogEntry } = require('./changelog-entry');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const skill = '.claude/skills/verify-multiprompt/';
const focus = read('src/focus.zig');
const shortcuts = read('src/shortcuts.zig');
const find = read('src/chat_find_ui.zig');
const main = read('src/main.zig');
const composer = read('src/chat_composer.zig');
const driver = read(skill + 'control.ps1');
const workflow = read('.github/workflows/verify.yml');
const recipe = driver.slice(driver.indexOf("        'chat-focus' {"), driver.indexOf("        'appearance' {\n            Select-Theme"));

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  const end = source.indexOf('\n}', start);
  assert.ok(end > start, name);
  return source.slice(start, end + 2);
}

function decision(source, name, args) {
  const expression = body(source, name).match(/return ([\s\S]*?);/);
  assert.ok(expression, name);
  return Function(...args, `return ${expression[1].replace(/\band\b/g, '&&').replace(/\bor\b/g, '||').replace(/\bWM_KEYDOWN\b/g, '0x100').replace(/\bWM_SYSKEYDOWN\b/g, '0x104')};`);
}

function chordContract(source) {
  const chord = decision(source, 'browserFocusChord', ['msg', 'vk', 'ctrl', 'alt']);
  for (const msg of [0x100, 0x104]) {
    for (const vk of [0x51, 0x4d]) {
      assert.equal(chord(msg, vk, false, true), true);
      assert.equal(chord(msg, vk, true, true), false);
      assert.equal(chord(msg, vk, false, false), false);
    }
  }
  for (const msg of [0x101, 0x105, 0x102, 0x106]) assert.equal(chord(msg, 0x51, false, true), false);
  assert.equal(chord(0x104, 0x41, false, true), false);
}

test('ISSUE-716 shared native chord decision preserves both key forms and excludes Ctrl/AltGr and keyup', () => {
  chordContract(focus);
  assert.match(focus, /test "ISSUE-716 Alt\+Q and Alt\+M escape Find in both keydown forms"/);
  assert.throws(() => chordContract(focus.replace('or msg == WM_SYSKEYDOWN', '')));
  assert.throws(() => chordContract(focus.replace('or vk == 0x4D', '')));
  assert.throws(() => chordContract(focus.replace('and !ctrl', '')));
});

function recoveryContract(source) {
  const recover = decision(source, 'browserFocusReturnsToInput', ['pane_present', 'chat_owns', 'focus_drifted']);
  for (const chat of [false, true]) {
    for (const drift of [false, true]) assert.equal(recover(false, chat, drift), true, 'no pane must restore composer or console');
  }
  assert.equal(recover(true, true, true), true, 'null/frame/transcript focus must restore composer');
  assert.equal(recover(true, true, false), false, 'composer or pane focus keeps normal toggle');
  assert.equal(recover(true, false, false), false, 'console view keeps normal toggle');
  assert.equal(recover(true, false, true), false, 'console view does not take the Chat View repair path');
}

test('ISSUE-716 native recovery decision rejects old no-pane no-op and drift-to-pane behavior', () => {
  recoveryContract(focus);
  assert.match(focus, /test "ISSUE-716 no pane always restores input and drifted Chat View returns to the composer"/);
  assert.throws(() => recoveryContract(focus.replace('!pane_present or (chat_owns and focus_drifted)', 'false')));
  assert.throws(() => recoveryContract(focus.replace('!pane_present or (chat_owns and focus_drifted)', '!pane_present')));
  assert.throws(() => recoveryContract(focus.replace('!pane_present or (chat_owns and focus_drifted)', 'true')));
});

function hookContract(source) {
  assert.match(source, /const focus_chord = @import\("focus.zig"\).browserFocusChord\(wp, kb.vkCode, isCtrlDown\(\), isAltDown\(kb.flags\)\);/);
  assert.match(source, /ownsKeys\(app_state.g_chat_find_open, foregroundIsOurs\(\)\) and !find_modifier and !focus_chord/);
  const start = source.indexOf('if (focus_chord and foregroundIsOurs() and app_state.active_shell < app_state.shell_count)');
  assert.ok(start > source.indexOf('ownsKeys('));
  const block = source.slice(start, source.indexOf('\n        }', start));
  for (const required of ['claimBrowserFocusPress(true', 'g_sysmenu_pending = false', 'WM_APP_BROWSER_FOCUS_TOGGLE']) assert.ok(block.includes(required), required);
  assert.doesNotMatch(block.split('\n')[0], /browser_enabled/);
}

test('ISSUE-716 hook bypasses Find only for the shared focus chord, preserves latch and posts on the UI thread without a pane prerequisite', () => {
  hookContract(shortcuts);
  assert.throws(() => hookContract(shortcuts.replace('and !find_modifier and !focus_chord', 'and !find_modifier')));
  assert.throws(() => hookContract(shortcuts.replace('focus_chord and foregroundIsOurs() and app_state.active_shell < app_state.shell_count)', 'focus_chord and foregroundIsOurs() and app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_enabled)')));
  assert.match(body(find, 'windowKey'), /if \(@import\("focus.zig"\).browserFocusChord\(msg, vk, ctrl, alt\)\) return false;/);
  const toggle = main.slice(main.indexOf('        WM_APP_BROWSER_FOCUS_TOGGLE => {'), main.indexOf('        WM_APP_QUIT_ALL => {'));
  assert.ok(toggle.indexOf('chat_find_ui.zig").close(false)') < toggle.indexOf('browserFocusReturnsToInput('));
  assert.match(toggle, /chatFocusDrifted\(\) and !activeBrowserHasForegroundFocus\(\) and !webView2HasInputFocus\(\)/);
  assert.match(toggle, /browserFocusReturnsToInput\(pane_present, chatViewOwnsInput\(\), focus_drifted\)/);
  assert.match(toggle, /cancelPendingNativeBrowserFocus\(\);\s*app_state.g_chat_browser_handoff_until = 0;\s*app_state.g_browser_focus_mode = false;\s*app_state.g_shell_focused = true;\s*focusActiveShell\(\);\s*return 0;/);
  for (const required of ['if (webView2HasInputFocus() or app_state.g_browser_focus_mode)', 'requestWebView2Focus();', 'toggle_pending cancel', 'toggle_back pane_to_shell', 'requestNativeBrowserFocus();']) assert.ok(toggle.includes(required), required);
  const harness = read('tools/chat-view-gaps.test.js');
  assert.ok(harness.includes('.replaceAll(\'@import("focus.zig").browserFocusChord\', \'browserFocusChord\')'));
  assert.ok(harness.includes("${fileBody('focus.zig', 'browserFocusChord')}"));
});

test('ISSUE-716 startup retains cached and restored composer focus, and activation repairs null/frame focus', () => {
  assert.match(read('src/launch_cache.zig'), /if \(s.chat\) \{[\s\S]*?@import\("chat_composer.zig"\).openChatView\(\);/);
  assert.match(main, /launch_cache.bindRestoredChat\(\);\s*@import\("chat_composer.zig"\).applySessionView\(\);/);
  assert.match(body(composer, 'openChatView'), /SetForegroundWindow\(app_state.g_main_hwnd\);\s*_ = SetFocus\(app_state.g_chat_composer_hwnd\);/);
  assert.match(body(focus, 'focusGuardActivationTarget'), /chatComposerFocusAllowed\(\) and \(focused == null or focused == app_state.g_main_hwnd\)/);
  assert.match(main, /if \(focusGuardComposerRepairAllowed\(\)\) \{\s*_ = SetFocus\(app_state.g_chat_composer_hwnd\);\s*altqLog\("composer_focus site=activate/);
  assert.match(body(composer, 'chatFocusDrifted'), /f == null or f == app_state.g_main_hwnd or f == app_state.g_chat_transcript_hwnd/);
});

function journeyContract(source) {
  const steps = [
    "Press @(0x12, 0x43)", "'one saved Chat View session without a browser pane'", "Wait-ChatFocus 'Edit' 'chat-enabled'",
    'Restart-ChatView 1', "Assert-ChatTyping 'abc' 'restart-typing'", "Press @(0x11, 0x46)",
    "Wait-ChatFocus 'ZigShellChatTranscript' 'find-open'", "Press @(0x12, 0x51)", "Assert-ChatTyping 'abc' 'find-alt-q-typing'",
    "Press @(0x1B)", "ClassNameProperty, 'ZigShellChatTranscript'", '$transcript.Current.ProcessId -ne $process.Id',
    'GetAncestor($handle, 2) -ne $script:window', 'GetClientRect($handle, [ref]$rect)',
    'Doctor\n            Assert-Foreground', 'ClickClient($handle,', "Snapshot 'transcript-clicked'", "Press @(0x12, 0x51)",
    "Assert-ChatTyping 'abc' 'transcript-alt-q-typing'", "Wait-ChatFocus 'ZigShellChatTranscript' 'alias-find-open'",
    "Press @(0x12, 0x4D)", "Assert-ChatTyping 'abc' 'find-alt-m-typing'", "$result.checks += @{ name = 'chat-focus'",
  ];
  let from = 0;
  for (const step of steps) {
    const at = source.indexOf(step, from);
    assert.ok(at >= from, `missing or misordered ${step}`);
    from = at + step.length;
  }
  assert.match(source, /PSObject.Properties\['bon'\] -and \$state.tabs\[0\].bon/);
  assert.doesNotMatch(source, /PostMessage|SendMessage|Set-Content|WriteAll|Copy-Item|SetEnvironmentVariable|Start-Sleep|Thread.Sleep|\.SetFocus\(|\.SetValue\(/);
}

function typingContract(source) {
  const readText = '[VerifyNative]::EditText($handle)';
  const steps = [
    "Wait-ChatFocus 'Edit' ($Step + '-focused')",
    '$composer = [System.Windows.Automation.AutomationElement]::FocusedElement',
    '$handle = [IntPtr]$composer.Current.NativeWindowHandle',
    "if ($composer.Current.ProcessId -ne $process.Id -or [VerifyNative]::Class($handle) -cne 'Edit' -or",
    "[VerifyNative]::GetAncestor($handle, 2) -ne $script:window) { throw 'Expected the owned composer Edit before reading text' }",
    `if (${readText} -cne '') { throw 'Expected an empty composer before typing proof' }`,
    'Type-Text $Text',
    `Wait-Until { ${readText} -ceq $Text } ("WM_GETTEXT typing landed: $Step")`,
    "Wait-ChatFocus 'Edit' $Step",
    "if ([System.Windows.Automation.AutomationElement]::FocusedElement.Current.NativeWindowHandle -ne $handle) { throw 'Typing focus left the original composer Edit' }",
    `Save-Json @{ WM_GETTEXT = ${readText}; handle = $composer.Current.NativeWindowHandle; pid = $composer.Current.ProcessId } ($Step + '.text.json')`,
  ];
  let from = 0;
  for (const step of steps) {
    const at = source.indexOf(step, from);
    assert.ok(at >= from, `missing or misordered ${step}`);
    from = at + step.length;
  }
  assert.doesNotMatch(source, /TextPattern|ValuePattern|GetCurrentPattern|\.Current\.Value|\.value\.json|\.Trim/);
}

function nativeTextContract(source) {
  assert.match(source, /DllImport\("user32.dll", CharSet=CharSet.Unicode, SetLastError=true\)\] static extern IntPtr SendMessageTimeout\(IntPtr hwnd, uint message, UIntPtr count, StringBuilder text, uint flags, uint timeout, out UIntPtr result\);/);
  assert.match(source, /DllImport\("user32.dll", EntryPoint="SendMessageTimeoutW", CharSet=CharSet.Unicode, SetLastError=true\)\] static extern IntPtr SendMessageTimeout\(IntPtr hwnd, uint message, UIntPtr count, IntPtr text, uint flags, uint timeout, out UIntPtr result\);/);
  const start = source.indexOf('public static string EditText(');
  const reader = source.slice(start, source.indexOf('public static string Title(', start));
  const steps = [
    'if (Class(hwnd) != "Edit") throw',
    'if (SendMessageTimeout(hwnd, 0x000E, UIntPtr.Zero, IntPtr.Zero, 2, 1000, out length) == IntPtr.Zero) throw',
    'StringBuilder text = new StringBuilder(checked((int)length.ToUInt64() + 2));',
    'if (SendMessageTimeout(hwnd, 0x000D, new UIntPtr((uint)text.Capacity), text, 2, 1000, out length) == IntPtr.Zero) throw',
    'if (length.ToUInt64() >= (ulong)(text.Capacity - 1)) throw',
    'return text.ToString();',
  ];
  let from = 0;
  for (const step of steps) {
    const at = reader.indexOf(step, from);
    assert.ok(at >= from, `missing or misordered ${step}`);
    from = at + step.length;
  }
  assert.doesNotMatch(reader, /GetWindowText|SetFocus|PostMessage|\.Trim/);
}

test('ISSUE-716 composer uses bounded Unicode WM_GETTEXTLENGTH then WM_GETTEXT with truncation protection', () => {
  nativeTextContract(driver);
  for (const [before, after] of [
    ['Class(hwnd) != "Edit"', 'false'],
    ['hwnd, 0x000E,', 'hwnd, 0x000D,'],
    ['EntryPoint="SendMessageTimeoutW"', 'EntryPoint="SendMessageTimeoutA"'],
    ['CharSet=CharSet.Unicode', 'CharSet=CharSet.Ansi'],
    ['IntPtr.Zero, 2, 1000, out length', 'IntPtr.Zero, 8, 1000, out length'],
    ['checked((int)length.ToUInt64() + 2)', '512'],
    ['hwnd, 0x000D,', 'hwnd, 0x000E,'],
    ['text, 2, 1000, out length', 'text, 8, 1000, out length'],
    ['length.ToUInt64() >= (ulong)(text.Capacity - 1)', 'false'],
    ['return text.ToString();', 'return text.ToString().Trim();'],
  ]) {
    assert.ok(driver.includes(before), before);
    assert.throws(() => nativeTextContract(driver.replaceAll(before, after)), before);
  }
});

test('ISSUE-716 Windows journey uses real keys, owned mouse input, shared normal restart and independent focused-element/WM_GETTEXT proof', () => {
  journeyContract(recipe);
  for (const step of ['Restart-ChatView 1', "Wait-ChatFocus 'ZigShellChatTranscript' 'find-open'", "Assert-ChatTyping 'abc' 'restart-typing'", 'GetAncestor($handle, 2) -ne $script:window', 'Doctor\n            Assert-Foreground']) {
    assert.throws(() => journeyContract(recipe.replace(step, '')));
  }
  const restart = driver.slice(driver.indexOf('function Restart-ChatView('), driver.indexOf('function Wait-ChatFocus('));
  for (const required of ['Doctor', '$process.CloseMainWindow()', '$process.WaitForExit(10000)', '$job.Stop()', '$stopped.ActiveProcesses -ne 0', '$script:process = $job.Start($Exe, $scratch,', '@($state.shells).Count -eq $ShellCount', '[VerifyNative]::BringToForeground($script:window)']) assert.ok(restart.includes(required), required);
  assert.match(driver, /'chat-view-everywhere' \{[\s\S]*?Restart-ChatView 3/);
  const waits = driver.slice(driver.indexOf('function Wait-ChatFocus('), driver.indexOf('\ntry {\n', driver.indexOf('function Wait-ChatFocus(')));
  for (const required of ['::FocusedElement', '$focused.Current.ProcessId -eq $process.Id', '$focused.Current.ClassName -ceq $Class', 'GetAncestor([IntPtr]$focused.Current.NativeWindowHandle, 2) -eq $script:window', 'Snapshot $Step']) assert.ok(waits.includes(required), required);
  const typing = waits.slice(waits.indexOf('function Assert-ChatTyping('));
  typingContract(typing);
  for (const [before, after] of [
    ['$handle = [IntPtr]$composer.Current.NativeWindowHandle', '$handle = $script:window'],
    ['$composer.Current.ProcessId -ne $process.Id', '$false'],
    ["[VerifyNative]::Class($handle) -cne 'Edit'", '$false'],
    ['[VerifyNative]::GetAncestor($handle, 2) -ne $script:window', '$false'],
    ['[VerifyNative]::EditText($handle)', '$composer.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern)'],
    ['[VerifyNative]::EditText($handle)', '[VerifyNative]::EditText($handle).Trim()'],
    ["-cne ''", "-cne 'abc'"],
    ['-ceq $Text', '-eq $Text'],
    ["Wait-ChatFocus 'Edit' $Step", ''],
    ['FocusedElement.Current.NativeWindowHandle -ne $handle', '$false'],
    ['WM_GETTEXT =', 'textPattern ='],
    ["'.text.json'", "'.value.json'"],
  ]) assert.throws(() => typingContract(typing.replace(before, after)));
  const press = driver.slice(driver.indexOf('function Press('), driver.indexOf('function Click-WorkspacePill('));
  assert.match(press, /function Press\([^\n]*\) \{\s*Doctor/);
  assert.match(press, /function Type-Text\([^\n]*\) \{\s*Doctor/);
  assert.ok(driver.includes("Save-Json $result 'result.json'"));
  assert.ok(recipe.includes("Snapshot 'action'"));
  assert.ok(recipe.includes("Snapshot 'after'"));
});

test('ISSUE-716 feature registration, PR journey, public docs and user changelog are complete', () => {
  assert.match(driver, /ValidateSet\([^\n]*'chat-focus'/);
  assert.match(workflow, /node tools\/verify-features.cjs \$env:FEATURE/);
  assert.ok(featureMatrix(workflow).available.includes('chat-focus'));
  assert.ok(featureMatrix(workflow).full.includes('chat-focus'));
  assert.ok(workflow.includes('- tools/chat-focus.test.js'));
  assert.match(workflow, /run: node --test [^\n]*tools\/chat-focus.test.js/);
  const map = read(skill + 'features/chat-focus.md');
  assert.deepEqual(map.match(/^## .+$/gm), ['## Sub-features', '## How to get to it (user POV)', '## Driving it with control.ps1', '## Gotchas']);
  for (const required of ['v0.28.848', 'WM_GETTEXTLENGTH (0x000E)', 'WM_GETTEXT (0x000D)', 'without trimming or normalizing', 'WM_GETTEXT JSON key', 'ControlType.Pane', 'same owned Edit', 'restart-typing.text.json', 'Doctor', 'result.json', 'Empty transcript clicks']) assert.ok(map.includes(required), required);
  assert.ok(read(skill + 'features/README.md').includes('](chat-focus.md)'));
  assert.ok(read(skill + 'SKILL.md').includes('](features/chat-focus.md)'));
  assert.ok(read(skill + 'SKILL.md').includes('WM_GETTEXTLENGTH/WM_GETTEXT'));
  assert.ok(read(skill + 'coverage.md').includes('| IGSH-716 |'));
  const changelog = readChangelogEntry('IGSH-716').trim();
  assert.equal(changelog.split('\n').length, 1);
  assert.match(changelog, /Alt\+Q.*Find.*no browser pane/);
  assert.doesNotMatch(changelog, /\.zig|WM_APP|ISSUE-|JSON/);
});
