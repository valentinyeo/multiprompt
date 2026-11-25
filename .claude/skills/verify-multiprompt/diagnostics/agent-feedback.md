# Agent feedback attachments

Dispatch the existing public workflow on the target branch:

```sh
gh workflow run chat-history-reader-proof.yml --ref <branch> -f feedback_live=true
```

The hosted Linux job runs the feedback behavioral cases, installs the verified official CLI, and uses its authorized agent secret. The real-board proof installs the bundled feedback tool, submits the same generated synthetic PNG twice to the canonical wish on board 13734 (https://app.hypertask.ai/project?id=13734&view=agent-feedback), checks attachment readback, and downloads its file source to verify the exact SHA-256. The synthetic image contains no private data. Inspect `feedback-live-proof` for the safe receipt and `feedback-live-diagnostic` on failure. Match the run revision to the branch.

This proves the feedback tool and board attachment path, not the Windows GUI. It does not capture or upload a real screenshot. No new ticket should be created by the proof. The proof accepts the canonical wish whichever ticket prefix board 13734 uses. Outside the workflow the tool reads the chat's own agent login when `HT_TOKEN` is unset, and `--drain` drops queue rows saved before the cutoff `1795550400` without a board call.
