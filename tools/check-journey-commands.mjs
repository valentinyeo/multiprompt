import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { commandCatalog, root } from './journey-commands.mjs';

export function checkJourneyCommands(source, catalog = commandCatalog()) {
  const errors = [];
  for (const [index, line] of source.split(/\r?\n/).entries()) {
    const code = line.replace(/'(?:''|[^'])*'|"(?:`.|[^"`])*"|#[^\r\n]*/g, text => ' '.repeat(text.length));
    if (/(?:^|[;{}])\s*(?:&\s*)?(?:Focus-)?Palette\b(?!\s*=)/i.test(code)) {
      errors.push(`${index + 1}: use Invoke-JourneyCommand with a catalog name, not Palette/Focus-Palette queries or routing numbers`);
    }
    const call = /(?:^|[;{}])\s*Invoke-JourneyCommand\s+'([^']+)'([^\r\n]*)/i.exec(line);
    if (call && !/\s-Session\b/i.test(call[2]) && !catalog[call[1].toLowerCase()]) {
      errors.push(`${index + 1}: unknown command name ${call[1]}; use a current palette/shortcut row in tools/journey-commands.mjs`);
    }
    if (call && /\s(?:-Target\s+)?['"]?\d+(?:\s|['"]|$)/i.test(call[2])) {
      errors.push(`${index + 1}: Invoke-JourneyCommand resolves routing numbers from source; pass only its stable name`);
    }
  }
  return errors;
}

export function checkJourneys(directory = path.join(root, '.claude/skills/verify-multiprompt')) {
  const catalog = commandCatalog();
  return fs.readdirSync(directory, { recursive: true }).filter(file => file.endsWith('.ps1')).flatMap(file =>
    checkJourneyCommands(fs.readFileSync(path.join(directory, file), 'utf8'), catalog).map(error => `${file}:${error}`));
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const errors = checkJourneys(process.argv[2]);
  if (errors.length) {
    console.error(errors.join('\n'));
    process.exitCode = 1;
  } else {
    console.log('Journey commands use stable catalog names');
  }
}
