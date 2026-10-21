import fs from 'node:fs';
import { pathToFileURL } from 'node:url';

export function releaseVersion(changelog, requestedTag = '') {
  const version = changelog.match(/\.ver\s*=\s*"(\d+\.\d+\.\d+)"/)?.[1];
  if (!version) throw new Error('No release version in src/changelog.zig');
  const tag = `v${version}`;
  if (requestedTag && requestedTag !== tag) throw new Error(`Release tag ${requestedTag} does not match ${tag}`);
  return tag;
}

if (process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url) {
  try {
    console.log(releaseVersion(fs.readFileSync(process.argv[2] || 'src/changelog.zig', 'utf8'), process.argv[3]));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
