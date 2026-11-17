import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const featureDirectory = '.claude/skills/verify-multiprompt/features';
const sourceFiles = ['src/shortcuts.zig', 'src/command_palette.zig', 'openwiki/architecture/features.md'];
const slug = text => text.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

function productionZig(source) {
  return source.replace(/^test "[^]*?^\}/gm, '').replace(/\/\/[^\n]*|"(?:\\.|[^"\\])*"/g, match => match.startsWith('//') ? '' : match);
}

export function inventory(read) {
  const entries = new Map();
  const add = (id, file, label) => entries.set(id, { id, file, label });
  const shortcuts = read(sourceFiles[0]).match(/\bSHORTCUT_ROWS\s*=\s*\[_\]ShortcutRow\s*\{([\s\S]*?)\n\};/);
  if (!shortcuts) throw new Error('SHORTCUT_ROWS was not found');
  let section = '';
  let parsedRows = 0;
  for (const row of shortcuts[1].matchAll(/\.\{\s*\.a\s*=\s*"((?:\\.|[^"\\])*)",\s*\.b\s*=\s*"((?:\\.|[^"\\])*)",\s*\.header\s*=\s*(true|false)\s*\}/g)) {
    parsedRows++;
    if (row[3] === 'true') section = slug(row[1]);
    else {
      const id = `shortcut:${section}/${slug(row[1])}`;
      if (entries.has(id)) throw new Error(`Duplicate shortcut source entry: ${id}`);
      add(id, sourceFiles[0], `${row[1]}: ${row[2]}`);
    }
  }
  if (parsedRows !== [...shortcuts[1].matchAll(/\.\{/g)].length) throw new Error('An unrecognized SHORTCUT_ROWS row would hide a source feature');
  if (!entries.size) throw new Error('No shortcut actions were found');

  const palette = productionZig(read(sourceFiles[1]));
  const bodies = [...palette.matchAll(/(?:pub\s+)?fn\s+(\w+)\([^]*?\n\}/g)]
    .filter(match => /g_search_results\[[^\n]*\]\s*=/.test(match[0]) || match[1] === 'palettePrimaryLabel')
    .map(match => match[0]).join('\n');
  const paletteIds = new Set([...bodies.matchAll(/\bSEARCH_[A-Z0-9_]+\b/g)].map(match => match[0])
    .filter(id => !/(?:_COUNT|_HEADER_OFFSET)$/.test(id)));
  for (const row of palette.matchAll(/\.(?:target|id)\s*=\s*(?:app_state\.)?(SEARCH_[A-Z0-9_]+)(\s*\+\s*\d+)?/g)) {
    paletteIds.add(row[1] + (row[2] ? row[2].replace(/\s/g, '') : ''));
  }
  for (const id of paletteIds) add(`palette:${id}`, sourceFiles[1], id);
  for (const [, , name] of palette.matchAll(/\bg_search_results\[[^\n]*\]\s*=\s*(\w+)\.(new_room_target|edit_room_target)/g)) {
    add(`palette:${name}`, sourceFiles[1], name);
  }
  if (!paletteIds.size) throw new Error('No palette actions were found');

  const wiki = read(sourceFiles[2]);
  let featureSection = false;
  let futureSection = false;
  let found = 0;
  for (const line of wiki.split('\n')) {
    const heading = /^## (.+)/.exec(line);
    if (heading) {
      featureSection = heading[1] === 'Features';
      futureSection = heading[1] === 'Future Features';
      if (!['What Is This', 'Why', 'Core Design', 'Features', 'Future Features'].includes(heading[1])) {
        add(`architecture:${slug(heading[1])}`, sourceFiles[2], heading[1]);
        found++;
      }
    } else if (!futureSection && (featureSection || /^[-*] /.test(line)) && line.trim()) {
      const bold = /^- \*\*(.+?)\*\*/.exec(line);
      const label = bold?.[1] || line.replace(/^[-*] /, '').split(/[.!]\s|\s(?:has|sit)\b/)[0];
      add(`architecture:${slug(label)}`, sourceFiles[2], label);
      found++;
    }
  }
  if (!found) throw new Error('No architecture features were found');
  return [...entries.values()].sort((a, b) => a.id.localeCompare(b.id));
}

export function liveRecipe(text) {
  const recipe = /^## (?:Driving[^\n]*|Driving recipe)\r?\n([^]*?)(?=^## |$(?![^]))/m.exec(text)?.[1] || '';
  return /^## (?:How to get to it[^\n]*|User entry points)\r?$/m.test(text)
    && !/\bunreachable\b|^Status:\s*(?:blocked|pending)/im.test(recipe)
    && /(?:control|drive)\.ps1|gh workflow run/.test(recipe)
    && /\b(?:press|type|click|select|open|send|run)\b/i.test(recipe)
    && /\b(?:require|assert|inspect|check|expect)\b/i.test(recipe)
    && /screenshot|result\.json|saved|visible|exact|evidence/i.test(recipe);
}

export function coverage(read, files) {
  const entries = inventory(read);
  const covered = new Map();
  const invalid = [];
  for (const file of files.filter(file => file.startsWith(`${featureDirectory}/`) && file.endsWith('.md') && !file.endsWith('/README.md'))) {
    const text = read(file);
    const claims = [...text.matchAll(/^Covers: (.+)$/gm)].flatMap(match => match[1].trim().split(', '));
    if (!claims.length) continue;
    if (!liveRecipe(text)) {
      invalid.push(`${file}: Covers entries need user entry points and a reachable live driving recipe with actions and evidence`);
      continue;
    }
    for (const id of claims) covered.set(id, file);
  }
  const ids = new Set(entries.map(entry => entry.id));
  for (const [id, file] of covered) if (!ids.has(id)) invalid.push(`${file}: unknown source entry ${id}`);
  const gaps = entries.filter(entry => !covered.has(entry.id));
  return { total: entries.length, covered: entries.length - gaps.length, gaps, invalid };
}

export function compare(current, base) {
  const allowed = new Set(base.gaps.map(entry => entry.id));
  return current.gaps.filter(entry => !allowed.has(entry.id));
}

export function snapshot(root) {
  const files = fs.readdirSync(path.join(root, featureDirectory)).map(file => `${featureDirectory}/${file}`);
  return coverage(file => fs.readFileSync(path.join(root, file), 'utf8'), files);
}

export function main(args, root = process.cwd()) {
  const json = args.includes('--json');
  args = args.filter(arg => arg !== '--json');
  if (args.length && (args.length !== 2 || args[0] !== '--base')) throw new Error('Usage: node tools/check-feature-coverage.mjs [--base <checkout-directory>] [--json]');
  const current = snapshot(root);
  const regressions = args.length ? compare(current, snapshot(path.resolve(root, args[1]))) : current.gaps;
  const percent = Number((100 * current.covered / current.total).toFixed(2));
  const report = { ...current, percent, newGaps: regressions };
  if (json) console.log(JSON.stringify(report, null, 2));
  else {
    console.log(`Feature journey coverage: ${percent}% (${current.covered}/${current.total}); target 100%.`);
    console.log(`Full gap list (${current.gaps.length}; existing gaps are Part H, w-2567h):`);
    for (const entry of current.gaps) console.log(`- ${entry.id} | ${entry.file} | ${entry.label}`);
    for (const error of current.invalid) console.error(error);
    if (regressions.length) console.error(`Missing live journeys (${regressions.length} new gaps):\n${regressions.map(entry => `- ${entry.id}`).join('\n')}\nAdd Covers: <source entry ID> to a feature file with a live driving recipe. Unreachable is not coverage.`);
  }
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, `Feature journey coverage: **${percent}% (${current.covered}/${current.total})**. Target 100%. New gaps: ${regressions.length}.\n\n${current.gaps.map(entry => `- \`${entry.id}\``).join('\n')}\n`);
  return current.invalid.length || regressions.length ? 1 : 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { process.exitCode = main(process.argv.slice(2)); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
