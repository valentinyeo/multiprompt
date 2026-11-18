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
  if (step.name === 'workspace-existing') {
    const home = before.tabs.find(row => row.shell_id === before.workspaces[0].last_shell);
    assert.ok(home && (home.workspace || 0) === 0, 'home remembers a real home-workspace session');
    assert.equal(after.tabs[after.active_tab].chat_id, home.chat_id, 'returning home restores its remembered session');
  } else if (step.route === 'context' || step.name === 'disconnected-global') {
    assert.equal(after.tabs[after.active_tab].chat_id, before.tabs[before.active_tab].chat_id, `${step.name} preserves the active identity`);
    assert.equal(after.active_workspace, before.active_workspace);
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
  test('session selection survives an automatic title change and skips palette headers', t => {
    const file = path.join(__dirname, 'control-feature-tab-actions.ps1');
    assert.ok(fs.existsSync(file), 'executable native tab journey exists');
    const text = fs.readFileSync(file, 'utf8');
    const select = text.slice(text.indexOf('function Select-ActionTab('), text.indexOf('function Rename-ActionTab('));
    const confirm = text.includes('function Confirm-ActionRow(') ? text.slice(text.indexOf('function Confirm-ActionRow('), text.indexOf('function Select-ActionRow(')) : '';
    const run = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', `
      $ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
      $script:state = '{"active_workspace":0,"active_tab":1,"tabs":[{"chat_id":101,"name":"Control"},{"chat_id":202,"name":"CMD 7"}]}' | ConvertFrom-Json
      $script:tabLog = ''; $script:log = ''; $script:tabPaletteOffset = 0; $script:selected = 0; $script:ready = $false
      $script:window = [IntPtr]202; $script:selectable = @(6301, 0, 1); $script:downs = 0
      function Read-Session { return $script:state }
      function Get-ActionTab($Id) { return @($script:state.tabs | Where-Object { $_.chat_id -eq $Id })[0] }
      function Invoke-JourneyCommand { $script:state.tabs[1].name = 'auto-renamed-folder'; throw 'The mutable CMD 7 query no longer contains the session' }
      function Open-ActionPalette {
        $script:log = "[palette] rows chars=0 count=5 ids=h0 6301 h1 0 1\n[palette] ready chars=0 count=5 target=6301\n"
        $script:state.tabs[1].name = 'auto-renamed-folder'
      }
      function Type-Text { throw 'Session identity must not depend on typing its mutable name' }
      function Read-SharedText { return $script:log }
      function Wait-Until($Condition, $Label) { for ($n=0; $n -lt 5; $n++) { if (& $Condition) { return } }; throw $Label }
      function Press($Keys, $Label) {
        if ($Keys[0] -eq 0x24) { $script:selected = 0 }
        elseif ($Keys[0] -eq 0x28) { $script:selected++; $script:downs++ }
        elseif ($Keys[0] -eq 13) {
          $target = $script:selectable[$script:selected]
          $script:log += "[palette] confirm target=$target\n"
          $script:ready = $target -eq 1
        }
        $script:log += "[palette-row] target=1 session=1 left=236 top=309 height=39 text=280\n"
      }
      function Doctor { }
      function Wait-Foreground { }
      function Assert-Foreground { }
      function Record { }
      Add-Type 'public static class VerifyNative { public static System.Action Receive; public static void ClickClient(System.IntPtr w, int x, int y) { if (w.ToInt64() != 202 || x != 280 || y != 328) throw new System.Exception("Wrong session row"); Receive(); } }'
      [VerifyNative]::Receive = { $script:log += "[palette] confirm target=1\n"; $script:ready = $true }
      function Wait-WorkspaceSurface($Workspace, $Tab, $Chat) { if (-not $script:ready -or $Workspace -ne 0 -or $Tab -ne 1 -or $Chat) { throw 'Wrong native receiving surface' } }
      ${confirm}
      ${select}
      Select-ActionTab 202
      if ($script:downs -ne 2 -or $script:state.tabs[1].name -ne 'auto-renamed-folder') { throw 'Header-aware session selection was not exercised' }
      $rejected = $false
      try { Select-ActionTab 999 } catch { $rejected = $true }
      if (-not $rejected) { throw 'Missing persistent identity was accepted' }
    `], { encoding: 'utf8' });
    if (run.error?.code === 'ENOENT') return t.skip('PowerShell is required to execute stable session selection');
    assert.equal(run.status, 0, run.stderr);
  });
  test('a palette refresh between Home and Down cannot confirm the Back row', t => {
    const text = fs.readFileSync(path.join(__dirname, 'control-feature-tab-actions.ps1'), 'utf8');
    const helper = text.slice(text.indexOf('function Confirm-ActionRow('), text.indexOf('function Select-ActionRow('));
    const run = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', `
      $ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
      $script:tabLog = ''; $script:tabPaletteOffset = 0; $script:window = [IntPtr]202
      $script:log = "[palette-row] target=6304 session=0 left=1 top=999 height=39 text=15\n[palette] rows chars=0 count=4 ids=6302 6320 6303 6304\n"
      $script:selected = 0; $script:confirmed = 0; $script:doctored = $false; $script:foreground = $false
      function Read-SharedText { return $script:log }
      function Type-Text { $script:log += "[palette] rows chars=8 count=2 ids=6302 6304\n[palette] ready chars=8 count=2 target=6304\n" }
      function Wait-Until($Condition, $Label) { for ($n=0; $n -lt 5; $n++) { if (& $Condition) { return } }; throw $Label }
      function Paint { $script:log += "[palette-row] target=6304 session=0 left=236 top=231 height=39 text=250\n" }
      function Doctor { $script:doctored = $true }
      function Wait-Foreground { $script:foreground = $true }
      function Assert-Foreground { if (-not $script:foreground) { throw 'Unowned input' } }
      function Record { }
      function Press($Keys, $Label) {
        if ($Keys[0] -eq 0x24) { $script:selected = 0; Paint }
        elseif ($Keys[0] -eq 0x28) {
          $script:selected = 1
          $script:log += "[palette] rows chars=8 count=2 ids=6302 6304\n[palette] ready chars=8 count=2 target=6304\n"
          $script:selected = ($script:selected + 1) % 2
          Paint
        } elseif ($Keys[0] -eq 13) { $script:confirmed = @(6302, 6304)[$script:selected]; $script:log += "[palette] confirm target=$script:confirmed\n" }
      }
      function Receive-Click($Window, $X, $Y) {
        if (-not $script:doctored -or -not $script:foreground -or $Window -ne 202) { throw 'Missing input ownership' }
        if ($X -ne 250 -or $Y -ne 250) { throw 'Stale or guessed row geometry' }
        $script:confirmed = 6304; $script:log += "[palette] confirm target=6304\n"
      }
      Add-Type 'public static class VerifyNative { public static System.Action<System.IntPtr, int, int> Receive; public static void ClickClient(System.IntPtr w, int x, int y) { Receive(w, x, y); } }'
      [VerifyNative]::Receive = { param($Window, $X, $Y) Receive-Click $Window $X $Y }
      ${helper}
      [void](Confirm-ActionRow 6304 'no group')
      if ($script:confirmed -ne 6304) { throw 'Wrong receiving action' }
    `], { encoding: 'utf8' });
    if (run.error?.code === 'ENOENT') return t.skip('PowerShell is required to reproduce palette selection refresh');
    assert.equal(run.status, 0, run.stderr);
  });
  test('a refreshed unchanged palette row can confirm once more without replaying accepted or changed actions', t => {
    const file = path.join(__dirname, 'control-feature-tab-actions.ps1');
    assert.ok(fs.existsSync(file), 'executable native tab journey exists');
    const text = fs.readFileSync(file, 'utf8');
    const helper = text.slice(text.indexOf('function Confirm-ActionRow('), text.indexOf('function Select-ActionTab('));
    const run = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', `
      $ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
      $Evidence = ''
      function Read-SharedText { return $script:log }
      function Save-Json { }
      function Type-Text { $script:log += "[palette] rows chars=13 count=1 ids=6301\n[palette] ready chars=13 count=1 target=6301\n" }
      function Wait-Until($Condition, $Label) { for ($n = 0; $n -lt 5; $n++) { if (& $Condition) { return } }; throw $Label }
      function Paint { $script:log += "[palette-row] target=6301 session=0 left=236 top=231 height=39 text=250\n" }
      function Doctor { }
      function Wait-Foreground { }
      function Assert-Foreground { }
      function Record { }
      function Press($Keys, $Label) { if ($script:scenario -ne 'no-fresh-paint') { Paint } }
      function Receive-Click {
        $script:clicks++
        if ($script:scenario -eq 'accepted' -or ($script:scenario -eq 'refreshed' -and $script:clicks -eq 2)) { $script:log += "[palette] confirm target=6301\n" }
        elseif ($script:scenario -eq 'refreshed' -or $script:scenario -eq 'keeps-refreshing') { $script:log += "[palette] rows chars=13 count=1 ids=6301\n[palette] ready chars=13 count=1 target=6301\n" }
        elseif ($script:scenario -eq 'changed') { $script:log += "[palette] rows chars=13 count=1 ids=6302\n[palette] ready chars=13 count=1 target=6302\n" }
        elseif ($script:scenario -eq 'selection-changed') { $script:log += "[palette] rows chars=13 count=1 ids=6301\n[palette] ready chars=13 count=1 target=6302\n" }
        elseif ($script:scenario -eq 'query-changed') { $script:log += "[palette] rows chars=0 count=1 ids=6301\n[palette] ready chars=0 count=1 target=6301\n" }
        elseif ($script:scenario -eq 'reordered') { $script:log += "[palette] rows chars=13 count=2 ids=6302 6301\n[palette] ready chars=13 count=2 target=6301\n" }
        elseif ($script:scenario -eq 'other-confirmed') { $script:log += "[palette] confirm target=6302\n[palette] rows chars=13 count=1 ids=6301\n[palette] ready chars=13 count=1 target=6301\n" }
        Paint
      }
      Add-Type 'public static class VerifyNative { public static System.Action Receive; public static void ClickClient(System.IntPtr w, int x, int y) { if (w.ToInt64() != 202 || x != 250 || y != 250) throw new System.Exception("Wrong action row"); Receive(); } }'
      [VerifyNative]::Receive = { Receive-Click }
      $script:window = [IntPtr]202
      ${helper}
      foreach ($scenario in @('refreshed', 'accepted', 'silent', 'changed', 'selection-changed', 'query-changed', 'reordered', 'other-confirmed', 'keeps-refreshing', 'no-fresh-paint')) {
        $script:scenario = $scenario; $script:log = "[palette-row] target=6301 session=0 left=1 top=999 height=39 text=15\n"; $script:clicks = 0
        $script:tabLog = ''; $script:tabPaletteOffset = 0; $script:tabInputs = @()
        $script:tabTargets = [pscustomobject]@{ SEARCH_GROUPMOVE_MENU_OFFSET = 6301 }
        $passed = $false
        try { Select-ActionRow 'SEARCH_GROUPMOVE_MENU_OFFSET' 'move to group'; $passed = $true } catch { }
        $expected = $scenario -in @('refreshed', 'accepted')
        if ($passed -ne $expected) { throw "$scenario receiving-confirm result was $passed" }
        $count = if ($scenario -in @('refreshed', 'keeps-refreshing')) { 2 } elseif ($scenario -eq 'no-fresh-paint') { 0 } else { 1 }
        if ($script:clicks -ne $count) { throw "$scenario sent $script:clicks clicks, expected $count" }
      }
    `], { encoding: 'utf8' });
    if (run.error?.code === 'ENOENT') return t.skip('PowerShell is required to execute native confirmation handling');
    assert.equal(run.status, 0, run.stderr);
  });
  test('returning to home accepts the app-written omitted workspace field', t => {
    const before = { active_tab: 1, active_workspace: 2, workspaces: [{ last_shell: 1 }], tabs: [{ chat_id: 101, shell_id: 1, name: 'Control' }, { chat_id: 202, shell_id: 2, name: 'Target', workspace: 2 }] };
    const after = structuredClone(before); after.active_workspace = 0; after.active_tab = 0; delete after.tabs[1].workspace;
    const step = { name: 'workspace-existing', route: 'context', id: 202 };
    stepEvidence(step, before, after, {}, undefined);
    assert.throws(() => stepEvidence(step, before, { ...after, active_tab: 1 }, {}, undefined), assert.AssertionError);
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
    const select = text.slice(text.indexOf('function Select-ActionTab('), text.indexOf('function Rename-ActionTab('));
    assert.ok(creation);
    const run = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', `
      $ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
      $script:state = '{"workspace_count":2,"active_workspace":1,"active_tab":0,"tabs":[{"chat_id":303,"shell_id":4,"name":"CMD 4"}]}' | ConvertFrom-Json
      $script:renameOpen = $false; $script:consoleSelected = $false
      function Read-Session { return $script:state }
      function Get-ActionTab($Id) { if ($Id -ne 303) { throw 'Wrong peer identity' }; return $script:state.tabs[0] }
      function Press($Keys, $Label) {
        if ($Keys[0] -eq 0x71) {
          if (-not $script:consoleSelected) { throw 'Workspace peer console was not activated before F2' }
          $script:renameOpen = $true
        }
      }
      function Invoke-JourneyCommand { throw 'Workspace peer selection must not depend on its automatic title' }
      function Confirm-ActionRow($Target, $Query = '') {
        if ($Target -ne 0 -or $Query -ne '') { throw 'Wrong workspace peer row identity' }
        $script:consoleSelected = $true
      }
      function Wait-WorkspaceSurface($Workspace, $Tab, $Chat) {
        if (-not $script:consoleSelected -or $Workspace -ne 1 -or $Tab -ne 0 -or $Chat) { throw 'Wrong workspace peer input surface' }
      }
      function Open-ActionPalette { }
      function Select-ActionRow { }
      function Wait-Until($Condition, $Label) { if (-not (& $Condition)) { throw $Label } }
      function Rename-ActionTab($Name) {
        if (-not $script:renameOpen) { throw 'Native rename was not opened' }
        $script:state.tabs[0].name = $Name
        $script:state.tabs[0] | Add-Member manual $true
      }
      ${select}
      ${creation}
      if (-not $script:state.tabs[0].PSObject.Properties['manual'] -or $script:state.tabs[0].name -ne 'Batch workspace peer') { throw 'Workspace peer retains a changing automatic title' }
    `], { encoding: 'utf8' });
    if (run.error?.code === 'ENOENT') return t.skip('PowerShell is required to execute workspace peer creation');
    assert.equal(run.status, 0, run.stderr);
  });
  test('a new tab is explicitly selected after Copy ID before requiring its console focus', t => {
    const file = path.join(__dirname, 'control-feature-tab-actions.ps1');
    assert.ok(fs.existsSync(file), 'executable native tab journey exists');
    const text = fs.readFileSync(file, 'utf8');
    const select = text.slice(text.indexOf('function Select-ActionTab('), text.indexOf('function Rename-ActionTab('));
    const create = text.slice(text.indexOf('function New-ActionTab('), text.indexOf('function Start-ActionStep('));
    const run = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', `
      $ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
      $script:state = '{"active_workspace":0,"active_tab":0,"tabs":[{"chat_id":101,"shell_id":1,"name":"Control"}]}' | ConvertFrom-Json
      $script:consoleSelected = $false
      function Read-Session { return $script:state }
      function Get-ActionTab($Id) { return @($script:state.tabs | Where-Object { $_.chat_id -eq $Id })[0] }
      function Invoke-JourneyCommand($Name, [switch]$Session) {
        if ($Session) {
          if ($Name -ne 'CMD 2') { throw 'Wrong session selected' }
          $script:consoleSelected = $true
        } else {
          $script:state.tabs += [pscustomobject]@{ chat_id=0; shell_id=2; name='CMD 2' }
          $script:state.active_tab = 1
        }
      }
      function Open-ActionPalette { }
      function Confirm-ActionRow($Target, $Query = '') {
        if ($Target -ne 1 -or $Query -ne '') { throw 'Wrong newly created session row identity' }
        $script:consoleSelected = $true
      }
      function Select-ActionRow { $script:state.tabs[1].chat_id = 202 }
      function Wait-Until($Condition, $Label) { if (-not (& $Condition)) { throw $Label } }
      function Wait-WorkspaceSurface($Workspace, $Tab, $Chat) { if (-not $script:consoleSelected -or $Tab -ne 1) { throw 'Saved active tab has not received console focus' } }
      function Press { if (-not $script:consoleSelected) { throw 'F2 before the new console was activated' } }
      function Rename-ActionTab($Name) { $script:state.tabs[1].name = $Name }
      ${select}
      ${create}
      $id = New-ActionTab 'Disconnected context'
      if ($id -ne 202 -or $script:state.tabs[1].name -ne 'Disconnected context' -or $script:state.tabs[0].name -ne 'Control') { throw 'New tab identity or rename changed the wrong session' }
    `], { encoding: 'utf8' });
    if (run.error?.code === 'ENOENT') return t.skip('PowerShell is required to execute new-tab focus handling');
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
  test('native rename uses the focused selected editor without requiring mouse geometry', t => {
    const file = path.join(__dirname, 'control-feature-tab-actions.ps1');
    assert.ok(fs.existsSync(file), 'executable native tab journey exists');
    const text = fs.readFileSync(file, 'utf8');
    const helper = text.slice(text.indexOf('function Rename-ActionTab('), text.indexOf('function New-ActionTab('));
    const rename = fs.readFileSync(path.resolve(__dirname, '../../../src/rename.zig'), 'utf8');
    assert.match(rename, /SendMessageW\(app_state\.g_edit_hwnd, 0x00B1, 0,/, 'the app selects the native editor contents when opening rename');
    const run = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', `
      $ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
      Add-Type 'public class VerifyNative {
        public struct Rect { public int Left, Top, Right, Bottom; }
        public static bool Clicked, Selected; public static int Commits; public static string Value;
        public static System.IntPtr GetFocusedWindow(System.IntPtr window) { return new System.IntPtr(202); }
        public static string Class(System.IntPtr window) { return "Edit"; }
        public static System.IntPtr GetAncestor(System.IntPtr window, uint flag) { return new System.IntPtr(101); }
        public static bool GetClientRect(System.IntPtr window, ref Rect rect) { return false; }
        public static void ClickClient(System.IntPtr window, int x, int y) { if (window.ToInt64() != 202 || x != 150 || y != 12) throw new System.Exception("Wrong editor click"); Clicked = true; }
        public static string EditText(System.IntPtr window) { return Value; }
      }'
      $script:window = [IntPtr]101
      function Doctor { }
      function Wait-Foreground { }
      function Wait-Until($Condition, $Label) { if (-not (& $Condition)) { throw $Label } }
      function Type-Text($Text) { if (-not $script:drop -and [VerifyNative]::Selected) { [VerifyNative]::Value = $Text } }
      function Press($Keys, $Label) {
        if ($Keys[0] -eq 0x11) { [VerifyNative]::Selected = $true }
        if ($Keys[0] -eq 13) { [VerifyNative]::Commits++; if ([VerifyNative]::Value -ne 'Disconnected context') { throw 'Unreceived rename committed' } }
      }
      ${helper}
      foreach ($drop in @($false, $true)) {
        $script:drop = $drop; [VerifyNative]::Clicked = $false; [VerifyNative]::Selected = $true
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
