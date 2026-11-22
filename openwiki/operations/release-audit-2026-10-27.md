# Release cleanup and merge review

## Stale draft

Draft `v0.28.780` was removed on 2026-10-27.
Release ID: `419438607`; created: 2026-10-21.
It was never published.
Its build workflows had finished.
No current source references targeted this draft.
The updater uses the latest published release.
The draft's x64 asset had two authenticated downloads.
Other draft assets had zero downloads.
Historical downloads do not establish current use.

Only the draft release was deleted.
Tag `v0.28.780` still targets `d3cff63ef9ab08444c472e9a77156f26c6aaac08`.
Published release `v0.28.952` remains unchanged.
Its asset IDs, names and sizes were preserved.
No source, installed app or tag was changed.
No new app release is needed.

## Large merge

Reviewed: [public-repository synchronization](https://github.com/valentinyeo/multiprompt/pull/2).
Merge: `af5d0db387eda70671fc44fa04867693d7db8c27`.
Comparison: merge against its first parent.

| Measure | Result |
| --- | ---: |
| Changed files | 195 |
| Added text lines | 22,182 |
| Deleted text lines | 1,190 |
| Binary files | 1 |

The reported 23,367 lines differs from this comparison.

| Area | Files | Added lines |
| --- | ---: | ---: |
| Application | 67 | 9,068 |
| Tools and regression coverage | 96 | 10,715 |
| Service | 11 | 1,928 |
| Build, extension, documentation and configuration | 21 | 471 |

The binary is a documentation hero image.
The service dependency lock adds 734 lines.
It is not a compiled artifact.

**Keep the synchronization merge.**
It contains application changes, checks and service code.
It is not a generated-code dump.
Keep the intentionally broken history-reader regression fixture.
The history-reader test loads that fixture.

One unused copied test needs separate cleanup:
`tools/chat-view-console-visibility.test.js.orig`.
It contains 250 lines, without tracked references.
Its suffix excludes it from test discovery.
[Cleanup ticket](https://app.hypertask.ai/detail/project-2060/1050).

## Verification

Authenticated release-ID and tag lookups return 404.
The preserved tag and published release remain readable.
Their recorded identities and assets match before cleanup.
The removal check rejected the live draft beforehand.
The merge audit rejects an unrelated commit.
