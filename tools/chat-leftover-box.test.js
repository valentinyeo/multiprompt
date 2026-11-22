const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');

test('wrapped no-break-space leftovers never join a new send or return as a human draft', () => {
  const script = `
import runpy, unittest
module = runpy.run_path('tools/chat-history-reader-test.py')
suite = unittest.TestSuite(unittest.defaultTestLoader.loadTestsFromTestCase(module[name]) for name in (
    'IGSH_1652_LeftoverBoxTest', 'IGSH_1647_PictureLinkSendTest', 'IGSH_1266_PreserveDraftHostTest'))
result = unittest.TextTestRunner(verbosity=2).run(suite)
raise SystemExit(not result.wasSuccessful())
`;
  const run = spawnSync('python3', ['-B', '-c', script], { encoding: 'utf8', timeout: 30000 });
  assert.equal(run.status, 0, run.stdout + run.stderr);
});
