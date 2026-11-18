const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const symbols = [
  'SEARCH_TABCTX_RENAME', 'SEARCH_TABCTX_COPY_ID', 'SEARCH_TABCTX_UNREAD', 'SEARCH_TABCTX_PIN_TOP',
  'SEARCH_TABCTX_FAVORITE', 'SEARCH_FAVORITE_OFFSET', 'SEARCH_INBOX_EXCLUDE_OFFSET',
  'SEARCH_TABCTX_BOT_FACE', 'SEARCH_TABCTX_BOT_COLOR', 'SEARCH_BOT_FACE_OFFSET', 'SEARCH_BOT_COLOR_OFFSET', 'SEARCH_TABCTX_BACK',
  'SEARCH_GROUPMOVE_MENU_OFFSET', 'SEARCH_GROUPMOVE_BACK_OFFSET', 'SEARCH_GROUPMOVE_NEW_OFFSET', 'SEARCH_GROUPMOVE_GROUP_OFFSET', 'SEARCH_GROUPMOVE_NONE_OFFSET',
  'SEARCH_TABCTX_WSMOVE', 'SEARCH_WORKSPACE_BACK_OFFSET', 'SEARCH_WSMOVE_NEW_OFFSET', 'SEARCH_WSMOVE_OFFSET',
  'SEARCH_TABCTX_ARCHIVE', 'SEARCH_TABCTX_END_TMUX', 'SEARCH_TABCTX_CLOSE_DISCONNECTED', 'SEARCH_CLOSE_DISCONNECTED_OFFSET',
];
const expectedSteps = [
  'rename-context', 'rename-global', 'rename-keyboard', 'copy-global', 'copy-context',
  'unread-context', 'unread-global', 'unread-keyboard', 'pin-context', 'unpin-context', 'pin-global', 'unpin-global',
  'inbox-exclude', 'inbox-include', 'favorite-context', 'favorite-global', 'favorite-keyboard-1', 'favorite-keyboard-0',
  'face-back', 'face-2', 'face-0', 'face-1', 'color-back', 'color-2', 'color-0', 'color-1',
  'group-back', 'group-new', 'group-peer', 'group-none', 'group-existing', 'workspace-back', 'workspace-new', 'workspace-existing',
  'disconnected-context', 'disconnected-global', 'archive-context', 'delete-context', 'delete-global', 'delete-keyboard',
];
const markerNames = ['control-before', 'control-after-moves', 'control-after-disconnected-context', 'control-after-disconnected-global', 'control-after-archive-context', 'control-after-delete-context', 'control-after-delete-global', 'control-after-delete-keyboard', 'control-after-restart'];
const readJson = (dir, file) => JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8').replace(/^\uFEFF/, ''));
const tab = (state, id) => state.tabs.find(row => row.chat_id === id);
const copiedId = id => `session:#${BigInt(id).toString(16).padStart(16, '0')}`;

