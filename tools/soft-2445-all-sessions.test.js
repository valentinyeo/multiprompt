const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');

const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('SOFT-2445 session row behavior', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'all-sessions-'));
  try {
    const archive = read('src/archive.zig');
    const start = archive.indexOf('fn allSessionsRowTab(');
    const end = archive.indexOf('fn sessionOverviewRowsRamMb(', start);
    assert.ok(start >= 0 && end > start);
    copyZig(['all_sessions_model.zig'], dir);
    const harness = `const overview = @import("all_sessions_model.zig");
const SessionOverviewRow = overview.Row;
const AS_ROW_OTHER: u8 = 255;
const AS_TAB_ALL: u32 = 200;
const AS_TAB_OTHER: u32 = 201;
const AS_TAB_WAITING: u32 = 202;
const AS_TAB_ARCHIVED: u32 = 203;
${archive.slice(start, end)}
${read('tools/fixtures/SOFT-2445/waiting.zig')}
${read('tools/fixtures/SOFT-2445/rows.zig')}`;
    fs.writeFileSync(path.join(dir, 'fixture.zig'), harness);
    const result = spawnSync(process.env.ZIG || process.env.ZIG_EXE || 'zig', ['test', 'fixture.zig'], {
      cwd: dir, encoding: 'utf8', timeout: 120000,
    });
    assert.equal(result.status, 0, `${result.error || ''}\n${result.stdout}\n${result.stderr}`);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
