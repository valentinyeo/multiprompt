const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const main = require('./app-source').readAppSource();
const skills = fs.readFileSync(path.join(root, 'src', 'skills.zig'), 'utf8');
const auth = fs.readFileSync(path.join(root, 'src', 'sync_auth.zig'), 'utf8');

test('Ctrl+K exposes grouped native and harness skills with keyboard command browsing', () => {
  assert.match(main, /SEARCH_SKILLS_MENU_OFFSET/);
  assert.match(main, /g_search_skills_mode/);
  assert.match(main, /L\("Skills\.\.\."\)/);
  assert.match(main, /"Multi Bot skills"/);
  assert.match(main, /L\("coding harness"\)/);
  assert.doesNotMatch(main, /plus_btn/);
  assert.doesNotMatch(main, /showChatPlusMenu/);
  assert.match(skills, /"\.claude", "skills"/);
  assert.match(skills, /"plugins", "installed_plugins.json"/);
  assert.match(skills, /enabledPlugins/);
  assert.match(skills, /skillOverrides/);
});

test('skill sends use the shared Android-compatible envelope', () => {
  assert.match(skills, /\/{s}\\n\\n<skill name=\\"{s}\\">\\n{s}\\n<\/skill>/);
  assert.match(skills, /{s}\\n\\n\/{s}\\n\\n<skill name=\\"{s}\\">\\n{s}\\n<\/skill>/);
});

test('desktop login uses PKCE and DPAPI without cookies or a client secret', () => {
  assert.match(main, /SEARCH_MULTIPROMPT_LOGIN_OFFSET/);
  assert.match(main, /multiprompt:\/\/auth\/callback/);
  assert.match(auth, /code_challenge_method/);
  assert.match(auth, /Sha256\.hash/);
  assert.match(auth, /CryptProtectData/);
  assert.match(auth, /CryptUnprotectData/);
  assert.doesNotMatch(auth, /Cf-Access-Jwt-Assertion/);
  assert.doesNotMatch(auth, /Cookie:/);
  assert.doesNotMatch(auth, /client_secret=/);
});
