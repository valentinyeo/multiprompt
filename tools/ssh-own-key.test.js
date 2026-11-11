const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const read = file => {
  try { return fs.readFileSync(path.join(__dirname, '..', file), 'utf8'); } catch { return ''; }
};

function body(source, name) {
  const start = source.search(new RegExp(`\\n(?:pub )?fn ${name}\\(`));
  if (start < 0) return '';
  const end = source.indexOf('\n}\n', start + 1);
  return source.slice(start, end < 0 ? source.length : end);
}

const consoleSource = read('src/console.zig');
const servers = read('src/ssh_servers.zig');
const identity = read('src/ssh_identity.zig');

test('IGSH-1928 every ssh launch requires isolated app settings, including during startup', () => {
  const append = body(consoleSource, 'appendSshExe');
  const config = 'app_state.g_ssh_config[0..app_state.g_ssh_config_len]';
  assert.ok(append.includes(config), 'appendSshExe reads the app ssh settings file');
  assert.match(append, /appendWideAscii\(buf, pos, "-F \\""\)/, 'wide launch lines pass -F');
  assert.match(append, /appendAsciiBuf\(buf, pos, "-F \\""\) and appendAsciiBuf\(buf, pos, config\)/, 'narrow launch lines pass -F');
  assert.match(body(consoleSource, 'resolveSshPath'), /loadSshConfig\(\);\s*return true;/);
  assert.match(body(consoleSource, 'loadSshConfig'), /ssh_identity\.zig"\)\.configFile/);
  assert.match(append, /if \(config\.len == 0\) return appendWideAscii\(buf, pos, ssh_unconfigured_options\);/);
  assert.match(append, /if \(config\.len == 0\) return appendAsciiBuf\(buf, pos, ssh_unconfigured_options\);/);
  assert.doesNotMatch(append, /if \(config\.len == 0\) return (?:true|false);/);
  assert.match(body(identity, 'configFile'), /"config-v2"/, 'never load a previous config that allowed agent fallback');
});

test('IGSH-1928 missing app settings never offer a default key, agent or password', () => {
  const match = consoleSource.match(/const ssh_unconfigured_options = "([^"\r\n]+)";/);
  assert.ok(match, 'the startup prefix has explicit isolated options');
  const result = spawnSync('ssh', [...match[1].trim().split(/\s+/), '-G', 'unconfigured.example.invalid'], { encoding: 'utf8', timeout: 10000 });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr);
  const values = name => result.stdout.split(/\r?\n/).filter(line => line.startsWith(`${name} `)).map(line => line.slice(name.length + 1));
  assert.deepEqual(values('identityfile'), ['none']);
  assert.deepEqual(values('identityagent'), ['none']);
  assert.deepEqual(values('identitiesonly'), ['yes']);
  assert.deepEqual(values('preferredauthentications'), ['publickey']);
});

test('IGSH-1928 the app settings force the app key and turn every agent off', () => {
  const render = body(servers, 'renderConfig');
  assert.match(render, /IdentityFile \\"\{s\}\\"\\r\\n  IdentitiesOnly yes\\r\\n  IdentityAgent none\\r\\n/);
  assert.doesNotMatch(render, /if \(!forced\(slot\)\) continue;/);
  assert.match(render, /if \(listed\(slot\)\) \{[\s\S]*HostName/, 'imported hosts carry their resolved addresses without including user settings');
  assert.match(render, /if \(listed\(slot\)\) key else "none"/, 'removed and empty aliases cannot restore old credentials');
  assert.match(render, /" !\{s\}"/, 'each Include excludes managed aliases, since IdentityFile accumulates');
  assert.match(render, /for \(\[_\]\[\]const u8\{ user, system \}\)/);
  assert.match(render, /PreferredAuthentications publickey/);
});

test('IGSH-1928 migration proves the app key first and never asks an agent to install it', () => {
  const proof = body(servers, 'proofArgs');
  for (const option of ['-F none', '-i \\"{s}\\"', 'IdentitiesOnly=yes', 'IdentityAgent=none', 'BatchMode=yes', 'StrictHostKeyChecking=accept-new']) {
    assert.ok(proof.includes(option), option);
  }
  const check = body(identity, 'check');
  assert.ok(check.indexOf('keys.addCommand(a, public_key)') >= 0, 'the app key is installed over the working connection');
  assert.ok(check.indexOf('const existing = run(a, proof,') < check.indexOf('keys.addCommand(a, public_key)'), 'a working app key never depends on old credentials again');
  assert.match(check, /if \(existing\.ok or slot\.owned\) \{[\s\S]*?finish\(i, existing\.ok,[\s\S]*?return;/);
  assert.match(check, /IdentityAgent=none -o IdentitiesOnly=yes -o BatchMode=yes/);
  assert.doesNotMatch(check, /sshPrefix\(/, 'bootstrap uses original config, not an already isolated alias');
  assert.match(check, /finish\(i, proven\.ok, servers\.failureReason\(proven\.text\)\)/);
  const publish = body(identity, 'publish');
  assert.ok(publish.indexOf('sameAddresses(') < publish.indexOf('console.setSshConfig(config)'), 'settings switch on only after ssh reads them back');
  assert.doesNotMatch(publish, /any_forced|servers\.forced/);
  const worker = body(identity, 'worker');
  assert.ok(worker.indexOf('seed(a, exe)') < worker.indexOf('publish(a, exe)'));
  assert.ok(worker.indexOf('publish(a, exe)') < worker.indexOf('if (due) check(a, exe, i)'), 'regular connections are isolated before migration begins');
  const remove = body(identity, 'remove');
  assert.match(remove, /if \(servers\.listed\(slot\)\) blk:/, 'a transiently failed server still gets a revocation attempt');
  assert.match(remove, /table\[i\] = \.\{ \.status = \.removed \};/, 'removed app-owned slots cannot reimport a legacy server on restart');
});

test('IGSH-1928 the app key lives in its own private folder, never in the user key', () => {
  assert.ok(identity.includes('"D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;"'), 'folder allows only this user and the system');
  assert.match(body(identity, 'ensureKey'), /protect\(dir, descriptor\)[\s\S]*ssh-keygen\.exe\\" -t ed25519 -N \\"\\" -q -C multibot -f[\s\S]*protect\(key, descriptor\)/);
  assert.match(body(identity, 'dataPath'), /ZigShell\\\\ssh-key/);
  assert.doesNotMatch(identity, /id_ed25519|\.ssh\\\\/);
  assert.match(read('src/session.zig'), /resolveSshPath\(false\);\n    @import\("ssh_identity\.zig"\)\.start\(\);/);
});

test('IGSH-1928 ssh-keygen lookups survive the extra -F argument', () => {
  const desktop = read('src/account_desktop.zig');
  assert.doesNotMatch(desktop, /std\.mem\.trim\(u8, ssh, "\\" "\)/);
  assert.equal((desktop.match(/@import\("console\.zig"\)\.sshExeOf\(ssh\)/g) || []).length, 2);
  assert.match(body(consoleSource, 'sshExeOf'), /indexOfScalarPos\(u8, prefix, 1, '"'\)/);
});

test('IGSH-1928 Servers ships on Settings, Ctrl+K, shortcut rows and the shortcut doc', () => {
  assert.match(read('src/app_state.zig'), /pub const SEARCH_SERVERS_OFFSET: usize = \d+;/);
  assert.match(read('src/command_palette.zig'), /g_search_results\[app_state\.g_search_result_count\] = app_state\.SEARCH_SERVERS_OFFSET;/);
  assert.match(read('src/sidebar.zig'), /result_idx == app_state\.SEARCH_SERVERS_OFFSET\) \{[\s\S]{0,400}ui_words\.settings_servers/);
  assert.match(read('src/main.zig'), /target == app_state\.SEARCH_SERVERS_OFFSET\) \{[\s\S]{0,200}WM_APP_SETTINGS_OPEN, 1, 0\)/);
  assert.match(read('src/main.zig'), /if \(wp == 1\) @import\("settings_panel\.zig"\)\.openServers\(\);/);
  assert.ok(read('src/shortcuts.zig').includes('.{ .a = "Ctrl+K -> Servers"'));
  assert.ok(read('openwiki/operations/keyboard-shortcuts.md').includes('Ctrl+K -&gt; Servers'));
  const panel = read('src/settings_panel.zig');
  assert.match(panel, /\.servers => openServers\(\),/);
  assert.match(body(panel, 'serversProc'), /identity\.checkServer\(id - server_test_id\)/);
  assert.match(body(panel, 'confirmRemove'), /identity\.removeServer\(slot_index\)/);
  assert.match(body(panel, 'addServerFromForm'), /identity\.addServer\(/);
  assert.match(read('build.zig'), /"src\/ssh_servers\.zig"/);
});
