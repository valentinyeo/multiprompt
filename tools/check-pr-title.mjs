import process from 'node:process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseTicketId } from './ticket-id.js';
import { checkMergeTitle } from './merge-title.js';

const leadingTicket = /^([A-Z][A-Z0-9]*-\d+(?:,\s*[A-Z][A-Z0-9]*-\d+)*):/;
const usage = 'Usage: PR_TITLE="SOFT-123: Fix the release build" node tools/check-pr-title.mjs';

export function checkTitle(title) {
  const value = (title || '').trim();
  if (!value) throw new Error(`Pull request title is empty; start it with the ticket that owns the change, for example "SOFT-123: Fix the release build"\n${usage}`);
  const lead = leadingTicket.exec(value)?.[1];
  const keys = lead ? lead.split(/,\s*/) : [];
  const rest = lead ? value.slice(lead.length).replace(/^\s*[,:]\s*/, '') : value;
  if (!keys.length) {
    throw new Error(`Pull request title "${value}" lacks a leading ticket ID; start it with the ticket that owns the change, for example "SOFT-123: ${value}"\nA release names its notes after the ticket in every commit subject, so a ticketless pull request title blocks the next release.\n${usage}`);
  }
  for (const key of keys) {
    if (!parseTicketId(key)) {
      throw new Error(`Pull request title "${value}" names ${key}, which is not a ticket this repository releases from; use IGSH, SOFT, HYCI or MUBO, for example "IGSH-235: ${rest}"\nA release names its notes after the ticket in every commit subject, so a ticket that no board resolves blocks the next release.\n${usage}`);
    }
  }
  return value;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const title = checkTitle(process.argv[2] ?? process.env.PR_TITLE);
    const keys = checkMergeTitle(title, (process.env.PR_FILES || '').split(/\s+/).filter(Boolean));
    console.log(`Pull request title OK: ${title}`);
    if (keys.length) console.log(`Changelog fragments agree: ${keys.join(', ')}`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
