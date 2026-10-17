import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Miniflare, convertV4MiniflareOptions } from 'miniflare';
import { hash, validateLayout, identity } from '../worker.js';

let mf, db, jwt, badJwt, invalidClaims;
const base = 'http://localhost';
const team = 'test.cloudflareaccess.com', aud = 'test-audience';
const encode = obj => Buffer.from(JSON.stringify(obj)).toString('base64url');
const layout = { schema: 1, revision: 1, workspaces: [{ name: 'Other' }], tabs: [{ kind: 'tmux', name: 'One', tmux_session: 'one', tmux_host: 0, workspace: 'Other' }] };
const request = (path, options) => mf.dispatchFetch(base + path, options);
const post = b => ({ method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(b) });
const verifier = 'x'.repeat(64), state = 's'.repeat(43);
async function login(token = jwt, redirect = 'http://127.0.0.1:43210/callback') {
  const url = '/login?' + new URLSearchParams({ redirect_uri: redirect, state, code_challenge: await hash(verifier), code_challenge_method: 'S256', device_name: 'Test device' });
  return request(url, { headers: { 'Cf-Access-Jwt-Assertion': token }, redirect: 'manual' });
}
async function enroll() {
  const r = await login(); assert.equal(r.status, 302);
  const target = new URL(r.headers.get('Location')); assert.equal(target.searchParams.get('state'), state);
  const grant = { grant_type: 'authorization_code', code: target.searchParams.get('code'), code_verifier: verifier, redirect_uri: 'http://127.0.0.1:43210/callback' };
  const response = await request('/oauth/token', post(grant)); assert.equal(response.status, 200);
  return { token: await response.json(), grant };
}
const auth = token => ({ Authorization: 'Bearer ' + token.access_token });
before(async () => {
  const pair = await crypto.subtle.generateKey({ name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, ['sign', 'verify']);
  const jwk = { ...await crypto.subtle.exportKey('jwk', pair.publicKey), kid: 'test-key' };
  async function sign(email, overrides = {}) {
    const hp = encode({ alg: 'RS256', kid: jwk.kid }) + '.' + encode({ iss: `https://${team}`, aud: [aud], exp: Math.floor(Date.now() / 1000) + 600, email, ...overrides });
    return hp + '.' + Buffer.from(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', pair.privateKey, new TextEncoder().encode(hp))).toString('base64url');
  }
  jwt = await sign('owner@example.com'); badJwt = await sign('intruder@example.com');
  invalidClaims = await Promise.all([{ aud: ['wrong-audience'] }, { iss: 'https://wrong.cloudflareaccess.com' }, { exp: 0 }, { nbf: Math.floor(Date.now() / 1000) + 600 }].map(claims => sign('owner@example.com', claims)));
  mf = new Miniflare(convertV4MiniflareOptions({ outboundService: async req => { assert.equal(req.url, `https://${team}/cdn-cgi/access/certs`); return new Response(JSON.stringify({ keys: [jwk] })); }, modules: true, scriptPath: new URL('../worker.js', import.meta.url).pathname, compatibilityDate: '2026-07-30', d1Databases: ['DB'], bindings: { ACCESS_TEAM: team, ACCESS_AUD: aud, ACCOUNT_EMAIL: 'owner@example.com' } }));
  db = await mf.getD1Database('DB');
  for (const sql of readFileSync(new URL('../schema.sql', import.meta.url), 'utf8').split(';').filter(s => s.trim())) await db.prepare(sql).run();
  await db.prepare('INSERT INTO layouts VALUES (?,?,?)').bind('owner@example.com', 1, JSON.stringify(layout)).run();
});
after(async () => { await mf?.dispose(); });

test('missing deployment identity configuration fails closed', async () => {
  for (const env of [{}, { ACCESS_TEAM: team, ACCESS_AUD: aud }, { ACCOUNT_EMAIL: 'owner@example.com' }]) {
    await assert.rejects(identity(new Request(base + '/login'), env), { status: 401 });
  }
});

test('missing, forged, wrong identity/audience/issuer and expired/future Access assertions cannot sign in', async () => {
  for (const token of ['', 'forged', badJwt, jwt.replace(/(?<=\.)[^.](?=[^.]+$)/, c => c === 'a' ? 'b' : 'a'), ...invalidClaims]) assert.equal((await login(token)).status, 401);
  assert.equal((await login(jwt)).status, 302);
});
test('only exact loopback callback is accepted; state and S256 are required', async () => {
  for (const uri of ['https://evil.example/callback', 'http://localhost:1234/callback', 'http://127.0.0.1:70000/callback', 'http://127.0.0.1:1234/evil', 'http://127.0.0.1:1234/callback?evil=1']) assert.equal((await login(jwt, uri)).status, 400);
  assert.equal((await request('/login?redirect_uri=http://127.0.0.1:1234/callback', { headers: { 'Cf-Access-Jwt-Assertion': jwt } })).status, 400);
});
test('PKCE wrong verifier and redirect rejected; code is single use even concurrently', async () => {
  const { token, grant } = await enroll();
  assert.equal((await request('/oauth/token', post(grant))).status, 400);
  const r = await login(); const code = new URL(r.headers.get('Location')).searchParams.get('code');
  assert.equal((await request('/oauth/token', post({ ...grant, code, code_verifier: 'z'.repeat(64) }))).status, 400);
  assert.equal((await request('/oauth/token', post({ ...grant, code, redirect_uri: 'http://127.0.0.1:123/callback' }))).status, 400);
  const results = await Promise.all([request('/oauth/token', post({ ...grant, code })), request('/oauth/token', post({ ...grant, code }))]);
  assert.deepEqual(results.map(r => r.status).sort(), [200, 400]); assert.equal(token.expires_in, 600);
});
test('expired codes and expired access tokens are rejected', async () => {
  const r = await login(); const code = new URL(r.headers.get('Location')).searchParams.get('code');
  await db.prepare('UPDATE codes SET expires=0').run();
  assert.equal((await request('/oauth/token', post({ grant_type: 'authorization_code', code, code_verifier: verifier, redirect_uri: 'http://127.0.0.1:43210/callback' }))).status, 400);
  const { token } = await enroll(); await db.prepare('UPDATE access_tokens SET expires=0 WHERE hash=?').bind(await hash(token.access_token)).run();
  assert.equal((await request('/v1/layout', { headers: auth(token) })).status, 401);
});
test('refresh rotates; D1 holds only hashes and revoked access fails immediately', async () => {
  const { token } = await enroll();
  const row = await db.prepare('SELECT * FROM devices WHERE id=?').bind(token.device_id).first();
  assert.equal(row.refresh_hash, await hash(token.refresh_token)); assert.notEqual(row.refresh_hash, token.refresh_token);
  const refresh = { grant_type: 'refresh_token', refresh_token: token.refresh_token };
  const r = await request('/oauth/token', post(refresh)); assert.equal(r.status, 200); const rotated = await r.json();
  assert.notEqual(rotated.refresh_token, token.refresh_token); assert.equal((await request('/oauth/token', post(refresh))).status, 200);
  assert.equal((await request('/v1/devices/' + token.device_id, { method: 'DELETE', headers: auth(rotated) })).status, 200);
  assert.equal((await request('/v1/layout', { headers: auth(rotated) })).status, 401);
  assert.equal((await request('/v1/layout', { headers: auth(token) })).status, 401);
  assert.equal((await request('/oauth/token', post({ grant_type: 'refresh_token', refresh_token: rotated.refresh_token }))).status, 400);
});
test('device list contains no credential hashes; another account cannot revoke', async () => {
  const { token } = await enroll();
  const r = await request('/v1/devices', { headers: auth(token) }); const data = await r.json();
  assert.equal(data.device_id, token.device_id); assert.ok(data.devices.some(d => d.id === token.device_id));
  assert.equal(JSON.stringify(data).includes('hash'), false);
  await db.prepare('INSERT INTO devices VALUES (?,?,?,?,?,?,?)').bind('foreign', 'foreign', 'foreign', 'foreign-hash', 0, 0, 0).run();
  assert.equal((await request('/v1/devices/foreign', { method: 'DELETE', headers: auth(token) })).status, 404);
});
test('GET requires device; two simultaneous PUTs admit one writer and return conflict snapshot', async () => {
  assert.equal((await request('/v1/layout')).status, 401);
  const { token } = await enroll(); const initial = await (await request('/v1/layout', { headers: auth(token) })).json();
  const put = name => request('/v1/layout', { method: 'PUT', headers: auth(token), body: JSON.stringify({ base_revision: initial.revision, layout: { ...layout, tabs: [{ ...layout.tabs[0], name }] } }) });
  const responses = await Promise.all([put('A'), put('B')]); assert.deepEqual(responses.map(r => r.status).sort(), [200, 409]);
  for (const r of responses) { const b = await r.json(); assert.equal(b.revision, initial.revision + 1); assert.equal(b.layout.revision, b.revision); }
});
test('portable layout allowlist excludes runtime/secrets and duplicate targets', () => {
  for (const bad of [{ ...layout, pid: 1 }, { ...layout, schema: 2 }, { ...layout, tabs: [layout.tabs[0], layout.tabs[0]] }, { ...layout, tabs: [{ ...layout.tabs[0], tmux_session: 'x;kill' }] }, { ...layout, tabs: [{ ...layout.tabs[0], workspace: 'Missing' }] }]) assert.throws(() => validateLayout(bad));
  assert.equal(validateLayout(layout), layout);
});

test('lost refresh reply and concurrent retries remain usable within bounded grace', async () => {
  const { token } = await enroll();
  const grant = { grant_type: 'refresh_token', refresh_token: token.refresh_token };
  assert.equal((await request('/oauth/token', post(grant))).status, 200);
  const responses = await Promise.all([request('/oauth/token', post(grant)), request('/oauth/token', post(grant))]);
  assert.deepEqual(responses.map(r => r.status), [200, 200]);
  const grace = await db.prepare('SELECT * FROM refresh_grace WHERE hash=?').bind(await hash(token.refresh_token)).first();
  assert.equal(grace.device, token.device_id);
  assert.ok(grace.expires <= Math.floor(Date.now() / 1000) + 600);
  for (const response of responses) {
    const reply = await response.json();
    assert.equal((await request('/v1/layout', { headers: auth(reply) })).status, 200);
    assert.equal((await request('/oauth/token', post({ ...grant, refresh_token: reply.refresh_token }))).status, 200);
  }
  assert.equal((await db.prepare('SELECT expires FROM refresh_grace WHERE hash=?').bind(await hash(token.refresh_token)).first()).expires, grace.expires);
  await db.prepare('UPDATE refresh_grace SET expires=unixepoch() WHERE hash=?').bind(await hash(token.refresh_token)).run();
  const expired = await request('/oauth/token', post(grant));
  assert.equal(expired.status, 400); assert.equal((await expired.json()).error, 'invalid_grant');
  await db.prepare('UPDATE devices SET revoked=1 WHERE id=?').bind(token.device_id).run();
  const revoked = await request('/oauth/token', post(grant)); assert.equal(revoked.status, 400);
});
test('manual naming is optional for legacy rows, typed on new rows, and case variants cannot duplicate identities', () => {
  for (const manual of [false, true]) assert.equal(validateLayout({ ...layout, tabs: [{ ...layout.tabs[0], manual }] }).tabs[0].manual, manual);
  assert.throws(() => validateLayout({ ...layout, tabs: [{ ...layout.tabs[0], manual: 'true' }] }));
  assert.throws(() => validateLayout({ ...layout, tabs: [layout.tabs[0], { ...layout.tabs[0], tmux_session: 'ONE' }] }));
});

test('non-string and null synced identities fail as invalid layout, not service errors', async () => {
  const { token } = await enroll();
  for (const tab of [null, { ...layout.tabs[0], tmux_session: 123 }]) {
    const response = await request('/v1/layout', { method: 'PUT', headers: auth(token), body: JSON.stringify({ base_revision: 0, layout: { ...layout, tabs: [tab] } }) });
    assert.equal(response.status, 400);
  }
});

test('Android callbacks preserve state and require matching PKCE and exact redirect; desktop is unchanged', async () => {
  for (const redirect of ['dev.multiprompt.companion://auth/callback', 'dev.multiprompt.companion.debug://auth/callback', 'http://127.0.0.1:65535/callback']) {
    const r = await login(jwt, redirect); assert.equal(r.status, 302);
    const callback = new URL(r.headers.get('Location'));
    assert.equal(callback.searchParams.get('state'), state);
    assert.deepEqual([...callback.searchParams.keys()].sort(), ['code', 'state']);
    const grant = { grant_type: 'authorization_code', code: callback.searchParams.get('code'), code_verifier: verifier, redirect_uri: redirect };
    assert.equal((await request('/oauth/token', post({ ...grant, code_verifier: 'z'.repeat(64) }))).status, 400);
    assert.equal((await request('/oauth/token', post({ ...grant, redirect_uri: 'http://127.0.0.1:1/callback' }))).status, 400);
    const exchange = await request('/oauth/token', post(grant)); assert.equal(exchange.status, 200);
    const token = await exchange.json(); assert.equal((await request('/v1/layout', { headers: auth(token) })).status, 200);
    assert.equal((await request('/oauth/token', post(grant))).status, 400);
  }
  for (const uri of ['dev.multiprompt.companion://auth/callback/evil', 'dev.multiprompt.companion://auth/callback?evil=1', 'dev.multiprompt.companion://auth/callback#evil', 'dev.multiprompt.companion://evil/callback', 'dev.multiprompt.companion://user@auth/callback', 'https://account.multiprompt.dev/callback', 'http://127.0.0.1:0/callback']) assert.equal((await login(jwt, uri)).status, 400);
  const params = { redirect_uri: 'dev.multiprompt.companion://auth/callback', state, code_challenge: await hash(verifier), code_challenge_method: 'S256' };
  for (const bad of [{ state: 'wrong' }, { code_challenge_method: 'plain' }, { code_challenge: '' }]) assert.equal((await request('/login?' + new URLSearchParams({ ...params, ...bad }), { headers: { 'Cf-Access-Jwt-Assertion': jwt } })).status, 400);
});
