import fs from 'node:fs';

const forbidden = [
  [/\bseconds?\b/, 'seconds'],
  [/\bsecs?\b/, 'secs'],
  [/\bminutes?\b/, 'minutes'],
  [/\bmins?\b/, 'mins'],
  [/\ba few\b/, 'a few'],
  [/\btakes?\b/, 'takes'],
  [/\beta\b/, 'ETA'],
  [/~\s*\d+\s*s\b/, 'an approximate duration in seconds'],
];

export function stringLiterals(source) {
  return [...source.matchAll(/"(?:[^"\\\n]|\\.)*"/g)].map(match => match[0]);
}

export function timeWording(source) {
  const found = [];
  for (const literal of stringLiterals(source)) {
    const text = literal.slice(1, -1).toLowerCase();
    for (const [pattern, name] of forbidden) {
      if (pattern.test(text)) found.push({ literal, name });
    }
  }
  return found;
}

try {
  const args = process.argv.slice(2);
  if (args.length > 1) {
    throw new Error('Usage: node tools/check-update-card-time-wording.mjs [file]');
  }
  const file = args[0] ?? 'src/update_card.zig';
  const found = timeWording(fs.readFileSync(file, 'utf8'));
  if (found.length) {
    throw new Error(found.map(({ literal, name }) => `${file}: update cards never show a time estimate, and this text has ${name}: ${literal}`).join('\n'));
  }
  console.log(`${file}: the update card shows no time estimate.`);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
