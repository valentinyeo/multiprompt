import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Miniflare, convertV4MiniflareOptions } from 'miniflare';
import { generateKeyPairSync, randomBytes } from 'node:crypto';
import worker, { hash, validateLayout, validateRecords, safeNext, validateUsage } from '../worker.js';

let mf, db;
const mail = [], usageToken = 'u'.repeat(43);
const base = 'http://localhost';
const encode = obj => Buffer.from(JSON.stringify(obj)).toString('base64url');
const layout = { schema: 1, revision: 1, workspaces: [{ name: 'Other' }], tabs: [{ kind: 'tmux', name: 'One', tmux_session: 'one', tmux_host: 0, workspace: 'Other' }] };
const request = (path, options) => mf.dispatchFetch(base + path, options);
const post = b => ({ method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(b) });
const verifier = 'x'.repeat(64), state = 's'.repeat(43);
async function login(redirect = 'http://127.0.0.1:43210/callback') {
  const cookie = await emailSignIn();
  const url = '/login?' + new URLSearchParams({ redirect_uri: redirect, state, code_challenge: await hash(verifier), code_challenge_method: 'S256', device_name: 'Test device' });
  return request(url, { method: 'POST', headers: { Cookie: cookie, ...origin }, redirect: 'manual' });
}
async function enroll() {
  const r = await login(); assert.equal(r.status, 303);
  const target = new URL(r.headers.get('Location')); assert.equal(target.searchParams.get('state'), state);
  const grant = { grant_type: 'authorization_code', code: target.searchParams.get('code'), code_verifier: verifier, redirect_uri: 'http://127.0.0.1:43210/callback' };
  const response = await request('/oauth/token', post(grant)); assert.equal(response.status, 200);
  return { token: await response.json(), grant };
}
const auth = token => ({ Authorization: 'Bearer ' + token.access_token });
before(async () => {
  mf = new Miniflare(convertV4MiniflareOptions({ outboundService: async req => {
    if (req.url === 'https://api.resend.com/emails') { mail.push(await req.json()); return new Response('{"id":"test"}'); }
    assert.fail('Unexpected outbound request: ' + req.url);
  }, modules: true, scriptPath: new URL('../.build/worker.js', import.meta.url).pathname, compatibilityDate: '2026-10-09', compatibilityFlags: ['nodejs_compat'], d1Databases: ['DB'],
  bindings: { ACCOUNT_EMAIL: 'owner@example.com', ALLOWED_EMAILS: 'owner@example.com', AUTH_ORIGINS: base, RP_ID: 'localhost', BETTER_AUTH_SECRET: 'test-only-value-'.repeat(3), RESEND_API_KEY: 'test-only-key', USAGE_PUSH_TOKEN: usageToken } }));
  db = await mf.getD1Database('DB');
  for (const sql of readFileSync(new URL('../schema.sql', import.meta.url), 'utf8').split(';').filter(s => s.trim())) await db.prepare(sql).run();
  await db.prepare('INSERT INTO layouts VALUES (?,?,?)').bind('owner@example.com', 1, JSON.stringify(layout)).run();
});
after(async () => { await mf?.dispose(); });

test('legacy assertion headers are ignored and cannot sign in', async () => {
  const jwt = encode({ alg: 'RS256', kid: 'test-key' }) + '.' + encode({ email: 'owner@example.com', exp: Math.floor(Date.now() / 1000) + 600 }) + '.' + 's'.repeat(43);
  const query = await authorizeQuery();
  for (const token of ['forged', jwt]) {
    const response = await request('/login?' + query, { headers: { 'Cf-Access-Jwt-Assertion': token }, redirect: 'manual' });
    assert.equal(response.status, 302);
    assert.equal(response.headers.get('Location'), '/signin?next=' + encodeURIComponent('/login?' + query));
  }
});

test('only exact loopback callback is accepted; state and S256 are required', async () => {
  for (const uri of ['https://evil.example/callback', 'http://localhost:1234/callback', 'http://127.0.0.1:70000/callback', 'http://127.0.0.1:1234/evil', 'http://127.0.0.1:1234/callback?evil=1']) assert.equal((await login(uri)).status, 400);
  assert.equal((await request('/login?redirect_uri=http://127.0.0.1:1234/callback', { method: 'POST', headers: { Cookie: await emailSignIn(), ...origin }, redirect: 'manual' })).status, 400);
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

test('favorite and manual accept every optional boolean combination and reject other values', () => {
  for (const manual of [undefined, false, true]) for (const favorite of [undefined, false, true]) {
    const tab = { ...layout.tabs[0], ...(manual === undefined ? {} : { manual }), ...(favorite === undefined ? {} : { favorite }) };
    assert.equal(validateLayout({ ...layout, tabs: [tab] }).tabs[0], tab);
  }
  for (const favorite of [null, 0, 1, 'true', [], {}]) assert.throws(() => validateLayout({ ...layout, tabs: [{ ...layout.tabs[0], favorite }] }), { status: 400, message: 'invalid_tab' });
});

test('legacy layout GET strips favorites without changing stored stars; declaring GET returns them', async () => {
  const { token } = await enroll();
  const starred = { ...layout, tabs: [{ ...layout.tabs[0], favorite: true }] };
  await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify(starred)).run();
  for (const features of [undefined, 'manual', 'favorite-other', 'favorite', 'manual, favorite']) {
    const response = await request('/v1/layout', { headers: { ...auth(token), ...(features === undefined ? {} : { 'X-Layout-Features': features }) } });
    assert.equal(response.status, 200); assert.equal(response.headers.get('X-Layout-Features'), 'favorite,used,visits,input,settings,hosts');
    const reply = await response.json();
    assert.deepEqual(reply.layout.tabs[0], features === 'favorite' || features === 'manual, favorite' ? starred.tabs[0] : layout.tabs[0]);
  }
  assert.deepEqual(JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout), starred);
});

test('legacy layout PUT preserves stars by case-insensitive host/session identity only', async () => {
  const { token } = await enroll();
  await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify({ ...layout, tabs: [{ ...layout.tabs[0], favorite: true }] })).run();
  const tabs = [{ ...layout.tabs[0], tmux_session: 'ONE', name: 'Renamed', favorite: false }, { ...layout.tabs[0], tmux_host: 1, favorite: true }, { ...layout.tabs[0], tmux_session: 'new', favorite: true }];
  const response = await request('/v1/layout', { method: 'PUT', headers: auth(token), body: JSON.stringify({ base_revision: 1, layout: { ...layout, tabs } }) });
  assert.equal(response.status, 200); assert.equal(response.headers.get('X-Layout-Features'), 'favorite,used,visits,input,settings,hosts');
  const reply = await response.json();
  assert.ok(reply.layout.tabs.every(tab => !Object.hasOwn(tab, 'favorite')));
  const stored = JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout);
  assert.deepEqual(stored.tabs[0], { ...tabs[0], favorite: true });
  assert.ok(stored.tabs.slice(1).every(tab => !Object.hasOwn(tab, 'favorite')));
  const again = await request('/v1/layout', { method: 'PUT', headers: auth(token), body: JSON.stringify({ base_revision: reply.revision, layout: reply.layout }) });
  assert.equal(again.status, 200);
  assert.equal(JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout).tabs[0].favorite, true);
});

test('declaring layout PUT stores and returns stars alongside manual naming', async () => {
  const { token } = await enroll();
  await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify(layout)).run();
  const tabs = [{ ...layout.tabs[0], manual: true, favorite: true }, { ...layout.tabs[0], tmux_session: 'two', manual: false, favorite: false }];
  const headers = { ...auth(token), 'X-Layout-Features': 'favorite' };
  const response = await request('/v1/layout', { method: 'PUT', headers, body: JSON.stringify({ base_revision: 1, layout: { ...layout, tabs } }) });
  assert.equal(response.status, 200); assert.equal(response.headers.get('X-Layout-Features'), 'favorite,used,visits,input,settings,hosts');
  const reply = await response.json();
  assert.deepEqual(reply.layout.tabs, tabs);
  const stored = await db.prepare('SELECT revision,layout FROM layouts').first();
  assert.equal(stored.revision, reply.revision); assert.deepEqual(JSON.parse(stored.layout), reply.layout);
  const get = await request('/v1/layout', { headers });
  assert.equal(get.headers.get('X-Layout-Features'), 'favorite,used,visits,input,settings,hosts'); assert.deepEqual(await get.json(), reply);
});

test('declaring layout PUT preserves absence and explicit false', async () => {
  const { token } = await enroll();
  for (const favorite of [undefined, false]) {
    await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify({ ...layout, tabs: [{ ...layout.tabs[0], favorite: true }] })).run();
    const tab = { ...layout.tabs[0], ...(favorite === undefined ? {} : { favorite }) };
    const response = await request('/v1/layout', { method: 'PUT', headers: { ...auth(token), 'X-Layout-Features': 'favorite' }, body: JSON.stringify({ base_revision: 1, layout: { ...layout, tabs: [tab] } }) });
    assert.equal(response.status, 200);
    assert.deepEqual((await response.json()).layout.tabs, [tab]);
    assert.deepEqual(JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout).tabs, [tab]);
  }
});

test('declaring unstar reaches other clients and survives a legacy PUT', async () => {
  const { token } = await enroll();
  await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify({ ...layout, tabs: [{ ...layout.tabs[0], favorite: true }] })).run();
  const headers = { ...auth(token), 'X-Layout-Features': 'favorite' };
  const tab = { ...layout.tabs[0], favorite: false };
  const put = await request('/v1/layout', { method: 'PUT', headers, body: JSON.stringify({ base_revision: 1, layout: { ...layout, tabs: [tab] } }) });
  assert.equal(put.status, 200); assert.deepEqual((await put.json()).layout.tabs, [tab]);
  assert.deepEqual(JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout).tabs, [tab]);
  const get = await request('/v1/layout', { headers });
  assert.equal(get.status, 200); assert.equal(get.headers.get('X-Layout-Features'), 'favorite,used,visits,input,settings,hosts');
  const saved = await get.json(); assert.deepEqual(saved.layout.tabs, [tab]);
  const legacy = await request('/v1/layout', { method: 'PUT', headers: auth(token), body: JSON.stringify({ base_revision: saved.revision, layout: { ...saved.layout, tabs: [{ ...tab, tmux_session: 'ONE', favorite: true }, { ...tab, tmux_host: 1 }, { ...tab, tmux_session: 'new' }] } }) });
  assert.equal(legacy.status, 200); assert.equal(legacy.headers.get('X-Layout-Features'), 'favorite,used,visits,input,settings,hosts');
  assert.ok((await legacy.json()).layout.tabs.every(tab => !Object.hasOwn(tab, 'favorite')));
  const stored = JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout);
  assert.deepEqual(stored.tabs[0], { ...tab, tmux_session: 'ONE' });
  assert.ok(stored.tabs.slice(1).every(tab => !Object.hasOwn(tab, 'favorite')));
  const again = await request('/v1/layout', { headers });
  assert.equal(again.status, 200); assert.deepEqual((await again.json()).layout, stored);
});

test('layout conflicts advertise features and hide winner stars only from legacy clients', async () => {
  const { token } = await enroll();
  const starred = { ...layout, tabs: [{ ...layout.tabs[0], favorite: true }] };
  await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify(starred)).run();
  for (const features of [undefined, 'favorite']) {
    const response = await request('/v1/layout', { method: 'PUT', headers: { ...auth(token), ...(features ? { 'X-Layout-Features': features } : {}) }, body: JSON.stringify({ base_revision: 0, layout }) });
    assert.equal(response.status, 409); assert.equal(response.headers.get('X-Layout-Features'), 'favorite,used,visits,input,settings,hosts');
    assert.deepEqual(await response.json(), { revision: 1, layout: features ? starred : layout });
  }
  assert.deepEqual(JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout), starred);
});

test('layout validation and authentication errors advertise features; non-boolean favorite is invalid_tab', async () => {
  const unauthorized = await request('/v1/layout');
  assert.equal(unauthorized.status, 401); assert.equal(unauthorized.headers.get('X-Layout-Features'), 'favorite,used,visits,input,settings,hosts');
  const { token } = await enroll();
  for (const favorite of [null, 0, 1, 'true', [], {}]) {
    const response = await request('/v1/layout', { method: 'PUT', headers: { ...auth(token), 'X-Layout-Features': 'favorite' }, body: JSON.stringify({ base_revision: 1, layout: { ...layout, tabs: [{ ...layout.tabs[0], favorite }] } }) });
    assert.equal(response.status, 400); assert.equal(response.headers.get('X-Layout-Features'), 'favorite,used,visits,input,settings,hosts');
    assert.deepEqual(await response.json(), { error: 'invalid_tab' });
  }
});

