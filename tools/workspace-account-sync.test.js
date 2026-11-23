const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const read = name => fs.readFileSync(path.join(__dirname, '..', name), 'utf8');
const desktop = read('src/account_desktop.zig');
const workspaces = read('src/workspaces.zig');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

test('SOFT-2295 archive fields are negotiated and omitted for older account services', () => {
  const client = read('src/account_client.zig');
  assert.match(client, /X-Layout-Features: [^"\n]*workspace_archive/);
  assert.match(client, /workspace_archive_supported = layoutSupports\(raw, "workspace_archive"\)/);
  assert.match(desktop, /if \(!remote\.workspace_archive_supported\) rebased = try account_layout\.activeWorkspaces\(alloc, rebased\)/);
  assert.match(body(desktop, 'publishSessionLayout'), /if \(!app_state\.g_account_workspace_archive_supported\) \{[\s\S]*plain_local = account_layout\.activeWorkspaces[\s\S]*plain_base = account_layout\.activeWorkspaces[\s\S]*plain_synced = account_layout\.activeWorkspaces/);
  assert.match(body(desktop, 'handleLayoutReply'), /if \(reply\.workspace_archive_supported\) received\.value else account_layout\.workspaceArchiveFrom/);
  assert.match(body(desktop, 'handleLayoutReply'), /if \(!reply\.workspace_archive_supported\) \{[\s\S]*local_ack = session_layout\.encode\(alloc, account_layout\.activeWorkspaces/);
});

test('SOFT-2295 archived registry entries are captured and inactive deletes publish', () => {
  assert.match(body(desktop, 'captureSessionLayout'), /g_workspaces[\s\S]*\.archived = true/);
  assert.match(body(desktop, 'accountCapturePush'), /withoutRemovedWorkspaces/);
  for (const name of ['archiveWorkspaceByIndex', 'deleteWorkspaceByIndex']) {
    assert.match(body(workspaces, name), /publishSessionLayout\(\)/);
  }
  const keepHeld = body(read('src/account_layout.zig'), 'keepHeld');
  assert.match(keepHeld, /!archived and find\(closed, t\) != null/);
});

test('SOFT-2295 startup and running pulls materialize archive snapshots before showing active workspaces', () => {
  for (const name of ['accountPrepareRestore', 'applyServerLayout']) {
    const source = body(desktop, name);
    assert.ok(source.indexOf('applyAccountWorkspaceArchives') >= 0);
    assert.ok(source.indexOf('applyAccountWorkspaceArchives') < source.indexOf('account_layout.activeWorkspaces'));
  }
  const reconcile = body(workspaces, 'applyAccountWorkspaceArchives');
  assert.match(reconcile, /exportSlotSessionFile\(slot\)/);
  assert.match(reconcile, /hibernateWorkspaceShell\(si\)/);
  assert.match(reconcile, /prepareArchiveCache/);
  assert.match(reconcile, /absorbWorkspaceIntoSlots/);
  assert.match(reconcile, /rememberRemovedWorkspace/);
  assert.doesNotMatch(reconcile, /endTmux|killRemote/);
});

test('SOFT-2295 hosted archive restore delete conflict and legacy-wire round trips', { skip: process.env.GITHUB_ACTIONS !== 'true' }, () => {
  const result = spawnSync(process.env.ZIG || 'zig', ['test', 'src/account_layout.zig', '-j1', '--test-filter', 'SOFT-2295'], {
    cwd: path.join(__dirname, '..'), encoding: 'utf8', timeout: 120000
  });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stderr, /All 6 tests passed/);
});
