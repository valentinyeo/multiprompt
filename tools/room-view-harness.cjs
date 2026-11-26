const fs = require('node:fs');
const path = require('node:path');

const production = path.join(__dirname, '..', 'src', 'room_view.zig');
const imports = new Set(['sameRoom', 'validModel']);
const windowed = /(^|[^\w.])w\.|fonts\.|avatar\.|smooth\.|(^|[^\w.])(SetFocus|ShowWindow|RemovePropW)\(/;

function matching(text, open) {
  let depth = 0;
  let quote = null;
  for (let i = open; i < text.length; i++) {
    const ch = text[i];
    if (quote) {
      if (ch === '\\') { i++; continue; }
      if (ch === quote) quote = null;
      continue;
    }
    if (ch === '"' || ch === "'") { quote = ch; continue; }
    if (ch === '{') depth++;
    if (ch === '}') {
      depth--;
      if (depth === 0) return i;
    }
  }
  throw new Error('unterminated block in src/room_view.zig');
}

function split(params) {
  const parts = [];
  let depth = 0;
  let start = 0;
  for (let i = 0; i < params.length; i++) {
    const ch = params[i];
    if ('([{'.includes(ch)) depth++;
    if (')]}'.includes(ch)) depth--;
    if (ch === ',' && depth === 0) { parts.push(params.slice(start, i)); start = i + 1; }
  }
  if (params.slice(start).trim()) parts.push(params.slice(start));
  return parts.map(part => part.trim()).filter(Boolean);
}

function declaration(text, name) {
  const start = text.indexOf(`const ${name} = struct {`);
  if (start >= 0) return `${text.slice(start, matching(text, text.indexOf('{', start)) + 1)};`;
  const line = new RegExp(`^(?:pub )?const ${name} = .+;$`, 'm').exec(text);
  if (!line) throw new Error(`src/room_view.zig no longer declares ${name}`);
  return line[0];
}

function helper(text, name) {
  const line = new RegExp(`^fn ${name}\\(.*$`, 'm').exec(text);
  if (!line) throw new Error(`src/room_view.zig no longer declares fn ${name}()`);
  const start = line.index;
  return text.slice(start, matching(text, text.indexOf('{', start)) + 1);
}

function viewParts(source) {
  const open = source.indexOf('pub const View = struct {');
  if (open < 0) throw new Error('src/room_view.zig no longer declares the View struct');
  const body = source.slice(open + 'pub const View = struct {'.length, matching(source, source.indexOf('{', open)));
  const top = new Set([...source.matchAll(/^fn (\w+)\(/gm)].map(match => match[1]));
  const methods = [];
  let at = 0;
  for (;;) {
    const found = /(?:^|\n) {4}(?:pub )?fn (\w+)\(/g;
    found.lastIndex = at;
    const match = found.exec(body);
    if (!match) break;
    const start = match.index + (body[match.index] === '\n' ? 1 : 0);
    const close = matching(body, body.indexOf('{', start));
    methods.push({ name: match[1], text: body.slice(start, close + 1) });
    at = close + 1;
  }
  if (methods.length < 20) throw new Error(`src/room_view.zig View exposes only ${methods.length} methods`);
  const fields = body.slice(0, methods.length ? body.indexOf(methods[0].text) : body.length)
    .split('\n')
    .filter(line => /^ {4}\w+: .+,$/.test(line));
  if (fields.length < 40) throw new Error(`src/room_view.zig View exposes only ${fields.length} fields`);
  const stubbed = methods.filter(method => windowed.test(method.text.replace(/self\.\w+/g, ''))
    || [...top].some(name => !imports.has(name) && method.text.includes(`${name}(`)));
  return { top, methods, fields, stubbed };
}

function signature(text) {
  const open = text.indexOf('(');
  let depth = 0;
  let close = -1;
  for (let i = open; i < text.length; i++) {
    if (text[i] === '(') depth++;
    if (text[i] === ')') {
      depth--;
      if (depth === 0) { close = i; break; }
    }
  }
  const name = /fn (\w+)\(/.exec(text)[1];
  const params = split(text.slice(open + 1, close));
  const returned = text.slice(close + 1, text.indexOf('{', close)).trim();
  return { name, params, returned };
}

function defaultBody(returned, name) {
  if (returned === '' || returned === 'void') return '{}';
  if (returned === 'bool') return '{ return false; }';
  if (returned.startsWith('?') || returned === 'w.HANDLE') return '{ return null; }';
  if (/^(u|i)(8|16|32|64|size)$/.test(returned)) return '{ return 0; }';
  throw new Error(`src/room_view.zig View method ${name}() returns ${returned}; declare a harness stub for it`);
}

function view(options = {}) {
  const source = options.source || fs.readFileSync(production, 'utf8');
  const { methods, fields, stubbed } = viewParts(source);
  const declared = options.stub || {};
  const copied = new Set(options.copy || []);
  const stubs = new Set(stubbed.map(method => method.name));
  for (const name of Object.keys(declared)) {
    if (!methods.some(method => method.name === name)) throw new Error(`harness stub ${name}() is not a View method in src/room_view.zig`);
    if (!stubs.has(name)) throw new Error(`harness stub ${name}() would be copied from src/room_view.zig; drop the stub or list it in copy`);
  }
  for (const name of copied) {
    if (!methods.some(method => method.name === name)) throw new Error(`harness copy ${name}() is not a View method in src/room_view.zig`);
  }
  const stubbedSource = methods.filter(method => stubs.has(method.name) && !copied.has(method.name)).map(method => {
    if (declared[method.name]) return declared[method.name];
    const { name, params, returned } = signature(method.text);
    return `    fn ${name}(${params.map(part => `_: ${part.slice(part.indexOf(':') + 1).trim()}`).join(', ')}) ${returned} ${defaultBody(returned, name)}`;
  });
  const copiedSource = methods.filter(method => !stubs.has(method.name) || copied.has(method.name)).map(method => method.text);
  return [
    declaration(source, 'ActionResult'),
    declaration(source, 'ActionKind'),
    declaration(source, 'ActionToken'),
    declaration(source, 'Callbacks'),
    declaration(source, 'Mode'),
    declaration(source, 'StoredId'),
    helper(source, 'sameRoom'),
    helper(source, 'validModel'),
    declaration(source, 'empty_rect'),
    'const View = struct {',
    fields.join('\n'),
    stubbedSource.join('\n'),
    copiedSource.join('\n'),
    '};',
  ].join('\n');
}

module.exports = { view, viewParts };
