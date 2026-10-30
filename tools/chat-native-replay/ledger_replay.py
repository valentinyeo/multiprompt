"""Hosted-only structural ledger baseline; no live DB or transcript access."""
import json
from collections import Counter
from pathlib import Path
from ledger import classify, resolve


def run():
    fixture = json.loads((Path(__file__).parent / 'ledger-fixture.json').read_text())
    assert fixture['schema'] == 'mp-held-claims-structural-v1'
    rows = fixture['rows']
    facts = classify(rows)
    requests = [{k: row[k] for k in ('db', 'message', 'session', 'source')} for row in rows]
    resolved = resolve(facts, requests)
    totals = Counter(row['classification'] for row in facts)
    assert len(rows) == len(facts) == len(resolved) == 28 and fixture['ledger_count'] == 8
    assert totals == {'legacy_verified_receipt': 11, 'queued': 7, 'submitted': 8, 'unconfirmed': 2}
    assert sum(row['desktop_id'] for row in rows) == 23
    assert sum(bool(fact.get('native_pair')) for fact in facts) == 2
    assert sum(row['in_latest20_snapshot'] is False for row, fact in zip(rows, facts)
               if fact['classification'] == 'legacy_verified_receipt') == 0
    assert resolved == facts
    return {'ledger_count': fixture['ledger_count'], 'rows': len(rows),
            'desktop_rows': 23, 'classification': dict(sorted(totals.items())),
            'native_pairs_enriching_legacy_claims': 2,
            'legacy_claims_outside_latest20_in_snapshot': 0,
            'independent_desktop_native_id_proofs': 0,
            'scope': fixture['scope']}


if __name__ == '__main__':
    print(json.dumps(run(), sort_keys=True))
