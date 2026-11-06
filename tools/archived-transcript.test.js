const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const reader = path.join(__dirname, '..', 'src', 'chat_history_reader.py');

const probe = String.raw`
import json, os, re, sys
from pathlib import Path
home = Path(sys.argv[1])
os.environ["HOME"] = str(home)
os.environ.pop("CLAUDE_CONFIG_DIR", None)
source = open(sys.argv[2], encoding="utf-8").read()
namespace = {"__name__": "reader"}
exec(compile(re.search(r"READER_SOURCE = r'''(.*?)'''", source, re.S).group(1), "reader", "exec"), namespace)
found = namespace["conversation_path"]("claude", sys.argv[3], sys.argv[4], home)
print(json.dumps(str(found) if found else None))
`;

test('a transcript the disk cleanup moved to another volume and linked back still opens', { skip: process.platform !== 'linux' }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-archived-'));
  try {
    const home = path.join(dir, 'home');
    const cwd = '/home/someone/projects/work';
    const folder = path.join(home, '.claude', 'projects', '-home-someone-projects-work');
    const archive = path.join(dir, 'volume', 'claude-projects-archive', '-home-someone-projects-work');
    fs.mkdirSync(folder, { recursive: true });
    fs.mkdirSync(archive, { recursive: true });
    const sid = '75f6b20f-dc9b-4bff-bb73-9284f021b764';
    const target = path.join(archive, sid + '.jsonl');
    fs.writeFileSync(target, JSON.stringify({ type: 'user', message: { role: 'user', content: 'hello?' } }) + '\n');
    const link = path.join(folder, sid + '.jsonl');
    fs.symlinkSync(target, link);
    const found = JSON.parse(execFileSync('python3', ['-I', '-X', 'utf8', '-c', probe, home, reader, sid, cwd], { encoding: 'utf8' }));
    assert.equal(found, link, 'an archived, linked-back transcript must resolve so resume and history keep working');

    const plain = 'a1b2c3d4-0000-4000-8000-000000000000';
    fs.writeFileSync(path.join(folder, plain + '.jsonl'), '{}\n');
    const plainFound = JSON.parse(execFileSync('python3', ['-I', '-X', 'utf8', '-c', probe, home, reader, plain, cwd], { encoding: 'utf8' }));
    assert.equal(plainFound, path.join(folder, plain + '.jsonl'));

    const renamed = 'c3d4e5f6-0000-4000-8000-000000000000';
    fs.writeFileSync(path.join(dir, 'secret.txt'), 'not a transcript\n');
    fs.symlinkSync(path.join(dir, 'secret.txt'), path.join(folder, renamed + '.jsonl'));
    const renamedFound = JSON.parse(execFileSync('python3', ['-I', '-X', 'utf8', '-c', probe, home, reader, renamed, cwd], { encoding: 'utf8' }));
    assert.equal(renamedFound, null, 'a link to some other file outside the projects folder is not a transcript');

    const outsider = 'b2c3d4e5-0000-4000-8000-000000000000';
    fs.symlinkSync(path.join(dir, 'missing-target.jsonl'), path.join(folder, outsider + '.jsonl'));
    const outsiderFound = JSON.parse(execFileSync('python3', ['-I', '-X', 'utf8', '-c', probe, home, reader, outsider, cwd], { encoding: 'utf8' }));
    assert.equal(outsiderFound, null, 'a dangling link is not a transcript');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
