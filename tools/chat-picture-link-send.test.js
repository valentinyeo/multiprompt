const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');

test('picture links submit once, retry swallowed Enter and report a full box as not sent', () => {
  const script = `
import runpy, unittest
module = runpy.run_path('tools/chat-history-reader-test.py')
suite = unittest.TestSuite(unittest.defaultTestLoader.loadTestsFromTestCase(module[name]) for name in (
    'IGSH_1647_PictureLinkSendTest', 'IGSH_1266_PreserveDraftHostTest'))
result = unittest.TextTestRunner(verbosity=2).run(suite)
raise SystemExit(not result.wasSuccessful())
`;
  const run = spawnSync('python3', ['-B', '-c', script], { encoding: 'utf8', timeout: 30000 });
  assert.equal(run.status, 0, run.stdout + run.stderr);
});