test('non-string and null synced identities fail as invalid layout, not service errors', async () => {
  const { token } = await enroll();
  for (const tab of [null, { ...layout.tabs[0], tmux_session: 123 }]) {
    const response = await request('/v1/layout', { method: 'PUT', headers: auth(token), body: JSON.stringify({ base_revision: 0, layout: { ...layout, tabs: [tab] } }) });
    assert.equal(response.status, 400);
  }
});

test('Android callbacks preserve state and require matching PKCE and exact redirect; desktop is unchanged', async () => {
  for (const redirect of ['dev.multiprompt.companion://auth/callback', 'dev.multiprompt.companion.debug://auth/callback', 'dev.multiprompt.companion.m3://auth/callback', 'http://127.0.0.1:65535/callback']) {
    const page = await request('/login?' + await authorizeQuery(redirect), { headers: { Cookie: await emailSignIn() }, redirect: 'manual' });
    assert.equal(page.status, 200);
    if (redirect.startsWith('dev.multiprompt.companion.m3:')) assert.ok(page.headers.get('Content-Security-Policy').split(';').find(directive => directive.trim().startsWith('form-action ')).trim().split(/\s+/).includes('dev.multiprompt.companion.m3:'));
    const r = await login(redirect); assert.equal(r.status, 303);
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
  for (const uri of ['dev.multiprompt.companion.m3x://auth/callback', 'dev.multiprompt.companion.m3://auth/callbackx', 'dev.multiprompt.companion://auth/callback/evil', 'dev.multiprompt.companion://auth/callback?evil=1', 'dev.multiprompt.companion://auth/callback#evil', 'dev.multiprompt.companion://evil/callback', 'dev.multiprompt.companion://user@auth/callback', 'https://account.example.com/callback', 'http://127.0.0.1:0/callback']) assert.equal((await login(uri)).status, 400);
  const params = { redirect_uri: 'dev.multiprompt.companion://auth/callback', state, code_challenge: await hash(verifier), code_challenge_method: 'S256' };
  for (const bad of [{ state: 'wrong' }, { code_challenge_method: 'plain' }, { code_challenge: '' }]) assert.equal((await request('/login?' + new URLSearchParams({ ...params, ...bad }), { method: 'POST', headers: { Cookie: await emailSignIn(), ...origin }, redirect: 'manual' })).status, 400);
});

const origin = { Origin: base };
const cookieOf = r => r.headers.getSetCookie().map(c => c.split(';')[0]).filter(c => !/=$/.test(c)).join('; ');
const json = (b, headers = {}) => ({ method: 'POST', headers: { 'Content-Type': 'application/json', ...origin, ...headers }, body: JSON.stringify(b) });
async function emailSignIn(email = 'owner@example.com', cookie = '') {
  mail.length = 0;
  assert.equal((await request('/api/auth/email-otp/send-verification-otp', json({ email, type: 'sign-in' }, { Cookie: cookie }))).status, 200);
  assert.equal(mail.length, 1); assert.deepEqual(mail[0].to, [email]);
  const otp = mail[0].subject.match(/^(\d{6}) /)[1];
  assert.ok((await request('/api/auth/sign-in/email-otp', json({ email, otp: otp === '000000' ? '111111' : '000000' }))).status >= 400);
  const r = await request('/api/auth/sign-in/email-otp', json({ email, otp }, { Cookie: cookie }));
  assert.equal(r.status, 200); const signedIn = cookieOf(r); assert.match(signedIn, /session_token=/);
  return signedIn;
}
const authorizeQuery = async (redirect = 'http://127.0.0.1:43210/callback') => new URLSearchParams({ redirect_uri: redirect, state, code_challenge: await hash(verifier), code_challenge_method: 'S256', device_name: 'Better Auth device' });

test('better auth: unauthenticated /login goes to the sign-in page; dashboard root shows sign-in', async () => {
  const q = await authorizeQuery();
  for (const path of ['/login?', '/authorize?']) {
    const r = await request(path + q, { redirect: 'manual' }); assert.equal(r.status, 302);
    assert.equal(r.headers.get('Location'), '/signin?next=' + encodeURIComponent(path + q));
  }
  const page = await request('/'); assert.equal(page.status, 200);
  const text = await page.text(); assert.match(text, /data-page="signin"/); assert.match(text, /passkey/i); assert.doesNotMatch(text, /id="no-mail"/);
  assert.equal((await request('/authorize?redirect_uri=https://evil.example/cb', { redirect: 'manual' })).status, 400);
});

test('better auth: email code is sent only to allowlisted addresses and is never stored in plain text', async () => {
  mail.length = 0;
  assert.equal((await request('/api/auth/email-otp/send-verification-otp', json({ email: 'intruder@example.com', type: 'sign-in' }))).status, 200);
  assert.equal(mail.length, 0);
  mail.length = 0;
  assert.equal((await request('/api/auth/email-otp/send-verification-otp', json({ email: 'owner@example.com', type: 'sign-in' }))).status, 200);
  const otp = mail[0].subject.slice(0, 6); assert.match(otp, /^\d{6}$/);
  const rows = (await db.prepare('SELECT value FROM verification').all()).results;
  assert.ok(rows.length > 0);
  for (const row of rows) assert.equal(row.value.includes(otp), false);
  await emailSignIn();
});

test('better auth: signed-in browser approves a device and the unchanged PKCE grant issues device tokens', async () => {
  const cookie = await emailSignIn(); const q = await authorizeQuery();
  const confirm = await request('/authorize?' + q, { headers: { Cookie: cookie } });
  assert.equal(confirm.status, 200); assert.match(await confirm.text(), /Better Auth device/);
  assert.equal((await request('/authorize?' + q, { method: 'POST', headers: { Cookie: cookie }, redirect: 'manual' })).status, 403);
  assert.equal((await request('/authorize?' + q, { method: 'POST', headers: { Cookie: cookie, Origin: 'https://evil.example' }, redirect: 'manual' })).status, 403);
  assert.equal((await request('/authorize?' + q, { method: 'POST', headers: origin, redirect: 'manual' })).status, 401);
  for (const path of ['/authorize?', '/login?']) {
    const r = await request(path + q, { method: 'POST', headers: { Cookie: cookie, ...origin }, redirect: 'manual' });
    assert.equal(r.status, 303); const callback = new URL(r.headers.get('Location'));
    assert.equal(callback.origin + callback.pathname, 'http://127.0.0.1:43210/callback'); assert.equal(callback.searchParams.get('state'), state);
    const grant = { grant_type: 'authorization_code', code: callback.searchParams.get('code'), code_verifier: verifier, redirect_uri: 'http://127.0.0.1:43210/callback' };
    const exchange = await request('/oauth/token', post(grant)); assert.equal(exchange.status, 200);
    const token = await exchange.json(); assert.equal(token.account_id, 'owner@example.com'); assert.equal(token.expires_in, 600);
    assert.equal((await request('/v1/layout', { headers: auth(token) })).status, 200);
    assert.equal((await request('/oauth/token', post({ grant_type: 'refresh_token', refresh_token: token.refresh_token }))).status, 200);
  }
  const signedIn = await request('/signin?next=' + encodeURIComponent('/authorize?' + q), { headers: { Cookie: cookie }, redirect: 'manual' });
  assert.equal(signedIn.status, 302); assert.equal(signedIn.headers.get('Location'), '/authorize?' + q);
});

test('better auth: dashboard session reads devices/layout, revokes only with same-origin header, never writes layout', async () => {
  const cookie = await emailSignIn(); const { token } = await enroll();
  const page = await (await request('/', { headers: { Cookie: cookie } })).text(); assert.match(page, /data-page="dash"/);
  const me = await (await request('/v1/me', { headers: { Cookie: cookie } })).json(); assert.deepEqual(me, { account: 'owner@example.com', device_id: null });
  const list = await (await request('/v1/devices', { headers: { Cookie: cookie } })).json(); assert.ok(list.devices.some(d => d.id === token.device_id));
  assert.equal((await request('/v1/layout', { headers: { Cookie: cookie } })).status, 200);
  assert.equal((await request('/v1/devices/' + token.device_id, { method: 'DELETE', headers: { Cookie: cookie, ...origin } })).status, 403);
  assert.equal((await request('/v1/devices/' + token.device_id, { method: 'DELETE', headers: { Cookie: cookie, Origin: 'https://evil.example', 'X-Multiprompt': 'dash' } })).status, 403);
  assert.equal((await request('/v1/layout', { method: 'PUT', headers: { Cookie: cookie, ...origin, 'X-Multiprompt': 'dash' }, body: '{}' })).status, 403);
  assert.equal((await request('/v1/devices/' + token.device_id, { method: 'DELETE', headers: { Cookie: cookie, ...origin, 'X-Multiprompt': 'dash' } })).status, 200);
  assert.equal((await request('/v1/layout', { headers: auth(token) })).status, 401);
  assert.equal((await request('/v1/devices', { headers: { Cookie: 'better-auth.session_token=forged.value' } })).status, 401);
});

test('better auth: a fresh session can start passkey registration; passkey sign-in options are public', async () => {
  const cookie = await emailSignIn();
  const reg = await request('/api/auth/passkey/generate-register-options', { headers: { Cookie: cookie, ...origin } });
  assert.equal(reg.status, 200); const options = await reg.json();
  assert.equal(options.rp.id, 'localhost'); assert.equal(typeof options.challenge, 'string');
  assert.ok((await request('/api/auth/passkey/generate-register-options', { headers: origin })).status >= 400);
  const signin = await request('/api/auth/passkey/generate-authenticate-options', { headers: origin });
  assert.equal(signin.status, 200); assert.equal(typeof (await signin.json()).challenge, 'string');
});

test('better auth: fresh sign-in displays the form with an existing session and renews stale passkey eligibility', async () => {
  const cookie = await emailSignIn();
  await db.prepare('UPDATE session SET createdAt=?').bind(new Date(Date.now() - 16 * 60 * 1000).toISOString()).run();
  const stale = await request('/api/auth/passkey/generate-register-options', { headers: { Cookie: cookie, ...origin } });
  assert.equal(stale.status, 403); assert.match((await stale.json()).message, /fresh/i);
  const next = '/?passkey=add';
  const fresh = await request('/signin?fresh=1&next=' + encodeURIComponent(next), { headers: { Cookie: cookie }, redirect: 'manual' });
  assert.equal(fresh.status, 200); const page = await fresh.text();
  assert.match(page, /data-page="signin"/); assert.ok(page.includes('const next = ' + JSON.stringify(next)));
  const normal = await request('/signin?next=' + encodeURIComponent(next), { headers: { Cookie: cookie }, redirect: 'manual' });
  assert.equal(normal.status, 302); assert.equal(normal.headers.get('Location'), next);
  const renewed = await emailSignIn('owner@example.com', cookie);
  assert.notEqual(renewed, cookie);
  const registration = await request('/api/auth/passkey/generate-register-options', { headers: { Cookie: renewed, ...origin } });
  assert.equal(registration.status, 200); assert.equal(typeof (await registration.json()).challenge, 'string');
  const dash = await (await request(next, { headers: { Cookie: renewed } })).text();
  assert.match(dash, /data-page="dash"/);
  const reauth = dash.match(/const REAUTH = [^\n]+/)[0];
  assert.equal(new Function(reauth + '; return REAUTH;')(), '/signin?fresh=1&next=' + encodeURIComponent(next));
});

test('removed bridge routes return normal 404 responses with or without a session', async () => {
  for (const cookie of ['', await emailSignIn()]) {
    for (const path of ['/login/bridge', '/api/auth/access-bridge']) {
      const response = await request(path, { headers: { Cookie: cookie }, redirect: 'manual' });
      assert.equal(response.status, 404);
      assert.doesNotMatch(cookieOf(response), /session_token=/);
    }
  }
});

test('usage: PUT needs the service token and a valid body; GET serves the signed-in owner and devices only', async () => {
  const status = { ts: '2026-10-10T08:00:00Z', mode: 'claude', override: null, why: 'test', advice: 'burn claude', dashboard: 'x',
    accounts: [{ id: 'claude-1', label: 'Claude Max', provider: 'claude', email: 'a@b.c', host: 'vps', in_ladder: true, stale: false, error: null, note: '', week: { used: 42, resets_at: '2026-10-12T00:00:00Z', hours_left: 40, time_gone: 0.7 }, five_hour: { used: 10 } }] };
  const put = (token, b = status) => request('/v1/usage', { method: 'PUT', headers: token ? { Authorization: 'Bearer ' + token } : {}, body: JSON.stringify(b) });
  assert.equal((await put(null)).status, 401); assert.equal((await put('w'.repeat(43))).status, 401);
  assert.equal((await put(usageToken, { ...status, accounts: 'nope' })).status, 400);
  assert.equal((await put(usageToken)).status, 200);
  assert.equal((await request('/v1/usage')).status, 401);
  const cookie = await emailSignIn(); const viaSession = await (await request('/v1/usage', { headers: { Cookie: cookie } })).json();
  assert.deepEqual(viaSession.status, status); assert.ok(viaSession.updated > 0);
  const { token } = await enroll(); assert.deepEqual((await (await request('/v1/usage', { headers: auth(token) })).json()).status, status);
  assert.throws(() => validateUsage({ ts: 1, accounts: [{ id: 5 }] })); assert.equal(validateUsage(status), status);
});

test('sign-in return target allows only device authorization and passkey enrolment', () => {
  for (const ok of ['/login?state=x', '/authorize?a=b', '/?passkey=add']) assert.equal(safeNext(ok), ok);
  for (const bad of ['https://evil.example', 'https://evil.example/', '//evil.example', '//evil.example/login?x', '/?passkey=add&next=https://evil.example/', '/?passkey=other', '/login', '/v1/layout', '/authorize?x#y', '/login?x\\y', null]) assert.equal(safeNext(bad), null);
});

test('better auth: magic link signs in once, is sent only to allowlisted addresses, and the sign-in page lists configured methods', async () => {
  mail.length = 0;
  assert.equal((await request('/api/auth/sign-in/magic-link', json({ email: 'intruder@example.com', callbackURL: '/' }))).status, 200);
  assert.equal(mail.length, 0);
  assert.equal((await request('/api/auth/sign-in/magic-link', json({ email: 'owner@example.com', callbackURL: '/' }))).status, 200);
  assert.equal(mail.length, 1); assert.deepEqual(mail[0].to, ['owner@example.com']);
  const link = new URL(mail[0].text.match(/https?:\/\/\S+/)[0]); const path = link.pathname + link.search;
  const used = await request(path, { redirect: 'manual' }); assert.equal(used.status, 302);
  const jar = cookieOf(used); assert.match(jar, /session_token=/);
  const page = await (await request('/', { headers: { Cookie: jar } })).text();
  assert.match(page, /Signed in as <b>owner@example\.com<\/b>/); assert.doesNotMatch(page, />false</);
  const again = await request(path, { redirect: 'manual' }); assert.doesNotMatch(cookieOf(again), /session_token=/);
  const signin = await (await request('/signin')).text();
  assert.match(signin, /data-methods="passkey,email"/); assert.match(signin, /id="send-link"/); assert.doesNotMatch(signin, /id="google"/);
});

test('dashboard helpers: usage is a 0-100 percentage and reset times are Unix seconds shown as relative time', async () => {
  const jar = await emailSignIn();
  const script = (await (await request('/', { headers: { Cookie: jar } })).text()).match(/const pct = [^\n]*\nconst when = [\s\S]*?toLocaleTimeString[^\n]*\n/)[0];
  const { pct, when } = new Function(script + '; return { pct, when };')();
  assert.equal(pct(1.0), 1); assert.equal(pct(77), 77); assert.equal(pct(null), null);
  const now = Date.now() / 1000;
  assert.equal(when(now + 6 * 3600 + 60), 'resets in 6 h'); assert.equal(when(now + 40 * 60), 'resets in 40 min');
  assert.match(when(now + 4 * 86400), /^resets [A-Z][a-z]{2} \d\d:\d\d$/); assert.equal(when(now - 5), 'just reset');
  assert.doesNotMatch(when(1791738000.345), /1970/);
});

test('pages let their own Allow form send its Origin; a null Origin is still refused', async () => {
  const page = await request('/login?' + await authorizeQuery(), { headers: { Cookie: await emailSignIn() }, redirect: 'manual' });
  assert.equal(page.status, 200);
  assert.equal(page.headers.get('Referrer-Policy'), 'same-origin');
  const blank = await request('/login?' + await authorizeQuery(), { method: 'POST', headers: { Cookie: await emailSignIn(), Origin: 'null' }, redirect: 'manual' });
  assert.equal(blank.status, 403);
});

test('used accepts only optional non-negative safe integers independently of favorite', () => {
  for (const used of [undefined, 0, 1, Number.MAX_SAFE_INTEGER]) for (const favorite of [undefined, false, true]) {
    const tab = { ...layout.tabs[0], ...(used === undefined ? {} : { used }), ...(favorite === undefined ? {} : { favorite }) };
    assert.equal(validateLayout({ ...layout, tabs: [tab] }).tabs[0], tab);
  }
  for (const used of [null, -1, 1.5, Number.MAX_SAFE_INTEGER + 1, Infinity, NaN, '1', true, [], {}]) {
    assert.throws(() => validateLayout({ ...layout, tabs: [{ ...layout.tabs[0], used }] }), { status: 400, message: 'invalid_tab' });
  }
});

test('used response negotiation is independent, token-exact, trimmed and covers GET and conflict winners', async () => {
  const { token } = await enroll();
  const tab = { ...layout.tabs[0], used: 1234, favorite: false };
  await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify({ ...layout, tabs: [tab] })).run();
  for (const features of ['', 'used-other', 'favorite', 'used', ' favorite , used ']) {
    const headers = { ...auth(token), 'X-Layout-Features': features };
    const expected = { ...layout.tabs[0], ...(features.includes('favorite') ? { favorite: false } : {}), ...(['used', ' favorite , used '].includes(features) ? { used: 1234 } : {}) };
    for (const options of [{ headers }, { method: 'PUT', headers, body: JSON.stringify({ base_revision: 0, layout }) }]) {
      const response = await request('/v1/layout', options);
      assert.equal(response.status, options.method ? 409 : 200);
      assert.equal(response.headers.get('X-Layout-Features'), 'favorite,used,visits,input,settings,hosts');
      assert.deepEqual((await response.json()).layout.tabs, [expected]);
    }
  }
  assert.deepEqual(JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout).tabs, [tab]);
});

