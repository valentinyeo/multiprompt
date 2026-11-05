import fs from 'node:fs';
import path from 'node:path';
import { tokenize } from './strip-comments.mjs';

export function noticeCalls(source) {
  const { tokens, comments } = tokenize(source, 'zig');
  const positions = [];
  let cursor = 0;
  let comment = 0;
  for (const [, value] of tokens) {
    while (cursor < source.length) {
      if (comments[comment]?.start === cursor) cursor = comments[comment++].end;
      else if (/\s/.test(source[cursor])) cursor++;
      else break;
    }
    if (!source.startsWith(value, cursor)) throw new Error('Cannot locate notice tokens');
    positions.push(cursor);
    cursor += value.length;
  }
  const declarations = [...source.matchAll(/^(?:pub )?(?:inline )?fn (\w+)\(/gm)];
  const calls = [];
  for (let i = 0; i < tokens.length; i++) {
    if (tokens[i][0] !== 'word' || tokens[i][1] !== 'showHeaderNoticeAscii' || tokens[i + 1]?.[1] !== '(' || tokens[i - 1]?.[1] === 'fn') continue;
    let end = i + 1;
    let depth = 0;
    do {
      if (tokens[end][1] === '(') depth++;
      if (tokens[end][1] === ')') depth--;
      end++;
    } while (depth > 0 && end < tokens.length);
    if (depth !== 0) throw new Error('Unterminated notice call');
    const start = positions[i];
    const name = declarations.findLast(item => item.index < start)?.[1] || 'unknown';
    const line = source.slice(source.lastIndexOf('\n', start) + 1, positions[end - 1] + 1);
    calls.push(`${name}: ${tokenize(line, 'zig').tokens.map(([, value]) => value).join('')}`);
  }
  return calls.sort();
}

export function noticeInventory(root) {
  return Object.fromEntries(fs.readdirSync(path.join(root, 'src')).filter(file => file.endsWith('.zig')).sort().flatMap(file => {
    const calls = noticeCalls(fs.readFileSync(path.join(root, 'src', file), 'utf8'));
    return calls.length ? [[file, calls]] : [];
  }));
}
