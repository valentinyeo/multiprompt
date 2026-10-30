# Shared chat runtime

- Desktop and Android send the complete canonical reader.
- The outer loader selects the inner reader.
- Selection happens before requests.
- Imports never install a runtime.
- The full-file hash identifies the client artifact.
- The inner-source hash identifies the selected runtime.

## Selection

- Each Unix user has a private runtime.
- Its directory is `~/.multiprompt-runtime`.
- `active.json` contains `protocol`, `generation`, and `sha256`.
- Protocol 1 starts at generation 1.
- Every inner-source edit increments `RUNTIME_GENERATION`.
- Generations increase monotonically.
- A lock serializes selection.
- Readers use owner-only permissions.
- Each reader is stored as `<sha256>.py`.
- Publishing syncs a temporary file.
- An atomic rename publishes it.
- Older launchers select the installed newer reader.
- Equal generations with different hashes fail closed.
- Unsafe files and corrupt readers fail closed.

## Requests

- Send this `--serve` request:

```json
{"id":1,"op":"engine_info"}
```

- It returns:

```json
{"id":1,"engine_info":{"protocol":1,"generation":1,"sha256":"..."}}
```

- Live history requests must send `follow: true`.
- This resolves the live session before saved IDs.
- Existing history responses remain unchanged.
- Watch and one-shot calls use selected source.
- Owner and held-worker calls also use it.
- Runtime errors return history error frames.
- They never execute older code instead.

## Limits

- Older launchers still run their embedded reader.
- Those launchers predate this loader.
- Existing processes continue until they exit.
- Selection cannot stop those processes.
- Recovery cursors remain independent of selection.
- Immediate cutover is not promised.
- Old and new process ordering is not promised.
- Android must migrate its embedded canonical file.
- Verify both clients before closing paired work.