test('used old-app saves preserve stored zero and positive stamps by host and case-insensitive session only', async () => {
  const { token } = await enroll();
  for (const used of [0, 1234]) for (const features of ['', 'favorite', 'used-other']) {
    const tab = { ...layout.tabs[0], used, favorite: true };
    await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify({ ...layout, tabs: [tab] })).run();
    const tabs = [{ ...tab, tmux_session: 'ONE', used: 9999, favorite: false }, { ...tab, tmux_host: 1 }, { ...tab, tmux_session: 'new' }];
    const response = await request('/v1/layout', { method: 'PUT', headers: { ...auth(token), 'X-Layout-Features': features }, body: JSON.stringify({ base_revision: 1, layout: { ...layout, tabs } }) });
    assert.equal(response.status, 200);
    assert.ok((await response.json()).layout.tabs.every(t => !Object.hasOwn(t, 'used')));
    const stored = JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout);
    assert.equal(stored.tabs[0].used, used);
    assert.equal(stored.tabs[0].favorite, features === 'favorite' ? false : true);
    assert.ok(stored.tabs.slice(1).every(t => !Object.hasOwn(t, 'used')));
    const hidden = await request('/v1/layout', { headers: auth(token) });
    const legacy = await hidden.json();
    const again = await request('/v1/layout', { method: 'PUT', headers: auth(token), body: JSON.stringify({ base_revision: legacy.revision, layout: legacy.layout }) });
    assert.equal(again.status, 200);
    assert.equal(JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout).tabs[0].used, used);
  }
});

test('used declaring saves merge max, keep absent stored values and leave unknown absent', async () => {
  const { token } = await enroll();
  for (const storedUsed of [undefined, 0, 2000]) for (const incoming of [undefined, 0, 1000, 3000, Number.MAX_SAFE_INTEGER]) {
    const previous = { ...layout.tabs[0], favorite: true, ...(storedUsed === undefined ? {} : { used: storedUsed }) };
    await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify({ ...layout, tabs: [previous] })).run();
    const tab = { ...layout.tabs[0], tmux_session: 'ONE', ...(incoming === undefined ? {} : { used: incoming }) };
    const response = await request('/v1/layout', { method: 'PUT', headers: { ...auth(token), 'X-Layout-Features': ' used ' }, body: JSON.stringify({ base_revision: 1, layout: { ...layout, tabs: [tab] } }) });
    assert.equal(response.status, 200);
    const reply = await response.json();
    const expected = storedUsed === undefined ? incoming : Math.max(storedUsed, incoming ?? storedUsed);
    assert.equal(reply.layout.tabs[0].used, expected);
    assert.equal(Object.hasOwn(reply.layout.tabs[0], 'used'), expected !== undefined);
    assert.ok(!Object.hasOwn(reply.layout.tabs[0], 'favorite'));
    const stored = JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout);
    assert.equal(stored.tabs[0].used, expected);
    assert.equal(stored.tabs[0].favorite, true);
  }
});

test('used invalid PUTs reject before saving and advertise layout features', async () => {
  const { token } = await enroll();
  for (const used of [null, -1, 0.5, Number.MAX_SAFE_INTEGER + 1, '123', false, [], {}]) {
    const response = await request('/v1/layout', { method: 'PUT', headers: { ...auth(token), 'X-Layout-Features': 'favorite,used' }, body: JSON.stringify({ base_revision: 1, layout: { ...layout, tabs: [{ ...layout.tabs[0], used }] } }) });
    assert.equal(response.status, 400);
    assert.equal(response.headers.get('X-Layout-Features'), 'favorite,used,visits,input,settings,hosts');
    assert.deepEqual(await response.json(), { error: 'invalid_tab' });
  }
});

test('visits hidden without exact feature on GET and 409 winners; headers advertise all features', async () => {
  const { token } = await enroll();
  const tab = { ...layout.tabs[0], favorite: false, used: 1234, visits: [0, 1000] };
  await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify({ ...layout, tabs: [tab] })).run();
  for (const features of ['', 'visits-other', 'favorite,used', 'visits', ' favorite , used , visits ']) {
    const declared = features.split(',').map(s => s.trim());
    const expected = { ...layout.tabs[0] };
    for (const key of ['favorite', 'used', 'visits']) if (declared.includes(key)) expected[key] = tab[key];
    const headers = { ...auth(token), 'X-Layout-Features': features };
    for (const options of [{ headers }, { method: 'PUT', headers, body: JSON.stringify({ base_revision: 0, layout }) }]) {
      const response = await request('/v1/layout', options);
      assert.equal(response.status, options.method ? 409 : 200);
      assert.equal(response.headers.get('X-Layout-Features'), 'favorite,used,visits,input,settings,hosts');
      assert.deepEqual((await response.json()).layout.tabs, [expected]);
    }
  }
  assert.deepEqual(JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout).tabs, [tab]);
});

test('visits kept on old-app save only by host and case-insensitive session identity', async () => {
  const { token } = await enroll();
  for (const features of ['', 'favorite,used', 'visits-other']) for (const visits of [[], [0, 1000]]) {
    const tab = { ...layout.tabs[0], visits };
    await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify({ ...layout, tabs: [tab] })).run();
    const tabs = [{ ...tab, tmux_session: 'ONE', visits: [9999] }, { ...tab, tmux_host: 1, visits: [9999] }, { ...tab, tmux_session: 'new', visits: [9999] }];
    const response = await request('/v1/layout', { method: 'PUT', headers: { ...auth(token), 'X-Layout-Features': features }, body: JSON.stringify({ base_revision: 1, layout: { ...layout, tabs } }) });
    assert.equal(response.status, 200);
    assert.ok((await response.json()).layout.tabs.every(t => !Object.hasOwn(t, 'visits')));
    const stored = JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout);
    assert.deepEqual(stored.tabs[0].visits, visits);
    assert.ok(stored.tabs.slice(1).every(t => !Object.hasOwn(t, 'visits')));
  }
});

