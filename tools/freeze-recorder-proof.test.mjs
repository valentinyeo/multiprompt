import test from 'node:test';
import assert from 'node:assert/strict';
import * as proof from './freeze-recorder-proof.mjs';
const { validateFreezeReport } = proof;

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

test('health receipts require actual coverage without gaps, freezes or private trace text', () => {
  const { validateWatchdogHealth } = proof;
  assert.equal(typeof validateWatchdogHealth, 'function', 'health receipt oracle exists');
  const row = { report_id: 'watchdog-100-2-300-0', captured_at: 160, summary: 'Windows watchdog health', thread: 'watchdog', android_version: 'Windows', stack_trace: 'observed_ms: 60000\nresponsive_ms: 59500\nunobserved_ms: 0\nfreezes: 0\n' };
  validateWatchdogHealth(row);
  for (const patch of [
    { stack_trace: row.stack_trace.replace('59500', '61000') },
    { stack_trace: row.stack_trace.replace('freezes: 0', 'freezes: 1') },
    { stack_trace: row.stack_trace.replace('unobserved_ms: 0', 'unobserved_ms: 10000') },
    { stack_trace: row.stack_trace + 'private text\n' },
    { captured_at: 110 },
    { thread: 'main' },
  ]) assert.throws(() => validateWatchdogHealth({ ...row, ...patch }));
});

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
