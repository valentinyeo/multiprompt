# Rooms: preview send and legacy safety

## Sub-features

Create a room with two agents. Persist its selection, members and draft. Refuse sending on a legacy peer. On a scoped preview peer, send one broadcast and receive two explicitly synthetic replies without repeats after restarting.

## How to get to it (user POV)

Open Ctrl+K and choose New room. Name it, select two agents, then press Ctrl+Enter. Type a draft and press Enter. Reopen the app with the same profile.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=rooms`, no release tag, on the isolated Rooms proof branch. The shared build enables `rooms-preview`; release visibility stays unchanged. The Windows driver delegates to `tools/verify-rooms/drive.ps1`. No workflow changes or live account secret are required.

The driver builds the existing account Worker through a local-only Wrangler dry run, then runs it with Miniflare on the disposable hosted Windows machine. As in the account journey, a temporary trusted certificate and hosts entry route the app's normal account origin to that isolated Worker. The fixture generates temporary device credentials, seeds its account layout through the real API, and protects the refresh credential through Windows DPAPI. Interactive sign-in and the production account service are not covered. Cleanup restores the original hosts file, removes both certificate entries, stops the owned service process tree, and deletes the profile and credentials.

Real keyboard input opens the palette and member picker, types Product sync, creates the room, attempts a legacy send, and checks draft persistence after restart. Switching only the remote boundary to scoped synthetic replies then exercises one real native broadcast send. Independent SQLite reads require exactly one human event and two distinct member replies bound to that event. Canonical event reads require exactly two started and ended turns. Reopening the owned app must load the same selected room without adding messages or turns. No room events or drafts are inserted by the driver.

Evidence includes real desktop screenshots before sending, after both replies and after restart, action traces, synthetic room/canonical witnesses, binary identity and cleanup checks under `verify-rooms`. The Windows boundary contract test also verifies legacy refusal, broadcast fan-out, command replay and read-after-reopen idempotency. It is not desktop proof by itself.

## Gotchas

SSH, host ownership and provider stdin/output are explicit stand-ins. Production canonical message transactions and host event reducers execute in-process on Windows; there is no real remote host subprocess or paid provider call. The fixture extracts the embedded production SQLite schema and runs its actual RoomStore/RoomBridge handlers. POSIX store ownership and dispatch locks are not verified on Windows. No private-chat fallback is allowed.

This preview journey does not establish release readiness, real-provider delivery, mention targeting, uncertain delivery retry, cross-room isolation, scoped restart, Android compatibility, themes or independent design QA. Those remain separate acceptance gates. Inspect exact-source `build.json`, `result.json`, witnesses and screenshots before claiming any passed outcome. A green preview must not enable release or merge the parent Rooms implementation by itself.

No raw profile, account record, credentials, app logs or memory dumps enter public artifacts. All visible messages and identities are synthetic and must be labelled that way wherever screenshots are attached.
