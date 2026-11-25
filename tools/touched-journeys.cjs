const fs = require('node:fs');
const path = require('node:path');
const { discoverFeatures } = require('./verify-features.cjs');

const SHARED_CORE_MAPS = 5;
const MAX_JOURNEYS = 8;
const SMOKE_JOURNEY = 'appearance';
const VERIFIER_OWN_CI_WORKFLOWS = new Set(['ci-repair-receipt.yml', 'emergency-lane.yml']);
const CHAT_SOURCE_FILES = new Set([
  'src/chat_echo.zig',
  'src/chat_history.zig',
  'src/chat_history_reader.py',
  'src/chat_render.zig',
  'src/chat_send.zig',
  'src/chat_session.zig',
]);
const CHAT_JOURNEYS = ['chat-still', 'server-chat'];

function patternFor(source) {
  return new RegExp(`^${source.split('*').map(part => part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('.*')}$`);
}

function touchedJourneys(files, directory = path.join(__dirname, '../.claude/skills/verify-multiprompt/features')) {
  const { available } = discoverFeatures(directory);
  const ciWorkflows = new Set();
  const unmapped = [];
  let sourceChange = false;
  const maps = fs.readdirSync(directory).filter(file => file.endsWith('.md')).flatMap(file => {
    const feature = path.basename(file, '.md');
    const text = fs.readFileSync(path.join(directory, file), 'utf8');
    const ciWorkflow = text.match(/^CI workflow: ([a-z0-9-]+\.yml)$/m)?.[1];
    if (!available.includes(feature) && !ciWorkflow) return [];
    const sources = text.match(/^Source files: (.+)$/m)?.[1].split(', ') || [];
    const covers = text.match(/^Covers: (.+)$/m)?.[1].split(', ').filter(entry => /^(?:src|tools|extension|\.github|\.claude)\//.test(entry)) || [];
    return [{ feature, ciWorkflow, sources: [...sources, ...covers] }];
  });
  const ownership = new Map();
  for (const map of maps) for (const source of map.sources) ownership.set(source, (ownership.get(source) || 0) + 1);
  const specificityOf = new Map();
  for (const file of files) {
    if (/(?:\.test\.[cm]?js|(?:\.test|-test)\.py)$/.test(file)) continue;
    if (file.startsWith('src/')) sourceChange = true;
    const matched = [];
    let owned = false;
    for (const map of maps) {
      const patterns = map.sources.filter(source => patternFor(source).test(file));
      const changedMap = file === `.claude/skills/verify-multiprompt/features/${map.feature}.md`;
      if (!patterns.length && !changedMap) continue;
      owned = true;
      if (map.ciWorkflow) {
        if (!VERIFIER_OWN_CI_WORKFLOWS.has(map.ciWorkflow)) ciWorkflows.add(map.ciWorkflow);
        continue;
      }
      const specificity = changedMap ? 0 : Math.min(...patterns.map(source => ownership.get(source)));
      matched.push({ feature: map.feature, specificity });
    }
    for (const { feature, specificity } of matched) {
      if (specificity > SHARED_CORE_MAPS) continue;
      if (!specificityOf.has(feature) || specificity < specificityOf.get(feature)) specificityOf.set(feature, specificity);
    }
    if (!owned) unmapped.push(file);
  }
  let features = [];
  const notes = [];
  let ranked = [];
  if (specificityOf.size) {
    ranked = [...specificityOf].sort(([left, a], [right, b]) => a - b || left.localeCompare(right));
    features = ranked.slice(0, MAX_JOURNEYS).map(([feature]) => feature).sort();
    const dropped = ranked.slice(MAX_JOURNEYS).map(([feature]) => feature).sort();
    if (dropped.length) notes.push(`Over the ${MAX_JOURNEYS}-journey cap, only the most specific journeys ran; dropped: ${dropped.join(', ')}.`);
  } else if (sourceChange && available.includes(SMOKE_JOURNEY)) {
    features = [SMOKE_JOURNEY];
  }
  const chatFiles = files.filter(file => CHAT_SOURCE_FILES.has(file)).sort();
  const chatJourneys = chatFiles.length ? CHAT_JOURNEYS.filter(name => available.includes(name)) : [];
  if (chatJourneys.length) {
    const order = ranked.map(([feature]) => feature);
    const optional = order.filter(feature => features.includes(feature) && !chatJourneys.includes(feature));
    const kept = optional.slice(0, Math.max(0, MAX_JOURNEYS - chatJourneys.length));
    const dropped = optional.filter(feature => !kept.includes(feature));
    if (dropped.length) notes.push(`Chat source changes always run ${chatJourneys.join(', ')}; dropped for that cap: ${dropped.join(', ')}.`);
    features = [...new Set([...chatJourneys, ...kept])].sort();
  }
  return {
    features,
    unmapped,
    ...(notes.length ? { notes } : {}),
    ...(ciWorkflows.size ? { ciWorkflows: [...ciWorkflows].sort() } : {}),
    ...(chatFiles.length ? { chatFiles } : {}),
  };
}

async function touchedJourneysForDiff(baseRef, headRef = 'HEAD', directory, root = process.cwd()) {
  const { execFileSync } = require('node:child_process');
  const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
  const head = git('rev-parse', '--verify', `${headRef}^{commit}`).trim();
  const base = git('merge-base', baseRef, head).trim();
  const files = git('diff', '--name-only', '-z', base, head).split('\0').filter(Boolean);
  if (!files.some(file => /^src\/[^/]+\.zig$/.test(file))) return touchedJourneys(files, directory);
  const { nativeTestParts } = await import('./native-test-parts.mjs');
  const scratch = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'journey-diff-'));
  const checkouts = [];
  try {
    for (const [name, revision] of [['base', base], ['head', head]]) {
      const checkout = path.join(scratch, name);
      git('worktree', 'add', '--quiet', '--detach', checkout, revision);
      checkouts.push(checkout);
    }
    const productionFiles = files.filter(file => {
      if (!/^src\/[^/]+\.zig$/.test(file)) return true;
      try {
        const parts = checkouts.map(checkout => {
          const source = path.join(checkout, file);
          if (!fs.lstatSync(source).isFile()) throw new Error('Not a regular Zig source file');
          return nativeTestParts(fs.readFileSync(source, 'utf8'));
        });
        return !(parts[0].names.length > 0 && JSON.stringify(parts[0].names) === JSON.stringify(parts[1].names) && parts[0].outside === parts[1].outside);
      } catch {
        return true;
      }
    });
    return touchedJourneys(productionFiles, directory);
  } finally {
    for (const checkout of checkouts.reverse()) git('worktree', 'remove', '--force', checkout);
    fs.rmSync(scratch, { recursive: true, force: true });
  }
}

module.exports = { touchedJourneys, touchedJourneysForDiff };

if (require.main === module) {
  touchedJourneysForDiff(process.argv[2], process.argv[3]).then(result => {
    for (const [name, value] of Object.entries(result)) {
      const line = `${name}=${JSON.stringify(value)}\n`;
      if (process.env.GITHUB_OUTPUT) fs.appendFileSync(process.env.GITHUB_OUTPUT, line);
      process.stdout.write(line);
    }
  }).catch(error => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
