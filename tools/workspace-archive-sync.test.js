const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const read = path => fs.readFileSync(new URL('../' + path, 'file://' + __filename), 'utf8');
const worker = read('service/worker.js');
const feature = 'workspace_archive';
const layout = {
  schema: 1,
  revision: 1,
  workspaces: [{ name: 'Other' }, { name: 'Work', archived: true }],
  tabs: [
    { kind: 'tmux', name: 'Stay', tmux_session: 'stay', tmux_host: 0, workspace: 'Other' },
    { kind: 'tmux', name: 'Filed', tmux_session: 'filed', tmux_host: 0, workspace: 'Work' },
  ],
};

function sandbox() {
  const start = worker.indexOf('export function validateLayout(');
  const end = worker.indexOf('\nfunction validateCrashReport', start);
  const source = worker.slice(worker.indexOf('const json ='), worker.indexOf('export function validateLayout')) + worker.slice(start, end).replace('export ', '');
  const context = { Response, TextEncoder, validate: null, respond: null };
  vm.runInNewContext(source + '\nvalidate = validateLayout; respond = layoutResponse;', context);
  return context;
}

function merge(previous, incoming, tokens) {
  const start = worker.indexOf("        if (!layoutFeature(req, 'settings'))");
  const end = worker.indexOf('        const stored = new Map(', start);
  assert.ok(start >= 0 && end > start);
  const context = { previousLayout: structuredClone(previous), layout: structuredClone(incoming), req: new Request('https://example.com', { headers: { 'X-Layout-Features': tokens } }) };
  vm.runInNewContext(worker.slice(worker.indexOf('const layoutFeature ='), worker.indexOf('function layoutResponse')) + worker.slice(start, end), context);
  return JSON.parse(JSON.stringify(context.layout));
}

test('SOFT-2295 the service stores workspace archived and older clients still sync', async () => {
  const { validate, respond } = sandbox();
  assert.doesNotThrow(() => validate(layout));
  assert.doesNotThrow(() => validate({ schema: 1, revision: 1, workspaces: [{ name: 'Other', archived: false }], tabs: [] }));
  for (const archived of [1, 'true', null, []]) {
    assert.throws(() => validate({ ...layout, workspaces: [{ name: 'Other', archived }] }), { status: 400, message: 'invalid_workspace' });
  }
  const capable = respond(new Request('https://example.com', { headers: { 'X-Layout-Features': feature } }), { layout });
  assert.equal(capable.headers.get('X-Layout-Features').split(',').includes(feature), true);
  const seen = (await capable.json()).layout;
  assert.equal(seen.workspaces.find(workspace => workspace.name === 'Work').archived, true);
  assert.equal(Object.hasOwn(seen.workspaces.find(workspace => workspace.name === 'Other'), 'archived'), false);
  assert.deepEqual(seen.tabs.map(tab => tab.tmux_session).sort(), ['filed', 'stay']);
  const older = respond(new Request('https://example.com', { headers: { 'X-Layout-Features': 'groups' } }), { layout });
  assert.equal(older.headers.get('X-Layout-Features').split(',').includes(feature), false);
  const hidden = (await older.json()).layout;
  assert.deepEqual(hidden.workspaces.map(workspace => workspace.name), ['Other']);
  assert.equal(Object.hasOwn(hidden.workspaces[0], 'archived'), false);
  assert.deepEqual(hidden.tabs.map(tab => tab.tmux_session), ['stay']);
  const stored = structuredClone(layout);
  const olderWrite = { ...stored, workspaces: [{ name: 'Other' }, { name: 'Notes' }], tabs: [stored.tabs[0]] };
  const kept = merge(stored, olderWrite, 'groups');
  assert.equal(kept.workspaces.find(workspace => workspace.name === 'Work').archived, true);
  assert.deepEqual(kept.tabs.map(tab => tab.tmux_session).sort(), ['filed', 'stay']);
  const restored = merge(stored, { ...stored, workspaces: stored.workspaces.map(({ archived, ...workspace }) => workspace) }, feature);
  assert.equal(restored.workspaces.every(workspace => workspace.archived !== true), true);
  const removed = merge(stored, { ...stored, workspaces: [stored.workspaces[0]], tabs: [stored.tabs[0]] }, feature);
  assert.equal(removed.workspaces.some(workspace => workspace.name === 'Work'), false);
  assert.deepEqual(removed.tabs.map(tab => tab.tmux_session), ['stay']);
});

test('SOFT-2295 desktop reads and writes the same archived field', () => {
  const session = read('src/session_layout.zig');
  const account = read('src/account_layout.zig');
  const desktop = read('src/account_desktop.zig');
  const client = read('src/account_client.zig');
  const workspaces = read('src/workspaces.zig');
  assert.match(session, /archived: \?bool = null/);
  assert.match(account, /x\.archived orelse false/);
  assert.match(account, /pub fn withArchived\(/);
  assert.match(account, /pub fn withoutArchived\(/);
  assert.match(account, /pub fn visibleLayout\(/);
  assert.match(client, /workspace_archive/);
  assert.match(desktop, /withArchived\(a, base, kept, names, closed\)/);
  assert.match(desktop, /if \(!remote\.workspace_archive_supported\) rebased = try account_layout\.withoutArchived\(alloc, rebased\)/);
  assert.match(desktop, /rememberSyncedArchive\(a, synced_layout\)/);
  assert.match(desktop, /visibleLayout\(a, synced_layout\)/);
  assert.match(workspaces, /pub fn applySyncedWorkspaceArchive\(/);
  const close = workspaces.slice(workspaces.indexOf('pub fn closeMyWorkspaceSlot('), workspaces.indexOf('fn deleteMyWorkspaceSlot('));
  assert.match(close, /const closed_before = app_state\.g_account_closed_count/);
  assert.match(close, /app_state\.g_account_closed_count = closed_before/);
  const restore = workspaces.slice(workspaces.indexOf('pub fn restoreArchivedWorkspaceByIndex('), workspaces.indexOf('fn workspaceDeleteFailed('));
  assert.match(restore, /openSyncedWorkspaceSlot\(id, name\)/);
});
