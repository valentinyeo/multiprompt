# Chat table build cost

The PR's `Chat table bench` check runs only on a GitHub Windows runner. It checks out the PR base and candidate, copies the candidate's benchmark test unchanged into the base render module and runs `zig build bench-chat-tables` using the candidate's build definition.

Each revision builds the same nine-cell table 2,000 times through its own production cell measurer, using real GDI fonts and width measurements. QueryPerformanceCounter brackets parsing, allocation and cell measurement, including font restoration; cache clearing and debug-log writes are outside the interval. Font metrics remain warm after the first build, as they do in normal use. Every build emits `CHAT_TABLE_BUILD index=... us=... cells=9` into that revision's debug log.

The uploaded `chat-table-bench` artifact retains source revisions, build logs, per-build debug logs and `summary.json`. The check validates the complete sequence and requires the candidate to stay below 0.35 ms per build. This is native Windows table-build cost, not Wine timing or tab-switch first-paint latency; it does not claim to reproduce the historical Wine benchmark's absolute times.
