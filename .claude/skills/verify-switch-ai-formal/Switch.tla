---------------------------- MODULE Switch ----------------------------
EXTENDS Naturals, FiniteSets, Sequences
CONSTANTS RefuseBusy, DisableOldBeforeStart, OldStaysDisabledWhenStartFails,
          ReportSwitchedWhenStartFails, SkipLocatorDelete, Providers, Scenario
VARIABLES phase, provider, liveCount, identityOk, historyOk, lost, duplicate,
          oldRunning, busy, pendingSwitch, switching, restarted, startOk, sentDuring,
          currentSid, dualLocator
vars == <<phase, provider, liveCount, identityOk, historyOk, lost, duplicate,
          oldRunning, busy, pendingSwitch, switching, restarted, startOk, sentDuring,
          currentSid, dualLocator>>
Init == /\ phase = "idle"
        /\ provider = "claude"
        /\ liveCount = 1
        /\ identityOk = TRUE
        /\ historyOk = TRUE
        /\ lost = FALSE
        /\ duplicate = FALSE
        /\ oldRunning = TRUE
        /\ busy = FALSE
        /\ pendingSwitch = 0
        /\ switching = FALSE
        /\ restarted = FALSE
        /\ startOk = TRUE
        /\ sentDuring = FALSE
        /\ currentSid = 1
        /\ dualLocator = FALSE
SetBusy == /\ ~switching
            /\ busy' = TRUE
            /\ phase' = "busy"
            /\ UNCHANGED <<provider, liveCount, identityOk, historyOk, lost, duplicate,
                            oldRunning, pendingSwitch, switching, restarted, startOk,
                            sentDuring, currentSid, dualLocator>>
ClearBusy == /\ busy
              /\ busy' = FALSE
              /\ phase' = "idle"
              /\ UNCHANGED <<provider, liveCount, identityOk, historyOk, lost, duplicate,
                              oldRunning, pendingSwitch, switching, restarted, startOk,
                              sentDuring, currentSid, dualLocator>>
RequestSwitch == /\ ~switching
                  /\ pendingSwitch < 2
                  /\ IF busy /\ RefuseBusy
                        THEN /\ pendingSwitch' = pendingSwitch + 1
                             /\ UNCHANGED <<phase, provider, liveCount, identityOk, historyOk,
                                            lost, duplicate, oldRunning, busy, switching,
                                            restarted, startOk, sentDuring, currentSid, dualLocator>>
                        ELSE /\ switching' = TRUE
                             /\ phase' = "switching"
                             /\ pendingSwitch' = pendingSwitch + 1
                             /\ UNCHANGED <<provider, liveCount, identityOk, historyOk, lost,
                                            duplicate, oldRunning, busy, restarted, startOk,
                                            sentDuring, currentSid, dualLocator>>
SendDuringSwitch == /\ switching
                     /\ sentDuring' = TRUE
                     /\ UNCHANGED <<phase, provider, liveCount, identityOk, historyOk, lost,
                                    duplicate, oldRunning, busy, pendingSwitch, switching,
                                    restarted, startOk, currentSid, dualLocator>>
Complete == /\ switching
             /\ switching' = FALSE
             /\ phase' = "idle"
             /\ currentSid' = currentSid + 1
             /\ identityOk' = TRUE
             /\ historyOk' = TRUE
             /\ liveCount' = 1
             /\ pendingSwitch' = 0
             /\ busy' = FALSE
             /\ UNCHANGED <<lost, duplicate, restarted, startOk, sentDuring>>
CommitToCodex == /\ Complete /\ provider = "claude" /\ provider' = "codex"
                 /\ dualLocator' = (IF SkipLocatorDelete THEN TRUE ELSE FALSE)
                 /\ oldRunning' = (IF DisableOldBeforeStart THEN FALSE ELSE oldRunning)
CommitToPi == /\ Complete /\ provider = "codex" /\ provider' = "pi"
              /\ dualLocator' = (IF SkipLocatorDelete THEN TRUE ELSE FALSE)
              /\ oldRunning' = (IF DisableOldBeforeStart THEN FALSE ELSE oldRunning)
CommitToClaude == /\ Complete /\ provider = "pi" /\ provider' = "claude"
                   /\ dualLocator' = (IF SkipLocatorDelete THEN TRUE ELSE FALSE)
                   /\ oldRunning' = (IF DisableOldBeforeStart THEN FALSE ELSE oldRunning)
CommitSwitch == CommitToCodex \/ CommitToPi \/ CommitToClaude
MarkStartFail == /\ Scenario /= "reliable"
                  /\ ~switching
                  /\ startOk' = FALSE
                  /\ UNCHANGED <<phase, provider, liveCount, identityOk, historyOk, lost,
                                  duplicate, oldRunning, busy, pendingSwitch, switching,
                                  restarted, sentDuring, currentSid, dualLocator>>
Restart == /\ Scenario /= "reliable"
            /\ restarted' = TRUE
            /\ switching' = FALSE
            /\ pendingSwitch' = 0
            /\ UNCHANGED <<phase, provider, liveCount, identityOk, historyOk, lost, duplicate,
                            oldRunning, busy, startOk, sentDuring, currentSid, dualLocator>>
Next == SetBusy \/ ClearBusy \/ RequestSwitch \/ SendDuringSwitch \/ CommitSwitch \/
        MarkStartFail \/ Restart
Spec == Init /\ [][Next]_vars
Bounded == pendingSwitch <= 2 /\ currentSid <= 5
OneLiveChat == liveCount <= 1 /\ ~dualLocator
IdentityStable == identityOk
NoLostOrDuplicate == ~lost /\ ~duplicate
HistoryReadable == switching \/ historyOk
FailedSwitchKeepsOld == startOk \/ oldRunning
=============================================================================