// Master carries the squash of this branch and the restored Tests triggers.
import { REPO, PR, gh, ghJson, fail } from './lib.mjs';

const pr = ghJson(['pr', 'view', String(PR), '--repo', REPO, '--json', 'state,mergeCommit']);
if (pr.state !== 'MERGED') fail(`PR ${PR} is ${pr.state}, not MERGED`);
const mergeSha = pr.mergeCommit.oid;

const log = gh(['api', `repos/${REPO}/commits?sha=master&path=.github/workflows/test.yml&per_page=3`, '--jq', '.[].sha']);
if (!log.split('\n').filter(Boolean).includes(mergeSha)) fail(`${mergeSha.slice(0, 8)} is not the workflow head on master`);

const yml = gh(['api', `repos/${REPO}/contents/.github/workflows/test.yml?ref=${mergeSha}`, '--jq', '.content']);
const text = Buffer.from(yml, 'base64').toString('utf8');
const events = text.split('\non:\n')[1]?.split('\npermissions:')[0] || '';
for (const trigger of ['  pull_request:', '  push:\n    branches: [master]', '  workflow_dispatch:']) {
  if (!events.includes(trigger)) fail(`master test.yml lost the trigger ${trigger.split(':')[0].trim()}`);
}
console.log(`merge=${mergeSha.slice(0, 8)} triggers=pull_request,push:master,dispatch`);
console.log('OK master runs Tests on every pull request and every master push');