test('visits declaring PUT unions dedupes keeps omissions and leaves unknown absent', async () => {
  const { token } = await enroll();
  for (const storedVisits of [undefined, [], [0, 2, 4]]) for (const incoming of [undefined, [], [0, 1, 4], [Number.MAX_SAFE_INTEGER]]) {
    const previous = { ...layout.tabs[0], ...(storedVisits === undefined ? {} : { visits: storedVisits }) };
    await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify({ ...layout, tabs: [previous] })).run();
    const tab = { ...layout.tabs[0], tmux_session: 'ONE', ...(incoming === undefined ? {} : { visits: incoming }) };
    const response = await request('/v1/layout', { method: 'PUT', headers: { ...auth(token), 'X-Layout-Features': ' visits ' }, body: JSON.stringify({ base_revision: 1, layout: { ...layout, tabs: [tab] } }) });
    assert.equal(response.status, 200);
    const expected = storedVisits === undefined && incoming === undefined ? undefined : [...new Set([...(storedVisits ?? []), ...(incoming ?? [])])].sort((a, b) => a - b);
    assert.deepEqual((await response.json()).layout.tabs[0].visits, expected);
    assert.deepEqual(JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout).tabs[0].visits, expected);
  }
});

test('visits cap retains newest eight and a later omission never drops them', async () => {
  const { token } = await enroll();
  await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify({ ...layout, tabs: [{ ...layout.tabs[0], visits: [0, 2, 4, 6, 8, 10, 12, 14] }] })).run();
  const send = (revision, tab) => request('/v1/layout', { method: 'PUT', headers: { ...auth(token), 'X-Layout-Features': 'favorite,used,visits,input' }, body: JSON.stringify({ base_revision: revision, layout: { ...layout, tabs: [tab] } }) });
  const response = await send(1, { ...layout.tabs[0], visits: [1, 3, 5, 7, 9, 11, 13, 15] });
  assert.equal(response.status, 200);
  const expected = [8, 9, 10, 11, 12, 13, 14, 15];
  assert.deepEqual((await response.json()).layout.tabs[0].visits, expected);
  const omitted = await send(2, layout.tabs[0]);
  assert.equal(omitted.status, 200);
  assert.deepEqual((await omitted.json()).layout.tabs[0].visits, expected);
});

test('visits bad values return 400 invalid_tab without changing stored layout', async () => {
  const { token } = await enroll();
  const before = await db.prepare('SELECT revision,layout FROM layouts').first();
  for (const visits of [null, 1, '1', true, {}, [-1], [1.5], [Number.MAX_SAFE_INTEGER + 1], ['1'], [null], [true], [2, 1], [1, 1], Array.from({ length: 9 }, (_, i) => i)]) {
    assert.throws(() => validateLayout({ ...layout, tabs: [{ ...layout.tabs[0], visits }] }), { status: 400, message: 'invalid_tab' });
    const response = await request('/v1/layout', { method: 'PUT', headers: { ...auth(token), 'X-Layout-Features': 'favorite,used,visits,input' }, body: JSON.stringify({ base_revision: before.revision, layout: { ...layout, tabs: [{ ...layout.tabs[0], visits }] } }) });
    assert.equal(response.status, 400);
    assert.equal(response.headers.get('X-Layout-Features'), 'favorite,used,visits,input,settings,hosts');
    assert.deepEqual(await response.json(), { error: 'invalid_tab' });
  }
  assert.deepEqual(await db.prepare('SELECT revision,layout FROM layouts').first(), before);
});

test('visits shared desktop Android fixture survives a declaring layout round trip', async () => {
  const fixture = JSON.parse(readFileSync(new URL('../../tools/fixtures/issue-415-frequent.json', import.meta.url), 'utf8'));
  validateLayout(fixture.layout);
  const { token } = await enroll();
  await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify(layout)).run();
  const response = await request('/v1/layout', { method: 'PUT', headers: { ...auth(token), 'X-Layout-Features': 'favorite,used,visits,input' }, body: JSON.stringify({ base_revision: 1, layout: fixture.layout }) });
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).layout.tabs, fixture.layout.tabs);
});

test('input accepts only optional non-negative safe integers independently of favorite', () => {
  for (const input of [undefined, 0, 1, Number.MAX_SAFE_INTEGER]) for (const favorite of [undefined, false, true]) {
    const tab = { ...layout.tabs[0], ...(input === undefined ? {} : { input }), ...(favorite === undefined ? {} : { favorite }) };
    assert.equal(validateLayout({ ...layout, tabs: [tab] }).tabs[0], tab);
  }
  for (const input of [null, -1, 1.5, Number.MAX_SAFE_INTEGER + 1, Infinity, NaN, '1', true, [], {}]) {
    assert.throws(() => validateLayout({ ...layout, tabs: [{ ...layout.tabs[0], input }] }), { status: 400, message: 'invalid_tab' });
  }
});

test('input response negotiation is independent, token-exact, trimmed and covers GET and conflict winners', async () => {
  const { token } = await enroll();
  const tab = { ...layout.tabs[0], input: 1234, favorite: false };
  await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify({ ...layout, tabs: [tab] })).run();
  for (const features of ['', 'input-other', 'favorite', 'input', ' favorite , input ']) {
    const headers = { ...auth(token), 'X-Layout-Features': features };
    const expected = { ...layout.tabs[0], ...(features.includes('favorite') ? { favorite: false } : {}), ...(['input', ' favorite , input '].includes(features) ? { input: 1234 } : {}) };
    for (const options of [{ headers }, { method: 'PUT', headers, body: JSON.stringify({ base_revision: 0, layout }) }]) {
      const response = await request('/v1/layout', options);
      assert.equal(response.status, options.method ? 409 : 200);
      assert.equal(response.headers.get('X-Layout-Features'), 'favorite,used,visits,input,settings,hosts');
      assert.deepEqual((await response.json()).layout.tabs, [expected]);
    }
  }
  assert.deepEqual(JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout).tabs, [tab]);
});

test('input old-app saves preserve stored zero and positive stamps by host and case-insensitive session only', async () => {
  const { token } = await enroll();
  for (const input of [0, 1234]) for (const features of ['', 'favorite', 'input-other']) {
    const tab = { ...layout.tabs[0], input, favorite: true };
    await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify({ ...layout, tabs: [tab] })).run();
    const tabs = [{ ...tab, tmux_session: 'ONE', input: 9999, favorite: false }, { ...tab, tmux_host: 1 }, { ...tab, tmux_session: 'new' }];
    const response = await request('/v1/layout', { method: 'PUT', headers: { ...auth(token), 'X-Layout-Features': features }, body: JSON.stringify({ base_revision: 1, layout: { ...layout, tabs } }) });
    assert.equal(response.status, 200);
    assert.ok((await response.json()).layout.tabs.every(t => !Object.hasOwn(t, 'input')));
    const stored = JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout);
    assert.equal(stored.tabs[0].input, input);
    assert.equal(stored.tabs[0].favorite, features === 'favorite' ? false : true);
    assert.ok(stored.tabs.slice(1).every(t => !Object.hasOwn(t, 'input')));
    const hidden = await request('/v1/layout', { headers: auth(token) });
    const legacy = await hidden.json();
    const again = await request('/v1/layout', { method: 'PUT', headers: auth(token), body: JSON.stringify({ base_revision: legacy.revision, layout: legacy.layout }) });
    assert.equal(again.status, 200);
    assert.equal(JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout).tabs[0].input, input);
  }
});

test('input declaring saves merge max, keep absent stored values and leave unknown absent', async () => {
  const { token } = await enroll();
  for (const storedInput of [undefined, 0, 2000]) for (const incoming of [undefined, 0, 1000, 3000, Number.MAX_SAFE_INTEGER]) {
    const previous = { ...layout.tabs[0], favorite: true, ...(storedInput === undefined ? {} : { input: storedInput }) };
    await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify({ ...layout, tabs: [previous] })).run();
    const tab = { ...layout.tabs[0], tmux_session: 'ONE', ...(incoming === undefined ? {} : { input: incoming }) };
    const response = await request('/v1/layout', { method: 'PUT', headers: { ...auth(token), 'X-Layout-Features': ' input ' }, body: JSON.stringify({ base_revision: 1, layout: { ...layout, tabs: [tab] } }) });
    assert.equal(response.status, 200);
    const reply = await response.json();
    const expected = storedInput === undefined ? incoming : Math.max(storedInput, incoming ?? storedInput);
    assert.equal(reply.layout.tabs[0].input, expected);
    assert.equal(Object.hasOwn(reply.layout.tabs[0], 'input'), expected !== undefined);
    assert.ok(!Object.hasOwn(reply.layout.tabs[0], 'favorite'));
    const stored = JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout);
    assert.equal(stored.tabs[0].input, expected);
    assert.equal(stored.tabs[0].favorite, true);
  }
});

test('input invalid PUTs reject before saving and advertise layout features', async () => {
  const { token } = await enroll();
  for (const input of [null, -1, 0.5, Number.MAX_SAFE_INTEGER + 1, '123', false, [], {}]) {
    const response = await request('/v1/layout', { method: 'PUT', headers: { ...auth(token), 'X-Layout-Features': 'favorite,input' }, body: JSON.stringify({ base_revision: 1, layout: { ...layout, tabs: [{ ...layout.tabs[0], input }] } }) });
    assert.equal(response.status, 400);
    assert.equal(response.headers.get('X-Layout-Features'), 'favorite,used,visits,input,settings,hosts');
    assert.deepEqual(await response.json(), { error: 'invalid_tab' });
  }
});

test('settings accepts empty and optional boolean keys without materializing defaults', () => {
  for (const frequent of [undefined, false, true]) for (const favorites of [undefined, false, true]) for (const all of [undefined, false, true]) for (const frequent_first of [undefined, false, true]) {
    const settings = Object.fromEntries(Object.entries({ frequent, favorites, all, frequent_first }).filter(([, value]) => value !== undefined));
    const candidate = { ...layout, settings };
    assert.equal(validateLayout(candidate), candidate);
    assert.deepEqual(candidate.settings, settings);
  }
  assert.ok(!Object.hasOwn(validateLayout(layout), 'settings'));
  for (const settings of [null, false, 0, 'true', [], { unknown: true }, { frequent: true, extra: false }, ...['frequent', 'favorites', 'all', 'frequent_first'].flatMap(key => [null, 0, 1, 'true', [], {}].map(value => ({ [key]: value })))]) {
    assert.throws(() => validateLayout({ ...layout, settings }), { status: 400, message: 'invalid_layout' });
  }
});

test('settings feature round trips explicit values, empty objects and omission', async () => {
  const { token } = await enroll();
  await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify(layout)).run();
  const headers = { ...auth(token), 'X-Layout-Features': 'favorite,used,visits,input, settings ' };
  let revision = 1;
  for (const settings of [{ frequent: false, favorites: true, all: false, frequent_first: false }, {}, undefined]) {
    const candidate = { ...layout, ...(settings === undefined ? {} : { settings }) };
    const response = await request('/v1/layout', { method: 'PUT', headers, body: JSON.stringify({ base_revision: revision, layout: candidate }) });
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('X-Layout-Features'), 'favorite,used,visits,input,settings,hosts');
    const reply = await response.json();
    assert.deepEqual(reply, { revision: ++revision, layout: { ...candidate, revision } });
    const get = await request('/v1/layout', { headers });
    assert.deepEqual(await get.json(), reply);
    const stored = await db.prepare('SELECT revision,layout FROM layouts').first();
    assert.equal(stored.revision, revision);
    assert.deepEqual(JSON.parse(stored.layout), reply.layout);
  }
});

