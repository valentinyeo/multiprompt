import test from 'node:test';
import assert from 'node:assert/strict';
import { noteBands } from './chat-notes-proof.mjs';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const frame = { scale: 1, transcript: { left: 10, top: 10, width: 380, height: 580 } };
function image(gap = 32, extra = 0, count = 5) {
  const width = 400;
  const height = 600;
  const pixels = Buffer.alloc(width * height * 4);
  for (let row = 0; row < count; row++) {
    const top = 30 + row * gap + (row > 0 ? extra : 0);
    for (let y = top; y < top + 8; y++) {
      for (let x = 40; x < 240; x += 3) pixels.writeUIntLE(0x787c84, (y * width + x) * 4, 3);
    }
  }
  return { width, height, pixels };
}

test('five compact dim rows are detected from painted pixels', () => {
  assert.equal(noteBands(image(), frame).rows.length, 5);
});
test('blank or missing runner rows cannot pass', () => {
  assert.throws(() => noteBands(image(32, 0, 0), frame), /five compact runner rows/);
  assert.throws(() => noteBands(image(32, 0, 4), frame), /five compact runner rows/);
});
test('tall messages fail the collapsed contract', () => {
  assert.throws(() => noteBands(image(80), frame), /full bubbles/);
});
test('expansion and collapse must change body space', () => {
  assert.throws(() => noteBands(image(), frame, true), /body disappeared/);
  assert.equal(noteBands(image(32, 220), frame, true).expanded, true);
  assert.throws(() => noteBands(image(32, 220), frame), /full bubbles/);
});

test('proof cache readers grant sharing needed by concurrent writers and replacement', async () => {
  const source = fs.readFileSync(new URL('./verify-chat-delivery/drive.ps1', import.meta.url), 'utf8');
  const share = source.match(/\$stream = \[IO\.File\]::Open\(\$Path, \[IO\.FileMode\]::Open, \[IO\.FileAccess\]::Read, (.+)\)/)[1];
  const { runInNewContext } = await import('node:vm');
  const expression = share.replaceAll('[IO.FileShare]::ReadWrite', '3').replaceAll('[IO.FileShare]::Delete', '4').replaceAll('-bor', '|');
  assert.equal(runInNewContext(expression) & 7, 7);
});

test('reading the transcript cache allows atomic replacement during native proof', { skip: process.platform !== 'win32' }, () => {
  const source = fs.readFileSync(new URL('./verify-chat-delivery/drive.ps1', import.meta.url), 'utf8');
  const reader = source.slice(source.indexOf('function Read-Shared('), source.indexOf('function Step('));
  const open = reader.match(/\$stream = ([^\r\n]+)/)[1];
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'notes-cache-sharing-'));
  const script = expression => `
$ErrorActionPreference = 'Stop'
${reader}
$Path = Join-Path $env:NOTES_CACHE_TEST 'cache.jsonl'
[IO.File]::WriteAllText($Path, 'old transcript')
[IO.File]::WriteAllText(($Path + '.next'), 'new transcript')
$stream = ${expression}
try {
  [IO.File]::Replace(($Path + '.next'), $Path, ($Path + '.previous'))
  $old = [IO.StreamReader]::new($stream)
  try { if ($old.ReadToEnd() -cne 'old transcript') { throw 'Open reader lost its original snapshot' } } finally { $old.Dispose() }
} finally { $stream.Dispose() }
if ((Read-Shared $Path) -cne 'new transcript') { throw 'Next read missed the replacement' }
Write-Host 'CACHE_REPLACEMENT_WHILE_READING_OK'
`;
  const run = expression => spawnSync('powershell.exe', ['-NoProfile', '-Command', script(expression)], {
    encoding: 'utf8', timeout: 20000, env: { ...process.env, NOTES_CACHE_TEST: directory },
  });
  try {
    const red = run('[IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)');
    assert.notEqual(red.status, 0, red.stdout + red.stderr);
    assert.match(red.stderr, /being used by another process/);
    const green = run(open);
    assert.equal(green.status, 0, green.stdout + green.stderr);
    assert.match(green.stdout, /CACHE_REPLACEMENT_WHILE_READING_OK/);
  } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});
