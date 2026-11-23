const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const composer = fs.readFileSync(path.join(root, 'src/chat_composer.zig'), 'utf8');
const complete = fs.readFileSync(path.join(root, 'tools/agent-notifications/mp_complete.py'), 'utf8');
const chatComplete = fs.readFileSync(path.join(root, 'src/chat_complete.zig'), 'utf8');

test('SOFT-3053 inne paths always reach the inne completer host', () => {
  assert.match(composer, /fn chatAcCompleterHost\(host: u8, cwd: \[]const u8\) u8/);
  assert.match(composer, /return TMUX_HOST_INNE/);
  assert.doesNotMatch(composer, /req\.host == TMUX_HOST_DE and.*inne/);
  assert.match(composer, /const ac_host = chatAcCompleterHost\(req\.host, cwd\)/);
});

test('SOFT-3053 catalog slots store the remote shell path', () => {
  assert.match(composer, /fn chatAcShellPath\(shell: \*const Shell, host: u8\) \[]const u8/);
  assert.match(composer, /shellKnownRemotePath\(shell, host\)/);
  assert.match(composer, /const cwd = chatAcShellPath\(shell, host\)/);
});

test('SOFT-3102 folder skills come from the chat cwd', () => {
  const py = `
import importlib.util, json, os, tempfile
from pathlib import Path
spec = importlib.util.spec_from_file_location("mp_complete", ${JSON.stringify(path.join(root, 'tools/agent-notifications/mp_complete.py'))})
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
with tempfile.TemporaryDirectory() as home, tempfile.TemporaryDirectory() as repo:
    mod.HOME = Path(home).resolve()
    root = Path(repo)
    skill = root / ".claude/skills/verify-multiprompt/SKILL.md"
    skill.parent.mkdir(parents=True)
    skill.write_text("---\\nname: verify-multiprompt\\ndescription: Check changes\\n---\\n", encoding="utf-8")
    (Path(home) / ".claude").mkdir()
    (Path(home) / ".claude/settings.json").write_text("{}", encoding="utf-8")
    mod.PROJECT_SCAN_CACHE.clear()
    rows1 = mod.project_and_plugins(root, {})
    names1 = [r[1] for r in rows1]
    assert "verify-multiprompt" in names1, names1
    skill.write_text(skill.read_text(encoding="utf-8") + "\\n", encoding="utf-8")
    rows2 = mod.project_and_plugins(root, {})
    names2 = [r[1] for r in rows2]
    assert "verify-multiprompt" in names2, names2
    assert mod.PROJECT_SCAN_CACHE, "expected cwd skill cache"
print("folder skills ok")
`;
  const run = spawnSync('python3', ['-c', py], { encoding: 'utf8', timeout: 60000 });
  assert.equal(run.status, 0, run.stderr || run.stdout);
  assert.match(run.stdout, /folder skills ok/);
});

test('SOFT-3102 typo queries still find exact-prefix skills first', () => {
  assert.match(chatComplete, /startsWithOneSwap/);
  assert.match(chatComplete, /verify-multiprompt/);
});