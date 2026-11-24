---
type: Architecture
title: Chats reach a server through the cloud
description: The outbound relay that carries the reader protocol when a server is not reached over SSH.
tags:
  - architecture
  - chat
  - sync
updated: 2026-11-24
---

# Chats reach a server through the cloud (MUBO-165)

Today the desktop reaches a server one way: an SSH process running
`python3 <reader> --serve`, with newline-delimited JSON on its stdin and stdout. The
server list holds three slots with host, user, port and key, and the app renders the SSH
config for them. A new user still needs a reachable SSH port, a key, and the reader
installed on that machine.

This page plans the second path: a server helper dials out to the Multibot cloud, the
desktop connects to the same cloud, and the two carry the frames SSH carries today.
The account service now holds the room and the route that reaches it; the desktop, the
helper and the servable deployment are still to come, so nothing switches transport yet.

## The frames do not change

The relay moves bytes. It does not read them.

- A request and its reply stay one JSON object per line, protocol 1, exactly as
  `--serve` speaks today. The channel id in each frame already multiplexes several
  requests over one connection (`chat_transport.py`).
- History, live events, send, receipts, approvals and the host socket calls all keep
  their current request and reply shapes. No client, reader or store field changes.
- A relay that cannot carry these frames must refuse the server instead of translating
  it, so no client ever sees a half-supported chat.

## Shape

- One live room per account, held by the account service
  (`https://account.multiprompt.dev`). The room is a Cloudflare Durable Object; the
  Worker in `service/` gains the upgrade route that hands a connection to it.
- The server helper opens one outbound WebSocket to the room and keeps it open. It
  registers its host slot, 0 through 2, which the server already carries as
  `MULTIPROMPT_HOST`. No inbound port, no port forwarding, no public hostname.
- The desktop opens a WebSocket to the same room and asks for one host slot. Frames for
  that slot go over that socket. Other slots stay separate, as they do over SSH today.
- Server to cloud is outbound only. A server behind NAT works, and a server that stops
  its helper is simply absent, which is what the sidebar already shows.

## The room the account service runs

The room is `RelayRoom`, a Durable Object in the account Worker, declared in
`service/wrangler.jsonc` as the `RELAY_ROOMS` binding. The Worker picks one object per
account, `idFromName(account)`, so one account never sees another's slots.

- `GET /v1/relay?slot=N` with `Upgrade: websocket` joins that slot. The same path without
  the upgrade header answers presence.
- A device Bearer token joins as a desktop. An `mpk_a_` admin service key joins as a
  server helper, which is the key a server already carries in `MULTIPROMPT_KEY`. A
  workspace key and a browser session are refused with `403 key_scope`, because a room
  belongs to the whole account, never to one workspace.
- The slot comes from the query string and must be 0, 1 or 2, matching the host slots the
  layout already carries. Any other value is `400 invalid_relay_slot`, and a desktop that
  omits it is refused the same way.
- One helper holds a slot. A helper that connects again replaces the old one, which is
  closed with code 4000, so a reconnecting server never fights the room for its slot.
- Every message the client sends is forwarded to the other side unchanged, text or binary.
  The room reads no field, keeps no frame and replays nothing; a frame with no peer is
  dropped, and the sender learns that from the same retry the message worker already runs.
- A desktop frame larger than 16 MiB, or a ninth desktop on one slot, ends that connection:
  `1009 frame_too_large` and `429 relay_busy`. A room never buffers to cover either.
- Presence answers `{ "slots": [{ "slot": 0, "server": false, "desktops": 0 }] }`, which
  is how the Settings switch learns that a slot has no helper and must name SSH as the way
  back instead of dialling out.
- Auth is checked once, on the upgrade, as the plan says: revoking a device closes its next
  connection rather than an open one.

## Auth

- The desktop presents the device Bearer token it already holds for layout sync.
- The server helper presents the account key it already uses for
  `MULTIPROMPT_KEY`; the same key the account service checks today.
- The room accepts a device token or an account key for that account, and nothing else.
  Revoking a device in the account dashboard closes its room sockets on the next
  upgrade, with no new revocation path.
- No new secret, no new key type and no new sign-in screen.

## The room is a pipe, not a store

- The room forwards frames and keeps no message text. D1 already holds layout metadata
  in plaintext; chat text does not join it.
- The server store stays the source of truth. `shared_messages`, `message_attempts` and
  the host's own state do not move.
- A room that restarts loses only connections, never a message, because it never held
  one. Reconnect is the same retry the message worker already runs.

## The switch

- Settings gains one row per server slot: `SSH` or `Cloud`. Existing slots stay `SSH`,
  so an upgrade changes nothing until the user asks.
- Flipping to `Cloud` closes the SSH channel for that slot and dials the room. Flipping
  back reopens SSH. The undo is the flip, and it needs no restart.
- A slot set to `Cloud` on a server whose helper has no relay reports the server as not
  reachable, with SSH named as the way back. It never falls back on its own.
- The switch is user-facing, so it ships on all three surfaces: a Ctrl+K row, a
  shortcut row in `src/shortcuts.zig` and
  [keyboard shortcuts](../operations/keyboard-shortcuts.md), and the existing
  `mb settings` verb. No new verb is needed.

## Compatibility

- An older desktop keeps using SSH: it never sends the cloud upgrade request, and the
  room ignores a slot it was not asked for.
- A server with an older reader answers the relay probe with no capability, so the
  switch stays unavailable there. Older and newer clients still exchange the same
  protocol 1 frames.
- The account layout, tab identity and session names are untouched, so Android's
  current build keeps working and needs no change to read a relayed chat.
  Android gaining the cloud path is its own paired ticket.

## Failure and its evidence

- Socket lost: the desktop retries with the existing per-chat backoff and shows the
  server offline meanwhile. It never resends text that may have landed.
- Room rejects a server: the slot shows the service's own reason, once, and no chat
  opens on it.
- A relayed chat draws the same delivery states as an SSH one, because the frames and
  receipts are the same. There is no cloud-only status element.

## Paired Android ticket

CLAUDE.md requires one paired Android ticket before shared chat or sync work starts, linked
both ways. This change is a plan only, so that ticket is not filed yet: the worker that wrote
this page has no board login. File it on board 2060 with the Multiprompt Android label before
slice 1, then link both directions:

- Title: Multibot Android: keep reading a chat the desktop reaches through the cloud
- Body: the desktop adds a cloud path for the same protocol 1 frames. Android's current build
  keeps working, because the account layout, tab identity and frames do not change. Android
  gains the cloud path after slice 3, and must be checked on a real phone against a relayed
  desktop before this work is Done.
- Old and new client compatibility: an old Android build reads a relayed chat through the
  existing layout and reader path with no change, and a new build must not require a server
  change beyond the relay it already advertises.

## Build slices

1. Relay on the server: a helper mode that dials out and bridges to the reader, proven
   against a room running locally.
2. Room in the account service: the upgrade route, the Durable Object, slot routing and
   the device-key check, with its own service tests. Landed as code; not deployed.
3. Desktop: the `Cloud` transport beside the SSH channel, then the Settings switch and
   its three surfaces.
4. Self-host: another hub origin in Settings, so a user can point a server at their own
   Cloudflare deployment. Not this ticket.

Slices 1 to 3 are the ticket's Done: a desktop chat over the cloud, and SSH again when
switched back.

## Not this ticket

- The rename to Multibot, which lands first.
- Phone changes, covered by the paired Android ticket.
- Moving the message store, the host or the agent onto the cloud.
- Any deletion or migration of existing SSH slots.
