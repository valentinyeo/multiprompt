"""Hosted replay of allowlisted structural metadata, not raw transcripts."""
import gzip
import json
import sys
from model import append, classify, counts, empty_snapshot
from cases import check
from ledger_replay import run as run_ledger


def main(path):
    full, incremental = empty_snapshot(), empty_snapshot()
    total = 0
    with gzip.open(path, 'rt', encoding='utf-8') as stream:
        header = json.loads(next(stream))
        if header.get('schema') != 'mp-native-structural-v1':
            raise ValueError('unexpected corpus schema')
        for line in stream:
            source, rows = json.loads(line)
            append(full, source, rows)
            midpoint = len(rows) // 2
            append(incremental, source, rows[:midpoint])
            append(incremental, source, rows[midpoint:])
            append(incremental, source, rows)
            total += len(rows)
    left, right = classify(full), classify(incremental)
    assert left == right and len(left) == total
    assert all(row['class'] and row['desktop_binding'] is None for row in left.values())
    assert total == 498394 and len(full['sources']) == 4294
    case_oracles = check(full, left)
    print(json.dumps({'ledger_baseline': run_ledger()}, sort_keys=True))
    print(json.dumps({'input_occurrences': total, 'sources_with_selected_events': len(full['sources']),
                      'classification': counts(left), 'desktop_bindings_proven': 0,
                      'full_incremental_and_reread_equal': True, 'case_oracles': case_oracles,
                      'scope': header['scope']}, sort_keys=True))


if __name__ == '__main__':
    main(sys.argv[1])
