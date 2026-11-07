# Hosted live working dots

## Sub-features

- Real composer Enter to three painted dots within 1000 ms.
- Dots animate after the subscribed live turn starts.
- Dots remain with a visible live reply before turn end.
- Two real follow-up messages stay queued while the dots animate.

## How to get to it (user POV)

Open the saved remote tab, open Chat View, type a message and press Enter.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=chat-working-live`, optionally with a release tag. The workflow selects the existing chat-delivery driver. Inspect `working-live` evidence, particularly timestamped BMP transcript captures, `timing.json`, `actions.json`, `stand-in/working-host.jsonl`, `doctor.json`, `result.json` and `cleanup.json`. The checker requires the production message store's queued event, matching dispatch, subscription pushes, a timely screenshot, animation after the turn-start push, the copied reply, reply pixels alongside working dots, and animated dots after two real follow-up messages queue. Capture end times use a monotonic stopwatch started before SendInput; filesystem writes and image analysis are not counted as capture time.

The remote shell and provider are stand-ins. The provider stand-in runs production message dispatch in a thread, substitutes host ownership and delivery, and writes production host events through the app-supplied reader's event store. The existing Windows notification polling fallback delivers the real subscription pages. It sends a text delta but deliberately no turn-ended event, so the reply must retain dots while the turn remains active. The journey then submits two real follow-up messages, requires both queued records from the production message store, and checks that the dots still animate. No credentials or paid provider are used. The app, composer, outbox, message store, subscription, window loop and painter are real.

## Recorded hosted proof

Run https://github.com/valentinyeo/multiprompt/actions/runs/42368960296 passed on `f6fefa003`. Downloaded `verify-chat-delivery/result.json` reports `passed`; both cleanup records report zero remaining owned processes and removed scratch directories. This is the simulated-provider boundary above, not a real provider acceptance claim.

## Gotchas

This is not proof of a real provider, real SSH, provider startup or the normal external message-worker process. Timing includes the actual hosted runner and stand-in transport, not production network or provider latency. A passing portable checker test is not a hosted desktop result. Require the Windows artifact and inspect the screenshots; no pass is claimed until that run succeeds.
