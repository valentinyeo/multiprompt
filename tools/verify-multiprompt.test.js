const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const skill = '.claude/skills/verify-multiprompt/';
const control = read(skill + 'control.ps1');
const workflow = read('.github/workflows/verify.yml');
const cli = read('tools/vps-multiprompt-browser.sh');
const bridge = read('src/browser_bridge.zig');
const journey = control.slice(control.indexOf("        'session-open' {"), control.indexOf("        'inbox' {"));
const transport = control.slice(control.indexOf('function Invoke-Zsb('), control.indexOf('function Select-Theme('));

function allowsSessionOpen(text) {
  assert.match(text, /\$env:FEATURE -notin @\([^\n)]*'session-open'[^\n)]*\)/);
}

function assertsSavedState(text) {
  for (const pattern of [
    /\$state = Read-Session/,
    /\$tabs\.Count -ne 1 -or @\(\$state\.tabs\)\.Count -ne @\(\$baseline\.tabs\)\.Count \+ 1/,
    /\$tab\.kind -cne 'tmux'/,
    /\$tab\.name -cne 'Verify 1'/,
    /\$tab\.group_id -ne \$group\.id/,
    /\$tabWorkspace -ne \$workspaceBefore/,
    /\$state\.active_workspace -ne \$workspaceBefore/,
    /\$state\.active_tab -ne \$activeTabBefore/,
    /\$repeated\.existing -ne \$true/,
    /\$repeated\.tab -ne \$created\.tab/,
    /\$repeated\.workspace -cne \$workspaceName/,
    /GetForegroundWindow\(\) -ne \$foregroundBefore/,
    /Title\(\$foregroundBefore\) -cne \$foregroundTitleBefore/,
    /Title\(\$script:window\) -cne \$titleBefore/,
  ]) assert.match(text, pattern);
  assert.equal((text.match(/Wait-Until \$assertSaved /g) || []).length, 3);
}

test('G1: workflow and harness allow session-open and Windows parses the driver', () => {
  allowsSessionOpen(workflow);
  assert.match(control, /ValidateSet\([^\n)]*'session-open'/);
  assert.match(workflow, /Language\.Parser\]::ParseFile/);
  assert.match(workflow, /run: node --test tools\/verify-multiprompt\.test\.js/);
  assert.match(workflow, /paths:[\s\S]*?- tools\/verify-multiprompt\.test\.js/);
  assert.throws(() => allowsSessionOpen(workflow.replace(", 'session-open'", '')));
});

function assertsGroupSetup(text) {
  const steps = [
    '$initialGroupIds = @()',
    "Palette 'move to group'", "'Enter: Move to Group submenu'", "Type-Text 'new group'",
    "'Enter: New group'", 'Wait-Until {', '$state = Read-Session',
    '@($state.groups).Count -ne $groupCount + 1',
    '$newGroups = @($state.groups | Where-Object { $_.id -notin $initialGroupIds })',
    '$newGroups.Count -eq 1', '[string]::IsNullOrWhiteSpace($newGroups[0].name)',
    '$state.tabs[$initial.active_tab].group_id -eq $newGroups[0].id',
    "'user-created group name and original tab membership saved'", '$baseline = Read-Session',
    '$group = @($baseline.groups | Where-Object { $_.id -notin $initialGroupIds })[0]',
    '$result.groupSetup = @{ name = $group.name; id = $group.id; customNameExercised = $false;',
  ];
  let offset = -1;
  for (const step of steps) {
    const next = text.indexOf(step, offset + 1);
    assert.ok(next > offset, `missing or misordered ${step}`);
    offset = next;
  }
  assert.doesNotMatch(text, /Type-Text 'Verify group'|Ctrl\+A: replace group name|Enter: save group name|\$group\s*=.*'Group 1'/);
}

