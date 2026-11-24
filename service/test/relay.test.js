import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Miniflare, convertV4MiniflareOptions } from 'miniflare';
import { hash } from '../worker.js';
import { relaySlot, frameTooLarge } from '../relay.js';

let mf, db;
const base = 'http://localhost';
const account = 'owner@example.com';
const other = 'second@example.com';
const adminKey = 'mpk_a_' + 'A'.repeat(43), workspaceKey = 'mpk_w_' + 'B'.repeat(43);
const deviceToken = 'd'.repeat(43), otherToken = 'e'.repeat(43);
const auth = token => ({ Authorization: 'Bearer ' + token });

const seedDevice = async (id, owner, name, token) => {
  await db.prepare('INSERT INTO devices (id,account,name,refresh_hash,created,last_seen) VALUES (?,?,?,?,1,1)').bind(id, owner, name, await hash('refresh-' + id)).run();
  await db.prepare('INSERT INTO access_tokens VALUES (?,?,?)').bind(await hash(token), id, Math.floor(Date.now() / 1000) + 600).run();
};

const open = async (path, token) => {
  const response = await mf.dispatchFetch(base + path, { headers: { Upgrade: 'websocket', ...auth(token) } });
  response.webSocket?.accept();
  return response;
};
const desktop = (token = deviceToken, slot = 0) => open('/v1/relay?slot=' + slot, token);
const helper = (token = adminKey, slot = 0) => open('/v1/relay?slot=' + slot, token);
const next = socket => new Promise((resolve, reject) => {
  const timer = setTimeout(() => reject(new Error('no frame arrived')), 2000);
  socket.addEventListener('message', event => { clearTimeout(timer); resolve(event.data); }, { once: true });
});
const silence = socket => new Promise((resolve, reject) => {
  const on = event => { clearTimeout(timer); reject(new Error('unexpected frame: ' + event.data)); };
  const timer = setTimeout(() => { socket.removeEventListener('message', on); resolve('silent'); }, 400);
  socket.addEventListener('message', on);
});
const presence = async (token = deviceToken) => (await (await mf.dispatchFetch(base + '/v1/relay', { headers: auth(token) })).json()).slots;
const settled = async (check, attempts = 40) => {
  for (let attempt = 0; attempt < attempts; attempt++) {
    const value = await check();
    if (value) return value;
    await new Promise(resolve => setTimeout(resolve, 25));
  }
  return null;
};

before(async () => {
  mf = new Miniflare(convertV4MiniflareOptions({
    modules: true, scriptPath: new URL('../.build/worker.js', import.meta.url).pathname,
    compatibilityDate: '2026-10-09', compatibilityFlags: ['nodejs_compat'], d1Databases: ['DB'],
    durableObjects: { RELAY_ROOMS: 'RelayRoom' },
    bindings: { ALLOWED_EMAILS: account + ',' + other, ACCOUNT_EMAIL: account, AUTH_ORIGINS: base, RP_ID: 'localhost' }
  }));
  db = await mf.getD1Database('DB');
  for (const sql of readFileSync(new URL('../schema.sql', import.meta.url), 'utf8').split(';').filter(s => s.trim())) await db.prepare(sql).run();
  await db.prepare('INSERT INTO service_keys (hash,account,kind,workspace,label,created) VALUES (?,?,?,?,?,1)').bind(await hash(adminKey), account, 'admin', null, 'relay admin').run();
  await db.prepare('INSERT INTO service_keys (hash,account,kind,workspace,label,created) VALUES (?,?,?,?,?,1)').bind(await hash(workspaceKey), account, 'workspace', 'inne', 'relay workspace').run();
  await seedDevice('device-one', account, 'Desktop', deviceToken);
  await seedDevice('device-two', other, 'Second desktop', otherToken);
});
after(async () => { await mf?.dispose(); });

test('only slots 0, 1 and 2 address a room, and a frame is capped', () => {
  assert.equal(relaySlot('0'), 0);
  assert.equal(relaySlot(2), 2);
  for (const value of ['3', -1, '1.5', '', 'x', null, undefined]) assert.equal(relaySlot(value), null);
  assert.equal(frameTooLarge('short'), false);
  assert.equal(frameTooLarge(new ArrayBuffer(16 * 1024 * 1024 + 1)), true);
  assert.equal(frameTooLarge(new ArrayBuffer(1024)), false);
});

