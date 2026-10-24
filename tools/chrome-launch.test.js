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
  assert.match(builder, /--remote-debugging-pipe --enable-unsafe-extension-debugging/);
  const assertNoIoPipes = source => assert.doesNotMatch(source, /--remote-debugging-io-pipes/);
  assertNoIoPipes(builder);
  assert.throws(() => assertNoIoPipes(`${builder} --remote-debugging-io-pipes=123,456`));
  assert.match(builder, /for \(args\) \|arg\|[\s\S]*appendChromeArgument\(&command, arg\)/);
});

test('the production CRT fd table packs count, flags and unaligned pointer-width handles', () => {
  const code = body(bridge, 'chromePipeReserved2')
    .replace(/var buffer: \[[^\n]+ = undefined;/, 'const buffer = Buffer.alloc(4 + 5 * (1 + handleBytes));')
    .replace('std.mem.writeInt(u32, buffer[0..4], 5, .little);', 'buffer.writeUInt32LE(5, 0);')
    .replace('@memset(buffer[4..9], 0);', 'buffer.fill(0, 4, 9);')
    .replace('[_]usize{', '[')
    .replace('write_handle };', 'write_handle ];')
    .replaceAll('@intFromPtr(INVALID_HANDLE_VALUE)', 'invalidHandle')
    .replaceAll('@sizeOf(usize)', 'handleBytes')
    .replace('for (handles, 0..) |handle, i|', 'for (const [i, handle] of handles.entries())')
    .replace('std.mem.writeInt(usize, buffer[offset..][0..handleBytes], handle, .little);', 'writeHandle(buffer, handle, offset);');
  for (const handleBytes of [4, 8]) {
    const invalidHandle = (1n << BigInt(handleBytes * 8)) - 1n;
    const read_handle = handleBytes === 4 ? 0x12345678n : 0x8877665544332211n;
    const write_handle = handleBytes === 4 ? 0x76543210n : 0xffeeddccbbaa0099n;
    const packed = vm.runInNewContext(`(() => { ${code} })()`, {
      Buffer, handleBytes, invalidHandle, read_handle, write_handle,
      writeHandle: (buffer, handle, offset) => handleBytes === 4 ? buffer.writeUInt32LE(Number(handle), offset) : buffer.writeBigUInt64LE(handle, offset),
    });
    assert.equal(packed.length, 4 + 5 * (1 + handleBytes));
    assert.deepEqual([...packed.subarray(0, 4)], [5, 0, 0, 0]);
    assert.deepEqual([...packed.subarray(4, 9)], [0, 0, 0, 9, 9]);
    [invalidHandle, invalidHandle, invalidHandle, read_handle, write_handle].forEach((handle, fd) => {
      for (let byte = 0; byte < handleBytes; byte++) {
        assert.equal(packed[9 + fd * handleBytes + byte], Number((handle >> BigInt(byte * 8)) & 255n));
      }
    });
  }
  assert.match(bridge, /test "IGSH-738 Chrome reserved2 packs CRT flags and unaligned fd 3 and 4 handles"/);
});

function loadUnpackedFailed(reply) {
  const wrap = value => {
    if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
      const entries = new Map(Object.entries(value).map(([key, item]) => [key, wrap(item)]));
      return { kind: 'object', object: { get: key => entries.get(key), contains: key => entries.has(key) } };
    }
    return { kind: Number.isInteger(value) ? 'integer' : value === null ? 'null' : Array.isArray(value) ? 'array' : typeof value, integer: value };
  };
  const code = body(bridge, 'chromeLoadUnpackedFailed')
    .replace(/const parsed = std\.json\.parseFromSlice[^\n]+/, 'let parsed; try { parsed = { value: wrap(JSON.parse(reply)) }; } catch { return false; }')
    .replace('defer parsed.deinit();', '')
    .replace('parsed.value != .object', "parsed.value.kind !== 'object'")
    .replace('orelse return false', '; if (id === undefined) return false')
    .replace('id == .integer', "id.kind === 'integer'")
    .replaceAll(' and ', ' && ');
  return vm.runInNewContext(`(() => { ${code} })()`, { reply, wrap });
}

