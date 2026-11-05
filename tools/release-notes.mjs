import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { ticketLine, ticketRecord } from './ticket-titles.mjs';
import { compareTags } from './version-stamp.mjs';

export function releaseNotes(source, tag) {
  const releases = [...source.matchAll(/\.\{ \.ver = "(\d+\.\d+\.\d+)",[^\n]*?\.items = &\.\{([\s\S]*?)\n    \}(?:, \.ticket = "(?:\\.|[^"\\])*")? \},/g)].map(match => {
    const items = [...match[2].matchAll(/\.text = ("(?:\\.|[^"\\])*"),\s*\.ticket = ("(?:\\.|[^"\\])*")/g)].map(item => {
      const literal = item[1].replace(/\\\\|\\u\{([\da-fA-F]+)\}|\\x([\da-fA-F]{2})|\\'/g, (escape, unicode, byte) => {
        if (unicode || byte) return JSON.stringify(String.fromCodePoint(parseInt(unicode || byte, 16))).slice(1, -1);
        return escape === "\\'" ? "'" : escape;
      });
      return { text: JSON.parse(literal), ticket: JSON.parse(item[2]) };
    });
    if (!items.length && compareTags(`v${match[1]}`, 'v0.28.1027') >= 0) throw new Error(`Release ${match[1]} needs plain ticketed lines`);
    if (items.length !== [...match[2].matchAll(/\.text\s*=/g)].length) throw new Error(`Release ${match[1]} has malformed lines`);
    if (items.some(item => !item.ticket)) throw new Error(`Release ${match[1]} has an unidentified line`);
    const kept = items;
    for (const item of kept) {
      const prefix = `${item.ticket} `;
      if (!item.text.startsWith(prefix) || ticketLine(ticketRecord(item.ticket, item.text.slice(prefix.length))) !== item.text) throw new Error(`Release ${match[1]} has an invalid ticket title for ${item.ticket}`);
    }
    return {
      version: match[1],
      changes: kept.map(item => item.text),
      tickets: kept.map(item => `https://app.hypertask.ai/detail/project-${item.ticket.startsWith('IGSH-') ? '2060' : '11514'}/${item.ticket.split('-')[1]}`),
    };
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
