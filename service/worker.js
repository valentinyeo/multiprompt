const now = () => Math.floor(Date.now() / 1000);
const b64 = bytes => btoa(String.fromCharCode(...new Uint8Array(bytes))).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
const random = () => b64(crypto.getRandomValues(new Uint8Array(32)));
export const hash = async text => b64(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text)));
const json = (value, status = 200) => new Response(JSON.stringify(value), { status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer' } });
const fail = (status, error) => { throw Object.assign(new Error(error), { status }); };
const decode = text => Uint8Array.from(atob(text.replaceAll('-', '+').replaceAll('_', '/')), c => c.charCodeAt(0));

export async function identity(request, env) {
  const account = env.ACCOUNT_EMAIL;
  if (typeof account !== 'string' || !account || !env.ACCESS_TEAM || !env.ACCESS_AUD) fail(401, 'access_required');
  const jwt = request.headers.get('Cf-Access-Jwt-Assertion') || '';
  try {
    const [h, p, s, extra] = jwt.split('.');
    if (extra || !s) fail(401, 'access_required');
    const header = JSON.parse(new TextDecoder().decode(decode(h)));
    const claims = JSON.parse(new TextDecoder().decode(decode(p)));
    if (header.alg !== 'RS256' || claims.iss !== `https://${env.ACCESS_TEAM}` ||
        !Array.isArray(claims.aud) || !claims.aud.includes(env.ACCESS_AUD) ||
        claims.exp <= now() || !Number.isFinite(claims.exp) || claims.nbf > now() || claims.email !== account) fail(401, 'access_required');
    const certs = await fetch(`https://${env.ACCESS_TEAM}/cdn-cgi/access/certs`);
    if (!certs.ok) fail(503, 'access_unavailable');
    const jwk = (await certs.json()).keys.find(k => k.kid === header.kid);
    if (!jwk) fail(401, 'access_required');
    const key = await crypto.subtle.importKey('jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
    if (!await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, decode(s), new TextEncoder().encode(`${h}.${p}`))) fail(401, 'access_required');
    return account;
  } catch (e) { if (e.status === 503) throw e; fail(401, 'access_required'); }
}

export function validateLayout(x) {
  const keys = (v, expected) => v && typeof v === 'object' && !Array.isArray(v) && Object.keys(v).sort().join(',') === expected.sort().join(',');
  const text = (v, n) => typeof v === 'string' && v.length > 0 && v.length <= n && !/[\x00-\x1f\x7f]|[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/u.test(v);
  if (!keys(x, ['schema', 'revision', 'workspaces', 'tabs']) || x.schema !== 1 || !Number.isSafeInteger(x.revision) || x.revision < 0 ||
      !Array.isArray(x.workspaces) || x.workspaces.length > 9 || !Array.isArray(x.tabs) || x.tabs.length > 256) fail(400, 'invalid_layout');
  const ws = new Set(), ids = new Set();
  for (const w of x.workspaces) {
    if (!keys(w, ['name']) || !text(w.name, 32) || new TextEncoder().encode(w.name).length > 31 || ws.has(w.name)) fail(400, 'invalid_workspace');
    ws.add(w.name);
  }
  for (const t of x.tabs) {
    const id = `${t?.tmux_host}:${String(t?.tmux_session).toLowerCase()}`;
    if (!(keys(t, ['kind', 'name', 'tmux_session', 'tmux_host', 'workspace']) ||
          keys(t, ['kind', 'name', 'tmux_session', 'tmux_host', 'workspace', 'manual']) && typeof t.manual === 'boolean') || t.kind !== 'tmux' || !text(t.name, 64) ||
        !Number.isInteger(t.tmux_host) || t.tmux_host < 0 || t.tmux_host > 2 || typeof t.tmux_session !== 'string' || !/^[A-Za-z0-9_-]{1,63}$/.test(t.tmux_session) || !ws.has(t.workspace) || ids.has(id)) fail(400, 'invalid_tab');
    ids.add(id);
  }
  return x;
}

async function body(request) {
  if (Number(request.headers.get('Content-Length')) > 1024 * 1024) fail(413, 'too_large');
  const reader = request.body?.getReader();
  if (!reader) fail(400, 'invalid_json');
  let size = 0; const chunks = [];
  while (true) {
    const { value, done } = await reader.read(); if (done) break;
    size += value.length; if (size > 1024 * 1024) { await reader.cancel(); fail(413, 'too_large'); }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size); let pos = 0;
  for (const chunk of chunks) { bytes.set(chunk, pos); pos += chunk.length; }
  try { return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes)); } catch { fail(400, 'invalid_json'); }
}
async function authenticate(request, db) {
  const token = request.headers.get('Authorization')?.match(/^Bearer ([A-Za-z0-9_-]{43})$/)?.[1];
  if (!token) fail(401, 'device_required');
  const device = await db.prepare('SELECT d.* FROM devices d JOIN access_tokens a ON a.device=d.id WHERE a.hash=? AND a.expires>? AND d.revoked=0').bind(await hash(token), now()).first();
  if (!device) fail(401, 'device_required');
  await db.prepare('UPDATE devices SET last_seen=? WHERE id=?').bind(now(), device.id).run();
  return device;
}
async function tokens(db, device, refresh) {
  const access = random();
  await db.batch([db.prepare('DELETE FROM access_tokens WHERE expires<=?').bind(now()), db.prepare('INSERT INTO access_tokens VALUES (?,?,?)').bind(await hash(access), device.id, now() + 600)]);
  return json({ access_token: access, token_type: 'Bearer', expires_in: 600, refresh_token: refresh, account_id: device.account, device_id: device.id });
}

export function validRedirect(redirect) {
  if (redirect === 'dev.multiprompt.companion://auth/callback' || redirect === 'dev.multiprompt.companion.debug://auth/callback') return true;
  return /^http:\/\/127\.0\.0\.1:[1-9][0-9]{0,4}\/callback$/.test(redirect || '') && Number(redirect.split(':')[2].split('/')[0]) <= 65535;
}

export default {
  async fetch(request, env) {
    try {
      const url = new URL(request.url), db = env.DB;
      if (url.pathname === '/health' && request.method === 'GET') return json({ service: 'multiprompt-account', schema: 1 });
      if (url.pathname === '/login' && request.method === 'GET') {
        const email = await identity(request, env);
        const redirect = url.searchParams.get('redirect_uri'), state = url.searchParams.get('state'), challenge = url.searchParams.get('code_challenge');
        const name = url.searchParams.get('device_name') || 'Windows desktop';
        if (!validRedirect(redirect) ||
            !/^[A-Za-z0-9_-]{43}$/.test(state || '') || !/^[A-Za-z0-9_-]{43}$/.test(challenge || '') || url.searchParams.get('code_challenge_method') !== 'S256' || name.length > 80 || /[\x00-\x1f]/.test(name)) fail(400, 'invalid_authorization');
        const code = random();
        await db.batch([
          db.prepare('DELETE FROM codes WHERE expires<=?').bind(now()),
          db.prepare('DELETE FROM access_tokens WHERE expires<=?').bind(now()),
          db.prepare('INSERT INTO codes VALUES (?,?,?,?,?,?)').bind(await hash(code), email, challenge, redirect, name, now() + 120)
        ]);
        const target = new URL(redirect); target.searchParams.set('code', code); target.searchParams.set('state', state);
        return new Response(null, { status: 302, headers: { Location: target.href, 'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer' } });
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
      const device = await authenticate(request, db);
      if (url.pathname === '/v1/devices' && request.method === 'GET') {
        const result = await db.prepare('SELECT id,name,created,last_seen,revoked FROM devices WHERE account=? ORDER BY created,id').bind(device.account).all();
        return json({ device_id: device.id, devices: result.results });
      }
      if (url.pathname.startsWith('/v1/devices/') && request.method === 'DELETE') {
        const result = await db.prepare('UPDATE devices SET revoked=1 WHERE id=? AND account=?').bind(url.pathname.slice('/v1/devices/'.length), device.account).run();
        return result.meta.changes ? json({ revoked: true }) : json({ error: 'not_found' }, 404);
      }
      if (url.pathname === '/v1/layout' && request.method === 'GET') {
        const row = await db.prepare('SELECT revision,layout FROM layouts WHERE account=?').bind(device.account).first();
        if (!row) fail(503, 'layout_not_seeded');
        return json({ revision: row.revision, layout: JSON.parse(row.layout) });
      }
      if (url.pathname === '/v1/layout' && request.method === 'PUT') {
        const b = await body(request), layout = validateLayout(b.layout);
        if (!Number.isSafeInteger(b.base_revision) || b.base_revision < 0) fail(400, 'invalid_revision');
        layout.revision = b.base_revision + 1;
        const result = await db.prepare('UPDATE layouts SET revision=revision+1,layout=? WHERE account=? AND revision=?').bind(JSON.stringify(layout), device.account, b.base_revision).run();
        if (!result.meta.changes) {
          const row = await db.prepare('SELECT revision,layout FROM layouts WHERE account=?').bind(device.account).first();
          return row ? json({ revision: row.revision, layout: JSON.parse(row.layout) }, 409) : json({ error: 'layout_not_seeded' }, 503);
        }
        return json({ revision: layout.revision, layout });
      }
      return json({ error: 'not_found' }, 404);
    } catch (e) {
      return json({ error: e.status ? e.message : 'service_unavailable' }, e.status || 503);
    }
  }
};
