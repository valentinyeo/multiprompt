# Fresh skill suggestions

## Sub-features

New skills appear when slash suggestions reopen. Cached results remain usable during the background request. The selected skill remains selected after results reorder. Sending reload-plugins refreshes without reopening suggestions.

## How to get to it (user POV)

Open Chat View in a remote Claude session. Type a slash and a skill prefix. Tab accepts the selected skill.

## Driving it with control.ps1

Dispatch verify.yml with feature=chat-skills and this branch, or a published release tag. The existing isolated desktop driver owns its app, profile and fake SSH transport. The transport calls the real mp_complete.py discovery over real SKILL.md files; no provider runs. A prepared built-in cache avoids provider initialization, without replacing skill discovery.

Warm suggestions with verify-zebra. Clear the composer, add verify-alpha on the test host, reopen suggestions and require a refreshed response within five seconds. Tab must still insert verify-zebra after alphabetical reordering. Filter and accept verify-alpha within the same five-second budget. Add verify-beta, send reload-plugins, and require a new discovery response before reopening suggestions.

Require CHAT_SKILLS_PROOF_OK, result.json passed, executable Doctor identity, screenshots, completion request records and zero remaining owned processes. The old app must fail the same journey at newly-added skill discovery, not setup.

## Gotchas

This is a GitHub Windows-only journey. Never run on the user's desktop. The test seeds a saved remote tab like chat-delivery; it proves the real composer and discovery, not SSH networking or a real agent. Skill selection is checked by the text Tab inserts, not merely a fetch log.
