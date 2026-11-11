const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
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

test('IGSH-1928 every ssh launch prefix carries the app key settings once they are proven', () => {
  const append = body(consoleSource, 'appendSshExe');
  const config = 'app_state.g_ssh_config[0..app_state.g_ssh_config_len]';
  assert.ok(append.includes(config), 'appendSshExe reads the app ssh settings file');
  assert.match(append, /appendWideAscii\(buf, pos, "-F \\""\)/, 'wide launch lines pass -F');
  assert.match(append, /appendAsciiBuf\(buf, pos, "-F \\""\) and appendAsciiBuf\(buf, pos, config\)/, 'narrow launch lines pass -F');
  assert.match(body(consoleSource, 'resolveSshPath'), /loadSshConfig\(\);\s*return true;/);
  assert.match(body(consoleSource, 'loadSshConfig'), /ssh_identity\.zig"\)\.configFile/);
});

test('IGSH-1928 the app settings force the app key and turn every agent off', () => {
  const render = body(servers, 'renderConfig');
  assert.match(render, /IdentityFile \\"\{s\}\\"\\r\\n  IdentitiesOnly yes\\r\\n  IdentityAgent none\\r\\n/);
  assert.match(render, /if \(!forced\(slot\)\) continue;/, 'servers not yet proven keep today\'s sign-in');
  assert.ok(render.indexOf('IdentityAgent none') < render.indexOf('Host *'), 'user settings are included after the forced blocks so the app values win');
  assert.ok(render.includes(' !{s}'), 'both includes exclude servers already using the app key');
  assert.match(body(servers, 'forced'), /slot\.status == \.connected or \(slot\.owned and listed\(slot\)\)/);
});

test('IGSH-1928 a server switches only after a login with the app key alone', () => {
  const proof = body(servers, 'proofArgs');
  for (const option of ['-F none', '-i \\"{s}\\"', 'IdentitiesOnly=yes', 'IdentityAgent=none', 'BatchMode=yes', 'StrictHostKeyChecking=accept-new']) {
    assert.ok(proof.includes(option), option);
  }
  const check = body(identity, 'check');
  assert.ok(check.indexOf('keys.addCommand(a, public_key)') >= 0, 'the app key is installed over the working connection');
  assert.ok(check.indexOf('servers.proofArgs(') < check.indexOf('keys.addCommand(a, public_key)'), 'try the app key before any old sign-in');
  assert.match(check, /if \(existing\.ok or slot\.owned\) \{[\s\S]*?return;/);
  assert.ok(check.includes('-o IdentityAgent=none -o IdentitiesOnly=yes -o BatchMode=yes'), 'bootstrap never contacts an agent');
  assert.match(check, /finish\(i, proven\.ok, servers\.failureReason\(proven\.text\)\)/);
  const publish = body(identity, 'publish');
  assert.ok(publish.indexOf('sameAddresses(') < publish.indexOf('console.setSshConfig(config)'), 'settings switch on only after ssh reads them back');
  assert.match(publish, /if \(!any_forced\) \{\s*console\.setSshConfig\(null\);/);
});

test('IGSH-1928 failed server retries run from the existing timer without waiting on a worker', () => {
  assert.match(read('src/main.zig'), /if \(wp == TIMER_UPDATE_CHECK\) \{\s*updateCardPoll\(\);\s*@import\("ssh_identity\.zig"\)\.retry\(\);/);
  const retry = body(identity, 'retry');
  assert.match(retry, /if \(!started\.load\(\.acquire\) or running\.load\(\.acquire\)\) return;/);
  assert.match(retry, /if \(!lock\.tryLock\(\)\) return;/);
  assert.match(retry, /servers\.needsMigration\(slot, now\)/);
  assert.match(retry, /lock\.unlock\(\);\s*if \(due\) _ = launch\(\.startup\);/);
  assert.match(body(identity, 'launch'), /if \(running\.swap\(true, \.acq_rel\)\)/);
  assert.match(body(identity, 'worker'), /servers\.needsMigration\(table\[i\], now\)/);
});

test('IGSH-1928 removed app-owned servers stay removed after restart', () => {
  assert.match(body(identity, 'remove'), /table\[i\] = \.\{ \.status = \.removed \};/);
  assert.match(body(identity, 'seed'), /if \(!empty\) continue;/);
  assert.match(body(identity, 'seed'), /const empty = table\[i\]\.status == \.empty;/);
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
