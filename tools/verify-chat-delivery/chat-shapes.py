from collections import Counter
import hashlib
import json
from pathlib import Path
import random
import sys

POLICY = 'aggregate statistics only; all fixture text generated'
WORDS = 'The native chat fixture keeps message sizes and mixed layouts while using entirely generated content. '


def lengths(histogram):
    for size, count in histogram:
        if not isinstance(size, int) or size < 0 or not isinstance(count, int) or count < 1:
            raise ValueError('Invalid shape histogram')
        yield from [size] * count


def text(size, index, layout):
    if size < 1:
        return ''
    prefix = f'IGSH1040_TURN_{index:06d} '
    if size < len(prefix):
        prefix = 'Fixture '
    lines = max(1, layout.get('lines', 1))
    messages = max(1, layout.get('messages', 1))
    wrap = max(24, min(180, size * messages // lines))
    body = (WORDS * (size // len(WORDS) + 2))[:size]
    body = '\n'.join(body[n:n + wrap] for n in range(0, len(body), wrap))
    if index % 11 == 0 and size > 180 and layout.get('code_fences', 0):
        body = '```python\nvalue = 1040\nprint(value)\n```\n\n' + body
    elif index % 13 == 0 and size > 180 and layout.get('table_lines', 0):
        body = '| Name | Value |\n| --- | --- |\n| Fixture | 1040 |\n\n' + body
    elif index % 7 == 0 and size > 80 and layout.get('list_lines', 0):
        body = '- First generated item\n- Second generated item\n\n' + body
    return (prefix + body + ' ' * size)[:size]


def conversation(role, body, sid, index):
    return dict(type=role, timestamp='2026-01-01T00:00:00.000Z', sessionId=sid,
                uuid=f'fixture-{index:08d}', message=dict(role=role, id=f'fixture-{index:08d}', content=[dict(type='text', text=body)]))


def encoded(event):
    return json.dumps(event, separators=(',', ':'), ensure_ascii=True).encode() + b'\n'


def tool_record(size, index):
    identity = f'fixture-tool-{index // 2:08d}'
    if index % 2 == 0:
        part = dict(type='tool_use', id=identity, name='Bash', input=dict(command=''))
        event = dict(type='assistant', timestamp='2026-01-01T00:00:00.000Z', message=dict(content=[part]))
        target = part['input']
        key = 'command'
    else:
        part = dict(type='tool_result', tool_use_id=identity, content='')
        event = dict(type='user', timestamp='2026-01-01T00:00:00.000Z', message=dict(content=[part]))
        target = part
        key = 'content'
    minimum = len(encoded(event))
    if size < minimum:
        size = minimum
    target[key] = ('generated output ' * (size // 17 + 1))[:size - minimum]
    raw = encoded(event)
    if len(raw) != size:
        raise ValueError('Tool record size was not preserved')
    return raw, minimum


def generate(profile, path, sid, seed):
    if profile['conversation_messages'] < 1 or profile['conversation_messages'] != sum(count for role in ('user', 'assistant') for _, count in profile['lengths_utf16'][role]):
        raise ValueError('Conversation count differs from its nonempty size histograms')
    randomizer = random.Random(seed)
    messages = [(role, size) for role in ('user', 'assistant') for size in lengths(profile['lengths_utf16'][role])]
    randomizer.shuffle(messages)
    tools = list(lengths(profile['tool_record_bytes']))
    randomizer.shuffle(tools)
    runner_lengths = Counter(lengths(profile['runner_lengths_utf16']))
    available_lengths = Counter(size for role, size in messages)
    if runner_lengths - available_lengths or any(size < 6 for size in runner_lengths):
        raise ValueError('Runner lengths are not a subset of the measured messages')
    path.parent.mkdir(parents=True, exist_ok=True)
    first = f'IGSH1040_FIRST_{seed}'
    last = f'IGSH1040_LAST_{seed}'
    last_raw = encoded(conversation('assistant', last, sid, len(messages) + 1))
    written, records, minimum_expansions, tool_count, marked, runner_count = 0, 0, 0, 0, 0, 0
    digest = hashlib.sha256()
    generated_lengths = {'user': {}, 'assistant': {}}
    with path.open('wb') as output:
        def write(raw):
            nonlocal written, records
            output.write(raw)
            digest.update(raw)
            written += len(raw)
            records += raw.count(b'\n')

        write(encoded(conversation('user', first, sid, 0)))
        tool_index = 0
        for index, (role, size) in enumerate(messages, 1):
            body = text(size, index, profile['layout_totals'])
            if runner_lengths[size] > 0:
                body = ('[from fixture-runner] ' + body)[:size]
                runner_lengths[size] -= 1
                runner_count += 1
            if len(body.encode('utf-16-le')) // 2 != size:
                raise ValueError('Conversation length changed')
            marked += body.startswith('IGSH1040_TURN_')
            generated_lengths[role][size] = generated_lengths[role].get(size, 0) + 1
            write(encoded(conversation(role, body, sid, index)))
            due = len(tools) * index // max(1, len(messages))
            while tool_index < due:
                size = tools[tool_index]
                raw, minimum = tool_record(size, tool_index)
                minimum_expansions += size < minimum
                write(raw)
                tool_index += 1
                tool_count += 1
        source_padding = 0
        if profile['source_completeness'] == 'complete-host-log':
            remaining = profile['source_bytes'] - written - len(last_raw)
            padding_records = profile['source_records'] - len(messages) - len(tools)
            minimum = len(encoded(dict(type='system', fixture_padding='')))
            if padding_records < 0 or remaining < padding_records * minimum:
                raise ValueError('Measured source cannot hold the generated records and markers')
            for index in range(padding_records):
                chunk = remaining // (padding_records - index)
                raw = encoded(dict(type='system', fixture_padding='x' * (chunk - minimum)))
                write(raw)
                source_padding += len(raw)
                remaining -= len(raw)
            if remaining:
                write(b' ' * remaining)
                source_padding += remaining
        write(last_raw)
    expected = {role: sorted((int(k), v) for k, v in values.items()) for role, values in generated_lengths.items()}
    for role in ('user', 'assistant'):
        if expected[role] != [tuple(value) for value in profile['lengths_utf16'][role]]:
            raise ValueError('Generated message length distribution changed')
    return dict(name=profile['name'], generated_bytes=written, generated_records=records, sha256=digest.hexdigest(),
                source_completeness=profile['source_completeness'], measured_source_bytes=profile['source_bytes'],
                source_conversation_messages=len(messages), marker_messages=2, marked_conversation_messages=marked,
                generated_conversation_messages=len(messages) + 2, tool_records=tool_count, runner_messages=runner_count,
                tool_records_expanded_to_valid_json=minimum_expansions, ignored_source_padding_bytes=source_padding,
                first_marker=first, last_marker=last)


def seed(shape_file, state_file):
    shapes = json.loads(Path(shape_file).read_text())
    state = json.loads(Path(state_file).read_text(encoding='utf-8-sig'))
    if shapes['schema'] != 1 or shapes['content_policy'] != POLICY or len(shapes['sessions']) != 5 or len(state['sessions']) != 5:
        raise ValueError('Five measured shape profiles and saved sessions must agree')
    result = []
    for index, (name, profile) in enumerate(zip(state['sessions'], shapes['sessions'])):
        sid = state['sids'][name]
        folder = f'C--verify-work{index}'
        path = Path(state['home']) / '.claude/projects' / folder / f'{sid}.jsonl'
        result.append(generate(profile, path, sid, index + 1))
    manifest = dict(schema=1, policy=POLICY, shape_sha256=hashlib.sha256(Path(shape_file).read_bytes()).hexdigest(), sessions=result)
    Path(state_file).with_name('chat-shape-manifest.json').write_text(json.dumps(manifest, indent=2))
    return manifest


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('Usage: chat-shapes.py SHAPE_JSON STATE_JSON')
    value = seed(sys.argv[1], sys.argv[2])
    print(json.dumps(value))
