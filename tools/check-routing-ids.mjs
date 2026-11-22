import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export function tokenize(source) {
  const tokens = [];
  const pattern = /\/\/[^\n]*|\\\\[^\n]*|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|0[xX][\da-fA-F_]+|0[bB][01_]+|0[oO][0-7_]+|\d[\d_]*|[A-Za-z_][A-Za-z_0-9]*|\s+|./gs;
  let line = 1;
  for (const match of source.matchAll(pattern)) {
    const text = match[0];
    if (!/^\s|^\/\/|^\\\\/.test(text)) tokens.push({ text, line, offset: match.index });
    line += (text.match(/\n/g) || []).length;
  }
  return tokens;
}

export function checkRouting(sources, manifest) {
  const files = new Map();
  const declarations = [];
  for (const [file, source] of Object.entries(sources)) {
    const tokens = tokenize(source);
    const constants = new Map();
    for (let i = 0; i < tokens.length; i++) {
      if (tokens[i].text !== 'const' || !/^[A-Za-z_]\w*$/.test(tokens[i + 1]?.text)) continue;
      let start = i + 2;
      while (start < tokens.length && !['=', ';', '{'].includes(tokens[start].text)) start++;
      if (tokens[start]?.text !== '=') continue;
      let end = start + 1;
      while (end < tokens.length && tokens[end].text !== ';') end++;
      const declaration = { file, name: tokens[i + 1].text, line: tokens[i + 1].line, start: start + 1, end, expr: tokens.slice(start + 1, end) };
      if (!constants.has(declaration.name)) constants.set(declaration.name, declaration);
      declarations.push(declaration);
    }
    files.set(file, { tokens, constants });
  }
  const errors = [];
  const location = entry => `${entry.file}:${entry.line} ${entry.name}`;
  const resolving = new Set();
  const cache = new Map();
  function imported(file, expr) {
    if (expr[0]?.text === '@' && expr[1]?.text === 'import' && expr[2]?.text === '(' && expr[4]?.text === ')') {
      return { file: path.posix.normalize(path.posix.join(path.posix.dirname(file), JSON.parse(expr[3].text))), consumed: 5 };
    }
    return null;
  }
  function moduleFile(file, name) {
    const declaration = files.get(file)?.constants.get(name);
    const module = declaration && imported(file, declaration.expr);
    if (!module || module.consumed !== declaration.expr.length) throw new Error(`unknown module ${name}`);
    return module.file;
  }
  function resolve(file, name) {
    const key = `${file}:${name}`;
    if (cache.has(key)) return cache.get(key);
    if (resolving.has(key)) throw new Error(`cyclic constant ${name}`);
    const declaration = files.get(file)?.constants.get(name);
    if (!declaration) throw new Error(`unknown constant ${name} in ${file}`);
    resolving.add(key);
    try {
      const value = evaluate(file, declaration.expr);
      cache.set(key, value);
      return value;
    } finally { resolving.delete(key); }
  }
  function evaluate(file, expr) {
    let i = 0;
    function atom() {
      const token = expr[i++]?.text;
      if (token === '+' || token === '-') return (token === '-' ? -1 : 1) * atom();
      if (token === '(') {
        const value = sum();
        if (expr[i++]?.text !== ')') throw new Error('unclosed arithmetic');
        return value;
      }
      if (/^(?:\d[\da-fA-F_xXbBoO]*)$/.test(token || '')) return Number(token.replaceAll('_', ''));
      const module = imported(file, expr.slice(i - 1));
      if (module) {
        i += module.consumed - 1;
        if (expr[i++]?.text !== '.') throw new Error('expected imported constant');
        return resolve(module.file, expr[i++]?.text);
      }
      if (/^[A-Za-z_]\w*$/.test(token || '')) {
        if (expr[i]?.text === '.') {
          i++;
          return resolve(moduleFile(file, token), expr[i++]?.text);
        }
        return resolve(file, token);
      }
      throw new Error(`unsupported arithmetic token ${token}`);
    }
    function sum() {
      let value = atom();
      while (['+', '-'].includes(expr[i]?.text)) {
        const op = expr[i++].text;
        value += (op === '+' ? 1 : -1) * atom();
      }
      return value;
    }
    const value = sum();
    if (i !== expr.length || !Number.isSafeInteger(value)) throw new Error(`unsupported routing expression ${expr.map(t => t.text).join(' ')}`);
    return value;
  }
  const isReexport = declaration => {
    const expr = declaration.expr;
    const module = imported(declaration.file, expr);
    if (module && expr.length === module.consumed + 2 && expr[module.consumed].text === '.') return true;
    if (expr.length === 3 && expr[1].text === '.') {
      try { moduleFile(declaration.file, expr[0].text); return true; } catch {}
    }
    return false;
  };
  const scalars = [];
  const messages = [];
  for (const declaration of declarations) {
    if (!/^(?:SEARCH_|WM_APP_)/.test(declaration.name) || isReexport(declaration)) continue;
    try {
      const value = resolve(declaration.file, declaration.name);
      if (declaration.name.startsWith('SEARCH_')) scalars.push({ ...declaration, value });
      else messages.push({ ...declaration, value: value - resolve(declaration.file, 'WM_APP') });
    } catch (error) { errors.push(`${location(declaration)}: ${error.message}; use resolvable integer constants and + or - for routing IDs`); }
  }
  const findScalar = name => {
    const matches = scalars.filter(scalar => scalar.name === name);
    if (matches.length !== 1) throw new Error(`expected one defining constant for ${name}, found ${matches.length}`);
    return matches[0];
  };
  const bands = [];
  for (const band of manifest) {
    try {
      if (!band.name || !band.base || !(typeof band.size === 'string' || Number.isSafeInteger(band.size))) throw new Error('invalid band entry');
      const base = findScalar(band.base);
      const size = typeof band.size === 'number' ? band.size : evaluate(base.file, tokenize(band.size));
      if (!Number.isSafeInteger(size) || size <= 0) throw new Error('band size must be a positive integer');
      bands.push({ ...base, bandName: band.name, size, endValue: base.value + size });
    } catch (error) { errors.push(`tools/routing-id-bands.json ${band.name}: ${error.message}; register a source base and its full size`); }
  }
  for (const [file, { tokens }] of files) {
    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i];
      if (!token.text.startsWith('SEARCH_') && token.text !== 'WM_APP') continue;
      const owner = declarations.find(d => d.file === file && i >= d.start && i < d.end);
      const previous = tokens[i - 1]?.text === '.' ? tokens[i - 3]?.text : tokens[i - 1]?.text;
      if (token.text.startsWith('SEARCH_') && !/_(?:ROWS|COUNT)$/.test(token.text) && (tokens[i + 1]?.text === '+' || previous === '+') && !owner?.name.startsWith('SEARCH_')) {
        const band = bands.find(band => band.name === token.text);
        if (!band) errors.push(`${file}:${token.line} ${token.text} uses a base-plus-index band absent from tools/routing-id-bands.json; register its full size before allocating IDs`);
        else if (['<', '>'].includes(previous) && tokens[i + 1]?.text === '+') {
          const sizeTokens = tokens.slice(i + 2, tokens[i + 3]?.text === '.' ? i + 5 : i + 3);
          try {
            const size = evaluate(file, sizeTokens);
            if (size > band.size) errors.push(`${file}:${token.line} ${token.text} source bound ${size} exceeds ${band.bandName} size ${band.size}; update tools/routing-id-bands.json to reserve the full band`);
          } catch (error) { errors.push(`${file}:${token.line} ${token.text} has an unresolved band bound: ${error.message}; use a resolvable size and register it in tools/routing-id-bands.json`); }
        }
      }
      if (token.text !== 'WM_APP' || tokens[i + 1]?.text !== '+' || owner?.name.startsWith('WM_APP_')) continue;
      let end = i + 2;
      let depth = 0;
      let expectAtom = true;
      while (end < tokens.length) {
        const text = tokens[end].text;
        if (expectAtom) {
          if (text === '(') depth++;
          else if (/^(?:[A-Za-z_]\w*|\d[\da-fA-F_xXbBoO]*)$/.test(text)) {
            if (tokens[end + 1]?.text === '.') end += 2;
            expectAtom = false;
          } else if (!['+', '-'].includes(text)) break;
        } else if (text === ')' && depth > 0) depth--;
        else if (['+', '-'].includes(text)) expectAtom = true;
        else break;
        end++;
      }
      const expr = tokens.slice(i + 2, end);
      try { messages.push({ file, line: token.line, name: owner?.name || 'WM_APP expression', value: evaluate(file, expr) }); }
      catch (error) { errors.push(`${file}:${token.line} WM_APP: ${error.message}; define a resolvable WM_APP_* constant`); }
    }
  }
  const fix = 'pick a free id outside every band in tools/routing-id-bands.json';
  const seen = new Map();
  for (const scalar of scalars) {
    const previous = seen.get(scalar.value);
    if (previous) errors.push(`${location(scalar)}=${scalar.value} overlaps ${location(previous)}=${previous.value}; ${fix}`);
    seen.set(scalar.value, scalar);
    for (const band of bands) {
      if (scalar.file === band.file && scalar.name === band.name) continue;
      if (scalar.value >= band.value && scalar.value < band.endValue) errors.push(`${location(scalar)}=${scalar.value} overlaps ${band.bandName} [${band.value},${band.endValue}); ${fix}`);
    }
  }
  for (let i = 0; i < bands.length; i++) {
    for (const other of bands.slice(i + 1)) {
      const band = bands[i];
      if (band.value < other.endValue && other.value < band.endValue) errors.push(`${location(band)} ${band.bandName} [${band.value},${band.endValue}) overlaps ${location(other)} ${other.bandName} [${other.value},${other.endValue}); ${fix}`);
    }
  }
  const messageIds = new Map();
  for (const message of messages) {
    const previous = messageIds.get(message.value);
    if (previous) errors.push(`${location(message)}=WM_APP+${message.value} overlaps ${location(previous)}: duplicate WM_APP id ${message.value}; allocate a unique WM_APP offset across src/**/*.zig`);
    messageIds.set(message.value, message);
  }
  return { errors, scalars: scalars.length, bands: bands.length, messages: messages.length };
}

export function readSources(root) {
  const sources = {};
  function visit(directory) {
    for (const entry of fs.readdirSync(path.join(root, directory), { withFileTypes: true })) {
      const file = `${directory}/${entry.name}`;
      if (entry.isDirectory()) visit(file);
      else if (entry.isFile() && file.endsWith('.zig')) sources[file] = fs.readFileSync(path.join(root, file), 'utf8');
    }
  }
  visit('src');
  return sources;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const args = process.argv.slice(2);
    if (args.length && (args.length !== 2 || args[0] !== '--root')) throw new Error('Usage: node tools/check-routing-ids.mjs [--root DIR]');
    const root = path.resolve(args[1] || '.');
    const result = checkRouting(readSources(root), JSON.parse(fs.readFileSync(path.join(root, 'tools/routing-id-bands.json'), 'utf8')));
    if (result.errors.length) { console.error(result.errors.join('\n')); process.exitCode = 1; }
    else console.log(`Routing IDs OK: ${result.scalars} scalars, ${result.bands} bands, ${result.messages} WM_APP IDs`);
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
