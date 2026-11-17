const test = require('node:test');
const assert = require('node:assert/strict');
const { checkFeatureMap, loadFeatureMap } = require('./check-feature-map.cjs');

const loaded = loadFeatureMap();

test('every source action has one reachable recipe or explicit missing prerequisite', async () => {
  assert.deepEqual(checkFeatureMap(await loaded), []);
});

test('missing, duplicate and dead index entries fail with the repair', async () => {
  const input = await loaded;
  const files = new Map(input.files);
  files.set('README.md', files.get('README.md').replace('- [Chat in long sessions](long-session-chat.md).', '') + '\n[dead](removed-feature.md)\n[duplicate](palette.md)\n');
  const errors = checkFeatureMap({ ...input, files });
  assert.ok(errors.includes('Index long-session-chat.md exactly once in features/README.md'));
  assert.ok(errors.includes('Index palette.md exactly once in features/README.md'));
  assert.ok(errors.includes('Remove dead index link removed-feature.md'));
});

test('new shortcut and palette actions cannot silently escape the map', async () => {
  const input = await loaded;
  const errors = checkFeatureMap({ ...input,
    shortcutRows: [...input.shortcutRows, { a: 'Ctrl+New', b: 'New visible action', header: false }],
    paletteSource: input.paletteSource + '\napp_state.g_search_results[0] = SEARCH_NEW_VISIBLE_ACTION_OFFSET;\n',
  });
  assert.ok(errors.some(error => error.includes('Ctrl+New / New visible action')));
  assert.ok(errors.includes('Map palette row/family SEARCH_NEW_VISIBLE_ACTION_OFFSET in its owning feature file'));
});

test('architecture additions and broken recipe anchors cannot masquerade as coverage', async () => {
  const input = await loaded;
  const files = new Map(input.files);
  files.set('shortcuts.md', files.get('shortcuts.md').replace('sidebar-sessions.md#select-select-and-reopen-sessions', 'sidebar-sessions.md#missing-recipe'));
  const errors = checkFeatureMap({ ...input, files, architectureSource: input.architectureSource + '\n- **New user feature**: do something.\n' });
  assert.ok(errors.includes('Map architecture feature New user feature'));
  assert.ok(errors.some(error => error.includes('missing heading sidebar-sessions.md#missing-recipe')));
});

test('server-group recipe can read and republish the same layout with its generated module', async t => {
  const fs = require('node:fs');
  const path = require('node:path');
  const os = require('node:os');
  const http = require('node:http');
  const { execFile } = require('node:child_process');
  const { promisify } = require('node:util');
  const driver = fs.readFileSync(path.join(__dirname, 'control-feature-server-open-group.ps1'), 'utf8');
  const script = driver.match(/WriteAllText\(\$bumpPath, "([^]*?)"\)/)?.[1];
  assert.ok(script, 'extract the actual generated account-layout module');
  const call = driver.match(/Invoke-ServerGroupNode @\(([^)]*\$bumpPath[^)]*)\)/)?.[1];
  assert.ok(call, 'extract the actual node invocation');
  const flags = [...call.matchAll(/'([^']+)'/g)].map(match => match[1]);
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-server-group-module-'));
  t.after(() => fs.rmSync(scratch, { recursive: true, force: true }));
  const modulePath = path.join(scratch, 'bump.mjs');
  const statePath = path.join(scratch, 'state.json');
  fs.writeFileSync(modulePath, script.replace(/`n/g, '\n'));
  fs.writeFileSync(statePath, JSON.stringify({ admin_key: 'synthetic-fixture-only' }));
  const layout = { groups: [{ id: 1, name: 'Runners' }], tabs: [{ tmux: 'fixture-session', group: 'Runners' }] };
  const requests = [];
  const server = http.createServer((request, response) => {
    let body = '';
    request.on('data', chunk => { body += chunk; });
    request.on('end', () => {
      requests.push({ method: request.method, url: request.url, authorization: request.headers.authorization, body });
      response.setHeader('Content-Type', 'application/json');
      response.end(JSON.stringify({ revision: 7, layout }));
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  await promisify(execFile)(process.execPath, [...flags, modulePath], { timeout: 10000, env: { ...process.env, MP_STATE: statePath, MP_URL: `http://127.0.0.1:${server.address().port}` } });
  assert.deepEqual(requests.map(request => [request.method, request.url]), [['GET', '/v1/layout'], ['PUT', '/v1/layout']]);
  assert.ok(requests.every(request => request.authorization === 'Bearer synthetic-fixture-only'));
  assert.deepEqual(JSON.parse(requests[1].body), { base_revision: 7, layout });
});