function catalog() {
  const source = fs.readFileSync(path.resolve(__dirname, '../../../src/app_state.zig'), 'utf8');
  const values = Object.fromEntries([...source.matchAll(/pub const (SEARCH_\w+): usize = (\d+);/g)].map(([, name, value]) => [name, Number(value)]));
  return Object.fromEntries(symbols.map(name => {
    assert.ok(Number.isInteger(values[name]), name);
    return [name, values[name]];
  }));
}
function savedTab(state, row) {
  return {
    id: row.chat_id, name: row.name, workspace: row.workspace || 0,
    group: state.groups?.find(group => group.id === row.group_id)?.name || '',
    starredGroup: state.groups?.find(group => group.id === row.starred_group_id)?.name || '',
    pin: !!row.pinned_top, starredPin: !!row.starred_pinned_top, favorite: !!row.favorite,
    face: row.face ?? null, color: row.color ?? null, excluded: !!row.inbox_excluded,
  };
}
function layout(state) {
  return state.tabs.map(row => savedTab(state, row)).sort((a, b) => a.id - b.id);
}
function stepEvidence(step, before, after, inbox, groupId) {
  const old = tab(before, step.id), current = tab(after, step.id);
  assert.ok(old, `${step.name} starts with the real target`);
  assert.ok(Number.isSafeInteger(step.id) && step.id > 0);
  if (step.route === 'context' || step.name === 'disconnected-global') {
    assert.equal(after.tabs[after.active_tab].chat_id, before.tabs[before.active_tab].chat_id, `${step.name} preserves the active identity`);
    if (step.name !== 'workspace-existing') assert.equal(after.active_workspace, before.active_workspace);
  } else {
    assert.equal(before.tabs[before.active_tab].chat_id, step.id, `${step.name} acts on the selected identity`);
  }
  const others = state => layout(state).filter(row => row.id !== step.id);
  assert.deepEqual(others(after), others(before), `${step.name} leaves every other tab unchanged`);
  const name = step.name;
  if (/^(?:archive|delete|disconnected)-/.test(name)) {
    assert.equal(current, undefined, `${name} removes only the victim`);
    assert.ok(step.extra.pid > 0 && step.extra.exited === true, 'the actual CMD process exited');
    if (name.startsWith('disconnected-')) assert.equal(old.pinned_top, true);
    return;
  }
  assert.ok(current);
  assert.equal(after.tabs.length, before.tabs.length);
  if (name.startsWith('rename-')) assert.equal(current.name, `Batch target ${step.route}`);
  else if (name.startsWith('copy-')) assert.equal(step.extra.clipboard, copiedId(step.id));
  else if (name.startsWith('unread-')) assert.ok(inbox.shells.some(row => row.sid === current.shell_id && row.att));
  else if (name.startsWith('pin-') || name.startsWith('unpin-')) assert.equal(!!current.pinned_top, name.startsWith('pin-'));
  else if (name.startsWith('favorite-')) assert.equal(!!current.favorite, name === 'favorite-context' || name.endsWith('-1'));
  else if (name.startsWith('inbox-')) assert.equal(!!current.inbox_excluded, name === 'inbox-exclude');
  else if (/^(face|color)-/.test(name)) {
    const [field, choice] = name.split('-');
    if (choice === 'back') assert.deepEqual(savedTab(after, current), savedTab(before, old));
    else if (choice === '0') assert.equal(current[field], undefined);
    else assert.equal(current[field], Number(choice) - 1);
  } else if (name.endsWith('-back')) assert.deepEqual(savedTab(after, current), savedTab(before, old));
  else if (name === 'group-new') assert.ok(current.group_id > 0 && after.groups.some(row => row.id === current.group_id));
  else if (name === 'group-none') assert.equal(current.group_id || 0, 0);
  else if (name === 'group-peer' || name === 'group-existing') assert.equal(current.group_id, groupId);
  else if (name === 'workspace-new') {
    assert.ok(current.workspace > 0);
    assert.equal(current.group_id || 0, 0);
    assert.equal(after.workspace_count, before.workspace_count + 1);
  } else if (name === 'workspace-existing') {
    assert.equal(current.workspace || 0, 0);
    assert.equal(after.active_workspace, 0);
  } else assert.fail(`Unknown evidence step ${name}`);
}
function windowEvidence(doctor, nodes, pid) {
  assert.equal(doctor.pid, pid);
  assert.match(doctor.sha256, /^[a-f0-9]{64}$/i);
  assert.ok(nodes.length);
  assert.equal(nodes[0].pid, pid);
  assert.equal(nodes[0].class, 'ZigShell');
  assert.equal(nodes[0].handle, doctor.hwnd);
}
function evidence(dir) {
  const identities = readJson(dir, 'tab-identities.json');
  const ids = [identities.control, identities.target, identities.peer];
  assert.ok(ids.every(id => Number.isSafeInteger(id) && id > 0));
  assert.equal(new Set(ids).size, 3);
  const steps = readJson(dir, 'tab-steps.json');
  assert.deepEqual(steps.map(row => row.name), expectedSteps, 'complete ordered native action matrix');
  const routes = catalog();
  const inputs = readJson(dir, 'tab-inputs.json');
  for (const symbol of symbols) assert.ok(inputs.some(row => row.symbol === symbol), `receiving menu confirmation for ${symbol}`);
  for (const row of inputs) {
    assert.ok(Number.isInteger(row.choice) && row.choice >= 0);
    assert.equal(row.target, routes[row.symbol] + row.choice);
    assert.match(row.trace, new RegExp(`\\[palette\\] confirm target=${row.target}(?:\\s|$)`));
  }
  let groupId;
  for (const step of steps) {
    assert.match(step.stem, /^tab-\d{3}$/);
    const before = readJson(dir, `${step.stem}-before.session.json`);
    const after = readJson(dir, `${step.stem}-after.session.json`);
    stepEvidence(step, before, after, readJson(dir, `${step.stem}-after.inbox.json`), groupId);
    if (step.name === 'group-new') groupId = tab(after, step.id).group_id;
    const doctor = readJson(dir, `${step.stem}-doctor.json`);
    const png = fs.readFileSync(path.join(dir, `${step.stem}.png`));
    assert.ok(png.length > 24 && png.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex')));
    windowEvidence(doctor, readJson(dir, `${step.stem}.uia.json`), step.pid);
  }
  for (const name of markerNames) assert.equal(fs.readFileSync(path.join(dir, `${name}.txt`), 'utf8').trim(), name);
  assert.deepEqual(layout(readJson(dir, 'tab-layout-after-restart.json')), layout(readJson(dir, 'tab-layout-before-restart.json')), 'names, IDs, appearance and membership survive a real restart');
  assert.equal(readJson(dir, 'tab-restarted-identity.json').clipboard, copiedId(identities.target));
  assert.match(fs.readFileSync(path.join(dir, 'tab-actions-session-audit.log'), 'utf8'), /pinned-local-session-exited-preserved/);
}

if (process.argv[2] === '--catalog') console.log(JSON.stringify(catalog()));
else if (process.argv[2] === '--evidence') {
  assert.equal(process.argv.length, 4);
  evidence(process.argv[3]);
  console.log('TAB_ACTION_EVIDENCE_OK');
} else {
  test('tab action catalog resolves every driven production routing symbol', () => {
    const values = catalog();
    assert.equal(Object.keys(values).length, symbols.length);
    assert.ok(Object.values(values).every(Number.isInteger));
  });
  test('native tab journey is registered and does not substitute saved-state setters for inputs', () => {
    const file = path.join(__dirname, 'control-feature-tab-actions.ps1');
    assert.ok(fs.existsSync(file), 'executable native tab journey exists');
    const text = fs.readFileSync(file, 'utf8');
    const control = fs.readFileSync(path.join(__dirname, 'control.ps1'), 'utf8');
    assert.match(control, /ValidateSet\([^]*?'tab-actions'/);
    assert.ok(control.includes("'control-feature-tab-actions.ps1'"));
    for (const input of ['RightClickClient', 'Get-Clipboard -Raw', 'pinned-local-session-exited-preserved', 'Restart-SessionRestore', 'Wait-WorkspaceSurface', 'victimProcess.HasExited', '--evidence $Evidence']) assert.ok(text.includes(input), input);
    assert.doesNotMatch(text, /WriteAllText|Set-Content|WM_APP|PostMessage|SendMessage|--state|permission-next/);
    assert.match(text, /\[photo-proof\\\]/);
    assert.match(text, /Substring\(\$script:tabPaletteOffset\)/);
    for (const name of ['copy-', 'rename-', 'unread-', 'face', 'color', 'group-new', 'workspace-existing', 'archive-context', 'delete-keyboard']) assert.ok(text.includes(name), name);
  });
  test('context geometry follows current placement after pin and unpin', t => {
    const file = path.join(__dirname, 'control-feature-tab-actions.ps1');
    assert.ok(fs.existsSync(file), 'executable native tab journey exists');
    const text = fs.readFileSync(file, 'utf8');
    const helper = text.slice(text.indexOf('function Get-ActionValue('), text.indexOf('function Open-ActionPalette('));
    const run = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', `
      $ErrorActionPreference = 'Stop'
      $script:pinned = $false
      function Read-Session { return @{ tabs = @([pscustomobject]@{ chat_id = 101 }, [pscustomobject]@{ chat_id = 202; pinned_top = $script:pinned }) } }
      function Read-SharedText { return $script:log }
      function Wait-Until($Condition, $Label) { if (-not (& $Condition)) { throw $Label } }
      ${helper}
      $script:log = "[photo-proof] expanded target=1 rect=20,229,56,265\n[photo-proof] pinned target=1 rect=122,68,178,124"
      if (((Get-ActionPoint 202) -join ',') -ne '38,247') { throw 'Unpinned target reused its old pinned rectangle' }
      $script:pinned = $true
      $script:log += "\n[photo-proof] expanded target=1 rect=20,113,56,149"
      if (((Get-ActionPoint 202) -join ',') -ne '150,96') { throw 'Pinned target reused its old expanded rectangle' }
    `], { encoding: 'utf8' });
    if (run.error?.code === 'ENOENT') return t.skip('PowerShell is required to execute the driver geometry helper');
    assert.equal(run.status, 0, run.stderr);
  });
  test('a refreshed unchanged palette row can confirm once more without replaying accepted or changed actions', t => {
    const file = path.join(__dirname, 'control-feature-tab-actions.ps1');
    assert.ok(fs.existsSync(file), 'executable native tab journey exists');
    const text = fs.readFileSync(file, 'utf8');
    const helper = text.slice(text.indexOf('function Select-ActionRow('), text.indexOf('function Select-ActionTab('));
    const run = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', `
      $ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
      $Evidence = ''
      function Read-SharedText { return $script:log }
      function Save-Json { }
      function Type-Text { $script:log += "[palette] rows chars=13 count=1 ids=6301\n[palette] ready chars=13 count=1 target=6301\n" }
      function Wait-Until($Condition, $Label) { for ($n = 0; $n -lt 5; $n++) { if (& $Condition) { return } }; throw $Label }
      function Press($Keys, $Label) {
        if ($Keys[0] -ne 13) { return }
        $script:enters++
        if ($script:scenario -eq 'accepted' -or ($script:scenario -eq 'refreshed' -and $script:enters -eq 2)) { $script:log += "[palette] confirm target=6301\n" }
        elseif ($script:scenario -eq 'refreshed' -or $script:scenario -eq 'keeps-refreshing') { $script:log += "[palette] rows chars=13 count=1 ids=6301\n[palette] ready chars=13 count=1 target=6301\n" }
        elseif ($script:scenario -eq 'changed') { $script:log += "[palette] rows chars=13 count=1 ids=6302\n[palette] ready chars=13 count=1 target=6302\n" }
        elseif ($script:scenario -eq 'selection-changed') { $script:log += "[palette] rows chars=13 count=1 ids=6301\n[palette] ready chars=13 count=1 target=6302\n" }
        elseif ($script:scenario -eq 'query-changed') { $script:log += "[palette] rows chars=0 count=1 ids=6301\n[palette] ready chars=0 count=1 target=6301\n" }
        elseif ($script:scenario -eq 'reordered') { $script:log += "[palette] rows chars=13 count=2 ids=6302 6301\n[palette] ready chars=13 count=2 target=6301\n" }
        elseif ($script:scenario -eq 'other-confirmed') { $script:log += "[palette] confirm target=6302\n[palette] rows chars=13 count=1 ids=6301\n[palette] ready chars=13 count=1 target=6301\n" }
      }
      ${helper}
      foreach ($scenario in @('refreshed', 'accepted', 'silent', 'changed', 'selection-changed', 'query-changed', 'reordered', 'other-confirmed', 'keeps-refreshing')) {
        $script:scenario = $scenario; $script:log = ''; $script:enters = 0
        $script:tabLog = ''; $script:tabPaletteOffset = 0; $script:tabInputs = @()
        $script:tabTargets = [pscustomobject]@{ SEARCH_GROUPMOVE_MENU_OFFSET = 6301 }
        $passed = $false
        try { Select-ActionRow 'SEARCH_GROUPMOVE_MENU_OFFSET' 'move to group'; $passed = $true } catch { }
        $expected = $scenario -in @('refreshed', 'accepted')
        if ($passed -ne $expected) { throw "$scenario receiving-confirm result was $passed" }
        $count = if ($scenario -in @('refreshed', 'keeps-refreshing')) { 2 } else { 1 }
        if ($script:enters -ne $count) { throw "$scenario sent $script:enters keypresses, expected $count" }
      }
    `], { encoding: 'utf8' });
    if (run.error?.code === 'ENOENT') return t.skip('PowerShell is required to execute native confirmation handling');
    assert.equal(run.status, 0, run.stderr);
  });
  test('returning to home accepts the app-written omitted workspace field', t => {
    const before = { active_tab: 1, active_workspace: 2, tabs: [{ chat_id: 101, name: 'Control' }, { chat_id: 202, name: 'Target', workspace: 2 }] };
    const after = structuredClone(before); after.active_workspace = 0; delete after.tabs[1].workspace;
    stepEvidence({ name: 'workspace-existing', route: 'context', id: 202 }, before, after, {}, undefined);
    const file = path.join(__dirname, 'control-feature-tab-actions.ps1');
    assert.ok(fs.existsSync(file), 'executable native tab journey exists');
    const text = fs.readFileSync(file, 'utf8');
    const helpers = text.slice(text.indexOf('function Get-ActionTab('), text.indexOf('function Get-ActionPoint('));
    const wait = text.split('\n').find(line => line.includes("'active target returned to the existing home workspace'"));
    assert.ok(wait);
    const run = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', `
      $ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
      $script:targetId = 202
      $script:state = '${JSON.stringify(after)}' | ConvertFrom-Json
      function Read-Session { return $script:state }
      function Wait-Until($Condition, $Label) { if (-not (& $Condition)) { throw $Label } }
      ${helpers}
      ${wait}
    `], { encoding: 'utf8' });
    if (run.error?.code === 'ENOENT') return t.skip('PowerShell is required to execute the driver workspace check');
    assert.equal(run.status, 0, run.stderr);
  });
  test('the new workspace peer receives a stable native name before tab moves', t => {
    const file = path.join(__dirname, 'control-feature-tab-actions.ps1');
    assert.ok(fs.existsSync(file), 'executable native tab journey exists');
    const text = fs.readFileSync(file, 'utf8');
    const creation = text.slice(text.indexOf("Press @(0x11, 0x4E)"), text.indexOf("Press @(0x12, 0x32)"));
    assert.ok(creation);
    const run = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', `
      $ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
      $script:state = '{"workspace_count":2,"active_tab":0,"tabs":[{"chat_id":303,"name":"CMD 4"}]}' | ConvertFrom-Json
      $script:renameOpen = $false
      function Read-Session { return $script:state }
      function Get-ActionTab($Id) { if ($Id -ne 303) { throw 'Wrong peer identity' }; return $script:state.tabs[0] }
      function Press($Keys, $Label) { if ($Keys[0] -eq 0x71) { $script:renameOpen = $true } }
      function Open-ActionPalette { }
      function Select-ActionRow { }
      function Wait-Until($Condition, $Label) { if (-not (& $Condition)) { throw $Label } }
      function Rename-ActionTab($Name) {
        if (-not $script:renameOpen) { throw 'Native rename was not opened' }
        $script:state.tabs[0].name = $Name
        $script:state.tabs[0] | Add-Member manual $true
      }
      ${creation}
      if (-not $script:state.tabs[0].PSObject.Properties['manual'] -or $script:state.tabs[0].name -ne 'Batch workspace peer') { throw 'Workspace peer retains a changing automatic title' }
    `], { encoding: 'utf8' });
    if (run.error?.code === 'ENOENT') return t.skip('PowerShell is required to execute workspace peer creation');
    assert.equal(run.status, 0, run.stderr);
  });
  test('pinned CMD exit waits on the real session audit channel', t => {
    const file = path.join(__dirname, 'control-feature-tab-actions.ps1');
    assert.ok(fs.existsSync(file), 'executable native tab journey exists');
    const wait = fs.readFileSync(file, 'utf8').split('\n').find(line => line.includes("'real CMD exits and the app preserves its pinned disconnected row'"));
    assert.ok(wait);
    const run = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', `
      $ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
      $script:tabLog = 'debug'; $script:tabAuditLog = 'audit'; $exitOffset = 0
      $victimProcess = [pscustomobject]@{ HasExited = $true }
      function Read-SharedText($Path) {
        if ($Path -eq 'audit') { return 'reason=pinned-local-session-exited-preserved instance=default count=5 active=4' }
        return 'WM_APP_SHELL_EXITED id=5 kind=cmd reason=preserve exit_code=0 known=true'
      }
      function Wait-Until($Condition, $Label) { if (-not (& $Condition)) { throw $Label } }
      ${wait}
      $victimProcess.HasExited = $false
      $rejected = $false
      try { ${wait} } catch { $rejected = $true }
      if (-not $rejected) { throw 'Audit receipt cannot substitute for actual process exit' }
    `], { encoding: 'utf8' });
    if (run.error?.code === 'ENOENT') return t.skip('PowerShell is required to execute the process-exit observation');
    assert.equal(run.status, 0, run.stderr);
  });
  test('native rename focuses and reads the editor before committing', t => {
    const file = path.join(__dirname, 'control-feature-tab-actions.ps1');
    assert.ok(fs.existsSync(file), 'executable native tab journey exists');
    const text = fs.readFileSync(file, 'utf8');
    const helper = text.slice(text.indexOf('function Rename-ActionTab('), text.indexOf('function New-ActionTab('));
    const run = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', `
      $ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
      Add-Type 'public class VerifyNative {
        public struct Rect { public int Left, Top, Right, Bottom; }
        public static bool Clicked, Selected; public static int Commits; public static string Value;
        public static System.IntPtr GetFocusedWindow(System.IntPtr window) { return new System.IntPtr(202); }
        public static string Class(System.IntPtr window) { return "Edit"; }
        public static System.IntPtr GetAncestor(System.IntPtr window, uint flag) { return new System.IntPtr(101); }
        public static bool GetClientRect(System.IntPtr window, ref Rect rect) { rect.Right = 300; rect.Bottom = 24; return true; }
        public static void ClickClient(System.IntPtr window, int x, int y) { if (window.ToInt64() != 202 || x != 150 || y != 12) throw new System.Exception("Wrong editor click"); Clicked = true; }
        public static string EditText(System.IntPtr window) { return Value; }
      }'
      $script:window = [IntPtr]101
      function Doctor { }
      function Wait-Foreground { }
      function Wait-Until($Condition, $Label) { if (-not (& $Condition)) { throw $Label } }
      function Type-Text($Text) { if (-not $script:drop -and [VerifyNative]::Clicked -and [VerifyNative]::Selected) { [VerifyNative]::Value = $Text } }
      function Press($Keys, $Label) {
        if ($Keys[0] -eq 0x11) { [VerifyNative]::Selected = $true }
        if ($Keys[0] -eq 13) { [VerifyNative]::Commits++; if ([VerifyNative]::Value -ne 'Disconnected context') { throw 'Unreceived rename committed' } }
      }
      ${helper}
      foreach ($drop in @($false, $true)) {
        $script:drop = $drop; [VerifyNative]::Clicked = $false; [VerifyNative]::Selected = $false
        [VerifyNative]::Commits = 0; [VerifyNative]::Value = 'CMD 5'
        $passed = $false
        try { Rename-ActionTab 'Disconnected context'; $passed = $true } catch { }
        if ($passed -eq $drop) { throw 'Rename receiving-check result is wrong' }
        $expected = if ($drop) { 0 } else { 1 }
        if ([VerifyNative]::Commits -ne $expected) { throw 'Rename committed before the requested text arrived' }
      }
    `], { encoding: 'utf8' });
    if (run.error?.code === 'ENOENT') return t.skip('PowerShell is required to execute native rename handling');
    assert.equal(run.status, 0, run.stderr);
  });
  test('window evidence binds the app root while allowing its embedded native console', () => {
    const doctor = { pid: 7228, hwnd: 131478, sha256: 'a'.repeat(64) };
    const nodes = [{ pid: 7228, handle: 131478, class: 'ZigShell' }, { pid: 832, handle: 393336, class: 'ConsoleWindowClass' }, { pid: 832, handle: 0, class: '' }];
    windowEvidence(doctor, nodes, 7228);
    assert.throws(() => windowEvidence(doctor, nodes, 99), assert.AssertionError);
    for (const changed of [{ pid: 99 }, { handle: 99 }, { class: 'OtherApp' }]) {
      assert.throws(() => windowEvidence(doctor, [{ ...nodes[0], ...changed }, ...nodes.slice(1)], 7228), assert.AssertionError);
    }
  });
  test('wrong inactive targets, clipboard identity and collateral edits fail with positive controls', () => {
    const before = { active_tab: 0, active_workspace: 0, tabs: [{ chat_id: 101, name: 'Control' }, { chat_id: 202, name: 'Target' }] };
    const after = structuredClone(before);
    const step = { name: 'copy-context', route: 'context', id: 202, extra: { clipboard: copiedId(202) } };
    stepEvidence(step, before, after, {}, undefined);
    step.extra.clipboard = copiedId(101);
    assert.throws(() => stepEvidence(step, before, after, {}, undefined), assert.AssertionError);
    step.extra.clipboard = copiedId(202); after.active_tab = 1;
    assert.throws(() => stepEvidence(step, before, after, {}, undefined), assert.AssertionError);
    after.active_tab = 0; after.tabs[0].name = 'Wrong rename';
    assert.throws(() => stepEvidence(step, before, after, {}, undefined), assert.AssertionError);
  });
  test('local close needs a removed identity and an exited process while the other tab survives', () => {
    const before = { active_tab: 0, active_workspace: 0, tabs: [{ chat_id: 101, name: 'Control' }, { chat_id: 202, name: 'Victim', pinned_top: true }, { chat_id: 303, name: 'Peer' }] };
    const after = { ...before, tabs: [before.tabs[0], before.tabs[2]] };
    const step = { name: 'disconnected-context', route: 'context', id: 202, extra: { pid: 42, exited: true } };
    stepEvidence(step, before, after, {}, undefined);
    const globalStep = { ...step, name: 'disconnected-global', route: 'global' };
    stepEvidence(globalStep, before, after, {}, undefined);
    assert.throws(() => stepEvidence(globalStep, before, { ...after, active_tab: 1 }, {}, undefined), assert.AssertionError);
    step.extra.exited = false;
    assert.throws(() => stepEvidence(step, before, after, {}, undefined), assert.AssertionError);
    step.extra.exited = true;
    assert.throws(() => stepEvidence(step, before, before, {}, undefined), assert.AssertionError);
  });
  test('Auto and explicit appearance values remain distinct and restart order is irrelevant', () => {
    const before = { active_tab: 0, active_workspace: 0, tabs: [{ chat_id: 101, name: 'Control' }, { chat_id: 202, name: 'Target', face: 1 }] };
    const after = structuredClone(before); delete after.tabs[1].face;
    const step = { name: 'face-0', route: 'context', id: 202 };
    stepEvidence(step, before, after, {}, undefined);
    after.tabs[1].face = 0;
    assert.throws(() => stepEvidence(step, before, after, {}, undefined), assert.AssertionError);
    assert.deepEqual(layout(before), layout({ ...before, tabs: [...before.tabs].reverse() }));
    const mutated = structuredClone(before); mutated.tabs[1].workspace = 2;
    assert.notDeepEqual(layout(before), layout(mutated));
  });
  test('the public catalog mode runs without another helper file', () => {
    const run = spawnSync(process.execPath, [__filename, '--catalog'], { encoding: 'utf8' });
    assert.equal(run.status, 0, run.stderr);
    assert.deepEqual(JSON.parse(run.stdout), catalog());
  });
}
