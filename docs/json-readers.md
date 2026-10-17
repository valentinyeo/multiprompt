# JSON readers

Inventory coordinates below refer to parent `a42bcb5`, so deleted readers remain locatable. Counts are logical document-reading entry points, not individual field lookups: **25 in src/main.zig, 1 in src/bridge.zig, 1 in src/chat_image.zig**.

| Original location | Entry point | Input / replacement |
| --- | --- | --- |
| src/main.zig:2694 | ensureDevThemeConfigFile | theme-dev.json revision; parsed root value |
| src/main.zig:2800 | loadDevThemeFromFile | theme-dev.json fonts/colors; parsed root, named sections and legacy flat fields |
| src/main.zig:8379 | parseWorkspaceRegistryJson | windows.json windows array |
| src/main.zig:8669 | scanLiveWorkspaceFile | inbox-*.json live-window header and workspace slots |
| src/main.zig:9051 | inferWorkspaceNameFromSessionFile | session-*.json first named group |
| src/main.zig:11432 | parseSessionTabs | session.json, session-*.json and workspace snapshots; root tabs array |
| src/main.zig:12013 | restoreSession | session.json/.bak preferences, workspace metadata, groups and active tab |
| src/main.zig:15521 | loadCapacityPolicy | capacity.json limits and zero-value fallbacks |
| src/main.zig:15616 | loadCustomCommands | commands.json commands array; label/name and kind/host aliases retained |
| src/main.zig:16384 | parseArchiveJson | archive.json array; host=1 mapping retained |
| src/main.zig:17383 | loadSnippets | snippets.json wrapped snippets array or legacy bare array |
| src/main.zig:17856 | loadRemindersIfNeeded | reminders.json array; validation participates in existing retry/quarantine policy |
| src/main.zig:24308 | absorbWorkspaceIntoSlots | session-*.json empty tabs and source workspace metadata |
| src/main.zig:25285 | writeCurrentThemeManifest | extension themes/current/manifest.json previous version |
| src/main.zig:25367 | browserUrlPollThread | bridge URL response result.url / result.tab.url |
| src/main.zig:26220 | resolveBrowserWindowIdFromCommand | bridge resolve-window response result.windowId / legacy root windowId |
| src/main.zig:34187 | chatOutboxParseJson | chat-outbox.json v1/v2 queues/messages and send anchors |
| src/main.zig:34258 | loadChatOutbox | chat-outbox.json migration version |
| src/main.zig:49960 | parseDeepgramTranscript | Deepgram JSON response; first nonempty transcript in document order |
| src/main.zig:53773 | zsbLooksLikeStaleBindingError | bridge ok/error response |
| src/main.zig:53805 | zsbReadOpenTab | bridge result.tab / legacy flat result |
| src/main.zig:53860 | zsbEstablishOpenTab | bridge navigation verification ok flag, now checked by URL reader |
| src/main.zig:53898 | zsbReplyHasUrl | bridge response decoded URL and success flag |
| src/main.zig:55065 | computeEtaAccuracy | eta-log.jsonl, parsed once per line |
| src/main.zig:55577 | loadInboxFile | inbox-*.json root, slots and shells, independent of member order |
| src/bridge.zig:1477 | replyIsInstanceMismatch | browser response ok/error, parsed Value |
| src/chat_image.zig:246 | parseUploadResponseUrl | upload response typed struct, ignore_unknown_fields=true; explicit output-buffer ownership |

Shared hand-written grammar removed: src/main.zig:2714 findThemeField, :2723 parseThemeStringField, :2748 parseThemeIntField, :3758 parseArchiveContent field extraction, :8276 parseJsonStringField, :8323 findJsonObjectEndFrom, :8360 parseJsonBoolFalse, :15545 customCmdJsonBoolTrue, :17301 parseJsonWideStringField, :17353 findJsonObjectClose, :34104 parseJsonU64Field, :55534 parseJsonUintField. Color hex, archive-row hex and numeric strings are decoded only after std.json has identified their actual values. Theme color/font and capacity wrappers no longer parse JSON text.

Other src/*.zig JSON consumers already used std.json and are unchanged. The remaining manifest line matching in writeCurrentThemeManifest is exclusively an existing writer/template transformation, not a reader; preserving it avoids gratuitous format changes. sync_protocol.zig JSON substring operations mutate test fixtures, never read production data. Upload configuration readers in bridge.zig/chat_image.zig read TOML, not JSON. JSONL line splitting and SSH preamble removal frame documents before std.json parses them. Error-message substring matching operates on decoded error strings. The frozen original session reader in tools/json-reader/legacy.zig exists only as the benchmark/compatibility positive control and is not imported by the application.

## Compatibility and defects

Missing fields retain false/zero/empty defaults, native browser=true, split=350 clamped to 50..950, and prior workspace/font/zoom/voice/capacity fallbacks. Quoted unsigned fields remain accepted where the old general uint reader accepted them; outbox's stricter default-aware uint reader retains its number-only behavior. Existing buffer caps, kind fallback to cmd, host/workspace mapping, command rejection rules, outbox v1 send-state defaults and reminders retry/quarantine policy remain in place. Unknown fields and nested extensions are ignored by consumers. UTF-8 strings now decode correctly; saved tab names are UTF-16 rather than lossy Latin-1. Truncation does not split UTF-8 codepoints or UTF-16 surrogate pairs.

Previously, fields before name were lost, substring matches could read nested/unrelated records, whitespace/reordered fields could hide tabs/settings, braces and brackets inside names could terminate arrays/objects, and generic unescaping turned newline and Unicode escapes into literal letters. Inbox headers also depended on shells being the last field. These are structural readers now.

Wire keys, types, ordering and optional-field emission are unchanged. Writer exceptions fix invalid JSON: byte escapers now encode control characters; workspace/group names and Claude cwd use that escaper; exported UTF-16 tab names now use the existing wide escaper instead of emitting invalid raw Latin-1/control bytes. Ordinary valid ASCII output remains unchanged.

## Proof

`node tools/json-reader/benchmark.mjs` builds native ReleaseFast unit tests using the actual SavedTab definition from the assembled application source and a frozen original parser. It checks every restored field against old-version and fully populated 60-tab fixtures, checks reordered/escaped/Unicode/nested/unknown/missing-field round trips, and proves the original reader fails the adversarial fixture. Timing includes document parsing, all tab-field conversions and allocator/deallocation costs; excludes file I/O and process creation. Nine batches of 100 restores use the median, with a hard after <= before * 1.10 assertion and a 512 KiB transient-arena ceiling. The benchmark prints measured timings and exits nonzero if a bound fails.

`zig test src/json_reader.zig -O ReleaseFast` exercises field scoping, escapes, u64 limits, numeric-string compatibility, defaults, UTF-16 conversion and round trips. Desktop tests cover session IDs before names, Unicode, control-character serialization, theme/capacity defaults, existing archive round trips, outbox v1/v2 state and Unicode. Upload/bridge tests cover formatted responses and nested decoys. Source-shape assertions for lock/attention persistence now follow the shared structural reader.
