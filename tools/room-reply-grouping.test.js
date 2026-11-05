const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, 'src', name), 'utf8');

function declaration(source, marker, indent = '') {
  const start = source.indexOf(marker);
  assert.notEqual(start, -1, `${marker} exists`);
  const end = source.indexOf(`\n${indent}}`, start);
  assert.notEqual(end, -1, `${marker} closes`);
  return source.slice(start, end + indent.length + 2) + (source[end + indent.length + 2] === ';' ? ';' : '');
}

function line(source, marker) {
  const start = source.indexOf(marker);
  assert.notEqual(start, -1, `${marker} exists`);
  return source.slice(start, source.indexOf('\n', start));
}

test('desktop replay groups reversed and paged room answers under their questions', () => {
  const frontend = read('room_frontend.zig');
  const view = read('room_view.zig');
  const controller = read('rooms.zig');
  const source = `
const std = @import("std");
const avatar = struct { pub const Appearance = struct { face: u8, color: u8 }; };
const room_view = struct {
    pub const Member = struct {};
    ${declaration(view, 'pub const Author = struct {')}
    ${declaration(view, 'pub const Message = struct {')}
    ${declaration(view, 'pub const ViewModel = struct {')}
};
const rooms = struct {
    pub const Member = struct {};
    pub const Controller = struct {
        host: u8,
        host_uuid: [36]u8 = undefined,
        has_host_uuid: bool = false,
        ${declaration(controller, 'pub fn init(host: u8)', '    ')}
        ${declaration(controller, 'pub fn bindHost(', '    ')}
    };
};
${line(frontend, 'const HistoryMember = struct')}
${line(frontend, 'const MemberBinding = struct')}
${line(frontend, 'const HumanEvent = struct')}
${declaration(frontend, 'const OwnedModel = struct {')}
var building_model: ?*OwnedModel = null;
fn authorFrom(_: std.mem.Allocator, _: std.json.Value) ?HistoryMember { return null; }
${declaration(frontend, 'fn numberField(')}
${declaration(frontend, 'fn textField(')}
${declaration(frontend, 'fn wide(')}
${declaration(frontend, 'fn acceptEvents(')}
${fs.readFileSync(path.join(__dirname, 'fixtures/igsh-1732/room-replay.zig'), 'utf8')}
`;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'room-reply-grouping-'));
  try {
    fs.writeFileSync(path.join(dir, 'replay.zig'), source);
    const run = spawnSync(process.env.ZIG || 'zig', ['test', 'replay.zig'], { cwd: dir, encoding: 'utf8', timeout: 120000 });
    assert.equal(run.error, undefined, run.error?.message);
    assert.equal(run.status, 0, `${run.stdout || ''}${run.stderr || ''}`);
    assert.match(run.stderr, /All 1 tests passed/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
