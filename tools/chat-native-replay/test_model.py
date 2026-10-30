import unittest
from model import append, classify, empty_snapshot


def event(position, kind, **fields):
    return dict(position=position, kind=kind, **fields)


class NativeFacts(unittest.TestCase):
    def test_id_pair_is_source_scoped_and_not_desktop_binding(self):
        remove = event(0, 'remove', ids={'commandUuid': 'c', 'deliveryId': 'd'})
        attachment = event(1, 'attachment', ids={'attachment.source_uuid': 'c', 'attachment.delivery_id': 'd'}, eligible=True)
        snap = empty_snapshot()
        append(snap, 'main', [remove, attachment])
        append(snap, 'side', [event(0, 'attachment', ids=attachment['ids'], flags={'isSidechain': True}, eligible=True)])
        result = classify(snap)
        self.assertEqual(result['main', 0]['native_alias'], ('main', 1))
        self.assertEqual(result['main', 1]['class'], 'native_acceptance')
        self.assertEqual(result['side', 0]['class'], 'excluded')
        self.assertTrue(all(r['desktop_binding'] is None for r in result.values()))

    def test_no_receipt_from_queue_operations_or_equal_body(self):
        rows = [event(0, 'enqueue', body_class='same'), event(1, 'dequeue'),
                event(2, 'popAll'), event(3, 'user', body_class='same', eligible=True)]
        snap = empty_snapshot(); append(snap, 's', rows)
        result = classify(snap)
        self.assertEqual([result['s', i]['class'] for i in range(4)], ['queue_fact'] * 3 + ['native_acceptance'])
        self.assertNotIn('native_alias', result['s', 0])

    def test_duplicates_and_flags_are_not_proof(self):
        ids = {'attachment.source_uuid': 'c', 'attachment.delivery_id': 'd'}
        rows = [event(0, 'remove', ids={'commandUuid': 'c', 'deliveryId': 'd'}),
                event(1, 'attachment', ids=ids, eligible=True), event(2, 'attachment', ids=ids, eligible=True),
                event(3, 'user', flags={'isMeta': True}, eligible=True),
                event(4, 'user'), event(5, 'user', incomplete=True)]
        snap = empty_snapshot(); append(snap, 's', rows)
        result = classify(snap)
        self.assertTrue(result['s', 0]['alias_ambiguous'])
        self.assertNotIn('native_alias', result['s', 0])
        self.assertEqual([result['s', i]['class'] for i in (3, 4, 5)], ['excluded', 'ambiguous', 'incomplete'])

    def test_incremental_reread_and_source_replacement(self):
        rows = [event(0, 'enqueue'), event(1, 'remove')]
        snap = empty_snapshot(); append(snap, 's', rows[:1]); append(snap, 's', rows[1:]); append(snap, 's', rows)
        other = empty_snapshot(); append(other, 's', rows)
        self.assertEqual(classify(snap), classify(other))
        with self.assertRaises(ValueError): append(snap, 's', [event(0, 'user')])
        with self.assertRaises(ValueError): append(snap, 's', [event(3, 'user')])


if __name__ == '__main__':
    unittest.main()