test('settings GET and 409 negotiation strips undeclared settings without changing storage', async () => {
  const { token } = await enroll();
  const saved = { ...layout, settings: { favorites: false, frequent_first: false }, tabs: [{ ...layout.tabs[0], favorite: true }] };
  await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify(saved)).run();
  for (const features of [undefined, 'settings-other', 'favorite', 'settings', ' favorite , settings ']) {
    const headers = { ...auth(token), ...(features === undefined ? {} : { 'X-Layout-Features': features }) };
    const expected = { ...layout, ...(['settings', ' favorite , settings '].includes(features) ? { settings: saved.settings } : {}), tabs: [{ ...layout.tabs[0], ...(['favorite', ' favorite , settings '].includes(features) ? { favorite: true } : {}) }] };
    for (const options of [{ headers }, { method: 'PUT', headers, body: JSON.stringify({ base_revision: 0, layout }) }]) {
      const response = await request('/v1/layout', options);
      assert.equal(response.status, options.method ? 409 : 200);
      assert.equal(response.headers.get('X-Layout-Features'), 'favorite,used,visits,input,settings,hosts');
      assert.deepEqual(await response.json(), { revision: 1, layout: expected });
    }
  }
  assert.deepEqual(JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout), saved);
});

test('settings legacy PUT preserves stored settings and cannot introduce or overwrite them', async () => {
  const { token } = await enroll();
  for (const settings of [undefined, {}, { frequent: false, favorites: false, all: false, frequent_first: false }]) for (const features of [undefined, 'favorite', 'settings-other']) for (const incoming of [undefined, { frequent: true, all: true }]) {
    const saved = { ...layout, ...(settings === undefined ? {} : { settings }) };
    await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify(saved)).run();
    const headers = { ...auth(token), ...(features === undefined ? {} : { 'X-Layout-Features': features }) };
    const tabs = [{ ...layout.tabs[0], name: 'Renamed' }];
    const response = await request('/v1/layout', { method: 'PUT', headers, body: JSON.stringify({ base_revision: 1, layout: { ...layout, tabs, ...(incoming === undefined ? {} : { settings: incoming }) } }) });
    assert.equal(response.status, 200);
    const reply = await response.json();
    assert.ok(!Object.hasOwn(reply.layout, 'settings'));
    assert.deepEqual(reply.layout.tabs, tabs);
    assert.deepEqual(JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout), { ...saved, revision: 2, tabs });
  }
});

test('settings invalid PUTs reject unknown keys and non-boolean values without saving', async () => {
  const { token } = await enroll();
  await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify(layout)).run();
  for (const settings of [{ other: true }, { frequent: 'false' }, { favorites: 0 }, { all: null }, { frequent_first: [] }, null, []]) {
    const response = await request('/v1/layout', { method: 'PUT', headers: { ...auth(token), 'X-Layout-Features': 'settings' }, body: JSON.stringify({ base_revision: 1, layout: { ...layout, settings } }) });
    assert.equal(response.status, 400);
    assert.equal(response.headers.get('X-Layout-Features'), 'favorite,used,visits,input,settings,hosts');
    assert.deepEqual(await response.json(), { error: 'invalid_layout' });
  }
  const stored = await db.prepare('SELECT revision,layout FROM layouts').first();
  assert.equal(stored.revision, 1);
  assert.deepEqual(JSON.parse(stored.layout), layout);
});

const host = { slot: 0, name: 'Host 1', hostname: '203.0.113.5', port: 22, user: 'owner', host_keys: ['ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA'] };

test('hosts capable PUT and GET round trip and advertise hosts', async () => {
  const { token } = await enroll();
  await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify(layout)).run();
  const headers = { ...auth(token), 'X-Layout-Features': ' hosts ' };
  const response = await request('/v1/layout', { method: 'PUT', headers, body: JSON.stringify({ base_revision: 1, layout: { ...layout, hosts: [host] } }) });
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('X-Layout-Features'), 'favorite,used,visits,input,settings,hosts');
  assert.deepEqual((await response.json()).layout.hosts, [host]);
  const get = await request('/v1/layout', { headers });
  assert.equal(get.status, 200);
  assert.deepEqual((await get.json()).layout.hosts, [host]);
});

test('hosts legacy GET and conflict hide hosts and PUT preserves stored hosts', async () => {
  const { token } = await enroll();
  for (const features of ['', 'hosts-other']) {
    const saved = { ...layout, hosts: [host] };
    await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify(saved)).run();
    const headers = { ...auth(token), 'X-Layout-Features': features };
    for (const options of [{ headers }, { method: 'PUT', headers, body: JSON.stringify({ base_revision: 0, layout }) }]) {
      const response = await request('/v1/layout', options);
      assert.equal(response.status, options.method ? 409 : 200);
      assert.ok(!Object.hasOwn((await response.json()).layout, 'hosts'));
    }
    const response = await request('/v1/layout', { method: 'PUT', headers, body: JSON.stringify({ base_revision: 1, layout: { ...layout, hosts: [{ ...host, hostname: 'other.example' }] } }) });
    assert.equal(response.status, 200);
    assert.ok(!Object.hasOwn((await response.json()).layout, 'hosts'));
    assert.deepEqual(JSON.parse((await db.prepare('SELECT layout FROM layouts').first()).layout).hosts, [host]);
  }
});

test('hosts partial PUT replaces slot 1 and keeps slot 0 sorted across empty and omitted updates', async () => {
  const { token } = await enroll();
  const old = { ...host, slot: 1, name: 'Host 2' }, updated = { ...old, hostname: '2001:db8::1', port: 2222 };
  await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify({ ...layout, hosts: [old, host] })).run();
  const headers = { ...auth(token), 'X-Layout-Features': 'hosts' };
  let revision = 1;
  for (const hosts of [[updated], [], undefined]) {
    const response = await request('/v1/layout', { method: 'PUT', headers, body: JSON.stringify({ base_revision: revision, layout: { ...layout, ...(hosts === undefined ? {} : { hosts }) } }) });
    assert.equal(response.status, 200);
    const reply = await response.json(); revision = reply.revision;
    assert.deepEqual(reply.layout.hosts, [host, updated]);
  }
});

test('hosts invalid values return invalid_hosts without changing D1', async () => {
  const { token } = await enroll();
  await db.prepare('UPDATE layouts SET revision=1,layout=?').bind(JSON.stringify(layout)).run();
  const before = await db.prepare('SELECT revision,layout FROM layouts').first();
  for (const hosts of [null, {}, [null], [{ ...host, hostname: 'bad host' }], [{ ...host, port: 0 }], [{ ...host, hostname: 'valid.example\n' }], [{ ...host, user: 'root\n' }], [{ ...host, host_keys: ['ssh-rsa AAAA\n'] }], [{ ...host, name: 'PRIVATE KEY' }], [host, host], [{ ...host, host_keys: ['ssh-rsa PRIVATE KEY'] }], [{ ...host, identity_file: '~/.ssh/id_rsa' }], [{ ...host, user: 'root\nHost *' }], [{ ...host, name: 'bad\nname' }], [{ ...host, name: 'bad\u0085name' }], [{ ...host, slot: 3 }], [{ ...host, host_keys: [host.host_keys[0], host.host_keys[0]] }], [{ ...host, host_keys: ['ssh-ed25519 ' + 'A'.repeat(1024)] }]]) {
    const response = await request('/v1/layout', { method: 'PUT', headers: { ...auth(token), 'X-Layout-Features': 'hosts' }, body: JSON.stringify({ base_revision: 1, layout: { ...layout, hosts } }) });
    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), { error: 'invalid_hosts' });
  }
  assert.deepEqual(await db.prepare('SELECT revision,layout FROM layouts').first(), before);
});

const crashReport = { id: 'crash-0001', captured_at: 1791738000, app_version: '0.1.213 (100213)', android_version: '15 (SDK 35)', thread: 'main', summary: 'java.lang.IllegalStateException: crash', stack_trace: 'java.lang.IllegalStateException: crash\n\tat dev.multiprompt.Main.run(Main.kt:42)' };
const sendCrash = (token, report = crashReport, headers = {}) => request('/v1/crash-reports', { ...post(report), headers: { ...post(report).headers, ...auth(token), ...headers } });

test('crash reports: valid report stores authenticated device/account and server receive time; duplicate does not overwrite', async () => {
  const { token } = await enroll();
  const before = Math.floor(Date.now() / 1000);
  const response = await sendCrash(token);
  assert.equal(response.status, 201); assert.deepEqual(await response.json(), { stored: true });
  const stored = await db.prepare('SELECT * FROM crash_reports WHERE device_id=?').bind(token.device_id).first();
  assert.deepEqual(stored, { device_id: token.device_id, report_id: crashReport.id, account: token.account_id, received_at: stored.received_at, ...Object.fromEntries(Object.entries(crashReport).filter(([key]) => key !== 'id')) });
  assert.ok(stored.received_at >= before && stored.received_at <= Math.floor(Date.now() / 1000));
  const duplicate = await sendCrash(token, { ...crashReport, summary: 'Changed' });
  assert.equal(duplicate.status, 200); assert.deepEqual(await duplicate.json(), { stored: false, duplicate: true });
  assert.deepEqual((await db.prepare('SELECT * FROM crash_reports WHERE device_id=?').bind(token.device_id).all()).results, [stored]);
});

test('crash reports: simultaneous retries store one row', async () => {
  const { token } = await enroll();
  const responses = await Promise.all([sendCrash(token), sendCrash(token)]);
  assert.deepEqual(responses.map(r => r.status).sort(), [200, 201]);
  assert.equal((await db.prepare('SELECT count(*) AS n FROM crash_reports WHERE device_id=?').bind(token.device_id).first()).n, 1);
});

test('crash reports: strict fields, types and bounds reject without storing', async () => {
  const { token } = await enroll();
  const bad = [null, [], 'report', 1, { ...crashReport, hostname: 'private' }];
  for (const key of Object.keys(crashReport)) {
    const omitted = { ...crashReport }; delete omitted[key]; bad.push(omitted);
    for (const value of [null, true, [], {}]) bad.push({ ...crashReport, [key]: value });
  }
  for (const id of ['', 'a'.repeat(7), 'a'.repeat(65), 'crash_001', 'crash 001', 'crash-01\n', 'crash-ä1']) bad.push({ ...crashReport, id });
  for (const captured_at of ['123', 1.5, Number.MAX_SAFE_INTEGER + 1]) bad.push({ ...crashReport, captured_at });
  for (const [key, max] of Object.entries({ app_version: 64, android_version: 64, thread: 200, summary: 2000, stack_trace: 16000 })) {
    bad.push({ ...crashReport, [key]: 'x'.repeat(max + 1) }, { ...crashReport, [key]: 123 });
  }
  bad.push({ ...crashReport, stack_trace: '' });
  for (const report of bad) {
    const response = await sendCrash(token, report);
    assert.equal(response.status, 400, JSON.stringify(report)?.slice(0, 100));
    assert.deepEqual(await response.json(), { error: 'invalid_crash_report' });
  }
  for (const body of ['', '{', 'null']) {
    const response = await request('/v1/crash-reports', { method: 'POST', headers: auth(token), body });
    assert.equal(response.status, 400); assert.deepEqual(await response.json(), { error: 'invalid_crash_report' });
  }
  assert.equal((await db.prepare('SELECT count(*) AS n FROM crash_reports WHERE device_id=?').bind(token.device_id).first()).n, 0);
});

test('crash reports: inclusive field boundaries allow empty optional text and multiline full stacks', async () => {
  const { token } = await enroll();
  for (const report of [
    { id: 'a'.repeat(8), captured_at: 0, app_version: '', android_version: '', thread: '', summary: '', stack_trace: 'x' },
    { id: 'Z9-'.repeat(21) + 'Z', captured_at: Number.MAX_SAFE_INTEGER, app_version: 'a'.repeat(64), android_version: 'a'.repeat(64), thread: 'a'.repeat(200), summary: 'a'.repeat(2000), stack_trace: 'a'.repeat(15998) + '\n\t' }
  ]) {
    assert.equal((await sendCrash(token, report)).status, 201);
    const stored = await db.prepare('SELECT stack_trace FROM crash_reports WHERE device_id=? AND report_id=?').bind(token.device_id, report.id).first();
    assert.equal(stored.stack_trace, report.stack_trace);
  }
});

test('crash reports: body limit counts bytes with and without content length and accepts exactly 32 KiB', async () => {
  const { token } = await enroll();
  const raw = JSON.stringify(crashReport);
  const exact = raw + ' '.repeat(32768 - Buffer.byteLength(raw));
  assert.equal((await request('/v1/crash-reports', { method: 'POST', headers: auth(token), body: exact })).status, 201);
  for (const body of [exact + ' ', JSON.stringify({ ...crashReport, stack_trace: '界'.repeat(12000) })]) {
    for (const headers of [auth(token), { ...auth(token), 'Content-Length': String(Buffer.byteLength(body)) }]) {
      const response = await request('/v1/crash-reports', { method: 'POST', headers, body });
      assert.equal(response.status, 413); assert.deepEqual(await response.json(), { error: 'too_large' });
    }
  }
});

