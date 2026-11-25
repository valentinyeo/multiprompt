import { test } from 'node:test';
import assert from 'node:assert/strict';
import { appPage } from '../pages.js';

test('sign-in page renders the three hub actions without SSH key fields', () => {
  for (const mail of [false, true]) {
    const page = appPage('signin', { mail, google: false });
    const actions = page.match(/<nav aria-label="Get started">([\s\S]*?)<\/nav>/)?.[1];
    assert.ok(actions, 'the sign-in page has a get-started action group');
    assert.equal((actions.match(/<(?:a|button)\b/g) || []).length, 3);
    assert.match(actions, /https:\/\/deploy\.workers\.cloudflare\.com\/\?url=https%3A%2F%2Fgithub\.com%2Fvalentinyeo%2Fmultiprompt%2Ftree%2Fmaster%2Fservice/);
    assert.match(actions, /Deploy your own hub/);
    assert.match(actions, /Sign in or sign up with a passkey/);
    assert.match(actions, /https:\/\/github\.com\/valentinyeo\/multiprompt\/releases\/latest\/download\/multiprompt-x64\.exe/);
    assert.match(actions, /Download for Windows/);
    assert.doesNotMatch(page, /<(?:input|textarea)[^>]*(?:ssh|private.?key|identity.?file|type="file")/i);
    assert.match(page, /SSH keys stay on your computer/);
    assert.match(page, /background:#000/);
    assert.match(page, /border-radius:999px/);
    assert.match(page, /max-width:600px/);
  }
});

test('sign-in keeps passkey and email enrollment behind the account action', () => {
  const page = appPage('signin', { mail: true });
  assert.match(page, /id="account"[^>]*hidden/);
  assert.match(page, /id="pk"/);
  assert.match(page, /verify your email first/i);
  assert.match(page, /generate-authenticate-options/);
  assert.match(page, /verify-authentication/);
  assert.match(page, /generate-register-options/);
  assert.match(page, /verify-registration/);
});
