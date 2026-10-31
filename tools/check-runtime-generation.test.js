import assert from 'node:assert/strict';
import test from 'node:test';
import { generationOf, verdict } from './check-runtime-generation.mjs';

const reader = (generation, body = 'print(1)\n') => `RUNTIME_GENERATION = ${generation}\n${body}`;

test('IGSH-1266 an unchanged reader passes', () => {
  const source = reader(36);
  assert.deepEqual(verdict(source, source), { ok: true, reason: 'src/chat_history_reader.py is unchanged' });
});

test('IGSH-1266 an edited reader without a bump fails', () => {
  const result = verdict(reader(36), reader(36, 'print(2)\n'));
  assert.equal(result.ok, false);
  assert.match(result.reason, /RUNTIME_GENERATION stayed 36/);
});

test('IGSH-1266 an edited reader with a lower or equal generation fails', () => {
  assert.equal(verdict(reader(36), reader(35, 'print(2)\n')).ok, false);
  assert.equal(verdict(reader(36, 'print(2)\n'), reader(36, 'print(3)\n')).ok, false);
});

test('IGSH-1266 an edited reader with a raised generation passes', () => {
  const result = verdict(reader(36), reader(37, 'print(2)\n'));
  assert.equal(result.ok, true);
  assert.match(result.reason, /36 -> 37/);
});

test('IGSH-1266 a missing generation line or missing file fails', () => {
  assert.equal(verdict('print(1)\n', 'print(2)\n').ok, false);
  assert.equal(verdict(reader(36), 'print(2)\n').ok, false);
  assert.equal(verdict(reader(36), null).ok, false);
});

test('IGSH-1266 a new reader with a generation passes', () => {
  assert.equal(verdict(null, reader(1)).ok, true);
});

test('IGSH-1266 the generation line is read exactly', () => {
  assert.equal(generationOf(reader(36)), 36);
  assert.equal(generationOf('  RUNTIME_GENERATION = 36\n'), null);
  assert.equal(generationOf('RUNTIME_GENERATION = 36.5\n'), null);
  assert.equal(generationOf(undefined), null);
});
