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
  assert.match(control, /Copy-Item \(Join-Path \$scratch '\*'\) \$data -Recurse -Force; break[\s\S]*?Remove-Item \$scratch -Recurse -Force/);
});

test('maintained verification code contains no removable code comments', async () => {
  const { strip } = await import('./strip-comments.mjs');
  for (const [source, language] of [[control, 'powershell'], [workflow, 'yaml'], [read('tools/verify-multiprompt.test.js'), 'javascript']]) {
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
  assert.match(table, /Press @\(0x12, 0x43\) 'Alt\+C: open formatted Chat View'\s+Wait-Until/);
  assert.doesNotMatch(table.replace('Wait-Until { $state = Read-Session;', 'Write-Output { $state = Read-Session;'), ready);
  assert.doesNotMatch(table.replace('$state.active_tab -lt @($state.tabs).Count', '$true'), ready);
});
