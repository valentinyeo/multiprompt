# UI save admission

## Sub-features

- Every UI-thread save uses the existing background write queue, including empty payloads.
- Rejected admission returns failure without entering the synchronous disk writer.
- Rejected saves share the existing coalesced saving-failed notice; failed notice posting permits retry.
- Successful admission and non-UI synchronous success/failure retain their existing results.

## How to get to it (user POV)

Change a workspace or another saved preference. Saving must not stop window input. If a background save cannot be accepted, the existing saving-failed notice appears instead of silently blocking the window.

## Driving it with hosted CI

The full Tests workflow discovers `tools/ui-thread-writes.test.js`. Its native fixture compiles the exact production `writeFileAtomicW` entry, substituting only UI-thread identity, queue admission, disk writer and notification boundaries. Five Zig cases execute rejected admission, empty saves, accepted saves, background writes, notice coalescing and notification retry/shutdown. A synchronous-writer call counter must remain zero for every UI case, even if queue admission fails. The unchanged pre-fix entry must fail these assertions in the automated red-proof job.

Also dispatch `freeze-recorder.yml --ref <branch>` with no credentials or release tag. It launches the actual isolated Windows app, proves the healthy control creates no incident and forces two main-thread stalls through the existing external boundary. The real watchdog saves thread contexts and the upload worker sends them to the isolated account service. Download `freeze-evidence` and inspect its result, saved reports and screenshots. This is a watchdog compatibility check, not a queue-pressure UI reproduction.

## Gotchas

- No local suites, native tests, builds or desktop driving.
- Queue admission is a controlled boundary in the unit fixture; it does not identify a new production incident's cause.
- The full-day ticket acceptance requires positive desktop usage and watchdog evidence. No recent uploaded incidents, a short hosted journey or passing unit checks cannot establish one actual working day without freezes.
- The bounded latest-by-path queue, atomic replacement and disk flush remain unchanged. Rejection is a failure, not a successful save.
