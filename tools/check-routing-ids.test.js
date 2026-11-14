const test = require('node:test');
const assert = require('node:assert/strict');
const { mkdtempSync, mkdirSync, writeFileSync, copyFileSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
const { spawnSync } = require('node:child_process');
const api = import('./check-routing-ids.mjs');

async function check(source, bands = [], extra = {}) {
  return (await api).checkRouting({ 'src/state.zig': source, ...extra }, bands);
}

const band = { name: 'workspace_delete', base: 'SEARCH_WORKSPACE_DELETE_OFFSET', size: 'MAX_WORKSPACES' };
const base = 'const MAX_WORKSPACES = 64;\nconst SEARCH_WORKSPACE_DELETE_OFFSET: usize = 6400;\n';

test('historical f95d969 lock IDs fail the allocation oracle with locations and fixes', async () => {
  const result = await check(base + 'const SEARCH_CHAT_VIEW_LOCK_SHELL_OFFSET = 6401;\nconst SEARCH_CHAT_VIEW_LOCK_CLEAR_OFFSET = 6402;', [band]);
  assert.equal(result.errors.length, 2);
  for (const [i, id] of [6401, 6402].entries()) {
    assert.match(result.errors[i], new RegExp(`src/state.zig:${i + 3} SEARCH_CHAT_VIEW_LOCK_.*=${id} overlaps workspace_delete \\[6400,6464\\)`));
    assert.match(result.errors[i], /pick a free id outside every band in tools\/routing-id-bands.json/);
  }
});

test('resolves const arithmetic, hex, parentheses and imported sizes without counting reexports', async () => {
  const result = await check(base + '\nconst SEARCH_AFTER = SEARCH_WORKSPACE_DELETE_OFFSET + MAX_WORKSPACES;\nconst SEARCH_NEGATIVE = (0x100 - 1) + 2;', [band], {
    'src/use.zig': 'const state = @import("state.zig"); const SEARCH_AFTER = state.SEARCH_AFTER; const SEARCH_WORKSPACE_DELETE_OFFSET = @import("state.zig").SEARCH_WORKSPACE_DELETE_OFFSET;'
  });
  assert.deepEqual(result.errors, []);
  assert.equal(result.scalars, 3);
});

test('all scalar names participate, including tab-context constants and aliases', async () => {
  const result = await check('const SEARCH_TABCTX_VIEW = 7100;\nconst SEARCH_OTHER = SEARCH_TABCTX_VIEW;');
  assert.match(result.errors.join('\n'), /src\/state.zig:2 SEARCH_OTHER=7100 overlaps src\/state.zig:1 SEARCH_TABCTX_VIEW/);
});

test('half-open boundaries and only the actual defining base are exempt', async () => {
  assert.deepEqual((await check(base + 'const SEARCH_LAST = 6464;', [band])).errors, []);
  assert.match((await check(base + 'const SEARCH_ALIAS = 6400;', [band])).errors.join('\n'), /SEARCH_ALIAS=6400 overlaps workspace_delete/);
});

test('overlapping bands fail even without interior scalar commands', async () => {
  const result = await check(base + 'const SEARCH_SECOND = 6390;', [band, { name: 'second', base: 'SEARCH_SECOND', size: 11 }]);
  assert.match(result.errors.join('\n'), /workspace_delete \[6400,6464\) overlaps .*second \[6390,6401\)/);
});

test('discovers unregistered dynamic bands, including qualified and reversed additions', async () => {
  for (const expr of ['SEARCH_WORKSPACE_DELETE_OFFSET + index', 'index + state.SEARCH_WORKSPACE_DELETE_OFFSET']) {
    const result = await check(base + `\nfn row(index: usize) usize { return ${expr}; }`);
    assert.match(result.errors.join('\n'), /base-plus-index band absent.*register its full size/);
  }
  assert.deepEqual((await check(base + 'fn row(i: usize) usize { return SEARCH_WORKSPACE_DELETE_OFFSET + i; }', [band])).errors, []);
});

test('comments, quoted text and multiline Zig strings are not allocations', async () => {
  const source = ['const SEARCH_GOOD = 1;', '/' + '/ const SEARCH_BAD = 1;', 'const text = "const SEARCH_BAD = 1;";', '\\\\const SEARCH_BAD = 1;', "const c = 'a';"].join('\n');
  assert.deepEqual((await check(source)).errors, []);
});

test('unresolved, cyclic and unsupported routing arithmetic fails closed', async () => {
  for (const source of ['const SEARCH_BAD = missing + 1;', 'const SEARCH_BAD = SEARCH_BAD + 1;', 'const SEARCH_BAD = 2 * 4;']) {
    assert.match((await check(source)).errors.join('\n'), /use resolvable integer constants/);
  }
  assert.match((await check(base, [{ ...band, size: 'MISSING' }])).errors.join('\n'), /routing-id-bands.json/);
});

test('cross-module message allocations and raw WM_APP uses share a namespace', async () => {
  const source = 'const WM_APP = 0x8000; const WM_APP_CHAT_FIND = WM_APP + 202;';
  for (const second of ['const WM_APP_PERMISSION = WM_APP + 202;', 'fn send() void { post(WM_APP + 202); }', 'const WM_APP_PERMISSION = WM_APP_CHAT_FIND;']) {
    const result = await check(source, [], { 'src/permission.zig': `const WM_APP = @import("state.zig").WM_APP; const WM_APP_CHAT_FIND = @import("state.zig").WM_APP_CHAT_FIND; ${second}` });
    assert.match(result.errors.join('\n'), /overlaps .*duplicate WM_APP id 202/);
  }
  assert.deepEqual((await check(source + 'const WM_APP_PERMISSION = WM_APP + 203;')).errors, []);
});

test('CLI reads recursive src files and root-local band manifest', t => {
  const root = mkdtempSync(join(tmpdir(), 'routing-ids-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  mkdirSync(join(root, 'src/nested'), { recursive: true });
  mkdirSync(join(root, 'tools'));
  copyFileSync(join(__dirname, 'check-routing-ids.mjs'), join(root, 'tools/check-routing-ids.mjs'));
  writeFileSync(join(root, 'tools/routing-id-bands.json'), JSON.stringify([band]));
  writeFileSync(join(root, 'src/nested/state.zig'), base);
  const run = () => spawnSync(process.execPath, [join(root, 'tools/check-routing-ids.mjs'), '--root', root], { encoding: 'utf8' });
  assert.equal(run().status, 0);
  writeFileSync(join(root, 'src/nested/state.zig'), base + 'const SEARCH_BAD = 6401;');
  const red = run();
  assert.equal(red.status, 1);
  assert.match(red.stderr, /src\/nested\/state.zig:3 SEARCH_BAD=6401 overlaps/);
});

test('registered bands must reserve the full source comparison bound', async () => {
  const source = base + 'fn row(target: usize) bool { const inside = target < SEARCH_WORKSPACE_DELETE_OFFSET + MAX_WORKSPACES; return inside; }';
  assert.deepEqual((await check(source, [band])).errors, []);
  assert.match((await check(source, [{ ...band, size: 32 }])).errors.join('\n'), /source bound 64 exceeds workspace_delete size 32/);
});

test('raw WM_APP arithmetic is resolved before duplicate detection', async () => {
  const source = 'const WM_APP = 0x8000; const WM_APP_CHAT_FIND = WM_APP + 202; fn send() void { post(WM_APP + (200 + 2)); }';
  assert.match((await check(source)).errors.join('\n'), /duplicate WM_APP id 202/);
});
