import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const SLOT_FIELD = "multiprompt_slot";

export const OLD_SHAPE_FILES = [
  "tools/fixtures/MUBO-294/servers.json",
  "tools/fixtures/SOFT-3139/servers.json"
];

export function serversFileNames(cwd = root) {
  const listed = execFileSync("git", ["ls-files", "-z"], { cwd, encoding: "utf8" }).split("\0");
  return listed.filter(name => name && name.split("/").at(-1) === "servers.json").sort();
}

export function problemsIn(name, text) {
  const oldShape = OLD_SHAPE_FILES.includes(name);
  let facts;
  try {
    facts = JSON.parse(text);
  } catch {
    return [`${name}: not JSON`];
  }
  const servers = facts && typeof facts === "object" && Array.isArray(facts.servers) ? facts.servers : null;
  if (!servers || servers.length === 0) return [`${name}: needs a non-empty "servers" list`];
  const problems = [];
  for (const [index, server] of servers.entries()) {
    if (!server || typeof server !== "object" || Array.isArray(server)) {
      problems.push(`${name}: server ${index} is not an object`);
      continue;
    }
    for (const field of ["id", "hostname"]) {
      if (typeof server[field] !== "string" || !server[field]) {
        problems.push(`${name}: server ${index} needs a non-empty "${field}"`);
      }
    }
    if (oldShape) continue;
    const slot = server[SLOT_FIELD];
    if (!Number.isInteger(slot) || slot < 0 || slot > 2) {
      problems.push(`${name}: server "${server.id ?? index}" needs "${SLOT_FIELD}": 0, 1 or 2 so every server names its account slot`);
    }
  }
  return problems;
}

function main() {
  const names = serversFileNames();
  if (!names.length) throw new Error("found no servers.json to check");
  for (const name of OLD_SHAPE_FILES) {
    if (!names.includes(name)) throw new Error(`${name} is listed as an older servers file snapshot but is missing`);
  }
  const problems = names.flatMap(name => problemsIn(name, readFileSync(resolve(root, name), "utf8")));
  if (problems.length) throw new Error(problems.join("\n"));
  console.log(`checked ${names.length} servers files`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    main();
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
