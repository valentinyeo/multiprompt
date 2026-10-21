#!/usr/bin/env python3
"""Public snapshot privacy checks and portable contributor verification."""
import argparse
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
IGNORED = {'.git', 'node_modules', '.zig-cache', 'zig-cache', 'zig-out', 'zig-out-arm', '__pycache__', '.astro', 'dist', '.wrangler'}
PRIVATE = re.compile(r'(?i)yeo[u]x|hyperta[s]k\.ai|\b[\w.-]+\.ts\.net|gma[i]l|/home/va[l]entin|Users[\\/]+va[l]en\b|\bva[l]entin\b(?! Yeo)|\b(?:IGSH|HTPR|YPER4|HELL)[-_]\d+|\bin[n]e\b|hetz[n]er|conta[b]o')
PRIVATE_REPOSITORY = re.compile(r'(?i)github\.com/valentinyeo/zig[s]hell(?:\b|[/.])')
IPV4 = re.compile(r'(?<![\w.])(?:\d{1,3}\.){3}\d{1,3}(?![\w.])')
EMAIL = re.compile(r'(?<![\\\w.+-])[\w.+-]+@[\w.-]+\.[a-zA-Z]{2,}')


def files():
    for directory, dirs, names in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in IGNORED and not d.startswith('.audit')]
        for name in names:
            if not name.startswith(('.audit', '.sanitize')):
                yield Path(directory) / name


def findings(text, path):
    result = []
    for number, line in enumerate(text.splitlines(), 1):
        if PRIVATE.search(line) or PRIVATE_REPOSITORY.search(line):
            result.append(f'{path}:{number}: private identity/domain')
        for match in EMAIL.finditer(line):
            domain = match[0].split('@')[1].lower()
            if not (domain.endswith(('.example', '.test', '.invalid')) or domain in {'example.com', 'example.net', 'example.org'}):
                result.append(f'{path}:{number}: non-example email')
        for match in IPV4.finditer(line):
            if path == 'extension/themes/current/manifest.json' and '"version"' in line:
                continue
            addr = ipaddress.IPv4Address(match[0])
            if not (addr.is_loopback or any(addr in ipaddress.IPv4Network(net) for net in ('192.0.2.0/24', '198.51.100.0/24', '203.0.113.0/24'))):
                result.append(f'{path}:{number}: non-example IPv4')
    return result


def check():
    assert findings('https://github.com/valentinyeo/' + 'zigshell/issues', 'fixture')
    assert not findings('https://github.com/valentinyeo/multiprompt', 'fixture')
    assert findings('user@' + 'personal.invalid-domain.com', 'fixture')
    assert findings('198.18.' + '0.1', 'fixture')
    assert findings('.tmux_session = "in' + 'ne-cro"', 'fixture')
    assert findings('Attach Hetz' + 'ner tmux Session', 'fixture')
    assert not findings('const command_in' + 'ne = 1; inner', 'fixture')
    assert findings('/home/va' + 'lentin/repo', 'fixture')
    assert not findings('user@example.com 127.0.0.1 192.0.2.10', 'fixture')
    errors = []
    for p in files():
        relative = p.relative_to(ROOT).as_posix()
        if p.name in {'AGENTS.md', 'CLAUDE.md', 'handoff.md', 'speedometer.md'} or p.name.startswith('GATES') or '.claude' in p.parts or 'agent-kit' in p.parts:
            errors.append(relative + ': internal-only path')
        if p.parent == ROOT and p.suffix.lower() == '.png':
            errors.append(relative + ': root screenshot')
        try:
            text = p.read_text()
        except UnicodeDecodeError:
            continue
        errors.extend(findings(text, relative))
    assert not errors, '\n'.join(errors)
    cfg = json.loads((ROOT / 'service/wrangler.jsonc').read_text())
    assert cfg['account_id'] == 'YOUR_CLOUDFLARE_ACCOUNT_ID'
    assert cfg['d1_databases'][0]['database_id'] == 'YOUR_D1_DATABASE_ID'
    assert not {'ACCESS_TEAM', 'ACCESS_AUD'} & cfg['vars'].keys()
    print('PUBLIC_AUDIT_OK')


def metadata():
    readme = (ROOT / 'README.md').read_text()
    for text in ('Windows only', 'Zig 0.16', 'zig build', 'https://multiprompt.dev', 'https://github.com/valentinyeo/multiprompt-android'):
        assert text in readme
    assert '[MIT](LICENSE)' in readme
    assert '\u2014' not in readme
    license_text = (ROOT / 'LICENSE').read_text()
    assert 'MIT License' in license_text and 'Copyright (c) 2026 Valentin Yeo' in license_text
    for path in ('zig-out/', 'zig-out-arm/', '.zig-cache/', 'zig-cache/'):
        assert path in (ROOT / '.gitignore').read_text().splitlines()
    for text in ('ACCOUNT_EMAIL', 'ALLOWED_EMAILS', 'AUTH_ORIGINS', 'database_id', 'account_id'):
        assert text in (ROOT / 'service/README.md').read_text()
    assert 'env.ACCOUNT_EMAIL' in (ROOT / 'service/worker.js').read_text()
    assert (ROOT / 'src/fonts/OFL.txt').is_file()
    expected_workflows = {'release.yml', 'test.yml', 'gitleaks.yml', 'no-comments.yml', 'extension-version.yml', 'docs-site.yml'}
    assert {p.name for p in (ROOT / '.github/workflows').glob('*.yml')} == expected_workflows
    for p in (ROOT / '.github').rglob('*.yml'):
        text = p.read_text()
        for ref in re.findall(r'(?<![\w/])(?:tools|tests|extension|src|docs-site)/[\w./*-]+', text):
            assert list(ROOT.glob(ref)), f'{p.relative_to(ROOT)}: missing {ref}'
    for ref in re.findall(r'"((?:src|tools|tests|extension)/[^"\n]+)"', (ROOT / 'build.zig').read_text()):
        assert (ROOT / ref).exists(), f'build.zig: missing {ref}'
    print('PUBLIC_METADATA_OK')


