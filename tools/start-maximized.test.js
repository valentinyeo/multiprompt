const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function assertFirstShow(plan) {
  assert.match(plan, /pub fn firstShowCommand\(\) i32 \{\s*return 8;\s*\}/);
  assert.match(plan, /test "IGSH-587 first show preserves maximized creation state without activation" \{\s*try std\.testing\.expectEqual\(@as\(i32, 8\), firstShowCommand\(\)\);/);
}

test('IGSH-587 first show uses SW_SHOWNA to retain maximization without activation', () => {
  const plan = read('src/launch_plan.zig');
  assertFirstShow(plan);
  assert.throws(() => assertFirstShow(plan.replace('return 8;', 'return 5;')));
  assert.throws(() => assertFirstShow(plan.replace('return 8;', 'return 4;')));
  const build = read('build.zig');
  assert.match(build, /root_source_file = b\.path\("src\/launch_plan\.zig"\)/);
  assert.match(build, /test_step\.dependOn\(&run_launch_plan_tests\.step\)/);
  assert.match(build, /vps_test_step\.dependOn\(&run_launch_plan_tests\.step\)/);
});
