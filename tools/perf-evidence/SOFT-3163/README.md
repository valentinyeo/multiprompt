# SOFT-3163: Windows desktop baseline

The goal is to measure repeated pauses and spikes in the Windows app, without changing the product or restarting the owner's app.

Windows CI reproduced tab-switch spikes and UI-thread stalls after the first chat paint. The largest confirmed repeatable problem is late whole-history layout. One rare draft-restoration stall is localized, but its internal operation remains unresolved. These controlled results do not establish every cause on the owner's installation.

No product source, version, release or PR changed. Only measurement tools, this report and a dispatch-only measurement workflow changed on this branch. **Do not merge this branch's replacement `test.yml` into master.** The ordinary release binary is uninstrumented. Separate diagnostic builds receive timing-only source injections in their disposable CI checkout.

## Before

Five fresh-profile trials on GitHub-hosted `windows-latest`. All values are milliseconds. Quantiles pool the raw observations; p95/p99 use nearest rank. Per-trial p50 ranges are included to expose variation.

| Action | Samples | p50 | p95 | p99 | Max | Trial p50 range |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Typing | 500 | 32.50 | 48.98 | 49.89 | 64.85 | 32.15 to 32.96 |
| Switching tabs | 500 | 42.46 | 60.36 | 154.99 | 267.75 | 37.79 to 43.03 |
| Opening Chat View | 100 | 42.65 | 58.51 | 59.67 | 60.94 | 41.25 to 42.91 |
| Scrolling a long chat | 500 | 43.60 | 60.06 | 61.55 | 76.23 | 31.40 to 44.56 |
| Receiving a live reply part | 500 | 60.64 | 78.38 | 83.52 | 95.60 | 57.61 to 61.09 |

The baseline has zero action failures, five exact ordered streaming receipts and zero owned processes left after each trial. Each streaming receipt contains all 110 parts exactly once: 10 warmups plus 100 measured parts. Representative final streaming and typing screenshots were inspected, not every PNG.

These are observed text/paint acknowledgement times followed by `DwmFlush`, not first-pixel presentation measurements. The no-input compositor control has n=500, p50 16.04, p95 31.52, p99 31.79 and max 47.12 ms. Do not subtract that control from individual observations. The observer can add scheduling and frame-clock delay.

## What was timed

- **Typing:** native `SendInput` until the editor returns the exact expected text through `WM_GETTEXT`, then compositor synchronization. This does not measure the first glyph pixel.
- **Switching:** native Ctrl+Tab until the requested shell logs a nonempty, clean-layout content paint, then compositor synchronization. Persisted target state is checked outside the timed interval.
- **Opening:** Alt+C opens the existing second session's Chat View from its console. A new nonempty transcript paint is required. This is not creating a new remote agent. The existing 1500 ms shortcut guard is honored outside timing, as in the existing verification journey.
- **Scrolling:** native mouse wheel input until nonzero movement and an increased transcript paint counter, then compositor synchronization.
- **Streaming:** append one incremental assistant part to the real synthetic transcript until the native reader pushes it and the transcript paint count increases, then compositor synchronization. The final copied transcript must contain every part exactly once and in order. Provider/network generation time is excluded.

There are ten saved chats. Nine have 40 generated conversation rounds with paragraphs, lists, code and tables, producing 404 rendered blocks. Another has a 400 MiB hidden-tool-output history with a short visible tail. The long scrolling and streaming cases use the second, genuinely long visible chat, not that short tail. Browser panes are closed. Ten warmups per action per trial are excluded. Each trial measures 100 of each action except opening, which measures 20.

Product source is pinned at `f64e17a9f0cf3d07067443e86c64b81269449606`, source tree `a801c635a796437fbae0d70719e6b5ca9a54d15f`. The release executable SHA256 is `638E463F4E4A3C18272272847348924CFA24D089D66C70F6381D857C50F27885`. Builds use Zig 0.16.0, ReleaseSmall, `-Dtarget=x86_64-windows-gnu -Drelease=true`. No ancestor fallback was allowed. Runtime helpers and native rendering are real; SSH/provider transport is synthetic. Updates and login are disabled only in the isolated CI profile. Verbose logging is enabled for the paint observations and differs from ordinary logging-off operation.

