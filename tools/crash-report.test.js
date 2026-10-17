'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { parseCrashReport, symbolizerArgs, parseSymbolizerOutput } = require('./crash-report.js');

const SAMPLE = [
  'multiprompt crash report',
  'version: 0.28.693',
  'build: stable',
  'time: 2026-10-11 13:45:01 (local)',
  'kind: exception',
  'exception_code: 0xC0000005 (ACCESS_VIOLATION)',
  'exception_address: 0x0000000140001234',
  'access: write at 0x0000000000000000',
  'module: multiprompt.exe',
  'module_base: 0x0000000140000000',
  'module_offset: 0x1234',
  'exe_base: 0x0000000140000000',
  'exe_offset: 0x1234 (address minus exe base; match with the .pdb)',
  'thread_id: 77',
  'tabs: 12',
  'chat_view: on',
  'stack_rvas (exe offsets found on the stack, nearest first):',
  '  0x2000',
  '  0x3abc',
  'debug_log_tail (last 200 lines):',
  'line one',
  'tabs: 99',
  '',
].join('\n');

test('parseCrashReport reads fields, offsets and stack candidates', () => {
  const r = parseCrashReport(SAMPLE);
  assert.strictEqual(r.fields.version, '0.28.693');
  assert.strictEqual(r.exeOffset, 0x1234);
  assert.deepStrictEqual(r.stackRvas, [0x2000, 0x3abc]);
  assert.match(r.logTail, /line one/);
});

test('log tail lines never overwrite report fields', () => {
  const r = parseCrashReport(SAMPLE);
  assert.strictEqual(r.fields.tabs, '12');
});

test('a report without an exe offset gives null', () => {
  const r = parseCrashReport('exe_offset: n/a (address is outside multiprompt.exe)\n');
  assert.strictEqual(r.exeOffset, null);
});

test('symbolizerArgs passes hex offsets as RVAs', () => {
  const a = symbolizerArgs('multiprompt.exe', [0x1234, 0x20]);
  assert.ok(a.includes('--relative-address'));
  assert.ok(a.includes('--obj=multiprompt.exe'));
  assert.deepStrictEqual(a.slice(-2), ['0x1234', '0x20']);
});

test('parseSymbolizerOutput pairs one block per address', () => {
  const out = 'main.wndProc\nsrc/main.zig:10:3\n\nmain.other\nsrc/main.zig:20:1\n\n';
  assert.deepStrictEqual(parseSymbolizerOutput(out, 2), [
    { fn: 'main.wndProc', where: 'src/main.zig:10:3' },
    { fn: 'main.other', where: 'src/main.zig:20:1' },
  ]);
});
