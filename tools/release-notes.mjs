import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { compareTags, plainChange, productChange } from './version-stamp.mjs';

export function releaseNotes(source, tag) {
  const releases = [...source.matchAll(/\.\{ \.ver = "(\d+\.\d+\.\d+)",[^\n]*?\.items = &\.\{([\s\S]*?)\n    \}(?:, \.ticket = "(?:\\.|[^"\\])*")? \},/g)].map(match => {
    const strict = compareTags(`v${match[1]}`, 'v0.28.1027') >= 0;
    const items = [...match[2].matchAll(/\.text = ("(?:\\.|[^"\\])*"),\s*\.ticket = ("(?:\\.|[^"\\])*")/g)].map(item => {
      const literal = item[1].replace(/\\\\|\\u\{([\da-fA-F]+)\}|\\x([\da-fA-F]{2})|\\'/g, (escape, unicode, byte) => {
        if (unicode || byte) return JSON.stringify(String.fromCodePoint(parseInt(unicode || byte, 16))).slice(1, -1);
        return escape === "\\'" ? "'" : escape;
      });
      return { text: JSON.parse(literal), ticket: JSON.parse(item[2]) };
    });
    if (strict && (!items.length || items.length !== [...match[2].matchAll(/\.text\s*=/g)].length || items.some(item => !plainChange(item.text) || !/^(?:IGSH-\d+|https:\/\/app\.hypertask\.ai\/detail\/project-2060\/\d+)$/.test(item.ticket)))) {
      throw new Error(`Release ${match[1]} needs plain ticketed lines`);
    }
    const kept = items.filter(item => productChange(item.text) || item.text === 'Checks and fixes, no visible change');
    if (strict && kept.length !== items.length) throw new Error(`Release ${match[1]} has an unsupported line`);
    const release = { version: match[1], changes: kept.map(item => item.text) };
    if (strict) release.tickets = kept.map(item => item.ticket.startsWith('IGSH-') ? `https://app.hypertask.ai/detail/project-2060/${item.ticket.slice(5)}` : item.ticket);
    return release;
  });
  const version = tag.replace(/^v/, '');
  if (!releases.length || releases[0].version !== version) throw new Error('Release notes must start with the offered version');
  return { version, releases };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [source, tag, output] = process.argv.slice(2);
  if (!source || !tag || !output) throw new Error('Usage: node tools/release-notes.mjs <changelog> <tag> <output>');
  fs.writeFileSync(output, JSON.stringify(releaseNotes(fs.readFileSync(source, 'utf8'), tag)) + '\n');
}
