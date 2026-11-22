const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const dir = path.join(root, '.github', 'workflows');
const rank = { none: 0, read: 1, write: 2 };

function block(lines, start, indent) {
  const out = {};
  for (let i = start + 1; i < lines.length; i++) {
    const line = lines[i];
    if (!line.trim()) continue;
    const lead = line.length - line.trimStart().length;
    if (lead <= indent) break;
    const m = line.trim().match(/^([a-z-]+):\s*(read|write|none)\s*$/);
    if (m) out[m[1]] = m[2];
  }
  return out;
}

function topPermissions(text) {
  const lines = text.split('\n');
  const i = lines.findIndex((l) => /^permissions:\s*$/.test(l));
  return i < 0 ? null : block(lines, i, 0);
}

function callers(text) {
  const lines = text.split('\n');
  const found = [];
  let job = null;
  for (let i = 0; i < lines.length; i++) {
    const jm = lines[i].match(/^  ([A-Za-z0-9_-]+):\s*$/);
    if (jm) job = { name: jm[1], perms: null };
    if (!job) continue;
    if (/^    permissions:\s*$/.test(lines[i])) job.perms = block(lines, i, 4);
    const um = lines[i].match(/^    uses:\s*\.\/\.github\/workflows\/([^\s]+)\s*$/);
    if (um) found.push({ job, target: um[1] });
  }
  return found;
}

test('every caller grants the permissions its reusable workflow requests', () => {
  const problems = [];
  for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.yml'))) {
    const text = fs.readFileSync(path.join(dir, file), 'utf8');
    const top = topPermissions(text);
    for (const { job, target } of callers(text)) {
      const targetPath = path.join(dir, target);
      if (!fs.existsSync(targetPath)) continue;
      const wanted = topPermissions(fs.readFileSync(targetPath, 'utf8'));
      const granted = job.perms || top;
      if (!wanted || !granted) continue;
      for (const [scope, level] of Object.entries(wanted)) {
        if ((rank[granted[scope]] || 0) < rank[level]) {
          problems.push(`${file} job ${job.name} calls ${target}, which needs ${scope}: ${level}, but grants ${granted[scope] || 'none'}`);
        }
      }
    }
  }
  assert.deepEqual(problems, []);
});
