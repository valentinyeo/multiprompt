import argparse
from collections import Counter
from pathlib import Path
import re
import subprocess


def inventory(source, step):
    prefix = source.split('    const test_groups =', 1)[0]
    dependencies = []
    for match in re.finditer(r'\b' + step + r'\.dependOn\((.+)\);', prefix):
        dependency = match[1]
        if dependency in ('&run.step', '&run_tests.step'):
            loop = prefix[:match.start()].rpartition('for ([_][]const u8{')[2]
            files = re.findall(r'"([^"]+)"', loop.split('}) |', 1)[0])
            assert files, dependency
            if dependency == '&run_tests.step':
                files = [file for file in files if file == 'src/workspace_view.zig']
            dependencies.extend(dependency + ':' + file for file in files)
        else:
            dependencies.append(dependency)
    assert dependencies and len(dependencies) == len(set(dependencies)), step
    return dependencies


def groups(source, step, array):
    routing = source.split(f'    for ({step}.dependencies.items) |dependency| {{', 1)[1]
    routing = routing.split(f'        {array}[group].dependOn(dependency);', 1)[0]
    expression = routing.split('const group: usize = ', 1)[1].strip()
    assignments = {}
    branches = re.findall(r'(?:else )?if \((.*?)\)\s*(\d+)\s*', expression, re.S)
    assert branches, array
    for condition, group in branches:
        references = re.findall(r'dependency == (&\w+\.step|\w+)', condition)
        assert references and re.fullmatch(r'\s*', re.sub(r'dependency == (?:&\w+\.step|\w+)|\bor\b', '', condition)), condition
        for reference in references:
            assert reference not in assignments, reference
            assignments[reference] = int(group)
    fallback = re.search(r'else\s+(\d+);$', expression)
    assert fallback, expression
    count = len(re.findall(r'b.step\("test-(?:vps-)?group-\d+"', source.split(f'    const {array} =', 1)[1].split('    };', 1)[0]))
    result = [[] for _ in range(count)]
    dependencies = inventory(source, step)
    assert set(assignments) <= set(dependencies), set(assignments) - set(dependencies)
    for dependency in dependencies:
        result[assignments.get(dependency, int(fallback[1]))].append(dependency)
    return result


def verify(before, after):
    expected = Counter(dependency for group in before for dependency in group)
    actual = Counter(dependency for group in after for dependency in group)
    assert expected == actual, f'missing={expected - actual}; added={actual - expected}'
    assert all(count == 1 for count in actual.values()), actual
    assert all(after), 'empty shard'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--base', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    before = subprocess.check_output(['git', 'show', f'{args.base}:build.zig'], cwd=root, text=True)
    after = (root / 'build.zig').read_text()
    assert before.split('    const test_groups =', 1)[0] == after.split('    const test_groups =', 1)[0], 'test definitions or upstream dependencies changed'
    for step, array, count in [('test_step', 'test_groups', 4), ('vps_test_step', 'vps_groups', 3)]:
        old = groups(before, step, array)
        new = groups(after, step, array)
        assert len(new) == count, array
        verify(old, new)
        for mutation in ('missing', 'duplicate'):
            broken = [list(group) for group in new]
            if mutation == 'missing':
                broken[0].pop()
            else:
                broken[1].append(broken[0][0])
            try:
                verify(old, broken)
            except AssertionError:
                print(f'{array}: {mutation} negative control rejected')
            else:
                raise AssertionError(f'{mutation} control accepted')
        print(f'{array}: {sum(map(len, old))} original test dependencies, {sum(map(len, new))} new, exactly once')
        for index, group in enumerate(new, 1):
            print(f'{array} {index} ({len(group)}): ' + ', '.join(group))
    print('SHARD COVERAGE VERIFIED')


if __name__ == '__main__':
    main()
