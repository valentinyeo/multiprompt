import { readdirSync, readFileSync, existsSync, statSync } from 'node:fs';
import { join } from 'node:path';

const dist = new URL('./dist/', import.meta.url).pathname;

function htmlFiles(dir) {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return htmlFiles(path);
    return name.endsWith('.html') ? [path] : [];
  });
}

function resolves(href) {
  const path = decodeURIComponent(href.split(/[?#]/)[0]);
  const target = join(dist, path);
  return existsSync(join(target, 'index.html')) || (existsSync(target) && statSync(target).isFile());
}

const broken = [];
for (const file of htmlFiles(dist)) {
  for (const [, href] of readFileSync(file, 'utf8').matchAll(/href="(\/[^"]*)"/g)) {
    if (!href.startsWith('//') && !resolves(href)) broken.push(`${file.slice(dist.length)} -> ${href}`);
  }
}

if (broken.length) {
  console.error(`Broken internal links:\n${broken.join('\n')}`);
  process.exit(1);
}
console.log('All internal links resolve.');
