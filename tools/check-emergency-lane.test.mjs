import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import {
  checkEmergencyLane,
  hasEmergencyLabel,
  shouldRefreshSiblingChecks,
  EMERGENCY_LABEL,
} from './check-emergency-lane.mjs';

const emergency = [{ number: 9, state: 'OPEN', draft: false, labels: [EMERGENCY_LABEL] }];
const routine = [{ number: 10, state: 'OPEN', draft: false, labels: ['Multiprompt'] }];

test('the emergency label name stays stable', () => {
  assert.equal(EMERGENCY_LABEL, 'emergency');
});

test('fixture pull lists gate non-emergency pull requests while emergency is open', () => {
  assert.equal(checkEmergencyLane([...emergency, ...routine], routine[0]).ok, false);
  assert.equal(checkEmergencyLane([...emergency, ...routine], emergency[0]).ok, true);
  assert.equal(checkEmergencyLane(routine, routine[0]).ok, true);
  assert.equal(checkEmergencyLane(emergency, emergency[0]).ok, true);
  assert.equal(checkEmergencyLane(emergency, { ...routine[0], state: 'CLOSED' }).ok, true);
  assert.equal(checkEmergencyLane(emergency, { ...routine[0], draft: true }).ok, true);
});

test('label edits and closing the emergency pull request refresh sibling checks', () => {
  assert.equal(shouldRefreshSiblingChecks('closed', [EMERGENCY_LABEL], routine), true);
  assert.equal(shouldRefreshSiblingChecks('unlabeled', [], routine), true);
  assert.equal(shouldRefreshSiblingChecks('labeled', [], routine), true);
  assert.equal(shouldRefreshSiblingChecks('synchronize', [EMERGENCY_LABEL], routine), false);
  assert.equal(shouldRefreshSiblingChecks('unlabeled', ['docs'], emergency), false);
});

test('workflow and checker ship together', () => {
  const workflow = fs.readFileSync(new URL('../.github/workflows/emergency-lane.yml', import.meta.url), 'utf8');
  assert.match(workflow, /name: emergency-lane\n/);
  assert.match(workflow, /types: \[opened, synchronize, reopened, ready_for_review, edited, labeled, unlabeled, closed\]/);
  assert.match(workflow, /node tools\/check-emergency-lane\.mjs check/);
  assert.match(workflow, /node tools\/check-emergency-lane\.mjs refresh/);
  assert.match(workflow, /Rerun emergency-lane for open pull requests after the lane clears/);
  assert.equal(hasEmergencyLabel(['Emergency']), true);
});