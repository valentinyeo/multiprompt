import argparse
import cProfile
import json
from pathlib import Path
import pstats
import re
import random
import secrets
import subprocess
import time
import tempfile
import types
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def load_reader(baseline=None):
    module = types.ModuleType('original_reader' if baseline else 'new_reader')
    source = git('show', baseline + ':src/chat_history_reader.py') if baseline else (ROOT / 'src/chat_history_reader.py').read_text()
    exec(compile(source, module.__name__, 'exec'), module.__dict__)
    return module


def candidates():
    found = []
    for pattern, agent in (('.claude/projects/*/*.jsonl', 'claude'), ('.codex/sessions/*/*/*/*.jsonl', 'codex')):
        for path in Path.home().glob(pattern):
            try:
                if path.is_file():
                    info = path.stat()
                    found.append((info.st_mtime_ns, path, agent, info.st_size))
            except OSError:
                continue
    return sorted(found, key=lambda item: item[0], reverse=True)


def phrases(reader, path, agent):
    first = middle = None
    distance = float('inf')
    size = path.stat().st_size
    with path.open('rb') as source:
        offset = 0
        for raw in source:
            try:
                event = json.loads(raw)
            except (ValueError, UnicodeError):
                offset += len(raw)
                continue
            row = reader.conversation_event(event, agent)
            if row:
                match = re.search(r'\b[A-Za-z0-9]+(?: [A-Za-z0-9]+){2,5}\b', row['text'])
                if match and len(match[0]) >= 12:
                    item = (match[0], offset, offset + len(raw))
                    if first is None:
                        first = item
                    if abs(offset - size / 2) < distance:
                        middle = item
                        distance = abs(offset - size / 2)
            offset += len(raw)
    assert first is not None and middle is not None, 'missing source phrases'
    return first, middle


def search(reader, path, agent, phrase, unlimited=False):
    query = dict(id=1, search=phrase, tmux='')
    clock = types.SimpleNamespace(monotonic=lambda: 0) if unlimited else time
    with patch.object(reader, 'time', clock):
        started = time.perf_counter()
        wire = reader.search_response(query, path, agent, path.stem)
        elapsed = time.perf_counter() - started
    lines = wire.splitlines()
    assert lines[-1] == reader.END
    header = lines[0].split('\t')
    rows = [json.loads(line) for line in lines[1:-1]]
    assert len(header) == 11 and int(header[7]) == len(rows)
    return wire, header, rows, elapsed


def profile(original, files):
    for index, (_, path, agent, size) in enumerate(files, 1):
        middle = phrases(original, path, agent)[1]
        profiler = cProfile.Profile()
        profiler.enable()
        _, header, _, elapsed = search(original, path, agent, middle[0])
        profiler.disable()
        print(f'profile file={index} agent={agent} bytes={size} elapsed={elapsed:.6f} hits={header[7]} truncated={header[8]}', flush=True)
        pstats.Stats(profiler).strip_dirs().sort_stats('cumulative').print_stats(18)
    print('ORIGINAL_PROFILE_COMPLETE', flush=True)


def equivalence(original, reader, files):
    picked = dict(claude=0, codex=0)
    searches = 0
    for _, path, agent, size in files:
        if picked[agent] == 20:
            continue
        early, middle = phrases(original, path, agent)
        needles = [early[0], middle[0], 'zq' + secrets.token_hex(12), 'straße', 'é', 'quote " and \\ path']
        for needle in needles:
            before = path.stat()
            expected, header, _, _ = search(original, path, agent, needle, unlimited=True)
            actual, _, _, _ = search(reader, path, agent, needle, unlimited=True)
            after = path.stat()
            assert (before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns), 'transcript changed during comparison'
            assert header[8] == '0', 'original hit cap prevents complete equivalence proof'
            assert actual == expected, f'output mismatch agent={agent} file={picked[agent] + 1} needle={needles.index(needle)}'
            searches += 1
        picked[agent] += 1
        print(f'equivalent agent={agent} file={picked[agent]} bytes={size} searches={len(needles)}', flush=True)
        if all(count == 20 for count in picked.values()):
            break
    assert picked == dict(claude=20, codex=20), picked
    print(f'REAL_SEARCH_EQUIVALENT files={sum(picked.values())} searches={searches}', flush=True)


