import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { Miniflare, convertV4MiniflareOptions } from 'miniflare';

test('infra: Wrangler declares the unrestricted EMAIL send binding', () => {
  const config = JSON.parse(readFileSync(new URL('../wrangler.jsonc', import.meta.url), 'utf8'));
  assert.deepEqual(config.send_email, [{ name: 'EMAIL' }]);
});

test('infra: with BETTER_AUTH_API_KEY the dash plugin loads and links/codes are sent through the hosted email API', async () => {
  const calls = [];
  const mf = new Miniflare(convertV4MiniflareOptions({
    outboundService: async req => {
      const body = req.method === 'POST' ? await req.text() : '';
      calls.push({ url: req.url, auth: req.headers.get('authorization'), body });
      return new Response('{"success":true,"messageId":"m1"}', { headers: { 'Content-Type': 'application/json' } });
    },
    modules: true, scriptPath: new URL('../.build/worker.js', import.meta.url).pathname, compatibilityDate: '2026-10-09', compatibilityFlags: ['nodejs_compat'], d1Databases: ['DB'],
    bindings: { ALLOWED_EMAILS: 'owner@example.com', AUTH_ORIGINS: 'http://localhost', RP_ID: 'localhost', BETTER_AUTH_SECRET: 'test-only-value-'.repeat(3), BETTER_AUTH_API_KEY: 'fake-infra-key' }
  }));
  try {
    const db = await mf.getD1Database('DB');
    for (const sql of readFileSync(new URL('../schema.sql', import.meta.url), 'utf8').split(';').filter(s => s.trim())) await db.prepare(sql).run();
    const page = await (await mf.dispatchFetch('http://localhost/signin')).text();
    assert.match(page, /data-methods="passkey,email"/);
    const send = await mf.dispatchFetch('http://localhost/api/auth/sign-in/magic-link', { method: 'POST', headers: { 'Content-Type': 'application/json', Origin: 'http://localhost' }, body: JSON.stringify({ email: 'owner@example.com', callbackURL: '/' }) });
    assert.equal(send.status, 200);
    await new Promise(r => setTimeout(r, 300));
    const mail = calls.find(c => /better-auth\.com/.test(c.url) && /email/i.test(c.url));
    assert.ok(mail, 'hosted email API was called: ' + JSON.stringify(calls.map(c => c.url)));
    assert.equal(mail.auth, 'Bearer fake-infra-key');
    assert.match(mail.body, /magic-link/);
  } finally { await mf.dispose(); }
});

test('infra: Wrangler has no legacy identity configuration', () => {
  const config = JSON.parse(readFileSync(new URL('../wrangler.jsonc', import.meta.url), 'utf8'));
  for (const key of ['ACCESS_TEAM', 'ACCESS_AUD']) assert.equal(Object.hasOwn(config.vars, key), false);
});

test('infra: legacy identity references occur only in explicit negative tests and deployment assertions', () => {
  const forbidden = /Cf-Access-Jwt-Assertion|ACCESS_AUD|ACCESS_TEAM|access-bridge|login\/bridge/;
  assert.ok(forbidden.test('Cf-Access-Jwt-Assertion'));
  const root = new URL('../', import.meta.url);
  const files = readdirSync(root, { recursive: true }).filter(file => !file.split('/').some(part => part === 'node_modules' || part.startsWith('.')) && /\.(js|py|jsonc|md)$/.test(file));
  assert.ok(files.includes('worker.js')); assert.ok(files.includes('auth.js'));
  for (const file of files) {
    if (['test/infra.test.js', 'test/provision.test.js', 'test/worker.test.js'].includes(file)) continue;
    const source = readFileSync(new URL(file, root), 'utf8');
    for (const line of source.split('\n')) {
      if (file === 'verify-deployment.py' && line === "status, _, _ = raw(ORIGIN + '/login/bridge')") continue;
      assert.doesNotMatch(line, forbidden, file);
    }
  }
});
