"""Evidence-specific oracles for the full structural corpus."""
import json
from pathlib import Path


def check(snapshot, result):
    cases = json.loads((Path(__file__).parent / 'cases.json').read_text())['cases']
    def rows(case):
        return [snapshot['sources'][ref['source']][ref['position']] for ref in cases[case]]
    def fact(case, index):
        ref = cases[case][index]
        return result[ref['source'], ref['position']]
    for name in ('A', 'B'):
        indices = [(1, 2)] if name == 'A' else [(2, 3), (5, 6)]
        for remove, receipt in indices:
            a, b = rows(name)[remove], rows(name)[receipt]
            assert (a['ids']['commandUuid'], a['ids']['deliveryId']) == (b['ids']['attachment.source_uuid'], b['ids']['attachment.delivery_id'])
            assert fact(name, remove).get('native_alias') == fact(name, receipt)['occurrence']
            assert fact(name, receipt)['class'] == 'native_acceptance'
        assert cases[name][indices[0][1]]['case_timestamp_rank'] < cases[name][indices[0][0] - 1]['case_timestamp_rank']
    assert rows('B')[3]['ids']['attachment.delivery_id'] != rows('B')[6]['ids']['attachment.delivery_id']
    assert rows('B')[1]['eq'] == rows('B')[4]['eq']
    assert [r['kind'] for r in rows('D')] == ['enqueue', 'dequeue', 'user']
    assert fact('D', 1)['class'] == 'queue_fact' and 'native_alias' not in fact('D', 1)
    main, side = rows('E_main')[0], rows('E_side')[0]
    assert (main['ids']['commandUuid'], main['ids']['deliveryId']) == (side['ids']['attachment.source_uuid'], side['ids']['attachment.delivery_id'])
    assert cases['E_main'][0]['source'] != cases['E_side'][0]['source']
    assert fact('E_side', 0)['class'] == 'excluded'
    assert 'native_alias' not in fact('E_main', 0)
    assert [r['kind'] for r in rows('F')] == ['enqueue', 'popAll', 'popAll']
    assert all(fact('F', i)['class'] == 'queue_fact' for i in range(3))
    assert rows('G')[0]['eq'] == rows('G')[1]['eq']
    assert rows('G')[0]['whitespace']['trailing_ascii_spaces'] == 1
    assert fact('H', 1)['class'] == fact('H', 3)['class'] == 'excluded'
    return sorted(cases)
