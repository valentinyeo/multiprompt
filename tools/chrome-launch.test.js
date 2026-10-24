const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const bridge = fs.readFileSync(process.env.CHROME_LAUNCH_BRIDGE_SOURCE || path.join(root, 'src/bridge.zig'), 'utf8');
const pane = read('src/browser_pane.zig');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  const end = source.indexOf('\n}', start);
  assert.ok(end > start, name);
  return source.slice(source.indexOf('{', start) + 1, end);
}

function quoteArgument(arg) {
  let text = '';
  const code = body(bridge, 'appendChromeArgument')
    .replaceAll('try ', '')
    .replace('var slashes: usize', 'let slashes')
    .replace('for (arg) |c|', 'for (const c of arg)')
    .replace(/const count = if \(([^\n]+)\) ([^\n]+) else ([^\n]+);/, 'const count = ($1) ? $2 : $3;')
    .replace(/for \(0\.\.([^\n]+)\) \|_\|/g, 'for (let i = 0; i < $1; i++)');
  vm.runInNewContext(code, { arg, command: { append: c => { text += c; } } });
  return text;
}

test('the production Windows quoting algorithm preserves spaces, quotes and trailing slashes', () => {
  for (const [arg, expected] of [
    ['', '""'],
    ['C:\\Program Files\\Chrome\\chrome.exe', '"C:\\Program Files\\Chrome\\chrome.exe"'],
    ['trailing\\', '"trailing\\\\"'],
    ['embedded"quote', '"embedded\\"quote"'],
    ['slash\\"quote', '"slash\\\\\\"quote"'],
    ['Unicode-é', '"Unicode-é"'],
  ]) assert.equal(quoteArgument(arg), expected);
  const builder = body(bridge, 'buildChromeLaunchCommand');
  assert.match(builder, /appendChromeArgument\(&command, exe\)/);
  assert.match(builder, /--remote-debugging-pipe --enable-unsafe-extension-debugging --remote-debugging-io-pipes=\{d\},\{d\}/);
  assert.match(builder, /\.\{ read_handle, write_handle \}/);
  assert.match(builder, /for \(args\) \|arg\|[\s\S]*appendChromeArgument\(&command, arg\)/);
});

