const fs = require('node:fs');
const path = require('node:path');

const masked = /\/\/[^\r\n]*|'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|@import\s*\(\s*"([^"\r\n]+)"\s*\)/g;

function importedNames(source) {
  return [...source.matchAll(masked)].filter(match => match[1]).map(match => match[1]);
}

function imports(source) {
  return importedNames(source).filter(name => name.endsWith('.zig'));
}

function dataImports(source) {
  return importedNames(source).filter(name => !name.endsWith('.zig') && name.includes('.'));
}

function copyZig(roots, dest, srcDir = path.join(__dirname, '../src')) {
  srcDir = path.resolve(srcDir);
  const copied = new Set();
  function visit(file, importer) {
    const relative = path.relative(srcDir, file);
    if (relative === '..' || relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative)) return;
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
    for (const dependency of dataImports(source)) {
      const data = path.resolve(path.dirname(file), dependency);
      const relativeData = path.relative(srcDir, data);
      if (relativeData === '..' || relativeData.startsWith(`..${path.sep}`) || path.isAbsolute(relativeData)) continue;
      const targetData = path.join(dest, relativeData);
      fs.mkdirSync(path.dirname(targetData), { recursive: true });
      if (fs.existsSync(data)) fs.copyFileSync(data, targetData);
    }
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

module.exports = { copyZig, imports, dataImports, handWrittenLists };
