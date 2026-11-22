const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const pageInfo = 'pageInfo { hasNextPage endCursor }';
const checkFields = '__typename ... on CheckRun { name status conclusion } ... on StatusContext { context state }';
const query = `query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    deleteBranchOnMerge
    pullRequest(number: $number) {
      id number state isDraft isCrossRepository author { login __typename } baseRefName headRefName headRefOid baseRef { target { oid } } mergeable changedFiles
      labels(first: 100) { nodes { name } ${pageInfo} }
      files(first: 100) { nodes { path changeType } totalCount ${pageInfo} }
      headRef { compare(headRef: "master") { aheadBy baseTarget { oid } headTarget { oid } } }
      commits(last: 1) { nodes { commit { oid statusCheckRollup {
        id contexts(first: 100) { nodes { ${checkFields} } ${pageInfo} }
      } } } }
    }
  }
}`;

function gh(...args) {
  return execFileSync('gh', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 32 * 1024 * 1024 });
}

function graphql(query, variables) {
  const args = ['api', 'graphql', '-f', `query=${query}`];
  for (const [key, value] of Object.entries(variables)) args.push(typeof value === 'number' ? '-F' : '-f', `${key}=${value}`);
  const result = JSON.parse(gh(...args));
  if (result.errors?.length || !result.data) throw new Error('incomplete GraphQL response');
  return result.data;
}

function complete(connection, id, type, field, fields) {
  if (!Array.isArray(connection?.nodes) || typeof connection.pageInfo?.hasNextPage !== 'boolean') throw new Error(`incomplete ${field}`);
  const nodes = [...connection.nodes];
  const seen = new Set();
  while (connection.pageInfo.hasNextPage) {
    const cursor = connection.pageInfo.endCursor;
    if (typeof cursor !== 'string' || !cursor || seen.has(cursor)) throw new Error(`invalid ${field} cursor`);
    seen.add(cursor);
    console.log(`additional read: ${field} pagination`);
    connection = graphql(`query($id: ID!, $cursor: String!) {
      node(id: $id) { ... on ${type} { ${field}(first: 100, after: $cursor) { nodes { ${fields} } ${pageInfo} } } }
    }`, { id, cursor }).node?.[field];
    if (!Array.isArray(connection?.nodes) || typeof connection.pageInfo?.hasNextPage !== 'boolean') throw new Error(`incomplete ${field} page`);
    nodes.push(...connection.nodes);
  }
  return nodes;
}