test('production loadUnpacked framing sends distinct NUL-delimited main and theme JSON messages', () => {
  const code = body(bridge, 'chromeLoadUnpackedMessage')
    .replace('var message = std.array_list.Managed(u8).init(allocator);', '')
    .replace('errdefer message.deinit();', '')
    .replaceAll('try ', '')
    .replace('appendJsonString(&message, path);', 'message.appendSlice(JSON.stringify(path));')
    .replace('.{id}', '[id]');
  const paths = ['C:\\Extension é\\quoted"path', 'C:\\Extension\\themes\\dark'];
  const frames = paths.map((extensionPath, index) => {
    let output = '';
    const message = {
      print: (template, [id]) => { output += template.replaceAll('{{', '{').replace('{d}', String(id)); },
      appendSlice: text => { output += text; },
      toOwnedSlice: () => output,
    };
    const frame = vm.runInNewContext(`(() => { ${code} })()`, { message, path: extensionPath, id: index + 1 });
    assert.equal(frame.at(-1), '\0');
    assert.equal(frame.split('\0').length, 2);
    assert.deepEqual(JSON.parse(frame.slice(0, -1)), { id: index + 1, method: 'Extensions.loadUnpacked', params: { path: extensionPath } });
    return frame;
  });
  assert.equal(frames.join('').split('\0').filter(Boolean).length, paths.length);
  assert.match(bridge, /test "IGSH-738 Chrome command preserves Windows arguments/);
  assert.match(bridge, /test "IGSH-738 loadUnpacked frames are NUL terminated JSON/);
  assert.match(read('build.zig'), /b\.addTest\(\.\{ \.root_module = bridge_exe\.root_module \}\)/);
});

test('pipe holder bypasses CLI deadlines and owns both pipes until the Chrome process exits', () => {
  assert.match(bridge, /chrome-launch <exe> <extension> <theme> \[args\.\.\.\]/);
  const badArgs = read('tools/bridge-bad-args.test.js');
  for (const invocation of ["['chrome-launch']", "['chrome-launch', 'chrome.exe']", "['chrome-launch', 'chrome.exe', 'extension']"]) assert.ok(badArgs.includes(invocation));
  const main = body(bridge, 'main');
  assert.ok(main.indexOf('return runChromeLaunch(allocator, &args)') >= 0);
  assert.ok(main.indexOf('return runChromeLaunch(allocator, &args)') < main.indexOf('commandDeadline'));
  const launch = body(bridge, 'runChromeLaunch');
  assert.match(launch, /\.bInheritHandle = 1/);
  assert.match(launch, /CreatePipe\(&child_read, &parent_write, &sa, 0\)/);
  assert.match(launch, /CreatePipe\(&parent_read, &child_write, &sa, 0\)/);
  assert.match(launch, /SetHandleInformation\(parent_write, 1, 0\)/);
  assert.match(launch, /SetHandleInformation\(parent_read, 1, 0\)/);
  assert.match(launch, /@intFromPtr\(child_read\), @intFromPtr\(child_write\)/);
  assert.match(launch, /CreateProcessW\(exe_w.ptr, command_w.ptr, null, null, 1, 0x08000000/);
  assert.match(launch, /drainChromePipe, \.\{parent_read\.\?\}/);
  assert.match(launch, /sendChromeExtension\(allocator, parent_write\.\?, 1, extension\)/);
  assert.match(launch, /sendChromeExtension\(allocator, parent_write\.\?, 2, theme\)/);
  assert.ok(launch.lastIndexOf('WaitForSingleObject(pi.hProcess, 0xFFFFFFFF)') > launch.indexOf('sendChromeExtension'));
  assert.match(body(bridge, 'drainChromePipe'), /while \(true\)[\s\S]*ReadFile/);
  assert.match(body(bridge, 'sendChromeExtension'), /try writeAll\(pipe, message\)/);
  assert.doesNotMatch(launch, /Browser\.close|Sleep|GetTickCount|commandDeadline/);
});

test('only native Chrome own profiles use a detached bridge while adoption remains HWND/profile based', () => {
  const launch = body(pane, 'shellExecuteEdgeUrl');
  assert.match(launch, /const chrome_bridge = native_chrome and app_state.g_browser_engine == \.chrome and browser_own_profile.isToken\(own_token\)/);
  assert.match(launch, /if \(chrome_bridge\)[\s\S]*chrome-launch/);
  assert.match(launch, /if \(chrome_bridge\) bridgeExePath\(\) else browserExePath\(\)/);
  assert.match(launch, /currentThemeToken\(\)/);
  assert.ok(launch.includes('appendEdgeExtensionLoadPaths(&params, &pos, extension_path);\n        appendBrowserWideAscii(&params, &pos, \"\\\" \");'));
  assert.match(launch, /browserLaunchWorker, \.\{ exe_w, params, nonce, app_state.g_main_hwnd, chrome_bridge \}/);
  const worker = body(pane, 'browserLaunchWorker');
  assert.match(worker, /CreateProcessW\([\s\S]*0x08000008/);
  assert.match(worker, /else \{\s+_ = ShellExecuteW/);
  assert.match(worker, /SetWinEventHook[\s\S]*browserLaunchEvent, 0, 0, 0/);
  const identity = body(pane, 'browserWindowProfileMatches');
  assert.match(identity, /GetWindowThreadProcessId\(hwnd, &pid\)/);
  assert.match(identity, /processCommandLine\(allocator, process\)/);
  assert.match(identity, /std.ascii.eqlIgnoreCase\(expected, actual\)/);
  assert.doesNotMatch(identity + body(pane, 'enumBrowserAdopt'), /parent[Pp]id|GetCurrentProcessId/);
});
