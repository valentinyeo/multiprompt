import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile
import uuid

rows = [json.loads(line) for line in Path(sys.argv[1]).read_text(encoding='utf-8-sig').splitlines() if line.strip()]
record = next(row for row in rows if row.get('kind') == 'attach' and 'tmux if-shell -F -t ' in row.get('command', ''))
parts = shlex.split(record['command'][record['command'].index('tmux if-shell -F -t '):])
assert len(parts) == 8 and parts[:5] == ['tmux', 'if-shell', '-F', '-t', '=workspace'], parts
match = re.fullmatch(r'#\{==:#\{start_time\}:#\{pid\}:#\{session_id\},([0-9]+:[0-9]+:\$[0-9]+)\}', parts[5])
assert match, parts
old_identity = match[1]
old_id = old_identity.rsplit(':', 1)[1]
assert parts[6] == f"attach-session -t '{old_id}'", parts[6]
assert parts[7] == "display-message -p 'Saved terminal session changed; refusing to attach.'", parts[7]
server = 'igsh-985-' + uuid.uuid4().hex
base = ['tmux', '-L', server, '-f', '/dev/null']
env = dict(os.environ, TERM='xterm-256color')
env.pop('TMUX', None)

def tmux(*args):
    return subprocess.check_output([*base, *args], env=env, text=True).strip()

with tempfile.TemporaryDirectory(prefix='igsh985-') as scratch:
    marker = Path(scratch) / 'attached'
    def run(command):
        marker.unlink(missing_ok=True)
        process = subprocess.Popen(['script', '-qec', shlex.join(command), '/dev/null'], stdin=subprocess.PIPE, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        try:
            process.wait(timeout=10)
            return subprocess.CompletedProcess(command, process.returncode, process.stdout.read())
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            process.stdin.close()
            process.stdout.close()
    try:
        tmux('new-session', '-d', '-s', 'workspace', 'cat')
        before = tmux('list-sessions', '-F', '#{session_name}').splitlines()
        identity = tmux('display-message', '-p', '-t', '=workspace', '#{start_time}:#{pid}:#{session_id}')
        session_id = identity.rsplit(':', 1)[1]
        hook = 'run-shell ' + shlex.quote('touch ' + shlex.quote(str(marker))) + ' ; detach-client'
        tmux('set-hook', '-g', 'client-attached', hook)
        actual = list(parts)
        actual[5] = parts[5].replace(old_identity, identity)
        actual[6] = parts[6].replace(old_id, session_id)
        guarded = [*base, *actual[1:]]
        positive = run(guarded)
        assert positive.returncode == 0 and marker.exists(), positive.stdout
        tmux('rename-session', '-t', session_id, 'original-renamed')
        tmux('new-session', '-d', '-s', 'workspace', 'cat')
        replacement = tmux('display-message', '-p', '-t', '=workspace', '#{start_time}:#{pid}:#{session_id}')
        assert replacement != identity
        legacy = run([*base, 'attach-session', '-t', 'workspace'])
        assert legacy.returncode == 0 and marker.exists(), legacy.stdout
        refused = run(guarded)
        assert refused.returncode == 0 and not marker.exists() and 'refusing to attach' in refused.stdout, refused.stdout
        tmux('kill-session', '-t', '=workspace')
        tmux('new-session', '-d', '-s', 'workspace-long', 'cat')
        prefix_legacy = run([*base, 'attach-session', '-t', 'workspace'])
        assert prefix_legacy.returncode == 0 and marker.exists(), prefix_legacy.stdout
        prefix_guarded = run(guarded)
        assert not marker.exists(), prefix_guarded.stdout
        remaining = tmux('list-sessions', '-F', '#{session_name}').splitlines()
        assert before == ['workspace'] and set(remaining) == {'original-renamed', 'workspace-long'}, remaining
        print('REAL_TMUX_GENERATION_PROOF_OK original-attaches replacement-refused prefix-refused no-guard-created-sessions')
    finally:
        subprocess.run([*base, 'kill-server'], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
