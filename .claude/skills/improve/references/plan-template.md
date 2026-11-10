# Plan template

The executor has no context. It has not seen the advisor session, the audit or the other plans. Assume it follows explicit instructions well and fills gaps badly.

Three properties make a plan executable:

1. Everything it needs is in the file: paths, excerpts, conventions, the repo rules that bind the change.
2. Every step ends in a check with an expected result. The executor never judges for itself whether it succeeded.
3. It has hard limits and STOP conditions, so the executor reports instead of improvising.

One difference from most repos shapes every plan here. Nobody builds or tests locally. A step can only be checked statically, by reading or searching. The whole change is proven once, by CI on the pushed branch. So keep steps small, and make the static checks sharp enough to catch a wrong edit before a twenty-minute CI run does.

File name: `tmp/plans/NNN-short-slug.md`, numbered in the recommended order.

## Template

```markdown
# Plan NNN: <imperative title, what is true once this lands>

> **Executor instructions**: Follow the steps in order. Run every check and
> confirm the expected result before the next step. If a STOP condition
> occurs, stop and report. Do not improvise. Never build, test or launch
> anything on this machine. CI on your pushed branch is the only test run.
>
> **Drift check, run first**: `git diff --stat <planned-at SHA>..HEAD -- <in-scope paths>`
> If an in-scope file changed, compare the "Current state" excerpts with the
> live code. A mismatch is a STOP condition.

## Status

- **Priority**: P1 | P2 | P3
- **Effort**: S | M | L
- **Risk**: LOW | MED | HIGH
- **Depends on**: tmp/plans/NNN-*.md, or "none"
- **Category**: bug | security | perf | tests | debt | deps | dx | docs | direction
- **Planned at**: commit `<short SHA>`, <YYYY-MM-DD>
- **Ticket**: IGSH-<n>, or "none yet". No ticket, no execution.
- **Android ticket**: IGSH-<n>, only for a change to chat, sessions or sync

## Why this matters

2 to 5 sentences. The problem, what it costs, what improves. The executor
uses this to make the right call when a detail is off.

## Current state

- Each relevant file with one line on its role:
  - `<path>`: <its role>, <what in it this plan changes> (lines <from> to <to>)
- Short excerpts of the code as it is today, with `file:line` markers.
- The convention to match, with one exemplar:
  "<how this repo does the thing>, see `<exemplar path>:<lines>`. Match it."

## Repo rules that bind this change

Quote the CLAUDE.md lines that apply. Leave out the rest. Typical ones:

- Code carries no comments. `tools/strip-comments.mjs --check` fails on any.
- An edit to the inner reader raises `RUNTIME_GENERATION` in `src/chat_history_reader.py`.
- A change to shipped files in `extension/` raises `"version"` in `extension/manifest.json`.
- Never edit `APP_VERSION` or `.ver` lines. CI stamps versions.
- A user-facing feature ships a shortcut where sensible, a palette entry, a `SHORTCUT_ROWS` row, the doc row and an `mb` verb in the same change.
- No Ctrl+Alt shortcuts. No status elements around chat messages.
- Regression inputs live in `tools/fixtures/<ticket>/`.

## Checks that prove it

| Check | Workflow and job | Run it on the branch | Expected |
|---|---|---|---|
| Full suite | `test.yml`, final `test` job | `gh workflow run test.yml --ref <branch>` | green |
| <named test file> | `test.yml`, `<job>` | same run | passes, including the new case |
| Desktop journey | `verify.yml` | `gh workflow run verify.yml --ref <branch> -f feature=<name>` | green, screenshot shows <what> |

Exact names, found during recon. If the session has no `gh`, use its GitHub
tool to dispatch the workflow. Read the run that matches your head SHA.
Never take a `master` run as proof for the branch.

## Scope

**In scope**, the only files to modify:
- `<path>`
- `tools/<name>.test.js` (create)

**Out of scope**, even though they look related:
- `<path>`: <why it stays untouched, and what breaks if it does not>

## Git workflow

- Branch: `improve/<TICKET>-<slug>`. Never commit to `master`. Never open a pull request.
- Commit subject: `<TICKET>: Brief description`. The body says what and why and ends with the line `Undo: git revert this commit.`
- Changelog: `changelog.d/<TICKET>-<slug>.md` containing exactly:
  `<one plain sentence for the end user, no ticket ids, file names or code names>`
  Or: "No fragment. This change is pipeline-only." State which, per `changelog.d/README.md`.
- Push only your own branch. Landing on `master` is the user's call, because that push ships a release.

## Steps

### Step 1: add the failing check

Write the check first, so the run shows red for the right reason before the fix.

**Check**: `grep -n "<test name>" tools/<file>.test.js` shows one match.

### Step 2: <imperative title>

What to do, exactly. Name files and symbols. Show the target shape of the
code where it carries weight.

**Check**: `<search command>` shows <expected output>.

(Order steps so the tree stays coherent between them: add the new path,
switch the callers, then remove the old path.)

### Last step: prove it in CI

Push the branch. Dispatch every row of "Checks that prove it". Record each run URL.

## Test plan

- New checks, in which file, covering which cases: the happy path, the regression this plan fixes, named edge cases.
- The existing test to copy the structure from.
- The check must exercise behaviour. A check that only matches source text does not count.

## Done criteria

ALL must hold:

- [ ] Every row of "Checks that prove it" is green on the branch's head SHA, with run URLs recorded
- [ ] `grep -rn "<old pattern>" src/` returns nothing
- [ ] `git diff --stat master...HEAD` lists only in-scope files
- [ ] The changelog fragment exists with the exact text above, or the plan says none is needed
- [ ] Every rule under "Repo rules that bind this change" is met

## STOP conditions

Stop and report if:

- The code at the "Current state" locations does not match the excerpts.
- A CI check fails twice after a reasonable fix attempt.
- The fix needs a file outside the scope.
- A check can only pass by skipping, disabling or weakening a test.
- You find that "<the key assumption>" is false.

## Maintenance notes

- What later changes will interact with this.
- What a reviewer should look at hardest.
- Follow-ups left out of this plan, and why.
```

## Index: `tmp/plans/README.md`

```markdown
# Plans

Written by the improve skill on <date> at commit <short SHA>.

| Plan | Title | Priority | Effort | Depends on | Ticket | Status |
|------|-------|----------|--------|------------|--------|--------|
| 001  | ...   | P1       | S      | none       | IGSH-n | TODO   |

Status: TODO | IN PROGRESS | DONE | BLOCKED (one-line reason) | REJECTED (one-line reason)

## Dependencies

- 002 needs 001 because <reason>.

## Considered and rejected

- <finding>: not worth doing because <one line>.

## Not audited

- <area>: <why>.
```

## Quality bar

Check each plan before you finish it:

- Could a model that has never seen this repo execute it with only this file and the checkout?
- Is every check a command with an expected result?
- Does every step name exact files and symbols?
- Does every CI row name a real workflow and job, and does that job run the test the plan relies on?
- Are the STOP conditions about this plan's real risks?
- Does the changelog sentence read like something a user would care about?
- Is the file free of secrets, private host names, internal paths and emails?
- Is the "Planned at" SHA filled in, and do the drift-check paths match the scope?