## Three measured blocking regions

### 1. Late whole-history layout blocks subsequent input

The matching-CPU diagnostic replay paints a complete 404-block chat, then immediately spends **95.957 ms** in `chatRelayout` on the UI thread. Before and after, the visible message, scroll position and content height remain identical. The layout counter increases from 285 to 286. The parent message is `WM_TIMER` with `wp=0x29`, which maps to `TIMER_CHAT_BROWSER_SWAP`, not the regular chat-refresh timer. This occurs with browser panes closed.

In the separate AMD EPYC 7763 replay, **59/100** measured tab inputs take more than 100 ms to return from input delivery. **All 59 overlap a UI-thread `chatRelayout` call.** Median layout overlap within those blocked input calls is **193.458 ms**. One call contains **228.7788 ms** of layout within a **268.5842 ms** input-delivery interval. The keyboard-hook body itself is not where that time is spent. The UI thread is busy before it can service input.

The second replay has different hardware and extra instrumentation. Its durations are diagnostic evidence, not baseline percentiles or a hardware comparison. Nested spans must not be added together.

Evidence: [late-layout.txt](late-layout.txt), [summary.json](summary.json), first profile `trial-1/debug.log:5705-5727`, and second profile `trial-1/samples.json`, switching index 24, with `trial-1/debug.log:1845`.

Source mapping after measurement: `src/main.zig:8379`, `src/win32.zig:363`, `src/chat_session.zig:2137`, `src/chat_render.zig:2514`.

### 2. Synchronous draft restoration contains the worst baseline spike

Baseline trial 1, switching index 45, takes **267.7548 ms**. The app's own switch trace assigns **236.124 ms** to `draft_bind`, inside **243.580 ms** of switch dispatch. Across all 500 measured switches, this stage has p50 **1.9745 ms**, p95 **2.949 ms**, p99 **32.550 ms** and max **236.124 ms**.

This localizes the outlier to `chatDraftBindToActive`, before the target chat paints. Switching precedes typing in each fresh profile, so these chats have no typed draft body to restore. The exact operation inside draft restoration was not isolated. **There is no evidence here to call it disk I/O, antivirus or a particular Win32 API.** It may overlap the same layout problem; these are not proven to be three independent bugs.

Evidence: [worst-switch.txt](worst-switch.txt), baseline `trial-1/samples.json`, index 45, and `trial-1/debug.log:1437` onward.

Source mapping: `src/console.zig:3070`, `src/chat_composer.zig:2732`.

### 3. Typing repeatedly paints the sidebar

The matching-CPU profile records **101 sidebar paints across 100 timed typing windows**. Per-call p50 is **4.823 ms**, p95 **5.243 ms**, p99 **6.635 ms**, and max **7.359 ms**. These calls run on the same UI thread as input and chat drawing. This is a smaller repeated cost, not an explanation for the entire 268 ms outlier.

Evidence: [typing-paint.txt](typing-paint.txt), first profile `trial-1/debug.log:4584-4597`, and the corresponding typing samples. The generated sidebar content is unchanged during typing.

Source mapping: `src/main.zig:1790`, `src/sidebar.zig:2488`.

## Fix order, without making a fix

1. **Don't do it. Recommended first:** avoid the second whole-history layout after the cached chat has already painted when message content and layout geometry have not changed. Keep status acquisition and genuine history/geometry invalidation. Do not delay the work with another timer.
2. **Don't repeat it:** investigate the timed draft-restoration region with nested load/flush/editor-message spans, then remove identical empty-editor restoration work if that is the measured cause. Do not guess its internal blocking operation from this trace.
3. **Do less:** limit sidebar/frame painting to changed regions rather than paying for it on each typed character.
4. **Do later:** defer only required remaining nonvisual work after measuring it. Moving the current redundant layout later would preserve the spikes.

No speedup, saved-time promise, candidate build, product patch or before/after delta is claimed.

## Benchmark checklist