test('crash reports: missing, invalid and expired device tokens are unauthorized', async () => {
  for (const headers of [{}, { Authorization: 'Bearer invalid' }, { Authorization: 'Bearer ' + 'z'.repeat(43) }]) {
    assert.equal((await request('/v1/crash-reports', { ...post(crashReport), headers })).status, 401);
  }
  const { token } = await enroll();
  await db.prepare('UPDATE access_tokens SET expires=0 WHERE hash=?').bind(await hash(token.access_token)).run();
  assert.equal((await sendCrash(token)).status, 401);
});

test('crash reports: browser sessions cannot write, even with same-origin dash headers', async () => {
  const cookie = await emailSignIn();
  for (const Origin of [base, 'https://evil.example', 'null', undefined]) {
    const response = await request('/v1/crash-reports', { ...post(crashReport), headers: { Cookie: cookie, 'X-Multiprompt': 'dash', ...(Origin === undefined ? {} : { Origin }) } });
    assert.equal(response.status, 403); assert.deepEqual(await response.json(), { error: 'cross_origin' });
  }
});

test('crash reports: same report id is independent per device', async () => {
  const { token: a } = await enroll(), { token: b } = await enroll();
  assert.equal((await sendCrash(a)).status, 201); assert.equal((await sendCrash(b)).status, 201);
  const rows = (await db.prepare('SELECT device_id,account FROM crash_reports WHERE device_id IN (?,?)').bind(a.device_id, b.device_id).all()).results;
  assert.deepEqual(rows.sort((x, y) => x.device_id.localeCompare(y.device_id)), [a, b].map(token => ({ device_id: token.device_id, account: token.account_id })).sort((x, y) => x.device_id.localeCompare(y.device_id)));
});

test('crash reports: 51st report prunes oldest received time, with deterministic arrival-order ties and device isolation', async () => {
  const { token: a } = await enroll(), { token: b } = await enroll();
  assert.equal((await sendCrash(b)).status, 201);
  for (let i = 0; i < 50; i++) assert.equal((await sendCrash(a, { ...crashReport, id: 'report-' + String(i).padStart(3, '0'), captured_at: 100 - i })).status, 201);
  await db.prepare('UPDATE crash_reports SET received_at=10 WHERE device_id=?').bind(a.device_id).run();
  await db.prepare('UPDATE crash_reports SET received_at=0 WHERE device_id=? AND report_id=?').bind(a.device_id, 'report-025').run();
  assert.equal((await sendCrash(a, { ...crashReport, id: 'report-050' })).status, 201);
  const rows = (await db.prepare('SELECT report_id FROM crash_reports WHERE device_id=?').bind(a.device_id).all()).results;
  assert.equal(rows.length, 50); assert.ok(!rows.some(row => row.report_id === 'report-025')); assert.ok(rows.some(row => row.report_id === 'report-050'));
  assert.equal((await sendCrash(a, { ...crashReport, id: 'report-051' })).status, 201);
  assert.equal((await db.prepare('SELECT count(*) AS n FROM crash_reports WHERE device_id=?').bind(a.device_id).first()).n, 50);
  assert.equal(await db.prepare('SELECT report_id FROM crash_reports WHERE device_id=? AND report_id=?').bind(a.device_id, 'report-000').first(), null);
  assert.equal((await db.prepare('SELECT count(*) AS n FROM crash_reports WHERE device_id=?').bind(b.device_id).first()).n, 1);
});

test('crash reports: revoke removes only the authorized device reports and rejects future uploads', async () => {
  const { token: a } = await enroll(), { token: b } = await enroll();
  assert.equal((await sendCrash(a)).status, 201); assert.equal((await sendCrash(b)).status, 201);
  await db.prepare('UPDATE devices SET account=? WHERE id=?').bind('another@example.com', b.device_id).run();
  assert.equal((await request('/v1/devices/' + b.device_id, { method: 'DELETE', headers: auth(a) })).status, 404);
  assert.equal((await db.prepare('SELECT count(*) AS n FROM crash_reports WHERE device_id=?').bind(b.device_id).first()).n, 1);
  for (const headers of [auth(a), { Cookie: await emailSignIn(), ...origin, 'X-Multiprompt': 'dash' }]) {
    assert.equal((await request('/v1/devices/' + a.device_id, { method: 'DELETE', headers })).status, 200);
  }
  assert.equal((await db.prepare('SELECT count(*) AS n FROM crash_reports WHERE device_id=?').bind(a.device_id).first()).n, 0);
  assert.equal((await db.prepare('SELECT count(*) AS n FROM crash_reports WHERE device_id=?').bind(b.device_id).first()).n, 1);
  assert.equal((await sendCrash(a)).status, 401);
});

test('crash reports: dashboard revoke deletes existing reports and preserves a sibling device on the same account', async () => {
  const { token: a } = await enroll(), { token: b } = await enroll();
  assert.equal(a.account_id, b.account_id);
  assert.equal((await sendCrash(a)).status, 201); assert.equal((await sendCrash(b)).status, 201);
  const response = await request('/v1/devices/' + a.device_id, { method: 'DELETE', headers: { Cookie: await emailSignIn(), ...origin, 'X-Multiprompt': 'dash' } });
  assert.equal(response.status, 200); assert.deepEqual(await response.json(), { revoked: true });
  assert.equal((await db.prepare('SELECT count(*) AS n FROM crash_reports WHERE device_id=?').bind(a.device_id).first()).n, 0);
  assert.equal((await db.prepare('SELECT count(*) AS n FROM crash_reports WHERE device_id=?').bind(b.device_id).first()).n, 1);
  assert.equal((await sendCrash(a)).status, 401);
  assert.equal((await sendCrash(b, { ...crashReport, id: 'crash-0002' })).status, 201);
});

const deviceKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFh';
const putDeviceKey = (token, public_key = deviceKey) => request('/v1/device-key', { method: 'PUT', headers: auth(token), body: JSON.stringify({ public_key }) });
const decideDeviceKey = (caller, target, action = 'approve') => request('/v1/device-keys/' + target.device_id + '/' + action, { method: 'POST', headers: auth(caller) });

test('device keys: registration is pending, unchanged keys preserve decisions and replacement requires approval again', async () => {
  const { token: a } = await enroll(), { token: b } = await enroll();
  const before = Math.floor(Date.now() / 1000);
  const registered = await putDeviceKey(a);
  assert.equal(registered.status, 200); assert.deepEqual(await registered.json(), { status: 'pending' });
  const pending = await db.prepare('SELECT * FROM device_keys WHERE device_id=?').bind(a.device_id).first();
  assert.deepEqual(pending, { device_id: a.device_id, account: a.account_id, public_key: deviceKey, status: 'pending', requested: pending.requested, decided: null, decided_by: null });
  assert.ok(pending.requested >= before && pending.requested <= Math.floor(Date.now() / 1000));
  await db.prepare('UPDATE device_keys SET requested=1 WHERE device_id=?').bind(a.device_id).run();
  assert.deepEqual(await (await putDeviceKey(a)).json(), { status: 'pending' });
  assert.equal((await db.prepare('SELECT requested FROM device_keys WHERE device_id=?').bind(a.device_id).first()).requested, 1);
  for (const [action, status] of [['approve', 'approved'], ['deny', 'denied']]) {
    const response = await decideDeviceKey(b, a, action);
    assert.equal(response.status, 200); assert.deepEqual(await response.json(), { status });
    const decided = await db.prepare('SELECT * FROM device_keys WHERE device_id=?').bind(a.device_id).first();
    assert.equal(decided.status, status); assert.equal(decided.decided_by, b.device_id);
    assert.ok(decided.decided >= before && decided.decided <= Math.floor(Date.now() / 1000));
    assert.deepEqual(await (await putDeviceKey(a, decided.public_key)).json(), { status });
    assert.deepEqual(await db.prepare('SELECT * FROM device_keys WHERE device_id=?').bind(a.device_id).first(), decided);
    for (const again of ['approve', 'deny']) {
      const repeated = await decideDeviceKey(b, a, again);
      assert.equal(repeated.status, 409); assert.deepEqual(await repeated.json(), { error: 'not_pending' });
    }
    if (action === 'approve') {
      const replacement = 'ssh-ed25519 ' + Buffer.concat([Buffer.from(deviceKey.slice(12), 'base64').subarray(0, 19), Buffer.alloc(32, 98)]).toString('base64');
      const changed = await putDeviceKey(a, replacement);
      assert.equal(changed.status, 200); assert.deepEqual(await changed.json(), { status: 'pending' });
      const row = await db.prepare('SELECT * FROM device_keys WHERE device_id=?').bind(a.device_id).first();
      assert.deepEqual(row, { ...pending, public_key: replacement, requested: row.requested });
      assert.ok(row.requested >= before && row.requested <= Math.floor(Date.now() / 1000));
    }
  }
  assert.equal((await putDeviceKey(b)).status, 200);
  assert.equal((await decideDeviceKey(a, b)).status, 200);
});

test('device keys: self decisions are forbidden, unknown and cross-account targets are hidden and lists are account scoped', async () => {
  const { token: a } = await enroll(), { token: foreign } = await enroll(), { token: empty } = await enroll();
  await db.prepare('UPDATE devices SET account=? WHERE id=?').bind('another@example.com', foreign.device_id).run();
  assert.equal((await putDeviceKey(a)).status, 200); assert.equal((await putDeviceKey(foreign)).status, 200);
  const before = (await db.prepare('SELECT * FROM device_keys').all()).results;
  for (const action of ['approve', 'deny']) {
    const self = await decideDeviceKey(a, a, action);
    assert.equal(self.status, 403); assert.deepEqual(await self.json(), { error: 'self_approval' });
    for (const [caller, target] of [[a, foreign], [foreign, a], [a, empty], [a, { device_id: 'missing' }]]) {
      const response = await decideDeviceKey(caller, target, action);
      assert.equal(response.status, 404); assert.deepEqual(await response.json(), { error: 'not_found' });
    }
  }
  assert.deepEqual((await db.prepare('SELECT * FROM device_keys').all()).results, before);
  for (const token of [a, foreign]) {
    const response = await request('/v1/device-keys', { headers: auth(token) });
    assert.equal(response.status, 200);
    const expected = (await db.prepare('SELECT k.device_id,d.name,k.public_key,k.status,k.requested,k.decided FROM device_keys k JOIN devices d ON d.id=k.device_id WHERE k.account=? ORDER BY k.requested,k.device_id').bind(token === foreign ? 'another@example.com' : a.account_id).all()).results;
    assert.deepEqual(await response.json(), { device_id: token.device_id, keys: expected });
    assert.ok(expected.some(key => key.device_id === token.device_id));
    assert.ok(!expected.some(key => key.device_id === (token === a ? foreign : a).device_id || key.device_id === empty.device_id));
  }
  assert.equal((await request('/v1/devices/' + foreign.device_id, { method: 'DELETE', headers: auth(a) })).status, 404);
  assert.equal((await db.prepare('SELECT status FROM device_keys WHERE device_id=?').bind(foreign.device_id).first()).status, 'pending');
});

test('device keys: concurrent approve and deny admit only one pending decision', async () => {
  const { token: a } = await enroll(), { token: b } = await enroll();
  assert.equal((await putDeviceKey(a)).status, 200);
  const responses = await Promise.all(['approve', 'deny'].map(action => decideDeviceKey(b, a, action)));
  assert.deepEqual(responses.map(r => r.status).sort(), [200, 409]);
  const winner = await responses.find(r => r.status === 200).json();
  assert.deepEqual(await responses.find(r => r.status === 409).json(), { error: 'not_pending' });
  const stored = await db.prepare('SELECT status,decided_by FROM device_keys WHERE device_id=?').bind(a.device_id).first();
  assert.deepEqual(stored, { status: winner.status, decided_by: b.device_id });
});

