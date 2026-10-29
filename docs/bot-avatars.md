# Bot identity

Desktop and Android use the raw tmux session name, not the editable title, provider or host ID. Hash its exact UTF-8 bytes using unsigned 32-bit FNV-1a: initial value 2166136261, XOR each byte, multiply by 16777619 with 32-bit wrapping. Face is hash modulo 20. Colour is floor(hash / 20) modulo 8.

Reference vectors: `HT Product Lead` → face 0, colour 3; `SF Design Lead` → face 8, colour 3; `机器人` → face 9, colour 4. Renaming the displayed title preserves the robot. Local consoles without tmux identity use their name.

The face order and eight colours match Android's `BotAvatar.kt`. The production native renderer draws vectors into a circular crop, including the same mirrored and tilted faces and diagonal shading. No avatar picker is added.

The sidebar uses 40-pixel faces, names and message previews. Pinned sessions wrap into 88×92 tiles with 56-pixel faces. The chat title uses the same identity at 28 pixels. Sizes follow the app's UI scaling.

Design: https://www.figma.com/design/8Yzu3N21UlCL7lA3YXm45D?node-id=113-873
Android: https://app.hypertask.ai/detail/project-2060/1151

The Robot avatars GitHub workflow runs the real Windows executable against an isolated saved profile and the existing SSH stand-in. It checks coloured avatar pixels, clicks both pinned tiles and a normal row, and records the selected raw session. Supply a published release tag to verify the shipped binary, or a pre-change tag for the negative control. No tests or synthetic input run on the user's desktop.