test('the production reply classifier accepts only id 1 errors', () => {
  assert.equal(loadUnpackedFailed('{"id":1,"error":{"message":"denied"}}'), true);
  for (const reply of ['{"id":1,"result":{}}', '{"id":2,"error":{}}', '{"error":{}}', '{"id":"1","error":{}}', 'null', '[]', 'invalid']) {
    assert.equal(loadUnpackedFailed(reply), false, reply);
  }
});

test('the production drain handles split/coalesced frames and keeps draining after errors or oversized frames', () => {
  const code = body(bridge, 'drainChromePipe')
    .replace('defer _ = CloseHandle(pipe);', '')
    .replace('var buffer: [4096]u8 = undefined;', 'const buffer = Buffer.alloc(4096);')
    .replace('var message = std.array_list.Managed(u8).init(std.heap.page_allocator);', '')
    .replace('defer message.deinit();', '')
    .replace('var discard = false;', 'let discard = false;')
    .replace(/var read: u32 = 0;\s*if \(ReadFile[^\n]+/, 'const chunk = chunks.shift(); if (!chunk) return; const read = chunk.length; chunk.copy(buffer);')
    .replace('for (buffer[0..read]) |byte|', 'for (const byte of buffer.subarray(0, read))')
    .replace('!discard and ', '!discard && ')
    .replace('std.debug.print("Chrome Extensions.loadUnpacked failed (CDP id 1).\\n", .{});', 'stderr.push("Chrome Extensions.loadUnpacked failed (CDP id 1).\\n");')
    .replace('message.items.len', 'message.items.length')
    .replace(/message.append\(byte\) catch \{\s*discard = true;\s*\};/, 'try { message.append(byte); } catch { discard = true; }');
  const failure = '{"id":1,"error":{"message":"denied"}}';
  const frames = `{"id":2,"error":{}}\0${failure}\0{"id":1,"result":{}}\0`;
  for (const chunks of [[Buffer.from(frames)], [...Buffer.from(frames)].map(byte => Buffer.from([byte]))]) {
    const stderr = [];
    const message = { items: [], append(byte) { this.items.push(byte); }, clearRetainingCapacity() { this.items = []; } };
    vm.runInNewContext(`(() => { ${code} })()`, { Buffer, chunks, message, stderr, max_native_message: 128, chromeLoadUnpackedFailed: bytes => loadUnpackedFailed(Buffer.from(bytes).toString()) });
    assert.deepEqual(stderr, ['Chrome Extensions.loadUnpacked failed (CDP id 1).\n']);
    assert.equal(chunks.length, 0);
  }
  for (const failAppend of [false, true]) {
    const chunks = [Buffer.from(`${'x'.repeat(129)}\0${failure}\0`)];
    const stderr = [];
    const message = { items: [], append(byte) { if (failAppend && byte === 120) throw Error('allocation failed'); this.items.push(byte); }, clearRetainingCapacity() { this.items = []; } };
    vm.runInNewContext(`(() => { ${code} })()`, { Buffer, chunks, message, stderr, max_native_message: 128, chromeLoadUnpackedFailed: bytes => loadUnpackedFailed(Buffer.from(bytes).toString()) });
    assert.equal(stderr.length, 1);
    assert.equal(chunks.length, 0);
  }
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
  assert.match(launch, /var reserved2 = chromePipeReserved2\(@intFromPtr\(child_read\), @intFromPtr\(child_write\)\)/);
  assert.match(launch, /si\.cbReserved2 = @intCast\(reserved2\.len\)/);
  assert.match(launch, /si\.lpReserved2 = &reserved2/);
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