| Check | Evidence and verdict |
| --- | --- |
| Limiter | Separate QPC traces identify UI-thread layout and input-delivery overlap. Baseline's worst dispatch is localized to draft binding. Its internal mechanism remains open. Compositor control is separate. |
| Production configuration | ReleaseSmall release build, pinned product source and executable hash, same generated fixture, warmed sessions, no build fallback. Logging-on and synthetic transport are disclosed. The primary profile matches baseline CPU family; the second uses EPYC 7763 and is not pooled. |
| Physical limits | All conversions use recorded QPC/Stopwatch frequency. The 236.124 ms draft region fits inside 243.580 ms dispatch and 267.7548 ms observed latency. No throughput ceiling or speedup is claimed. |
| Errors and output | Every accepted run has zero errors. Wrong target, empty paint, unchanged scroll, missing/duplicate/reordered reply parts or leaked processes fails the run. Timeouts are not latency samples. |
| Repetition | Five fresh-profile trials. Per-trial medians and ranges are in `summary.json`; all raw samples remain in the baseline artifact. There is no A/B candidate to alternate. Profiling builds are excluded from the before table. |
| User relevance | Real native input, editor, reader, cache, layout and drawing. Static ten-chat workload, no live owner data, browser panes closed. Cold launch, real network/provider work and the owner's wider setup are not represented. First-response timing alone misses some post-paint stalls; separate traces expose those. |
| Work happened | Exact typed text, requested shell paint, closed-before-open state, nonzero wheel movement plus increased paint count, real transcript appends, reader push, and all 110 rendered reply parts copied exactly once in order in each trial. Observer CPU is recorded separately; baseline observer uses 1.45 to 2.36 CPU seconds over 164 to 174 wall seconds per trial, so it is not CPU-saturated. |

The Explain the Number principle changed the investigation: a first-paint number was not treated as proof that the UI stopped blocking. Attack the Premise changed the opening setup: the 400 ms repeat assumption was rejected against the observed ignored input and the documented 1500 ms guard.

## Evidence and rerun

- [Baseline and matching-CPU profile run](https://github.com/valentinyeo/multiprompt/actions/runs/45479124542).
- [Baseline artifact: speed-baseline-45479124542](https://github.com/valentinyeo/multiprompt/actions/runs/45479124542/artifacts/14961714000).
- [Profile artifact: speed-candidate-45479124542](https://github.com/valentinyeo/multiprompt/actions/runs/45479124542/artifacts/14962250575).
- [Input/compositor split replay](https://github.com/valentinyeo/multiprompt/actions/runs/45479549214), [artifact: speed-candidate-45479549214](https://github.com/valentinyeo/multiprompt/actions/runs/45479549214/artifacts/14963915448).
- Artifacts retain raw `samples.json`, `machine.json`, `build.json`, `control.json`, `accounting.json`, `debug.log`, screenshots, streaming receipts, invocation records and teardown accounting. Retention is 14 days. This directory preserves the numeric summary and selected trace excerpts beyond artifact expiry.

Dispatch only on the measurement branch, never master:

```sh
gh workflow run test.yml --ref measure/soft-3163-windows-spikes -f samples=100 -f trials=5 -f profile=true
```

Parse downloaded artifacts without launching the app:

```sh
python3 tools/everyday-performance-report.py <baseline-directory> --profile <profile-directory>
```

## Faults and remaining gaps

This worker's board shim has no agent login. No board writes or borrowed login were used. The orchestrator must update SOFT-3163 and file/reuse the appropriate fault tickets.

- **Multiprompt board/view, board 2060, label Multiprompt:** new measurement tooling initially failed on a PowerShell CPU-property alias, startup/restore identity assumptions, asynchronous session persistence, shortcut pacing, an incorrect cumulative streaming fixture and an anonymous provenance API lookup. These were reported before correction. Failed and invalid calibrations were excluded. The bad streaming fixture was caught by screenshot review; the receipt now rejects duplicates and reordering.
- **Shared setup, board 2060, label Poteto:** deslop unavailable. No subagents or outside review were started for this measure-only task. The added code contains no comments.
- **SOFT-3163 remains investigative:** the rare draft-binding stall's inner operation and the owner's exact workload remain unproven. The measured layout stall has a concrete first fix to test in phase 2. This report is not permission to close the product issue or merge around the review cap.

No build, test suite or desktop execution ran on the shared server. All desktop execution and builds were GitHub-hosted Windows jobs. The owner's app was never contacted or restarted.
