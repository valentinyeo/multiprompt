import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export function validateFreezeReport(text) {
  const lines = text.trimEnd().split(/\r?\n/);
  assert.equal(lines.shift(), 'multiprompt freeze report');
  assert.match(lines.shift(), /^version: \d+\.\d+\.\d+$/);
  assert.match(lines.shift(), /^time_unix: \d+$/);
  const duration = /^unresponsive_ms: (\d+)$/.exec(lines.shift());
  assert.ok(duration && Number(duration[1]) > 5000);
  assert.equal(lines.shift(), 'thread_context: captured');
  if (lines[0]?.startsWith('reason:')) assert.match(lines.shift(), /^reason: [12]$/);
  if (lines[0]?.startsWith('frame_size:')) {
    assert.match(lines.shift(), /^frame_size: -?\d+ -?\d+$/);
    assert.match(lines.shift(), /^client_size: -?\d+ -?\d+$/);
  }
  assert.match(lines.shift(), /^instruction: (?:multiprompt\.exe|ntdll\.dll|kernelbase\.dll|kernel32\.dll|user32\.dll|win32u\.dll|gdi32\.dll|gdi32full\.dll|dwrite\.dll)\+0x[0-9A-F]+$/);
  assert.equal(lines.shift(), 'stack_rvas:');
  let frames = 0;
  while (/^  0x[0-9A-F]+$/.test(lines[0])) { lines.shift(); frames++; }
  assert.ok(frames > 0 && frames <= 24, 'Missing main-thread code locations');
  assert.equal(lines.shift(), 'app_events (uptime_ms message_id tab_index view):');
  assert.ok(lines.length > 0 && lines.length <= 16);
  for (const line of lines) assert.match(line, /^  \d+ 0x[0-9A-F]+ \d+ (?:terminal|chat|browser|inbox|search|sessions|shortcuts|changelog)$/);
}

export function validateWatchdogHealth(row) {
  assert.equal(row.summary, 'Windows watchdog health');
  assert.equal(row.thread, 'watchdog');
  assert.equal(row.android_version, 'Windows');
  const identity = /^watchdog-(\d+)-(\d+)-(\d+)-0$/.exec(row.report_id);
  assert.ok(identity, 'typed first watchdog receipt identity');
  const fields = /^observed_ms: (\d+)\nresponsive_ms: (\d+)\nunobserved_ms: (\d+)\nfreezes: (\d+)\n$/.exec(row.stack_trace);
  assert.ok(fields, 'numeric-only coverage receipt');
  const [observed, responsive, unobserved, freezes] = fields.slice(1).map(Number);
  assert.ok(observed >= 60000 && responsive >= 55000 && responsive <= observed);
  assert.equal(unobserved, 0);
  assert.equal(freezes, 0);
  assert.ok(observed <= (row.captured_at - Number(identity[1]) + 2) * 1000);
}

export function validateEvidence(directory) {
  validateFreezeReport(fs.readFileSync(path.join(directory, 'first-freeze.txt'), 'utf8'));
  const result = JSON.parse(fs.readFileSync(path.join(directory, 'result.json'), 'utf8'));
  if (result.watchdogHealth) validateWatchdogHealth(JSON.parse(fs.readFileSync(path.join(directory, 'watchdog-health.json'), 'utf8').replace(/^\uFEFF/, '')));
  assert.equal(result.healthyReports, 0);
  assert.equal(result.firstStallReports, 1);
  assert.equal(result.secondStallReports, 2);
  assert.equal(result.restartNoticePixels, 0);
  assert.ok(result.userActionNoticePixels >= 10, 'Explicit user action must still paint its reply');
  assert.equal(result.privateTextAbsent, true);
  assert.match(result.exeHash, /^[0-9A-F]{64}$/);
  assert.ok(fs.statSync(path.join(directory, 'next-start.png')).size > 1000);
  assert.ok(fs.statSync(path.join(directory, 'user-action.png')).size > 1000);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  validateEvidence(process.argv[2]);
  console.log('FREEZE_EVIDENCE_OK');
}
