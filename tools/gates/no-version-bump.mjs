import { execFileSync } from "node:child_process";

const diff = execFileSync("git", ["diff", "HEAD", "--", "src/main.zig"], { encoding: "utf8" });
const bumped = diff
  .split(/\r?\n/)
  .filter((line) => /^[+-]\s*const APP_VERSION\s*=/.test(line));
if (bumped.length > 0) {
  console.log("APP_VERSION changed:\n" + bumped.join("\n") + "\nadd changelog.d/<TICKET>-<slug>.md instead; the version is stamped after merge (node tools/version-stamp.mjs release)");
  process.exit(1);
}
console.log("NO-VERSION-BUMP-OK");
