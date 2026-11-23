const { test } = require('node:test');
const assert = require('node:assert/strict');
const { webcrypto } = require('node:crypto');
const { existsSync } = require('node:fs');
const { join } = require('node:path');

globalThis.crypto ??= webcrypto;

test('remote photo keys match the cross-device contract', async () => {
  assert.ok(existsSync(join(__dirname, '../service/bot-photo.js')), 'photo API module exists');
  const { remotePhotoKey } = await import('../service/bot-photo.js');
  assert.equal(await remotePhotoKey(1, 'My-Bot'), '7fb158a6819a5e497a67662c60c7837ffbd327627773fd876686c60f93d88d5a');
  assert.equal(await remotePhotoKey(0, 'chief-of-staff'), '44b6ce7ad143b0f7a96b98865d4055b049f45518e19e9b4753e8a2f6ee121b06');
  assert.equal(await remotePhotoKey(1, 'my-bot'), await remotePhotoKey(1, 'My-Bot'));
  assert.notEqual(await remotePhotoKey(0, 'my-bot'), await remotePhotoKey(1, 'my-bot'));
});

test('photo validation rejects malformed data and bad checksums', async () => {
  assert.ok(existsSync(join(__dirname, '../service/bot-photo.js')), 'photo API module exists');
  const { validPhotoPng } = await import('../service/bot-photo.js');
  const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGD4DwABBAEAX+XDSwAAAABJRU5ErkJggg==';
  assert.equal(validPhotoPng(png), true);
  assert.equal(validPhotoPng(''), false);
  assert.equal(validPhotoPng('a'.repeat(87388)), false);
  assert.equal(validPhotoPng(Buffer.from('not png').toString('base64')), false);
  const changed = Buffer.from(png, 'base64');
  changed[20] ^= 1;
  assert.equal(validPhotoPng(changed.toString('base64')), false);
  const header = change => {
    const bytes = Buffer.from(png, 'base64');
    change(bytes);
    let crc = 0xffffffff;
    for (const byte of bytes.subarray(12, 29)) {
      crc ^= byte;
      for (let i = 0; i < 8; i++) crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
    }
    bytes.writeUInt32BE((crc ^ 0xffffffff) >>> 0, 29);
    return bytes.toString('base64');
  };
  for (const offset of [16, 20]) {
    for (const dimension of [0, 257]) assert.equal(validPhotoPng(header(bytes => bytes.writeUInt32BE(dimension, offset))), false);
  }
  assert.equal(validPhotoPng(header(bytes => { bytes[24] = 3; })), false);
  assert.equal(validPhotoPng(header(bytes => { bytes[26] = 1; })), false);
  assert.equal(validPhotoPng(header(bytes => { bytes[28] = 2; })), false);
  assert.equal(validPhotoPng(Buffer.from(png, 'base64').subarray(0, 40).toString('base64')), false);
});


test('MUBO-244 chat photo keys agree across UUID formats and restored aliases', async () => {
  const { chatPhotoKey } = await import('../service/bot-photo.js');
  const expected = 'e675a29f53a92c0b3b809cf2d0c8ce652f1def6483829a4547ab8f143d7c2576';
  for (const csid of ['11111111-2222-4333-8444-555555555555', '11111111222243338444555555555555']) {
    assert.equal(await chatPhotoKey({ csid, tmux_host: 0, tmux_session: 'old-runner' }), expected);
  }
  assert.equal(await chatPhotoKey({ tmux_host: 1, tmux_session: 'live-11111111222243338444555555555555' }), expected);
  assert.equal(await chatPhotoKey({ csid: 'invalid', tmux_session: 'live-11111111222243338444555555555555' }), expected);
  assert.equal(await chatPhotoKey({ csid: 'ABCDEF01-2222-4333-8444-555555555555', tmux_session: 'old' }), await chatPhotoKey({ csid: 'abcdef01222243338444555555555555' }));
  for (const tmux_session of ['old-runner', 'live-short', 'live-1111111122224333844455555555555g', 'live-h11111111222243338444555555555555']) {
    assert.equal(await chatPhotoKey({ tmux_session }), null);
  }
});
