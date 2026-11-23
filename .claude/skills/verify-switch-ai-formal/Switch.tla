---------------------------- MODULE Switch ----------------------------
EXTENDS Naturals, FiniteSets, Sequences
CONSTANTS RefuseBusy, StopOldOnCommit, CommitAfterStartFail,
          CarryQueuedMessages, SkipLocatorDelete, CarryIdentity, CarryHistory,
          Providers, Scenario
VARIABLES phase, provider, liveCount, identityOk, historyOk, lost, duplicate,
          aiRunning, busy, pendingSwitch, switching, restarted, startOk, sentDuring,
          currentSid, dualLocator
vars == <<phase, provider, liveCount, identityOk, historyOk, lost, duplicate,
          aiRunning, busy, pendingSwitch, switching, restarted, startOk, sentDuring,
          currentSid, dualLocator>>
Init == /\ phase = "idle"
        /\ provider = "claude"
        /\ liveCount = 1
        /\ identityOk = TRUE
        /\ historyOk = TRUE
        /\ lost = FALSE
        /\ duplicate = FALSE
        /\ aiRunning = TRUE
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
                            aiRunning, pendingSwitch, switching, restarted, startOk,
                            sentDuring, currentSid, dualLocator>>
ClearBusy == /\ busy
              /\ busy' = FALSE
              /\ phase' = "idle"
              /\ UNCHANGED <<provider, liveCount, identityOk, historyOk, lost, duplicate,
                              aiRunning, pendingSwitch, switching, restarted, startOk,
                              sentDuring, currentSid, dualLocator>>
RequestSwitch == /\ ~switching
                  /\ pendingSwitch < 2
                  /\ IF busy /\ RefuseBusy
                        THEN /\ pendingSwitch' = pendingSwitch + 1
                             /\ UNCHANGED <<phase, provider, liveCount, identityOk, historyOk,
                                            lost, duplicate, aiRunning, busy, switching,
                                            restarted, startOk, sentDuring, currentSid, dualLocator>>
                        ELSE /\ switching' = TRUE
                             /\ phase' = "switching"
                             /\ pendingSwitch' = pendingSwitch + 1
                             /\ UNCHANGED <<provider, liveCount, identityOk, historyOk, lost,
                                            duplicate, aiRunning, busy, restarted, startOk,
                                            sentDuring, currentSid, dualLocator>>
SendDuringSwitch == /\ switching
                     /\ sentDuring' = TRUE
                     /\ UNCHANGED <<phase, provider, liveCount, identityOk, historyOk, lost,
                                    duplicate, aiRunning, busy, pendingSwitch, switching,
                                    restarted, startOk, currentSid, dualLocator>>
MarkStartFail == /\ Scenario /= "reliable"
                  /\ switching
                  /\ startOk' = FALSE
                  /\ UNCHANGED <<phase, provider, liveCount, identityOk, historyOk, lost,
                                  duplicate, aiRunning, busy, pendingSwitch, switching,
                                  restarted, sentDuring, currentSid, dualLocator>>
AbortSwitch == /\ switching
                /\ ~startOk
                /\ switching' = FALSE
                /\ phase' = "idle"
                /\ pendingSwitch' = 0
                /\ startOk' = TRUE
                /\ UNCHANGED <<provider, liveCount, identityOk, historyOk, lost, duplicate,
                                aiRunning, busy, restarted, sentDuring, currentSid, dualLocator>>
CommitSwitch == /\ switching
                /\ (startOk \/ CommitAfterStartFail)
                /\ switching' = FALSE
                /\ phase' = "idle"
                /\ currentSid' = currentSid + 1
                /\ identityOk' = (identityOk /\ CarryIdentity /\ ~SkipLocatorDelete)
                /\ historyOk' = (historyOk /\ CarryHistory)
                /\ liveCount' = (IF StopOldOnCommit THEN 1 ELSE 2)
                /\ pendingSwitch' = 0
                /\ busy' = FALSE
                /\ dualLocator' = SkipLocatorDelete
                /\ duplicate' = dualLocator'
                /\ aiRunning' = startOk
                /\ lost' = (lost \/ (sentDuring /\ ~CarryQueuedMessages))
                /\ provider' = (IF provider = "claude" THEN "codex"
                                ELSE IF provider = "codex" THEN "pi" ELSE "claude")
                /\ UNCHANGED <<restarted, startOk, sentDuring>>
Restart == /\ Scenario /= "reliable"
            /\ restarted' = TRUE
            /\ switching' = FALSE
            /\ pendingSwitch' = 0
            /\ startOk' = TRUE
            /\ UNCHANGED <<phase, provider, liveCount, identityOk, historyOk, lost, duplicate,
                            aiRunning, busy, sentDuring, currentSid, dualLocator>>
Next == SetBusy \/ ClearBusy \/ RequestSwitch \/ SendDuringSwitch \/ MarkStartFail \/
        AbortSwitch \/ CommitSwitch \/ Restart
Spec == Init /\ [][Next]_vars
Bounded == pendingSwitch <= 2 /\ currentSid <= 5
OneLiveChat == liveCount <= 1 /\ ~dualLocator
IdentityStable == identityOk
NoLostOrDuplicate == ~lost /\ ~duplicate
HistoryReadable == switching \/ historyOk
FailedSwitchKeepsOld == startOk \/ aiRunning
=============================================================================
