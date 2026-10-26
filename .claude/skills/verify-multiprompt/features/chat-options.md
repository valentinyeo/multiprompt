# Chat options

## Sub-features

When the latest reply lists two or more lettered or numbered options, Chat View shows each as a clickable card under the reply, and a click sends the answer for the user. When a terminal prompt asks a single-select question with a numbered pick list, each option is a card and a click sends that option's number to the prompt. A last card, Type something else, selects the prompt's own typing option and puts the cursor in the message box. The chosen card stays highlighted, the others fade, and older replies show no clickable cards.

## How to get to it (user POV)

Open Chat View with Alt+C on a session whose latest reply ends with A and B options, or whose terminal is waiting on a pick list. Click a card.

## Driving it with control.ps1

Run on GitHub Windows only:

```sh
gh workflow run verify.yml --ref ceo/IGSH-984 -f feature=chat-options
gh workflow run verify.yml --ref master -f feature=chat-options
```

The journey prints a reply with options A and B in a real CMD tab from a script that waits for one line of console input. It opens Chat View, reads the card positions from the app's `CHAT_CHOICES` trace, clicks card B with a real mouse click, and requires the script to receive exactly `B: Reuse the Yeo UX key for now`. It then requires the chosen card to be highlighted with no clickable cards left, and a second click on card A to change nothing. A second CMD tab prints a Claude Code single-select question screen and waits for one key. The journey clicks the second card and requires the script to receive `2`, with the card highlighted.

## Gotchas

The question screen is printed by a script that copies the real prompt's rows; it is not Claude Code itself, and the key is read by PowerShell, not by an agent. The same run on a build without option cards must fail at the card wait. Card detection follows the Android app: items labelled A, B, C or 1, 2, 3 in order, two or more, in the latest reply. A tmux or SSH session is not covered by the question prompt cards because the app reads prompts from the local console only.
