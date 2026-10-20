const esc = v => String(v ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

const style = `
:root{--bg:#f4f4f4;--layer:#fff;--text:#161616;--muted:#525252;--border:#e0e0e0;--field:#f4f4f4;--line:#8d8d8d;--primary:#0f62fe;--primary-hover:#0353e9;--danger:#da1e28;--ok:#24a148;--warn:#f1c21b;--head:#161616;--head-text:#f4f4f4;--focus:#0f62fe}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#161616;--layer:#262626;--text:#f4f4f4;--muted:#c6c6c6;--border:#393939;--field:#393939;--line:#6f6f6f;--primary:#0f62fe;--primary-hover:#0353e9;--danger:#fa4d56;--ok:#42be65;--warn:#f1c21b;--head:#000;--head-text:#f4f4f4;--focus:#fff}}
*{box-sizing:border-box}html,body{margin:0}body{background:var(--bg);color:var(--text);font:14px/1.43 "IBM Plex Sans",system-ui,-apple-system,"Segoe UI",sans-serif;letter-spacing:.16px}
header{background:var(--head);color:var(--head-text);height:48px;display:flex;align-items:center;padding:0 16px;gap:16px}
header b{font-weight:600}header .sp{flex:1}header .who{color:#c6c6c6;font-size:13px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
main{max-width:1056px;margin:0 auto;padding:32px 16px 64px}
h1{font-size:28px;font-weight:400;margin:0 0 8px}h2{font-size:20px;font-weight:400;margin:0 0 16px}
p{margin:0 0 16px;color:var(--muted)}
.tile{background:var(--layer);padding:24px;margin-bottom:24px;border:1px solid var(--border)}
.narrow{max-width:416px;margin:48px auto}
label{display:block;font-size:12px;color:var(--muted);margin:0 0 8px}
input{width:100%;height:40px;padding:0 16px;background:var(--field);color:var(--text);border:0;border-bottom:1px solid var(--line);font:inherit;outline:none;margin-bottom:16px}
input:focus{outline:2px solid var(--focus);outline-offset:-2px}
button,.btn{display:inline-flex;align-items:center;justify-content:space-between;min-height:48px;min-width:160px;padding:0 16px;border:0;background:var(--primary);color:#fff;font:inherit;cursor:pointer;text-decoration:none;gap:32px}
button:hover{background:var(--primary-hover)}button:focus-visible,.btn:focus-visible{outline:2px solid var(--focus);outline-offset:-4px;box-shadow:inset 0 0 0 3px var(--layer)}
button.secondary,.btn.secondary{background:#393939}button.secondary:hover{background:#4c4c4c}
button.ghost{background:transparent;color:var(--primary);min-width:0}button.ghost:hover{background:var(--field)}
button.danger{background:var(--danger)}button.small{min-height:32px;min-width:0;padding:0 12px}
button[disabled]{opacity:.5;cursor:not-allowed}
.stack{display:flex;flex-direction:column;gap:8px}.row{display:flex;gap:8px;flex-wrap:wrap}
.or{display:flex;align-items:center;gap:12px;color:var(--muted);font-size:12px;margin:24px 0}.or:before,.or:after{content:"";flex:1;border-top:1px solid var(--border)}
.note{font-size:12px;color:var(--muted);min-height:16px;margin-top:8px}.note.err{color:var(--danger)}
table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:12px 16px;border-bottom:1px solid var(--border);vertical-align:top}
th{font-size:12px;font-weight:600;background:var(--field)}
.tag{display:inline-block;font-size:12px;padding:0 8px;border-radius:12px;line-height:20px;background:var(--field);color:var(--muted)}
.tag.ok{background:#defbe6;color:#0e6027}.tag.bad{background:#fff1f1;color:#a2191f}.tag.blue{background:#d0e2ff;color:#0043ce}
.meter{height:8px;background:var(--field);min-width:96px}.meter i{display:block;height:100%;background:var(--primary)}.meter i.hot{background:var(--danger)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:16px}
.ws h3{font-size:14px;font-weight:600;margin:0 0 8px}.ws ul{margin:0;padding-left:18px;color:var(--muted)}
.scroll{overflow-x:auto}
@media (max-width:600px){main{padding:16px}.narrow{margin:16px auto}button,.btn{width:100%}th,td{padding:8px}}
`;

const shell = (title, body, script = '') => `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)}</title><link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;600&display=swap" rel="stylesheet">
<style>${style}</style></head><body>${body}${script ? `<script>${script}</script>` : ''}</body></html>`;

const common = `
const $ = s => document.querySelector(s);
const note = (el, text, err) => { el.textContent = text || ''; el.className = 'note' + (err ? ' err' : ''); };
async function call(path, opts = {}) {
  const r = await fetch(path, { credentials: 'same-origin', ...opts, headers: { 'Content-Type': 'application/json', ...(opts.headers || {}) } });
  const data = await r.json().catch(() => ({}));
  if (!r.ok) throw Object.assign(new Error(data.message || data.error || ('HTTP ' + r.status)), { status: r.status });
  return data;
}
const b64 = buf => btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\\+/g, '-').replace(/\\//g, '_').replace(/=+$/, '');
const unb64 = s => Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((s.length + 3) % 4)), c => c.charCodeAt(0));
const creds = list => (list || []).map(c => ({ ...c, id: unb64(c.id) }));
async function passkeyCreate(o) {
  const c = await navigator.credentials.create({ publicKey: { ...o, challenge: unb64(o.challenge), user: { ...o.user, id: unb64(o.user.id) }, excludeCredentials: creds(o.excludeCredentials) } });
  return { id: c.id, rawId: b64(c.rawId), type: c.type, authenticatorAttachment: c.authenticatorAttachment || undefined,
    response: { clientDataJSON: b64(c.response.clientDataJSON), attestationObject: b64(c.response.attestationObject), transports: c.response.getTransports ? c.response.getTransports() : [] } };
}
async function passkeyGet(o) {
  const c = await navigator.credentials.get({ publicKey: { ...o, challenge: unb64(o.challenge), allowCredentials: creds(o.allowCredentials) } });
  return { id: c.id, rawId: b64(c.rawId), type: c.type, authenticatorAttachment: c.authenticatorAttachment || undefined,
    response: { clientDataJSON: b64(c.response.clientDataJSON), authenticatorData: b64(c.response.authenticatorData), signature: b64(c.response.signature), userHandle: c.response.userHandle ? b64(c.response.userHandle) : undefined } };
}
`;

function signin({ next, google, mail }) {
  const body = `<header><b>multiprompt</b><span class="sp"></span></header>
<main data-page="signin" data-methods="${['passkey', mail && 'email', google && 'google'].filter(Boolean).join(',')}"><div class="tile narrow">
<h1>Sign in</h1><p>${mail ? 'Use a passkey, or get a sign-in link by email.' : 'Use a passkey.'}</p>
<div class="stack"><button id="pk" type="button">Sign in with a passkey <span aria-hidden="true">&#8594;</span></button></div>
${mail ? '<div class="or">or</div>' : '<p id="no-mail" class="note">Email codes are not switched on yet. Use a passkey.</p>'}
<form id="f-email"${mail ? '' : ' hidden'}><label for="email">Email</label><input id="email" type="email" autocomplete="username webauthn" required>
<div class="row"><button type="submit" id="send-link">Email me a link <span aria-hidden="true">&#8594;</span></button><button type="submit" id="send-code" class="ghost">Use a code instead</button></div></form>
<form id="f-code" hidden><label for="otp">6-digit code</label><input id="otp" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9]{6}" maxlength="6" required>
<div class="row"><button type="submit">Sign in <span aria-hidden="true">&#8594;</span></button><button type="button" class="ghost" id="again">Use another email</button></div></form>
${google ? '<div class="or">or</div><button id="google" type="button" class="secondary">Continue with Google <span aria-hidden="true">&#8594;</span></button>' : ''}
<div id="msg" class="note" role="status"></div></div></main>`;
  const script = common + `
const next = ${JSON.stringify(next || '/')}; const msg = $('#msg'); let email = '';
const done = () => { location.replace(next); };
$('#f-email').onsubmit = async e => { e.preventDefault(); email = $('#email').value.trim().toLowerCase();
  const byCode = e.submitter && e.submitter.id === 'send-code';
  try { note(msg, 'Sending...');
    if (byCode) { await call('/api/auth/email-otp/send-verification-otp', { method: 'POST', body: JSON.stringify({ email, type: 'sign-in' }) });
      $('#f-email').hidden = true; $('#f-code').hidden = false; $('#otp').focus(); note(msg, 'If this email has an account, a code is on its way.'); }
    else { await call('/api/auth/sign-in/magic-link', { method: 'POST', body: JSON.stringify({ email, callbackURL: next }) });
      note(msg, 'If this email has an account, a sign-in link is on its way. Open it on this device.'); } }
  catch (err) { note(msg, 'Could not send a code: ' + err.message, true); } };
$('#f-code').onsubmit = async e => { e.preventDefault();
  try { await call('/api/auth/sign-in/email-otp', { method: 'POST', body: JSON.stringify({ email, otp: $('#otp').value.trim() }) }); done(); }
  catch (err) { note(msg, 'That code did not work: ' + err.message, true); } };
$('#again').onclick = () => { $('#f-code').hidden = true; $('#f-email').hidden = false; note(msg, ''); };
$('#pk').onclick = async () => {
  try { note(msg, 'Waiting for your passkey...'); const o = await call('/api/auth/passkey/generate-authenticate-options');
    await call('/api/auth/passkey/verify-authentication', { method: 'POST', body: JSON.stringify({ response: await passkeyGet(o) }) }); done(); }
  catch (err) { note(msg, 'Passkey sign-in failed: ' + err.message, true); } };
const g = $('#google'); if (g) g.onclick = async () => {
  try { const r = await call('/api/auth/sign-in/social', { method: 'POST', body: JSON.stringify({ provider: 'google', callbackURL: next }) }); location.href = r.url; }
  catch (err) { note(msg, 'Google sign-in failed: ' + err.message, true); } };
`;
  return shell('multiprompt sign-in', body, script);
}

function dash({ email }) {
  const body = `<header><b>multiprompt</b><span class="sp"></span><span class="who">${esc(email)}</span><button id="out" class="ghost small" type="button" style="color:#f4f4f4">Sign out</button></header>
<main data-page="dash"><h1>Dashboard</h1><p>Signed in as <b>${esc(email)}</b>.</p>
<section class="tile"><h2>AI usage</h2><div id="usage" class="scroll"><p>Loading...</p></div></section>
<section class="tile"><h2>Devices</h2><div id="devices" class="scroll"><p>Loading...</p></div></section>
<section class="tile"><h2>Workspaces and tabs</h2><div id="layout"><p>Loading...</p></div></section>
<section class="tile" id="pk-tile"><h2>Passkeys</h2><div id="passkeys"><p>Loading...</p></div>
<button id="add-pk" type="button">Add a passkey <span aria-hidden="true">+</span></button><div id="pk-msg" class="note" role="status"></div></section>
</main>`;
  const script = common + `
const ago = t => { if (!t) return 'never'; const s = Math.max(0, Date.now() / 1000 - t); return s < 90 ? 'just now' : s < 5400 ? Math.round(s / 60) + ' min ago' : s < 129600 ? Math.round(s / 3600) + ' h ago' : Math.round(s / 86400) + ' days ago'; };
const h = (tag, attrs, ...kids) => { const el = document.createElement(tag); for (const [k, v] of Object.entries(attrs || {})) if (v != null) el.setAttribute(k, v); for (const k of kids.flat()) el.append(k instanceof Node ? k : String(k ?? '')); return el; };
const pct = v => typeof v === 'number' ? Math.round(v) : null;
const when = r => { const ms = typeof r === 'string' ? Date.parse(r) : r < 1e11 ? r * 1000 : r; if (!Number.isFinite(ms)) return '';
  const min = Math.round((ms - Date.now()) / 60000); if (min <= 0) return 'just reset';
  if (min < 90) return 'resets in ' + min + ' min'; if (min < 36 * 60) return 'resets in ' + Math.round(min / 60) + ' h';
  const d = new Date(ms); return 'resets ' + d.toLocaleDateString('en-GB', { weekday: 'short' }) + ' ' + d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' }); };
function meter(w) { if (!w) return '-'; const p = pct(w.used); if (p == null) return '-';
  return h('div', {}, h('div', { class: 'meter', title: p + '%' }, h('i', { class: p >= 85 ? 'hot' : null, style: 'width:' + Math.min(100, p) + '%' })), h('span', { class: 'note' }, p + '% used' + (w.resets_at ? ', ' + when(w.resets_at) : ''))); }
async function usage() { const box = $('#usage');
  try { const { updated, status: s } = await call('/v1/usage');
    const head = h('p', {}, 'Mode ', h('span', { class: 'tag blue' }, s.mode || '-'), s.override ? ' (override ' + s.override + ')' : '', ' · updated ' + ago(s.pushed_at || updated) + (s.why ? ' · ' + s.why : ''));
    const rows = (s.accounts || []).map(a => h('tr', {}, h('td', {}, h('b', {}, a.label || a.id), h('div', { class: 'note' }, [a.provider, a.email, a.host].filter(Boolean).join(' · '))),
      h('td', {}, meter(a.week)), h('td', {}, meter(a.five_hour)),
      h('td', {}, a.error ? h('span', { class: 'tag bad' }, 'error') : a.stale ? h('span', { class: 'tag' }, 'stale') : h('span', { class: 'tag ok' }, a.in_ladder === false ? 'not in ladder' : 'ok'), a.note || a.error ? h('div', { class: 'note' }, a.error || a.note) : '')));
    box.replaceChildren(head, s.advice ? h('p', {}, s.advice) : '', h('table', {}, h('thead', {}, h('tr', {}, h('th', {}, 'Account'), h('th', {}, 'Week'), h('th', {}, '5 hours'), h('th', {}, 'Status'))), h('tbody', {}, rows)));
  } catch (err) { box.replaceChildren(h('p', {}, err.status === 404 ? 'No usage reported yet.' : 'Could not load usage: ' + err.message)); } }
async function devices() { const box = $('#devices');
  try { const { devices } = await call('/v1/devices');
    const rows = devices.map(d => h('tr', {}, h('td', {}, d.name), h('td', {}, ago(d.created)), h('td', {}, ago(d.last_seen)),
      h('td', {}, d.revoked ? h('span', { class: 'tag' }, 'revoked') : (() => { const b = h('button', { class: 'danger small', type: 'button' }, 'Revoke');
        b.onclick = async () => { if (!confirm('Sign out "' + d.name + '"? It must sign in again.')) return; b.disabled = true;
          try { await call('/v1/devices/' + encodeURIComponent(d.id), { method: 'DELETE', headers: { 'X-Multiprompt': 'dash' } }); devices_(); } catch (err) { alert('Revoke failed: ' + err.message); b.disabled = false; } }; return b; })())));
    box.replaceChildren(devices.length ? h('table', {}, h('thead', {}, h('tr', {}, h('th', {}, 'Device'), h('th', {}, 'Added'), h('th', {}, 'Last seen'), h('th', {}, ''))), h('tbody', {}, rows)) : h('p', {}, 'No devices yet.'));
  } catch (err) { box.replaceChildren(h('p', {}, 'Could not load devices: ' + err.message)); } }
const devices_ = devices;
async function layout() { const box = $('#layout');
  try { const { revision, layout: l } = await call('/v1/layout');
    const cards = l.workspaces.map(w => { const tabs = l.tabs.filter(t => t.workspace === w.name);
      return h('div', { class: 'ws tile', style: 'margin:0' }, h('h3', {}, w.name + ' ', h('span', { class: 'tag' }, tabs.length + ' tabs')), h('ul', {}, tabs.map(t => h('li', {}, t.name)))); });
    box.replaceChildren(h('p', {}, l.workspaces.length + ' workspaces, ' + l.tabs.length + ' tabs · revision ' + revision), h('div', { class: 'grid' }, cards));
  } catch (err) { box.replaceChildren(h('p', {}, 'Could not load workspaces: ' + err.message)); } }
async function passkeys() { const box = $('#passkeys');
  try { const list = await call('/api/auth/passkey/list-user-passkeys');
    box.replaceChildren(list.length ? h('ul', {}, list.map(p => h('li', {}, (p.name || 'Passkey') + ' · added ' + new Date(p.createdAt).toLocaleDateString()))) : h('p', {}, 'No passkey yet. Add one to sign in without an email code.'));
  } catch (err) { box.replaceChildren(h('p', {}, 'Could not load passkeys: ' + err.message)); } }
const REAUTH = '/signin?fresh=1&next=' + encodeURIComponent('/?passkey=add');
async function addPasskey(auto) { const m = $('#pk-msg');
  try { note(m, 'Follow your browser prompt...'); const o = await call('/api/auth/passkey/generate-register-options');
    await call('/api/auth/passkey/verify-registration', { method: 'POST', body: JSON.stringify({ response: await passkeyCreate(o), name: navigator.platform || 'Passkey' }) });
    note(m, 'Passkey added.'); passkeys(); }
  catch (err) {
    const stale = err.status === 403 && /fresh/i.test(err.message);
    if (stale && !auto) { note(m, 'Confirming it is you first...'); location.href = REAUTH; return; }
    note(m, stale ? 'Press Add a passkey to continue.' : 'Could not add a passkey: ' + err.message, true); } }
$('#add-pk').onclick = () => addPasskey(false);
$('#out').onclick = async () => { try { await call('/api/auth/sign-out', { method: 'POST', body: '{}' }); } finally { location.replace('/'); } };
if (new URLSearchParams(location.search).get('passkey') === 'add') { $('#pk-tile').scrollIntoView(); history.replaceState(null, '', '/'); addPasskey(true); }
usage(); devices(); layout(); passkeys();
`;
  return shell('multiprompt dashboard', body, script);
}

export const appPage = (kind, opts) => kind === 'dash' ? dash(opts) : signin(opts);

export function confirmPage(email, name, redirect) {
  const body = `<header><b>multiprompt</b><span class="sp"></span><span class="who">${esc(email)}</span></header>
<main data-page="authorize"><div class="tile narrow"><h1>Sign in this device?</h1>
<p><b>${esc(name)}</b> wants to sign in to multiprompt as <b>${esc(email)}</b>. Only continue if you just started this from the app.</p>
<form method="post"><div class="row"><button type="submit">Allow <span aria-hidden="true">&#8594;</span></button></div></form>
<p class="note">The app receives a one-time code at ${esc(redirect.split('?')[0])}.</p></div></main>`;
  return shell('multiprompt: approve device', body);
}
