---------------------------- MODULE Switch ----------------------------
EXTENDS Naturals, FiniteSets, Sequences
CONSTANTS RefuseBusy, StopOldOnCommit, CommitAfterStartFail,
          CarryQueuedMessages, SkipLocatorDelete, CarryIdentity, CarryHistory,
          DetectPlan, HonourOff, FollowOrder, AutoSwitchDefaultOn, Providers, Scenario
VARIABLES phase, provider, liveCount, identityOk, historyOk, lost, duplicate,
          aiRunning, busy, pendingSwitch, switching, restarted, startOk, sentDuring,
          currentSid, dualLocator, planOut, autoSwitchOn, movedByPlan, plansLeft
vars == <<phase, provider, liveCount, identityOk, historyOk, lost, duplicate,
          aiRunning, busy, pendingSwitch, switching, restarted, startOk, sentDuring,
          currentSid, dualLocator, planOut, autoSwitchOn, movedByPlan, plansLeft>>
Next(ai) == IF ai = "claude" THEN "codex" ELSE IF ai = "codex" THEN "pi" ELSE "claude"
Other(ai) == IF ai = "claude" THEN "pi" ELSE "claude"
PlanTarget == IF FollowOrder THEN Next(provider) ELSE Other(provider)
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
        /\ planOut = FALSE
        /\ autoSwitchOn = AutoSwitchDefaultOn
        /\ movedByPlan = FALSE
        /\ plansLeft = 3
SetBusy == /\ ~switching
            /\ busy' = TRUE
            /\ phase' = "busy"
            /\ UNCHANGED <<provider, liveCount, identityOk, historyOk, lost, duplicate,
                            aiRunning, pendingSwitch, switching, restarted, startOk,
                            sentDuring, currentSid, dualLocator, planOut, autoSwitchOn,
                            movedByPlan, plansLeft>>
ClearBusy == /\ busy
              /\ busy' = FALSE
              /\ phase' = "idle"
              /\ UNCHANGED <<provider, liveCount, identityOk, historyOk, lost, duplicate,
                              aiRunning, pendingSwitch, switching, restarted, startOk,
                              sentDuring, currentSid, dualLocator, planOut, autoSwitchOn,
                              movedByPlan, plansLeft>>
RequestSwitch == /\ ~switching
                  /\ pendingSwitch < 2
                  /\ IF busy /\ RefuseBusy
                        THEN /\ pendingSwitch' = pendingSwitch + 1
                             /\ UNCHANGED <<phase, provider, liveCount, identityOk, historyOk,
                                            lost, duplicate, aiRunning, busy, switching,
                                            restarted, startOk, sentDuring, currentSid,
                                            dualLocator, planOut, autoSwitchOn, movedByPlan,
                                            plansLeft>>
                        ELSE /\ switching' = TRUE
                             /\ phase' = "switching"
                             /\ pendingSwitch' = pendingSwitch + 1
                             /\ UNCHANGED <<provider, liveCount, identityOk, historyOk, lost,
                                            duplicate, aiRunning, busy, restarted, startOk,
                                            sentDuring, currentSid, dualLocator, planOut,
                                            autoSwitchOn, movedByPlan, plansLeft>>
SendDuringSwitch == /\ switching
                     /\ sentDuring' = TRUE
                     /\ UNCHANGED <<phase, provider, liveCount, identityOk, historyOk, lost,
                                    duplicate, aiRunning, busy, pendingSwitch, switching,
                                    restarted, startOk, currentSid, dualLocator, planOut,
                                    autoSwitchOn, movedByPlan, plansLeft>>
MarkStartFail == /\ Scenario /= "reliable"
                  /\ switching
                  /\ startOk' = FALSE
                  /\ UNCHANGED <<phase, provider, liveCount, identityOk, historyOk, lost,
                                  duplicate, aiRunning, busy, pendingSwitch, switching,
                                  restarted, sentDuring, currentSid, dualLocator, planOut,
                                  autoSwitchOn, movedByPlan, plansLeft>>
