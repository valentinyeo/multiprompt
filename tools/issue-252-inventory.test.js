const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const inventory = JSON.parse(read('docs/sync-fields.json'));
const fields = text => [...new Set([...text.matchAll(/\\"([a-zA-Z_][a-zA-Z_0-9]*)\\"\s*:/g)].map(m => m[1]))].sort();
function section(file, start, end) {
  const text = read(file);
  const at = text.indexOf(start);
  assert.ok(at >= 0, start);
  const to = text.indexOf(end, at + start.length);
  assert.ok(to > at, end);
  return text.slice(at, to);
}
function audit(source, documented) {
  for (const field of fields(source)) assert.ok(Object.hasOwn(documented, field), `Unclassified persisted field: ${field}`);
  for (const policy of Object.values(documented)) assert.ok(['sync', 'never-sync'].includes(policy));
}

test('ISSUE-252 every local session serializer field has an explicit inventory policy', () => {
  const source = section('src/session.zig', 'pub fn saveSessionTo(', '\npub fn saveSession(') +
    section('src/sidebar.zig', 'pub fn writeArchiveMarkers(', '\npub fn restoreArchiveMarkers(') +
    section('src/frequent.zig', 'pub fn writeInput(', '\ntest ') +
    section('src/workspaces.zig', 'fn exportSlotSessionFile(', '\nfn ');
  audit(source, inventory.session.fields);
  assert.throws(() => audit(source + '\nconst added = "\\"unreviewed_secret\\":true";', inventory.session.fields), /unreviewed_secret/);
  for (const field of ['cwd', 'ccwd', 'favicon_path', 'pid', 'shell_id', 'wid', 'bsplit', 'burl', 'archive_rows', 'done_rows']) assert.equal(inventory.session.fields[field], 'never-sync');
  for (const field of ['name', 'kind', 'tmux_session', 'tmux_host', 'workspace', 'manual', 'favorite', 'used', 'input', 'visits']) assert.equal(inventory.session.fields[field], 'sync');
});

test('ISSUE-252 host and registry inventory separates portable identity from local credentials and handles', () => {
  const registry = section('src/workspaces.zig', 'fn writeWorkspaceRegistryFile(', '\n}');
  audit(registry, inventory.workspace_registry.fields);
  assert.throws(() => audit(registry + '\n"\\"password\\":false"', inventory.workspace_registry.fields), /password/);
  for (const field of ['host_keys', 'IdentityFile', 'CertificateFile', 'IdentityAgent', 'password', 'private_key', 'public_key', '*']) assert.equal(inventory.hosts.fields[field], 'never-sync');
  for (const policy of Object.values(inventory.window_geometry.fields)) assert.equal(policy, 'never-sync');
  const doc = read('docs/laptop-sync.md');
  for (const term of ['PR #12', 'IGSH-423', '/v1/layout', '/v1/sync-records', 'Not deployed', 'plaintext', 'Local CMD']) assert.ok(doc.includes(term), term);
});
