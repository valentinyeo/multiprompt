const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { execFile, spawnSync } = require('node:child_process');
const { promisify } = require('node:util');
const { readFileSync } = require('node:fs');
const path = require('node:path');
const run = promisify(execFile);
const root = path.resolve(__dirname, '..');
const script = path.join(root, 'service/crash-reports.py');
const rows = Array.from({ length: 25 }, (_, i) => ({
  device_id: i % 2 ? 'device-a' : 'device-b',
  report_id: `report-${i}`,
  device_name: i % 2 ? 'Pixel 测试' : 'Tablet',
  received_at: 1700000000 + Math.floor(i / 2),
  captured_at: 1699999999 - i,
  app_version: '0.1.2 (3)',
  android_version: '15 (SDK 35)',
  thread: 'main',
  summary: `Crash ${i}: 测试`,
  stack_trace: 'java.lang.IllegalStateException: 测试\n\tat dev.multiprompt.Main.run(Main.kt:42)',
}));
const sqlite = `
import json, sqlite3, sys
sys.stdout.reconfigure(encoding='utf-8')
data = json.load(sys.stdin)
db = sqlite3.connect(':memory:')
db.row_factory = sqlite3.Row
db.executescript('CREATE TABLE devices (id TEXT PRIMARY KEY, name TEXT); CREATE TABLE crash_reports (device_id TEXT, report_id TEXT, received_at INTEGER, captured_at INTEGER, app_version TEXT, android_version TEXT, thread TEXT, summary TEXT, stack_trace TEXT, account TEXT DEFAULT "not-selected");')
for row in data['rows']:
    db.execute('INSERT OR IGNORE INTO devices VALUES (?,?)', (row['device_id'], row['device_name']))
    db.execute('INSERT INTO crash_reports (device_id,report_id,received_at,captured_at,app_version,android_version,thread,summary,stack_trace) VALUES (?,?,?,?,?,?,?,?,?)', tuple(row[k] for k in ('device_id','report_id','received_at','captured_at','app_version','android_version','thread','summary','stack_trace')))
db.set_authorizer(lambda op, *args: sqlite3.SQLITE_OK if op in (sqlite3.SQLITE_SELECT, sqlite3.SQLITE_READ) else sqlite3.SQLITE_DENY)
print(json.dumps([dict(row) for row in db.execute(data['sql'], data['params'])], ensure_ascii=False))
`;

async function reader(args = [], overrides = {}) {
  const env = {
    PATH: process.env.PATH,
    SYSTEMROOT: process.env.SYSTEMROOT,
    PYTHONIOENCODING: 'ascii',
    TZ: 'Pacific/Honolulu',
    CLOUDFLARE_ACCOUNT_ID: 'test-account',
    CLOUDFLARE_API_TOKEN: 'test-token',
    ...overrides,
  };
  for (const key of Object.keys(env)) if (env[key] === undefined) delete env[key];
  try {
    return { status: 0, ...await run('python3', [script, ...args], { env, encoding: 'utf8', timeout: 10000 }) };
  } catch (error) {
    return { status: error.code, stdout: error.stdout, stderr: error.stderr };
  }
}

