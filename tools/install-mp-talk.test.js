const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { spawnSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..');
const INSTALLER = path.join(ROOT, 'tools', 'install-mp-talk.sh');
const DESKTOP_TOOLS = [
  ['mp-send', 'mp_send.py'],
  ['multibot-feedback', 'multibot_feedback.py'],
  ['mp-helper', 'mp_helper.py'],
  ['mp-shell', 'mp_shell.py']
];
const INSTALLED = ['mp-send', 'mp-fresh', 'mp-sessions', 'mp-helper', 'mp-shell', 'multibot-feedback', 'mp-layout'];

function installer(args, home) {
  return spawnSync('/bin/sh', [INSTALLER, ...args], {
    encoding: 'utf8',
    env: { ...process.env, HOME: home, XDG_DATA_HOME: path.join(home, 'share'), MP_TALK_BIN: path.join(home, 'bin') }
  });
}

test('SOFT-2823 one install gives an account every Multibot tool', () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-talk-install-'));
  try {
    const install = installer([], home);
    assert.equal(install.status, 0, install.stderr);
    for (const name of INSTALLED) {
      const tool = path.join(home, 'bin', name);
      assert.ok(fs.existsSync(tool), name + ' must be installed');
      const help = spawnSync(tool, ['--help'], { encoding: 'utf8', env: process.env });
      assert.equal(help.status, 0, name + ' --help failed: ' + help.stderr);
    }
    const clean = installer(['--check'], home);
    assert.equal(clean.status, 0, clean.stdout + clean.stderr);
    assert.match(clean.stdout, /mp-layout ok/);
    fs.unlinkSync(path.join(home, 'bin', 'multibot-feedback'));
    const missing = installer(['--check'], home);
    assert.equal(missing.status, 1, 'a missing tool must fail the check');
    assert.match(missing.stdout, /multibot-feedback missing/);
  } finally {
    fs.rmSync(home, { recursive: true, force: true });
  }
});

test('SOFT-2823 the installer covers every chat tool the desktop runs', () => {
  const source = fs.readFileSync(INSTALLER, 'utf8');
  const bundle = fs.readFileSync(path.join(ROOT, 'src', 'chat_session.zig'), 'utf8');
  for (const [name, file] of DESKTOP_TOOLS) {
    assert.match(bundle, new RegExp('@embedFile\\("' + file.replace('.', '\\.') + '"\\)'), 'the desktop must ship ' + file);
    assert.match(source, new RegExp(name + ':' + file.replace('.', '\\.')), 'the installer must copy ' + file);
  }
  assert.match(source, /mp-sessions:mp_sessions\.py/);
  assert.match(source, /mp-layout:mp-layout\.mjs/);
});

test('SOFT-2823 --user without an account name is refused', () => {
  const done = spawnSync('/bin/sh', [INSTALLER, '--user'], { encoding: 'utf8' });
  assert.equal(done.status, 2);
  assert.match(done.stderr, /--user needs an account name/);
});

test('SOFT-2823 --user repeats the same command for every server account', () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-talk-users-'));
  try {
    const fake = path.join(home, 'bin');
    const log = path.join(home, 'sudo.log');
    fs.mkdirSync(fake);
    fs.writeFileSync(path.join(fake, 'sudo'), '#!/bin/sh\nprintf "%s\\n" "$*" >> "' + log + '"\n');
    fs.chmodSync(path.join(fake, 'sudo'), 0o755);
    const done = spawnSync('/bin/sh', [INSTALLER, '--check', '--user', 'inne', '--user', 'valentin'], {
      encoding: 'utf8',
      env: { ...process.env, PATH: fake + ':' + process.env.PATH }
    });
    assert.equal(done.status, 0, done.stderr);
    assert.ok(fs.existsSync(log), 'sudo must run once for each named account');
    const calls = fs.readFileSync(log, 'utf8').trim().split('\n');
    assert.equal(calls.length, 2, calls.join('\n'));
    assert.match(calls[0], /^-n -H -u inne -- \/bin\/sh .*install-mp-talk\.sh --check$/);
    assert.match(calls[1], /^-n -H -u valentin -- \/bin\/sh .*install-mp-talk\.sh --check$/);
  } finally {
    fs.rmSync(home, { recursive: true, force: true });
  }
});
