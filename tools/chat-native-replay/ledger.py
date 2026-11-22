"""Classify stored app claims; never write a ledger or infer transport IDs."""
from collections import Counter

REQUIRED_CHECKS = (
    'claim_matches_message_binding', 'offset_at_or_after_origin',
    'unique_sid_inode_file', 'nonnegative_in_range_offset', 'line_boundary',
    'complete_line', 'digest_matches', 'json_object', 'record_sessionId_matches',
    'accepted_record_kind', 'eligibility_flags_clear', 'file_stable_during_read',
)
EXCLUDED_FLAGS = ('isSidechain', 'isMeta', 'isCompactSummary', 'isVisibleInTranscriptOnly')
LEGACY = 'existing_app_legacy_content_correlated_claim'


def classify(rows):
    """Return one result per ledger row, preserving uncertain source states."""
    keys = Counter((r['db'], r['message']) for r in rows)
    occurrences = Counter((c.get('source'), c.get('offset_rank'))
                          for r in rows for c in r.get('claims', []))
    claim_ids = Counter((r['db'], c.get('id')) for r in rows for c in r.get('claims', []))
    result = []
    for row in rows:
        entry = {'db': row['db'], 'message': row['message'], 'session': row['session'],
                 'source': row['source'], 'source_state': row['state'],
                 'classification': 'unconfirmed'}
        if keys[row['db'], row['message']] != 1:
            entry['reason'] = 'duplicate_message'
        elif row['state'] in ('queued', 'submitted', 'cancelled'):
            entry['classification'] = row['state']
        elif row['state'] != 'delivered':
            entry['reason'] = 'unknown_state'
        elif len(row.get('claims', [])) != 1:
            entry['reason'] = 'missing_or_multiple_claims'
        else:
            claim = row['claims'][0]
            occurrence = (claim.get('source'), claim.get('offset_rank'))
            valid_kind = claim.get('record_type') == 'user' or (
                claim.get('record_type') == 'attachment' and claim.get('attachment_type') == 'queued_command')
            valid_bounds = (type(row.get('origin_rank')) is int and type(claim.get('offset_rank')) is int
                            and type(claim.get('end_rank')) is int and
                            0 <= row['origin_rank'] <= claim['offset_rank'] < claim['end_rank'])
            valid = (row.get('source_compatibility') == 'compatible' and
                     claim.get('message') == row['message'] and
                     claim.get('session') == row['session'] == claim.get('record_session') and
                     claim.get('source') == row['source'] and valid_bounds and valid_kind and
                     claim.get('binding_basis') == LEGACY and
                     claim.get('independent_desktop_native_id_proof') is False and
                     not any(claim.get('flags', {}).get(k) for k in EXCLUDED_FLAGS) and
                     all(claim.get('checks', {}).get(k) is True for k in REQUIRED_CHECKS) and
                     occurrences[occurrence] == 1 and claim_ids[row['db'], claim.get('id')] == 1 and
                     claim.get('id') is not None)
            if valid:
                entry.update(classification='legacy_verified_receipt', occurrence=occurrence,
                             binding_basis=LEGACY, body_eligibility=claim.get('body_eligibility'),
                             independent_desktop_native_id_proof=False,
                             native_pair=claim.get('native_pair', {}))
            else:
                entry['reason'] = 'unverifiable_or_ambiguous_claim'
        result.append(entry)
    return result


def resolve(classifications, requests):
    """Resolve explicitly bound IDs, including beyond any visible/history window."""
    index = {(r['db'], r['message'], r['session'], r['source']): r for r in classifications}
    return [index.get((q['db'], q['message'], q['session'], q['source']),
                      {'classification': 'unconfirmed', 'reason': 'identity_not_found'})
            for q in requests]
