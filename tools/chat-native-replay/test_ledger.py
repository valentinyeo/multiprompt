import copy
import json
import unittest
from collections import Counter
from pathlib import Path
from ledger import classify, resolve
from ledger_replay import run


def fixture():
    return json.loads((Path(__file__).parent / 'ledger-fixture.json').read_text())['rows']


def verified_row():
    return copy.deepcopy(next(row for row in fixture() if row['claims']))


def request(row):
    return {k: row[k] for k in ('db', 'message', 'session', 'source')}


class LedgerFacts(unittest.TestCase):
    def test_real_derived_snapshot(self):
        report = run()
        self.assertEqual(report['classification'], {'legacy_verified_receipt': 11, 'queued': 7,
                                                    'submitted': 8, 'unconfirmed': 2})
        self.assertEqual(report['independent_desktop_native_id_proofs'], 0)
        self.assertEqual(report['legacy_claims_outside_latest20_in_snapshot'], 0)

    def test_wrong_binding_or_unverifiable_evidence_is_never_delivered(self):
        mutations = [
            lambda r: r['claims'][0].update(session='wrong'),
            lambda r: r['claims'][0].update(source='wrong-inode'),
            lambda r: r['claims'][0]['checks'].update(digest_matches=False),
            lambda r: r['claims'][0]['checks'].update(complete_line=False),
            lambda r: r['claims'][0]['checks'].update(file_stable_during_read=False),
            lambda r: r.update(source_compatibility='changed'),
            lambda r: r['claims'][0].update(message='wrong'),
            lambda r: r['claims'][0].update(record_session='wrong'),
            lambda r: r['claims'][0].update(offset_rank=r['origin_rank'] - 1),
            lambda r: r['claims'][0]['flags'].update(isMeta=True),
            lambda r: r['claims'][0]['checks'].pop('line_boundary'),
            lambda r: r.update(claims=[]),
        ]
        for change in mutations:
            with self.subTest(change=change):
                row = verified_row(); change(row)
                self.assertEqual(classify([row])[0]['classification'], 'unconfirmed')

    def test_duplicates_cannot_claim_an_occurrence_twice(self):
        first = verified_row(); second = copy.deepcopy(first)
        second['message'] = second['claims'][0]['message'] = 'other'
        second['claims'][0]['id'] = 'other-claim'
        self.assertEqual([r['classification'] for r in classify([first, second])], ['unconfirmed'] * 2)
        duplicated = verified_row(); duplicated['claims'].append(copy.deepcopy(duplicated['claims'][0]))
        self.assertEqual(classify([duplicated])[0]['classification'], 'unconfirmed')
        self.assertEqual([r['classification'] for r in classify([first, first])], ['unconfirmed'] * 2)

    def test_pending_states_are_not_retried_or_promoted(self):
        for state in ('queued', 'submitted'):
            row = verified_row(); row['state'] = state
            result = classify([row])[0]
            self.assertEqual(result['classification'], state)
            self.assertNotIn('occurrence', result)
            self.assertNotIn('retry', result)

    def test_request_binding_and_more_than_twenty_without_rendered_text(self):
        template = verified_row(); rows = []
        for i in range(25):
            row = copy.deepcopy(template)
            row['message'] = row['claims'][0]['message'] = 'synthetic-message-' + str(i)
            row['claims'][0]['id'] = 'synthetic-claim-' + str(i)
            row['claims'][0]['offset_rank'] = row['origin_rank'] + i * 2 + 1
            row['claims'][0]['end_rank'] = row['origin_rank'] + i * 2 + 2
            row['in_latest20_snapshot'] = False
            rows.append(row)
        facts = classify(rows)
        self.assertEqual(Counter(f['classification'] for f in facts), {'legacy_verified_receipt': 25})
        requests = [request(row) for row in rows]
        self.assertEqual(resolve(facts, requests), facts)
        for field in ('message', 'db', 'session', 'source'):
            wrong = request(rows[0]); wrong[field] = 'not-the-bound-identity'
            self.assertEqual(resolve(facts, [wrong])[0]['classification'], 'unconfirmed')


if __name__ == '__main__':
    unittest.main()
