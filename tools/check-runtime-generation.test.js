import assert from 'node:assert/strict';
import test from 'node:test';
import { hostGenerationGuard } from './check-runtime-generation.mjs';

test('SOFT-3010 host rotate must not reference RUNTIME_GENERATION directly', () => {
  const ok = "def host_generation():\n  return 1\nhost_log('rotate', dict(generation=host_generation()))\n";
  const bad = "def host_generation():\n  return 1\nhost_log('rotate', dict(generation=RUNTIME_GENERATION))\n";
  assert.equal(hostGenerationGuard(ok).ok, true);
  assert.equal(hostGenerationGuard(bad).ok, false);
  assert.equal(hostGenerationGuard('print(1)\n').ok, false);
  assert.equal(hostGenerationGuard(null).ok, false);
});
