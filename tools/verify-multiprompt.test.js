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

function evaluateConcurrencyGroup(template, context) {
  return template.replace(/\$\{\{([\s\S]*?)\}\}/g, (_, expression) => {
    const source = expression.trim();
    const lexer = /\s*('(?:[^']|'')*'|(?:github|inputs)\.[a-z_]+|format|==|!=|&&|\|\||[(),])/gy;
    const tokens = [];
    while (lexer.lastIndex < source.length) {
      const token = lexer.exec(source);
      assert.ok(token, `unsupported concurrency expression: ${source}`);
      tokens.push(token[1]);
    }
    let position = 0;
    const take = token => tokens[position] === token && (++position > 0);
    const expect = token => assert.ok(take(token), `expected ${token}`);
    function primary() {
      const token = tokens[position++];
      if (token === '(') {
        const value = or();
        expect(')');
        return value;
      }
      if (token === 'format') {
        expect('(');
        const pattern = or();
        const args = [];
        while (take(',')) args.push(or());
        expect(')');
        return () => pattern().replace(/\{(\d+)\}/g, (_, index) => {
          assert.ok(args[index], `missing format argument ${index}`);
          return args[index]();
        });
      }
      assert.ok(token, 'missing concurrency operand');
      if (token.startsWith("'")) return () => token.slice(1, -1).replace(/''/g, "'");
      assert.match(token, /^(github\.(workflow|ref|event_name|run_attempt|sha)|inputs\.[a-z_]+)$/);
      const [object, key] = token.split('.');
      return () => context[object]?.[key] ?? '';
    }
    function equality() {
      let left = primary();
      for (;;) {
        const negate = take('!=');
        if (!negate && !take('==')) break;
        const previous = left, right = primary();
        left = () => (String(previous()).toLowerCase() === String(right()).toLowerCase()) !== negate;
      }
      return left;
    }
    function and() {
      let left = equality();
      while (take('&&')) {
        const previous = left, right = equality();
        left = () => previous() && right();
      }
      return left;
    }
    function or() {
      let left = and();
      while (take('||')) {
        const previous = left, right = and();
        left = () => previous() || right();
      }
      return left;
    }
    const evaluate = or();
    assert.equal(position, tokens.length, 'unconsumed concurrency tokens');
    return evaluate();
  });
}

test('concurrency evaluator respects precedence, short-circuiting, format and string literals', () => {
  const evaluate = expression => evaluateConcurrencyGroup('${{ ' + expression + ' }}', {});
  assert.equal(evaluate("'a' == 'A' && format('{0}-{1}', 'it''s', 'ok') || 'wrong'"), "it's-ok");
  assert.equal(evaluate("'kept' || '' && 'wrong'"), 'kept');
  assert.equal(evaluate("'1' != '2' && 'differs' || 'same'"), 'differs');
  assert.equal(evaluate("'1' != '1' && 'differs' || 'same'"), 'same');
  assert.equal(evaluate("'kept' || format('{0}')"), 'kept');
  assert.equal(evaluate("'' && format('{0}') || 'fallback'"), 'fallback');
  assert.throws(() => evaluate('unknown'), assert.AssertionError);
  assert.throws(() => evaluate("'a' 'b'"), assert.AssertionError);
});

test('release tags reuse master verification instead of starting another full Windows matrix', () => {
  const push = workflow.match(/^  push:\r?\n((?:    [^\n]*\r?\n)+)/m);
  assert.ok(push, 'master pushes still trigger full verification');
  assert.match(push[1], /^    branches: \[master, 'ceo\/IGSH-1072\*', ceo\/IGSH-1061-recovery, ceo\/IGSH-1033\]\r?$/m);
  assert.ok(workflow.includes(`github.event_name == 'push' && github.ref == 'refs/heads/ceo/IGSH-1061-recovery' && fromJSON(format('["{0}"]', 'browser-pane-stuck'))`), 'recovery branch runs only its failing browser journey');
  assert.doesNotMatch(push[1], /^    tags(?:-ignore)?:/m, 'release tags must not duplicate the tested master matrix');
});

test('concurrency isolates dispatch features and tags while preserving pull_request and push groups', () => {
  const concurrency = workflow.match(/^concurrency:\r?\n((?:[ \t]+[^\n]*\r?\n)+)/m);
  assert.ok(concurrency, 'workflow concurrency block exists');
  const group = concurrency[1].match(/^  group: (.+?)\r?$/m);
  assert.ok(group, 'workflow concurrency group exists');
  assert.match(concurrency[1], /^  cancel-in-progress: \$\{\{ github\.event_name == 'pull_request' \}\}\r?$/m, 'a running master verify finishes; only the pending run is replaced');
  assert.doesNotMatch(concurrency[1], /refs\/heads\/master/, 'a master push never cancels the master verify already running');
  assert.match(workflow, /^    strategy:\n      fail-fast: false\n      max-parallel: 6\n      matrix:\n/m, 'full journey matrix leaves Windows slots for release and PR checks');
  const context = (event, feature, tag = '', attempt = '1') => ({
    github: { workflow: 'Verify desktop', ref: 'refs/heads/master', event_name: event, run_attempt: attempt, sha: 'abc123' },
    inputs: { feature, tag },
  });
  const dispatch = (feature, tag) => evaluateConcurrencyGroup(group[1], context('workflow_dispatch', feature, tag));
  assert.notEqual(dispatch('chat-delivery'), dispatch('chat-sync-audit'), 'different dispatch features need different concurrency groups');
  assert.equal(dispatch('chat-delivery', 'v0.28.823'), dispatch('chat-delivery', 'v0.28.823'));
  assert.notEqual(dispatch('chat-delivery', 'v0.28.823'), dispatch('chat-delivery'));
  for (const event of ['pull_request', 'push']) {
    for (const inputs of [undefined, { feature: 'chat-delivery', tag: 'v0.28.823' }]) {
      const current = context(event);
      current.inputs = inputs;
      const gate = event === 'push' && inputs ? `-gate-${current.github.sha}` : '';
      assert.equal(evaluateConcurrencyGroup(group[1], current), `${current.github.workflow}-${current.github.ref}${gate}`);
    }
    const first = evaluateConcurrencyGroup(group[1], context(event));
    const rerun = evaluateConcurrencyGroup(group[1], context(event, undefined, '', '2'));
    assert.notEqual(rerun, first, `${event} reruns leave the group a new push cancels`);
  }
  const gateOne = context('push', 'relaunch-saved-sessions');
  const gateTwo = context('push', 'relaunch-saved-sessions');
  gateTwo.github.sha = 'def456';
  assert.notEqual(evaluateConcurrencyGroup(group[1], gateOne), evaluateConcurrencyGroup(group[1], gateTwo), 'the release gate run of each master commit has its own group and never queues behind another commit');
});

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
  assert.match(workflow, /run: node --test --test-concurrency=1 tools\/verify-multiprompt\.test\.js/);
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
  assert.match(bridge, /"workspace-list"\) or std\.mem\.eql\(u8, argv\[0\], "session-open"\) or std\.mem\.eql\(u8, argv\[0\], "session-status"\) or zsbIsTabVerb\(argv\[0\]\)\) \{\s*sendZsbWorkspaceResponse/);
  assert.match(bridge, /zsbSessionOpen\(args, out, @import\("console.zig"\)\.spawnBackgroundTmuxSession, saveSession\)/);
});

