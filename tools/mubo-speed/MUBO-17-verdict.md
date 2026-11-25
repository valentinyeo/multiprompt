# MUBO-17: idle footprint with three live chats open

Ticket: https://app.hypertask.ai/detail/project-13734/17
Claim tested: with live chats open and nothing for the user to do, Multi Bot writes
under 1 MB/hour to its debug log and burns less CPU than before.

**Verdict: FAIL.** The quiet half passes on log (0.695 -> 0.231 MB/hour) with no CPU
difference. The half Valentin hit, a reply streaming into live chats, writes 2.9-3.1
MB/hour on both builds and burns more CPU after (4.5% -> 8.1% of one core, higher in
4 of 5 rounds).

## Runs

- Full run, 3 quiet rounds and 5 streaming rounds, 600 s a side, alternating order:
  https://github.com/valentinyeo/multiprompt/actions/runs/45539704572
- Harness branch: `proof/mubo-idle-stream`, not on master.
- The verdict job in that run downloaded all eight round artifacts but merged them
  into one folder, where identically named round folders collide, so it scored an
  empty evidence set. The table above is the same script run over the downloaded
  artifacts. The merge is now off; the report job lists the files it found.

## Table

Quiet: three live chats restored, nothing new arriving.

| release | windows | median MB/hour | MB/hour range | median CPU % of one core | CPU % range |
| --- | --- | --- | --- | --- | --- |
| v0.28.1683 | 3 | 0.695 | 0.694-0.697 | 0.250 | 0.219-0.297 |
| v0.28.1953 | 3 | 0.231 | 0.231-0.233 | 0.250 | 0.232-0.286 |

Streaming: three live chats, a reply kept arriving in all three for the window.

| release | windows | median MB/hour | MB/hour range | median CPU % of one core | CPU % range | transcript fetches per window | view scroll growth |
| --- | --- | --- | --- | --- | --- | --- | --- |
| v0.28.1683 | 5 | 2.929 | 1.613-3.293 | 4.507 | 2.083-7.688 | 563 | 296248 |
| v0.28.1953 | 5 | 3.145 | 2.217-3.394 | 8.099 | 3.577-8.914 | 732 | 296176 |

## What writes, per 600 s window

Quiet: old build 1008 lines (`[focus-trace]` 355, `[altq]` 355, per-paint 242), new
build 238 lines, all `[chat]`. The focus-repair loop that ran twice a second stopped.

Streaming: old build 6055 lines (2297 `[chat]`, 2252 `PERF[chat]:`, 356 `[focus-trace]`,
356 `[altq]`, 726 per-paint). New build 3760 lines (2643 `[chat]`, 1061 `PERF[chat]:`).
The log limiter cut 1200 per-paint lines, but the fetch lines grew because the new
build fetches the transcript more often.

## The harness bug this fixed

The earlier proof branch (`proof/mubo-live-idle`, run 45521373965) seeded three chats
whose transcript never resolved: the app logged `session transcript not found`, showed
"Chat not available for this session", and fetched nothing but failures. Its windows
had no chat content, so its log and CPU numbers describe an empty chat view.

Two things are needed for a live chat to render under the Windows fake host: the tab
carries `csid`, and the agent-host config is present so the reader resolves the
transcript by session id instead of `/proc`, which the Windows runner does not have.

## What this does not cover

- A stale held message, the other half of PR 953. The laptop sample had 4800 of 5764
  requests from two such shells; this harness makes none.
- A reply that stops. The streaming window keeps a reply arriving for 600 s, which is
  longer than a real answer, so its MB/hour is a ceiling for continuous streaming.
