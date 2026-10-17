const fs = require('node:fs');
const path = require('node:path');

function readAppSource(override) {
  if (override) return fs.readFileSync(override, 'utf8');
  const root = path.resolve(__dirname, '..');
  const order = JSON.parse(fs.readFileSync(path.join(__dirname, 'app-source-order.json'), 'utf8'));
  const files = new Map();
  for (const [file] of order) {
    if (files.has(file)) continue;
    const text = fs.readFileSync(path.join(root, 'src', file), 'utf8');
    let comptime = 0;
    const declarations = [...text.matchAll(/^(?:pub )?(?:export )?(?:inline )?(?:extern "[^"]+" )?(const|var|fn|test|comptime)\b\s*([A-Za-z_]\w*|"(?:\\.|[^"\\])*")?/gm)];
    const starts = new Map(declarations.map(m => [m[1] + ' ' + (m[1] === 'comptime' ? comptime++ : m[2]), m.index]));
    const first = starts.get(order.find(([name]) => name === file)[1]);
    if (first !== undefined) {
      const prefix = text.slice(0, first).replace(/comptime \{\s*if \(@import\("builtin"\)\.is_test\) \{(?:\s*_ = @import\("[a-z_0-9]+\.zig"\);)+\s*\}\s*\}/g, '');
      if (prefix.replace(/^(?:pub )?const \w+ = @import\("[^"]+"\)(?:\.\w+)?;\s*$/gm, '').trim()) throw new Error(`Unmapped source prefix in ${file}`);
    }
    files.set(file, { text, starts });
  }
  return order.map(([file, key], index) => {
    const { text, starts } = files.get(file);
    const next = order.slice(index + 1).find(([name]) => name === file);
    const start = starts.get(key), end = next ? starts.get(next[1]) : text.length;
    if (start === undefined || end === undefined || end <= start) throw new Error(`Missing source range ${file}: ${key}`);
    return text.slice(start, end);
  }).join('').replace(/\/\/[^\n]*|\\\\[^\n]*|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\bapp_state\./g, token => token === 'app_state.' ? '' : token).replace(/^([ \t]*)pub (?!(?:fn main\b|const (?:panic|std_options)\b))/gm, '$1');
}

module.exports = { readAppSource };
if (require.main === module) process.stdout.write(readAppSource());
