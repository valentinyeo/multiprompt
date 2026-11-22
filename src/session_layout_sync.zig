const std = @import("std");

pub const remote_command = "python3 -c 'import base64,sys;exec(base64.b64decode(sys.stdin.buffer.readline()))' ";
pub const server_script =
    \\import os, sys, json, tempfile, fcntl, time, re
    \\from pathlib import Path
    \\LIMIT = 1024 * 1024
    \\def text(s, n):
    \\    return isinstance(s, str) and 0 < len(s.encode('utf-16-le')) // 2 <= n and all(ord(c) >= 32 and ord(c) != 127 for c in s)
    \\def validate(x):
    \\    if not isinstance(x, dict) or set(x) != {'schema', 'revision', 'workspaces', 'tabs'} or type(x['schema']) is not int or x['schema'] != 1:
    \\        raise ValueError('unsupported layout')
    \\    if type(x['revision']) is not int or not 0 <= x['revision'] < 2**64 - 1:
    \\        raise ValueError('invalid revision')
    \\    ws, tabs = x['workspaces'], x['tabs']
    \\    if not isinstance(ws, list) or not isinstance(tabs, list) or len(ws) > 64 or len(tabs) > 4096:
    \\        raise ValueError('layout too large')
    \\    names, ids = set(), set()
    \\    for w in ws:
    \\        if not isinstance(w, dict) or set(w) != {'name'} or not text(w['name'], 32) or len(w['name'].encode('utf-8')) > 32 or w['name'] in names:
    \\            raise ValueError('invalid workspace')
    \\        names.add(w['name'])
    \\    for t in tabs:
    \\        if not isinstance(t, dict) or set(t) != {'kind', 'name', 'tmux_session', 'tmux_host', 'workspace'}:
    \\            raise ValueError('nonportable tab')
    \\        if t['kind'] != 'tmux' or not text(t['name'], 64) or type(t['tmux_host']) is not int or t['tmux_host'] not in (0, 1, 2):
    \\            raise ValueError('invalid tab')
    \\        if not isinstance(t['tmux_session'], str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,63}', t['tmux_session']) or t['workspace'] not in names:
    \\            raise ValueError('invalid target')
    \\        key = (t['tmux_host'], t['tmux_session'])
    \\        if key in ids:
    \\            raise ValueError('duplicate tab')
    \\        ids.add(key)
    \\    return x
    \\def read(stream):
    \\    raw = stream.read(LIMIT)
    \\    if len(raw) >= LIMIT:
    \\        raise ValueError('layout too large')
    \\    return validate(json.loads(raw))
    \\root = Path.home() / '.local/share/multiprompt'
    \\os.umask(0o077)
    \\root.mkdir(parents=True, exist_ok=True, mode=0o700)
    \\root.chmod(0o700)
    \\path = root / 'layout.json'
    \\if sys.argv[1] == 'pull':
    \\    with path.open('rb') as f:
    \\        value = read(f)
    \\    print(json.dumps(value, ensure_ascii=True, separators=(',', ':')))
    \\elif sys.argv[1] == 'publish':
    \\    incoming = read(sys.stdin.buffer)
    \\    with (root / 'layout.lock').open('a') as lock:
    \\        deadline = time.monotonic() + 8
    \\        while True:
    \\            try:
    \\                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    \\                break
    \\            except BlockingIOError:
    \\                if time.monotonic() >= deadline:
    \\                    raise TimeoutError('layout lock timed out')
    \\                time.sleep(0.05)
    \\        old = {'schema': 1, 'revision': 0, 'workspaces': [], 'tabs': []}
    \\        if path.exists():
    \\            with path.open('rb') as f:
    \\                old = read(f)
    \\        names = {w['name'] for w in incoming['workspaces']}
    \\        ids = {(t['tmux_host'], t['tmux_session']) for t in incoming['tabs']}
    \\        incoming['workspaces'] += [w for w in old['workspaces'] if w['name'] not in names]
    \\        incoming['tabs'] += [t for t in old['tabs'] if (t['tmux_host'], t['tmux_session']) not in ids]
    \\        incoming['revision'] = old['revision'] + 1
    \\        validate(incoming)
    \\        raw = json.dumps(incoming, ensure_ascii=True, separators=(',', ':')).encode()
    \\        if len(raw) >= LIMIT:
    \\            raise ValueError('layout too large')
    \\        fd, tmp = tempfile.mkstemp(prefix='.layout-', dir=root)
    \\        try:
    \\            with os.fdopen(fd, 'wb') as f:
    \\                f.write(raw)
    \\                f.flush()
    \\                os.fsync(f.fileno())
    \\            os.replace(tmp, path)
    \\            d = os.open(root, os.O_RDONLY | os.O_DIRECTORY)
    \\            try:
    \\                os.fsync(d)
    \\            finally:
    \\                os.close(d)
    \\        finally:
    \\            if os.path.exists(tmp):
    \\                os.unlink(tmp)
    \\        print('MP_LAYOUT_PUBLISHED:' + str(incoming['revision']))
    \\else:
    \\    raise ValueError('unknown operation')
;

pub fn frame(a: std.mem.Allocator, json: []const u8) ![]u8 {
    const n = std.base64.standard.Encoder.calcSize(server_script.len);
    const bytes = try a.alloc(u8, n + 1 + json.len);
    _ = std.base64.standard.Encoder.encode(bytes[0..n], server_script);
    bytes[n] = '\n';
    @memcpy(bytes[n + 1 ..], json);
    return bytes;
}

test "SSH frame keeps the program and arbitrary JSON out of shell interpolation" {
    const json = "{\"name\":\"Kraków ' \\\" $HOME ; 🚀\"}";
    const bytes = try frame(std.testing.allocator, json);
    defer std.testing.allocator.free(bytes);
    const end = std.mem.indexOfScalar(u8, bytes, '\n').?;
    const size = try std.base64.standard.Decoder.calcSizeForSlice(bytes[0..end]);
    const decoded = try std.testing.allocator.alloc(u8, size);
    defer std.testing.allocator.free(decoded);
    try std.base64.standard.Decoder.decode(decoded, bytes[0..end]);
    try std.testing.expectEqualStrings(server_script, decoded);
    try std.testing.expectEqualStrings(json, bytes[end + 1 ..]);
}