AbortSwitch == /\ switching
                /\ ~startOk
                /\ switching' = FALSE
                /\ phase' = "idle"
                /\ pendingSwitch' = 0
                /\ startOk' = TRUE
                /\ UNCHANGED <<provider, liveCount, identityOk, historyOk, lost, duplicate,
                                aiRunning, busy, restarted, sentDuring, currentSid,
                                dualLocator, planOut, autoSwitchOn, movedByPlan, plansLeft>>
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
                /\ provider' = Next(provider)
                /\ UNCHANGED <<restarted, startOk, sentDuring, planOut, autoSwitchOn,
                                movedByPlan, plansLeft>>
PlanRunsOut == /\ phase = "idle"
               /\ ~switching
               /\ ~planOut
               /\ planOut' = TRUE
               /\ IF DetectPlan /\ (autoSwitchOn \/ ~HonourOff) /\ plansLeft > 1
                     THEN /\ provider' = PlanTarget
                          /\ movedByPlan' = TRUE
                          /\ plansLeft' = plansLeft - 1
                          /\ currentSid' = currentSid + 1
                          /\ liveCount' = (IF StopOldOnCommit THEN 1 ELSE 2)
                          /\ identityOk' = (identityOk /\ CarryIdentity /\ ~SkipLocatorDelete)
                          /\ historyOk' = (historyOk /\ CarryHistory)
                          /\ dualLocator' = SkipLocatorDelete
                          /\ duplicate' = dualLocator'
                          /\ aiRunning' = TRUE
                          /\ lost' = (lost \/ (sentDuring /\ ~CarryQueuedMessages))
                          /\ UNCHANGED <<phase, busy, pendingSwitch, switching, restarted,
                                          startOk, sentDuring, autoSwitchOn>>
                     ELSE /\ UNCHANGED <<phase, provider, liveCount, identityOk, historyOk,
                                          lost, duplicate, aiRunning, busy, pendingSwitch,
                                          switching, restarted, startOk, sentDuring, currentSid,
                                          dualLocator, autoSwitchOn, movedByPlan, plansLeft>>
ToggleAutoSwitch == /\ ~switching
                    /\ autoSwitchOn' = ~autoSwitchOn
                    /\ movedByPlan' = FALSE
                    /\ planOut' = FALSE
                    /\ UNCHANGED <<phase, provider, liveCount, identityOk, historyOk, lost,
                                    duplicate, aiRunning, busy, pendingSwitch, switching,
                                    restarted, startOk, sentDuring, currentSid, dualLocator,
                                    plansLeft>>
Restart == /\ Scenario /= "reliable"
            /\ restarted' = TRUE
            /\ switching' = FALSE
            /\ pendingSwitch' = 0
            /\ startOk' = TRUE
            /\ UNCHANGED <<phase, provider, liveCount, identityOk, historyOk, lost, duplicate,
                            aiRunning, busy, sentDuring, currentSid, dualLocator, planOut,
                            autoSwitchOn, movedByPlan, plansLeft>>
NextStep == SetBusy \/ ClearBusy \/ RequestSwitch \/ SendDuringSwitch \/ MarkStartFail \/
            AbortSwitch \/ CommitSwitch \/ PlanRunsOut \/ ToggleAutoSwitch \/ Restart
Spec == Init /\ [][NextStep]_vars
Bounded == pendingSwitch <= 2 /\ currentSid <= 5
OneLiveChat == liveCount <= 1 /\ ~dualLocator
IdentityStable == identityOk
NoLostOrDuplicate == ~lost /\ ~duplicate
HistoryReadable == switching \/ historyOk
FailedSwitchKeepsOld == startOk \/ aiRunning
ToggleOffKeepsChat == autoSwitchOn \/ ~movedByPlan
PlanOutMovesChat == ~planOut \/ movedByPlan \/ plansLeft <= 1 \/ ~autoSwitchOn
AutoSwitchFollowsOrder == ~movedByPlan \/ FollowOrder
=============================================================================
