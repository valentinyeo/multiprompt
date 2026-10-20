const fs = require('node:fs');
const path = require('node:path');

function imports(source) {
  return [...source.matchAll(/\/\/[^\r\n]*|"(?:\\.|[^"\\])*"|@import\s*\(\s*"([^"\r\n]+\.zig)"\s*\)/g)]
    .filter(match => match[1]).map(match => match[1]);
}

function copyZig(roots, dest, srcDir = path.join(__dirname, '../src')) {
  srcDir = path.resolve(srcDir);
  const copied = new Set();
  function visit(file, importer) {
    const relative = path.relative(srcDir, file);
    if (!relative.endsWith('.zig') || relative === '..' || relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative)) return;
    const name = relative.split(path.sep).join('/');
    if (copied.has(name)) return;
    let source;
    try {
      source = fs.readFileSync(file, 'utf8');
    } catch (error) {
      throw new Error(`Cannot copy Zig file ${name} imported by ${importer}: ${error.message}`, { cause: error });
    }
    const target = path.join(dest, relative);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.copyFileSync(file, target);
    copied.add(name);
    for (const dependency of imports(source)) visit(path.resolve(path.dirname(file), dependency), name);
    for (const match of source.matchAll(/\/\/[^\r\n]*|"(?:\\.|[^"\\])*"|@embedFile\s*\(\s*"([^"\r\n]+)"\s*\)/g)) {
      if (!match[1]) continue;
      const asset = path.resolve(path.dirname(file), match[1]);
      const relativeAsset = path.relative(srcDir, asset);
      if (relativeAsset === '..' || relativeAsset.startsWith(`..${path.sep}`) || path.isAbsolute(relativeAsset)) throw new Error(`Embed outside source root: ${match[1]}`);
      const targetAsset = path.join(dest, relativeAsset);
      fs.mkdirSync(path.dirname(targetAsset), { recursive: true });
      fs.copyFileSync(asset, targetAsset);
    }
  }
  for (const root of roots) visit(path.resolve(srcDir, root), '<root>');
  return [...copied];
}

function handWrittenLists(jsSource) {
  const snippets = [];
  for (const match of jsSource.matchAll(/for\s*\(\s*(?:const|let|var)\s+\w+\s+of\s+\[[^\]]*\]\s*\)\s*(?:\{[\s\S]*?\n\s*\}|[^\n]*)/g)) {
    if (/['"][^'"\n]+\.zig['"]/.test(match[0]) && /\b(?:copyFileSync|writeFileSync)\s*\(/.test(match[0]) && /(?:src\/|['"](?:\.\.\/)?src['"])/.test(match[0])) snippets.push(match[0]);
  }
  for (const match of jsSource.matchAll(/\bcopyFileSync\s*\([^;]+;/g)) {
    if (/(?:src\/[^'"`]*\.zig|['"](?:\.\.\/)?src['"][^;]*['"][^'"\n]+\.zig['"])/.test(match[0]) && !snippets.some(snippet => snippet.includes(match[0]))) snippets.push(match[0]);
  }
  return snippets;
}

module.exports = { copyZig, imports, handWrittenLists };