test('G2: keyboard palette creates a group and waits for its real saved name and membership', () => {
  assert.ok(journey.length > 0);
  assertsGroupSetup(journey);
  assert.throws(() => assertsGroupSetup(journey.replace('$newGroups.Count -eq 1', '$true')));
  assert.throws(() => assertsGroupSetup(journey.replace('$state.tabs[$initial.active_tab].group_id -eq $newGroups[0].id', '$true')));
  assert.throws(() => assertsGroupSetup(journey.replace("            $baseline = Read-Session", "            Type-Text 'Verify group'\n            $baseline = Read-Session")));
  assert.match(journey, /\$activeBefore\.group_id -ne \$group\.id/);
  const palette = read('src/command_palette.zig');
  assert.match(palette, /groupmove_labels[^\n]*"move to group"/);
  assert.match(palette, /labelsMatchQuery\(&\.\{"new group"\}/);
  assert.match(read('src/main.zig'), /target == SEARCH_GROUPMOVE_NEW_OFFSET[\s\S]*?createDefaultGroup\(\)[\s\S]*?startGroupRename\(gidx\)/);
});

test('G2: offline startup uses the actual ephemeral app-owned loopback listener', () => {
  assert.match(read('src/account_desktop.zig'), /GetEnvironmentVariableA\("MULTIPROMPT_NO_LOGIN"[\s\S]*?g_account_bypass = true/);
  const main = read('src/main.zig');
  const startupListener = /\.links => \{\s*launch_cache\.step\(\.links\);\s*if \(std\.Thread\.spawn\(\.\{\}, notifyListenerThread, \.\{\}\)\) \|notify_thread\| \{[^{}]*\} else \|_\| \{[^{}]*\}\s*startTunnelInboundListener\(\);\s*if \(!@import\("session\.zig"\)\.prepareStartupRestore\(\)\)/;
  assert.match(main, startupListener);
  assert.doesNotMatch(main.replace('startTunnelInboundListener();', ''), startupListener);
  assert.match(main, /startup_phase = @enumFromInt\(@intFromEnum\(startup_phase\) \+ 1\);/);
  assert.match(read('src/launch_plan.zig'), /pub const Deferred = enum \{[^}]*\blinks,\s*tabs,/);
  assert.match(read('src/account_desktop.zig'), /pub fn accountBootstrap\(hwnd: HANDLE\) bool \{\s*if \(app_state\.g_account_bypass\) return true;/);
  assert.match(read('src/session.zig'), /pub fn prepareStartupRestore\(\) bool \{[^}]*std\.Thread\.spawn\(\.\{\}, startupRestoreWorker,/);
  assert.match(read('src/session.zig'), /fn startupRestoreWorker\([^\n]*\) void \{\s*_ = @import\("console\.zig"\)\.resolveSshPath\(false\);/);
  assert.match(read('src/main.zig'), /listener_status\.load\(\.acquire\)[\s\S]*?\.pending => return false/);
  const links = main.slice(main.indexOf('        .links => {'), main.indexOf('        .tabs => {'));
  const listenerBeforeRestore = /startTunnelInboundListener\(\);\s*if \(!@import\("session\.zig"\)\.prepareStartupRestore\(\)\)/;
  assert.match(links, listenerBeforeRestore);
  assert.doesNotMatch(links.replace('startTunnelInboundListener();', ''), listenerBeforeRestore);
  const account = read('src/account_desktop.zig');
  const worker = account.slice(account.indexOf('fn layoutSyncWorker('), account.indexOf('fn accountPrepareRestore('));
  const discoveryBeforeResume = /resolveSshPath\(false\);[\s\S]*?accountResumeJob\(\.startup\)/;
  assert.match(worker, discoveryBeforeResume);
  assert.doesNotMatch(worker.replace('resolveSshPath(false)', 'unresolvedSshPath()'), discoveryBeforeResume);
  assert.match(bridge, /pub fn startTunnelInboundListener\(\)[\s\S]*?sin_port = htons\(0\)[\s\S]*?sin_addr = 0x0100007F/);
  assert.match(journey, /tunnel-inbound listening port=\(\\d\+\) err=0/);
  assert.match(journey, /Get-NetTCPConnection -State Listen -LocalAddress '127\.0\.0\.1' -LocalPort \$script:zsbPort/);
  assert.match(journey, /\$_.OwningProcess -eq \$process.Id/);
  assert.match(bridge, /"workspace-list"\) or std\.mem\.eql\(u8, argv\[0\], "session-open"\)\) \{\s*sendZsbWorkspaceResponse/);
  assert.match(bridge, /zsbSessionOpen\(args, out, @import\("console.zig"\)\.spawnBackgroundTmuxSession, saveSession\)/);
});

test('G2: transport encodes the CLI bytes with bounded TCP and no external harness process', () => {
  assert.ok(cli.includes('sess="workspace"'));
  assert.ok(cli.includes('payload = base64.b64encode(("\\x1f".join(args) + "\\x1f").encode()).decode()'));
  assert.ok(cli.includes('sock.sendall(f"ZSB:{session}:{payload}\\n".encode())'));
  assert.ok(transport.includes('[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($Arguments -join [char]0x1F) + [char]0x1F))'));
  assert.ok(transport.includes('[Text.Encoding]::UTF8.GetBytes("ZSB:workspace:${payload}`n")'));
  assert.match(transport, /Doctor\s+Assert-Foreground\s+Record/);
  assert.match(transport, /ConnectAsync\('127\.0\.0\.1', \$Port\)/);
  assert.match(transport, /connecting\.Wait\(5000\)/);
  const suppressConnectResult = /\[void\]\$connecting\.GetAwaiter\(\)\.GetResult\(\)/;
  assert.match(transport, suppressConnectResult);
  assert.doesNotMatch(transport.replace('[void]$connecting', '$connecting'), suppressConnectResult);
  assert.match(transport, /WriteTimeout = 5000/);
  assert.match(transport, /90000 - \$timer.ElapsedMilliseconds/);
  assert.match(transport, /16 \* 1024 \* 1024/);
  assert.match(transport, /\$response\.ok -ne \$true/);
  assert.match(transport, /finally \{ \$reply.Dispose\(\); \$client.Dispose\(\) \}/);
  assert.doesNotMatch(transport, /Start-Process|Invoke-Expression|PostMessage/);
});

test('docked native browser handoff retains identity, visibility and strict foreign-input guards', () => {
  const guard = control.slice(control.indexOf('function Assert-Foreground {'), control.indexOf('function Press('));
  const handoff = control.slice(control.indexOf('function Focus-BrowserPaneOwner('), control.indexOf('function Assert-ConnectedPaneStaysVisible('));
  const refusesForeign = /function Assert-Foreground \{\s*if \(\[VerifyNative\]::GetAncestor\(\[VerifyNative\]::GetForegroundWindow\(\), 2\) -ne \$script:window\) \{ throw 'Refusing input: owned app is not foreground' \}\s*\}/;
  const dockedOwner = /\$pane.browser_state -eq 'connected' -and\s*\$pane.browser_connection_id -eq \$ConnectionId -and \[VerifyNative\]::PaneVisible\(\$script:window\)/;
  const waitsBeforeActivation = /Wait-Until \{[\s\S]*\} "browser-pane-stuck \$\{Step\}: docked pane ready for main-window activation" 25\s*Doctor\s*Record[^\n]*\n\s*\[void\]\[VerifyNative\]::SetForegroundWindow\(\$script:window\)/;
  const verifiesForeground = /Wait-Until \{ \[VerifyNative\]::GetAncestor\(\[VerifyNative\]::GetForegroundWindow\(\), 2\) -eq \$script:window \} "browser-pane-stuck \$\{Step\}: main window is foreground" 5/;
  for (const pattern of [dockedOwner, waitsBeforeActivation, verifiesForeground]) {
    assert.match(handoff, pattern);
    assert.throws(() => assert.match(handoff.replace(pattern, ''), pattern));
  }
  assert.match(handoff, /Focus-BrowserPaneOwner \$Step \$pane.browser_connection_id/);
  assert.match(guard, refusesForeign);
  assert.throws(() => assert.match(guard.replace(refusesForeign, ''), refusesForeign));
});

test('G2: discovery, creation and repeat use saved names and identical arguments', () => {
  assert.match(journey, /Invoke-Zsb @\('workspace-list'\)/);
  assert.match(journey, /\$_.id -eq \$workspaceBefore -and \$_.name -ceq \$workspaceName -and \$_.active -eq \$true/);
  assert.match(journey, /\$_.id -eq \$group.id -and \$_.name -ceq \$group.name/);
  assert.match(journey, /\$hostName = \$listed.hosts\[0\]/);
  assert.match(journey, /@\('session-open', '--workspace', \$workspaceName, '--group', \$group.name, '--host', \$hostName, '--tmux', 'verify-1', '--name', 'Verify 1'\)/);
  assert.match(journey, /\$created = Invoke-Zsb \$openArgs/);
  assert.match(journey, /\$created.created -ne \$true -or \$created.tab -le 0/);
  assert.match(journey, /\$repeated = Invoke-Zsb \$openArgs/);
  assertsSavedState(journey);
  assert.throws(() => assertsSavedState(journey.replace('$state.active_tab -ne $activeTabBefore', '$false')));
  assert.throws(() => assertsSavedState(journey.replace('$repeated.existing -ne $true', '$false')));
  assert.throws(() => assertsSavedState(journey.replace('$tab.group_id -ne $group.id', '$false')));
});

test('G2: optional save fields and failed SSH preservation match app persistence', () => {
  assert.match(journey, /PSObject.Properties\['tmux_session'\]/);
  assert.match(journey, /\$tabWorkspace = 0\s+if \(\$tab.PSObject.Properties\['workspace'\]\)/);
  assert.match(read('src/session.zig'), /if \(app_state.shells\[i\]\.workspace != 0\)/);
  assert.match(journey, /sshBoundary = @\{ verified = \$false/);
  assert.match(journey, /ssh-reconnect disconnect id=' \+ \$created.tab/);
  assert.match(journey, /known=true/);
  assert.match(journey, /\$failure.Groups\[2\].Value -in @\(0, 259\)/);
  assert.match(journey, /'observed failed SSH attach for the created tab' 60/);
  assert.match(journey, /\$result.sshBoundary.observed = \$script:sshFailure/);
  assert.match(journey, /\$result.sshBoundary.tabRemoved = \$false/);
  assert.match(read('src/console.zig'), /markSshTabDisconnected: preserving SSH\/tmux tab for automatic reconnect/);
});

test('G2: evidence is retained without seeding app state or bypassing cleanup', () => {
  for (const shot of ['before', 'action', 'after']) assert.ok(journey.includes(`Snapshot '${shot}'`));
  for (const name of ['session-before', 'session-created', 'session-repeated', 'session-after']) assert.ok(journey.includes(`'${name}.json'`));
  assert.match(transport, /WriteAllBytes[\s\S]*?\.request.bin/);
  assert.match(transport, /WriteAllText[\s\S]*?\.reply.json/);
  assert.doesNotMatch(journey, /Set-Content|WriteAllText|WriteAllBytes|SetEnvironmentVariable|PostMessage/);
  assert.match(control, /function Press[^\n]*\n\s+Doctor\s+Wait-Until \{\s+\[void\]\[VerifyNative\]::SetForegroundWindow\(\$script:window\)\s+\[VerifyNative\]::GetAncestor\(\[VerifyNative\]::GetForegroundWindow\(\), 2\) -eq \$script:window\s+\} 'owned app foreground for keyboard input'\s+Assert-Foreground\s+Record \$Label\s+\[VerifyNative\]::Chord\(\$Keys\)/);
  assert.match(control, /function Type-Text[\s\S]*?Doctor\s+Assert-Foreground/);
  assert.match(control, /\$stopped = \$job.Stop\(\)/);
  assert.match(control, /Copy-Item \(Join-Path \$scratch '\*'\) \$data -Recurse -Force; break[\s\S]*?Remove-ScratchPath \$scratch/);
});

test('audit verification is isolated from unchanged desktop journeys and retains fixture evidence', () => {
  const auditJob = workflow.slice(workflow.indexOf('  chat-sync-audit:'), workflow.indexOf('  verify:'));
  assert.match(auditJob, /if: inputs\.feature == 'chat-sync-audit'/);
  assert.match(auditJob, /runs-on: ubuntu-latest/);
  assert.match(auditJob, /run: zig build chat-audit/);
  assert.match(auditJob, /set -o pipefail/);
  assert.match(auditJob, /python3 tools\/chat-sync-audit\.test\.py -v 2>&1 \| tee evidence\/fixtures\.log/);
  assert.match(auditJob, /git rev-parse HEAD > evidence\/revision\.txt/);
  assert.match(auditJob, /if: always\(\)/);
  assert.match(auditJob, /name: verify-chat-sync-audit/);
  assert.match(auditJob, /file zig-out\/bin\/chat-audit \| tee evidence\/renderer-file\.txt/);
  assert.match(auditJob, /uses: actions\/upload-artifact@[a-f0-9]{40}\r?\n        with:\r?\n          name: chat-audit-linux\r?\n          path: zig-out\/bin\/chat-audit\r?\n          retention-days: 30\r?\n          if-no-files-found: error/);
  for (const ending of ['\n', '\r\n']) {
    assert.match(workflow.replace(/\r?\n/g, ending), /  verify:\r?\n    if: inputs\.feature != 'chat-sync-audit'\r?\n    runs-on: windows-latest/);
  }
  assert.match(read(skill + 'features/README.md'), /\[Chat sync audit\]\(\.\.\/diagnostics\/chat-sync-audit.md\)/);
  assert.match(read(skill + 'diagnostics/chat-sync-audit.md'), /not a Windows desktop journey/);
  assert.equal(fs.existsSync(path.join(root, skill, 'features/chat-sync-audit.md')), false);
  assert.match(read(skill + 'SKILL.md'), /\[Chat sync audit\]\(diagnostics\/chat-sync-audit.md\)/);
});

test('maintained verification code contains no removable code comments', async () => {
  const { strip } = await import('./strip-comments.mjs');
  for (const [source, language] of [[control, 'powershell'], [workflow, 'yaml'], [read('tools/verify-multiprompt.test.js'), 'javascript'], [read('tools/verify-scratch.test.ps1'), 'powershell']]) {
    assert.equal(strip(source, language).commentLines, 0);
  }
});

test('G3: four-section feature map is indexed and workspace entry points link it', () => {
  const map = read(skill + 'features/session-open.md');
  assert.deepEqual([...map.matchAll(/^## (.+)$/gm)].map(match => match[1]), [
    'Sub-features', 'How to get to it (user POV)', 'Driving it with control.ps1', 'Gotchas',
  ]);
  assert.match(read(skill + 'features/README.md'), /\[Session open\]\(session-open.md\)/);
  const workspaces = read(skill + 'features/workspaces.md').split('## How to get to it (user POV)')[1].split('## Driving it')[0];
  assert.match(workspaces, /zsb workspace-list/);
  assert.match(workspaces, /zsb session-open --workspace/);
  assert.match(workspaces, /\[Session open\]\(session-open.md\)/);
  assert.match(map, /not a Windows journey result/);
});


test('chat table journey waits for the Chat View tab to be saved before recording its identity', () => {
  const table = control.slice(control.indexOf("        'chat-tables' {"), control.indexOf("        'sessions' {"));
  const ready = /Wait-Until \{ \$state = Read-Session; \$null -ne \$state -and @\(\$state\.tabs\)\.Count -gt 0 -and \$state\.active_tab -ge 0 -and \$state\.active_tab -lt @\(\$state\.tabs\)\.Count \} 'saved initial table tab'\s+\$tableTab = \(Read-Session\)\.active_tab/;
  assert.match(table, ready);
  const completion = /\$command \+= ' && echo table-ready>"' \+ \(Join-Path \$scratch 'table-ready\.txt'\) \+ '"'\s+Type-Text \$command\s+Press @\(0x0D\)/;
  assert.match(table, completion);
  assert.doesNotMatch(table.replace(' && echo table-ready', ' && echo wrong-marker'), completion);
  assert.match(table, /Press @\(0x12, 0x43\) 'Alt\+C: open formatted Chat View'\s+Wait-Until/);
  assert.doesNotMatch(table.replace('Wait-Until { $state = Read-Session;', 'Write-Output { $state = Read-Session;'), ready);
  assert.doesNotMatch(table.replace('$state.active_tab -lt @($state.tabs).Count', '$true'), ready);
});

test('IGSH-376 Chat View keeps desktop toggle evidence separate from native received-message proof', () => {
  const chat = control.slice(control.indexOf("        'chat-view' {"), control.indexOf("        'inbox' {"));
  assert.ok(chat.length > 0);
  assert.match(control, /ValidateSet\([^\n)]*'chat-view'/);
  assert.match(workflow, /\$env:FEATURE -notin @\([^\n)]*'chat-view'/);
  const chord = control.slice(control.indexOf('    public static void Chord('), control.indexOf('    public static void Text('));
  assert.match(chord, /Input\[\] inputs = new Input\[keys\.Length \* 2\]/);
  assert.match(chord, /inputs\[i\]\.data\.keyboard = new Keyboard \{ key = \(ushort\)keys\[i\] \}/);
  assert.match(chord, /inputs\[keys\.Length \+ i\]\.data\.keyboard = new Keyboard \{ key = \(ushort\)keys\[keys\.Length - i - 1\], flags = 2 \}/);
  assert.equal((chord.match(/SendInput\(/g) || []).length, 1);
  assert.doesNotMatch(chord, /\bKey\(/);
  assert.match(workflow, /git config --global core\.autocrlf false[\s\S]*?uses: actions\/checkout@/);
  assert.match(workflow, /MULTIPROMPT_CHAT_RENDER_PROOF: '1'/);
  assert.match(workflow, /zig build test-main --summary all/);
  assert.match(workflow, /if \(\$LASTEXITCODE -ne 0\) \{ throw 'Native desktop rendering tests failed' \}/);
  assert.match(workflow, /evidence\/chat-markdown-render\.png/);
  assert.equal((chat.match(/Press @\(0x12, 0x43\)/g) || []).length, 3);
  const debounce = Number(read('src/app_state.zig').match(/BROWSER_TOGGLE_DEBOUNCE_MS: u32 = (\d+)/)[1]);
  const waits = [...chat.matchAll(/AddMilliseconds\((\d+)\)/g)];
  assert.equal(waits.length, 2);
  for (const wait of waits) assert.ok(Number(wait[1]) > debounce);
  assert.equal((chat.match(/Wait-Until \{ \[DateTime\]::UtcNow -ge \$toggleReady \}/g) || []).length, 2);
  assert.match(chat, /ClassNameProperty, 'ZigShellChatTranscript'/);
  assert.match(chat, /-not \$_\.Current.IsOffscreen/);
  assert.match(chat, /\.cv -eq \$true/);
  assert.match(chat, /\.cv -eq \$false/);
  assert.match(chat, /\$after.active_tab -ne \$baseline.active_tab/);
  assert.match(chat, /liveDeliveryVerified = \$false/);
  for (const shot of ['action', 'closed', 'after']) assert.ok(chat.includes(`Snapshot '${shot}'`));
  for (const state of ['before', 'opened', 'closed', 'after']) assert.ok(chat.includes(`'session-${state}.json'`));
  assert.doesNotMatch(chat, /Set-Content|WriteAllText|WriteAllBytes|SetEnvironmentVariable|PostMessage/);
  const map = read(skill + 'features/chat-view.md');
  assert.deepEqual([...map.matchAll(/^## (.+)$/gm)].map(match => match[1]), [
    'Sub-features', 'How to get to it (user POV)', 'Driving it with control.ps1', 'Gotchas',
  ]);
  assert.match(read(skill + 'features/README.md'), /\[Chat View\]\(chat-view.md\)/);
  assert.match(map, /not a screenshot of live delivery/);
});

test('IGSH-376 Chat View persists baseline through real UI before requiring saved startup state', () => {
  const chat = control.slice(control.indexOf("        'chat-view' {"), control.indexOf("        'inbox' {"));
  const resetBeforeSavedBaseline = /Palette 'interface'[\s\S]*?Press @\(0x28\)[\s\S]*?Press @\(0x28\)[\s\S]*?Press @\(0x0D\) 'Enter: persist default UI size before Chat View'[\s\S]*?'saved initial tab before Chat View'[\s\S]*?\$baseline = Read-Session/;
  assert.match(chat, resetBeforeSavedBaseline);
  assert.doesNotMatch(chat.replace("'Enter: persist default UI size before Chat View'", "'No reset'"), resetBeforeSavedBaseline);
  assert.match(chat, /\$baseline\.ui_scale -ne 100/);
});

test('IGSH-376 browser journey retains upstream focus and scratch preparation contracts', () => {
  const open = control.slice(control.indexOf('function Open-BrowserPane('), control.indexOf('function Assert-ConnectedPaneStaysVisible('));
  const settledBeforeForeground = /\$pane = Assert-BrowserPane 'open' \$Step \$PreviousId\s+Focus-BrowserPaneOwner \$Step \$pane.browser_connection_id\s+return \$pane/;
  assert.match(open, settledBeforeForeground);
  assert.doesNotMatch(open.replace('Focus-BrowserPaneOwner $Step $pane.browser_connection_id', ''), settledBeforeForeground);
  const prepareBeforeCopy = /\$stopped = \$job.Stop\(\)[\s\S]*?Prepare-ScratchEvidence \$scratch[\s\S]*?Copy-Item \(Join-Path \$scratch '\*'\) \$data -Recurse -Force; break[\s\S]*?Remove-ScratchPath \$scratch/;
  assert.match(control, prepareBeforeCopy);
  assert.doesNotMatch(control.replace('Prepare-ScratchEvidence $scratch', ''), prepareBeforeCopy);
  assert.doesNotMatch(control, /robocopy/);
});

test('browser emulation map drives the real native CLI and extension only on GitHub Windows', () => {
  const driver = read(skill + 'browser-emulation.mjs');
  const map = read(skill + 'features/browser-emulation.md');
  assert.match(workflow, /FEATURE -notin @\([^\n)]*'browser-emulation'/);
  assert.match(workflow, /control\.ps1 -Feature browser-emulation/);
  assert.match(control, /browserJob\.Start\(\$node/);
  assert.match(control, /activeAfterStop = \$stopped\.ActiveProcesses/);
  assert.match(driver, /assert\.equal\(process\.env\.GITHUB_ACTIONS, 'true'/);
  assert.match(driver, /assert\.equal\(process\.platform, 'win32'/);
  assert.match(driver, /const exe = path\.resolve\('verify-bin\/zigshell-bridge\.exe'\)/);
  assert.match(driver, /--load-extension=\$\{extension\}/);
  assert.match(driver, /allowed_origins: \[.*chrome-extension:/);
  assert.match(driver, /exec\(exe, command/);
  assert.doesNotMatch(driver, /Target\.attachToTarget|Runtime\.evaluate|page\.emulate|page\.setViewport/);
  for (const args of ["['emulate', 'iphone']", "['emulate', 'pixel']", "['emulate', '360x740', '--mobile']", "['emulate', '800x600']", "['emulate', 'off']", "['click', '#next']", "['reload']"]) {
    assert.ok(driver.includes(args), args);
  }
  assert.match(driver, /requests\.some\(request => request\.url === '\/next' && \/iPhone\/\.test\(request\.userAgent\) && request\.mobileHint === '\?1' && request\.platformHint === '"iOS"'\)/);
  assert.ok(driver.includes("['click', '#menu-toggle']"));
  assert.match(driver, /addEventListener\("resize",\(\)=>\{window\.menuOpen=false;window\.resizeCount\+\+/);
  assert.match(driver, /assert\.equal\(menu\.open, true/);
  assert.match(driver, /assert\.equal\(menu\.resizeCount, menuBefore\.resizeCount/);
  assert.match(driver, /userAgentMobile:navigator\.userAgentData\.mobile/);
  assert.match(driver, /assert\.equal\(state\.userAgentMobile, true\)/);
  assert.match(driver, /assert\.equal\(state\.userAgentPlatform, platform\)/);
  assert.match(driver, /assert\.equal\(restored\.width, baseline\.width\)/);
  assert.match(driver, /assert\.equal\(offReloaded\.touch, baseline\.touch\)/);
  assert.match(driver, /cdp\('Browser\.close'\)/);
  assert.match(driver, /pre\{white-space:pre-wrap;overflow-wrap:anywhere\}/);
  assert.match(map, /F12 and browser-chrome DevTools keys remain out of scope/);
  assert.match(read(skill + 'features/README.md'), /\[Browser emulation\]\(browser-emulation\.md\)/);

});

function assertsWorkspaceFocusHandoff(text) {
  const start = text.indexOf('pub fn switchToWorkspace(');
  const end = text.indexOf('\npub fn copyBlueDotHookInstructions(', start);
  assert.ok(start >= 0 && end > start);
  const switching = text.slice(start, end);
  assert.match(switching, /if \(target\) \|idx\| \{\s*if \(app_state\.g_focus_user_action_tick != 0\) [^\n]*switchToShell\(idx\);\s*if \(!app_state\.g_restoring and !app_state\.g_account_applying and @import\("focus\.zig"\)\.foregroundIsOurs\(\)\) \{\s*app_state\.g_focus_authorized_hwnd = if \(app_state\.g_chat_active\) app_state\.g_chat_composer_hwnd else app_state\.shells\[idx\]\.hwnd;\s*app_state\.g_focus_authorized_until = GetTickCount64\(\) \+ 1500;\s*app_state\.g_focus_browser_shell_id = 0;\s*\}\s*focusActiveShell\(\);/);
  assert.doesNotMatch(switching, /g_focus_(?:user_action|input)_tick\s*=/);
}

test('IGSH-522: workspace return grants a bounded owned-input handoff, never background or pane authority', () => {
  const switching = read('src/workspaces.zig');
  assertsWorkspaceFocusHandoff(switching);
  for (const [before, after] of [
    ['!app_state.g_restoring and ', ''],
    ['!app_state.g_account_applying and ', ''],
    ['@import("focus.zig").foregroundIsOurs()', 'true'],
    ['app_state.g_chat_composer_hwnd else app_state.shells[idx].hwnd', 'app_state.shells[idx].browser_hwnd'],
    ['GetTickCount64() + 1500', 'GetTickCount64() + 60000'],
    ['app_state.g_focus_browser_shell_id = 0;', ''],
    [/        focusActiveShell\(\);\r?\n    } else \{/, '        app_state.g_focus_user_action_tick = GetTickCount64();\n        focusActiveShell();\n    } else {'],
  ]) {
    for (const newline of ['\n', '\r\n']) {
      const source = switching.replace(/\r?\n/g, newline);
      const broken = source.replace(before, after);
      assert.notEqual(broken, source);
      assert.throws(() => assertsWorkspaceFocusHandoff(broken));
    }
  }
  const focusJourney = control.slice(control.indexOf("        'workspace-focus' {"), control.indexOf("        'chat-view' {"));
  const returning = focusJourney.slice(focusJourney.indexOf("Press @(0x11, 0x4E) 'Ctrl+N:"));
  assert.ok(returning.includes("Type-Text 'workspace-focus-chat'"));
  assert.ok(returning.includes("$expectedText = 'before-workspace-focus-chat'"));
  assert.match(returning, /EditText\(\[IntPtr\]\$composerHandle\) -ceq \$expectedText/);
  assert.match(returning, /NativeWindowHandle -ne \$composerHandle/);
  assert.doesNotMatch(returning, /SetForegroundWindow|SetFocus|\.SetFocus\(|Click.*(?:composer|typing box)/i);
});

function assertsOptionalChatViewRead(source) {
  const surface = source.slice(source.indexOf('function Wait-WorkspaceSurface('), source.indexOf('function Wait-ConsoleText('));
  const expression = surface.match(/\[bool\]\(([^\n]+?)\) -ne \$Chat/);
  assert.ok(expression, 'Chat View must retain its expected-state comparison');
  assert.equal(expression[1], "$state.tabs[$Tab].PSObject.Properties['cv'] -and $state.tabs[$Tab].cv");
  const evaluate = new Function('tab', `return Boolean(${expression[1]
    .replace("$state.tabs[$Tab].PSObject.Properties['cv']", "Object.hasOwn(tab, 'cv')")
    .replace('$state.tabs[$Tab].cv', 'tab.cv')
    .replace(' -and ', ' && ')});`);
  for (const saved of [{}, { cv: false }, { cv: true }]) {
    const tab = new Proxy(saved, {
      get(target, key) {
        assert.ok(Object.hasOwn(target, key), `StrictMode read of missing ${key}`);
        return target[key];
      },
    });
    for (const expected of [false, true]) {
      assert.equal(evaluate(tab) !== expected, (saved.cv === true) !== expected);
    }
  }
}

test('IGSH-522: optional saved cv is false under StrictMode without weakening Chat View equality', () => {
  assert.match(read('src/session.zig'), /if \(app_state\.shells\[i\]\.chat_view_on and pos < json_buf\.len - 540\) \{\s*const cv = ",\\"cv\\":true";/);
  assert.match(read('src/app_state.zig'), /cv: bool = false/);
  assertsOptionalChatViewRead(control);
  for (const [before, after] of [
    ["$state.tabs[$Tab].PSObject.Properties['cv'] -and ", ''],
    [' -and $state.tabs[$Tab].cv', ''],
    [' -ne $Chat)', ' -ne $false)'],
  ]) {
    const broken = control.replace(before, after);
    assert.notEqual(broken, control);
    assert.throws(() => assertsOptionalChatViewRead(broken), assert.AssertionError);
  }
});

function assertsFocusJourneyReadiness(source) {
  const focus = source.slice(source.indexOf("        'workspace-focus' {"), source.indexOf("        'chat-view' {"));
  const pills = source.slice(source.indexOf('function Click-WorkspacePill('), source.indexOf('function Focus-Palette('));
  const palette = source.slice(source.indexOf('function Focus-Palette('), source.indexOf('function Wait-WorkspaceSurface('));
  const surface = source.slice(source.indexOf('function Wait-WorkspaceSurface('), source.indexOf('function Wait-ConsoleText('));
  const console = source.slice(source.indexOf('function Wait-ConsoleText('), source.indexOf('function Palette('));
  assert.match(focus, /if \(\$initial.hide_pills\) \{\s*Focus-Palette 'workspace switcher' 6213\s*Press @\(0x0D\) 'Enter: show workspace switcher'/);
  assert.ok(focus.indexOf("'workspace switcher shown and saved'") < focus.indexOf("Press @(0x11, 0x4E) 'Ctrl+N:"));
  assert.match(focus, /Snapshot 'pills-ready'/);
  assert.match(focus, /Focus-Palette 'per tab' 6345/);
  for (const text of [pills, focus]) {
    assert.match(text, /PSObject.Properties\['hide_pills'\] -and -not \$state.hide_pills/);
    for (const field of ['hide_sidebar', 'sidebar_collapsed']) {
      assert.ok(text.includes(`-not ($state.PSObject.Properties['${field}'] -and $state.${field})`));
    }
  }
  assert.match(pills, /\$state.single_window/);
  assert.ok(pills.includes("Where-Object { $_.PSObject.Properties['snoozed'] -and $_.snoozed }).Count -eq 0"));
  assert.ok(pills.includes("-not $state.PSObject.Properties['ui_scale'] -or $state.ui_scale -eq 100"));
  assert.ok(pills.indexOf('Wait-Until {') < pills.indexOf('[VerifyNative]::ClickClient'));
  assert.match(pills, /8 \+ \(\$Workspace \+ 1\) \* 29 \+ 12\), 17/);
  assert.match(palette, /\$start = \(Get-Content \$log -Raw\).Length/);
  assert.match(palette, /Substring\(\$start\)/);
  assert.match(palette, /GetFocusedWindow\(\$script:window\) -eq \$script:window/);
  assert.match(palette, /\$Query.Length/);
  assert.match(palette, /\$Target/);
  assert.equal((palette.match(/Wait-Until \{/g) || []).length, 2);
  for (const field of ['active_workspace', 'active_tab', 'kind', 'cv']) assert.ok(surface.includes(`$state.${field}`) || surface.includes(`].${field}`));
  assert.match(surface, /IsOffscreen/);
  assert.match(surface, /NativeWindowHandle -eq \$Composer/);
  assert.match(surface, /Class\(\$foreground\) -eq 'ConsoleWindowClass'/);
  assert.match(surface, /'ZigShell-' \+ \$state.tabs\[\$Tab\].shell_id/);
  assert.doesNotMatch(surface + console, /SetFocus|SetForegroundWindow|ClickClient|::Text\(|::Chord\(/);
  assert.match(console, /TextPattern\]::Pattern/);
  assert.match(console, /EndsWith\(\$Command, \[StringComparison\]::Ordinal\)/);
  for (const line of focus.split(/\r?\n/)) {
    if (/Press .*?(?:Ctrl\+N|Alt\+2|Alt\+Right|Alt\+Left|switch to shell)|^\s+Click-WorkspacePill /.test(line)) {
      const after = focus.slice(focus.indexOf(line) + line.length);
      assert.match(after, /^\r?\n\s+(?:Wait-Until \{|Wait-WorkspaceSurface )/);
    }
  }
  assert.equal((focus.match(/Wait-ConsoleText /g) || []).length, 4);
  assert.equal((focus.match(/Click-WorkspacePill /g) || []).length, 4);
  assert.equal((focus.match(/name = 'workspace-focus-/g) || []).length, 4);
}

test('IGSH-522: hidden pills are shown through the palette and every focus transition waits for real input readiness', () => {
  assertsFocusJourneyReadiness(control);
  for (const [before, after] of [
    ["Focus-Palette 'workspace switcher' 6213", "Palette 'workspace switcher'"],
    ["$state.PSObject.Properties['hide_pills'] -and -not $state.hide_pills", '$true'],
    ["Wait-WorkspaceSurface $second $secondTab $false", 'Start-Sleep -Milliseconds 250'],
    ["Wait-ConsoleText 'echo workspace-focus-shell-pill'", ''],
    ['$focused.Current.NativeWindowHandle -eq $Composer', '$true'],
  ]) {
    const broken = control.replaceAll(before, after);
    assert.notEqual(broken, control);
    assert.throws(() => assertsFocusJourneyReadiness(broken));
  }
  assert.match(read('src/app_state.zig'), /g_hide_pills: bool = true/);
  assert.match(read('src/sidebar.zig'), /g_hide_sidebar or app_state.g_hide_pills\) return null/);
  assert.match(read('src/command_palette.zig'), /defer \{[\s\S]*?\[palette\] ready chars=\{d\} count=\{d\} target=\{d\}/);
});

test('IGSH-556: Favorites groups journey uses real keys and requires independent saved IDs', () => {
  const favorites = control.slice(control.indexOf("        'favorites-groups' {"), control.indexOf("        'session-open' {"));
  function contract(driver, workflowText) {
    assert.match(driver, /ValidateSet\([^\n)]*'favorites-groups'/);
    assert.match(workflowText, /\$env:FEATURE -notin @\([^\n)]*'favorites-groups'/);
    assert.match(favorites, /Press @\(0x12, 0x53\)/);
    assert.match(favorites, /favorite -eq \$true/);
    assert.equal((favorites.match(/Palette 'move to group'/g) || []).length, 2);
    assert.equal((favorites.match(/Type-Text 'new group'/g) || []).length, 2);
    assert.match(favorites, /Press @\(0x12, 0x31\)/);
    assert.match(favorites, /\$newGroups\[0\]\.id -ne \$homeGroupId/);
    assert.match(favorites, /\$state.tabs\[\$tabIndex\].group_id -eq \$homeGroupId -and \$state.tabs\[\$tabIndex\].starred_group_id -eq \$newGroups\[0\].id/);
    assert.match(favorites, /Snapshot 'starred-grouped'/);
    assert.match(favorites, /Press @\(0x12, 0x32\)/);
    assert.match(favorites, /starred_group_id -eq \$favoritesGroupId/);
    assert.match(favorites, /group_id = \$homeGroupId; starred_group_id = \$favoritesGroupId/);
    assert.doesNotMatch(favorites, /Set-Content|WriteAllText|SendMessage|PostMessage|skip/i);
  }
  contract(control, workflow);
  assert.throws(() => contract(control.replace("'favorites-groups', ", ''), workflow));
  assert.throws(() => contract(control, workflow.replace("'favorites-groups', ", '')));
  assert.ok(control.indexOf('    Doctor\n') < control.indexOf("        'favorites-groups' {"));
  const map = read(skill + 'features/favorites-groups.md');
  for (const heading of ['Sub-features', 'How to get to it (user POV)', 'Driving it with control.ps1', 'Gotchas']) {
    assert.ok(map.includes(`## ${heading}`));
  }
  assert.match(read(skill + 'features/README.md'), /\[Favorites groups\]\(favorites-groups.md\)/);
  assert.match(read(skill + 'features/workspaces.md'), /\[Favorites groups\]\(favorites-groups.md\)/);
});

function assertsScratchRaceHandling(source) {
  const cleanup = source.slice(source.indexOf('function Test-VanishedScratchItem('), source.indexOf('function Wait-Until('));
  assert.match(cleanup, /if \(Test-Path -LiteralPath \$Path\) \{ return \$false \}/);
  for (const type of ['System.Management.Automation.ItemNotFoundException', 'IO.FileNotFoundException', 'IO.DirectoryNotFoundException']) {
    assert.ok(cleanup.includes(`-is [${type}]`));
  }
  assert.match(cleanup, /\$exception = \$exception.InnerException/);
  assert.match(cleanup, /catch \{\s*if \(-not \(Test-VanishedScratchItem \$_ \$entry.FullName\)\) \{ throw \}/);
  assert.match(cleanup, /AddSeconds\(20\)/);
  assert.match(cleanup, /Scratch cleanup left paths:[^\n]*\$leftovers -join/);
  assert.match(source, /Remove-ScratchPath \$scratch/);
}

test('ISSUE-559 cleanup tolerates only typed missing paths and reports remaining paths within a bound', () => {
  assertsScratchRaceHandling(control);
  for (const [before, after] of [
    ['if (Test-Path -LiteralPath $Path) { return $false }', ''],
    ['if (-not (Test-VanishedScratchItem $_ $entry.FullName)) { throw }', 'throw'],
    ['Scratch cleanup left paths:', 'Cleanup failed:'],
  ]) {
    const broken = control.replace(before, after);
    assert.notEqual(broken, control);
    assert.throws(() => assertsScratchRaceHandling(broken));
  }
});

test('ISSUE-559 real Windows cleanup rejects the old vanished-lockfile race and names locked leftovers', { skip: process.platform !== 'win32' }, () => {
  const { spawnSync } = require('node:child_process');
  const result = spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-File', path.join(__dirname, 'verify-scratch.test.ps1')], { encoding: 'utf8', timeout: 45000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /ISSUE-559 old cleanup rejected:/);
  assert.match(result.stdout, /ISSUE-559 production cleanup passed/);
});

test('ISSUE-559 setup waits for rendered browser readiness and retries only owned-frame activation', () => {
  const palette = control.slice(control.indexOf('function Focus-Palette('), control.indexOf('function Wait-WorkspaceSurface('));
  assert.equal((palette.match(/Press @\(0x11, 0x4B\)/g) || []).length, 1);
  assert.match(palette, /if \(\$trace -notmatch[^\n]*\) \{ return \$false \}\s*Doctor\s*Assert-Foreground\s*\[void\]\[VerifyNative\]::SetForegroundWindow\(\$script:window\)/);
  assert.match(palette, /'command palette initialized and owned frame focused' 20/);
  const setup = control.slice(control.indexOf("    if ($Feature -in @('browser-pane-stuck', 'pane-layout'))"), control.indexOf("    Record 'Launch complete;"));
  assert.match(setup, /ZigShell\/EdgeUserData/);
  assert.match(setup, /\$warmupJob.Start\(\$edge/);
  assert.match(setup, /MainWindowTitle -match '\^Multiprompt verification browser ready'/);
  assert.match(setup, /'isolated browser rendered setup page before the pane adoption deadline starts' 60/);
  assert.doesNotMatch(setup, /Assert-BrowserPane|PaneLayoutProof|Start-Sleep/);
  assert.match(control, /\$warmupStopped = \$warmupJob.Stop\(\)/);
  assert.match(workflow, /run: node --test tools\/verify-multiprompt.test.js/);
  assert.ok(workflow.includes('- tools/verify-scratch.test.ps1'));
});