def run(args, cwd=ROOT):
    print('+', ' '.join(map(str, args)), flush=True)
    subprocess.run(args, cwd=cwd, check=True)


def verify():
    zig = shutil.which(os.environ.get('ZIG', 'zig'))
    assert zig, 'Zig compiler not found'
    zig = str(Path(zig).resolve())
    os.environ['ZIG'] = os.environ['ZIG_EXE'] = zig
    os.environ['PATH'] = str(Path(zig).parent) + os.pathsep + os.environ.get('PATH', '')
    assert subprocess.check_output([zig, 'version'], text=True).startswith('0.16.')
    try:
        run([zig, 'build', '-Dtarget=x86_64-windows-gnu'])
        run([zig, 'build', 'test-vps', '--summary', 'all'])
        excluded = {'main.zig', 'bridge.zig', 'account_client.zig', 'sync_vault.zig', 'sync_auth.zig', 'usage_telemetry.zig', 'fonts.zig'}
        portable = [p for p in sorted((ROOT / 'src').glob('*.zig')) if p.name not in excluded and '@import("app_state.zig")' not in p.read_text() and re.search(r'^test ', p.read_text(), re.M)]
        for p in portable:
            optimize = ['-O', 'ReleaseFast'] if p.name == 'chat_perf_test.zig' else []
            run([zig, 'test', str(p.relative_to(ROOT)), *optimize])
        run([zig, 'fmt', '--check', 'build.zig', *map(str, (p.relative_to(ROOT) for p in sorted((ROOT / 'src').glob('*.zig'))))])
        run(['node', 'tools/json-reader/benchmark.mjs'])
        tests = sorted(str(p.relative_to(ROOT)) for folder in ('tools', 'extension') for p in (ROOT / folder).glob('*.test.js'))
        run(['node', '--test', '--test-concurrency=2', *tests])
        for folder in ('tools/agent-notifications', 'tools/usage-telemetry', 'tests'):
            run(['python3', '-m', 'unittest', 'discover', '-s', folder, '-p', 'test_*.py'])
        run(['python3', 'tools/chat-history-reader-test.py'])
        run(['python3', 'tests/session_sync_checks.py'])
        for folder in ('service', 'docs-site'):
            if not (ROOT / folder / 'node_modules').exists():
                run(['npm', 'ci', '--no-audit', '--no-fund'], ROOT / folder)
        run(['npm', 'test'], ROOT / 'service')
        run(['npm', 'run', 'check'], ROOT / 'docs-site')
        for p in sorted((ROOT / 'tools').rglob('*.sh')):
            run(['bash', '-n', str(p.relative_to(ROOT))])
        print(f'Portable Zig modules verified: {len(portable)}')
    finally:
        for name in ('zig-out', 'zig-out-arm', '.zig-cache', 'zig-cache', 'service/node_modules', 'docs-site/node_modules', 'docs-site/dist', 'docs-site/.astro', 'service/.wrangler'):
            shutil.rmtree(ROOT / name, ignore_errors=True)
        for directory, dirs, _ in os.walk(ROOT):
            for name in list(dirs):
                if name == '__pycache__':
                    shutil.rmtree(Path(directory) / name)
                    dirs.remove(name)
    assert not (ROOT / 'zig-out').exists() and not (ROOT / '.zig-cache').exists()
    print('BUILD_TESTS_OK')


def commit():
    output = lambda *args: subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()
    assert output('rev-list', '--count', 'HEAD') == '1'
    assert output('log', '-1', '--format=%s') == 'Initial public release'
    assert output('log', '-1', '--format=%an <%ae>|%cn <%ce>') == 'Valentin Yeo <maintainer@example.com>|Valentin Yeo <maintainer@example.com>'
    assert not output('status', '--porcelain')
    assert not output('remote')
    run(['git', 'show', '--format=', '--check', 'HEAD'])
    print('LOCAL_COMMIT_OK')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    for mode in ('check', 'metadata', 'verify', 'commit'):
        group.add_argument('--' + mode, action='store_true')
    args = parser.parse_args()
    os.chdir(ROOT)
    {'check': check, 'metadata': metadata, 'verify': verify, 'commit': commit}[next((k for k, v in vars(args).items() if v), 'check')]()
