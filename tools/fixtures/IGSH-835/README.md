# IGSH-835 queue reconciliation fixtures

`recorded-transcript.jsonl` reuses the first real user record already published in `tools/fixtures/igsh363/joined-turn.json`, preserving its timestamp and message bytes. The preceding enqueue is a synthetic queued-state setup one millisecond before that record; it intentionally has no remove/dequeue notification. No private transcript or host information is added. The test first refreshes with only that enqueue, then appends the recorded user event and refreshes the same reader process and cache. It also checks an unchanged refresh and a cold queue replay.

`identical-sends.jsonl` is synthetic: two identical sends, one matching user occurrence, an assistant answer, and a second matching user occurrence. Both occurrences share the enqueue timestamp, so position rather than timestamp uniqueness must distinguish them. One occurrence clears only one marker, including across incremental and cold replay.

`queue-replay-before.py` is the unchanged `queue_apply` and `queue_replay` source from master revision `2245664568fb5ffd35168790746c9f4596f8accf`. The GitHub workflow executes both fixture tests against this checked-in snapshot and requires assertion failures in both, then executes the fixed production reader and the complete reader regression suite. No Git-history lookup is needed to reproduce red evidence.

Additional regressions cover exact-text and timestamp boundaries, ignored assistant/sidechain/meta/compaction records, queued-command attachments, explicit removals followed by matching transcript records, and incomplete JSONL writes. Builds and tests run on GitHub only.
