import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const doc = 'openwiki/operations/keyboard-shortcuts.md';
const start = '<!-- SHORTCUT_ROWS:START -->';
const end = '<!-- SHORTCUT_ROWS:END -->';

function zigString(literal) {
  return literal.slice(1, -1).replace(/\\(u\{[0-9a-fA-F]+\}|x[0-9a-fA-F]{2}|["\\nrt])/g, (_, escape) => {
    if (escape.startsWith('u{')) return String.fromCodePoint(parseInt(escape.slice(2, -1), 16));
    if (escape.startsWith('x')) return String.fromCharCode(parseInt(escape.slice(1), 16));
    return { n: '\n', r: '\r', t: '\t', '"': '"', '\\': '\\' }[escape];
  });
}

export function parseShortcutRows(source) {
  const array = source.match(/pub const SHORTCUT_ROWS = \[_\]ShortcutRow\{([^]*?)\n\};/);
  if (!array) throw new Error('Cannot find src/shortcuts.zig SHORTCUT_ROWS');
  const string = '"(?:\\\\.|[^"\\\\])*"';
  const row = new RegExp(`\\.\\{\\s*\\.a\\s*=\\s*(${string}),\\s*\\.b\\s*=\\s*(${string}),\\s*\\.header\\s*=\\s*(true|false)\\s*,?\\s*\\}`, 'g');
  const rows = [...array[1].matchAll(row)].map(([, a, b, header]) => ({
    a: zigString(a), b: zigString(b), header: header === 'true',
  }));
  if (!rows.length || array[1].replace(row, '').replace(/[\s,]/g, '')) {
    throw new Error('Cannot parse every src/shortcuts.zig SHORTCUT_ROWS row; use .a, .b and .header fields');
  }
  return rows;
}

export function renderShortcutRows(rows) {
  const cell = text => text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/\|/g, '\\|').replace(/\r?\n/g, '<br>');
  const lines = [start, '', '## Full list'];
  for (const row of rows) {
    if (row.header) {
      lines.push('', `### ${cell(row.a)}`, '', '| Keys | Action |', '| --- | --- |');
    } else {
      lines.push(`| ${cell(row.a)} | ${cell(row.b)} |`);
    }
  }
  lines.push('', end);
  return lines.join('\n');
}

function main() {
  const file = path.join(root, doc);
  const original = fs.readFileSync(file, 'utf8');
  const generated = renderShortcutRows(parseShortcutRows(fs.readFileSync(path.join(root, 'src/shortcuts.zig'), 'utf8')));
  const block = /<!-- SHORTCUT_ROWS:START -->[^]*?<!-- SHORTCUT_ROWS:END -->/;
  if ((original.includes(start) || original.includes(end)) && !block.test(original)) {
    throw new Error(`${doc} has incomplete SHORTCUT_ROWS markers`);
  }
  const updated = block.test(original) ? original.replace(block, () => generated) : `${original.trimEnd()}\n\n${generated}\n`;
  if (original === updated) return;
  if (process.argv.includes('--check')) {
    console.error(`${doc} is out of date; run node tools/shortcuts-doc.mjs`);
    process.exitCode = 1;
  } else {
    fs.writeFileSync(file, updated);
    console.log(`Updated ${doc}`);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) main();
