import test from 'node:test';
import assert from 'node:assert/strict';
import { validateFreezeReport } from './freeze-recorder-proof.mjs';

const report = `multiprompt freeze report
version: 0.28.1
time_unix: 1793016000
unresponsive_ms: 6001
thread_context: captured
instruction: ntdll.dll+0x1234
stack_rvas:
  0x4321
app_events (uptime_ms message_id tab_index view):
  1000 0x113 0 terminal
`;

test('accept only diagnostic fields with code locations and numeric app events', () => {
  validateFreezeReport(report);
  validateFreezeReport(report.replace('terminal', 'chat'));
});

test('reject private text in every field and extra raw log lines', () => {
  const lines = report.trimEnd().split('\n');
  for (let i = 0; i < lines.length; i++) {
    const changed = [...lines];
    changed[i] += ' private-message-host-path';
    assert.throws(() => validateFreezeReport(changed.join('\n')), `field ${i}`);
  }
  assert.throws(() => validateFreezeReport(report + 'debug_log_tail: private-text\n'));
});

test('reject missing reports, missing stuck location, early triggers and uncaptured context', () => {
  for (const invalid of ['', report.replace('  0x4321\n', ''), report.replace('6001', '5000'), report.replace('captured', 'unavailable'), report.replace('ntdll.dll+0x1234', 'unavailable')]) {
    assert.throws(() => validateFreezeReport(invalid));
  }
});
