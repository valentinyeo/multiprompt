const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');

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

test('SOFT-2476 skills installed as linked folders show up in discovery', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'linked-skills-'));
  try {
    const installed = path.join(dir, 'installed');
    const root = path.join(dir, '.claude', 'skills');
    fs.mkdirSync(installed);
    fs.mkdirSync(root, { recursive: true });
    fs.writeFileSync(path.join(installed, 'SKILL.md'), '---\ndescription: Linked skill.\n---\nLinked instructions.');
    fs.symlinkSync(installed, path.join(root, 'valentin-mode'), process.platform === 'win32' ? 'junction' : 'dir');
    copyZig(['skills.zig'], dir);
    const harness = path.join(dir, 'linked-skills-test.zig');
    fs.writeFileSync(harness, `
const std = @import("std");
const skills = @import("skills.zig");
test "linked skill fixture" {
    const items = try skills.discover(std.testing.allocator, std.testing.io, ${JSON.stringify(dir)}, &.{});
    defer skills.deinitAll(std.testing.allocator, items);
    try std.testing.expectEqual(@as(usize, 1), items.len);
    try std.testing.expectEqualStrings("valentin-mode", items[0].name);
    try std.testing.expectEqualStrings("Linked skill.", items[0].description);
    try std.testing.expectEqualStrings("Linked instructions.", items[0].body);
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', harness, '--test-filter', 'linked skill fixture'], { cwd: dir, encoding: 'utf8', timeout: 180000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
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
