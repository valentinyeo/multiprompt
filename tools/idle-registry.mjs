import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const defaultSrc = path.join(here, '../src');
const timerCall = /(?<![A-Za-z0-9_])(SetTimer|SetCoalescableTimer|setCoalescableTimerInterval)\(/g;
const fetchCall = /(?<![A-Za-z0-9_])(chatFileRequestForDelivery|chatFileRequest)\(/g;
const declaration = /\bfn\s+(SetTimer|SetCoalescableTimer|setCoalescableTimerInterval|chatFileRequestForDelivery|chatFileRequest)\s*\(/;

export function splitArguments(text, open) {
  const args = [];
  let depth = 0;
  let start = open + 1;
  let quote = false;
  for (let i = open; i < text.length; i += 1) {
    const ch = text[i];
    if (quote) {
      if (ch === '\\') i += 1;
      else if (ch === '"') quote = false;
      continue;
    }
    if (ch === '"') quote = true;
    else if (ch === '(' || ch === '[' || ch === '{') depth += 1;
    else if (ch === ')' || ch === ']' || ch === '}') {
      depth -= 1;
      if (depth === 0) {
        args.push(text.slice(start, i).trim());
        return args;
      }
    } else if (ch === ',' && depth === 1) {
      args.push(text.slice(start, i).trim());
      start = i + 1;
    }
  }
  return args;
}

export function normalizeTimerToken(token) {
  const match = token.match(/([A-Za-z_0-9]+)\s*$/);
  return match ? match[1] : token;
}

function lineOf(text, index) {
  return text.slice(0, index).split('\n').length;
}

function onDeclarationLine(text, index) {
  const start = text.lastIndexOf('\n', index) + 1;
  const end = text.indexOf('\n', index);
  return declaration.test(text.slice(start, end < 0 ? text.length : end));
}

function enclosingFunction(lines, line) {
  for (let i = line - 1; i >= 0; i -= 1) {
    const found = lines[i].match(/^\s*(?:pub\s+)?fn\s+([A-Za-z_0-9]+)/);
    if (found) return found[1];
  }
  return null;
}

function sourceFiles(srcDir) {
  return fs.readdirSync(srcDir).filter(name => name.endsWith('.zig') && name !== 'win32.zig').sort();
}

export function scanTimerSites(srcDir = defaultSrc) {
  const sites = [];
  for (const file of sourceFiles(srcDir)) {
    const text = fs.readFileSync(path.join(srcDir, file), 'utf8');
    const lines = text.split('\n');
    for (const match of text.matchAll(timerCall)) {
      if (onDeclarationLine(text, match.index)) continue;
      if (enclosingFunction(lines, lineOf(text, match.index)) === 'setCoalescableTimerInterval') continue;
      const open = match.index + match[0].length - 1;
      const args = splitArguments(text, open);
      if (args.length < 2) throw new Error(`${file}:${lineOf(text, match.index)} timer call has no id argument`);
      sites.push({ file, line: lineOf(text, match.index), timer: normalizeTimerToken(args[1]) });
    }
  }
  return sites;
}

export function scanFetchSites(srcDir = defaultSrc) {
  const sites = [];
  for (const file of sourceFiles(srcDir)) {
    const text = fs.readFileSync(path.join(srcDir, file), 'utf8');
    const lines = text.split('\n');
    for (const match of text.matchAll(fetchCall)) {
      if (onDeclarationLine(text, match.index)) continue;
      const line = lineOf(text, match.index);
      const owner = enclosingFunction(lines, line);
      if (owner === null) throw new Error(`${file}:${line} fetch call outside a function`);
      sites.push({ file, line, key: `${file}:${owner}` });
    }
  }
  return sites;
}

export function timerConstants(srcDir = defaultSrc) {
  const constants = new Map();
  const declarationPattern = /const (TIMER_[A-Z_0-9]+)\s*(?::\s*[a-z0-9]+)?\s*=\s*(0x[0-9A-Fa-f]+|\d+);/g;
  for (const name of fs.readdirSync(srcDir).filter(n => n.endsWith('.zig'))) {
    const text = fs.readFileSync(path.join(srcDir, name), 'utf8');
    for (const match of text.matchAll(declarationPattern)) {
      if (name === 'idle_budget.zig') continue;
      const value = Number(match[2]);
      if (constants.has(match[1]) && constants.get(match[1]) !== value) throw new Error(`${match[1]} is declared with two values`);
      constants.set(match[1], value);
    }
  }
  return constants;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const timers = {};
  for (const site of scanTimerSites()) {
    timers[site.timer] = timers[site.timer] || new Set();
    timers[site.timer].add(site.file);
  }
  const fetches = [...new Set(scanFetchSites().map(site => site.key))].sort();
  console.log(JSON.stringify({ timers: Object.fromEntries(Object.entries(timers).map(([k, v]) => [k, [...v].sort()])), fetches }, null, 2));
}
