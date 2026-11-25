import base64
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import time


def sha256_file(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def strip_frontmatter(text):
    if not text.startswith('---\n'):
        return text.strip()
    marker = text.find('\n---', 3)
    if marker < 0:
        return text.strip()
    return text[marker + 4:].strip()


def run_text(argv):
    return subprocess.run(argv, capture_output=True, text=True, check=True).stdout.strip()


def main():
    root = Path(sys.argv[1])
    sid = 'a1b2c3d4-2567-4000-8000-000000000523'
    tmux_name = 'live-pi-ci'
    home = Path.home()
    work = home / 'work'
    work.mkdir(parents=True, exist_ok=True)
    agent_dir = home / '.pi/agent'
    agent_dir.mkdir(parents=True, exist_ok=True)
    settings_path = agent_dir / 'settings.json'
    settings_path.write_text(json.dumps({
        'defaultProvider': 'openai-codex',
        'defaultModel': 'gpt-6.1-sol',
        'enableSkillCommands': True,
    }, indent=2) + '\n', encoding='utf-8')
    auth_path = agent_dir / 'auth.json'
    if not auth_path.is_file():
        raise RuntimeError('Missing Pi auth.json before real-Pi seed')
    auth_mode = os.stat(auth_path).st_mode & 0o777
    if auth_mode != 0o600:
        raise RuntimeError(f'Pi auth.json permissions are {oct(auth_mode)}, expected 0o600')
    skill_dir = agent_dir / 'skills/valentin-mode'
    responsive_dir = agent_dir / 'skills/responsive-mode'
    required_files = {
        'valentin_mode_skill_md': skill_dir / 'SKILL.md',
        'valentin_mode_context_py': skill_dir / 'context.py',
        'valentin_mode_version_sh': skill_dir / 'version.sh',
        'valentin_mode_version_stamp': skill_dir / 'VERSION',
        'responsive_mode_skill_md': responsive_dir / 'SKILL.md',
    }
    for name, path in required_files.items():
        if not path.is_file():
            raise RuntimeError(f'Missing required vstack skill file {name}: {path}')
    version_line = run_text(['sh', str(required_files['valentin_mode_version_sh'])])
    if not version_line or 'unknown' in version_line.lower():
        raise RuntimeError(f'Invalid valentin-mode version line: {version_line!r}')
    vstack_root = home / '.local/share/vstack'
    vstack_commit = run_text(['git', '-C', str(vstack_root), 'rev-parse', 'HEAD'])
    pi_version = run_text(['pi', '--version'])
    node_version = run_text(['node', '-v'])
    codex_version = run_text(['codex', '--version'])
    models_out = run_text(['pi', '--list-models'])
    has_codex_sol = any('openai-codex' in line and 'gpt-6.1-sol' in line for line in models_out.splitlines())
    if not has_codex_sol:
        raise RuntimeError('pi --list-models did not advertise openai-codex/gpt-6.1-sol')
    body_text = strip_frontmatter(required_files['valentin_mode_skill_md'].read_text(encoding='utf-8'))
    provenance = {
        'pi_version': pi_version,
        'node_version': node_version,
        'codex_version': codex_version,
        'vstack_repo': 'https://github.com/valentinyeo/vstack',
        'vstack_commit': vstack_commit,
        'valentin_mode_version_line': version_line,
        'valentin_mode_skill_path': str(required_files['valentin_mode_skill_md']),
        'valentin_mode_body_sha256': hashlib.sha256(body_text.encode('utf-8')).hexdigest(),
        'file_sha256': {name: sha256_file(path) for name, path in required_files.items()},
        'pi_models_has_openai_codex_gpt_6_1_sol': has_codex_sol,
    }
    sources = {name: base64.b64encode((root / f'src/chat_connectors/{name}.py').read_bytes()).decode() for name in ('claude', 'codex')}
    reader = runpy.run_path(str(root / 'src/chat_history_reader.py'), init_globals=dict(CONNECTOR_SOURCES=sources))
    subprocess.run(['tmux', 'new-session', '-d', '-s', tmux_name, '-c', str(work)], check=True)
    result = reader['host_cli'](['enable', 'pi', sid, '--tmux', tmux_name, '--cwd', str(work)])
    assert result['status'] == 'enabled', result
    paths = reader['host_paths']('pi', sid)
    config = reader['host_read'](paths['config'])
    if 'command' in config:
        raise RuntimeError('Real Pi seed must not set a custom provider command')
    started = reader['host_start']('pi', sid)
    assert started['status'] in ('started', 'already'), started
    ready = None
    for _ in range(200):
        events = reader['message_events_page']('pi', sid, 0)['events']
        ready = next((entry for entry in events if entry['event'].get('kind') == 'host.status' and entry['event'].get('payload', {}).get('state') == 'ready'), None)
        if ready is not None:
            break
        time.sleep(0.1)
    if ready is None:
        raise RuntimeError('Real Pi host did not become ready')
    print(json.dumps({
        'sid': sid,
        'provider': 'pi',
        'tmux': tmux_name,
        'cwd': str(work),
        'home': str(home),
        'ready': ready,
        'provenance': provenance,
    }))


if __name__ == '__main__':
    main()
