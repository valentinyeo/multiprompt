import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { assertDriverTypable, driverTypableViolations } from './keyboard-driver.mjs';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const spec = JSON.parse(fs.readFileSync(path.join(root, 'tools/verify-server-chat/skill-quote.json'), 'utf8'));
const drive = fs.readFileSync(path.join(root, 'tools/verify-server-chat/drive.ps1'), 'utf8');

test('SOFT-3097 skill-quote typed strings stay inside the desktop driver keyboard map', () => {
  assertDriverTypable('skill-quote.busyPrime', spec.busyPrime);
  for (const [name, message] of [['send', 'windows send proof'], ['clear', '/clear'], ['after-clear', 'windows after clear']]) {
    assertDriverTypable(name, message);
  }
  assertDriverTypable('palette chat view select all', 'chat view select all');
});

test('SOFT-3097 skill-quote compose uses clipboard paste when quotes contain unmappable text', () => {
  const skillText = spec.compose.join('\n');
  assert.ok(driverTypableViolations(skillText).length > 0, 'quoted skill text must include paste-only characters');
  assert.match(drive, /Paste-Line \$skillText/);
  assert.doesNotMatch(drive, /Submit-Line \$skillText|Type-Text \$skillText/);
});