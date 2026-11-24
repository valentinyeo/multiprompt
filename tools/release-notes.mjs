import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseTicketId, unlinkedTicketId } from './ticket-id.js';
import { ticketLine, ticketRecord } from './ticket-titles.mjs';
import { compareTags, userFacingTitle, userFacingReleaseLine } from './version-stamp.mjs';

function unlinkedText(text) {
  let value = (typeof text === 'string' ? text : '').replace(/[\x00-\x1f\x7f]/g, ' ').trim();
  while (Buffer.byteLength(value) > 512) value = value.slice(0, -1).trim();
  if (!value || Buffer.from(value).toString('utf8') !== value) return null;
  return value;
}

export function releaseNotes(source, tag, warn = () => {}) {
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
    const unlinked = text => {
      const value = unlinkedText(text);
      return value ? [{ text: value, ticket: null }] : [];
    };
    const kept = items.flatMap(item => {
      if (!item.ticket) {
        warn(`Release ${match[1]}: a line has no ticket key; publishing it without a link`);
        return unlinked(item.text);
      }
      const ticket = item.ticket === unlinkedTicketId ? null : parseTicketId(item.ticket);
      if (!ticket) {
        if (item.ticket !== unlinkedTicketId) warn(`Release ${match[1]}: ${item.ticket} is not a ticket key this repository releases from; publishing its line without a link`);
        return unlinked(item.text);
      }
      const prefix = `${item.ticket} `;
      if (!item.text.startsWith(prefix)) {
        const visible = userFacingTitle(item.text);
        warn(`Release ${match[1]}: ${item.ticket} has no title after its key; ${visible ? 'publishing its line without a link' : 'leaving the line out'}`);
        return visible ? unlinked(item.text) : [];
      }
      try {
        const record = ticketRecord(item.ticket, item.text.slice(prefix.length));
        return [{ text: ticketLine(record), ticket: record.id }];
      } catch (error) {
        const remainder = item.text.slice(prefix.length).trim();
        const visible = !!remainder && userFacingTitle(remainder);
        warn(`Release ${match[1]}: ${item.ticket} has no title this release can publish (${error.message}); ${visible ? 'publishing its line without a link' : 'leaving the line out'}`);
        return visible ? unlinked(remainder) : [];
      }
    });
    const visible = kept.filter(item => !item.ticket || userFacingReleaseLine(item.text));
    return {
      version: match[1],
      changes: visible.map(item => item.text),
      tickets: visible.map(item => {
        if (!item.ticket) return null;
        const ticket = parseTicketId(item.ticket);
        return `https://app.hypertask.ai/detail/project-${ticket.boardId}/${ticket.number}`;
      }),
    };
  });
  const version = tag.replace(/^v/, '');
  if (!releases.length || releases[0].version !== version) throw new Error('Release notes must start with the offered version');
  return { version, releases };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [source, tag, output] = process.argv.slice(2);
  if (!source || !tag || !output) throw new Error('Usage: node tools/release-notes.mjs <changelog> <tag> <output>');
  fs.writeFileSync(output, JSON.stringify(releaseNotes(fs.readFileSync(source, 'utf8'), tag, line => console.error(`Release notes warning: ${line}`))) + '\n');
}
