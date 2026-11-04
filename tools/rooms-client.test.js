const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');

for (const source of ['src/room_message.zig', 'src/room_journal.zig', 'src/rooms.zig']) {
  test(`desktop rooms protocol: ${source}`, () => {
    assert.ok(fs.existsSync('src/room_message.zig'), 'Rooms must plan explicit recipients before persisting a message');
    const result = spawnSync(process.env.ZIG || process.env.ZIG_EXE || 'zig', ['test', source], {
      encoding: 'utf8', timeout: 180000, maxBuffer: 8 * 1024 * 1024,
    });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
  });
}
