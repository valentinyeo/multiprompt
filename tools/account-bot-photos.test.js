const { test } = require('node:test');
const assert = require('node:assert/strict');
const { webcrypto } = require('node:crypto');

globalThis.crypto ??= webcrypto;

test('remote photo keys match the cross-device contract', async () => {
  const { remotePhotoKey } = await import('../service/bot-photo.js');
  assert.equal(await remotePhotoKey(1, 'My-Bot'), '7fb158a6819a5e497a67662c60c7837ffbd327627773fd876686c60f93d88d5a');
  assert.equal(await remotePhotoKey(0, 'chief-of-staff'), '44b6ce7ad143b0f7a96b98865d4055b049f45518e19e9b4753e8a2f6ee121b06');
});

test('photo validation rejects malformed data and bad checksums', async () => {
  const { validPhotoPng } = await import('../service/bot-photo.js');
  const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGD4DwABBAEAX+XDSwAAAABJRU5ErkJggg==';
  assert.equal(validPhotoPng(png), true);
  assert.equal(validPhotoPng(''), false);
  assert.equal(validPhotoPng('a'.repeat(87388)), false);
  assert.equal(validPhotoPng(Buffer.from('not png').toString('base64')), false);
  const changed = Buffer.from(png, 'base64');
  changed[20] ^= 1;
  assert.equal(validPhotoPng(changed.toString('base64')), false);
});
