import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Miniflare, convertV4MiniflareOptions } from 'miniflare';
import { hash } from '../worker.js';

let mf, db;
const owner = 'owner@example.com', other = 'other@example.com';
const ownerToken = 'A'.repeat(43), secondToken = 'B'.repeat(43), otherToken = 'C'.repeat(43);
const path = '/v1/secrets/screencast2';
const call = (token, method = 'GET', value, route = path) => mf.dispatchFetch('http://localhost' + route, {
  method,
  headers: token ? { Authorization: 'Bearer ' + token } : {},
  ...(value === undefined ? {} : { body: JSON.stringify(value) })
});

before(async () => {
  mf = new Miniflare(convertV4MiniflareOptions({ modules: true, scriptPath: new URL('../.build/worker.js', import.meta.url).pathname, compatibilityDate: '2026-10-09', compatibilityFlags: ['nodejs_compat'], d1Databases: ['DB'], bindings: { ALLOWED_EMAILS: owner, AUTH_ORIGINS: 'http://localhost', RP_ID: 'localhost' } }));
  db = await mf.getD1Database('DB');
  for (const sql of readFileSync(new URL('../schema.sql', import.meta.url), 'utf8').split(';').filter(s => s.trim())) await db.prepare(sql).run();
  for (const [token, account, id] of [[ownerToken, owner, 'owner'], [secondToken, owner, 'second'], [otherToken, other, 'other']]) {
    await db.prepare('INSERT INTO devices (id,account,name,refresh_hash,created,last_seen,revoked) VALUES (?,?,?,?,?,?,0)').bind(id, account, id, id + '-refresh', 1, 1).run();
    await db.prepare('INSERT INTO access_tokens (hash,device,expires) VALUES (?,?,?)').bind(await hash(token), id, Math.floor(Date.now() / 1000) + 600).run();
  }
});
after(async () => { await mf?.dispose(); });

test('screencast2 GET and PUT require an authenticated device', async () => {
  for (const token of [undefined, 'invalid', 'Z'.repeat(43)]) {
    assert.equal((await call(token)).status, 401);
    assert.equal((await call(token, 'PUT', { key: 'fixture-upload-key' })).status, 401);
  }
  for (const kind of ['a', 'w']) {
    const key = 'mpk_' + kind + '_' + 'K'.repeat(43);
    await db.prepare('INSERT INTO service_keys (hash,account,kind,workspace,label,created) VALUES (?,?,?,?,?,?)').bind(await hash(key), owner, kind === 'a' ? 'admin' : 'workspace', kind === 'w' ? 'Work' : null, 'fixture', 1).run();
    assert.equal((await call(key)).status, 403);
    assert.equal((await call(key, 'PUT', { key: 'fixture-upload-key' })).status, 403);
  }
});

test('screencast2 validates keys exactly like Deepgram', async () => {
  for (const key of [{}, { key: '' }, { key: 5 }, { key: 'x'.repeat(257) }, { key: 'has space' }, { key: 'café' }, { key: 'x\n' }, { key: 'x', extra: true }, ['x']]) {
    const response = await call(ownerToken, 'PUT', key);
    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), { error: 'invalid_secret' });
  }
  assert.equal((await call(ownerToken, 'PUT', { key: 'x'.repeat(1024) })).status, 413);
});

test('screencast2 round trip shares within an account, not across accounts or secret names', async () => {
  assert.equal((await call(ownerToken)).status, 404);
  assert.equal((await call(ownerToken, 'PUT', { key: 'fixture-upload-key' })).status, 200);
  const read = await call(secondToken);
  assert.equal(read.status, 200);
  assert.equal(read.headers.get('Cache-Control'), 'no-store');
  assert.deepEqual(await read.json(), { key: 'fixture-upload-key' });
  const row = await db.prepare('SELECT value FROM account_secrets WHERE account=? AND name=?').bind(owner, 'screencast2').first();
  assert.equal(row.value, 'fixture-upload-key');
  assert.equal((await call(ownerToken, 'GET', undefined, '/v1/secrets/deepgram')).status, 404);
  assert.equal((await call(ownerToken, 'PUT', { key: 'fixture-dictation-key' }, '/v1/secrets/deepgram')).status, 200);
  assert.equal((await call(otherToken)).status, 404);
  assert.equal((await call(otherToken, 'PUT', { key: 'fixture-other-account-key', account: owner })).status, 400);
  assert.equal((await call(otherToken, 'PUT', { key: 'fixture-other-account-key' })).status, 200);
  assert.deepEqual(await (await call(ownerToken)).json(), { key: 'fixture-upload-key' });
  assert.deepEqual(await (await call(otherToken)).json(), { key: 'fixture-other-account-key' });
  const replacement = 'R'.repeat(256);
  assert.equal((await call(secondToken, 'PUT', { key: replacement })).status, 200);
  assert.deepEqual(await (await call(ownerToken)).json(), { key: replacement });
  assert.deepEqual(await (await call(ownerToken, 'GET', undefined, '/v1/secrets/deepgram')).json(), { key: 'fixture-dictation-key' });
  for (const route of ['/v1/secrets/unknown', path + '/extra']) {
    assert.equal((await call(ownerToken, 'GET', undefined, route)).status, 404);
    assert.equal((await call(ownerToken, 'PUT', { key: 'fixture-key' }, route)).status, 404);
  }
  await db.prepare('UPDATE devices SET revoked=1 WHERE id=?').bind('second').run();
  assert.equal((await call(secondToken)).status, 401);
  assert.equal((await call(secondToken, 'PUT', { key: 'fixture-revoked-key' })).status, 401);
});
