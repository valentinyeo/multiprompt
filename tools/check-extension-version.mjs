import { execFileSync } from "node:child_process";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));

export function parseVersion(version) {
  if (typeof version !== "string" || !/^\d+\.\d+\.\d+$/.test(version) || version.trim() !== version) {
    throw new Error(`Invalid major.minor.patch version: ${version}`);
  }
  const parts = version.split(".").map(Number);
  if (!parts.every(Number.isSafeInteger)) throw new Error(`Invalid version: ${version}`);
  return parts;
}

export function compareVersions(left, right) {
  const a = parseVersion(left);
  const b = parseVersion(right);
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return a[i] > b[i] ? 1 : -1;
  }
  return 0;
}

export function isShippedFile(path) {
  return path.startsWith("extension/") && !path.endsWith(".test.js");
}

function main(args) {
  if (args.length < 1 || args.length > 2) {
    throw new Error("Usage: node tools/check-extension-version.mjs <base-ref> [head-ref]");
  }
  const [base, head = "HEAD"] = args;
  const git = (...args) => execFileSync("git", args, { cwd: root, encoding: "utf8" });
  const ancestor = git("merge-base", base, head).trim();
  const changed = git("diff", "--name-only", "--no-renames", "-z", ancestor, head, "--", "extension/")
    .split("\0").filter(isShippedFile);
  if (changed.length === 0) {
    console.log("extension unchanged");
    return;
  }
  const versionAt = (ref) => JSON.parse(git("show", `${ref}:extension/manifest.json`)).version;
  const before = versionAt(ancestor);
  const after = versionAt(head);
  if (compareVersions(after, before) <= 0) {
    throw new Error(`Extension changed: ${changed.join(", ")}. Version ${before} -> ${after} must increase; bump "version" in extension/manifest.json.`);
  }
  console.log(`Extension version ${before} -> ${after}`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
