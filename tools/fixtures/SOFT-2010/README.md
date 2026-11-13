# Reported chat freeze

`freeze.json` snapshots the numeric diagnostics from the reported five-second Chat View freeze. It contains no chat content, machine paths or device identifiers.

The final recorded `0x8092` message is `WM_APP_CHAT_FILE_READY`. That establishes the active message, not the blocking function. The watchdog scans stack memory for addresses inside the executable, so `stack_rvas` includes data pointers and stale return addresses. It is not an unwound stack trace.

The original release symbols artifact contains the wrong PDB. Its GUID does not match the symbolized executable, and it resolves app addresses to bridge functions. Track the packaging repair at https://app.hypertask.ai/detail/project-11514/378. Use matching symbols and compare the production and symbolized machine code before attributing a production address to source, because the twin's addresses differ.

The blocking cause and failing-before regression remain unproven. This fixture preserves the input for that investigation; it does not demonstrate a fix.
