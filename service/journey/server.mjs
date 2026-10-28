import { createServer as createHttp } from 'node:http';
import { createServer as createHttps } from 'node:https';
import { readFileSync, writeFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { Miniflare, convertV4MiniflareOptions } from 'miniflare';
import { hash } from '../worker.js';

const args = Object.fromEntries(process.argv.slice(2).map(arg => arg.replace(/^--/, '').split('=')));
const port = Number(args.port || 8787);
const stateFile = args.state;
const account = 'journey@example.com';
const secret = () => randomBytes(32).toString('base64url');
const tab = (name, workspace) => ({ kind: 'tmux', name, tmux_session: name, tmux_host: 0, workspace });
const layout = {
  schema: 1,
  revision: 1,
  workspaces: [{ name: 'Work' }, { name: 'Notes' }],
  tabs: [tab('work-main', 'Work'), tab('runner-1', 'Work'), tab('runner-2', 'Work'), tab('runner-3', 'Work'), tab('notes-a', 'Notes')]
};

const mf = new Miniflare(convertV4MiniflareOptions({
  modules: true,
  scriptPath: new URL('../.build/worker.js', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'),
  compatibilityDate: '2026-10-09',
  compatibilityFlags: ['nodejs_compat'],
  d1Databases: ['DB'],
  bindings: { ACCOUNT_EMAIL: account, ALLOWED_EMAILS: account, AUTH_ORIGINS: 'http://localhost', RP_ID: 'localhost' }
}));
const db = await mf.getD1Database('DB');
for (const sql of readFileSync(new URL('../schema.sql', import.meta.url), 'utf8').split(';').filter(s => s.trim())) await db.prepare(sql).run();

const refresh = secret();
const keys = { admin: 'mpk_a_' + secret(), workspace: 'mpk_w_' + secret(), other: 'mpk_w_' + secret() };
await db.prepare('INSERT INTO layouts VALUES (?,?,?)').bind(account, 1, JSON.stringify(layout)).run();
await db.prepare('INSERT INTO devices (id,account,name,refresh_hash,created,last_seen) VALUES (?,?,?,?,?,?)').bind('journey-device', account, 'Journey', await hash(refresh), 1, 1).run();
const addKey = async (key, kind, workspace) => db.prepare('INSERT INTO service_keys (hash,account,kind,workspace,label,created) VALUES (?,?,?,?,?,?)').bind(await hash(key), account, kind, workspace, 'journey', 1).run();
await addKey(keys.admin, 'admin', null);
await addKey(keys.workspace, 'workspace', 'Notes');
await addKey(keys.other, 'workspace', 'Missing');

let reportOffline = false;
const handler = async (req, res) => {
  if (args.reports === 'true' && req.url === '/__journey/reports') {
    const rows = await db.prepare('SELECT report_id,captured_at,received_at,app_version,summary,stack_trace FROM crash_reports ORDER BY received_at,rowid').all();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ reports: rows.results }));
    return;
  }
  if (args.reports === 'true' && req.url.startsWith('/__journey/offline/')) {
    reportOffline = req.url.endsWith('/true');
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ offline: reportOffline }));
    return;
  }
  if (reportOffline && req.url === '/v1/crash-reports') {
    res.writeHead(503, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'fixture_offline' }));
    return;
  }
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const body = Buffer.concat(chunks);
  const headers = { ...req.headers };
  delete headers.host;
  const response = await mf.dispatchFetch('http://localhost' + req.url, { method: req.method, headers, body: ['GET', 'HEAD'].includes(req.method) ? undefined : body });
  res.writeHead(response.status, Object.fromEntries(response.headers));
  res.end(Buffer.from(await response.arrayBuffer()));
};
const server = args.pfx
  ? createHttps({ pfx: readFileSync(args.pfx), passphrase: args.pfxpass }, handler)
  : createHttp(handler);
server.listen(port, args.bind || '0.0.0.0', () => {
  if (stateFile) writeFileSync(stateFile, JSON.stringify({ account, refresh_token: refresh, admin_key: keys.admin, workspace_key: keys.workspace, other_key: keys.other }));
  console.log('journey service ready on ' + port);
});
process.on('SIGTERM', async () => { server.close(); await mf.dispose(); process.exit(0); });
