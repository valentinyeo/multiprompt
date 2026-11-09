export const REQUIRED_CHECKS = ['install', 'start', 'chats', 'computer-view', 'sync', 'memory', 'crashes'];

export function releaseVersion(tag) {
  const match = /^v(\d+\.\d+\.\d+)$/.exec(String(tag ?? '').trim());
  if (!match) throw new Error(`invalid release tag: ${tag}`);
  return match[1];
}

export function shippedTickets(subjects) {
  const tickets = new Set();
  for (const subject of subjects) {
    const line = String(subject ?? '').split('\n')[0];
    for (const match of line.matchAll(/(?:^|[^A-Za-z0-9-])(IGSH-\d+)/g)) tickets.add(match[1]);
  }
  return [...tickets].sort((left, right) => Number(left.slice(5)) - Number(right.slice(5)));
}

export function connectedMachines(output) {
  const machines = new Set();
  for (const line of String(output ?? '').split(/\r?\n/)) {
    const match = /^[\u2713\u2714]\s+(\S+)/.exec(line.trim());
    if (match) machines.add(match[1]);
  }
  return machines;
}

export function readResult(stdout) {
  const match = /LAPTOP_CHECK_JSON_BEGIN\s*([\s\S]*?)\s*LAPTOP_CHECK_JSON_END/.exec(String(stdout ?? ''));
  if (!match) throw new Error('check output has no result block');
  const result = JSON.parse(match[1]);
  if (!Array.isArray(result?.checks) || result.checks.length === 0) throw new Error('check output has no checks');
  return result;
}

export function summarize(result, expectedVersion) {
  const checks = Array.isArray(result?.checks) ? result.checks : [];
  const present = new Set(checks.map(check => check.name));
  const missing = REQUIRED_CHECKS.filter(name => !present.has(name));
  const failed = checks.filter(check => check.ok !== true).map(check => check.name);
  if (expectedVersion && result?.version !== expectedVersion) failed.unshift('version');
  const verdict = missing.length === 0 && failed.length === 0 ? 'PASS' : 'FAIL';
  return { verdict, failed, missing, checks };
}

function escapeHtml(text) {
  return String(text ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

export function commentBody({ tag, host, verdict, failed, missing, checks }) {
  const lines = [`<p><b>Test laptop check: ${verdict}</b> ${tag} on ${host}</p>`, '<ul>'];
  for (const check of checks) lines.push(`<li>${check.ok === true ? 'PASS' : 'FAIL'} ${escapeHtml(check.name)}: ${escapeHtml(check.detail)}</li>`);
  for (const name of missing) lines.push(`<li>MISSING ${escapeHtml(name)}</li>`);
  lines.push('</ul>');
  if (failed.length > 0) lines.push(`<p>Failed: ${escapeHtml(failed.join(', '))}</p>`);
  return lines.join('\n');
}

export function shouldAttempt(entry, maxAttempts = 2) {
  if (!entry) return true;
  if (entry.verdict === 'PASS') return false;
  return Number(entry.attempts ?? 0) < maxAttempts;
}

export function recordAttempt(entry, tag, verdict, at) {
  const attempts = entry?.tag === tag ? Number(entry.attempts ?? 0) : 0;
  return { tag, verdict, attempts: attempts + 1, at };
}
