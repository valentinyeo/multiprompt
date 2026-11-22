const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../src/browser_pane.zig'), 'utf8').replace(/\r\n/g, '\n');
const marker = 'test "IGSH-523 docked pane without an extension never resolves on health ticks" {';
const start = source.indexOf(marker);
assert.notEqual(start, -1);
const fixture = source.slice(start, source.indexOf('\n}', start) + 2);

function responsiveFixture(text) {
  const loop = text.slice(text.indexOf('for (0..5)'));
  assert.match(loop, /PeekMessageW\(&message, null, 0, 0, 0\);\s*try std\.testing\.expectEqual\(@as\(BOOL, 0\), IsHungAppWindow\(hwnd\)\);\s*browserHealthTick\(\);/);
  for (const observation of [
    'expectEqual(hwnd, app_state.shells[0].browser_hwnd)',
    'expectEqual(@as(u8, 0), app_state.shells[0].browser_health_misses)',
    'expectEqual(@as(u32, 0), entry.shell_id)',
    'expectEqual(@as(i64, 0), app_state.shells[0].browser_window_id)',
    'expectEqualStrings("connected", browserConnectionState(&app_state.shells[0]))',
  ]) assert.ok(loop.includes(observation), observation);
}

test('health fixture observes a responsive owned window before asserting connected', () => {
  responsiveFixture(fixture);
  for (const line of fixture.slice(fixture.indexOf('for (0..5)')).split('\n').filter(line => /PeekMessageW|IsHungAppWindow|try std\.testing/.test(line))) {
    assert.throws(() => responsiveFixture(fixture.replace(line, '')), { code: 'ERR_ASSERTION' });
  }
});
