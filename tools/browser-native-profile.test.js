const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const own = read('src/browser_own_profile.zig');
const before = read('tools/fixtures/igsh-726/browser-profile-command-before.zig');
const pane = read('src/browser_pane.zig');
const bridge = read('src/bridge.zig');
const worker = read('extension/bridge.js');
const ownToken = 'own-adee37bbc9fa6013ec24ccfd';

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  const end = source.indexOf('\n}\n', start);
  assert.ok(end > start, name);
  return source.slice(source.indexOf('{', start) + 1, end);
}

function qualify(source, original, value) {
  const code = body(source, 'command')
    .replace(/\b(value|original)\.len\b/g, '$1.length')
    .replaceAll('std.fmt.bufPrint(buf, ', 'format(')
    .replaceAll('std.mem.indexOfScalarPos(u8, original, 1, \'"\') orelse return error.InvalidProfileCommand', 'indexOfQuote(original)')
    .replaceAll('return error.InvalidProfileCommand', 'throw new Error("InvalidProfileCommand")')
    .replaceAll('original[0..end]', 'original.slice(0, end)')
    .replaceAll('original[end..]', 'original.slice(end)')
    .replaceAll('if (value.length == 0) "\\\"\\\"" else value', 'value.length == 0 ? "\\\"\\\"" : value')
    .replaceAll(' and ', ' && ')
    .replaceAll(' or ', ' || ')
    .replaceAll('.{', '[')
    .replaceAll('});', ']);');
  return vm.runInNewContext(`(() => { ${code} })()`, {
    original, value,
    isToken: token => /^own-[a-f0-9]{24}$/.test(token),
    indexOfQuote: text => {
      const index = text.indexOf('"', 1);
      if (index < 0) throw new Error('InvalidProfileCommand');
      return index;
    },
    format: (template, values) => {
      let index = 0;
      return template.replaceAll('{s}', () => values[index++]);
    },
  });
}

function selectedProfile(command, envProfile, fileProfile) {
  const match = command.match(/ --profile (""|[a-z0-9-]+)/);
  const profile_override = match ? match[1] === '""' ? '' : match[1] : null;
  const start = bridge.indexOf('    g_profile_token = if (is_legacy_host)');
  const end = bridge.indexOf('    if (is_native_host and !is_legacy_host)', start);
  assert.ok(start >= 0 && end > start);
  const code = bridge.slice(start, end)
    .replace('if (is_legacy_host) "" else', 'is_legacy_host ? "" :')
    .replaceAll(' orelse ', ' ?? ')
    .replaceAll(' and ', ' && ')
    .replaceAll('&g_window_file_profile', 'g_window_file_profile');
  return vm.runInNewContext(`${code}\ng_profile_token`, {
    g_profile_token: '', is_native_host: false, is_legacy_host: false,
    profile_override, profile_env: profile_override == null ? envProfile : null,
    g_window_file_profile_set: fileProfile != null, g_window_file_profile: fileProfile,
  });
}

const resolveCommand = '"bridge.exe" resolve-window --shell-id 3 --match "ZSPANE2-200" --owner-pid 100';

test('shared restore resolves on the shared pipe even when the last shell window file selects the own profile', () => {
  const command = qualify(own, resolveCommand, '');
  assert.equal(selectedProfile(command, null, ownToken), '');
  assert.match(command, / --profile "" resolve-window/);
});

test('the original shared command follows the inherited own-profile file and sends its nonce to the wrong worker', async () => {
  const command = qualify(before, resolveCommand, '');
  assert.equal(command, resolveCommand);
  assert.equal(selectedProfile(command, null, ownToken), ownToken);
  assert.equal(selectedProfile(qualify(own, resolveCommand, ''), ownToken, ownToken), '');
  const resolve = worker.match(/async function resolveWindow\(message\) \{[\s\S]*?\n\}/)[0];
  async function resolveInProfile(profile) {
    const context = {
      chrome: {
        windows: { getAll: async () => [{ id: 42, type: 'normal' }] },
        tabs: { query: async () => [{ id: 1, windowId: 42, url: `data:text/html,<title>${profile === '' ? 'ZSPANE2-200' : 'ZSPANE1-100'}</title>` }] },
      },
      loadProtectedWindows: async () => {}, protectedWindowMeta: new Map(),
      compactTab: tab => tab, isExtensionTab: () => false,
      isPaneBeaconTab: tab => tab.url.startsWith('data:text/html,<title>ZSPANE'),
      message: { shellId: 3, ownerPid: 100, match: 'ZSPANE2-200' },
    };
    return vm.runInNewContext(`${resolve}\nresolveWindow(message)`, context);
  }
  await assert.rejects(resolveInProfile(selectedProfile(command, null, ownToken)), /no window with tab url matching/);
  assert.equal((await resolveInProfile(selectedProfile(qualify(own, resolveCommand, ''), null, ownToken))).windowId, 42);
});

test('explicit own-profile commands and ambient terminal CLI inference remain intact', () => {
  assert.equal(qualify(own, resolveCommand, ownToken), `"bridge.exe" --profile ${ownToken}${resolveCommand.slice(12)}`);
  assert.equal(selectedProfile(qualify(own, resolveCommand, ownToken), 'other', null), ownToken);
  assert.equal(selectedProfile(resolveCommand, null, ownToken), ownToken);
  assert.equal(selectedProfile(resolveCommand, 'other', ownToken), 'other');
  assert.equal(selectedProfile(resolveCommand, null, null), '');
  for (const value of ['', ownToken, 'invalid']) {
    assert.throws(() => qualify(own, 'bridge.exe tabs', value), /InvalidProfileCommand/);
  }
  assert.throws(() => qualify(own, resolveCommand, 'invalid'), /InvalidProfileCommand/);
});

test('both app command paths qualify shared and own profiles before inheriting the process environment', () => {
  const spawn = body(pane, 'spawnBrowserCliForShell');
  assert.doesNotMatch(spawn, /if \(own_token\.len == 0\)/);
  assert.match(spawn, /browser_own_profile\.command\(&qualified_buf, cmd, own_token\)/);
  assert.match(spawn, /spawnBrowserCliHidden\(qualified\)/);
  assert.match(body(pane, 'browserWindowResolveWorker'), /browser_command_profile = job.profile;/);
  assert.match(body(pane, 'resolveBrowserWindowIdFromCommand'), /browser_own_profile\.command\(&qualified_buf, raw_cmd, std.mem.sliceTo\(&browser_command_profile, 0\)\)/);
  assert.match(body(bridge, 'resolveWindowFromEnv'), /g_window_file_profile_set = true/);
  assert.match(body(bridge, 'requestBrowserForWindow'), /isolatedPipeName\(&pipe_name_buf, profile_token\)/);
  assert.match(body(bridge, 'isolatedPipeName'), /if \(token.len == 0\) return isolated_pipe_name/);
});
