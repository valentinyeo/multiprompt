import { execFileSync } from 'node:child_process';

const repo = 'valentinyeo/multiprompt';
const merge = '307bca51295f1a51bd5d9559bb258108484972c8';
const run = '42853784160';

function gh(args) {
  return execFileSync('gh', args, { encoding: 'utf8' });
}

const pr = JSON.parse(gh(['pr', 'view', '919', '--repo', repo, '--json', 'state,mergedAt,mergeCommit,url']));
if (pr.state !== 'MERGED') throw new Error('PR 919 is not merged');
if (pr.mergeCommit.oid !== merge) throw new Error('unexpected merge commit');

const runView = JSON.parse(gh(['run', 'view', run, '--repo', repo, '--json', 'conclusion,url,headSha']));
if (runView.conclusion !== 'success') throw new Error('CI is not success');

const release = JSON.parse(gh(['release', 'view', '--repo', repo, '--json', 'tagName']));
const compare = JSON.parse(gh([
  'api',
  `repos/${repo}/compare/${merge}...${release.tagName}`,
]));
if (compare.status !== 'ahead' && compare.status !== 'identical') {
  throw new Error(`release ${release.tagName} status ${compare.status}`);
}
if (compare.behind_by !== 0) throw new Error(`release is behind the merge by ${compare.behind_by}`);

console.log(`G1 PASS ${pr.url} ${merge} ${runView.url} ${release.tagName} ahead ${compare.ahead_by} behind ${compare.behind_by}`);