async function fakeApi(t, options = {}) {
  const requests = [];
  const errors = [];
  const server = http.createServer(async (request, response) => {
    try {
      const url = new URL(request.url, 'http://localhost');
      assert.equal(request.headers.authorization, 'Bearer test-token');
      requests.push({ method: request.method, path: url.pathname, search: url.searchParams });
      response.setHeader('Content-Type', 'application/json; charset=utf-8');
      if (request.method === 'GET') {
        assert.equal(url.pathname, '/client/v4/accounts/test-account/d1/database');
        response.end(JSON.stringify({ success: true, result: options.missingDatabase ? [] : [{ name: 'other' }, { name: url.searchParams.get('name'), uuid: 'test-database' }] }));
        return;
      }
      assert.equal(request.method, 'POST');
      assert.equal(url.pathname, '/client/v4/accounts/test-account/d1/database/test-database/query');
      assert.equal(request.headers['content-type'], 'application/json');
      let body = '';
      for await (const chunk of request) body += chunk.toString('utf8');
      const query = JSON.parse(body);
      requests.at(-1).query = query;
      assert.match(query.sql, /^SELECT\s/i);
      assert.doesNotMatch(query.sql, /\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|REPLACE|PRAGMA|ATTACH)\b|;/i);
      assert.match(query.sql, /FROM crash_reports\b.*JOIN devices\b/i);
      assert.doesNotMatch(query.sql, /\*|\baccount\b/);
      const result = spawnSync('python3', ['-c', sqlite], { input: JSON.stringify({ ...query, rows: options.rows || rows }), encoding: 'utf8' });
      assert.equal(result.status, 0, result.stderr);
      response.end(JSON.stringify({ success: !options.apiFailure, result: [{ success: !options.queryFailure, results: JSON.parse(result.stdout) }] }));
    } catch (error) {
      errors.push(error);
      response.writeHead(500);
      response.end('{}');
    }
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(async () => {
    await new Promise(resolve => server.close(resolve));
    assert.deepEqual(errors, []);
  });
  return { requests, env: { CLOUDFLARE_API_BASE_URL: `http://127.0.0.1:${server.address().port}/client/v4/` } };
}

for (const name of ['CLOUDFLARE_ACCOUNT_ID', 'CLOUDFLARE_API_TOKEN']) {
  for (const value of [undefined, '', '   ']) {
    test(`missing or blank ${name}: ${JSON.stringify(value)}`, async () => {
      const result = await reader([], { [name]: value });
      assert.notEqual(result.status, 0);
      assert.match(result.stderr, new RegExp(`Missing required environment variable: ${name}`));
      assert.doesNotMatch(result.stderr, /Traceback/);
    });
  }
}

test('help works offline without credentials', async () => {
  const result = await reader(['--help'], { CLOUDFLARE_ACCOUNT_ID: undefined, CLOUDFLARE_API_TOKEN: undefined });
  assert.equal(result.status, 0, result.stderr);
  for (const option of ['--limit', '--database', '--json']) assert.ok(result.stdout.includes(option));
});

test('formats every report field in UTF-8 and UTC, newest received first with rowid ties', async t => {
  const api = await fakeApi(t);
  const result = await reader(['--limit', '2'], api.env);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), [rows[24], rows[23]].map(row => [
    `Device: ${row.device_name}`, `Report: ${row.report_id}`,
    `Received: ${new Date(row.received_at * 1000).toISOString().replace('.000Z', '+00:00')}`,
    `Captured: ${new Date(row.captured_at * 1000).toISOString().replace('.000Z', '+00:00')}`,
    `App version: ${row.app_version}`, `Android version: ${row.android_version}`,
    `Thread: ${row.thread}`, `Summary: ${row.summary}`, 'Stack trace:', row.stack_trace,
  ].join('\n')).join('\n\n'));
  assert.deepEqual(api.requests[1].query.params, [2]);
  assert.equal(api.requests[0].search.get('name'), 'multiprompt-account');
});

test('JSON returns unmodified selected rows, defaults to 20 and honors database override', async t => {
  const api = await fakeApi(t);
  const result = await reader(['--json', '--database', 'custom database'], api.env);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), rows.toReversed().slice(0, 20));
  assert.deepEqual(api.requests[1].query.params, [20]);
  assert.equal(api.requests[0].search.get('name'), 'custom database');
});

test('device filtering is parameterized and cannot inject writes', async t => {
  const api = await fakeApi(t);
  const result = await reader(['--json', '--device', 'device-a', '--limit', '3'], api.env);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), rows.toReversed().filter(row => row.device_id === 'device-a').slice(0, 3));
  const hostile = "device-a'; DELETE FROM crash_reports; --";
  const injected = await reader(['--json', '--device', hostile], api.env);
  assert.equal(injected.status, 0, injected.stderr);
  assert.deepEqual(JSON.parse(injected.stdout), []);
  assert.deepEqual(api.requests[3].query.params, [hostile, 20]);
  assert.ok(!api.requests[3].query.sql.includes(hostile));
});

for (const limit of ['0', '-1', 'oops', '1; DELETE FROM crash_reports']) {
  test(`invalid limit is rejected offline: ${limit}`, async () => {
    const result = await reader(['--limit', limit]);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /--limit/);
  });
}

test('empty results produce an empty JSON array', async t => {
  const api = await fakeApi(t, { rows: [] });
  const result = await reader(['--json'], api.env);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), []);
});

for (const option of ['missingDatabase', 'apiFailure', 'queryFailure']) {
  test(`API failure is clear without exposing authentication: ${option}`, async t => {
    const api = await fakeApi(t, { [option]: true });
    const result = await reader([], api.env);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /database not found|Crash report read failed/);
    assert.doesNotMatch(result.stderr, /test-token|Traceback/);
  });
}

test('SQL oracle rejects a write as a positive control', () => {
  const result = spawnSync('python3', ['-c', sqlite], { input: JSON.stringify({ rows, sql: 'DELETE FROM crash_reports', params: [] }), encoding: 'utf8' });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /not authorized/);
});

test('existing CI runs this test through the Linux test-vps build step', () => {
  const build = readFileSync(path.join(root, 'build.zig'), 'utf8');
  const workflow = readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  assert.match(build, /const crash_reports_tests = b\.addSystemCommand\(&\.\{ "node", "--test", "tools\/crash-reports\.test\.js" \}\);/);
  assert.match(build, /vps_test_step\.dependOn\(&crash_reports_tests\.step\);/);
  assert.match(workflow, /zig build test-vps --summary all/);
  assert.match(workflow, /python-version: '3\.12'/);
});
