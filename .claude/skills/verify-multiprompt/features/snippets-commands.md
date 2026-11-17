# Snippets and custom commands

Journeys: command-palette

## Sub-features

The recipes below name the user actions, expected result and exact boundary.

## How to get to it (user POV)

Use the entry paths in the action table below on a disposable owned profile.

## Driving it with drive.ps1

Preconditions: a healthy GitHub Windows instance and the selected journey prerequisites.

Use `verify.yml` with the named executable journey, not this map stem. A journey is a recipe, not a claim of a live pass.

The recipes distinguish existing focused journeys from unreachable complete paths. UNREACHABLE names the missing data, endpoint, build mode or driver action; it never means the product passed.

### snippets: Snippets and custom commands

Create a named snippet through Ctrl+K Create Snippet; Ctrl+Enter saves and Escape cancels. Repeat with the same name in different case to prove replacement instead of duplication. Open Use snippets with Alt+; or Ctrl+;, paste into an unsent marker and cancel. Manage snippets and press Delete twice on the disposable snippet. Open Edit commands.json in the disposable profile, add a harmless marker command, let the file-change watcher reload it and execute its named palette row. A distinct Reload commands row is not currently generated.

Observable proof: Exact snippet text appears at the caret without sending; one Delete cannot remove it and the second removes only the selected snippet. After restart saved snippets match. The custom command writes its unique marker and malformed JSON leaves the app usable.

Journey: command-palette includes snippet confirmation/persistence. UNREACHABLE for full create/manage/custom-command proof until the driver creates through UI, controls the owned external editor, reloads and independently reads the marker and saved snippet file.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_CUSTOMCMD_EDIT_OFFSET` | Ctrl+K, type **commands**, then select the matching action with Up/Down and Enter. Follow `snippets` above. |
| `SEARCH_CUSTOMCMD_OFFSET` | Search Ctrl+K for the label configured in the isolated profile's commands.json. Follow `snippets` above. |
| `SEARCH_CUSTOMCMD_RELOAD_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_SNIPPETS_MENU_OFFSET` | Ctrl+K, search for **use snippets**. Follow `snippets` above. |
| `SEARCH_SNIPPET_BACK_OFFSET` | Open the named submenu, then choose **Back from snippets**. Follow `snippets` above. |
| `SEARCH_SNIPPET_CREATE_OFFSET` | Ctrl+K, search for **create snippet**. Follow `snippets` above. |
| `SEARCH_SNIPPET_MANAGE_OFFSET` | Ctrl+K, search for **manage snippets**. Follow `snippets` above. |
| `SEARCH_SNIPPET_OFFSET` | Open **Use snippets** with Ctrl+; or Alt+;, then select the saved snippet name. Follow `snippets` above. |

## Gotchas

Never treat an offline, synthetic or diagnostic check as authenticated end-to-end proof.
