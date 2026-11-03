// The Tests run dispatched by the merge push on master finished with every job green.
import { REPO, PR, ghJson, fail } from './lib.mjs';

const pr = ghJson(['pr', 'view', String(PR), '--repo', REPO, '--json', 'mergeCommit']);
const sha = pr.mergeCommit.oid;

const runs = ghJson(['run', 'list', '--repo', REPO, '--branch', 'master', '--limit', '60',
  '--json', 'databaseId,headSha,name,conclusion,status,event,createdAt,updatedAt']);
const mine = runs.filter((r) => r.headSha === sha && r.name === 'Tests');
if (mine.length === 0) fail(`no Tests run on master for ${sha.slice(0, 8)}`);
const run = mine[0];
if (run.status !== 'completed') fail(`Tests run ${run.databaseId} still ${run.status}`);
if (run.conclusion !== 'success') fail(`Tests run ${run.databaseId} is ${run.conclusion}`);

const jobs = ghJson(['api', `repos/${REPO}/actions/runs/${run.databaseId}/jobs?per_page=100`, '--jq', '.jobs']);
const pending = jobs.filter((j) => j.status !== 'completed');
const failed = jobs.filter((j) => j.conclusion !== 'success' && j.conclusion !== 'skipped' && !j.name.startsWith('test ('));
const shards = jobs.filter((j) => j.name.startsWith('test-vps') || j.name.startsWith('test-windows'));
if (pending.length) fail(`${pending.length} jobs still running`);
if (failed.length) fail(`red jobs: ${failed.map((j) => `${j.name}=${j.conclusion}`).join(', ')}`);
if (shards.length < 8) fail(`only ${shards.length} test shards reported`);

const minutes = Math.round((new Date(run.updatedAt) - new Date(run.createdAt)) / 60000);
console.log(`run=${run.databaseId} sha=${sha.slice(0, 8)} jobs=${jobs.length} shards=${shards.length} red=0 wall=${minutes}m`);
console.log('OK the master Tests run is green');
