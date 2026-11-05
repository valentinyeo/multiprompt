# Shared workspace colours

## Existing implementation

The account Worker advertises `workspace_color`. Desktop and Android preserve named workspace colour indices during layout writes, rebases and cache refreshes. Legacy writers cannot erase stored colours. Worker and native layout regressions run through the full hosted Tests workflow.

## Paired native journey

Dispatch the existing `account-journey.yml` workflow on the proof branch with `pictures_isolated=true`. Its existing Windows desktop and Android emulator jobs share an ephemeral actual Worker/D1 fixture through a free HTTPS tunnel. No workflow changes or production account writes are required.

The phone opens Session list actions → Settings and touches the Work workspace’s Lilac swatch (index 4). The driver requires its real selected-ring pixels and independently reads index 4 from the account layout before signalling readiness.

Desktop selects the synced session through Ctrl+K. It requires index 4 in both the account response and app-owned saved workspace state, then captures `desktop-colour-from-phone.png`. The real Ctrl+K Workspace color → Mint action selects index 6. The driver requires index 6 in both account and saved state and captures `desktop-colour-to-phone.png`.

After the existing picture propagation check, Android reopens settings and requires the Mint selected-ring pixels. Its final `root.png` shows the phone’s resulting settings. Both receipts contain complementary `workspace_colors` records. The receipt checker rejects missing, mismatched or one-sided colour evidence for an isolated run. Existing picture and process-cleanup requirements remain mandatory.

Download `session-picture-desktop-<attempt>`, `session-picture-phone-<attempt>` and both cleanup receipts. Inspect screenshots, source provenance and both JSON receipts before claiming success. Keep desktop and Android screenshots separate.

## Boundaries

These are actual app UI actions, not direct writes of chosen colours. The account layout, device credentials and remote sessions are synthetic. Sign-in and remote agents are not tested. The shared HTTPS origin is substituted in both builds, so this does not establish release-byte equivalence or production-device delivery. The extra colour actions run only against the isolated tunnel origin, never the live account proof.