test('device keys: device, dashboard and self revocation retain pending, approved and denied keys as revoked', async () => {
  const { token: b } = await enroll();
  assert.equal((await putDeviceKey(b)).status, 200);
  for (const initial of ['pending', 'approved', 'denied']) {
    const { token: a } = await enroll();
    assert.equal((await putDeviceKey(a)).status, 200);
    if (initial !== 'pending') assert.equal((await decideDeviceKey(b, a, initial === 'approved' ? 'approve' : 'deny')).status, 200);
    const before = await db.prepare('SELECT * FROM device_keys WHERE device_id=?').bind(a.device_id).first();
    const headers = initial === 'approved' ? { Cookie: await emailSignIn(), ...origin, 'X-Multiprompt': 'dash' } : auth(initial === 'denied' ? a : b);
    const response = await request('/v1/devices/' + a.device_id, { method: 'DELETE', headers });
    assert.equal(response.status, 200); assert.deepEqual(await response.json(), { revoked: true });
    assert.deepEqual(await db.prepare('SELECT * FROM device_keys WHERE device_id=?').bind(a.device_id).first(), { ...before, status: 'revoked' });
    const listed = await request('/v1/device-keys', { headers: auth(b) });
    assert.equal(listed.status, 200);
    assert.deepEqual((await listed.json()).keys.find(key => key.device_id === a.device_id), { device_id: a.device_id, name: 'Test device', public_key: before.public_key, status: 'revoked', requested: before.requested, decided: before.decided });
    assert.equal((await putDeviceKey(a)).status, 401);
    for (const action of ['approve', 'deny']) {
      const decision = await decideDeviceKey(b, a, action);
      assert.equal(decision.status, 409); assert.deepEqual(await decision.json(), { error: 'not_pending' });
    }
  }
  assert.equal((await db.prepare('SELECT status FROM device_keys WHERE device_id=?').bind(b.device_id).first()).status, 'pending');
});

test('device keys: strict public-key bodies reject private material, comments, algorithms, extra fields and oversize keys without writing', async () => {
  const { token } = await enroll();
  assert.equal((await putDeviceKey(token)).status, 200);
  const before = await db.prepare('SELECT * FROM device_keys WHERE device_id=?').bind(token.device_id).first();
  const bad = [null, [], 'key', 1, {}, { other: deviceKey }, { public_key: deviceKey, extra: true }, { public_key: deviceKey, private_key: 'PRIVATE' }];
  for (const public_key of [null, true, 1, [], {}, '', '-----BEGIN OPENSSH PRIVATE KEY-----\nPRIVATE\n-----END OPENSSH PRIVATE KEY-----', deviceKey + ' comment', 'ssh-rsa AAAA', 'ssh-ed25519 ' + 'A'.repeat(189), 'ssh-ed25519 PRIVATE', 'ssh-ed25519 BEGIN', 'ssh-ed25519 AAA===', 'ssh-ed25519 AA_A', 'ssh-ed25519 AA-A', 'ssh-ed25519  AAAA', ...['\n', '\r', '\r\n', '\u2028', '\u2029', ' '].map(suffix => deviceKey + suffix)]) bad.push({ public_key });
  for (const body of [...bad.map(b => JSON.stringify(b)), '', '{']) {
    const response = await request('/v1/device-key', { method: 'PUT', headers: auth(token), body });
    assert.equal(response.status, 400, body); assert.deepEqual(await response.json(), { error: 'invalid_key' });
    assert.deepEqual(await db.prepare('SELECT * FROM device_keys WHERE device_id=?').bind(token.device_id).first(), before);
  }
  for (const public_key of ['ssh-ed25519 A+/', 'ssh-ed25519 A+/=', 'ssh-ed25519 A+/==', 'ssh-ed25519 ' + 'A'.repeat(188)]) {
    const response = await putDeviceKey(token, public_key);
    assert.equal(response.status, 400); assert.deepEqual(await response.json(), { error: 'invalid_key' });
    assert.deepEqual(await db.prepare('SELECT * FROM device_keys WHERE device_id=?').bind(token.device_id).first(), before);
  }
});

test('device keys: every endpoint requires a live device Bearer token, not a browser session', async () => {
  const { token: a } = await enroll(), { token: b } = await enroll();
  assert.equal((await putDeviceKey(b)).status, 200);
  const calls = [['/v1/device-key', 'PUT'], ['/v1/device-keys', 'GET'], ...['approve', 'deny'].map(action => ['/v1/device-keys/' + b.device_id + '/' + action, 'POST'])];
  const cookie = await emailSignIn();
  const headers = [{}, { Authorization: 'Bearer invalid' }, { Authorization: 'Bearer ' + 'z'.repeat(43) }, { Cookie: cookie }, { Cookie: cookie, ...origin, 'X-Multiprompt': 'dash' }];
  await db.prepare('UPDATE access_tokens SET expires=0 WHERE hash=?').bind(await hash(a.access_token)).run();
  headers.push(auth(a));
  const { token: revoked } = await enroll();
  assert.equal((await request('/v1/devices/' + revoked.device_id, { method: 'DELETE', headers: auth(b) })).status, 200);
  headers.push(auth(revoked));
  for (const h of headers) for (const [path, method] of calls) {
    const response = await request(path, { method, headers: h, ...(method === 'PUT' ? { body: JSON.stringify({ public_key: deviceKey }) } : {}) });
    assert.equal(response.status, 401, method + ' ' + path); assert.deepEqual(await response.json(), { error: 'device_required' });
  }
  assert.equal((await db.prepare('SELECT status FROM device_keys WHERE device_id=?').bind(b.device_id).first()).status, 'pending');
});

test('device keys: additive schema is repeatable and enforces statuses and cascading device ownership', async () => {
  const sql = readFileSync(new URL('../schema.sql', import.meta.url), 'utf8').split(';').find(s => s.includes('CREATE TABLE IF NOT EXISTS device_keys'));
  await db.prepare(sql).run();
  const columns = (await db.prepare('PRAGMA table_info(device_keys)').all()).results;
  assert.deepEqual(columns.map(c => [c.name, c.type, c.notnull, c.pk]), [['device_id', 'TEXT', 0, 1], ['account', 'TEXT', 1, 0], ['public_key', 'TEXT', 1, 0], ['status', 'TEXT', 1, 0], ['requested', 'INTEGER', 1, 0], ['decided', 'INTEGER', 0, 0], ['decided_by', 'TEXT', 0, 0]]);
  const fk = (await db.prepare('PRAGMA foreign_key_list(device_keys)').all()).results;
  assert.equal(fk.length, 1); assert.equal(fk[0].table, 'devices'); assert.equal(fk[0].from, 'device_id'); assert.equal(fk[0].to, 'id'); assert.equal(fk[0].on_delete, 'CASCADE');
  await db.prepare('INSERT INTO devices VALUES (?,?,?,?,?,?,?)').bind('key-schema', 'schema@example.com', 'Schema device', 'key-schema-hash', 0, 0, 0).run();
  await db.prepare("INSERT INTO device_keys VALUES (?,?,?,'pending',0,NULL,NULL)").bind('key-schema', 'schema@example.com', deviceKey).run();
  await assert.rejects(db.prepare("UPDATE device_keys SET status='invalid' WHERE device_id='key-schema'").run(), /CHECK constraint failed/);
  await assert.rejects(db.prepare("INSERT INTO device_keys VALUES ('missing-key-device','schema@example.com',?,'pending',0,NULL,NULL)").bind(deviceKey).run(), /FOREIGN KEY constraint failed/);
  await db.prepare("DELETE FROM devices WHERE id='key-schema'").run();
  assert.equal(await db.prepare("SELECT * FROM device_keys WHERE device_id='key-schema'").first(), null);
});

test('device keys: after all flows every column in D1 is free of PRIVATE material', async () => {
  const rows = (await db.prepare('SELECT * FROM device_keys').all()).results;
  assert.ok(rows.length > 0);
  for (const status of ['pending', 'approved', 'denied', 'revoked']) assert.ok(rows.some(row => row.status === status), status);
  const check = row => { for (const value of Object.values(row)) assert.doesNotMatch(String(value), /PRIVATE/); };
  assert.throws(() => check({ decided_by: 'PRIVATE' }), assert.AssertionError);
  for (const row of rows) check(row);
});

function afterKeyLookup(hook) {
  let fired = false;
  return {
    prepare(sql) {
      const wrap = statement => new Proxy(statement, { get(target, name) {
        if (name === 'bind') return (...args) => wrap(target.bind(...args));
        if (name === 'first') return async (...args) => {
          const result = await target.first(...args);
          if (!fired && sql.startsWith('SELECT device_id FROM device_keys')) { fired = true; await hook(); }
          return result;
        };
        const value = target[name];
        return typeof value === 'function' ? value.bind(target) : value;
      } });
      return wrap(db.prepare(sql));
    },
    batch: statements => db.batch(statements)
  };
}

for (const initial of ['absent', 'pending', 'approved', 'denied']) test('device key regression: slow PUT cannot resurrect revoked key: ' + initial, async () => {
  const { token: caller } = await enroll(), { token: admin } = await enroll();
  if (initial !== 'absent') {
    assert.equal((await putDeviceKey(caller)).status, 200);
    if (initial !== 'pending') assert.equal((await decideDeviceKey(admin, caller, initial === 'approved' ? 'approve' : 'deny')).status, 200);
  }
  const reading = Promise.withResolvers(), release = Promise.withResolvers();
  const stream = new ReadableStream({ async pull(controller) {
    reading.resolve();
    await release.promise;
    controller.enqueue(new TextEncoder().encode(JSON.stringify({ public_key: 'ssh-ed25519 ' + Buffer.concat([Buffer.from(deviceKey.slice(12), 'base64').subarray(0, 19), Buffer.alloc(32, 98)]).toString('base64') })));
    controller.close();
  } }, { highWaterMark: 0 });
  const pending = worker.fetch(new Request(base + '/v1/device-key', { method: 'PUT', headers: auth(caller), body: stream, duplex: 'half' }), { DB: db });
  await reading.promise;
  try { assert.equal((await request('/v1/devices/' + caller.device_id, { method: 'DELETE', headers: auth(admin) })).status, 200); }
  finally { release.resolve(); }
  const response = await pending;
  const row = await db.prepare('SELECT * FROM device_keys WHERE device_id=?').bind(caller.device_id).first();
  assert.equal(row?.status ?? null, initial === 'absent' ? null : 'revoked');
  if (row) assert.equal(row.public_key, deviceKey);
  assert.equal(response.status, 401); assert.deepEqual(await response.json(), { error: 'device_required' });
  assert.equal((await decideDeviceKey(admin, caller)).status, initial === 'absent' ? 404 : 409);
});

for (const action of ['approve', 'deny']) {
  test('device key regression: revoked caller cannot ' + action + ' after lookup', async () => {
    const { token: caller } = await enroll(), { token: target } = await enroll(), { token: admin } = await enroll();
    assert.equal((await putDeviceKey(target)).status, 200);
    const before = await db.prepare('SELECT * FROM device_keys WHERE device_id=?').bind(target.device_id).first();
    const guarded = afterKeyLookup(async () => {
      assert.equal((await request('/v1/devices/' + caller.device_id, { method: 'DELETE', headers: auth(admin) })).status, 200);
    });
    const response = await worker.fetch(new Request(base + '/v1/device-keys/' + target.device_id + '/' + action, { method: 'POST', headers: auth(caller) }), { DB: guarded });
    assert.deepEqual(await db.prepare('SELECT * FROM device_keys WHERE device_id=?').bind(target.device_id).first(), before);
    assert.equal(response.status, 401); assert.deepEqual(await response.json(), { error: 'device_required' });
  });
  for (const change of ['caller account', 'target account', 'target revoked']) test('device key regression: ' + change + ' blocks ' + action + ' atomically', async () => {
    const { token: caller } = await enroll(), { token: target } = await enroll();
    assert.equal((await putDeviceKey(target)).status, 200);
    const before = await db.prepare('SELECT * FROM device_keys WHERE device_id=?').bind(target.device_id).first();
    const guarded = afterKeyLookup(async () => {
      if (change === 'target revoked') await db.prepare('UPDATE devices SET revoked=1 WHERE id=?').bind(target.device_id).run();
      else await db.prepare('UPDATE devices SET account=? WHERE id=?').bind('another@example.com', change === 'caller account' ? caller.device_id : target.device_id).run();
    });
    const response = await worker.fetch(new Request(base + '/v1/device-keys/' + target.device_id + '/' + action, { method: 'POST', headers: auth(caller) }), { DB: guarded });
    assert.deepEqual(await db.prepare('SELECT * FROM device_keys WHERE device_id=?').bind(target.device_id).first(), before);
    assert.equal(response.status, change === 'caller account' ? 401 : 409);
  });
}

