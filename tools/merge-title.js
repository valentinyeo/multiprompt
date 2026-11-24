const { canonicalTicketId, parseTicketId } = require('./ticket-id.js');

const fragmentFile = /^changelog\.d\/([A-Z][A-Z0-9]*-\d+)-[^/]+\.md$/;
const leadingKeys = /^([A-Z][A-Z0-9]*-\d+(?:,\s*[A-Z][A-Z0-9]*-\d+)*)(?::|,|\s)/;
const trailingNumber = /\s*\(#\d+\)$/;
const usage = 'The squash title is built from the pull request title and its changelog fragments; nobody types it.';

function compareKeys(a, b) {
  const [, prefix, number] = /^([A-Z][A-Z0-9]*)-(\d+)$/.exec(a);
  const [, otherPrefix, otherNumber] = /^([A-Z][A-Z0-9]*)-(\d+)$/.exec(b);
  if (prefix !== otherPrefix) return prefix < otherPrefix ? -1 : 1;
  const left = BigInt(number);
  const right = BigInt(otherNumber);
  return left === right ? 0 : left < right ? -1 : 1;
}

function orderedKeys(values) {
  return [...new Set(values)].sort(compareKeys);
}

function fragmentKeys(files) {
  const written = new Map();
  for (const file of files || []) {
    const key = fragmentFile.exec(String(file))?.[1];
    if (!key) continue;
    const id = canonicalTicketId(key);
    if (!written.has(id)) written.set(id, key);
  }
  return orderedKeys([...written.values()]);
}

function titleKeys(title) {
  const lead = leadingKeys.exec(String(title || '').trim())?.[1];
  const written = new Map();
  for (const key of lead ? lead.split(/,\s*/) : []) {
    const id = parseTicketId(key)?.id;
    if (id && !written.has(id)) written.set(id, key);
  }
  return orderedKeys([...written.values()]);
}

function titleText(title) {
  const value = String(title || '').trim().replace(trailingNumber, '');
  const lead = leadingKeys.exec(value)?.[1];
  return (lead ? value.slice(lead.length).replace(/^\s*[,:]\s*/, '') : value).trim();
}

function mergeHeadline(title, files, number) {
  if (!Number.isSafeInteger(number) || number <= 0) throw new Error(`Invalid pull request number: ${number}`);
  const text = titleText(title);
  if (!text) throw new Error(`Pull request title "${title}" has no text after its ticket keys\n${usage}`);
  const named = fragmentKeys(files);
  const keys = named.length ? named : titleKeys(title);
  return `${keys.length ? `${keys.join(', ')}: ` : ''}${text} (#${number})`;
}

function checkMergeTitle(title, files) {
  const expected = fragmentKeys(files);
  if (!expected.length) return [];
  const named = titleKeys(title);
  const expectedIds = orderedKeys(expected.map(key => canonicalTicketId(key)));
  const namedIds = orderedKeys(named.map(key => canonicalTicketId(key)));
  if (namedIds.length === expectedIds.length && namedIds.every((id, index) => id === expectedIds[index])) return expected;
  throw new Error(`Pull request title "${title}" leads with ${named.length ? named.join(', ') : 'no ticket key'}, but its changelog fragments name ${expected.join(', ')}\nStart the title with the same keys as the fragments, for example "${expected[0]}: ${titleText(title)}", so the squash title releases the tickets the release notes come from.\n${usage}`);
}

module.exports = { compareKeys, fragmentKeys, titleKeys, titleText, mergeHeadline, checkMergeTitle };
