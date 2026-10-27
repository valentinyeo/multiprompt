import assert from 'node:assert/strict';
import test from 'node:test';
import { matches, shouldRun } from './pr-windows-gate.mjs';

test('ordinary pull request pushes do not start the repeated Windows matrix', () => {
  assert.equal(shouldRun({ event: 'pull_request', action: 'synchronize', paths: ['src/main.zig'], patterns: ['src/**'] }), false);
  assert.equal(shouldRun({ event: 'pull_request', action: 'opened', paths: ['src/main.zig'], patterns: ['src/**'] }), false);
  assert.equal(shouldRun({ event: 'pull_request', action: 'labeled', label: 'hold', paths: ['src/main.zig'], patterns: ['src/**'] }), false);
});

test('approval, the automerge label, master, and a merge queue run the matrix once', () => {
  const patterns = ['src/**', 'build.zig', 'tools/freeze-recorder*'];
  assert.equal(shouldRun({ event: 'pull_request_review', review: 'approved', draft: 'false', paths: ['src/main.zig'], patterns }), true);
  assert.equal(shouldRun({ event: 'pull_request_review', review: 'approved', draft: 'true', paths: ['src/main.zig'], patterns }), false);
  assert.equal(shouldRun({ event: 'pull_request_review', review: 'commented', draft: 'false', paths: ['src/main.zig'], patterns }), false);
  assert.equal(shouldRun({ event: 'pull_request_review', review: 'approved', draft: 'false', paths: ['README.md'], patterns }), false);
  assert.equal(shouldRun({ event: 'pull_request', action: 'labeled', label: 'automerge' }), true);
  assert.equal(shouldRun({ event: 'push' }), true);
  assert.equal(shouldRun({ event: 'merge_group' }), true);
  assert.equal(shouldRun({ event: 'workflow_dispatch' }), true);
});

test('path patterns match the workflow filters', () => {
  assert.equal(matches('src/main.zig', 'src/**'), true);
  assert.equal(matches('src/pane/layout.zig', 'src/**'), true);
  assert.equal(matches('tools/freeze-recorder-proof.mjs', 'tools/freeze-recorder*'), true);
  assert.equal(matches('tools/other.mjs', 'tools/freeze-recorder*'), false);
  assert.equal(matches('.claude/skills/verify-multiprompt/window-controls.ps1', '.claude/skills/verify-multiprompt/window-controls*'), true);
});
