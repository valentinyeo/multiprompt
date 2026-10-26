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
  assert.match(lines.shift(), /^instruction: (?:multiprompt\.exe|ntdll\.dll|kernelbase\.dll|kernel32\.dll|user32\.dll|win32u\.dll|gdi32\.dll|gdi32full\.dll|dwrite\.dll)\+0x[0-9A-F]+$/);
  assert.equal(lines.shift(), 'stack_rvas:');
  let frames = 0;
  while (/^  0x[0-9A-F]+$/.test(lines[0])) { lines.shift(); frames++; }
  assert.ok(frames > 0 && frames <= 24, 'Missing main-thread code locations');
  assert.equal(lines.shift(), 'app_events (uptime_ms message_id tab_index view):');
  assert.ok(lines.length > 0 && lines.length <= 16);
  for (const line of lines) assert.match(line, /^  \d+ 0x[0-9A-F]+ \d+ (?:terminal|chat|browser|inbox|search|sessions|shortcuts|changelog)$/);
}

export function validateEvidence(directory) {
  validateFreezeReport(fs.readFileSync(path.join(directory, 'first-freeze.txt'), 'utf8'));
  const result = JSON.parse(fs.readFileSync(path.join(directory, 'result.json'), 'utf8'));
  assert.equal(result.healthyReports, 0);
  assert.equal(result.firstStallReports, 1);
  assert.equal(result.secondStallReports, 2);
  assert.equal(result.restartNotice, true);
  assert.equal(result.privateTextAbsent, true);
  assert.match(result.exeHash, /^[0-9A-F]{64}$/);
  assert.ok(fs.statSync(path.join(directory, 'next-start.png')).size > 1000);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  validateEvidence(process.argv[2]);
  console.log('FREEZE_EVIDENCE_OK');
}
