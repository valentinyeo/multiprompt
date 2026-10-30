# Native structural replay

Investigation only. This model does not change the reader, send path, desktop outbox, Android, or durable ledger. Queue operations are facts, not delivery receipts. An eligible native occurrence is evidence of a persisted CLI record, not a desktop delivery or backend inference. No desktop binding is inferred. Timeouts cannot authorize retry or prove nondelivery.

`structural.jsonl.gz` contains all 498,394 selected events from the bounded private metadata extraction, grouped by anonymous source. The original scan covered 4,301 files; 4,294 had selected events. Selection covered queue operations, queued-command attachments and user records, not full JSONL. The original scan found one malformed candidate and skipped other types before parsing. Historical completeness is unknown. The corpus cannot classify records the extractor did not capture.

The header describes unavailable fields. Positions count selected occurrences within each source; `gap_before` marks nonadjacent original lines, not a byte offset. IDs are corpus-wide opaque equality labels; exact/normalized body classes are source-local diagnostic labels only. No body is present. Flag values and absent fields remain distinct, but the extractor did not retain invalid ID values or their original field presence. Whitespace counts are structural. General timestamps were discarded by the extractor; only selected case-local timestamp ranks are available. Eligibility is unknown except for selected occurrences where private analysis recorded body categories. Missing eligibility is ambiguous, not accepted. Session fields remain separate. Cross-file offsets are not comparable.

`cases.json` points into complete extracted source sequences, not sparse neighborhoods seeded with an empty queue. A, B, D, E, F, G and H are real-derived structural oracles; `test_model.py` adds synthetic controls. E retains the main/sidechain distinction. No actual desktop held/outbox bindings were captured. Synthetic fixture labels and case-local ranks must not be interpreted as provider or desktop IDs.

On GitHub-hosted CI only:

```sh
python3 -m unittest discover -s tools/chat-native-replay -p 'test_*.py' -v
python3 tools/chat-native-replay/replay.py tools/chat-native-replay/structural.jsonl.gz
```

The hosted job is independent and report-only. Root must inspect the allowlisted export before pushing. It reports classification counts and checks complete classification, same-source unique ID-pair aliases, full/incremental equality, idempotent reread and the named cases. It does not replay raw logs, prove actual application behavior, settle submitted rows, or repair Reset.
