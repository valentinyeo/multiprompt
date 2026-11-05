# Rooms: legacy-peer safety

## Sub-features

Create a room with two agents. Persist its selected room, members and draft. Refuse live sending when the peer lacks scoped replies.

## How to get to it (user POV)

Open Ctrl+K and choose New room. Name it, select two agents, then press Ctrl+Enter. Type a draft and press Enter. Reopen the app with the same profile.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=rooms`, no release tag, on the Rooms branch. The shared build enables `rooms-preview`; release visibility stays unchanged. The Windows driver delegates to `tools/verify-rooms/drive.ps1`.

The encrypted `IGSH_1313_ROOMS_PROOF` secret supplies a disposable live account's desktop refresh credential. Its layout needs the Work workspace, two remote sessions named Alpha and Beta, and a synthetic host at slot zero. The driver seeds those saved tabs once, with synthetic Claude identities, and protects the credential through Windows DPAPI. Interactive sign-in is not covered.

Real keyboard input opens the palette and member picker, creates Product sync, types a draft and attempts sending. Independent SQLite reads witness the production embedded RoomStore/RoomBridge results. The driver waits for the app's persisted selection and matching draft before stopping its owned process job. It relaunches that same profile and checks the native composer text. Evidence includes screenshots, synthetic room witnesses, binary identity checks and cleanup results under `verify-rooms`.

## Gotchas

SSH, tmux and provider availability use an explicit stand-in. The fixture extracts the embedded production SQLite schema and runs its real command handlers. It bypasses the POSIX ownership constructor on Windows; it does not verify remote filesystem security. The peer reports legacy store-only capability. No private-chat fallback is allowed.

This journey does not prove live replies, retry delivery, cross-room isolation, scoped restart, Android compatibility, themes or independent design QA. Those remain release gates. A green run is only legacy-peer desktop proof. Inspect screenshots and `result.json` before claiming that gate passed.

No raw profile, account record, credentials or app logs enter public artifacts. Only the owned process job and scratch profile are removed. The disposable account and temporary Actions secret require separate guarded cleanup after proof.
