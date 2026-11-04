# Positive watchdog coverage

## Sub-features

- The existing watchdog records sampled awake and responsive time, unknown observation time and cumulative freeze counts.
- Its first minute and then hourly receipts use the existing private authenticated report upload, not a new endpoint.
- Only numeric diagnostic counters, version and process/session identity are sent. No chat contents, paths or host names.
- The day verifier requires eight responsive hours in one explicitly selected desktop session, no observation gaps or freezes, fresh evidence and no subsequent crash/freeze report.

## How to get to it (user POV)

Use the normal in-app update and keep working. No extra button or restart is requested. The watchdog reports healthy coverage automatically, so a stopped or unmonitored app cannot masquerade as a freeze-free day.

## Driving it with hosted CI

Dispatch `gh workflow run freeze-recorder.yml --ref <branch>` without credentials or tag. The actual isolated Windows watchdog must produce its first numeric receipt after a real minute, and the real uploader must send it to the existing isolated account service. The journey stores `watchdog-health.json`; the independent oracle checks it. Existing healthy-no-incident, forced heartbeat/paint stalls, once-only upload, restart, privacy and cleanup assertions remain active.

Full Tests discovers `tools/freeze-recorder-upload.test.js`, `tools/freeze-recorder-proof.test.mjs` and `tools/watchdog-day-proof.test.js`. Native tests execute the real worker/tracker and validate payload privacy, observed-time accounting, sleeping/missing observations, cumulative freezes, hourly bounds and restart identity. Accelerated model time verifies accounting only.

After release, read the actual selected device through `service/crash-reports.py --device <actual-device-id> --limit 1000 --json` with the existing cached account credentials. Keep the raw output private. Run `python3 tools/watchdog-day-proof.py <private-reports.json> --device <actual-device-id>`. Exit 2 with `observing` means the gate is not met; exit 0 requires positive fresh eight-hour coverage. The output has no device identifier or private source rows. Re-read after ordinary usage; never substitute a hosted fixture device or shorten eight hours.

## Gotchas

- Incident absence, background account last-seen, machine wall-clock uptime and a short hosted run are not healthy UI coverage.
- Machine sleep is excluded by unbiased interrupt time. Observer delays over two seconds are unknown, not healthy. Sessions with unknown coverage fail the day gate conservatively.
- Restarts and separate devices cannot be summed. Later freezes/crashes invalidate a prior receipt; cumulative counters may not decrease.
- Freshness is ninety minutes because receipts are hourly. A stale or future receipt cannot pass.
- The tracker proves the app's actual awake runtime, not what the person typed. No activity content is collected.
- No local builds, test suites or desktop driving. Never restart or replace the user's running app.
