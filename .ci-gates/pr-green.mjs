// Before-state gate: every check on the open PR head is green, measured from GitHub.
import { REPO, PR, gh, ghJson, fail } from './lib.mjs';

const pr = ghJson(['pr', 'view', String(PR), '--repo', REPO, '--json', 'headRefOid,state,mergeStateStatus,statusCheckRollup']);
if (pr.state !== 'OPEN') fail(`PR ${PR} is ${pr.state}, not OPEN`);
if (pr.mergeStateStatus === 'DIRTY' || pr.mergeStateStatus === 'BEHIND') fail(`PR ${PR} merge state ${pr.mergeStateStatus}`);

const runs = ghJson([
  'api',
  `repos/${REPO}/commits/${pr.headRefOid}/check-runs?per_page=100`,
  '--jq', '.check_runs',
]);
const rollup = pr.statusCheckRollup || [];
const total = runs.length;
if (total === 0) fail('no check runs on the PR head');
const bad = runs.filter((r) => r.status !== 'completed' || r.conclusion !== 'success');
const names = new Set(runs.map((r) => r.name));
if (names.size < 10) fail(`only ${names.size} distinct check names`);

// Independent read: the rollup view must agree with the check-runs list.
const rollupBad = rollup.filter((c) => (c.conclusion || c.state) !== 'SUCCESS');
if (rollupBad.length !== bad.length) fail(`rollup disagrees: ${rollupBad.length} vs ${bad.length} bad`);

const start = new Date(Math.min(...runs.map((r) => new Date(r.started_at || r.created_at).getTime())));
const end = new Date(Math.max(...runs.map((r) => new Date(r.completed_at || r.created_at).getTime())));
const minutes = Math.round((end - start) / 60000);

if (bad.length) fail(`${bad.length}/${total} not green: ${bad.map((r) => r.name).join(', ')}`);
console.log(`head=${pr.headRefOid.slice(0, 8)} checks=${total} red=0 wall=${minutes}m`);
console.log('OK every check on the PR head is green');