def speed(reader, files):
    assert len(files) == 3 and max(item[3] for item in files) >= 170_000_000
    for index, (_, path, agent, size) in enumerate(files, 1):
        middle = phrases(reader, path, agent)[1]
        _, header, rows, elapsed = search(reader, path, agent, middle[0])
        print(f'speed file={index} agent={agent} bytes={size} elapsed={elapsed:.6f} hits={header[7]} truncated={header[8]} middle_fraction={middle[1] / size:.3f}', flush=True)
        assert 0.4 <= middle[1] / size <= 0.6, 'source phrase is not from the middle'
        assert header[8] == '0' and elapsed < 1.5, 'search exceeded budget'
        assert any((row['offset'], row['end']) == middle[1:] for row in rows), 'middle source hit missing'
    print('LARGE_SEARCH_WITHIN_BUDGET', flush=True)


def synthetic(original, reader):
    rng = random.Random(268)
    texts = ['distinctive needle', 'unrelated content', 'Straße ſtraße Kelvin ﬃle', 'é', 'quote " and \\ path',
             'pre<local-command-stdout>hidden</local-command-stdout>fix',
             '<command-name>deploy</command-name><command-args>production now</command-args>',
             'some<pasted_content>joined words</pasted_content> here', 'x' * 2000 + 'distinctive needle',
             'normalized   summary', 'x' * 300 + ' rawbase64 ' + 'A' * 300]
    needles = ['distinctive needle', 'strasse', 'straße', 'kelvin', 'ffile', 'é', 'quote " and \\ path',
               'prefix', 'deploy production', 'some joined words', 'normalized summary', 'image omitted',
               'Ran', 'Read example', 'None', '1e', '1000', 'missing randomly', 'i', 'name']
    checked = 0
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / 'fixture.jsonl'
        for agent in ('claude', 'codex'):
            for trial in range(8):
                events = []
                for index in range(60):
                    text = rng.choice(texts)
                    identity = rng.choice(['same', 'other', 'escaped/id', 'escaped\\id', 'é'])
                    timestamp = str(index)
                    role = rng.choice(['user', 'assistant'])
                    if agent == 'claude':
                        kind = rng.choice(['message', 'tool_use', 'tool_result'])
                        part = (dict(type='text', text=text) if kind == 'message' else
                                dict(type=kind, id=identity, name=rng.choice(['Bash', 'Read', 'Write', 'Unknown']),
                                     input=dict(command=text, description=text, file_path='project/example.txt'),
                                     tool_use_id=identity, content=text))
                        events.append(dict(type=role, timestamp=timestamp, message=dict(role=role, content=[part])))
                    else:
                        kind = rng.choice(['message', 'function_call', 'custom_tool_call', 'local_shell_call',
                                           'function_call_output', 'custom_tool_call_output', 'local_shell_call_output'])
                        events.append(dict(type='response_item', timestamp=timestamp,
                                           payload=dict(type=kind, role=role, content=[dict(type='input_text', text=text)],
                                                        call_id=identity, name='exec_command',
                                                        arguments=json.dumps(dict(cmd=text, description=text)), output=text)))
                with path.open('wb') as output:
                    for event in events:
                        raw = json.dumps(event, ensure_ascii=bool(rng.randrange(2))).encode()
                        if trial == 7:
                            raw = raw.replace(b'"type"', b'"ty\\u0070e"').replace(b'"id"', b'"i\\u0064"')
                        output.write(raw + b'\n')
                for needle in needles:
                    expected = search(original, path, agent, needle, unlimited=True)[0]
                    actual = search(reader, path, agent, needle, unlimited=True)[0]
                    assert actual == expected, f'synthetic mismatch agent={agent} trial={trial} needle={needle!r}'
                    checked += 1
        path.write_text(''.join(json.dumps(dict(type='assistant', message=dict(role='assistant', content='distinctive needle'))) + '\n' for _ in range(510)))
        expected, header, _, _ = search(original, path, 'claude', 'distinctive needle', unlimited=True)
        assert header[7:9] == ['500', '1']
        assert search(reader, path, 'claude', 'distinctive needle', unlimited=True)[0] == expected
        with patch.object(reader, 'tool_events', lambda event, agent, **kwargs: []):
            path.write_text(json.dumps(dict(type='assistant', message=dict(role='assistant', content=[dict(type='tool_use', id='control', name='Bash', input={})]))) + '\n'
                            + json.dumps(dict(type='user', message=dict(role='user', content=[dict(type='tool_result', tool_use_id='control', content='distinctive needle')]))) + '\n')
            assert search(reader, path, 'claude', 'distinctive needle', unlimited=True)[0] != search(original, path, 'claude', 'distinctive needle', unlimited=True)[0]
    print(f'SYNTHETIC_SEARCH_EQUIVALENT comparisons={checked + 1} negative_control=rejected', flush=True)


