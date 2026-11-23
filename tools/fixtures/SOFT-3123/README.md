# SOFT-3123 geometry evidence

The messages-only journey must reject extra working-strip space without undoing the stable new-message band.

`geometry-input.json` is the unchanged geometry from `messages-only/geometry-input.json` in [failed master run 45113017715](https://github.com/valentinyeo/multiprompt/actions/runs/45113017715/job/137490985917), artifact [14791628821](https://github.com/valentinyeo/multiprompt/actions/runs/45113017715/artifacts/14791628821). Only formatting changed.

The retained `debug.log` records:

```text
[chat] frame transcript 314,62,1006,628 edit 368,670,918,692 card 354,658,1006,702
```

The composer edit starts 12px inside its card. The card starts at 658; the transcript ends at 628. The actual gap is exactly 30px, not the proof's obsolete 14px.

[SOFT-3077, commit 0307f2e12d14900485458e9325d825050e76f989](https://github.com/valentinyeo/multiprompt/commit/0307f2e12d14900485458e9325d825050e76f989) deliberately made `chatNewMessagesHeight()` a constant `uiScaled(30)` and the transcript gap the maximum of that band and the normal 14px gap. This prevents a pill arrival from shifting or clipping messages. `chatWorkingIndicatorH()` still returns zero. The failed run's final screenshot shows the messages and composer with no working strip.

The corrected oracle requires exactly the 30px scaled band and checks every pixel in that band during CLEAN on/off. It accepts neither the old 14px gap nor any extra working-strip space. The fixture test covers 100%, 150% and 200% scale, with one-pixel and 16px missing/extra-space negative controls. Existing message-pixel and tool-data assertions remain unchanged.

No app code changes; no changelog fragment is needed. All tests and desktop verification run on GitHub-hosted runners.