test('the room answers only a device or an account admin key, and only for a real slot', async () => {
  assert.equal((await mf.dispatchFetch(base + '/v1/relay')).status, 401);
  assert.equal((await mf.dispatchFetch(base + '/v1/relay?slot=0', { headers: auth(workspaceKey) })).status, 403);
  assert.equal((await mf.dispatchFetch(base + '/v1/relay?slot=7', { headers: auth(deviceToken) })).status, 400);
  assert.equal((await mf.dispatchFetch(base + '/v1/relay', { headers: { Upgrade: 'websocket', ...auth(deviceToken) } })).status, 400);
  const upgrader = await desktop(deviceToken, 0);
  assert.equal(upgrader.status, 101);
  upgrader.webSocket.close();
  assert.ok(await settled(async () => (await presence())[0].desktops === 0), 'the closed desktop left the room');
});

test('a helper and a desktop on one slot carry frames both ways, and presence names the slot', async () => {
  const server = await helper(adminKey, 0);
  assert.equal(server.status, 101);
  const client = await desktop(deviceToken, 0);
  assert.equal(client.status, 101);
  const seen = await settled(async () => { const slots = await presence(); return slots[0].server && slots[0].desktops === 1 ? slots : null; });
  assert.deepEqual(seen, [{ slot: 0, server: true, desktops: 1 }, { slot: 1, server: false, desktops: 0 }, { slot: 2, server: false, desktops: 0 }]);

  const toDesktop = next(client.webSocket);
  server.webSocket.send('{"kind":"history","id":"a1"}');
  assert.equal(await toDesktop, '{"kind":"history","id":"a1"}');

  const toServer = next(server.webSocket);
  client.webSocket.send('{"kind":"history","id":"a2"}');
  assert.equal(await toServer, '{"kind":"history","id":"a2"}');

  client.webSocket.close();
  server.webSocket.close();
  const gone = await settled(async () => { const slots = await presence(); return slots[0].server === false && slots[0].desktops === 0 ? slots : null; });
  assert.ok(gone, 'both sides left the room');
});

test('slots stay separate, a second account has its own room, and a desktop with no helper sends nowhere', async () => {
  const zero = await helper(adminKey, 0);
  const one = await helper(adminKey, 1);
  const wrongSlot = await desktop(deviceToken, 1);
  const orphan = await desktop(deviceToken, 0);
  await settled(async () => { const slots = await presence(); return slots[0].server && slots[0].desktops === 1 && slots[1].server && slots[1].desktops === 1; });

  wrongSlot.webSocket.send('{"kind":"history","id":"b1"}');
  assert.equal(await next(one.webSocket), '{"kind":"history","id":"b1"}');
  zero.webSocket.send('{"kind":"history","id":"b2"}');
  assert.equal(await next(orphan.webSocket), '{"kind":"history","id":"b2"}');
  orphan.webSocket.send('{"kind":"history","id":"b3"}');
  assert.equal(await next(zero.webSocket), '{"kind":"history","id":"b3"}');
  assert.equal(await silence(one.webSocket), 'silent');

  const stranger = await presence(otherToken);
  assert.deepEqual(stranger, [{ slot: 0, server: false, desktops: 0 }, { slot: 1, server: false, desktops: 0 }, { slot: 2, server: false, desktops: 0 }]);

  zero.webSocket.close();
  one.webSocket.close();
  wrongSlot.webSocket.close();
  orphan.webSocket.close();
});

test('a reconnecting helper takes its slot and the replaced helper leaves', async () => {
  const first = await helper(adminKey, 2);
  const second = await helper(adminKey, 2);
  assert.equal(second.status, 101);
  const client = await desktop(deviceToken, 2);
  assert.equal(client.status, 101);
  await settled(async () => (await presence())[2].desktops === 1);
  const frame = next(client.webSocket);
  second.webSocket.send('{"kind":"live","id":"c1"}');
  assert.equal(await frame, '{"kind":"live","id":"c1"}');
  first.webSocket.close();
  const still = next(client.webSocket);
  second.webSocket.send('{"kind":"live","id":"c2"}');
  assert.equal(await still, '{"kind":"live","id":"c2"}');
  second.webSocket.close();
  client.webSocket.close();
});