function main() {
  const repo = process.env.GITHUB_REPOSITORY;
  if (!/^[\w.-]+\/[\w.-]+$/.test(repo || '')) throw new Error('invalid repository');
  const [owner, name] = repo.split('/');
  const event = JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8'));
  let number;
  let expectedHead;
  let dryRun;
  if (process.env.GITHUB_EVENT_NAME === 'workflow_run') {
    const run = event.workflow_run;
    if (run?.event !== 'pull_request' || run.conclusion !== 'success' || run.head_branch === 'master'
      || run.head_repository?.full_name !== repo || run.pull_requests?.length !== 1) {
      console.log('skip (not a successful single-PR check)');
      return;
    }
    number = run.pull_requests[0].number;
    expectedHead = run.head_sha;
    if (!/^[0-9a-f]{40}$/.test(expectedHead || '')) throw new Error('invalid source head');
    dryRun = process.env.DRY_RUN === 'true';
    console.log(`source run=${run.id} PR=${number} head=${expectedHead}`);
  } else if (process.env.GITHUB_EVENT_NAME === 'workflow_dispatch') {
    number = Number(event.inputs?.pull_request);
    dryRun = event.inputs?.dry_run !== 'false';
  } else {
    console.log('skip (unsupported event)');
    return;
  }
  if (!Number.isSafeInteger(number) || number <= 0) throw new Error('invalid PR number');
  const repository = graphql(query, { owner, name, number }).repository;
  const pr = repository?.pullRequest;
  if (!pr || pr.number !== number || pr.state !== 'OPEN') {
    console.log(`#${number}: skip (PR is not open)`);
    return;
  }
  if (expectedHead && expectedHead !== pr.headRefOid) {
    console.log(`#${number}: skip (stale completed check)`);
    return;
  }
  const commit = pr.commits?.nodes?.[0]?.commit;
  const comparison = pr.headRef?.compare;
  const baseOid = pr.baseRef?.target?.oid;
  if (!/^[0-9a-f]{40}$/.test(baseOid || '') || commit?.oid !== pr.headRefOid || comparison?.baseTarget?.oid !== pr.headRefOid
    || comparison?.headTarget?.oid !== baseOid || !Number.isSafeInteger(comparison?.aheadBy) || comparison.aheadBy < 0) {
    throw new Error('incoherent PR head or master comparison');
  }
  const paginated = pr.labels?.pageInfo?.hasNextPage || commit.statusCheckRollup?.contexts?.pageInfo?.hasNextPage;
  const labels = complete(pr.labels, pr.id, 'PullRequest', 'labels', 'name');
  const rollup = commit.statusCheckRollup;
  const checks = rollup ? complete(rollup.contexts, rollup.id, 'StatusCheckRollup', 'contexts', checkFields) : [];
  if (!Array.isArray(pr.files?.nodes) || typeof pr.files.pageInfo?.hasNextPage !== 'boolean') throw new Error('incomplete PR files');
  const fileFallback = pr.files.pageInfo.hasNextPage || pr.files.nodes.some(file => ['RENAMED', 'COPIED'].includes(file.changeType));
  let files;
  if (fileFallback) {
    console.log('additional read: complete REST files with rename origins');
    const pages = JSON.parse(gh('api', `repos/${repo}/pulls/${number}/files?per_page=100`, '--paginate', '--slurp'));
    if (!Array.isArray(pages) || !pages.every(Array.isArray)) throw new Error('invalid REST files');
    const entries = pages.flat();
    if (entries.length !== pr.changedFiles || entries.some(file => file.status === 'renamed' && !file.previous_filename)) throw new Error('incomplete REST files');
    files = entries.flatMap(file => [file.filename, ...(file.previous_filename ? [file.previous_filename] : [])]);
  } else {
    if (pr.files.nodes.length !== pr.changedFiles || pr.files.totalCount !== pr.changedFiles) throw new Error('incomplete PR file list');
    files = pr.files.nodes.map(file => file.path);
  }
  if (paginated || fileFallback) {
    const current = graphql(`query($owner: String!, $name: String!, $number: Int!) {
      repository(owner: $owner, name: $name) { pullRequest(number: $number) { headRefOid baseRef { target { oid } } } }
    }`, { owner, name, number }).repository?.pullRequest;
    if (current?.headRefOid !== pr.headRefOid || current?.baseRef?.target?.oid !== baseOid) throw new Error('PR changed during paginated read');
  }
  const dir = fs.mkdtempSync(path.join(process.env.RUNNER_TEMP || os.tmpdir(), 'automerge-'));
  let verdict;
  try {
    const author = pr.author?.__typename === 'Bot' ? { login: `app/${pr.author.login}` } : pr.author;
    fs.writeFileSync(path.join(dir, 'info.json'), JSON.stringify({ ...pr, author, labels, statusCheckRollup: checks }));
    fs.writeFileSync(path.join(dir, 'files.json'), JSON.stringify(files));
    verdict = execFileSync('bash', [path.join(__dirname, 'automerge-admit.sh'), path.join(dir, 'info.json'), path.join(dir, 'files.json'), String(comparison.aheadBy), owner], { encoding: 'utf8' }).trim();
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
  console.log(`#${number}: ${verdict}`);
  if (verdict !== 'merge') return;
  if (dryRun) {
    console.log('dry-run: no merge or dispatch');
    return;
  }
  const merged = graphql(`mutation($id: ID!, $head: GitObjectID!) {
    mergePullRequest(input: { pullRequestId: $id, expectedHeadOid: $head, mergeMethod: SQUASH }) {
      pullRequest { number merged mergeCommit { oid } }
    }
  }`, { id: pr.id, head: pr.headRefOid }).mergePullRequest?.pullRequest;
  if (merged?.number !== number || merged.merged !== true || !/^[0-9a-f]{40}$/.test(merged.mergeCommit?.oid || '')) throw new Error('merge was not confirmed');
  console.log(`#${number}: merged ${merged.mergeCommit.oid}`);
  for (const workflow of ['test.yml', 'no-comments.yml', 'gitleaks.yml']) gh('workflow', 'run', workflow, '-R', repo, '--ref', 'master');
  if (!repository.deleteBranchOnMerge && pr.headRefName && pr.headRefName !== 'master') {
    try {
      gh('api', '--method', 'DELETE', `repos/${repo}/git/refs/heads/${encodeURIComponent(pr.headRefName)}`);
    } catch (error) {
      console.error(`merged, but could not delete branch: ${error.message}`);
    }
  }
}

try {
  main();
} catch (error) {
  console.error(`automerge failed closed: ${error.message}`);
  process.exitCode = 1;
}
