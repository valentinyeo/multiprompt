import { makeAuth, isAllowed, origins, mailConfigured, googleConfigured } from './auth.js';
import { appPage, confirmPage } from './pages.js';

const now = () => Math.floor(Date.now() / 1000);
const b64 = bytes => btoa(String.fromCharCode(...new Uint8Array(bytes))).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
const random = () => b64(crypto.getRandomValues(new Uint8Array(32)));
export const hash = async text => b64(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text)));
const json = (value, status = 200) => new Response(JSON.stringify(value), { status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer' } });
const fail = (status, error) => { throw Object.assign(new Error(error), { status }); };
const layoutFeature = (request, token) => (request.headers.get('X-Layout-Features') || '').split(',').some(feature => feature.trim() === token);
function layoutResponse(request, value, status = 200) {
  if (value.layout) value = { ...value, layout: { ...value.layout, tabs: value.layout.tabs.map(tab => {
    const visible = { ...tab };
    if (!layoutFeature(request, 'favorite')) delete visible.favorite;
    if (!layoutFeature(request, 'muted')) delete visible.muted;
    if (!layoutFeature(request, 'used')) delete visible.used;
    if (!layoutFeature(request, 'visits')) delete visible.visits;
    if (!layoutFeature(request, 'input')) delete visible.input;
    return visible;
  }) } };
  if (value.layout && !layoutFeature(request, 'workspace_color')) value.layout.workspaces = value.layout.workspaces.map(({ color, ...workspace }) => workspace);
  if (value.layout && !layoutFeature(request, 'settings')) delete value.layout.settings;
  if (value.layout && !layoutFeature(request, 'hosts')) delete value.layout.hosts;
  if (value.layout && !layoutFeature(request, 'host_removal')) delete value.layout.removed_hosts;
  const response = json(value, status);
  response.headers.set('X-Layout-Features', 'favorite,muted,used,visits,input,settings,hosts,host_removal,workspace_color');
  return response;
}
export function validateLayout(x) {
  const keys = (v, expected) => v && typeof v === 'object' && !Array.isArray(v) && Object.keys(v).sort().join(',') === expected.sort().join(',');
  const text = (v, n) => typeof v === 'string' && v.length > 0 && v.length <= n && !/[\x00-\x1f\x7f]|[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/u.test(v);
  if (!keys(x, ['schema', 'revision', 'workspaces', 'tabs', ...['settings', 'hosts', 'removed_hosts'].filter(key => Object.hasOwn(x || {}, key))]) || x.schema !== 1 || !Number.isSafeInteger(x.revision) || x.revision < 0 ||
      !Array.isArray(x.workspaces) || x.workspaces.length > 9 || !Array.isArray(x.tabs) || x.tabs.length > 256) fail(400, 'invalid_layout');
  if (Object.hasOwn(x, 'settings') && (!x.settings || typeof x.settings !== 'object' || Array.isArray(x.settings) || Object.entries(x.settings).some(([key, value]) => !['frequent', 'favorites', 'all', 'frequent_first'].includes(key) || typeof value !== 'boolean'))) fail(400, 'invalid_layout');
  if (Object.hasOwn(x, 'removed_hosts') && (!Array.isArray(x.removed_hosts) || x.removed_hosts.length > 3 || new Set(x.removed_hosts).size !== x.removed_hosts.length || x.removed_hosts.some(slot => !Number.isInteger(slot) || slot < 0 || slot > 2))) fail(400, 'invalid_hosts');
  if (Object.hasOwn(x, 'hosts')) {
    const slots = new Set();
    if (!Array.isArray(x.hosts) || x.hosts.length > 3 || JSON.stringify(x.hosts).includes('PRIVATE KEY')) fail(400, 'invalid_hosts');
    for (const h of x.hosts) {
      if (!keys(h, ['slot', 'name', 'hostname', 'port', 'user', ...(Object.hasOwn(h || {}, 'host_keys') ? ['host_keys'] : [])]) ||
          !Number.isInteger(h.slot) || h.slot < 0 || h.slot > 2 || slots.has(h.slot) || !text(h.name, 32) || /[\u0080-\u009f]/u.test(h.name) ||
          !text(h.hostname, 253) || !/^(?:[A-Za-z0-9.-]{1,253}|[0-9A-Fa-f:]{2,45})$/.test(h.hostname) ||
          !Number.isInteger(h.port) || h.port < 1 || h.port > 65535 || !text(h.user, 32) || !/^[A-Za-z_][A-Za-z0-9_.-]{0,31}$/.test(h.user) ||
          (Object.hasOwn(h, 'host_keys') && (!Array.isArray(h.host_keys) || h.host_keys.length > 4 || new Set(h.host_keys).size !== h.host_keys.length ||
            h.host_keys.some(key => !text(key, 1024) || !/^(ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|ssh-rsa) [A-Za-z0-9+/]+={0,2}$/.test(key))))) fail(400, 'invalid_hosts');
      slots.add(h.slot);
    }
  }
  const ws = new Set(), ids = new Set();
  for (const w of x.workspaces) {
    if (!keys(w, ['name', ...(Object.hasOwn(w || {}, 'color') ? ['color'] : [])]) || (Object.hasOwn(w, 'color') && (!Number.isInteger(w.color) || w.color < 0 || w.color >= 7)) || !text(w.name, 32) || new TextEncoder().encode(w.name).length > 31 || ws.has(w.name)) fail(400, 'invalid_workspace');
    ws.add(w.name);
  }
  for (const t of x.tabs) {
    const id = `${t?.tmux_host}:${String(t?.tmux_session).toLowerCase()}`;
    const optional = ['manual', 'favorite', 'muted', 'used', 'visits', 'input'].filter(key => Object.hasOwn(t || {}, key));
    if (!keys(t, ['kind', 'name', 'tmux_session', 'tmux_host', 'workspace', ...optional]) || optional.some(key => key === 'visits' ? !Array.isArray(t.visits) || t.visits.length > 8 || t.visits.some((v, i) => !Number.isSafeInteger(v) || v < 0 || (i > 0 && v <= t.visits[i - 1])) : (key === 'used' || key === 'input') ? !Number.isSafeInteger(t[key]) || t[key] < 0 : typeof t[key] !== 'boolean') || t.kind !== 'tmux' || !text(t.name, 64) ||
        !Number.isInteger(t.tmux_host) || t.tmux_host < 0 || t.tmux_host > 2 || typeof t.tmux_session !== 'string' || !/^[A-Za-z0-9_-]{1,63}$/.test(t.tmux_session) || !ws.has(t.workspace) || ids.has(id)) fail(400, 'invalid_tab');
    ids.add(id);
  }
  return x;
}

function validateCrashReport(x) {
  const fields = ['id', 'captured_at', 'app_version', 'android_version', 'thread', 'summary', 'stack_trace'];
  const limits = { app_version: 64, android_version: 64, thread: 200, summary: 2000, stack_trace: 16000 };
  if (!x || typeof x !== 'object' || Array.isArray(x) || Object.keys(x).length !== fields.length || Object.keys(x).some(key => !fields.includes(key)) ||
      typeof x.id !== 'string' || !/^[A-Za-z0-9-]{8,64}$/.test(x.id) || !Number.isSafeInteger(x.captured_at) ||
      Object.entries(limits).some(([key, limit]) => typeof x[key] !== 'string' || x[key].length > limit) || !x.stack_trace.length) fail(400, 'invalid_crash_report');
  return x;
}

async function body(request, limit = 1024 * 1024, invalid = 'invalid_json') {
  if (Number(request.headers.get('Content-Length')) > limit) fail(413, 'too_large');
  const reader = request.body?.getReader();
  if (!reader) fail(400, invalid);
  let size = 0; const chunks = [];
  while (true) {
    const { value, done } = await reader.read(); if (done) break;
    size += value.length; if (size > limit) { await reader.cancel(); fail(413, 'too_large'); }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size); let pos = 0;
  for (const chunk of chunks) { bytes.set(chunk, pos); pos += chunk.length; }
  try { return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes)); } catch { fail(400, invalid); }
}
async function authenticate(request, db) {
  const token = request.headers.get('Authorization')?.match(/^Bearer ([A-Za-z0-9_-]{43})$/)?.[1];
  if (!token) fail(401, 'device_required');
  const device = await db.prepare('SELECT d.* FROM devices d JOIN access_tokens a ON a.device=d.id WHERE a.hash=? AND a.expires>? AND d.revoked=0').bind(await hash(token), now()).first();
  if (!device) fail(401, 'device_required');
  await db.prepare('UPDATE devices SET last_seen=? WHERE id=?').bind(now(), device.id).run();
  return device;
}
async function authenticateKey(db, key, pathname) {
  const keyHash = await hash(key);
  const row = await db.prepare('SELECT hash,account,kind,workspace FROM service_keys WHERE hash=? AND revoked=0').bind(keyHash).first();
  if (!row || row.kind !== (key[4] === 'a' ? 'admin' : 'workspace')) fail(401, 'device_required');
  if (pathname !== '/v1/layout') fail(403, 'key_scope');
  await db.prepare('UPDATE service_keys SET last_used=? WHERE hash=?').bind(now(), keyHash).run();
  return { id: null, account: row.account, keyHash, kind: row.kind, workspace: row.workspace };
}
function scoped(device, layout) {
  if (device.kind !== 'workspace') return layout;
  if (!layout.workspaces.some(w => w.name === device.workspace)) fail(404, 'workspace_not_found');
  return { schema: 1, revision: layout.revision, workspaces: [layout.workspaces.find(w => w.name === device.workspace)], tabs: layout.tabs.filter(tab => tab.workspace === device.workspace) };
}
function confine(device, layout, previous) {
  if (!previous) fail(503, 'layout_not_seeded');
  const name = device.workspace;
  if (!previous.workspaces.some(w => w.name === name)) fail(404, 'workspace_not_found');
  if (layout.workspaces.length !== 1 || layout.workspaces[0].name !== name || layout.tabs.some(tab => tab.workspace !== name)) fail(403, 'scope_denied');
  const id = tab => `${tab.tmux_host}:${tab.tmux_session.toLowerCase()}`;
  const outside = new Set(previous.tabs.filter(tab => tab.workspace !== name).map(id));
  if (layout.tabs.some(tab => outside.has(id(tab)))) fail(403, 'scope_denied');
  const tabs = []; let placed = false;
  for (const tab of previous.tabs) {
    if (tab.workspace !== name) tabs.push(tab);
    else if (!placed) { tabs.push(...layout.tabs); placed = true; }
  }
  if (!placed) tabs.push(...layout.tabs);
  return validateLayout({ ...previous, revision: layout.revision, workspaces: previous.workspaces.map(w => w.name === name ? layout.workspaces[0] : w), tabs });
}
async function sessionAccount(request, env, auth) {
  if (!env.BETTER_AUTH_SECRET || !(request.headers.get('Cookie') || '').includes('session_token')) return null;
  const session = await auth().api.getSession({ headers: request.headers }).catch(() => null);
  const email = session?.user?.email?.toLowerCase();
  return email && isAllowed(env, email) ? email : null;
}
function sameOrigin(request, env) {
  const origin = request.headers.get('Origin');
  if (!origin || !origins(env).includes(origin) || origin !== new URL(request.url).origin) fail(403, 'cross_origin');
}
async function tokens(db, device, refresh) {
  const access = random();
  await db.batch([db.prepare('DELETE FROM access_tokens WHERE expires<=?').bind(now()), db.prepare('INSERT INTO access_tokens VALUES (?,?,?)').bind(await hash(access), device.id, now() + 600)]);
  return json({ access_token: access, token_type: 'Bearer', expires_in: 600, refresh_token: refresh, account_id: device.account, device_id: device.id });
}

export function validRedirect(redirect) {
  if (redirect === 'dev.multiprompt.companion://auth/callback' || redirect === 'dev.multiprompt.companion.debug://auth/callback' || redirect === 'dev.multiprompt.companion.m3://auth/callback') return true;
  return /^http:\/\/127\.0\.0\.1:[1-9][0-9]{0,4}\/callback$/.test(redirect || '') && Number(redirect.split(':')[2].split('/')[0]) <= 65535;
}

function authorization(url) {
  const redirect = url.searchParams.get('redirect_uri'), state = url.searchParams.get('state'), challenge = url.searchParams.get('code_challenge');
  const name = url.searchParams.get('device_name') || 'Windows desktop';
  if (!validRedirect(redirect) ||
      !/^[A-Za-z0-9_-]{43}$/.test(state || '') || !/^[A-Za-z0-9_-]{43}$/.test(challenge || '') || url.searchParams.get('code_challenge_method') !== 'S256' || name.length > 80 || /[\x00-\x1f]/.test(name)) fail(400, 'invalid_authorization');
  return { redirect, state, challenge, name };
}
async function issue(db, email, { redirect, state, challenge, name }, status = 302) {
  const code = random();
  await db.batch([
    db.prepare('DELETE FROM codes WHERE expires<=?').bind(now()),
    db.prepare('DELETE FROM access_tokens WHERE expires<=?').bind(now()),
    db.prepare('INSERT INTO codes VALUES (?,?,?,?,?,?)').bind(await hash(code), email, challenge, redirect, name, now() + 120)
  ]);
  const target = new URL(redirect); target.searchParams.set('code', code); target.searchParams.set('state', state);
  return redirectTo(target.href, status);
}
const redirectTo = (location, status = 302) => new Response(null, { status, headers: { Location: location, 'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer' } });
const html = (text, status = 200) => new Response(text, { status, headers: {
  'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store', 'Referrer-Policy': 'same-origin', 'X-Frame-Options': 'DENY',
  'Content-Security-Policy': "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; connect-src 'self'; form-action 'self' http://127.0.0.1:* dev.multiprompt.companion: dev.multiprompt.companion.debug: dev.multiprompt.companion.m3:; frame-ancestors 'none'; base-uri 'none'"
} });
export function safeNext(next) {
  return next === '/?passkey=add' || typeof next === 'string' && /^\/(login|authorize)\?[^\\#]*$/.test(next) && !next.startsWith('//') ? next : null;
}
export function validateUsage(x) {
  const obj = v => v && typeof v === 'object' && !Array.isArray(v);
  const window = w => w === null || w === undefined || obj(w);
  if (!obj(x) || !Array.isArray(x.accounts) || x.accounts.length > 64 || !(typeof x.ts === 'string' || typeof x.ts === 'number')) fail(400, 'invalid_usage');
  for (const a of x.accounts) if (!obj(a) || typeof a.id !== 'string' || a.id.length > 128 || !window(a.week) || !window(a.five_hour)) fail(400, 'invalid_usage');
  return x;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const reply = (value, status) => url.pathname === '/v1/layout' ? layoutResponse(request, value, status) : json(value, status);
    try {
      const db = env.DB;
      let instance;
      const auth = () => instance ||= makeAuth(env, url.origin);
      if (url.pathname === '/health' && request.method === 'GET') return json({ service: 'multiprompt-account', schema: 1 });
      if (url.pathname === '/login' || url.pathname === '/authorize') {
        const params = authorization(url);
        const email = await sessionAccount(request, env, auth);
        if (request.method === 'GET') {
          if (!email) return redirectTo('/signin?next=' + encodeURIComponent(url.pathname + url.search));
          return html(confirmPage(email, params.name, params.redirect));
        }
        if (request.method === 'POST') {
          sameOrigin(request, env);
          if (!email) fail(401, 'session_required');
          return issue(db, email, params, 303);
        }
        fail(405, 'method_not_allowed');
      }
      if (url.pathname.startsWith('/api/auth/')) {
        if (!env.BETTER_AUTH_SECRET) fail(503, 'auth_not_configured');
        return auth().handler(request);
      }
      if ((url.pathname === '/' || url.pathname === '/signin') && request.method === 'GET') {
        const email = await sessionAccount(request, env, auth);
        const next = safeNext(url.searchParams.get('next'));
        const fresh = url.pathname === '/signin' && url.searchParams.get('fresh') === '1';
        if (email && next && !fresh) return redirectTo(next);
        return html(appPage(email && !fresh ? 'dash' : 'signin', { email, next, google: googleConfigured(env), mail: mailConfigured(env) }));
      }
      if (url.pathname === '/v1/usage' && request.method === 'PUT') {
        const supplied = request.headers.get('Authorization')?.match(/^Bearer ([A-Za-z0-9_-]{32,128})$/)?.[1];
        if (!env.USAGE_PUSH_TOKEN || !supplied || await hash(supplied) !== await hash(env.USAGE_PUSH_TOKEN)) fail(401, 'service_token_required');
        const status = validateUsage(await body(request, 256 * 1024));
        await db.prepare('INSERT INTO usage (account,updated,status) VALUES (?,?,?) ON CONFLICT(account) DO UPDATE SET updated=excluded.updated,status=excluded.status').bind(env.USAGE_ACCOUNT || env.ACCOUNT_EMAIL, now(), JSON.stringify(status)).run();
        return json({ stored: true });
      }
      if (url.pathname === '/oauth/token' && request.method === 'POST') {
        const b = await body(request);
        if (b.grant_type === 'authorization_code') {
          if (!/^[A-Za-z0-9_-]{43,128}$/.test(b.code_verifier || '') || !/^[A-Za-z0-9_-]{43}$/.test(b.code || '')) fail(400, 'invalid_grant');
          const row = await db.prepare('DELETE FROM codes WHERE hash=? AND challenge=? AND redirect=? AND expires>? RETURNING *').bind(await hash(b.code), await hash(b.code_verifier), b.redirect_uri || '', now()).first();
          if (!row) fail(400, 'invalid_grant');
          const refresh = random(), device = { id: crypto.randomUUID(), account: row.account };
          await db.prepare('INSERT INTO devices (id,account,name,refresh_hash,created,last_seen) VALUES (?,?,?,?,?,?)').bind(device.id, device.account, row.name, await hash(refresh), now(), now()).run();
          return tokens(db, device, refresh);
        }
        if (b.grant_type === 'refresh_token') {
          if (!/^[A-Za-z0-9_-]{43}$/.test(b.refresh_token || '')) fail(400, 'invalid_grant');
          const refresh = random();
          const supplied = await hash(b.refresh_token), timestamp = now();
          const match = 'revoked=0 AND (refresh_hash=? OR id IN (SELECT device FROM refresh_grace WHERE hash=? AND expires>?))';
          const result = await db.batch([
            db.prepare('DELETE FROM refresh_grace WHERE expires<=?').bind(timestamp),
            db.prepare('INSERT OR IGNORE INTO refresh_grace SELECT refresh_hash,id,? FROM devices WHERE ' + match).bind(timestamp + 600, supplied, supplied, timestamp),
            db.prepare('UPDATE devices SET refresh_hash=?,last_seen=? WHERE ' + match + ' RETURNING *').bind(await hash(refresh), timestamp, supplied, supplied, timestamp)
          ]);
          const device = result[2].results[0];
          if (!device) fail(400, 'invalid_grant');
          return tokens(db, device, refresh);
        }
        fail(400, 'unsupported_grant');
      }
      if (!url.pathname.startsWith('/v1/')) return json({ error: 'not_found' }, 404);
      const keyRoute = url.pathname === '/v1/device-key' || url.pathname === '/v1/device-keys' || /^\/v1\/device-keys\/[^/]+\/(approve|deny)$/.test(url.pathname);
      const sessionEmail = keyRoute || request.headers.get('Authorization') ? null : await sessionAccount(request, env, auth);
      const serviceKey = request.headers.get('Authorization')?.match(/^Bearer (mpk_[aw]_[A-Za-z0-9_-]{43})$/)?.[1];
      const device = serviceKey ? await authenticateKey(db, serviceKey, url.pathname) : sessionEmail ? { id: null, account: sessionEmail } : await authenticate(request, db);
      if (sessionEmail && request.method !== 'GET') {
        sameOrigin(request, env);
        if (request.headers.get('X-Multiprompt') !== 'dash' || !(url.pathname.startsWith('/v1/devices/') && request.method === 'DELETE')) fail(403, 'cross_origin');
      }
      if (url.pathname === '/v1/me' && request.method === 'GET') return json({ account: device.account, device_id: device.id });
      if (url.pathname === '/v1/usage' && request.method === 'GET') {
        const row = await db.prepare('SELECT updated,status FROM usage WHERE account=?').bind(device.account).first();
        return row ? json({ updated: row.updated, status: JSON.parse(row.status) }) : json({ error: 'no_usage' }, 404);
      }
      if (url.pathname === '/v1/device-key' && request.method === 'PUT') {
        const b = await body(request, 1024 * 1024, 'invalid_key');
        if (!b || typeof b !== 'object' || Array.isArray(b) || Object.keys(b).length !== 1 || typeof b.public_key !== 'string' || b.public_key.length > 200 ||
            !/^ssh-ed25519 [A-Za-z0-9+/]+={0,2}$/.test(b.public_key) || /\s$/.test(b.public_key)) fail(400, 'invalid_key');
        const encoded = b.public_key.slice(12);
        let decoded;
        try { decoded = atob(encoded); } catch { fail(400, 'invalid_key'); }
        if (btoa(decoded) !== encoded || decoded.length !== 51 || decoded.slice(0, 19) !== '\x00\x00\x00\x0bssh-ed25519\x00\x00\x00\x20') fail(400, 'invalid_key');
        const result = await db.batch([
          db.prepare("INSERT INTO device_keys (device_id,account,public_key,status,requested) SELECT ?,?,?,'pending',? WHERE EXISTS (SELECT 1 FROM devices WHERE id=? AND account=? AND revoked=0) ON CONFLICT(device_id) DO NOTHING").bind(device.id, device.account, b.public_key, now(), device.id, device.account),
          db.prepare('SELECT k.status,k.public_key FROM device_keys k JOIN devices d ON d.id=k.device_id WHERE k.device_id=? AND k.account=? AND d.account=k.account AND d.revoked=0').bind(device.id, device.account)
        ]);
        if (!result[1].results.length) fail(401, 'device_required');
        const key = result[1].results[0];
        if (key.status !== 'revoked' && key.public_key !== b.public_key) fail(409, 'key_locked');
        return json({ status: key.status });
      }
      if (url.pathname === '/v1/device-keys' && request.method === 'GET') {
        const result = await db.prepare('SELECT k.device_id,d.name,k.public_key,k.status,k.requested,k.decided FROM device_keys k JOIN devices d ON d.id=k.device_id WHERE k.account=? ORDER BY k.requested,k.device_id').bind(device.account).all();
        return json({ device_id: device.id, keys: result.results });
      }
      const decision = url.pathname.match(/^\/v1\/device-keys\/([^/]+)\/(approve|deny)$/);
      if (decision && request.method === 'POST') {
        const row = await db.prepare('SELECT device_id FROM device_keys WHERE device_id=? AND account=?').bind(decision[1], device.account).first();
        if (!row) fail(404, 'not_found');
        if (row.device_id === device.id) fail(403, 'self_approval');
        const status = decision[2] === 'approve' ? 'approved' : 'denied';
        const result = await db.prepare("UPDATE device_keys SET status=?,decided=?,decided_by=? WHERE device_id=? AND account=? AND status='pending' AND EXISTS (SELECT 1 FROM devices WHERE id=? AND account=? AND revoked=0) AND EXISTS (SELECT 1 FROM devices WHERE id=device_keys.device_id AND account=device_keys.account AND revoked=0)").bind(status, now(), device.id, row.device_id, device.account, device.id, device.account).run();
        if (!result.meta.changes) {
          if (!await db.prepare('SELECT id FROM devices WHERE id=? AND account=? AND revoked=0').bind(device.id, device.account).first()) fail(401, 'device_required');
          fail(409, 'not_pending');
        }
        return json({ status });
      }
      if (url.pathname === '/v1/devices' && request.method === 'GET') {
        const result = await db.prepare('SELECT id,name,created,last_seen,revoked FROM devices WHERE account=? ORDER BY created,id').bind(device.account).all();
        return json({ device_id: device.id, devices: result.results });
      }
      if (url.pathname.startsWith('/v1/devices/') && request.method === 'DELETE') {
        const id = url.pathname.slice('/v1/devices/'.length);
        const result = await db.batch([
          db.prepare('UPDATE devices SET revoked=1 WHERE id=? AND account=?').bind(id, device.account),
          db.prepare("UPDATE device_keys SET status='revoked' WHERE device_id IN (SELECT id FROM devices WHERE id=? AND account=?)").bind(id, device.account),
          db.prepare('DELETE FROM crash_reports WHERE device_id IN (SELECT id FROM devices WHERE id=? AND account=?)').bind(id, device.account)
        ]);
        return result[0].meta.changes ? json({ revoked: true }) : json({ error: 'not_found' }, 404);
      }
      if (url.pathname === '/v1/crash-reports' && request.method === 'POST') {
        const b = validateCrashReport(await body(request, 32 * 1024, 'invalid_crash_report'));
        const result = await db.batch([
          db.prepare('INSERT INTO crash_reports (device_id,report_id,account,received_at,captured_at,app_version,android_version,thread,summary,stack_trace) SELECT ?,?,?,?,?,?,?,?,?,? WHERE EXISTS (SELECT 1 FROM devices WHERE id=? AND account=? AND revoked=0) ON CONFLICT(device_id,report_id) DO NOTHING').bind(device.id, b.id, device.account, now(), b.captured_at, b.app_version, b.android_version, b.thread, b.summary, b.stack_trace, device.id, device.account),
          db.prepare('DELETE FROM crash_reports WHERE device_id=? AND rowid IN (SELECT rowid FROM crash_reports WHERE device_id=? ORDER BY received_at DESC,rowid DESC LIMIT -1 OFFSET 50)').bind(device.id, device.id)
        ]);
        if (!result[0].meta.changes && !await db.prepare('SELECT id FROM devices WHERE id=? AND account=? AND revoked=0').bind(device.id, device.account).first()) fail(401, 'device_required');
        return result[0].meta.changes ? json({ stored: true }, 201) : json({ stored: false, duplicate: true });
      }
      if (url.pathname === '/v1/layout' && request.method === 'GET') {
        const row = await db.prepare('SELECT revision,layout FROM layouts WHERE account=?').bind(device.account).first();
        if (!row) fail(503, 'layout_not_seeded');
        return reply({ revision: row.revision, layout: scoped(device, JSON.parse(row.layout)) });
      }
      if (url.pathname === '/v1/layout' && request.method === 'PUT') {
        const b = await body(request);
        let layout = validateLayout(b.layout);
        if (!Number.isSafeInteger(b.base_revision) || b.base_revision < 0) fail(400, 'invalid_revision');
        const row = await db.prepare('SELECT layout FROM layouts WHERE account=?').bind(device.account).first();
        const previousLayout = row ? JSON.parse(row.layout) : null;
        const confined = device.kind === 'workspace';
        if (confined) layout = confine(device, layout, previousLayout);
        const req = confined ? { headers: new Headers({ 'X-Layout-Features': (request.headers.get('X-Layout-Features') || '').split(',').map(feature => feature.trim()).filter(feature => !['settings', 'hosts', 'host_removal'].includes(feature)).join(',') }) } : request;
        if (!layoutFeature(req, 'workspace_color')) {
          const storedWorkspaces = new Map((previousLayout?.workspaces || []).map(workspace => [workspace.name, workspace]));
          for (const workspace of layout.workspaces) {
            const color = storedWorkspaces.get(workspace.name)?.color;
            if (color !== undefined) workspace.color = color;
            else delete workspace.color;
          }
        }
        if (!layoutFeature(req, 'settings')) {
          if (previousLayout?.settings !== undefined) layout.settings = { ...previousLayout.settings };
          else delete layout.settings;
        }
        if (!layoutFeature(req, 'hosts')) {
          if (previousLayout?.hosts !== undefined) layout.hosts = previousLayout.hosts;
          else delete layout.hosts;
        } else if (previousLayout?.hosts !== undefined || layout.hosts !== undefined) {
          const hosts = new Map((previousLayout?.hosts || []).map(host => [host.slot, host]));
          for (const host of layout.hosts || []) {
            const previous = hosts.get(host.slot);
            const keepName = previous?.hostname === host.hostname && host.name === ['Host 1', 'Host 2', 'Remote host 3'][host.slot] && previous.name !== host.name;
            hosts.set(host.slot, keepName ? { ...host, name: previous.name } : host);
          }
          layout.hosts = [...hosts.values()].sort((a, b) => a.slot - b.slot);
        }
        const removed = [...new Set([...(previousLayout?.removed_hosts || []), ...(layoutFeature(req, 'host_removal') ? layout.removed_hosts || [] : [])])].sort((a, b) => a - b);
        if (removed.length) layout.removed_hosts = removed;
        else delete layout.removed_hosts;
        if (layout.hosts) layout.hosts = layout.hosts.filter(host => !removed.includes(host.slot));
        const stored = new Map((previousLayout?.tabs || []).map(tab => [`${tab.tmux_host}:${tab.tmux_session.toLowerCase()}`, tab]));
        for (const tab of layout.tabs) {
          const previous = stored.get(`${tab.tmux_host}:${tab.tmux_session.toLowerCase()}`);
          if (!layoutFeature(req, 'favorite')) {
            if (typeof previous?.favorite === 'boolean') tab.favorite = previous.favorite;
            else delete tab.favorite;
          }
          if (!layoutFeature(req, 'muted')) {
            if (typeof previous?.muted === 'boolean') tab.muted = previous.muted;
            else delete tab.muted;
          }
          if (!layoutFeature(req, 'used')) {
            if (previous?.used !== undefined) tab.used = previous.used;
            else delete tab.used;
          } else if (previous?.used !== undefined) tab.used = Math.max(previous.used, tab.used ?? previous.used);
          if (!layoutFeature(req, 'input')) {
            if (previous?.input !== undefined) tab.input = previous.input;
            else delete tab.input;
          } else if (previous?.input !== undefined) tab.input = Math.max(previous.input, tab.input ?? previous.input);
          if (!layoutFeature(req, 'visits')) {
            if (previous?.visits !== undefined) tab.visits = previous.visits;
            else delete tab.visits;
          } else if (previous?.visits !== undefined || tab.visits !== undefined) {
            tab.visits = [...new Set([...(previous?.visits ?? []), ...(tab.visits ?? [])])].sort((a, b) => a - b).slice(-8);
          }
        }
        layout.revision = b.base_revision + 1;
        const alive = device.keyHash ? ['EXISTS (SELECT 1 FROM service_keys WHERE hash=? AND revoked=0)', [device.keyHash]] : ['EXISTS (SELECT 1 FROM devices WHERE id=? AND account=? AND revoked=0)', [device.id, device.account]];
        const result = await db.prepare('UPDATE layouts SET revision=revision+1,layout=? WHERE account=? AND revision=? AND ' + alive[0]).bind(JSON.stringify(layout), device.account, b.base_revision, ...alive[1]).run();
        if (!result.meta.changes) {
          if (!await db.prepare('SELECT 1 AS ok WHERE ' + alive[0]).bind(...alive[1]).first()) fail(401, 'device_required');
          const row = await db.prepare('SELECT revision,layout FROM layouts WHERE account=?').bind(device.account).first();
          return row ? reply({ revision: row.revision, layout: scoped(device, JSON.parse(row.layout)) }, 409) : reply({ error: 'layout_not_seeded' }, 503);
        }
        return reply({ revision: layout.revision, layout: scoped(device, layout) });
      }
      return reply({ error: 'not_found' }, 404);
    } catch (e) {
      return reply({ error: e.status ? e.message : 'service_unavailable' }, e.status || 503);
    }
  }
};