const keyPair = generateKeyPairSync('ed25519');
const keyWire = Buffer.concat([Buffer.from('0000000b7373682d6564323535313900000020', 'hex'), keyPair.publicKey.export({ format: 'der', type: 'spki' }).subarray(-32)]);
for (const [name, encoded] of [
  ['private DER', keyPair.privateKey.export({ format: 'der', type: 'pkcs8' }).toString('base64')],
  ['public DER', keyPair.publicKey.export({ format: 'der', type: 'spki' }).toString('base64')],
  ['non-key base64', 'A+/=='],
  ['wrong algorithm', Buffer.concat([keyWire.subarray(0, 4), Buffer.from('ssh-ed25518'), keyWire.subarray(15)]).toString('base64')],
  ['algorithm length', Buffer.concat([Buffer.from('0000000a', 'hex'), keyWire.subarray(4)]).toString('base64')],
  ['key length', Buffer.concat([keyWire.subarray(0, 15), Buffer.from('0000001f', 'hex'), keyWire.subarray(19)]).toString('base64')],
  ['truncated key', keyWire.subarray(0, -1).toString('base64')],
  ['trailing bytes', Buffer.concat([keyWire, Buffer.from([0])]).toString('base64')],
  ['noncanonical padding', keyWire.toString('base64') + '=']
]) test('device key regression: rejects ' + name + ' without writing', async () => {
  const { token } = await enroll();
  const response = await putDeviceKey(token, 'ssh-ed25519 ' + encoded);
  assert.equal(response.status, 400); assert.deepEqual(await response.json(), { error: 'invalid_key' });
  assert.equal(await db.prepare('SELECT * FROM device_keys WHERE device_id=?').bind(token.device_id).first(), null);
});

test('device key regression: real Ed25519 and live-probe wire keys remain accepted', async () => {
  const { token } = await enroll();
  for (const wire of [keyWire, Buffer.concat([keyWire.subarray(0, 19), randomBytes(32)])]) {
    const public_key = 'ssh-ed25519 ' + wire.toString('base64');
    const response = await putDeviceKey(token, public_key);
    assert.equal(response.status, 200); assert.deepEqual(await response.json(), { status: 'pending' });
    assert.equal((await db.prepare('SELECT public_key FROM device_keys WHERE device_id=?').bind(token.device_id).first()).public_key, public_key);
  }
});

const syncHost = (device, stamp, hostname = 'one.example.com') => ({ kind: 'host', id: '0', updated_at: stamp, device_id: device, deleted: false, host: { slot: 0, name: 'Host 1', hostname, port: 22, user: 'owner' } });
const syncPut = (token, records) => request('/v1/sync-records', { method: 'PUT', headers: auth(token), body: JSON.stringify({ records }) });
const syncGet = async token => {
  const result = await request('/v1/sync-records', { headers: auth(token) });
  assert.equal(result.status, 200);
  return (await result.json()).records;
};

test('ISSUE-252 authenticated devices round trip add edit delete and deterministic host conflicts', async () => {
  await db.prepare('DELETE FROM sync_records').run();
  const { token: first } = await enroll(), { token: second } = await enroll();
  const start = Date.now() - 10000;
  const host = syncHost(first.device_id, start);
  const workspace = { kind: 'workspace', id: 'Work', updated_at: start, device_id: first.device_id, deleted: false, workspace: { name: 'Work' } };
  const session = { kind: 'session', id: '0:one', updated_at: start, device_id: first.device_id, deleted: false, session: { kind: 'tmux', name: 'One', tmux_session: 'One', tmux_host: 0, workspace: 'Work' } };
  assert.equal((await syncPut(first, [host, workspace, session])).status, 200);
  assert.deepEqual(await syncGet(second), [host, workspace, session]);
  const left = syncHost(first.device_id, start + 100, 'left.example.com'), right = syncHost(second.device_id, start + 100, 'right.example.com');
  const changed = { ...session, updated_at: start + 100, session: { ...session.session, name: 'Renamed' } };
  const responses = await Promise.all([syncPut(first, [left, changed]), syncPut(second, [right])]);
  assert.ok(responses.every(r => [200, 409].includes(r.status)));
  assert.equal((await syncPut(first, [left, changed])).status, 200);
  assert.equal((await syncPut(second, [right])).status, 200);
  const winner = first.device_id > second.device_id ? left : right;
  const received = await syncGet(first);
  assert.deepEqual(received[0], winner);
  assert.deepEqual(received[1], workspace);
  assert.equal(received[2].session.name, 'Renamed');
  const dead = [winner, workspace, changed].map(({ kind, id }) => ({ kind, id, updated_at: start + 200, device_id: first.device_id, deleted: true }));
  assert.equal((await syncPut(first, dead)).status, 200);
  assert.equal((await syncPut(first, [host, workspace, session])).status, 200);
  assert.deepEqual(await syncGet(second), dead);
  await db.prepare('DELETE FROM sync_records').run();
  assert.equal((await syncPut(second, [right])).status, 200);
  assert.equal((await syncPut(first, [left])).status, 200);
  assert.deepEqual(await syncGet(first), [winner]);
});

test('ISSUE-252 record service rejects credentials keys local paths geometry malformed ids and future clocks', async () => {
  const valid = syncHost('device-a', 100);
  assert.equal(validateRecords([valid])[0], valid);
  for (const key of ['password', 'private_key', 'host_keys', 'IdentityFile', 'cwd', 'window_x', 'window_y', 'width', 'height']) {
    assert.throws(() => validateRecords([{ ...valid, [key]: 'device-only' }]));
    assert.throws(() => validateRecords([{ ...valid, host: { ...valid.host, [key]: 'device-only' } }]));
  }
  for (const bad of [{ ...valid, updated_at: Date.now() + 600000 }, { ...valid, id: '3' }, { ...valid, deleted: true }, { ...valid, device_id: 'unsafe/id' }, { ...valid, session: {} }]) assert.throws(() => validateRecords([bad]));
  assert.throws(() => validateRecords([valid, valid]));
  const { token } = await enroll();
  assert.equal((await syncPut(token, [{ ...valid, device_id: token.device_id, host: { ...valid.host, password: 'device-only' } }])).status, 400);
});

test('ISSUE-252 records are account scoped and unauthorized or revoked devices cannot read or write', async () => {
  assert.equal((await request('/v1/sync-records')).status, 401);
  const { token } = await enroll();
  const otherToken = 'record-foreign-access'.padEnd(43, 'x');
  await db.prepare('INSERT INTO devices VALUES (?,?,?,?,?,?,?)').bind('record-foreign', 'foreign-account', 'Foreign device', 'record-foreign-refresh', 0, 0, 0).run();
  await db.prepare('INSERT INTO access_tokens VALUES (?,?,?)').bind(await hash(otherToken), 'record-foreign', Math.floor(Date.now() / 1000) + 600).run();
  const foreign = { access_token: otherToken, device_id: 'record-foreign' };
  assert.deepEqual(await syncGet(foreign), []);
  assert.equal((await syncPut(foreign, [syncHost(foreign.device_id, Date.now())])).status, 200);
  assert.notDeepEqual(await syncGet(foreign), await syncGet(token));
  await request('/v1/devices/' + token.device_id, { method: 'DELETE', headers: auth(token) });
  assert.equal((await request('/v1/sync-records', { headers: auth(token) })).status, 401);
  assert.equal((await syncPut(token, [syncHost('device', 400)])).status, 401);
});


test('ISSUE-252 N records bind device identity and provide server time for skew correction', async () => {
  const { token } = await enroll();
  const forged = await syncPut(token, [syncHost('forged-device', Date.now())]);
  assert.equal(forged.status, 403);
  assert.equal((await forged.json()).error, 'record_device_mismatch');
  const fast = await syncPut(token, [syncHost(token.device_id, Date.now() + 600000)]);
  assert.equal(fast.status, 400);
  const error = await fast.json();
  assert.equal(error.error, 'clock_skew');
  assert.ok(Math.abs(error.server_time - Date.now()) < 5000);
  assert.equal((await syncPut(token, [syncHost(token.device_id, error.server_time)])).status, 200);
});

test('ISSUE-252 D expired tombstones are collected stale replay rejected and batches bounded', async () => {
  await db.prepare('DELETE FROM sync_records').run();
  const { token } = await enroll();
  const cutoff = Date.now() - 31 * 24 * 60 * 60 * 1000;
  const dead = { kind: 'host', id: '0', updated_at: cutoff, device_id: token.device_id, deleted: true };
  await db.prepare('INSERT INTO sync_records VALUES (?,?,?,?,?,?)').bind('owner@example.com', dead.kind, dead.id, dead.updated_at, dead.device_id, JSON.stringify(dead)).run();
  assert.deepEqual(await syncGet(token), []);
  const stale = await syncPut(token, [syncHost(token.device_id, cutoff)]);
  assert.equal(stale.status, 409);
  assert.equal((await stale.json()).error, 'record_expired');
  const oversized = Array.from({ length: 17 }, (_, i) => ({ kind: 'workspace', id: 'Work' + i, updated_at: Date.now(), device_id: token.device_id, deleted: false, workspace: { name: 'Work' + i } }));
  const result = await syncPut(token, oversized);
  assert.equal(result.status, 413);
  assert.equal((await result.json()).error, 'record_batch_limit');
  assert.deepEqual(await syncGet(token), []);
});

test('ISSUE-252 D full account returns capacity error instead of dropping records', async () => {
  await db.prepare('DELETE FROM sync_records').run();
  const { token } = await enroll();
  await db.prepare("WITH RECURSIVE n(x) AS (SELECT 0 UNION ALL SELECT x+1 FROM n WHERE x<4095) INSERT INTO sync_records (account,kind,id,updated_at,device_id,document) SELECT ?, 'workspace', 'Full'||x, ?, ?, json_object('kind','workspace','id','Full'||x,'updated_at',?,'device_id',?,'deleted',json('false'),'workspace',json_object('name','Full'||x)) FROM n").bind('owner@example.com', Date.now(), token.device_id, Date.now(), token.device_id).run();
  const result = await syncPut(token, [syncHost(token.device_id, Date.now())]);
  assert.equal(result.status, 409);
  assert.equal((await result.json()).error, 'record_capacity');
  assert.equal((await db.prepare('SELECT count(*) AS n FROM sync_records WHERE account=?').bind('owner@example.com').first()).n, 4096);
  await db.prepare('DELETE FROM sync_records').run();
});

test('ISSUE-252 E activity preserves concurrent session metadata through the real endpoint', async () => {
  await db.prepare('DELETE FROM sync_records').run();
  const { token: first } = await enroll(), { token: second } = await enroll();
  const now = Date.now() - 1000;
  const stamp = (updated_at, device_id) => ({ updated_at, device_id });
  const base = { kind: 'session', id: '0:one', updated_at: now, device_id: first.device_id, deleted: false, session: { kind: 'tmux', name: 'Old', favorite: false, tmux_session: 'one', tmux_host: 0, workspace: 'Work', used: 10, input: 10, visits: [1] } };
  const renamed = { ...base, updated_at: now + 100, fields: { name: stamp(now + 100, first.device_id), manual: stamp(now, first.device_id), favorite: stamp(now + 100, first.device_id), workspace: stamp(now, first.device_id) }, session: { ...base.session, name: 'Renamed', favorite: true } };
  const active = { ...base, updated_at: now + 200, device_id: second.device_id, fields: Object.fromEntries(['name', 'manual', 'favorite', 'workspace'].map(key => [key, stamp(now, first.device_id)])), session: { ...base.session, used: 300, input: 400, visits: [2] } };
  for (const order of [[renamed, active], [active, renamed]]) {
    await db.prepare('DELETE FROM sync_records').run();
    for (const record of order) assert.equal((await syncPut(record.device_id === first.device_id ? first : second, [record])).status, 200);
    const [record] = await syncGet(first);
    assert.equal(record.session.name, 'Renamed');
    assert.equal(record.session.favorite, true);
    assert.equal(record.session.used, 300);
    assert.equal(record.session.input, 400);
    assert.deepEqual(record.session.visits, [1, 2]);
  }
});
