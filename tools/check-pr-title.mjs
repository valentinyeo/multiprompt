import process from 'node:process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const leadingTicket = /^[A-Z][A-Z0-9]*-\d+:/;
const usage = 'Usage: PR_TITLE="SOFT-123: Fix the release build" node tools/check-pr-title.mjs';

export function checkTitle(title) {
  const value = (title || '').trim();
  if (!value) throw new Error(`Pull request title is empty; start it with the ticket that owns the change, for example "SOFT-123: Fix the release build"\n${usage}`);
  if (!leadingTicket.test(value)) {
    throw new Error(`Pull request title "${value}" lacks a leading ticket ID; start it with the ticket that owns the change, for example "SOFT-123: ${value}"\nA release names its notes after the ticket in every commit subject, so a ticketless pull request title blocks the next release.\n${usage}`);
  }
  return value;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const title = checkTitle(process.argv[2] ?? process.env.PR_TITLE);
    console.log(`Pull request title OK: ${title}`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