def commits(baseline):
    assert git('branch', '--show-current') == 'ceo/ISSUE-268-speed'
    history = git('rev-list', '--reverse', baseline + '..HEAD').splitlines()
    assert len(history) == 4, history
    assert git('show', '-s', '--format=%s', history[0]) == 'issue: search covers the whole transcript on 170 MB files'
    for change, pin in zip(history[::2], history[1::2]):
        assert git('diff-tree', '--no-commit-id', '--name-only', '-r', pin) == 'tools/public-export/manifest.json'
        pinned = json.loads(git('show', pin + ':tools/public-export/manifest.json'))['pinned']
        for file in git('diff-tree', '--no-commit-id', '--name-only', '-r', change).splitlines():
            if file in pinned:
                assert pinned[file] == git('rev-parse', change + ':' + file)
    changed = set(git('diff', '--name-only', baseline, 'HEAD').splitlines())
    allowed = {'src/chat_history_reader.py', 'tools/chat-history-reader-test.py', 'tools/chat-history-search-check.py',
               'tools/public-export/overlay/tools/chat-history-reader-test.py', 'tools/public-export/manifest.json'}
    assert changed == allowed, changed
    manifest = json.loads((ROOT / 'tools/public-export/manifest.json').read_text())
    for file in changed & manifest['pinned'].keys():
        assert manifest['pinned'][file] == git('hash-object', file)
    original = git('show', baseline + ':tools/chat-history-reader-test.py')
    public = git('show', baseline + ':tools/public-export/overlay/tools/chat-history-reader-test.py')
    private_now = (ROOT / 'tools/chat-history-reader-test.py').read_text().rstrip()
    public_now = (ROOT / 'tools/public-export/overlay/tools/chat-history-reader-test.py').read_text().rstrip()
    start = private_now.index('    def test_igsh268_search_prefilter_')
    end = private_now.index('    def test_igsh268_pure_function_', start)
    added = private_now[start:end]
    assert private_now.replace(added, '', 1) == original
    assert public_now.replace(added.replace('IGSH_', 'ISSUE_').replace('IGSH-', 'ISSUE-'), '', 1) == public
    assert not git('diff', 'HEAD', '--', *sorted(allowed)), 'uncommitted task changes'
    print(f'LOCAL_COMMITS_VERIFIED commits={",".join(history)}', flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--baseline', required=True)
    parser.add_argument('mode', choices=['profile', 'equivalence', 'speed', 'synthetic', 'commits'])
    args = parser.parse_args()
    if args.mode == 'commits':
        commits(args.baseline)
        return
    reader = load_reader()
    original = load_reader(args.baseline)
    if args.mode == 'synthetic':
        synthetic(original, reader)
        return
    files = candidates()
    largest = sorted(files, key=lambda item: item[3], reverse=True)[:3]
    if args.mode == 'profile':
        profile(original, largest)
    elif args.mode == 'equivalence':
        equivalence(original, reader, files)
    else:
        speed(reader, largest)


if __name__ == '__main__':
    main()
