import { execFileSync } from 'node:child_process';

const allowed = new Set([
  '348741585+software-factory-runners[bot]@users.noreply.github.com',
  '3296316+valentinyeo@users.noreply.github.com',
  'noreply@github.com',
]);
const [base, head] = process.argv.slice(2);

function isAncestor(baseSha, headSha) {
  try {
    execFileSync('git', ['merge-base', '--is-ancestor', baseSha, headSha], { env: { ...process.env, GIT_NO_REPLACE_OBJECTS: '1' } });
    return true;
  } catch (error) {
    if (error.status === 1) return false;
    throw error;
  }
}

try {
  if (!base || !head) throw new Error('Usage: node tools/check-commit-identities.mjs <base> <head>');
  const git = (...args) => execFileSync('git', args, {
    encoding: 'utf8',
    maxBuffer: 16 * 1024 * 1024,
    env: { ...process.env, GIT_NO_REPLACE_OBJECTS: '1' },
  });
  const revisions = [base, head].map(ref => git('rev-parse', '--verify', '--end-of-options', `${ref}^{commit}`).trim());
  if (!isAncestor(revisions[0], revisions[1])) {
    throw new Error(`${base} is not an ancestor of ${head}; the checked range must be only the commits a push adds. Do not rewrite master history.`);
  }
  const fields = git('log', '--no-use-mailmap', '-z', '--format=%H%x00%ae%x00%ce%x00%B', `${revisions[0]}..${revisions[1]}`).split('\0');
  fields.pop();
  const errors = [];
  for (let i = 0; i < fields.length; i += 4) {
    const [sha, author, committer, message] = fields.slice(i, i + 4);
    if (!allowed.has(author)) errors.push(`${sha}: author email is not allowed`);
    if (!allowed.has(committer)) errors.push(`${sha}: committer email is not allowed`);
    if (/^\s*Co-authored-by\s*:/im.test(message)) errors.push(`${sha}: Co-authored-by lines are forbidden`);
  }
  if (errors.length) {
    throw new Error(`${errors.join('\n')}\nAllowed author and committer emails: ${[...allowed].join(', ')}.\nWorkers must use software-factory-runners[bot] <${[...allowed][0]}>. Remove all Co-authored-by lines.`);
  }
  console.log(`Commit identities OK (${fields.length / 4} commits)`);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
