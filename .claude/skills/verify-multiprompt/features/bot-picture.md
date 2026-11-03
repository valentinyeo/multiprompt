# Bot picture

Verify on: push

Give a bot your own picture through the tab-action palette, check the real Windows file picker, and confirm the saved tab and the drawn face keep it across a restart until Reset picture brings the drawn face back.

## Sub-features

- `upload-picture`: `Upload image` opens the real file picker, a chosen PNG is copied into the app's own store and drawn instead of the drawn face.
- `picture-survives-restart`: the saved `picture` number and the copied file survive a normal close and relaunch, and the picture is drawn again.
- `cancel-keeps-picture`: cancelling the picker keeps the saved picture number and the drawn pixels.
- `unreadable-keeps-look`: a file that is not a readable image keeps the old look and shows `Could not read that picture` in the header notice.
- `reset-restores-face`: `Reset picture` clears the saved number and the picture pixels, leaving the drawn face.

## How to get to it (user POV)

- Press Ctrl+K, type `bot face`, press Enter on the `Bot face` row in the tab-action band.
- The bot-look submenu lists `Back`, `Upload image`, `Reset picture` (only while this bot has a picture), then the named faces, and the named colours on the colour page.
- `Upload image` opens the standard Windows picture picker, owned by the main window, for PNG, JPG and JPEG. Enter accepts the file name field; Esc cancels and keeps the old picture.
- A chosen picture is copied to the app's own store and drawn in place of the drawn face. `Reset picture` clears it and the drawn face comes back with the saved colour.
- The saved session file `data/roaming/ZigShell/session.json` carries `tabs[].picture` as a decimal number; absent or `0` means no picture. The copy is `data/roaming/ZigShell/bot-pictures/<16 hex>.img`.

## Driving it with control.ps1

Preconditions:

- Baseline Doctor passes and the initial CMD tab is usable on the isolated hosted desktop.
- No session or settings file is seeded. The picture arrives only through the real picker, and every later assertion reads app-written state.
- The journey relaunches the app, so it is `Verify on: push` only and stays out of the `pull_request` matrix.

- **Dispatch.** Run `gh workflow run verify.yml -f feature=bot-picture`; watch and download as described in the [index](README.md). This invokes `control.ps1 -Feature bot-picture` on Windows with `--single-window`, the same launch shape the restart uses.
- **Baseline.** `Doctor`, `Snapshot 'before'` and a fresh window shot count picture pixels in the left 60 px column and top 300 px of the window rectangle. The baseline must draw at most 2 pixels within 24 of `255,0,160`; more means the area already holds a picture.
- **Fixture.** The journey draws a 96x72 PNG, solid `#FF00A0` with a white diagonal cross, at `$scratch\bot-picture.png` and records that path in `result.json` as `pictureFixture`.
- **Open.** Ctrl+K, `Type-Text 'bot face'`, Enter on `Bot face`, `Snapshot 'action'`, then `Type-Text 'upload image'` and Enter. Each query waits for the app's own `[palette] rows chars=<query length> count=<1 or more>` debug line after the previous log offset, and every matched line is saved as `paletteRows`.
- **Picker.** The journey waits for a visible top-level window of class `#32770` whose root owner is the app's main window. It never matches a process name. It brings that dialog to the foreground and records the foreground proof. It then finds the file name box by window class (the `ComboBoxEx32` and its `Edit`), selects the field's text, posts the ASCII path as character messages into that real Edit, and presses Enter with real input. `result.json` records the selector and the input path used. Esc cancels. It never sweeps the shell file list, and it does not rely on the accessibility proxy, which reports this dialog's controls as plain panes and refuses them focus.
- **Upload.** After the picker closes, the saved active tab must carry `picture` greater than 0. The palette is then dismissed, the store must hold `bot-pictures\<16 hex>.img` named after that number, and the picture pixels must number at least 100 with a bounding box whose width and height differ by at most 4 px. `Snapshot 'uploaded'`.
- **Cancel.** Reopen the submenu, `Upload image`, wait for the picker, take the foreground, Esc it (twice if the field's completion list swallows the first), dismiss the palette. The saved number and the picture pixel count must be unchanged.
- **Unreadable.** `$scratch\broken.png` holds plain text. Reopen the submenu, upload it, and require the picker to close, the same saved number and pixel count, and `Could not read that picture` in the app's debug log. `Snapshot 'unreadable'`.
- **Restart.** `Restart-SessionRestore 'restart' $false` closes the owned window and relaunches the same isolated profile. The restored tab must keep the same `picture` number, the copied file must still exist, and the picture pixels must again pass the count and roundness checks. `Snapshot 'restart'`.
- **Reset.** Reopen the submenu, `Type-Text 'reset picture'`, Enter. The saved `picture` must be absent or 0 and the picture pixel count must return to the baseline count. `Snapshot 'reset'`, then `Snapshot 'after'`.
- **Proof.** `result.json` carries `subFeatures` and exactly one check per sub-feature with the numbers read: `picture`, `storeFile`, `pixels`, `boundingBox`, `baselinePixels`, and the notice text. A missing or duplicated check fails the journey.

## Gotchas

- The saved `picture` number is a 64-bit hash written as a plain decimal, so it can exceed a signed 64-bit integer. The journey reads it from the saved file as text and keeps the exact digits; it never round-trips it through a JSON number.
- The unreadable notice is asserted from the app's debug log. The header notice is painted text with no other trace, so an app build that shows the notice without logging `Could not read that picture` fails this journey at that wait.
- The picker fills its own file name Edit before Enter: the Open button keeps the dialog's initial focus, so typing without addressing that field would go nowhere. A dialog that never reaches the foreground fails before any character is sent rather than writing into another window, and one Enter that leaves the dialog open is retried once.
- The picture is proven by pixels inside the left 60 px column and top 300 px of the window rectangle, and by the app-written `picture` number and store file. The drawn face itself has no pixel oracle: `reset-restores-face` proves the picture is gone, not that the restored face is pixel-identical to `before.png`.
- The round-avatar claim is the bounding box being within 4 px of square. A letterboxed or stretched drawing fails that check rather than passing quietly.
- One Esc is pressed after every picker interaction to dismiss the bot-look palette; it is harmless when the app already closed the palette. If a future palette keeps a deeper level open, the following query wait times out instead of typing into the console.
- The fixture path is ASCII because `ZIGSHELL_DEBUG=1` logs it. The path is typed into the picker, never into the app's own input path.
- This journey does not prove account-synced bot faces, the Android surface, a picture chosen from a network drive, EXIF rotation, or a picture deleted from the store while the session still names it.
- Only this journey is covered by its run. A passing run is not a claim that every face, colour page or bot surface holds the picture.
