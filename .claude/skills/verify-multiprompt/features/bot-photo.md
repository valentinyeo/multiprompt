# Bot photos

## Sub-features

Bot face offers a local image and Reset. Images use a centered circle. Reset keeps the chosen face and color.

## How to get to it (user POV)

Open Ctrl+K, choose Bot face, then Upload image or Reset.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=bot-photo`. The Windows-only driver uses isolated local sessions and real native file dialogs. Evidence is uploaded as `verify-bot-photo`.

## Gotchas

This journey uses offline local tabs. It does not verify account sync, remote services, or Android. Review `result.json` and screenshots before claiming success.