test('G2: transport encodes the CLI bytes with bounded TCP and no external harness process', () => {
  assert.ok(cli.includes('sess="workspace"'));
  assert.ok(cli.includes('payload = base64.b64encode(("\\x1f".join(args) + "\\x1f").encode()).decode()'));
  assert.ok(cli.includes('sock.sendall(f"AUTH:{token}:ZSB:{session}:{payload}\\n".encode())'));
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

function assertsOwnedInput(source) {
  const guard = source.slice(source.indexOf('function Assert-Foreground {'), source.indexOf('function Wait-Foreground {'));
  const wait = source.slice(source.indexOf('function Wait-Foreground {'), source.indexOf('function Press('));
  const press = source.slice(source.indexOf('function Press('), source.indexOf('function Type-Text('));
  const type = source.slice(source.indexOf('function Type-Text('), source.indexOf('function Click-WorkspacePill('));
  for (const pattern of [
    /for \(\$attempt = 0; \$attempt -lt 5; \$attempt\+\+\)/,
    /\$foreground = \[VerifyNative\]::GetForegroundWindow\(\)/,
    /\$root = \[VerifyNative\]::GetAncestor\(\$foreground, 2\)/,
    /\$rootOwner = \[VerifyNative\]::GetAncestor\(\$foreground, 3\)/,
    /\[uint32\]\$foregroundOwner = 0/,
    /GetWindowThreadProcessId\(\$rootOwner, \[ref\]\$foregroundOwner\)/,
    /if \(\$foreground -ne \[IntPtr\]::Zero -and \$root -ne \[IntPtr\]::Zero -and \$rootOwner -ne \[IntPtr\]::Zero -and\s*\(\$root -eq \$script:window -or \$foregroundOwner -eq \$process.Id\)\) \{ return \}/,
    /if \(\$attempt -lt 4\) \{ Start-Sleep -Milliseconds 100 \}/,
    /throw 'Refusing input: owned app is not foreground'/,
  ]) assert.match(guard, pattern);
  assert.equal((guard.match(/\breturn\b/g) || []).length, 1);
  assert.equal((guard.match(/\bfor\s*\(/g) || []).length, 1);
  assert.deepEqual([...guard.matchAll(/\[VerifyNative\]::(\w+)\(/g)].map(match => match[1]), [
    'GetForegroundWindow', 'GetAncestor', 'GetAncestor', 'GetWindowThreadProcessId',
  ]);
  assert.doesNotMatch(guard, /SetForegroundWindow|SetFocus|BringToForeground|::Chord\(|::Text\(|Wait-(?:Until|Foreground)|\b(?:while|do|until)\b/);
  assert.match(wait, /^function Wait-Foreground \{\s+try \{ Assert-Foreground; return \} catch \{\}\s+for \(\$attempt = 0; \$attempt -lt 50; \$attempt\+\+\) \{\s+\[void\]\[VerifyNative\]::AllowSetForegroundWindow\(\[uint32\]\$process.Id\)\s+\[void\]\[VerifyNative\]::SetForegroundWindow\(\$script:window\)\s+try \{ Assert-Foreground; return \} catch \{\}\s+if \(\$attempt -lt 49\) \{ Start-Sleep -Milliseconds 100 \}\s+\}\s+Assert-Foreground\s+\}\s*$/);
  assert.doesNotMatch(wait, /Wait-Until|while\s*\(/);
  assert.match(press, /^function Press\(\[int\[\]\]\$Keys, \[string\]\$Label\) \{\s+Doctor\s+Wait-Foreground\s+Record \$Label\s+Assert-Foreground\s+\[VerifyNative\]::Chord\(\$Keys\)\s+\}\s*$/);
  assert.match(press, /Record \$Label\s+Assert-Foreground\s+\[VerifyNative\]::Chord\(\$Keys\)/);
  assert.equal((press.match(/::Chord\(/g) || []).length, 1);
  assert.equal((press.match(/::SetForegroundWindow\(/g) || []).length, 0);
  assert.doesNotMatch(press, /Wait-Until|Start-Sleep|catch|\b(?:for|while)\s*\(/);
  assert.match(type, /^function Type-Text\(\[string\]\$Text\) \{\s+Doctor\s+Wait-Foreground\s+Record \('Type ' \+ \$Text\)\s+Assert-Foreground\s+\[VerifyNative\]::Text\(\$Text\)\s+\}\s*$/);
  assert.match(type, /Record \('Type ' \+ \$Text\)\s+Assert-Foreground\s+\[VerifyNative\]::Text\(\$Text\)/);
  assert.equal((type.match(/::Text\(/g) || []).length, 1);
  assert.doesNotMatch(type, /SetForegroundWindow|SetFocus|BringToForeground/);
}

test('IGSH-807: foreground ownership is bounded, refuses foreign input and is rechecked at injection', () => {
  assertsOwnedInput(control);
  for (const [before, after] of [
    ['function Wait-Foreground {\n    try { Assert-Foreground; return } catch {}', 'function Wait-Foreground {'],
    ['$foreground = [VerifyNative]::GetForegroundWindow()', '[void][VerifyNative]::AllowSetForegroundWindow([uint32]$process.Id)\n        $foreground = [VerifyNative]::GetForegroundWindow()'],
    ['$foreground = [VerifyNative]::GetForegroundWindow()', '[void][VerifyNative]::SetForegroundWindow($script:window)\n        $foreground = [VerifyNative]::GetForegroundWindow()'],
    ['        [void][VerifyNative]::SetForegroundWindow($script:window)\n        try { Assert-Foreground; return } catch {}', '        try { Assert-Foreground; return } catch {}\n        [void][VerifyNative]::SetForegroundWindow($script:window)'],
    ['    [void][VerifyNative]::SetForegroundWindow($script:window)\n', ''],
    ['    [void][VerifyNative]::SetForegroundWindow($script:window)\n', '    [void][VerifyNative]::SetForegroundWindow($script:window)\n    [void][VerifyNative]::SetForegroundWindow($script:window)\n'],
    ['    [VerifyNative]::Chord($Keys)', '    [VerifyNative]::Chord($Keys)\n    [VerifyNative]::Chord($Keys)'],
    ['    [VerifyNative]::Text($Text)', '    [VerifyNative]::Text($Text)\n    [VerifyNative]::Text($Text)'],
    ["    Doctor\n    Wait-Foreground\n    Record ('Type ' + $Text)", "    Doctor\n    Record ('Type ' + $Text)"],
    ['$attempt -lt 50', '$true'],
    ['$attempt -lt 49', '$true'],
    ['    Assert-Foreground\n}\n\nfunction Press(', '    try { Assert-Foreground } catch {}\n}\n\nfunction Press('],
    ['    Assert-Foreground\n}\n\nfunction Press(', '    return\n}\n\nfunction Press('],
    ['        [void][VerifyNative]::AllowSetForegroundWindow([uint32]$process.Id)\n', ''],
    ['    Wait-Foreground\n', ''],
    ['    Record $Label\n    Assert-Foreground\n    [VerifyNative]::Chord($Keys)', '    Record $Label\n    [VerifyNative]::Chord($Keys)\n    Assert-Foreground'],
    ['$attempt -lt 5', '$true'],
    ['$attempt -lt 4', '$true'],
    ['Start-Sleep -Milliseconds 100', 'Start-Sleep -Seconds 100'],
    ['GetAncestor($foreground, 3)', 'GetAncestor($foreground, 2)'],
    ['GetWindowThreadProcessId($rootOwner, [ref]$foregroundOwner)', 'GetWindowThreadProcessId($foreground, [ref]$foregroundOwner)'],
    ['$foreground -ne [IntPtr]::Zero -and', ''],
    ['$root -ne [IntPtr]::Zero -and', ''],
    ['$rootOwner -ne [IntPtr]::Zero -and', ''],
    ['$root -eq $script:window -or $foregroundOwner -eq $process.Id', '$true'],
    ["throw 'Refusing input: owned app is not foreground'", 'return'],
    ['        [void][VerifyNative]::SetForegroundWindow($script:window)\n        try { Assert-Foreground; return } catch {}', '    [void][VerifyNative]::SetForegroundWindow($script:window)'],
    ['    Assert-Foreground\n    [VerifyNative]::Chord($Keys)', '    [VerifyNative]::Chord($Keys)'],
    ['    Assert-Foreground\n    [VerifyNative]::Text($Text)', '    [VerifyNative]::Text($Text)'],
  ]) {
    const broken = control.replaceAll(before, after);
    assert.notEqual(broken, control, before);
    assert.throws(() => assertsOwnedInput(broken), assert.AssertionError, before);
  }
});

test('IGSH-807: real PowerShell helpers accept owned roots and bound transient or foreign focus without injecting', { skip: process.platform !== 'win32' }, () => {
  const os = require('node:os');
  const { spawnSync } = require('node:child_process');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh807-foreground-'));
  const helpers = control.slice(control.indexOf('function Assert-Foreground {'), control.indexOf('function Click-WorkspacePill('));
  const script = `$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
public static class VerifyNative {
    public static IntPtr Foreground = new IntPtr(10), Root = new IntPtr(10), RootOwner = new IntPtr(10);
    public static uint Owner = 42;
    public static int Reads, Chords, Texts, Activations, Allows, RecoverOnActivation;
    public static bool LoseOnActivation;
    public static IntPtr GetForegroundWindow() { Reads++; return Foreground; }
    public static IntPtr GetAncestor(IntPtr hwnd, uint flags) { return flags == 2 ? Root : RootOwner; }
    public static uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid) { pid = Owner; return 1; }
    public static bool AllowSetForegroundWindow(uint pid) { Allows++; return true; }
    public static bool SetForegroundWindow(IntPtr hwnd) {
        Activations++;
        if (LoseOnActivation) Foreign();
        if (RecoverOnActivation > 0 && Activations >= RecoverOnActivation) { Foreground = Root = RootOwner = hwnd; Owner = 42; }
        return true;
    }
    public static void Chord(int[] keys) { Chords++; }
    public static void Text(string text) { Texts++; }
    public static void Foreign() { Foreground = new IntPtr(99); Root = new IntPtr(99); RootOwner = new IntPtr(99); Owner = 99; }
}
'@
$script:window = [IntPtr]10
$process = [pscustomobject]@{ Id = 42 }
$script:recover = $false
$script:loseOnRecord = $false
$script:sleeps = 0
function Doctor {}
function Record($Label) { if ($script:loseOnRecord) { [VerifyNative]::Foreign() } }
function Start-Sleep([int]$Milliseconds) {
    if ($Milliseconds -ne 100) { throw 'Wrong retry interval' }
    $script:sleeps++
    if ($script:recover) { [VerifyNative]::Owner = 42 }
}
${helpers}
function Reset {
    [VerifyNative]::Foreground = [IntPtr]10; [VerifyNative]::Root = [IntPtr]10; [VerifyNative]::RootOwner = [IntPtr]10
    [VerifyNative]::Owner = 42; [VerifyNative]::Reads = 0; [VerifyNative]::Chords = 0; [VerifyNative]::Texts = 0; [VerifyNative]::Activations = 0; [VerifyNative]::Allows = 0; [VerifyNative]::RecoverOnActivation = 0
    [VerifyNative]::LoseOnActivation = $false; $script:loseOnRecord = $false; $script:recover = $false; $script:sleeps = 0
}
function Require($Ok, $Message) { if (-not $Ok) { throw $Message } }
function Refuses([scriptblock]$Action) {
    $refused = $false
    try { & $Action } catch {
        if ($_.Exception.Message -cne 'Refusing input: owned app is not foreground') { throw }
        $refused = $true
    }
    Require $refused 'Foreign input accepted'
    Require ([VerifyNative]::Chords -eq 0 -and [VerifyNative]::Texts -eq 0) 'Foreign input injected'
}
Reset
Press @(0x12, 0x43) 'owned main'
Require ([VerifyNative]::Chords -eq 1 -and [VerifyNative]::Activations -eq 0 -and [VerifyNative]::Allows -eq 0) 'Owned main input failed'
Reset
[VerifyNative]::Foreground = [IntPtr]20; [VerifyNative]::Root = $script:window; [VerifyNative]::Owner = 99
[VerifyNative]::LoseOnActivation = $true
Press @(0x0D) 'owned child console Enter'
Require ([VerifyNative]::Chords -eq 1 -and [VerifyNative]::Activations -eq 0 -and [VerifyNative]::Foreground -eq [IntPtr]20) 'IGSH-884 Enter moved focus away from the owned console'
Reset
[VerifyNative]::Owner = 99
Assert-Foreground
Require ([VerifyNative]::Reads -eq 1) 'Owned GA_ROOT was rejected'
Reset
[VerifyNative]::Foreground = [IntPtr]20; [VerifyNative]::Root = [IntPtr]20
Assert-Foreground
Require ([VerifyNative]::Reads -eq 1) 'App-process root owner was rejected'
Reset
[VerifyNative]::Foreign(); $script:recover = $true
Assert-Foreground
Require ([VerifyNative]::Reads -eq 2 -and $script:sleeps -eq 1) 'Transient foreground did not recover within bound'
Reset
[VerifyNative]::Foreign()
Refuses { Press @(0x41) 'foreign' }
Require ([VerifyNative]::Reads -eq 260 -and $script:sleeps -eq 257 -and [VerifyNative]::Activations -eq 50 -and [VerifyNative]::Allows -eq 50) 'Foreign refusal did not respect retry or activation boundary'
Reset
[VerifyNative]::Foreign(); [VerifyNative]::RecoverOnActivation = 2
Press @(0x41) 'recovered on second activation'
Require ([VerifyNative]::Chords -eq 1 -and [VerifyNative]::Activations -eq 2 -and [VerifyNative]::Allows -eq 2 -and $script:sleeps -eq 9) 'Press did not retry foreground activation'
Reset
[VerifyNative]::Foreign(); [VerifyNative]::RecoverOnActivation = 50
Press @(0x41) 'recovered on last activation'
Require ([VerifyNative]::Chords -eq 1 -and [VerifyNative]::Activations -eq 50 -and [VerifyNative]::Allows -eq 50 -and $script:sleeps -eq 249) 'Press did not allow the last bounded activation'
foreach ($field in @('Foreground', 'Root', 'RootOwner')) {
    Reset
    if ($field -eq 'Foreground') { [VerifyNative]::Foreground = [IntPtr]::Zero }
    if ($field -eq 'Root') { [VerifyNative]::Root = [IntPtr]::Zero }
    if ($field -eq 'RootOwner') { [VerifyNative]::RootOwner = [IntPtr]::Zero }
    Refuses { Assert-Foreground }
    Require ([VerifyNative]::Reads -eq 5) 'Null HWND bypassed bounded ownership checks'
}
Reset
[VerifyNative]::Foreign()
[VerifyNative]::LoseOnActivation = $true
Refuses { Press @(0x41) 'lost on activation' }
Reset
$script:loseOnRecord = $true
Refuses { Press @(0x41) 'lost before chord' }
Reset
$script:loseOnRecord = $true
Refuses { Type-Text 'lost before text' }
Reset
[VerifyNative]::Foreign(); [VerifyNative]::RecoverOnActivation = 2
Type-Text 'recovered text'
Require ([VerifyNative]::Texts -eq 1 -and [VerifyNative]::Activations -eq 2) 'Text did not recover owned foreground'
Reset
Type-Text 'owned text'
Require ([VerifyNative]::Texts -eq 1 -and [VerifyNative]::Activations -eq 0) 'Text repaired focus or failed to inject'
Write-Host 'IGSH-807 owned foreground and bounded retry behaviour passed'
`;
  try {
    const file = path.join(dir, 'foreground.ps1');
    fs.writeFileSync(file, script);
    const result = spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-File', file], { encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, /IGSH-807 owned foreground and bounded retry behaviour passed/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

function assertsPaneFocusGeometry(source, workflowText) {
  const focus = source.slice(source.indexOf("            foreach ($theme in @('dark', 'multiprompt'"), source.indexOf("            Select-Theme 'dark' 'pane-layout-final-dark'"));
  assert.match(focus, /foreach \(\$theme in @\('dark', 'multiprompt', 'light', 'amoled', 'mid', 'edgegray', 'system'\)\)/);
  assert.match(focus, /foreach \(\$view in @\('shell', 'chat'\)\)/);
  assert.match(focus, /foreach \(\$cycle in @\(1, 2\)\)/);
  for (const required of [
    'Wait-ConsoleText $command', "(Get-Content $marker -Raw).Trim() -ceq $step",
    "(Get-Content $returnMarker -Raw).Trim() -ceq 'returned'",
    "'Alt+Q selected the owned browser'", "'Refusing browser probe outside the Alt+Q-selected pane'",
    "('IGSH807 keys ' + $pageKeys + ' ')", "'browser page received the exact next key'",
    "'Browser input changed the chat draft'", "'Alt+Q lost the chat draft'",
    "[VerifyNative]::EditText($composer) -ceq ($draft + '-returned')",
    '$focusProofs += @{ theme = $theme; view = $view; cycle = $cycle; pageKeys = $pageKeys; pixels = $pixels }',
    "Save-Json $focusProofs 'focus-ring-proof.json'",
    "if (@($focusProofs | Where-Object { $_.pixels.mismatches -ne 0 }).Count -ne 0) { throw 'IGSH-807 focus ring pixels differ from the unfocused surface' }",
  ]) assert.ok(focus.includes(required), required);
  assert.doesNotMatch(focus, /SetForegroundWindow|FocusOwnedWindow|BringToForeground/);
  const pane = source.slice(source.indexOf("        'pane-layout' {"), source.indexOf("        'browser-switch-speed' {"));
  for (const match of pane.matchAll(/^([ \t]*)\[VerifyNative\]::(?:Chord|Text)\(/gm)) {
    assert.match(pane.slice(0, match.index), /Assert-Foreground\r?\n$/);
  }
  const final = pane.slice(pane.indexOf("            Select-Theme 'dark' 'pane-layout-final-dark'"), pane.indexOf("            Save-Json $proof 'pane-layout-pixels.json'"));
  const maskCapture = pane.slice(pane.indexOf("                Press @(0x11, 0x32) 'Ctrl+2: restore original console"), pane.indexOf('                $maskColors.themes[$theme].pixels ='));
  for (const capture of [final, maskCapture]) {
    assert.match(capture, /Wait-WorkspaceSurface \$initial.active_workspace \$consoleTab \$false/);
    for (const required of [
      'GetForegroundWindow() -ne $console', 'PaneWindow($script:window) -ne $browser',
      "GetProp($browser, 'ZigShellPaneOwner') -ne $script:window", 'IsZoomed($script:window)',
      '$frame = New-Object VerifyNative+Rect', '$client = New-Object VerifyNative+Rect',
      '$consoleRect = New-Object VerifyNative+Rect', '$browserRect = New-Object VerifyNative+Rect',
      '$origin = New-Object VerifyNative+Point', 'GetWindowRect($script:window, [ref]$frame)',
      'GetClientRect($script:window, [ref]$client)', 'ClientToScreen($script:window, [ref]$origin)',
      'GetWindowRect($console, [ref]$consoleRect)', 'GetWindowRect($browser, [ref]$browserRect)',
      '$client.Left += $origin.X; $client.Right += $origin.X; $client.Top += $origin.Y; $client.Bottom += $origin.Y',
      '$state = Read-Session', '$state.tabs[$consoleTab].shell_id -ne $consoleShellId',
      "$state.tabs[$consoleTab].PSObject.Properties['cv'] -and $state.tabs[$consoleTab].cv",
      '$scale = 100', "if ($state.PSObject.Properties['ui_scale']) { $scale = [int]$state.ui_scale }",
      '$dpi = [VerifyNative]::GetDpiForWindow($script:window)',
      "$hidePills = $state.PSObject.Properties['hide_pills'] -and $state.hide_pills",
    ]) assert.ok(capture.includes(required), required);
    assert.ok(capture.indexOf('$dpi =') < capture.indexOf('Snapshot '));
    assert.doesNotMatch(capture, /\$console =|\$browser =/);
  }
  assert.match(final, /Save-Json[^\n]+ 'pane-layout-rects.json'\s+Snapshot 'pane-layout'\s+\$proof = \[PaneLayoutProof\]::Check\([^\n]+, \$frame, \$client, \$consoleRect, \$browserRect, \$dpi, \$scale, \$hidePills\)/);
  assert.match(final, /Fresh console UIA and HWND identity\/bounds disagree/);
  for (const required of [
    "'9618091700e09f5958a48390449dc5067874d5dd'",
    "$red.error -ne 'IGSH-807 focus ring pixels differ from the unfocused surface'",
    '$proofList.Count -ne 28 -or $withoutRing -ne 0',
    'if ([int]$proof.pixels.mismatches -le 0) { $withoutRing++ }',
  ]) assert.ok(workflowText.includes(required), required);
}

test('IGSH-807: every raw injection is owned, all focus proofs remain strict and final/mask geometry is fresh', () => {
  assertsPaneFocusGeometry(control, workflow);
  for (const required of [
    "'dark', 'multiprompt', 'light', 'amoled', 'mid', 'edgegray', 'system'", "@('shell', 'chat')", '@(1, 2)',
    '$_.pixels.mismatches -ne 0', 'GetForegroundWindow() -ne $console',
    'GetWindowRect($console, [ref]$consoleRect)', 'GetWindowRect($browser, [ref]$browserRect)',
    '$client = New-Object VerifyNative+Rect', 'GetClientRect($script:window, [ref]$client)',
    'ClientToScreen($script:window, [ref]$origin)', '$dpi = [VerifyNative]::GetDpiForWindow($script:window)',
    '$state.tabs[$consoleTab].shell_id -ne $consoleShellId',
  ]) {
    const broken = control.replaceAll(required, '');
    assert.notEqual(broken, control, required);
    assert.throws(() => assertsPaneFocusGeometry(broken, workflow), assert.AssertionError, required);
  }
  const unguarded = control.replaceAll('                        Assert-Foreground\n                        [VerifyNative]::Chord', '                        [VerifyNative]::Chord');
  assert.notEqual(unguarded, control);
  assert.throws(() => assertsPaneFocusGeometry(unguarded, workflow), assert.AssertionError);
  for (const required of ['$proofList.Count -ne 28 -or $withoutRing -ne 0', "$red.error -ne 'IGSH-807 focus ring pixels differ from the unfocused surface'"]) {
    assert.throws(() => assertsPaneFocusGeometry(control, workflow.replace(required, '$false')), assert.AssertionError);
  }
});

test('docked native browser handoff retains identity, visibility and strict foreign-input guards', () => {
  const handoff = control.slice(control.indexOf('function Focus-BrowserPaneOwner('), control.indexOf('function Assert-ConnectedPaneStaysVisible('));
  const dockedOwner = /\$pane.browser_state -eq 'connected' -and\s*\$pane.browser_connection_id -eq \$ConnectionId -and \[VerifyNative\]::PaneVisible\(\$script:window\)/;
  const waitsBeforeActivation = /Wait-Until \{[\s\S]*\} "browser-pane-stuck \$\{Step\}: docked pane ready for main-window activation" 25\s*Doctor\s*Record[^\n]*\n\s*\[void\]\[VerifyNative\]::SetForegroundWindow\(\$script:window\)/;
  const verifiesForeground = /Wait-Until \{ \[VerifyNative\]::GetAncestor\(\[VerifyNative\]::GetForegroundWindow\(\), 2\) -eq \$script:window \} "browser-pane-stuck \$\{Step\}: main window is foreground" 5/;
  for (const pattern of [dockedOwner, waitsBeforeActivation, verifiesForeground]) {
    assert.match(handoff, pattern);
    assert.throws(() => assert.match(handoff.replace(pattern, ''), pattern));
  }
  assert.match(handoff, /Focus-BrowserPaneOwner \$Step \$pane.browser_connection_id/);
  assertsOwnedInput(control);
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

test('failed SSH status must match the created tab and exact logged nonzero exit code', () => {
  function requiresFailureStatus(source) {
    assert.match(source, /Invoke-Zsb @\('session-status', '--tab', \[string\]\$created.tab\) \$script:zsbPort 'session-status-failed'/);
    assert.match(source, /\$status.tab -ne \$created.tab/);
    assert.match(source, /\$status.state -cne 'disconnected'/);
    assert.match(source, /-not \$status.PSObject.Properties\['exit_code'\]/);
    assert.match(source, /\$status.exit_code -ne \$script:sshFailure.exitCode/);
    assert.match(source, /name = 'session-status-failed-attach'/);
  }
  requiresFailureStatus(journey);
  for (const required of ["'session-status'", "$status.tab -ne $created.tab", "$status.state -cne 'disconnected'", "$status.exit_code -ne $script:sshFailure.exitCode"]) {
    assert.throws(() => requiresFailureStatus(journey.replace(required, '$false')));
  }
});

test('G2: evidence is retained without seeding app state or bypassing cleanup', () => {
  for (const shot of ['before', 'action', 'after']) assert.ok(journey.includes(`Snapshot '${shot}'`));
  for (const name of ['session-before', 'session-created', 'session-repeated', 'session-after']) assert.ok(journey.includes(`'${name}.json'`));
  assert.match(transport, /WriteAllBytes[\s\S]*?\.request.bin/);
  assert.match(transport, /WriteAllText[\s\S]*?\.reply.json/);
  assert.doesNotMatch(journey, /Set-Content|WriteAllText|WriteAllBytes|SetEnvironmentVariable|PostMessage/);
  assertsOwnedInput(control);
  assert.match(control, /function Type-Text[\s\S]*?Doctor\s+Wait-Foreground/);
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
    assert.match(workflow.replace(/\r?\n/g, ending), /  verify:\r?\n(?:    needs: [^\n]+\r?\n|    continue-on-error: [^\n]+\r?\n)*    if: inputs\.feature != 'chat-sync-audit'\r?\n    runs-on: windows-latest/);
  }
  assert.match(read(skill + 'features/README.md'), /\[Chat sync audit\]\(\.\.\/diagnostics\/chat-sync-audit.md\)/);
  assert.match(read(skill + 'diagnostics/chat-sync-audit.md'), /not a Windows desktop journey/);
  assert.equal(fs.existsSync(path.join(root, skill, 'features/chat-sync-audit.md')), false);
  assert.match(read(skill + 'SKILL.md'), /\[Chat sync audit\]\(diagnostics\/chat-sync-audit.md\)/);
});

test('maintained verification code contains no removable code comments', async () => {
  const { strip } = await import('./strip-comments.mjs');
  for (const [source, language] of [[control, 'powershell'], [workflow, 'yaml'], [read('tools/verify-multiprompt.test.js'), 'javascript'], [read('tools/verify-scratch.test.ps1'), 'powershell'], ...['console', 'inbox', 'launch_cache', 'main', 'session'].map(file => [read(`src/${file}.zig`), 'zig'])]) {
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
  assert.match(workflow, /zig build test-main -Drender-proof=true --summary all/);
  assert.match(workflow, /if \(\$LASTEXITCODE -ne 0\) \{ throw 'Native desktop rendering tests failed' \}/);
  assert.match(workflow, /evidence\/chat-markdown-render\.png/);
  assert.equal((chat.split('$localAgent =')[0].match(/Press @\(0x12, 0x43\)/g) || []).length, 3);
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
  assert.match(workflow, /control\.ps1 -Feature \$env:FEATURE/);
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

test('IGSH-789: remote-session help sends activity through the installed notifier', () => {
  const source = read('src/workspaces.zig');
  const start = source.indexOf('    const text = if (is_remote)', source.indexOf('pub fn copyBlueDotHookInstructions('));
  const end = source.indexOf('\n    else\n', start);
  assert.ok(start >= 0 && end > start, 'remote blue-dot help must exist');
  const help = source.slice(start, end);
  assert.doesNotMatch(help, /[^\n]*(?:ACTIVE|DONE)[^\n]*\/dev\/tcp\/localhost[/:]19548/);
  assert.match(help, /UserPromptSubmit -> command:  python3 ~\/\.local\/share\/zigshell\/notify\.py claude active/);
  assert.match(help, /Stop             -> command:  python3 ~\/\.local\/share\/zigshell\/notify\.py claude done/);
  assert.match(help, /reverse SSH tunnel[^\n]*localhost:19548/);
  assert.match(help, /TMUX_PANE/);
  assert.match(help, /MULTIPROMPT_TAB/);
  assert.doesNotMatch(help, /no tools beyond bash|bash's built-in|The label/);
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
    ['if (!app_state.g_restoring and !app_state.g_account_applying and', 'if (!app_state.g_account_applying and'],
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
  assert.match(focus, /Focus-Palette 'chat view off everywhere' 6347/);
  assert.match(focus, /-not \$state\.PSObject\.Properties\['chat_view_mode'\] -and -not \$state\.tabs\[\$initialTab\]\.PSObject\.Properties\['chat_view_lock'\]/);
  assert.ok(focus.includes("-not ($state.tabs[$initialTab].PSObject.Properties['cv'] -and $state.tabs[$initialTab].cv)"));
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
  assert.match(palette, /\$start = \(\(Get-Content \$log -Raw\) -join ''\).Length/);
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

test('IGSH-820 shell baseline uses a live one-shot palette command', () => {
  assert.match(read('src/app_state.zig'), /SEARCH_CHAT_VIEW_MODE_NOWHERE_OFFSET: usize = 6347;/);
  assert.match(read('src/command_palette.zig'), /asciiContainsQueryInsensitive\("Chat View off everywhere"[\s\S]*?g_search_results\[app_state\.g_search_result_count\] = SEARCH_CHAT_VIEW_MODE_NOWHERE_OFFSET;/);
  assert.match(read('src/main.zig'), /setEverywhere\(app_state\.shells\[0\.\.app_state\.shell_count\], target == SEARCH_CHAT_VIEW_MODE_EVERYWHERE_OFFSET\)[\s\S]*?applySessionView\(\);\s*saveSession\(\);/);
});

test('IGSH-522: hidden pills are shown through the palette and every focus transition waits for real input readiness', () => {
  assertsFocusJourneyReadiness(control);
  for (const [before, after] of [
    ["Focus-Palette 'workspace switcher' 6213", "Palette 'workspace switcher'"],
    ["Focus-Palette 'chat view off everywhere' 6347", "Palette 'chat view off everywhere'"],
    ["Focus-Palette 'chat view off everywhere' 6347", "Focus-Palette 'chat view off everywhere' 0"],
    ["-and -not $state.tabs[$initialTab].PSObject.Properties['chat_view_lock']", ''],
    ["-not ($state.tabs[$initialTab].PSObject.Properties['cv'] -and $state.tabs[$initialTab].cv)", '$true'],
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
  assert.match(cleanup, /function Remove-ScratchPath\(\[string\]\$Path, \[int\]\$Seconds = 20\) \{\s*\$deadline = \[DateTime\]::UtcNow.AddSeconds\(\$Seconds\)/);
  assert.match(cleanup, /Scratch cleanup left paths:[^\n]*\$leftovers -join/);
  assert.match(source, /Remove-ScratchPath \$scratch/);
}

test('ISSUE-559 cleanup tolerates only typed missing paths and reports remaining paths within a bound', () => {
  assertsScratchRaceHandling(control);
  for (const [before, after] of [
    ['if (Test-Path -LiteralPath $Path) { return $false }', ''],
    ['if (-not (Test-VanishedScratchItem $_ $entry.FullName)) { throw }', 'throw'],
    ['Scratch cleanup left paths:', 'Cleanup failed:'],
    ['function Remove-ScratchPath([string]$Path, [int]$Seconds = 20)', 'function Remove-ScratchPath([string]$Path, [int]$Seconds = 1)'],
    ['$deadline = [DateTime]::UtcNow.AddSeconds($Seconds)', '$deadline = [DateTime]::UtcNow.AddSeconds(1)'],
  ]) {
    const broken = control.replace(before, after);
    assert.notEqual(broken, control);
    assert.throws(() => assertsScratchRaceHandling(broken));
  }
});

test('ISSUE-559 real Windows cleanup rejects the old vanished-lockfile race and names locked leftovers', { skip: process.platform !== 'win32' }, () => {
  const { spawnSync } = require('node:child_process');
  const result = spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-File', path.join(__dirname, 'verify-scratch.test.ps1')], { encoding: 'utf8', timeout: 120000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /ISSUE-559 old cleanup rejected:/);
  assert.match(result.stdout, /ISSUE-559 production cleanup passed/);
});

test('ISSUE-559 setup waits for rendered browser readiness and retries only owned-frame activation', () => {
  const palette = control.slice(control.indexOf('function Focus-Palette('), control.indexOf('function Wait-WorkspaceSurface('));
  assert.equal((palette.match(/Press @\(0x11, 0x4B\)/g) || []).length, 1);
  assert.match(palette, /Press @\(0x11, 0x4B\) 'Ctrl\+K: open command palette'\s+Retry-PaletteOpen \$log \$start/);
  assert.match(control, /function Retry-PaletteOpen[\s\S]*?-le 3[\s\S]*?ready chars=0[\s\S]*?Activate-OwnedFrame\s+Press @\(0x11, 0x4B\) 'Ctrl\+K: open command palette again'/);
  assert.match(control, /function Activate-OwnedFrame \{[\s\S]*?SetForegroundWindow\(\$script:window\)[\s\S]*?GetAncestor\(\[VerifyNative\]::GetForegroundWindow\(\), 2\) -eq \$script:window/);
  assert.match(palette, /if \(\$trace -notmatch[^\n]*\) \{ return \$false \}\s*Doctor\s*Assert-Foreground\s*\[void\]\[VerifyNative\]::SetForegroundWindow\(\$script:window\)/);
  assert.match(palette, /'command palette initialized and owned frame focused' 20/);
  const setup = control.slice(control.indexOf("    if ($Feature -in @('browser-pane-stuck', 'pane-layout', 'browser-pane-locked', 'browser-switch-speed', 'chat-switch-speed', 'chat-first-paint', 'browser-corners', 'window-controls'))"), control.indexOf("    Record 'Launch complete;"));
  assert.match(setup, /ZigShell\/EdgeUserData/);
  assert.match(setup, /\$warmupJob.Start\(\$edge/);
  assert.match(setup, /MainWindowTitle -match '\^Multiprompt verification browser ready'/);
  assert.match(setup, /'isolated browser rendered setup page before the pane adoption deadline starts' 60/);
  assert.doesNotMatch(setup, /Assert-BrowserPane|PaneLayoutProof|Start-Sleep/);
  assert.match(control, /\$warmupStopped = \$warmupJob.Stop\(\)/);
  assert.match(workflow, /run: node --test --test-concurrency=1 tools\/verify-multiprompt.test.js/);
  assert.ok(workflow.includes('- tools/verify-scratch.test.ps1'));
});

test('ISSUE-569 restore registry, real close/kill and persistent private relaunches cannot be skipped', () => {
  function contract(driver, workflowText) {
    assert.match(driver, /ValidateSet\([^\n)]*'session-restore'/);
    assert.match(workflowText, /\$env:FEATURE -notin @\([^\n)]*'session-restore'/);
    const launch = driver.slice(driver.indexOf("    if ($Feature -eq 'session-restore') {"), driver.indexOf("    if ($Feature -in @('browser-pane-stuck'"));
    assert.match(launch, /\$job.Start\(\$Exe, \$scratch, [^\n]+, '--single-window'\)/);
    const restart = driver.slice(driver.indexOf('function Restart-SessionRestore('), driver.indexOf('function Assert-SessionRestoreSelection('));
    assert.match(restart, /Doctor\s+if \(\$process.MainWindowHandle -ne \$script:window\) \{ throw/);
    assert.match(restart, /if \(\$Crash\) \{[\s\S]*?Stop-Process -Id \$process.Id -Force[\s\S]*?\} else \{[\s\S]*?\$process.CloseMainWindow\(\)/);
    assert.match(restart, /if \(-not \$process.WaitForExit\(20000\)\) \{ throw/);
    assert.match(restart, /\$stopped = \$job.Stop\(\)/);
    assert.ok(restart.indexOf('$job.Stop()') < restart.indexOf('$script:job = New-Object VerifyJob'));
    assert.match(restart, /\$script:process = \$job.Start\(\$Exe, \$scratch, [^\n]+, '--single-window'\)/);
    assert.match(restart, /\$state.hwnd -eq \$script:window.ToInt64\(\).ToString\(\)/);
    assert.match(restart, /Substring\(\$logStart\)/);
    assert.match(restart, /\$state.hwnd -eq \$script:window.ToInt64\(\).ToString\(\) -and @\(\$state.shells\).Count -gt 0 -and\s+\$trace -match 'launch step=browser'\s+\} "\$Stage relaunch publishes its owned window and restored shells before activation" 60/);
    assert.match(restart, /\$trace -match 'launch step=browser' -and \$trace -match 'installHook: KEYBOARD_LL installed'/);
    assert.doesNotMatch(restart, /no-window-restore|Remove-Item|Set-Content|WriteAll|Stop-Process -Name|New-Item/);
    const recipe = driver.slice(driver.indexOf("        'session-restore' {"), driver.indexOf("        'workspaces' {"));
    let offset = -1;
    for (const step of [
      "Press @(0x11, 0x4E) 'Ctrl+N:", "@('Restore first', 'Restore middle', 'Restore last')",
      "Focus-Palette 'new cmd' 2000", "Press @(0x71) 'F2:", 'Type-Text $names[$i]',
      "Focus-Palette 'Restore middle' $middleIndex", "Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId",
      "Restart-SessionRestore 'normal-close' $false", "Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId",
      "name = 'normal-close-selection'",
      "'normal-close hook-ready owned foreground before workspace input'",
      "'favorite home workspace active outside Starred before palette input'",
      "'favorite-home-kill hook-ready owned foreground before palette input'",
      "Focus-Palette 'Restore first' $firstIndex",
      "Assert-SessionRestoreSelection 'Restore first' $workspace $workspaceId", "Restart-SessionRestore 'process-kill' $true",
      "Assert-SessionRestoreSelection 'Restore first' $workspace $workspaceId", "name = 'process-kill-selection'",
      "if ($result.checks.Count -ne $requiredChecks.Count) { throw", "Snapshot 'after'",
    ]) {
      const next = recipe.indexOf(step, offset + 1);
      assert.ok(next > offset, `missing or misordered ${step}`);
      offset = next;
    }
    assert.doesNotMatch(recipe, /Set-Content|WriteAll|SetEnvironmentVariable|PostMessage|Remove-Item/);
    for (const shot of ['action', 'normal-close-after', 'kill-action', 'after']) assert.ok(recipe.includes(`Snapshot '${shot}'`));
    assert.ok(driver.indexOf("'process-kill-after.inbox.json'") < driver.indexOf("    $result.status = 'passed'"));
    assert.match(driver, /feature = \$Feature; status = 'failed'/);
  }
  contract(control, workflow);
  for (const required of [
    "'session-restore', ", 'Stop-Process -Id $process.Id -Force', '$process.CloseMainWindow()',
    '$state.hwnd -eq $script:window.ToInt64().ToString()', "$trace -match 'launch step=browser'",
    "$trace -match 'installHook: KEYBOARD_LL installed'",
    "Restart-SessionRestore 'normal-close' $false", "Restart-SessionRestore 'process-kill' $true",
    "name = 'normal-close-selection'", "name = 'process-kill-selection'",
  ]) {
    const broken = control.replace(required, '');
    assert.notEqual(broken, control);
    assert.throws(() => contract(broken, workflow));
  }
  assert.throws(() => contract(control, workflow.replace("'session-restore', ", '')));
  assert.throws(() => contract(control.replace("'--single-window')", "'--single-window --no-window-restore')"), workflow));
  const map = read(skill + 'features/session-restore.md');
  assert.deepEqual([...map.matchAll(/^## (.+)$/gm)].map(match => match[1]), [
    'Sub-features', 'How to get to it (user POV)', 'Driving it with control.ps1', 'Gotchas',
  ]);
  assert.match(read(skill + 'features/README.md'), /\[Session restore\]\(session-restore.md\)/);
  assert.match(read(skill + 'SKILL.md'), /`session-restore`/);
});

test('ISSUE-569 relaunch activation recovers foreground only as an input precondition and preserves failure captures', () => {
  function contract(driver) {
    const activation = driver.slice(driver.indexOf('    public static void BringToForeground('), driver.indexOf('    [DllImport("user32.dll", SetLastError=true)] static extern bool GetGUIThreadInfo'));
    assert.match(activation, /GetWindowThreadProcessId\(GetForegroundWindow\(\), out pid\)/);
    assert.match(activation, /uint currentThread = GetCurrentThreadId\(\)/);
    assert.match(activation, /foregroundThread != 0 && foregroundThread != currentThread && AttachThreadInput\(currentThread, foregroundThread, true\)/);
    assert.match(activation, /targetThread != 0 && targetThread != currentThread && targetThread != foregroundThread && AttachThreadInput\(currentThread, targetThread, true\)/);
    assert.match(activation, /Key\(0x12, 0, 0\);\s*try \{\s*AllowSetForegroundWindow\(targetPid\);\s*BringWindowToTop\(hwnd\);\s*SetForegroundWindow\(hwnd\);\s*\} finally \{\s*Key\(0x12, 0, 2\);\s*if \(attachedTarget\) AttachThreadInput\(currentThread, targetThread, false\);\s*if \(attached\) AttachThreadInput\(currentThread, foregroundThread, false\);\s*\}/);
    const restart = driver.slice(driver.indexOf('function Restart-SessionRestore('), driver.indexOf('function Assert-SessionRestoreSelection('));
    assert.match(restart, /\$process.Refresh\(\)\s+\$script:window = \$process.MainWindowHandle/);
    assert.match(restart, /\$state.hwnd -eq \$script:window.ToInt64\(\).ToString\(\)/);
    assert.match(restart, /\$trace -match 'launch step=browser' -and \$trace -match 'installHook: KEYBOARD_LL installed'/);
    assert.match(restart, /ShowWindow\(\$script:window, 9\)/);
    assert.match(restart, /MoveWindow\(\$script:window, 10, 10, 1000, 650, \$true\)/);
    const publication = restart.slice(restart.indexOf('    Wait-Until {'), restart.indexOf('    [void][VerifyNative]::ShowWindow'));
    assert.match(publication, /Wait-Until \{\s+\$process.Refresh\(\)\s+\$script:window = \$process.MainWindowHandle\s+\$state = Read-Inbox\s+\$trace = \(\(Get-Content \$log -Raw\) -join ''\).Substring\(\$logStart\)\s+\$script:window -ne \[IntPtr\]::Zero -and \$null -ne \$state -and\s+\$state.hwnd -eq \$script:window.ToInt64\(\).ToString\(\) -and @\(\$state.shells\).Count -gt 0 -and\s+\$trace -match 'launch step=browser'\s+\} "\$Stage relaunch publishes its owned window and restored shells before activation" 60/);
    assert.doesNotMatch(publication, /installHook|BringToForeground|Start-Sleep/);
    assert.match(restart, /Wait-Until \{\s+\[VerifyNative\]::BringToForeground\(\$script:window\)\s+\[VerifyNative\]::GetAncestor\(\[VerifyNative\]::GetForegroundWindow\(\), 2\) -eq \$script:window\s+\} "\$Stage relaunched window foreground before input"\s+Wait-Until \{\s+\$process.Refresh\(\)\s+\$script:window = \$process.MainWindowHandle\s+\$state = Read-Inbox\s+\$trace = \(\(Get-Content \$log -Raw\) -join ''\).Substring\(\$logStart\)\s+\$script:window -ne \[IntPtr\]::Zero -and \$null -ne \$state -and\s+\$state.hwnd -eq \$script:window.ToInt64\(\).ToString\(\) -and @\(\$state.shells\).Count -gt 0 -and\s+\$trace -match 'launch step=browser' -and \$trace -match 'installHook: KEYBOARD_LL installed'\s+\} "\$Stage relaunch owns its published state after session restore" 60\s+Doctor/);
    assert.doesNotMatch(restart, /Assert-Foreground/);
    assertsOwnedInput(driver);
    assert.match(driver, /SetForegroundWindow\(\$script:window\)\s+Wait-Until[^\n]+ 'foreground main window'/);
    assert.match(driver, /try \{ Snapshot 'failure' \} catch/);
    assert.match(driver, /Save-Json \$focus \(\$Name \+ '.focus.json'\)/);
    assert.match(driver, /\$bitmap.Save\(\(Join-Path \$Evidence \(\$Name \+ '.png'\)\)/);
  }
  contract(control);
  const publicationStart = control.indexOf('    Wait-Until {', control.indexOf('function Restart-SessionRestore('));
  const activationStart = control.indexOf('    [void][VerifyNative]::ShowWindow', publicationStart);
  const readinessStart = control.indexOf('    Wait-Until {', control.indexOf('    } "$Stage relaunched window foreground before input"', activationStart));
  const doctor = control.indexOf('    Doctor\n    } finally {', readinessStart);
  const racy = control.slice(0, publicationStart) + control.slice(readinessStart, doctor) + control.slice(activationStart, readinessStart) + control.slice(doctor);
  assert.throws(() => contract(racy), assert.AssertionError);
  for (const [before, after] of [
    ['AttachThreadInput(currentThread, foregroundThread, true)', 'false'],
    ['if (attached) AttachThreadInput(currentThread, foregroundThread, false);', ''],
    ['AllowSetForegroundWindow(targetPid);', ''],
    ['Key(0x12, 0, 0);\n        try {', 'try {'],
    ['            SetForegroundWindow(hwnd);\n        } finally {', '        } finally {'],
    ['[VerifyNative]::BringToForeground($script:window)\n        [VerifyNative]::GetAncestor', '[void][VerifyNative]::SetForegroundWindow($script:window)\n        [VerifyNative]::GetAncestor'],
    ['} "$Stage relaunched window foreground before input"\n    Wait-Until {', '} "$Stage relaunched window foreground before input"\n    Assert-Foreground\n    Wait-Until {'],
    ['} "$Stage relaunch publishes its owned window and restored shells before activation" 60', '} "$Stage relaunch publishes its owned window and restored shells before activation" 1'],
    ['} "$Stage relaunch owns its published state after session restore" 60', '} "$Stage relaunch owns its published state after session restore" 1'],
    ["Snapshot 'failure'", "Snapshot 'ignored'"],
    ["($Name + '.focus.json')", "($Name + '.ignored.json')"],
    ["$bitmap.Save((Join-Path $Evidence ($Name + '.png'))", "$bitmap.Save((Join-Path $Evidence ($Name + '.ignored'))"],
  ]) {
    const broken = control.replace(before, after);
    assert.notEqual(broken, control);
    assert.throws(() => contract(broken));
  }
});

test('ISSUE-569 snapshots identify foreign foreground windows and preserve pre-close desktop ancestry', () => {
  function contract(driver) {
    const identity = driver.slice(driver.indexOf('    public static Dictionary<string, object> WindowIdentity('), driver.indexOf('    public static bool PaneVisible('));
    for (const required of [
      'uint ownerThread = GetWindowThreadProcessId(hwnd, out ownerPid);',
      '{ "handle", hwnd.ToInt64() }', '{ "pid", ownerPid }', '{ "thread", ownerThread }',
      '{ "class", Class(hwnd) }', '{ "title", Title(hwnd) }',
      '{ "root", GetAncestor(hwnd, 2).ToInt64() }',
      '{ "rootOwner", GetAncestor(hwnd, 3).ToInt64() }',
      '{ "visible", IsWindowVisible(hwnd) }',
      'public static List<Dictionary<string, object>> DesktopWindows()',
      'windows.Add(WindowIdentity(hwnd));', 'return true;', 'return windows;',
    ]) assert.ok(identity.includes(required), required);
    assert.doesNotMatch(identity, /SetForegroundWindow|SetFocus|ShowWindow|SendInput|Thread\.Sleep|if\s*\(/);
    const snapshot = driver.slice(driver.indexOf('function Snapshot('), driver.indexOf('function Assert-Foreground'));
    for (const required of [
      '$foreground = [VerifyNative]::GetForegroundWindow()',
      'foreground = $foreground.ToInt64()', 'capturedAt = [DateTime]::UtcNow.ToString(\'o\')',
      '$focus.foregroundWindow = [VerifyNative]::WindowIdentity($foreground)',
      '$focus.foregroundRoot = [VerifyNative]::WindowIdentity([VerifyNative]::GetAncestor($foreground, 2))',
      '$focus.foregroundRootOwner = [VerifyNative]::WindowIdentity([VerifyNative]::GetAncestor($foreground, 3))',
      '$focus.desktopWindows = @([VerifyNative]::DesktopWindows())',
      '$focus.processes = @(Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId, Name, CreationDate | Select-Object ProcessId, ParentProcessId, Name, CreationDate)',
      '$focus.foregroundError = $_.Exception.Message', '$focus.desktopError = $_.Exception.Message',
      '$focus.processError = $_.Exception.Message',
      "Save-Json $focus ($Name + '.focus.json')",
    ]) assert.ok(snapshot.includes(required), required);
    assert.ok(snapshot.indexOf('$focus.processes') < snapshot.indexOf('Save-Json $focus'));
    assert.ok(snapshot.indexOf('Save-Json $focus') < snapshot.indexOf('$element.FindAll'));
    assert.doesNotMatch(snapshot, /SetForegroundWindow|SetFocus|ShowWindow|Start-Process|Wait-Until|Start-Sleep|CommandLine|ExecutablePath/);
    assert.match(driver, /Snapshot 'before'/);
    const recipe = driver.slice(driver.indexOf("        'session-restore' {"), driver.indexOf("        'workspaces' {"));
    assert.match(recipe, /Snapshot 'action'\s+Restart-SessionRestore 'normal-close' \$false/);
    assert.match(driver, /try \{ Snapshot 'failure' \} catch/);
  }
  contract(control);
  for (const required of [
    '{ "pid", ownerPid }', '{ "class", Class(hwnd) }', '{ "title", Title(hwnd) }',
    '{ "root", GetAncestor(hwnd, 2).ToInt64() }', '{ "rootOwner", GetAncestor(hwnd, 3).ToInt64() }',
    'windows.Add(WindowIdentity(hwnd));', '$focus.foregroundWindow =', '$focus.foregroundRoot =',
    '$focus.foregroundRootOwner =', '$focus.desktopWindows =', '$focus.processes =',
    'Select-Object ProcessId, ParentProcessId, Name, CreationDate',
    '$focus.foregroundError =', '$focus.desktopError =', '$focus.processError =',
  ]) {
    const broken = control.replace(required, '');
    assert.notEqual(broken, control, required);
    assert.throws(() => contract(broken), assert.AssertionError);
  }
});

test('ISSUE-569 selection assertions resolve published active identity and require the original workspace', () => {
  const assertion = control.slice(control.indexOf('function Assert-SessionRestoreSelection('), control.indexOf('function Select-Theme('));
  function contract(source) {
    for (const required of [
      '$state = Read-Inbox', '$saved = Read-Session', '$_.sid -eq $state.active_shell_id',
      '$selected.Count -eq 1', '$selected[0].name -ceq $Name', '$selected[0].ws -eq $Workspace',
      '$state.active_workspace -eq $Workspace', '$saved.active_workspace -eq $Workspace',
      "$state.PSObject.Properties['starred_view']", "$saved.PSObject.Properties['starred_view']",
      '$state.starred_view -eq $Starred', '$saved.starred_view -eq $Starred',
      '$saved.workspaces[$Workspace].wid -ceq $WorkspaceId',
      '$saved.tabs[$saved.active_tab].name -ceq $Name', ").Count -eq 3",
    ]) assert.ok(source.includes(required), required);
    assert.doesNotMatch(source, /Set-Content|WriteAll|SetEnvironmentVariable|PostMessage|GetForegroundWindow|Assert-Foreground|\$saved\.active_shell_id\s*-eq\s*\$state\.active_shell_id/);
  }
  contract(assertion);
  assert.throws(() => contract(assertion.replace('$saved.tabs[$saved.active_tab].name -ceq $Name', '$saved.active_shell_id -eq $state.active_shell_id')));
  for (const required of ['$_.sid -eq $state.active_shell_id', '$selected[0].name -ceq $Name', '$state.active_workspace -eq $Workspace', '$saved.workspaces[$Workspace].wid -ceq $WorkspaceId']) {
    assert.throws(() => contract(assertion.replace(required, '$true')));
  }
  const publisher = read('src/inbox.zig');
  assert.match(publisher, /active_shell_id\\":\{d\},\\"active_workspace\\":\{d\}/);
  assert.match(publisher, /if \(app_state.active_shell < app_state.shell_count\) app_state.shells\[app_state.active_shell\].shell_id else 0/);
});

test('ISSUE-569 selection persistence is independent of deferred browser startup and stale snapshots', () => {
  function contract(session, console, cache, main) {
    const switching = console.slice(console.indexOf('pub fn switchToShell(idx:'), console.indexOf('var startup_completed:'));
    const save = switching.slice(switching.indexOf('    ensureActiveVisible();'), switching.indexOf('        app_state.shells[idx].notified = false;'));
    assert.match(save, /if \(!app_state.g_restoring and \(idx != prev or unarchived_on_open or/);
    assert.doesNotMatch(save, /defer_browser/);
    assert.doesNotMatch(save, /selected_shell_id\s*=/);
    const selectionSave = session.slice(session.indexOf('pub fn saveSession()'), session.indexOf('pub fn preserveFailedRemoteSavedTab('));
    assert.match(selectionSave, /if \(app_state.g_focus_user_action_tick != 0 and app_state.active_shell < app_state.shell_count\) \{/);
    assert.match(selectionSave, /selected_shell_id = shell_id/);
    assert.match(selectionSave, /selected_starred = app_state.g_starred_workspace/);
    assert.match(selectionSave, /else if \(!@import\("launch_cache.zig"\).tabs_restored\) return;/);
    assert.match(save, /saveSession\(\)/);
    const deferred = cache.slice(cache.indexOf('pub fn deferred('), cache.indexOf('pub fn closedDuringStartup('));
    assert.doesNotMatch(deferred, /selected_shell_id = state.shells\[state.active_shell\].shell_id/);
    assert.match(deferred, /shell.shell_id == selected_shell_id/);
    const persistence = session.slice(session.indexOf('pub fn saveSession()'), session.indexOf('pub fn preserveFailedRemoteSavedTab('));
    assert.doesNotMatch(persistence, /if \(@import\("launch_cache.zig"\).pending\) return;/);
    assert.match(session, /active_shell_id\\":\{d\}/);
    assert.match(session, /selectedSavedTab\(json, tabs\[0\.\.tab_count\]/);
    assert.match(session, /app_state.g_active_workspace = if \(restored_active_shell_id != 0 and app_state.active_shell < app_state.shell_count\)\s+app_state.shells\[app_state.active_shell\].workspace/);
    assert.match(session, /const live_shell_count = app_state.shell_count/);
    assert.match(session, /if \(idx < live_shell_count\)/);
    const close = main.slice(main.lastIndexOf('        WM_CLOSE =>'), main.lastIndexOf('        WM_DESTROY =>'));
    assert.match(close, /saveSession\(\);\s+launch_cache.finish\(\);[\s\S]*DestroyWindow\(hwnd\)/);
    assert.doesNotMatch(close, /app_state.active_shell\s*=|app_state.shell_count\s*=/);
    assert.match(close, /g_current_workspace_restore = app_state.g_quit_all_in_progress/);
  }
  const sources = [read('src/session.zig'), read('src/console.zig'), read('src/launch_cache.zig'), read('src/main.zig')];
  contract(...sources);
  for (const [file, before, after] of [
    [1, 'if (!app_state.g_restoring and (idx != prev or unarchived_on_open or', 'if (!defer_browser and !app_state.g_restoring and (idx != prev or unarchived_on_open or'],
    [0, '    logSessionAudit("saveSession:before-write");', '    if (@import("launch_cache.zig").pending) return;\n    logSessionAudit("saveSession:before-write");'],
    [2, '    if (cached) {\n', '    if (cached) {\n        selected_shell_id = state.shells[state.active_shell].shell_id;\n'],
    [0, 'if (idx < live_shell_count)', 'if (idx < app_state.shell_count)'],
    [3, '            saveSession();\n            launch_cache.finish();', '            app_state.active_shell = 0;\n            saveSession();\n            launch_cache.finish();'],
  ]) {
    const broken = [...sources];
    broken[file] = broken[file].replace(before, after);
    assert.notEqual(broken[file], sources[file]);
    assert.throws(() => contract(...broken));
  }
});


test('ISSUE-569 Starred restore persists the view and reuses the real workspace entry path', () => {
  function contract(session, inbox, workspaces) {
    const save = session.slice(session.indexOf('pub fn saveSessionTo('), session.indexOf('fn mergeStartupSelection('));
    assert.match(save, /!app_state.g_single_window or app_state.g_starred_workspace or app_state.shells\[i\].workspace == app_state.g_active_workspace/);
    assert.ok(save.includes('\\"starred_view\\":{}'));
    assert.match(save, /app_state.shells\[app_state.active_shell\].shell_id, app_state.g_starred_workspace/);
    const merge = session.slice(session.indexOf('fn mergeStartupSelection('), session.indexOf('fn selectedSavedTab('));
    assert.match(merge, /"starred_view", \.\{ \.bool = json_reader.boolTrue\(live.value, "starred_view"\) \}/);
    const view = session.slice(session.indexOf('fn restoreStarredView('), session.indexOf('pub fn saveSession()'));
    assert.match(view, /app_state.g_starred_workspace = false;/);
    assert.match(view, /if \(!starred or !app_state.g_single_window or app_state.active_shell >= app_state.shell_count\) return;/);
    assert.match(view, /if \(!@import\("workspaces.zig"\).starredShellVisible\(app_state.active_shell\)\) return;/);
    assert.match(view, /app_state.g_starred_last_shell = app_state.shells\[app_state.active_shell\].shell_id;/);
    assert.match(view, /@import\("workspaces.zig"\).switchToWorkspace\(@import\("workspace_view.zig"\).starred\);/);
    assert.doesNotMatch(view, /g_starred_workspace = true|SetTimer|focusActiveShell|loadInboxModel/);
    const restore = session.slice(session.indexOf('pub fn restoreSession()'), session.indexOf('test "', session.indexOf('pub fn restoreSession()')));
    assert.match(restore, /const restore_starred = savedStarredView\(json, tabs\[0\.\.tab_count\]\);/);
    assert.ok(restore.indexOf('const restore_starred =') < restore.indexOf('spawnSavedTab('));
    const source = session.slice(session.indexOf('fn savedStarredView('), session.indexOf('fn restoreStarredView('));
    assert.match(source, /selected_shell_id != 0/);
    assert.match(source, /selected_starred/);
    assert.match(source, /if \(!json_reader.boolTrue\(json, "starred_view"\)\) return false;/);
    assert.doesNotMatch(source, /g_starred_workspace/);
    assert.ok(restore.indexOf('restoreStarredView(restore_starred and (restored_active_shell_id != 0 or selected_live != 0));') > restore.indexOf('seedActiveWorkspaceLastShell('));
    assert.match(inbox, /active_workspace\\":\{d\},\\"starred_view\\":\{\}/);
    assert.match(inbox, /app_state.g_active_workspace,\s+app_state.g_starred_workspace,/);
    const entry = workspaces.slice(workspaces.indexOf('if (ws_in == @import("workspace_view.zig").starred)'), workspaces.indexOf('if (ws_in >= app_state.g_lws_count'));
    assert.match(entry, /if \(!app_state.g_restoring and app_state.g_chat_browser_swap.shell_id == 0\) saveSession\(\);/);
    for (const name of [
      'ISSUE-569 saved Starred view restores the same favorite session',
      'ISSUE-569 same favorite saved at home restores home instead of Starred',
      'ISSUE-569 saved Starred view falls back home when session is unfavorited',
    ]) assert.ok(session.includes(`test "${name}"`), name);
    const fixture = session.slice(session.indexOf('fn testStarredSelectionRoundTrip('), session.indexOf('test "ISSUE-569 filtered save'));
    for (const required of [
      'saveSessionTo(path, null)', 'selectedSavedTab(parsed.value, tabs[0..count], 0)',
      'json_reader.boolean(json_reader.field(parsed.value, "starred_view"), !saved_starred)',
      'restoreStarredView(savedStarredView(parsed.value, tabs[0..count]))',
      'saved_starred and favorite_on_restore, app_state.g_starred_workspace',
      '@as(u32, 42), app_state.shells[app_state.active_shell].shell_id',
      '@as(u8, 1), app_state.g_active_workspace',
      'testStarredSelectionRoundTrip(true, true, false)', 'testStarredSelectionRoundTrip(false, true, false)',
      'testStarredSelectionRoundTrip(true, false, false)',
    ]) assert.ok(fixture.includes(required), required);
    assert.match(session, /expect\(json_reader.boolTrue\(parsed.value, "starred_view"\)\)/);
    assert.match(session, /expect\(!json_reader.boolTrue\(new_parsed.value, "starred_view"\)\)/);
  }
  const sources = [read('src/session.zig'), read('src/inbox.zig'), read('src/workspaces.zig')];
  contract(...sources);
  for (const [file, before, after] of [
    [0, 'or app_state.g_starred_workspace or', 'or'],
    [0, ',\\"starred_view\\":{}', ''],
    [0, '.bool = json_reader.boolTrue(live.value, "starred_view")', '.bool = false'],
    [0, 'if (!@import("workspaces.zig").starredShellVisible(app_state.active_shell)) return;', ''],
    [0, 'app_state.g_starred_last_shell = app_state.shells[app_state.active_shell].shell_id;', ''],
    [0, 'restoreStarredView(restore_starred and (restored_active_shell_id != 0 or selected_live != 0));', ''],
    [1, ',\\"starred_view\\":{}', ''],
    [2, '        if (!app_state.g_restoring and app_state.g_chat_browser_swap.shell_id == 0) saveSession();', ''],
  ]) {
    const broken = [...sources];
    broken[file] = broken[file].replace(before, after);
    assert.notEqual(broken[file], sources[file], before);
    assert.throws(() => contract(...broken));
  }
});

test('ISSUE-569 journey restores the same favorite in Starred and at home with real keys', () => {
  function contract(driver) {
    const restart = driver.slice(driver.indexOf('function Restart-SessionRestore('), driver.indexOf('function Assert-SessionRestoreSelection('));
    assert.match(restart, /\$trace = \(\(Get-Content \$log -Raw\) -join ''\).Substring\(\$logStart\)/);
    assert.match(restart, /\$trace -match 'launch step=browser' -and \$trace -match 'installHook: KEYBOARD_LL installed'/);
    const recipe = driver.slice(driver.indexOf("        'session-restore' {"), driver.indexOf("        'workspaces' {"));
    assert.doesNotMatch(recipe, /SetForegroundWindow|GetFocusedWindow|Start-Sleep/);
    let offset = -1;
    for (const step of [
      "Press @(0x12, 0x53) 'Alt+S: favorite the middle restore session'", "'middle favorite persisted'",
      "Press @(0x12, 0x31) 'Alt+1: open the Starred workspace'", "Focus-Palette 'Restore middle' $middleIndex",
      "Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true",
      "Restart-SessionRestore 'normal-close' $false",
      "Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true",
      "name = 'starred-view-selection'",
      "'normal-close hook-ready owned foreground before workspace input'",
      "Press @([byte]0x12, [byte](0x32 + $workspace))",
      "'favorite home workspace active outside Starred before palette input'",
      "Focus-Palette 'Restore middle' $middleIndex",
      "Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $false",
      "Restart-SessionRestore 'favorite-home-kill' $true",
      "Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $false",
      "'same session remains a favorite at home after kill'",
      "'favorite-home-kill-after.inbox.json'", "'favorite-home-kill-after.session.json'",
      "name = 'favorite-home-selection'",
      "'favorite-home-kill hook-ready owned foreground before palette input'",
      "Restart-SessionRestore 'process-kill' $true",
      'if ($result.checks.Count -ne $requiredChecks.Count) { throw',
    ]) {
      const next = recipe.indexOf(step, offset + 1);
      assert.ok(next > offset, `missing or misordered ${step}`);
      offset = next;
    }
    for (const stage of ['normal-close', 'favorite-home-kill']) {
      assert.ok(recipe.includes(`Wait-Until {
                Doctor
                [VerifyNative]::GetAncestor([VerifyNative]::GetForegroundWindow(), 2) -eq $script:window
            } '${stage} hook-ready owned foreground before ${stage === 'normal-close' ? 'workspace' : 'palette'} input'`));
    }
    assert.ok(recipe.includes(`Wait-Until {
                $state = Read-Inbox
                $null -ne $state -and $state.active_workspace -eq $workspace -and $state.starred_view -eq $false
            } 'favorite home workspace active outside Starred before palette input'`));
    const assertion = driver.slice(driver.indexOf('function Assert-SessionRestoreSelection('), driver.indexOf('function Select-Theme('));
    for (const required of [
      '[bool]$Starred = $false', "$state.PSObject.Properties['starred_view']",
      "$saved.PSObject.Properties['starred_view']", '$state.starred_view -eq $Starred',
      '$saved.starred_view -eq $Starred',
    ]) assert.ok(assertion.includes(required), required);
  }
  contract(control);
  for (const required of [
    "Press @(0x12, 0x53) 'Alt+S: favorite the middle restore session'",
    "Press @(0x12, 0x31) 'Alt+1: open the Starred workspace'",
    "Press @([byte]0x12, [byte](0x32 + $workspace))",
    "Restart-SessionRestore 'favorite-home-kill' $true",
    "'normal-close hook-ready owned foreground before workspace input'",
    "'favorite-home-kill hook-ready owned foreground before palette input'",
    "'favorite home workspace active outside Starred before palette input'",
    "$trace -match 'installHook: KEYBOARD_LL installed'",
    '$null -ne $state -and $state.active_workspace -eq $workspace -and $state.starred_view -eq $false',
    '$state.starred_view -eq $Starred', '$saved.starred_view -eq $Starred',
    "name = 'starred-view-selection'", "name = 'favorite-home-selection'",
  ]) {
    const broken = control.replaceAll(required, '');
    assert.notEqual(broken, control);
    assert.throws(() => contract(broken));
  }
  const map = read(skill + 'features/session-restore.md');
  for (const required of ['starred-view-selection', 'favorite-home-selection', 'Alt+S', 'Alt+1', 'starred_view', 'favorite-home-kill-after']) {
    assert.ok(map.includes(required), required);
  }
});

test('ISSUE-569 Starred restore never queues a hide for its already selected console', () => {
  function contract(workspaces, session) {
    const start = workspaces.indexOf('    if (ws_in == @import("workspace_view.zig").starred)');
    const entry = workspaces.slice(start, workspaces.indexOf('    if (ws_in >= app_state.g_lws_count', start));
    assert.ok(start >= 0 && entry.length > 0);
    assert.match(entry, /if \(starredShellVisible\(i\) and app_state\.shells\[i\]\.shell_id == app_state\.g_starred_last_shell\) \{\s*if \(i != app_state\.active_shell\) switchToShell\(@intCast\(i\)\);\s*break;/);
    assert.match(entry, /refreshStarredWorkspace\(\);\s*if \(app_state\.active_shell < app_state\.shell_count\) \{\s*app_state\.g_starred_last_shell = app_state\.shells\[app_state\.active_shell\]\.shell_id;\s*focusActiveShell\(\);/);
    assert.match(entry, /parkMainWindowBeforeActiveShellRemoval\(app_state\.active_shell\)/);
    assert.ok(entry.indexOf('parkMainWindowBeforeActiveShellRemoval(') < entry.indexOf('switchToShell('));
    const restore = session.slice(session.indexOf('fn restoreStarredView('), session.indexOf('pub fn saveSession()'));
    assert.match(restore, /app_state\.g_starred_last_shell = app_state\.shells\[app_state\.active_shell\]\.shell_id;\s*@import\("workspaces.zig"\)\.switchToWorkspace\(@import\("workspace_view.zig"\)\.starred\);/);
    const unit = workspaces.slice(workspaces.indexOf('test "ISSUE-569 Starred entry keeps the selected session surface without a shell switch"'), workspaces.indexOf('pub fn copyBlueDotHookInstructions('));
    for (const observation of [
      'app_state.g_main_hwnd = null;', 'app_state.g_restoring = true;', 'for (0..2) |i|',
      'app_state.g_chat_browser_swap.request(app_state.shells[i].shell_id, 123);',
      'switchToWorkspace(@import("workspace_view.zig").starred);',
      'expectEqual(app_state.shells[i].shell_id, app_state.g_chat_browser_swap.shell_id)',
      'expectEqual(@as(u64, 123), app_state.g_chat_browser_swap.requested_at)',
    ]) assert.ok(unit.includes(observation), observation);
  }
  const sources = [read('src/workspaces.zig'), read('src/session.zig')];
  contract(...sources);
  for (const [file, before, after] of [
    [0, 'if (i != app_state.active_shell) switchToShell(@intCast(i));', 'switchToShell(@intCast(i));'],
    [0, 'if (i != app_state.active_shell)', 'if (i == app_state.active_shell)'],
    [0, '            focusActiveShell();', ''],
    [0, 'expectEqual(app_state.shells[i].shell_id, app_state.g_chat_browser_swap.shell_id)', 'expect(true)'],
    [1, 'app_state.g_starred_last_shell = app_state.shells[app_state.active_shell].shell_id;', ''],
  ]) {
    const broken = [...sources];
    if (file === 0 && before.trim() === 'focusActiveShell();') {
      const start = broken[0].indexOf('    if (ws_in == @import("workspace_view.zig").starred)');
      broken[0] = broken[0].slice(0, start) + broken[0].slice(start).replace(before, after);
    } else broken[file] = broken[file].replace(before, after);
    assert.notEqual(broken[file], sources[file], before);
    assert.throws(() => contract(...broken), assert.AssertionError, before);
  }
});

test('chat-delivery is an explicit saved-tmux boundary journey, not a live-delivery claim by the toggle journey', () => {
  assert.match(control, /ValidateSet\([^\n]*'chat-delivery'/);
  assert.match(workflow, /FEATURE -notin @\([^\n]*'chat-delivery'/);
  const dispatch = control.slice(control.indexOf("        'chat-delivery' {"), control.indexOf("        'safe-updates' {"));
  assert.match(dispatch, /verify-chat-delivery\/drive.ps1/);
  assert.match(dispatch, /ExpectedVersion \$ExpectedVersion -ExpectedHash \$ExpectedHash -Evidence \$Evidence/);
  assert.match(dispatch, /if \(\$LASTEXITCODE -ne 0\)/);
  assert.match(read(skill + 'features/README.md'), /\[Chat delivery\]\(chat-delivery.md\)/);
  assert.match(read(skill + 'features/chat-view.md'), /\[Chat delivery\]\(chat-delivery.md\)/);
  assert.match(read(skill + 'features/chat-delivery.md'), /production `ssh-path.txt` override/);
  assert.match(read(skill + 'features/chat-delivery.md'), /not real Claude or a real server/);
});

test('IGSH-599 local Chat View journey observes suggestion delivery and protects a typed draft', () => {
  const chat = control.slice(control.indexOf("        'chat-view' {"), control.indexOf("        'inbox' {"));
  const agent = read('tools/chat-local-agent.c');
  assert.match(workflow, /fromJSON\('\[[^'\n]*"chat-view"/);
  assert.match(workflow, /- tools\/chat-local-agent\.c/);
  assert.match(workflow, /if: env\.RELEASE_TAG == ''[^\n]*\|\| env\.FEATURE == 'chat-view'/);
  assert.match(workflow, /zig cc -target x86_64-windows-gnu -O2 tools\/chat-local-agent\.c -o verify-bin\/claude\.exe/);
  assert.match(workflow, /if \(\$LASTEXITCODE -ne 0\) \{ throw 'Local Claude console stand-in build failed' \}/);
  assert.match(chat, /foreach \(\$mode in @\('typed', 'suggestion'\)\)/);
  assert.match(chat, /Palette 'new cmd'[\s\S]*?Type-Text \('"' \+ \$localAgent/);
  assert.match(chat, /\$inbox = Read-Inbox[\s\S]*?\$_.sid -eq \$localState.tabs\[\$localTab\].shell_id[\s\S]*?\$_.ag -eq 1/);
  const detectionWait = chat.match(/\} 'local claude\.exe detected as Claude for the direct input route' -Seconds (\d+)\s*\n/);
  const normalNamePoll = read('src/power.zig').match(/\.normal\s*=>\s*setCoalescableTimerInterval\(hwnd, TIMER_NAME_POLL, ([\d_]+)\)/);
  assert.ok(detectionWait, 'local Claude detection wait must specify -Seconds');
  assert.ok(normalNamePoll, 'normal TIMER_NAME_POLL interval must be present');
  assert.ok(Number(detectionWait[1]) > Number(normalNamePoll[1].replaceAll('_', '')) / 1000, 'local Claude detection timeout must exceed one normal shell-name poll interval');
  assert.match(chat, /FocusedElement.Current.NativeWindowHandle -eq \$composer.Current.NativeWindowHandle/);
  const normalSend = /Type-Text \$message\s+if \(\$mode -eq 'suggestion'\) \{[\s\S]*?Press @\(0x11, 0x0D\) 'Ctrl\+Enter: send through normal Chat View outbox'\s+\} else \{\s+Press @\(0x0D\) 'Enter: send through normal Chat View outbox'/;
  assert.match(chat, normalSend);
  assert.doesNotMatch(chat.replace('Type-Text $message', 'Type-Text other'), normalSend);
  assert.match(chat, /\$composerHandle = \[VerifyNative\]::GetFocusedWindow\(\$script:window\)/);
  assert.match(chat, /GetAncestor\(\$composerHandle, 2\) -ne \$script:window -or \[VerifyNative\]::Class\(\$composerHandle\) -cne 'Edit'/);
  const stdinDelivery = /\[IO.File\]::Open\(\$prefix \+ '-stdin.bin', \[IO.FileMode\]::Open, \[IO.FileAccess\]::Read, \[IO.FileShare\]::ReadWrite\)[\s\S]*?\$stdin\.CopyTo\(\$buffer\)[\s\S]*?\$received = \[Text.Encoding\]::ASCII.GetString\(\$receivedBytes\)[\s\S]*?\$received -ceq \$wireMessage/;
  assert.ok(chat.includes("$wireMessage = ([string][char]27) + '[200~' + $message + ([string][char]27) + '[201~' + \"`r\""));
  assert.match(chat, stdinDelivery);
  assert.doesNotMatch(chat.replace('$received -ceq $wireMessage', '$true'), stdinDelivery);
  assert.doesNotMatch(chat.replace('[IO.FileShare]::ReadWrite', '[IO.FileShare]::Read'), stdinDelivery);
  const draftProtection = /finally \{[\s\S]*?\$typedCheck.receivedBytes = \(Get-Item \(\$typedPrefix \+ '-stdin.bin'\)\).Length[\s\S]*?\$_.t -ceq \$typedMessage -and \$_.s -eq 0 -and \$_.x -eq 0[\s\S]*?\$typedCheck.receivedBytes -eq 0 -and \$typedCheck.queued[\s\S]*?if \(-not \$typedCheck.passed\) \{ throw/;
  assert.match(chat, draftProtection);
  assert.doesNotMatch(chat.replace('$typedCheck.receivedBytes -eq 0', '$true'), draftProtection);
  for (const name of ['local-route-suggestion', 'local-route-typed']) {
    assert.match(chat, new RegExp(`name = '${name}'; passed = \\$false`));
    assert.ok(read(skill + 'features/chat-view.md').includes('`' + name + '`'));
  }
  assert.match(chat, /\$result.checks \+= \$typedCheck\s+\$result.checks \+= \$suggestionCheck/);
  assert.match(agent, /SetConsoleMode\(output, mode \| ENABLE_VIRTUAL_TERMINAL_PROCESSING\)/);
  assert.ok(agent.includes('L"\\x276f \\x1b[90m\\x1b[7mT\\x1b[27m\\x1b[2mry a suggested reply\\x1b[22m\\x1b[39m\\r\\x1b[2C"'));
  assert.ok(agent.includes('L"\\x276f user draft\\x1b[7m \\x1b[27m"'));
  assert.match(agent, /ReadConsoleOutputAttribute\(output, attributes, 32, origin/);
  assert.match(agent, /ReadConsoleInputW\(input, &record/);
  assert.match(agent, /fputc\(\(char\)c, received\)/);
  assert.match(agent, /fflush\(received\)/);
  assert.doesNotMatch(agent, /Sleep\(|SetConsoleTextAttribute|AttachConsole|CreateProcess/);
  assert.doesNotMatch(chat, /Start-Sleep|AddSeconds|Set-Content|WriteAll|PostMessage|Invoke-Zsb/);
});

test('IGSH-599 attribute classifier reads the trimmed prompt row and keeps four Zig regressions', () => {
  const send = read('src/chat_send.zig');
  const idle = send.slice(send.indexOf('fn chatInputRowIsIdle('), send.indexOf('test "Chat View idle input row detection"'));
  const capture = send.slice(send.indexOf('fn chatOutboxInputRowIdle('), send.indexOf('fn sendTextToShellVerifiedAt('));
  assert.match(idle, /row: \[\]const u16, attributes: \[\]const u16/);
  assert.match(idle, /if \(blank\) return true/);
  assert.match(idle, /attributes.len != row.len/);
  assert.match(idle, /attributes\[2\] & reverse_video == 0/);
  assert.match(idle, /default_foreground = attributes\[1\] & foreground_mask/);
  assert.match(idle, /if \(foreground == default_foreground or foreground != gray_foreground\) return false/);
  assert.doesNotMatch(idle, /app_state|ReadConsole|Sleep|GetTickCount/);
  assert.match(capture, /@intFromPtr\(line.ptr\) - @intFromPtr\(&app_state.g_chat_raw\[r \* width\]\)/);
  assert.match(capture, /\.x = @intCast\(column\), \.y = @intCast\(@as\(i32, start_row\) \+ @as\(i32, @intCast\(r\)\)\)/);
  assert.match(capture, /ReadConsoleOutputAttribute\(handle, attributes.ptr, @intCast\(line.len\), origin, &attributes_read\) == 0 or attributes_read != line.len/);
  assert.match(capture, /return chatInputRowIsIdle\(line, attributes\)/);
  assert.match(read('src/win32.zig'), /pub extern "kernel32" fn ReadConsoleOutputAttribute\(HANDLE, \[\*\]u16, DWORD, COORD, \*DWORD\) callconv\(WINAPI\) BOOL/);
  const cases = [...send.matchAll(/test "ISSUE-599 ([^"]+)"/g)].map(match => match[1]);
  assert.deepEqual(cases, [
    'suggestion row counts idle',
    'typed text row counts busy',
    'typed text with the inverse cursor after it counts busy',
    'blank row still idle',
  ]);
  assert.match(read('tools/chat-local-agent.c'), /WriteConsoleW\(output, clear,[^\n]+\n\s*CONSOLE_SCREEN_BUFFER_INFO info;\s*if \(!GetConsoleScreenBufferInfo\(output, &info\)\) return 4;\s*COORD origin = \{0, info.srWindow.Bottom\}/);
});

test('IGSH-612 palette-order journey seeds only the usage fixture and fails releases on the selected row', () => {
  assert.match(control, /ValidateSet\([^\n)]*'palette-order'/);
  assert.match(workflow, /\$env:FEATURE -notin @\([^\n)]*'palette-order'/);
  assert.match(workflow, /fromJSON\('\[[^\n]*"palette-order"[^\]]*\]'\)/);
  assert.match(control, /if \(\$Feature -eq 'palette-order'\) \{\s+\$config = Join-Path \$env:APPDATA 'ZigShell'\s+New-Item -ItemType Directory -Force \$config \| Out-Null\s+Copy-Item \$paletteUsageFixture \(Join-Path \$config 'palette-usage.tsv'\)\s+\}/);
  assert.ok(control.indexOf("Copy-Item $paletteUsageFixture") < control.indexOf('$job = New-Object VerifyJob'));
  const journey = control.slice(control.indexOf("        'palette-order' {"), control.indexOf("        'chat-view-everywhere' {"));
  assert.match(journey, /throw "palette-order: selected row \$selected, expected most used command/);
  assert.match(journey, /\$ids\[0\] -ne 'h0'/);
  assert.match(journey, /text = 'chat view per tab'; id = 0/);
  assert.match(journey, /text = 'copy shell diagnostics'; id = 6247/);
  assert.doesNotMatch(journey, /Set-Content|WriteAllText|WriteAllBytes|SetEnvironmentVariable|PostMessage|Copy-Item/);
  const fixture = read('tools/fixtures/IGSH-612/palette-usage.tsv').split('\r\n').filter(Boolean).map(line => line.split('\t'));
  assert.ok(fixture.length > 10);
  for (const [id, count, last] of fixture) {
    assert.match(id, /^\d+$/);
    assert.match(count, /^\d+$/);
    assert.match(last, /^\d+$/);
    assert.ok(!['6202', '6205'].includes(id));
  }
  assert.equal(new Set(fixture.map(([, count]) => count)).size, fixture.length);
  const map = read(skill + 'features/palette-order.md');
  for (const heading of ['## Sub-features', '## How to get to it (user POV)', '## Driving it with control.ps1', '## Gotchas']) assert.ok(map.includes(heading));
  assert.match(read(skill + 'features/README.md'), /\[Palette order\]\(palette-order.md\)/);
  assert.match(read(skill + 'SKILL.md'), /`palette-order`/);
});

test('IGSH-908 status-card journey keeps compact pages and proves the existing-style usage popup', () => {
  assert.match(control, /ValidateSet\([^\n)]*'status-card'/);
  assert.match(workflow, /\$env:FEATURE -notin @\([^\n)]*'status-card'/);
  assert.match(workflow, /fromJSON\('\[[^\n]*"status-card", "palette-order"[^\]]*\]'\)/);
  const journey = control.slice(control.indexOf("        'status-card' {"), control.indexOf("        'command-palette' {"));
  assert.ok(journey.length > 0);
  assert.match(journey, /foreach \(\$page in 0\.\.2\)/);
  assert.match(journey, /Press @\(0x11, 0x10, 0x47\)/);
  assert.match(journey, /roaming\/ZigShell\/sidebar-status-card\.txt/);
  assert.match(journey, /Measure-StatusCard \$shot/);
  assert.match(journey, /\$result\.statusCard = \[ordered\]@\{ heights = \$heights/);
  assert.match(journey, /if \(\$height -gt 30 -or \$height -lt 20\) \{ throw/);
  assert.match(journey, /IGSH-908: usage pill has no frame at the sidebar bottom/);
  for (const check of ['usage panel closes on second click', 'usage panel closes on Escape', 'usage panel closes on outside click']) assert.ok(journey.includes(check));
  assert.match(journey, /MenuLook/);
  assert.match(journey, /\$look\.cornerShown/);
  assert.match(journey, /usagePill = \$true/);
  assert.match(journey, /Snapshot 'pill-closed'/);
  assert.match(journey, /Snapshot 'pill-open'/);
  assert.match(control, /MultipromptUsageTelemetryLaunch/);
  assert.match(control, /IGSH-908\/usage-telemetry\.json/);
  assert.doesNotMatch(journey, /Set-Content|WriteAllText|WriteAllBytes|SetEnvironmentVariable|PostMessage|Copy-Item/);
  const measure = control.slice(control.indexOf('function Measure-StatusCard('), control.indexOf('function Sidebar-Luminance('));
  assert.match(measure, /GetDpiForWindow\(\$script:window\)/);
  assert.match(measure, /\$scale = \$dpi \/ 96\.0/);
  assert.match(measure, /height = \[Math\]::Round\(\$pixels \/ \$scale, 1\)/);
  assert.match(control, /public static void MoveMouseClient\(IntPtr hwnd, int x, int y, bool requireOwned\)/);
  const map = read(skill + 'features/status-card.md');
  for (const heading of ['## Sub-features', '## How to get to it (user POV)', '## Driving it with control.ps1', '## Gotchas']) assert.ok(map.includes(heading));
  assert.match(map, /v0\.28\.839/);
  assert.match(read(skill + 'features/README.md'), /\[Status card\]\(status-card.md\)/);
  assert.match(read(skill + 'SKILL.md'), /`status-card`/);
  assert.ok(read(skill + 'coverage.md').includes('| IGSH-673 |'));
});

test('ISSUE-569 grouped restore journey splits a real home group before every targeted restart', () => {
  function contract(driver, map) {
    const recipe = driver.slice(driver.indexOf("        'session-restore' {"), driver.indexOf("        'workspaces' {"));
    let offset = -1;
    for (const step of [
      "Focus-Palette 'tab order' 6217", "Press @(0x11, 0x4E) 'Ctrl+N:",
      "@('Restore first', 'Restore middle', 'Restore last')", 'if ($i -lt 2)',
      "Focus-Palette 'move to group' 6301", "{ 'new group' } else { 'Group 1' }",
      '{ 6303 } else { 6320 }', 'Type-Text $groupQuery', "'group submenu query selects the existing UI action'",
      "'home group membership persisted through real palette input'", 'if ($i -ne 1)',
      "'reorder companion favorite persisted'", "'middle favorite persisted'",
      "Prepare-SessionRestoreGroupOrder 'update-restart'", "Restart-SessionRestore 'update-restart' $false $true",
      "Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true",
      "Prepare-SessionRestoreGroupOrder 'normal-close'", "Restart-SessionRestore 'normal-close' $false",
      "Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true",
      "foreach ($stage in @('favorite-cross-workspace-close', 'favorite-cross-workspace-kill'))",
      'Prepare-SessionRestoreGroupOrder $stage', "Restart-SessionRestore $stage ($stage -eq 'favorite-cross-workspace-kill')",
      "Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true",
    ]) {
      const next = recipe.indexOf(step, offset + 1);
      assert.ok(next > offset, `missing or misordered ${step}`);
      offset = next;
    }
    const prepare = driver.slice(driver.indexOf('function Prepare-SessionRestoreGroupOrder('), driver.indexOf('function Restart-SessionRestore('));
    for (const required of [
      "if (-not $saved.starred_view -or $tabs[$middle].name -cne 'Restore middle') { throw",
      "$tabs[$first].group_id -eq 0 -or $tabs[$first].group_id -ne $tabs[$middle].group_id",
      "$tabs[$last].PSObject.Properties['group_id']", "$tabs[$middle].PSObject.Properties['starred_group_id']",
      "$tabs[$last].PSObject.Properties['starred_group_id']", 'if ($middle + 1 -eq $last)',
      "Press @(0x11, 0x10, 0x28) 'Ctrl+Shift+Down:", 'elseif ($last + 1 -ne $middle)',
      "$tabs[$middle].name -ceq 'Restore middle'", "$tabs[$middle - 1].name -ceq 'Restore last'",
      "$tabs[$middle - 2].name -ceq 'Restore first'", '$tabs[$middle - 2].group_id -eq $tabs[$middle].group_id',
      "-not $tabs[$middle - 1].PSObject.Properties['group_id']", "$selected[0].name -ceq 'Restore middle'",
      'savedIndex = $middle; normalizedIndex = ($middle - 1)', "($Stage + '-group-order.json')",
    ]) assert.ok(prepare.includes(required), required);
    assert.doesNotMatch(prepare + recipe, /Set-Content|WriteAll|PostMessage|Start-Sleep|session\.json\.launch\.json|keep_alive\s*=/);
    const setup = recipe.slice(0, recipe.indexOf('            $tabs = @((Read-Session).tabs)'));
    assert.match(setup, /\$saved.PSObject.Properties\['groups'\]/);
    assert.match(setup, /\$_.PSObject.Properties\['group_id'\] -and \$_.group_id -eq \$saved.groups\[0\].id/);
    for (const word of ['Ctrl+Shift+Down', 'group_id', 'saved index minus one', 'PID zero', 'skip normalization', 'both app commits']) assert.ok(map.includes(word), word);
  }
  const map = read(skill + 'features/session-restore.md');
  contract(control, map);
  for (const required of [
    "Focus-Palette 'tab order' 6217", "Focus-Palette 'move to group' 6301",
    "{ 'new group' } else { 'Group 1' }", "'home group membership persisted through real palette input'",
    "'reorder companion favorite persisted'", "Press @(0x11, 0x10, 0x28) 'Ctrl+Shift+Down:",
    "$tabs[$middle - 1].name -ceq 'Restore last'", '$tabs[$middle - 2].group_id -eq $tabs[$middle].group_id',
    "Prepare-SessionRestoreGroupOrder 'update-restart'", "Prepare-SessionRestoreGroupOrder 'normal-close'",
    'Prepare-SessionRestoreGroupOrder $stage', "$tabs[$last].PSObject.Properties['starred_group_id']",
  ]) {
    const broken = control.replaceAll(required, '');
    assert.notEqual(broken, control, required);
    assert.throws(() => contract(broken, map), assert.AssertionError, required);
  }
});

test('ISSUE-569 local CMD restore has PID zero until UI completion, and split-group normalization changes the selected index', () => {
  function timing(consoleSource, session, main, cache) {
    const spawn = consoleSource.slice(consoleSource.indexOf('pub fn spawnShellWithSession('), consoleSource.indexOf('pub fn respawnShellInPlace('));
    assert.match(spawn, /var pi = std.mem.zeroes\(PROCESS_INFORMATION\);/);
    assert.match(spawn, /const asynchronous = @import\("launch_cache.zig"\).pending or app_state.g_account_applying;/);
    assert.match(spawn, /if \(!asynchronous and CreateProcessW\([^;]+&pi\)/);
    assert.match(spawn, /\.console_inflight = asynchronous,[\s\S]*?\.pid = pi.dwProcessId,/);
    const worker = consoleSource.slice(consoleSource.indexOf('fn startupShellWorker('), consoleSource.indexOf('fn discardStartupShell('));
    assert.match(worker, /job.pid = pi.dwProcessId;/);
    assert.match(worker, /PostMessageW\(job.owner, WM_STARTUP_SHELL_READY/);
    assert.doesNotMatch(worker, /app_state.shells\[[^\]]+\]\.pid\s*=/);
    const finish = consoleSource.slice(consoleSource.indexOf('pub fn finishStartupShell('));
    assert.match(finish, /app_state.shells\[idx\].console_inflight = false;/);
    assert.match(finish, /app_state.shells\[idx\].pid = job.pid;/);
    assert.match(main, /if \(msg == WM_TIMER and wp == @import\("console.zig"\).TIMER_STARTUP_SHELL\)/);
    assert.match(main, /launch_cache.deferred\(\);[\s\S]*?const restored = restoreSession\(\);/);
    assert.match(cache, /pub fn begin\(\) void \{\s*pending = true;/);
    const restore = session.slice(session.indexOf('pub fn restoreSession()'), session.indexOf('fn writeStartupLastgood('));
    let offset = -1;
    for (const step of ['for (0..tab_count) |t|', 'spawnSavedTab(&tabs[t]', 'findShellById(restored_active_shell_id)', 'normalizeGroupOrder();']) {
      const next = restore.indexOf(step, offset + 1);
      assert.ok(next > offset, `missing or misordered ${step}`);
      offset = next;
    }
    assert.doesNotMatch(restore, /DispatchMessage|PeekMessage|GetMessage|finishStartupShell/);
  }
  const sources = ['src/console.zig', 'src/session.zig', 'src/main.zig', 'src/launch_cache.zig'].map(read);
  timing(...sources);
  for (const [index, required] of [
    [0, 'var pi = std.mem.zeroes(PROCESS_INFORMATION);'],
    [0, 'const asynchronous = @import("launch_cache.zig").pending or app_state.g_account_applying;'],
    [0, 'app_state.shells[idx].pid = job.pid;'], [1, 'normalizeGroupOrder();'],
  ]) {
    const broken = [...sources];
    broken[index] = broken[index].replaceAll(required, '');
    assert.notEqual(broken[index], sources[index], required);
    assert.throws(() => timing(...broken), assert.AssertionError, required);
  }
  const sidebar = read('src/sidebar.zig');
  const normalize = sidebar.slice(sidebar.indexOf('pub fn normalizeGroupOrder()'), sidebar.indexOf('pub fn applyPendingGroup()'));
  assert.match(normalize, /if \(app_state.g_starred_workspace\) return;/);
  assert.match(normalize, /tmp\[written\] = app_state.shells\[i\];[\s\S]*?const gid = app_state.shells\[i\].group_id;[\s\S]*?if \(gid == 0\) continue;/);
  assert.match(normalize, /if \(app_state.shells\[j\].group_id == gid\) \{\s*tmp\[written\] = app_state.shells\[j\];/);
  const rows = [
    { name: 'A', group: 0 }, { name: 'Restore first', group: 7 },
    { name: 'Restore last', group: 0 }, { name: 'Restore middle', group: 7 },
  ].map((row, i) => ({ ...row, pid: 0, shell_id: i + 101, console_inflight: true }));
  function normalized(input) {
    const result = [];
    for (const row of input) {
      if (result.includes(row)) continue;
      result.push(row);
      if (row.group) for (const member of input) if (member.group === row.group && !result.includes(member)) result.push(member);
    }
    return result;
  }
  const ordered = normalized(rows);
  const selected = rows[3];
  assert.deepEqual(ordered.map(row => row.name), ['A', 'Restore first', 'Restore middle', 'Restore last']);
  assert.equal(ordered.indexOf(selected), 2);
  assert.equal(ordered[3].name, 'Restore last');
  assert.equal(selected.pid, 0);
  assert.equal(ordered.findIndex(row => row.shell_id === selected.shell_id), 2);
  assert.deepEqual(normalized(rows.map(row => ({ ...row, group: 0 }))).map(row => row.name), rows.map(row => row.name));
});

test('ISSUE-569 cross-workspace favorite journey requires the saved pair on close and kill', () => {
  function contract(driver, map) {
    const recipe = driver.slice(driver.indexOf("        'session-restore' {"), driver.indexOf("        'workspaces' {"));
    const cross = recipe.slice(recipe.indexOf("            foreach ($stage in @('favorite-cross-workspace-close'"));
    let offset = -1;
    for (const step of [
      "foreach ($stage in @('favorite-cross-workspace-close', 'favorite-cross-workspace-kill'))",
      'Doctor', "Press @(0x12, 0x32) 'Alt+2:",
      '$state.active_workspace -eq 0', '$saved.active_workspace -eq 0',
      '$state.starred_view -eq $false -and $saved.starred_view -eq $false',
      "Press @(0x12, 0x31) 'Alt+1: open Starred from workspace A'",
      "Focus-Palette 'Restore middle' $middleIndex",
      "Press @(0x0D) 'Enter: select the workspace B favorite by name in Starred'",
      "Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true",
      "Restart-SessionRestore $stage ($stage -eq 'favorite-cross-workspace-kill')",
      "Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true",
      '$_.workspace -eq $workspace -and $_.favorite -eq $true',
      "($stage + '-after.inbox.json')", "($stage + '-after.session.json')", "Snapshot ($stage + '-after')",
      "name = 'favorite-cross-workspace-selection'",
      "$requiredChecks = @('normal-close-selection', 'starred-view-selection', 'favorite-home-selection', 'process-kill-selection', 'favorite-cross-workspace-selection', 'update-restart-selection')",
      'foreach ($check in $requiredChecks)',
      'if (@($result.checks | Where-Object { $_.name -ceq $check }).Count -ne 1) { throw',
      'if ($result.checks.Count -ne $requiredChecks.Count) { throw',
    ]) {
      const next = cross.indexOf(step, offset + 1);
      assert.ok(next > offset, `missing or misordered ${step}`);
      offset = next;
    }
    assert.match(recipe, /if \(\$workspace -eq 0 -or \[string\]::IsNullOrWhiteSpace\(\$workspaceId\)\) \{ throw/);
    assert.doesNotMatch(recipe, /Set-Content|WriteAll|PostMessage|Start-Sleep/);
    const restart = driver.slice(driver.indexOf('function Restart-SessionRestore('), driver.indexOf('function Assert-SessionRestoreSelection('));
    assert.doesNotMatch(restart, /session\.json\.launch\.json|\$launch\.starred|\$launch\.active/);
    assert.ok(driver.indexOf("name = 'favorite-cross-workspace-selection'") < driver.indexOf("    $result.status = 'passed'"));
    for (const word of ['favorite-cross-workspace-selection', 'workspace A', 'workspace B', 'starred_view', 'launch snapshot', 'all six checks']) assert.ok(map.includes(word), word);
  }
  const map = read(skill + 'features/session-restore.md');
  contract(control, map);
  for (const required of [
    "'favorite-cross-workspace-close', 'favorite-cross-workspace-kill'",
    "Press @(0x12, 0x32) 'Alt+2: open workspace A, not the favorite home workspace B'",
    "Press @(0x12, 0x31) 'Alt+1: open Starred from workspace A'",
    "Press @(0x0D) 'Enter: select the workspace B favorite by name in Starred'",
    "Restart-SessionRestore $stage ($stage -eq 'favorite-cross-workspace-kill')",
    '$_.workspace -eq $workspace -and $_.favorite -eq $true',
    "name = 'favorite-cross-workspace-selection'",
    'if (@($result.checks | Where-Object { $_.name -ceq $check }).Count -ne 1) { throw',
  ]) {
    const broken = control.replaceAll(required, '');
    assert.notEqual(broken, control, required);
    assert.throws(() => contract(broken, map));
  }
  assert.throws(() => contract(control, map.replaceAll('favorite-cross-workspace-selection', '')));
});


test('ISSUE-569 updater restart uses the real helper and judges only the restored view and session', () => {
  function contract(driver, map) {
    const restart = driver.slice(driver.indexOf('function Restart-SessionRestore('), driver.indexOf('function Assert-SessionRestoreSelection('));
    let offset = -1;
    for (const step of [
      '[bool]$Updater = $false', '$oldPid = $process.Id', 'if ($Updater) {',
      '$nextJob = New-Object VerifyJob',
      "$helper = $nextJob.Start($Exe, $scratch, (Join-Path $Evidence ($Stage + '-stdout.log')), (Join-Path $Evidence ($Stage + '-stderr.log')), ('--relaunch-after ' + $oldPid))",
      '$process.CloseMainWindow()', '$process.WaitForExit(20000)', '$job.Stop()',
      '$candidateWindow = [IntPtr]([long]$state.hwnd)',
      '[VerifyNative]::GetWindowThreadProcessId($candidateWindow, [ref]$owner)',
      '$owner -eq $oldPid -or $owner -eq $helper.Id',
      '$candidate = Get-Process -Id $owner',
      '$nextJob.Contains($candidate) -or $candidate.Path -ne $Exe',
      '$script:process = $candidate', '$helper.WaitForExit(20000)',
      '$script:job = $nextJob', '$nextJob = $null',
      "$trace -match 'launch step=browser' -and $trace -match 'installHook: KEYBOARD_LL installed'",
      'if ($null -ne $nextJob)', '$nextJob.Stop()', '$nextJob.Dispose()',
    ]) {
      const next = restart.indexOf(step, offset + 1);
      assert.ok(next > offset, `missing or misordered ${step}`);
      offset = next;
    }
    assert.match(driver, /Check\(IsProcessInJob\(process.Handle, job, out result\)\);\s*return result;/);
    const updater = restart.slice(restart.indexOf('    if ($Updater) {', restart.indexOf('$script:window = [IntPtr]::Zero')), restart.indexOf('    } else {', restart.indexOf('$script:window = [IntPtr]::Zero')));
    assert.doesNotMatch(updater, /\.Start\(|Stop-Process/);
    assert.doesNotMatch(restart, /session\.json\.launch\.json|\$launch\.starred|\$launch\.active/);
    const recipe = driver.slice(driver.indexOf("        'session-restore' {"), driver.indexOf("        'workspaces' {"));
    offset = -1;
    for (const step of [
      "Press @(0x12, 0x32) 'Alt+2: open workspace A before updater restart'",
      '$state.active_workspace -eq 0', '$saved.active_workspace -eq 0',
      "Press @(0x12, 0x31) 'Alt+1: open Starred from workspace A before updater restart'",
      "Focus-Palette 'Restore middle' $middleIndex",
      "Press @(0x0D) 'Enter: select the workspace B favorite by name before updater restart'",
      "Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true",
      "Restart-SessionRestore 'update-restart' $false $true",
      "Assert-SessionRestoreSelection 'Restore middle' $workspace $workspaceId $true",
      "'updater favorite retains its original home and favorite flag'",
      "'update-restart-after.inbox.json'", "'update-restart-after.session.json'", "Snapshot 'update-restart-after'",
      "name = 'update-restart-selection'", "Restart-SessionRestore 'normal-close' $false",
    ]) {
      const next = recipe.indexOf(step, offset + 1);
      assert.ok(next > offset, `missing or misordered ${step}`);
      offset = next;
    }
    assert.match(recipe, /\$requiredChecks = @\([^\n]*'update-restart-selection'\)/);
    const selection = driver.slice(driver.indexOf('function Assert-SessionRestoreSelection('), driver.indexOf('function Select-Theme('));
    for (const observation of [
      '$_.sid -eq $state.active_shell_id', '$selected[0].name -ceq $Name',
      '$saved.tabs[$saved.active_tab].name -ceq $Name',
      '$state.starred_view -eq $Starred', '$saved.starred_view -eq $Starred',
    ]) assert.ok(selection.includes(observation), observation);
    for (const word of ['update-restart-selection', '--relaunch-after', 'WM_CLOSE', 'No launch-snapshot schema assertion', 'all six checks']) assert.ok(map.includes(word), word);
  }
  const map = read(skill + 'features/session-restore.md');
  contract(control, map);
  for (const required of [
    "('--relaunch-after ' + $oldPid)", '$nextJob.Contains($candidate)',
    '$candidate.Path -ne $Exe', '$script:process = $candidate',
    "Restart-SessionRestore 'update-restart' $false $true", "name = 'update-restart-selection'",
    '$saved.tabs[$saved.active_tab].name -ceq $Name', '$state.starred_view -eq $Starred',
    '$saved.starred_view -eq $Starred', 'Check(IsProcessInJob(process.Handle, job, out result));',
  ]) {
    const broken = control.replace(required, '');
    assert.notEqual(broken, control, required);
    assert.throws(() => contract(broken, map), assert.AssertionError, required);
  }
  const coupled = control.replace('    $oldPid = $process.Id', "    $launch = Get-Content 'session.json.launch.json'\n    $oldPid = $process.Id");
  assert.throws(() => contract(coupled, map), assert.AssertionError);
  assert.throws(() => contract(control, map.replaceAll('update-restart-selection', '')), assert.AssertionError);
});


test('ISSUE-569 fast and deferred restore keep the authoritative view and session paired', () => {
  function contract(snapshot, cache, session, console) {
    const schema = snapshot.slice(snapshot.indexOf('pub const Snapshot = struct'), snapshot.indexOf('pub fn encode('));
    assert.match(schema, /starred: bool = false,/);
    const restoreCache = cache.slice(cache.indexOf('pub fn restore()'), cache.indexOf('pub fn painted('));
    assert.match(restoreCache, /state.g_starred_workspace = s.starred;/);
    assert.doesNotMatch(restoreCache, /selected_shell_id\s*=/);
    const saveCache = cache.slice(cache.indexOf('pub fn save()'), cache.indexOf('test "'));
    assert.match(saveCache, /\.starred = state.g_starred_workspace,/);
    assert.match(saveCache, /\.active = state.shells\[state.active_shell\].shell_id,/);
    const save = session.slice(session.indexOf('pub fn saveSession()'), session.indexOf('pub fn preserveFailedRemoteSavedTab('));
    assert.match(save, /if \(@import\("launch_cache.zig"\).pending\) \{\s*if \(app_state.g_focus_user_action_tick != 0 and app_state.active_shell < app_state.shell_count\) \{/);
    assert.match(save, /selected_shell_id = shell_id;\s*@import\("launch_cache.zig"\).selected_starred = app_state.g_starred_workspace;/);
    assert.match(save, /selected_live_shell_id = if \(@import\("launch_cache.zig"\).tabs_restored or !@import\("launch_cache.zig"\).cachedShell\(shell_id\)\) shell_id else 0;/);
    assert.match(save, /else if \(!@import\("launch_cache.zig"\).tabs_restored\) return;/);
    assert.ok(save.indexOf('else if (!@import("launch_cache.zig").tabs_restored) return;') < save.indexOf('saveSessionTo('));
    const switching = console.slice(console.indexOf('pub fn switchToShell(idx:'), console.indexOf('var startup_completed:'));
    assert.doesNotMatch(switching, /selected_shell_id\s*=/);
    const view = session.slice(session.indexOf('fn savedStarredView('), session.indexOf('fn restoreStarredView('));
    assert.match(view, /pending and @import\("launch_cache.zig"\).selected_shell_id != 0/);
    assert.match(view, /if \(@import\("launch_cache.zig"\).selected_live_shell_id != 0\) return @import\("launch_cache.zig"\).selected_starred;/);
    assert.match(view, /if \(tab.shell_id == @import\("launch_cache.zig"\).selected_shell_id\) return @import\("launch_cache.zig"\).selected_starred;/);
    assert.match(view, /if \(!json_reader.boolTrue\(json, "starred_view"\)\) return false;/);
    assert.match(view, /return selectedSavedTab\(json, tabs, 0\) != null;/);
    assert.doesNotMatch(view, /g_starred_workspace/);
    const restore = session.slice(session.indexOf('pub fn restoreSession()'), session.indexOf('test "', session.indexOf('pub fn restoreSession()')));
    assert.match(restore, /const restore_starred = savedStarredView\(json, tabs\[0\.\.tab_count\]\);/);
    assert.ok(restore.indexOf('const restore_starred =') < restore.indexOf('spawnSavedTab('));
    assert.match(restore, /restoreStarredView\(restore_starred and \(restored_active_shell_id != 0 or selected_live != 0\)\);/);
    for (const name of [
      'ISSUE-569 launch snapshot round trips the Starred selection pair',
      'ISSUE-569 legacy launch snapshot without Starred decodes as false',
    ]) assert.ok(snapshot.includes(`test "${name}"`), name);
    assert.match(snapshot, /for \(\[_\]bool\{ false, true \}\) \|starred\|/);
    assert.match(snapshot, /expectEqual\(starred, parsed.value.starred\)/);
    assert.match(snapshot, /expect\(!parsed.value.starred\)/);
    for (const name of [
      'ISSUE-569 Starred saved with the favorite in a non-active workspace restores Starred',
      'ISSUE-569 saved view and selected session use the same source during startup',
    ]) assert.ok(session.includes(`test "${name}"`), name);
    assert.ok(session.includes('@as(u64, if (saved_starred) 0 else 1), json_reader.uint(parsed.value, "active_workspace")'));
    assert.ok(session.includes('@as(u8, 1), tabs[selected].workspace'));
    assert.ok(session.includes('try testStarredSelectionRoundTrip(true, true, true);'));
    assert.ok(session.includes('selected_shell_id = if (startup_user_selection) tabs[selected].shell_id else 0;'));
    assert.ok(session.includes('restoreStarredView(savedStarredView(parsed.value, tabs[0..count]))'));
  }
  const sources = [read('src/launch_snapshot.zig'), read('src/launch_cache.zig'), read('src/session.zig'), read('src/console.zig')];
  contract(...sources);
  for (const [file, before, after] of [
    [0, '    starred: bool = false,', ''],
    [1, '    state.g_starred_workspace = s.starred;', ''],
    [1, '        .starred = state.g_starred_workspace,', ''],
    [1, '    const s = parsed.value;', '    const s = parsed.value;\n    selected_shell_id = s.active;'],
    [2, 'app_state.g_focus_user_action_tick != 0 and app_state.active_shell < app_state.shell_count', 'app_state.active_shell < app_state.shell_count'],
    [2, 'selected_starred = app_state.g_starred_workspace;', 'selected_starred = false;'],
    [2, 'else if (!@import("launch_cache.zig").tabs_restored) return;', ''],
    [2, 'return @import("launch_cache.zig").selected_starred;', 'return app_state.g_starred_workspace;'],
    [2, 'if (tab.shell_id == @import("launch_cache.zig").selected_shell_id)', 'if (true)'],
    [2, 'return selectedSavedTab(json, tabs, 0) != null;', 'return true;'],
    [2, '    const restore_starred = savedStarredView(json, tabs[0..tab_count]);', ''],
    [3, '        saveSession();\n    }\n    if (idx < app_state.shell_count)', '        @import("launch_cache.zig").selected_shell_id = app_state.shells[idx].shell_id;\n        saveSession();\n    }\n    if (idx < app_state.shell_count)'],
  ]) {
    const broken = [...sources];
    broken[file] = broken[file].replace(before, after);
    assert.notEqual(broken[file], sources[file], before);
    assert.throws(() => contract(...broken), assert.AssertionError, before);
  }
});


test('ISSUE-569 respawn selection survives PID-zero normalization and automatic refresh', () => {
  function contract(sidebar, session) {
    const consoleSource = read('src/console.zig');
    const complete = consoleSource.slice(consoleSource.indexOf('pub fn finishStartupShell('));
    assert.doesNotMatch(complete, /active_shell\s*=|switchToShell/);
    const normalize = sidebar.slice(sidebar.indexOf('pub fn normalizeGroupOrder()'), sidebar.indexOf('pub fn applyPendingGroup()'));
    assert.match(normalize, /const active_id = if \(app_state.active_shell < app_state.shell_count\) app_state.shells\[app_state.active_shell\].shell_id else 0;/);
    assert.match(normalize, /if \(active_id != 0\)/);
    assert.match(normalize, /if \(app_state.shells\[k\].shell_id == active_id\) \{\s*app_state.active_shell = k;/);
    assert.doesNotMatch(normalize, /\.pid|active_pid/);
    const savedView = session.slice(session.indexOf('fn savedStarredView('), session.indexOf('fn restoreStarredView('));
    assert.match(savedView, /return selectedSavedTab\(json, tabs, 0\) != null;/);
    const regression = session.slice(session.indexOf('test "ISSUE-569 respawned selection'), session.indexOf('test "ISSUE-569 saved view and selected session use'));
    for (const name of ['First', 'Selected', 'Middle', 'Winner']) assert.ok(regression.includes(`\\"name\\":\\"${name}\\"`), name);
    for (const observation of [
      'ISSUE-569 respawned selection falls back to saved index and tmux identity before group normalization',
      'for ([_]u32{ 896, 999 }) |saved_id|', 'const selected = selectedSavedTab(parsed.value, tabs[0..count], 0).?;',
      'expectEqual(@as(u32, 3), selected)', 'expect(savedStarredView(parsed.value, tabs[0..count]))',
      'const restored_shell_ids = [_]u32{ 913, 0, 914, 915 };', 'console_inflight = true;',
      'expect(findShellById(saved_id) == null)', 'findShellById(restored_shell_ids[selected]).?',
      'group_id = if (i == 1) 0 else 7;', 'normalizeGroupOrder();\n        try std.testing.expectEqual(@as(u32, 1)',
      'expectEqual(@as(u32, 1), app_state.active_shell)',
      'expectEqual(@as(DWORD, 0), app_state.shells[app_state.active_shell].pid)',
      'ISSUE-569 automatic Starred refresh after respawn keeps the restored session without input',
      'app_state.g_starred_last_shell = 915;', 'app_state.g_focus_user_action_tick = 0;',
      '@import("workspaces.zig").refreshStarredWorkspace();',
      'expectEqual(@as(u32, 915), app_state.shells[app_state.active_shell].shell_id)',
      'expectEqual(@as(u8, 1), app_state.shells[app_state.active_shell].workspace)',
      'expect(app_state.g_starred_workspace)',
    ]) assert.ok(regression.includes(observation), observation);
    const restore = session.slice(session.indexOf('pub fn restoreSession()'), session.indexOf('fn writeStartupLastgood('));
    assert.ok(restore.indexOf('findShellById(restored_active_shell_id)') < restore.indexOf('normalizeGroupOrder();'));
  }
  const sidebar = read('src/sidebar.zig');
  const session = read('src/session.zig');
  contract(sidebar, session);
  const before = read('tools/fixtures/igsh-569/normalize-before.zig');
  assert.throws(() => contract(before, session), assert.AssertionError);
  for (const [source, old, replacement] of [
    [0, 'if (active_id != 0)', 'if (false)'],
    [0, 'shells[k].shell_id == active_id', 'shells[k].pid == active_id'],
    [1, 'return selectedSavedTab(json, tabs, 0) != null;', 'return false;'],
    [1, 'normalizeGroupOrder();\n        try std.testing.expectEqual(@as(u32, 1)', 'try std.testing.expectEqual(@as(u32, 1)'],
    [1, '@import("workspaces.zig").refreshStarredWorkspace();', ''],
  ]) {
    const broken = [sidebar, session];
    broken[source] = broken[source].replace(old, replacement);
    assert.notEqual(broken[source], [sidebar, session][source], old);
    assert.throws(() => contract(...broken), assert.AssertionError, old);
  }
});

test('IGSH-678 chat code font journey measures real console code and names every check', () => {
  const code = control.slice(control.indexOf("        'chat-code-font' {"), control.indexOf("        'sessions' {"));
  assert.match(control, /ValidateSet\([^\n)]*'chat-code-font'/);
  assert.match(workflow, /\$env:FEATURE -notin @\([^\n)]*'chat-code-font'/);
  assert.match(workflow, /if: env\.FEATURE == 'chat-code-font' && env\.RELEASE_TAG == ''/);
  assert.match(workflow, /node tools\/chat-code-font-proof\.mjs evidence/);
  for (const name of ['IGSH-678 code cell size', 'IGSH-678 code font face and size', 'IGSH-678 code edges', 'IGSH-678 diff rows smooth on green and red']) assert.ok(code.includes(`name = '${name}'`), name);
  assert.match(code, /Press @\(0x12, 0x43\) 'Alt\+C: open Chat View on the code block'/);
  assert.match(code, /\[CodeFontProof\]::Bar\(/);
  assert.ok(code.includes('\\[chatcode\\] face='));
  assert.match(code, /Max\(8, \$chatPt - 3\)/);
  for (const shot of ['action', 'after']) assert.ok(code.includes(`Snapshot '${shot}'`));
  assert.ok(code.indexOf("'code-crop-4x.png'") < code.indexOf("throw ('IGSH-678 code size: '"), 'crop is retained before the size assertion fails');
  assert.doesNotMatch(code, /Set-Content|WriteAllText|WriteAllBytes|SetEnvironmentVariable|PostMessage/);
  const map = read(skill + 'features/chat-code-font.md');
  assert.deepEqual([...map.matchAll(/^## (.+)$/gm)].map(match => match[1]), [
    'Sub-features', 'How to get to it (user POV)', 'Driving it with control.ps1', 'Gotchas',
  ]);
  assert.match(read(skill + 'features/README.md'), /\[Chat code font\]\(chat-code-font.md\)/);
  assert.match(read(skill + 'coverage.md'), /\| IGSH-678 \|[^\n]*\| chat-code-font \|/);
});

test('IGSH-702 remind-me journey presses Ctrl+H and proves the picker by the app palette rows log', () => {
  assert.match(control, /ValidateSet\([^\n)]*'remind-me'/);
  assert.match(workflow, /\$env:FEATURE -notin @\([^\n)]*'remind-me'/);
  assert.match(workflow, /fromJSON\('\[[^\n]*"remind-me"(?:, "[a-z-]+")*\]'\)/);
  const journey = control.slice(control.indexOf("        'remind-me' {"), control.indexOf("        'group-rail' {"));
  assert.match(journey, /Press @\(0x11, 0x48\)/);
  assert.match(journey, /SEARCH_REMIND_PRESET_OFFSET/);
  assert.match(journey, /Snapshot 'action'[\s\S]*Snapshot 'after'/);
  assert.match(journey, /Remind Me preset rows published after Ctrl\+H/);
  assert.match(journey, /pickerRowIds = \$pickerIds/);
  const dismissal = /Press @\(0x1B\)|presetRowsGoneAfterEsc|Snapshot 'closed'/;
  for (const step of ["Press @(0x1B) 'Esc: leave the Remind Me presets'", 'presetRowsGoneAfterEsc = $true', "Snapshot 'closed'"]) assert.match(step, dismissal);
  assert.doesNotMatch(journey, dismissal);
  const map = read(skill + 'features/remind-me.md');
  assert.match(map, /Esc is not covered/);
  assert.match(map, /foreground on the GitHub runner/);
  for (const heading of ['## Sub-features', '## How to get to it (user POV)', '## Driving it with control.ps1', '## Gotchas']) assert.ok(map.includes(heading));
  assert.match(read(skill + 'features/README.md'), /\[Remind Me\]\(remind-me.md\)/);
  assert.match(read(skill + 'SKILL.md'), /`remind-me`/);
});

test('IGSH-901 tab-names journey seeds unflagged names once, reorders them and samples names through three restarts', () => {
  assert.match(control, /ValidateSet\([^\n)]*'tab-names'/);
  assert.match(workflow, /\$env:FEATURE -notin @\([^\n)]*'tab-names'/);
  assert.match(control, /\$Feature -in @\('browser-own-profile', 'tab-names'\)/);
  assert.match(control, /if \(\$Feature -eq 'tab-names'\) \{\s+\$seedFolder = Join-Path \$scratch 'GitHub'/);
  const journey = control.slice(control.indexOf("        'tab-names' {"), control.indexOf("        'favorites-groups' {"));
  assert.match(journey, /Press @\(0x11, 0x10, 0x26\)/);
  assert.doesNotMatch(journey, /Press @\(0x71\)/);
  assert.match(journey, /Restart-SessionRestore \$stage\[0\] \$stage\[1\]/);
  assert.match(journey, /TotalSeconds -lt 45/);
  assert.match(journey, /Tab names or order changed after/);
  assert.match(journey, /A seeded name became manual before/);
  for (const name of ['names-launch', 'names-restart-1', 'names-restart-2', 'names-restart-3', 'tab-names-order-survive-restarts']) assert.ok(journey.includes(name));
  const seed = control.slice(control.indexOf("    if ($Feature -eq 'tab-names') {"), control.indexOf("    $job = New-Object VerifyJob"));
  assert.doesNotMatch(seed, /manual\s*=\s*\$true/);
  const map = read(skill + 'features/tab-names.md');
  assert.match(map, /Seeding boundary/);
  assert.match(map, /v0\.28\.893/);
  assert.match(map, /Tab names or order changed/);
  for (const heading of ['## Sub-features', '## How to get to it (user POV)', '## Driving it with control.ps1', '## Gotchas']) assert.ok(map.includes(heading));
  assert.match(read(skill + 'features/README.md'), /\[Tab names\]\(tab-names.md\)/);
  assert.match(read(skill + 'SKILL.md'), /`tab-names`/);
  assert.match(read(skill + 'coverage.md'), /\| IGSH-901 \|[^\n]*\| tab-names \|/);
});

test('IGSH-706 inbox journey proves mute hides the published session without closing its tab and unmute restores it', () => {
  const inbox = control.slice(control.indexOf("        'inbox' {"), control.indexOf("        'remind-me' {"));
  const steps = [
    /Snapshot 'returned'\s+Palette 'new cmd'\s+Press @\(0x0D\) 'Enter: create a second CMD session to mute'/,
    /Wait-Until \{ \$state = Read-Inbox; \$null -ne \$state -and @\(\$state\.shells\)\.Count -eq 2 \} 'both sessions published to the Inbox'\s+\$sid = \(Read-Session\)\.tabs\[1\]\.shell_id/,
    /Wait-Until \{ \$state = Read-Inbox; \$null -ne \$state -and @\(\$state\.shells \| Where-Object \{ \$_\.sid -eq \$sid \}\)\.Count -eq 1 \}/,
    /Wait-Until \{ \$state = Read-Session; \$null -ne \$state -and \$state\.active_tab -ge 0 -and \$state\.tabs\[\$state\.active_tab\]\.shell_id -eq \$sid \}/,
    /\$baseline = Read-Session\s+Palette 'mute tab'\s+Press @\(0x0D\) 'Enter: mute the current tab'/,
    /Wait-Until \{\s+\$state = Read-Session\s+\$null -ne \$state -and \$state\.active_tab -eq \$baseline\.active_tab -and\s+\$state\.tabs\[\$state\.active_tab\]\.shell_id -eq \$sid -and\s+\$state\.tabs\[\$state\.active_tab\]\.PSObject\.Properties\['muted'\] -and \$state\.tabs\[\$state\.active_tab\]\.muted -eq \$true\s+\}/,
    /Wait-Until \{ \$state = Read-Inbox; \$null -ne \$state -and @\(\$state\.shells \| Where-Object \{ \$_\.sid -eq \$sid \}\)\.Count -eq 0 \}/,
    /Press @\(0x11, 0x10, 0x49\) 'Ctrl\+Shift\+I: open Inbox with the session muted'/,
    /Wait-Until \{ \[VerifyNative\]::Title\(\$script:window\)\.StartsWith\('Inbox - '\) \}/,
    /Press @\(0x12, 0x49\) 'Alt\+I: select All split with the session muted'\s+Snapshot 'muted'/,
    /\$result\.checks \+= @\{ name = 'inbox-muted-hidden'; sid = \$sid; listed = \$false; title = \[VerifyNative\]::Title\(\$script:window\) \}/,
    /Press @\(0x1B\) 'Esc: return from Inbox with the session muted'\s+Wait-Until \{ -not \[VerifyNative\]::Title\(\$script:window\)\.StartsWith\('Inbox - '\) \}/,
    /Wait-Until \{\s+\$state = Read-Session\s+\$null -ne \$state -and @\(\$state\.tabs\)\.Count -eq @\(\$baseline\.tabs\)\.Count -and\s+@\(\$state\.tabs \| Where-Object \{ \$_\.shell_id -eq \$sid \}\)\.Count -eq 1\s+\}/,
    /Snapshot 'muted-returned'\s+Palette 'unmute tab'\s+Press @\(0x0D\) 'Enter: unmute the current tab'/,
    /Wait-Until \{ \$state = Read-Inbox; \$null -ne \$state -and @\(\$state\.shells \| Where-Object \{ \$_\.sid -eq \$sid \}\)\.Count -eq 1 \}/,
    /\$result\.checks \+= @\{ name = 'inbox-unmuted-listed'; sid = \$sid; listed = \$true \}/,
  ];
  function contract(source) {
    let remaining = source;
    for (const step of steps) {
      const match = remaining.match(step);
      assert.ok(match, `missing or misordered ${step}`);
      remaining = remaining.slice(match.index + match[0].length);
    }
    assert.doesNotMatch(source, /Set-Content|WriteAllText|WriteAllBytes|SetEnvironmentVariable|PostMessage/);
  }
  const mute = inbox.slice(inbox.indexOf("Snapshot 'returned'"));
  contract(mute);
  for (const step of steps) {
    const broken = mute.replace(step, '');
    assert.notEqual(broken, mute);
    assert.throws(() => contract(broken), assert.AssertionError);
  }
  const map = read(skill + 'features/inbox.md');
  for (const item of ['`inbox-mute`', '`new cmd`', '`shell_id`', '`mute tab`', '`muted: true`', '`inbox-muted-hidden`', '`listed=false`', '`unmute tab`', '`inbox-unmuted-listed`', '`listed=true`']) assert.ok(map.includes(item), item);
  for (const shot of ['action', 'after', 'returned', 'muted', 'muted-returned']) {
    assert.ok(inbox.includes(`Snapshot '${shot}'`));
    assert.ok(map.includes(`\`${shot}.png\``));
  }
});

test('IGSH-814 theme verification waits for the initialized palette and selected Themes command before typing', () => {
  const selection = control.slice(control.indexOf('function Select-Theme('), control.indexOf('function Measure-StatusCard('));
  const readiness = /Focus-Palette 'themes' 4000\s+Press @\(0x0D\) 'Enter: Themes\.\.\.'\s+Type-Text \$Theme/;
  assert.match(selection, readiness);
  for (const replacement of ["Palette 'themes'", "Focus-Palette 'themes' 0"]) {
    assert.doesNotMatch(selection.replace("Focus-Palette 'themes' 4000", replacement), readiness);
  }
  assert.match(selection, /Wait-Until \{ \(Test-Path \$path\) -and \(Get-Content \$path -Raw\)\.Trim\(\) -eq \$SavedTheme \}/);
});

test('IGSH-900 relaunch-saved-sessions journey seeds saved sessions, relaunches three times and gates the release', () => {
  assert.match(control, /ValidateSet\([^\n)]*'relaunch-saved-sessions'/);
  assert.match(workflow, /\$env:FEATURE -notin @\([^\n)]*'relaunch-saved-sessions'/);
  assert.match(workflow, /fromJSON\('\["appearance", "chat-dictation", "relaunch-saved-sessions", [^\n]*\]'\)/);
  const journey = control.slice(control.indexOf("        'relaunch-saved-sessions' {"), control.indexOf("        'session-open' {"));
  assert.match(journey, /foreach \(\$launch in 2, 3\)/);
  assert.match(journey, /Restart-SessionRestore "relaunch-\$launch" \$false \$false \$openPorts/);
  assert.match(journey, /Open-NotifyPortListeners/);
  assert.match(journey, /\$after\.selected -cne \$starred\.selected/);
  const assertion = control.slice(control.indexOf('function Assert-RelaunchSessions('), control.indexOf("Write-Host 'Launch: validate executable and prepare isolated profile'"));
  assert.match(assertion, /sessions listed twice in the sidebar/);
  assert.match(assertion, /@\(\$saved\.tabs\)\.Count -eq \$Seed\.live\.Count/);
  assert.match(assertion, /group headers missing/);
  assert.doesNotMatch(journey + assertion, /Set-Content|WriteAll|Stop-Process/);
  const seed = control.slice(control.indexOf('function New-RelaunchSeed {'), control.indexOf('function Get-NotifyPorts {'));
  assert.match(seed, /foreach \(\$i in 1\.\.14\)/);
  assert.match(seed, /kind = 'tmux'/);
  assert.match(seed, /starred_view = \$true/);
  assert.match(control, /Get-NotifyPorts[\s\S]*notify_ports\.zig/);
  const map = read(skill + 'features/relaunch-saved-sessions.md');
  for (const required of ['seeded-state', 'occupied-ports', 'selection-kept', 'IGSH-890', 'auto-release-admit.sh']) assert.ok(map.includes(required), required);
  assert.match(read(skill + 'features/README.md'), /\[Relaunch saved sessions\]\(relaunch-saved-sessions.md\)/);
  assert.match(read(skill + 'SKILL.md'), /`relaunch-saved-sessions`/);
  assert.throws(() => assert.match(control.replace("'relaunch-saved-sessions')][string]$Feature", "')][string]$Feature"), /ValidateSet\([^\n)]*'relaunch-saved-sessions'/));
});

test('IGSH-925 chat-first-paint journey relaunches a saved chat with a docked browser and rejects any moved chat rectangle', () => {
  assert.match(control, /ValidateSet\([^\n)]*'chat-first-paint'/);
  assert.match(workflow, /\$env:FEATURE -notin @\([^\n)]*'chat-first-paint'/);
  assert.match(workflow, /fromJSON\('\["appearance", "chat-dictation", "relaunch-saved-sessions", [^\n]*"chat-first-paint"\]'\)/);
  const journey = control.slice(control.indexOf("        'chat-first-paint' {"), control.indexOf("        'browser-switch-speed' {"));
  assert.ok(journey.length > 200, 'chat-first-paint journey missing');
  assert.match(journey, /Open-BrowserPane/);
  assert.match(journey, /launch first-paint ms=/);
  assert.match(journey, /Capture-Window 'first-paint'/);
  assert.match(journey, /Capture-Window 'settled'/);
  assert.match(journey, /chat layout moved after first paint/);
  assert.match(journey, /chat-first-paint seed invalid/);
  assert.doesNotMatch(journey, /Set-Content|WriteAll|Stop-Process/);
  const map = read(skill + 'features/chat-first-paint.md');
  for (const required of ['first-paint-layout', 'docked-browser-pane', 'fast-reopen', 'IGSH-568', 'chat layout moved after first paint']) assert.ok(map.includes(required), required);
  assert.match(read(skill + 'features/README.md'), /\[Chat first paint\]\(chat-first-paint.md\)/);
  assert.match(read(skill + 'SKILL.md'), /`chat-first-paint`/);
  assert.throws(() => assert.match(control.replace("'chat-first-paint', ", ''), /ValidateSet\([^\n)]*'chat-first-paint'/));
});

test('IGSH-905 six-line composer proof holds Shift until the native composer shows the newline and always releases it', () => {
  const start = control.indexOf('function Press-ShiftEnter(');
  assert.notEqual(start, -1, 'control.ps1 has no Press-ShiftEnter');
  const helper = control.slice(start, control.indexOf('\nfunction ', start + 1));
  const order = /\[VerifyNative\]::GetAncestor\(\$composer, 2\) -ne \$script:window -or \[VerifyNative\]::Class\(\$composer\) -cne 'Edit'[\s\S]+?\[VerifyNative\]::KeyDown\(0x10\)\s+try \{[\s\S]+?\[VerifyNative\]::KeyDown\(0x0D\)[\s\S]+?\[VerifyNative\]::KeyUp\(0x0D\)\s+Wait-Until \{ @\(\[VerifyNative\]::EditText\(\$composer\) -split "`r\?`n"\)\.Count -eq \(\$before \+ 1\) \}[^\n]*\s+\} finally \{\s+\[VerifyNative\]::KeyUp\(0x10\)\s+\}\s+Wait-Until \{ -not \[VerifyNative\]::IsDown\(0x10\) \}/;
  assert.match(helper, order);
  assert.doesNotMatch(helper, /Chord|\[VerifyNative\]::Text|Press @/);
  assert.equal(helper.split('[VerifyNative]::KeyUp(0x10)').length - 1, 1);
  const buttons = control.slice(control.indexOf("$buttonsCheck = @{ name = 'round-bottom-composer-buttons'"), control.indexOf('$buttonsCheck.passed = $true'));
  assert.match(buttons, /Press-ShiftEnter 'Shift\+Enter: grow the owned draft without sending'\s+Type-Text \('Draft line ' \+ \$line\)/);
  assert.doesNotMatch(buttons, /Press @\(0x10, 0x0D\)/);
  assert.match(buttons, /@\(\$draft -split "`r\?`n"\)\.Count -ne \$lines/);
  for (const broken of [
    helper.replace(/\} finally \{\s+\[VerifyNative\]::KeyUp\(0x10\)\s+\}/, '}\n    [VerifyNative]::KeyUp(0x10)'),
    helper.replace('[VerifyNative]::KeyDown(0x10)\n    try {', 'try {\n        [VerifyNative]::KeyDown(0x10)\n        [VerifyNative]::KeyUp(0x10)'),
  ]) {
    assert.doesNotMatch(broken, order);
  }
  const earlyRelease = helper.replace('[VerifyNative]::KeyDown(0x0D)', '[VerifyNative]::KeyUp(0x10)\n        [VerifyNative]::KeyDown(0x0D)');
  assert.notEqual(earlyRelease.split('[VerifyNative]::KeyUp(0x10)').length - 1, 1);
});

test('IGSH-911 native bubble and selection scans recognize exact delivered alpha tones', () => {
  const samples = JSON.parse(read('tools/fixtures/IGSH-911/bubble-tones.json'));
  const blend = control.slice(control.indexOf('static System.Drawing.Color QueuedColor('), control.indexOf('public static Point MessageBubblePoint('));
  for (const channel of ['R', 'G', 'B']) assert.ok(blend.includes(`(bg.${channel} * 128 + 128) / 256 + (fill.${channel} * 127 + 128) / 256`));
  const scan = control.slice(control.indexOf('public static Point MessageBubblePoint('), control.indexOf('public static Point[] SelectTranscriptText('));
  assert.ok(scan.includes('var queuedFill = QueuedColor(bg, fill);'));
  assert.match(scan, /color == fill.ToArgb\(\) \|\| color == queuedFill.ToArgb\(\)/);
  assert.match(scan, /pixels.GetPixel\(x - 1, y\).ToArgb\(\) == color/);
  assert.match(scan, /pixels.GetPixel\(x, y - 1\).ToArgb\(\) == color/);
  const selection = control.slice(control.indexOf('public static int TranscriptSelectionPixels('), control.indexOf('public static int[] DictationMicPixels('));
  assert.ok(selection.includes('queuedColors.Add(QueuedColor(bg, fill).ToArgb());'));
  assert.ok(selection.includes('else if (queuedColors.Contains(c.ToArgb())) count++;'));
  const queued = fill => samples.background.map((value, i) => Math.floor((value * 128 + 128) / 256) + Math.floor((fill[i] * 127 + 128) / 256));
  assert.deepEqual(queued(samples.sending), samples.delivered);
  assert.deepEqual(queued(samples.selection), samples.deliveredSelection);
  assert.notDeepEqual(samples.selection, samples.deliveredSelection);
  assert.notDeepEqual(samples.background.map((value, i) => Math.floor((value * 128 + samples.selection[i] * 127) / 255)), samples.deliveredSelection);
  assert.ok(read('src/chat_render.zig').includes('.source_constant_alpha = 128'));
});

test('IGSH-857: debug.log is read with shared access so a live app write cannot fail the journey', () => {
  assert.ok(!control.includes('[IO.File]::ReadAllText($log)'));
  assert.ok(!control.includes('[IO.File]::ReadAllText($launchLog)'));
  const helper = control.slice(control.indexOf('function Read-SharedText('), control.indexOf('function Read-DictationAudit('));
  assert.match(helper, /\[IO\.FileShare\]::ReadWrite/);
  assert.equal(control.split('(Read-SharedText $log)').length - 1, 4);
  assert.equal(control.split('Read-SharedText $launchLog').length - 1, 1);
});

test('IGSH-977 chat-send-latency journey sends 20 messages and fails any that takes over 100 ms to draw', () => {
  assert.match(control, /ValidateSet\([^\n)]*'chat-send-latency'/);
  assert.match(workflow, /\$env:FEATURE -notin @\([^\n)]*'chat-send-latency'/);
  assert.match(workflow, /fromJSON\('\["appearance", [^\n]*"chat-send-latency", "chat-first-paint"\]'\)/);
  const journey = control.slice(control.indexOf("        'chat-send-latency' {"), control.indexOf("        'chat-focus' {"));
  assert.ok(journey.length > 200, 'chat-send-latency journey missing');
  assert.match(journey, /for \(\$n = 1; \$n -le 20; \$n\+\+\)/);
  assert.match(journey, /Press @\(0x0D\)/);
  assert.match(journey, /send-latency id=/);
  assert.match(journey, /took longer than 100 ms/);
  assert.doesNotMatch(journey, /Set-Content|Stop-Process/);
  assert.match(journey, /0x276F/);
  assert.match(journey, /claude agent/);
  const map = read(skill + 'features/chat-send-latency.md');
  for (const required of ['bubble-first', 'marks-only-in-log', 'IGSH-977', '100 ms']) assert.ok(map.includes(required), required);
  assert.match(read(skill + 'features/README.md'), /\[Chat send latency\]\(chat-send-latency.md\)/);
  assert.match(read(skill + 'SKILL.md'), /`chat-send-latency`/);
  const marks = read('src/send_latency.zig');
  assert.match(marks, /send-latency id=/);
  assert.match(read('src/chat_send.zig'), /send_latency\.markPressed\(\)/);
  assert.match(read('src/chat_render.zig'), /send_latency\.markPainted\(/);
  assert.throws(() => assert.match(control.replace("'chat-send-latency'", ''), /ValidateSet\([^\n)]*'chat-send-latency'/));
});

test('IGSH-1033 master smoke, targeted proofs and full candidate select distinct matrices', () => {
  const expression = workflow.match(/^        feature: \$\{\{ (.+) \}\}$/m)[1];
  assert.ok(fs.existsSync(path.join(root, 'tools/journey-policy.json')));
  const policy = JSON.parse(read('tools/journey-policy.json'));
  const features = [...workflow.matchAll(/fromJSON\('(\[[^'\n]+\])'\)/g)].map(match => JSON.parse(match[1])).find(values => values.includes('chat-dictation'));
  const evaluate = (event, inputs = {}) => JSON.parse(JSON.stringify(require('node:vm').runInNewContext(
    expression, {
      inputs, github: { event_name: event, ref: 'refs/heads/master' },
      startsWith: (value, prefix) => value.startsWith(prefix),
      fromJSON: JSON.parse, format: (pattern, value) => pattern.replace('{0}', value),
    })));
  assert.deepEqual(evaluate('push'), ['appearance']);
  assert.deepEqual(evaluate('pull_request'), ['appearance']);
  assert.deepEqual(evaluate('push', { feature: 'relaunch-saved-sessions' }), ['relaunch-saved-sessions']);
  assert.deepEqual(evaluate('workflow_run', { feature: 'all' }), features);
  assert.deepEqual(evaluate('push', { feature: 'all' }), features);
  assert.deepEqual(evaluate('workflow_dispatch', { feature: 'pane-layout' }), ['pane-layout']);
  assert.match(workflow, /continue-on-error: \$\{\{ contains\(fromJSON\(needs.journey-policy.outputs.quarantined\), matrix.feature\) \}\}/);
  for (const key of Object.keys(policy.quarantined)) {
    assert.ok(features.includes(key));
    assert.match(policy.quarantined[key].ticket, /^https:\/\/app.hypertask.ai\/detail\/project-2060\/\d+$/);
    assert.equal(new Set(policy.quarantined[key].runs).size, 2);
  }
});

test('IGSH-1033 historical desktop controls never run on master or release candidates', () => {
  for (const name of ['Build IGSH-807 pre-fix focus-ring control', 'Require visible pre-fix focus rings with unchanged input cycling', 'Build the pre-fix commit 42cecfd3 negative control', 'Require pre-fix 42cecfd3 to show activity rows with the identical journey']) {
    const step = workflow.slice(workflow.indexOf('      - name: ' + name)).split(/\n      - /)[0];
    assert.match(step, /if: github.event_name == 'workflow_dispatch' &&/);
  }
});
