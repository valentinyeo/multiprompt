# Closing the loop

Three follow-through flows: `execute`, `reconcile` and `--tickets`.

The founding rule holds in all three. The advisor never edits source code, never commits, never pushes.

## `execute <plan>`

### Before dispatching

- The plan has a ticket. The commit subject and the changelog fragment both carry it. With "none yet", stop and offer `--tickets`.
- The plan's dependencies show DONE in `tmp/plans/README.md`.
- Run the plan's drift check yourself. If in-scope files changed, reconcile the plan first.
- A plan for a chat or sidebar element needs a ticket filed by Valentin or the design lead. Without one, stop.
- A plan that changes chat, sessions or sync needs its paired Android ticket. Without one, stop.

### Dispatch

Spawn one `general-purpose` subagent with `isolation: "worktree"`. Default model `sonnet`, or the one the user named.

The prompt holds:

1. The full text of the plan, inline. `tmp/` is ignored by Git, so the worktree does not contain it.
2. This preamble:

> You are the executor for the plan below. Follow it step by step. Run every
> check and confirm the expected result before moving on. Touch only the
> files in scope. Never build, test, install or launch anything on this
> machine: no zig, no node --test, no Python test suites, no Wine. The only
> test run is CI on your pushed branch. Commit in the worktree as the plan's
> Git workflow says. Push only your own branch, never master, and never open
> a pull request. If a STOP condition occurs, stop and report. Before you
> report, check every claim against a tool result from this session. If a
> check failed or you skipped it, say so. Reply in exactly the format below.

3. The report format:

```
STATUS: COMPLETE | STOPPED
BRANCH: name and head SHA
STEPS: per step, done or skipped, with the check's result
CI: per check, run URL and conclusion, or "not run" with the reason
STOPPED BECAUSE: only if STOPPED, which condition and what you saw
FILES CHANGED: list
NOTES: deviations, surprises, judgment calls
```

If the session cannot push or dispatch workflows, the executor reports "not run". Hand the branch to the user with the commands from the plan's check table.

### Review

Review like a lead reading a change against its spec. Fix nothing yourself.

1. Read the CI runs yourself. Each must match the branch's head SHA and be green. A `master` run proves nothing about the branch. Do not rerun anything locally.
2. Scope: `git -C <worktree> diff --stat master...HEAD` against the in-scope list. One file outside it fails the review.
3. Read the whole diff against "Why this matters" and the conventions the plan names. Every hunk traces to a step.
4. Read what the new checks assert. An executor can make a check pass by asserting nothing, by matching source text, or by weakening an older test. Any of those fails the review.
5. Check the repo rules the plan quoted: no comments, generation raised, extension version raised, changelog sentence in plain user language, no hand-edited version.

### Verdict

A deviation the executor explained in NOTES is judged on merit. One it hid fails the review.

| Verdict | When | Action |
|---|---|---|
| APPROVE | CI green on the head SHA, scope clean, quality holds | Mark DONE in the index. Give the user the branch, the commits, the run URLs and the NOTES. Landing on `master` is theirs to do. |
| REVISE | Gaps the executor can fix | Message the same executor with specific feedback. Two rounds at most, then BLOCK. |
| BLOCK | A STOP condition, a scope breach, or revisions used up | Mark BLOCKED with the reason. Rewrite the plan with what you learned. Tell the user what changed. |

Never approve without a green run. "Looks right" is not a verdict here, because nothing was run locally.

## `reconcile`

Read `tmp/plans/README.md` and every plan, then act per status:

- DONE: confirm the commits are on `master` and the static done criteria still hold at HEAD. Mark verified. Keep the file.
- BLOCKED: read the reason and look at the obstacle in the code. Rewrite the plan around it, or mark REJECTED with one line.
- IN PROGRESS and stale: tell the user. An executor probably died. Look for its branch.
- TODO: run the drift check. If drifted, confirm the finding still exists, then refresh the excerpts and the "Planned at" SHA. If it is gone, mark REJECTED as "fixed independently".

If `tmp/plans/` is empty because an earlier session's container ended, rebuild the index from the tickets filed with `--tickets`.

End with a short report: verified, refreshed, rejected, and what can run now.

## `--tickets`

The flag is the user's permission to create tickets. Never create one without it. Never publish a plan as a GitHub issue: this repo is public.

1. Check that the session has the Hypertask tools. If not, write the plan files and say why tickets were skipped.
2. Show the titles about to become tickets. Confirm once if someone is there to answer.
3. Create one ticket per plan on board 2060, prefix `IGSH`. The description is the plan body.
4. The title is plain user language. Release notes print it as written, so no file names or code names.
5. For a change to chat, sessions or sync, create or update the paired Android ticket first, link both ways, and use the board's Multiprompt Android label.
6. Do not file a build ticket for a chat or sidebar element. List it for Valentin as an option.
7. Before filing a security plan, reread it for secret values and private details. There should be none.
8. Write each ticket ID into the plan's Status block and the index.

The ticket is how the plan survives the session. The plan file stays the working copy while the session lasts.
