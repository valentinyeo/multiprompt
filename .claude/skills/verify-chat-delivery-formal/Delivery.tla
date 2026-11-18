---------------------------- MODULE Delivery ----------------------------
EXTENDS Naturals, Sequences, TLC
CONSTANTS Reconciles, LoadQueued, LoadSending, ShowQueuedOld, ShowNotSent,
          ShowDelivered, CanSendQueued, CanSendWritten, TimeoutQueued,
          TimeoutSending, Scenario
VARIABLES state, written, pending, host, transcript, age, restarted, retried,
          submitted, wire, hostWires, connected
vars == <<state, written, pending, host, transcript, age, restarted, retried,
          submitted, wire, hostWires, connected>>
Init == /\ state = "empty" /\ written = FALSE /\ pending = FALSE
        /\ host = "empty" /\ transcript = FALSE /\ age = FALSE
        /\ restarted = FALSE /\ retried = FALSE /\ submitted = FALSE
        /\ wire = 1 /\ hostWires = {} /\ connected = TRUE
Send == /\ state = "empty"
        /\ state' = "queued" /\ pending' = TRUE
        /\ UNCHANGED <<written, host, transcript, age, restarted, retried,
                        submitted, wire, hostWires, connected>>
Submit == /\ pending /\ connected /\ ~submitted
          /\ IF written THEN CanSendWritten ELSE state = "queued" /\ CanSendQueued
          /\ state' = "sending" /\ written' = TRUE /\ submitted' = TRUE
          /\ UNCHANGED <<pending, host, transcript, age, restarted, retried,
                          wire, hostWires, connected>>
HostReceives == /\ submitted /\ wire \notin hostWires
                /\ host' = "queued" /\ hostWires' = hostWires \cup {wire}
                /\ UNCHANGED <<state, written, pending, transcript, age,
                                restarted, retried, submitted, wire, connected>>
HostDispatch == /\ host = "queued" /\ host' = "sent"
                /\ UNCHANGED <<state, written, pending, transcript, age,
                                restarted, retried, submitted, wire, hostWires, connected>>
HostAccepts == /\ host = "sent" /\ host' = "accepted"
               /\ UNCHANGED <<state, written, pending, transcript, age,
                               restarted, retried, submitted, wire, hostWires, connected>>
Receipt == /\ connected /\ pending /\ host \in {"queued", "sent", "accepted"}
           /\ state' = IF host = "accepted" THEN "delivered" ELSE "queued"
           /\ written' = TRUE
           /\ UNCHANGED <<pending, host, transcript, age, restarted, retried,
                           submitted, wire, hostWires, connected>>
Disconnect == /\ connected /\ connected' = FALSE
              /\ UNCHANGED <<state, written, pending, host, transcript, age,
                              restarted, retried, submitted, wire, hostWires>>
Reconnect == /\ ~connected /\ connected' = TRUE
             /\ UNCHANGED <<state, written, pending, host, transcript, age,
                             restarted, retried, submitted, wire, hostWires>>
Wait == /\ Scenario = "all" /\ pending /\ ~age /\ age' = TRUE
        /\ state' = CASE state = "queued" -> TimeoutQueued
                      [] state = "sending" -> TimeoutSending
                      [] OTHER -> state
        /\ UNCHANGED <<written, pending, host, transcript, restarted,
                        retried, submitted, wire, hostWires, connected>>
Resume == /\ Scenario # "reliable" /\ pending /\ ~restarted /\ written
          /\ restarted' = TRUE
          /\ state' = CASE state = "sending" -> LoadSending
                        [] state = "queued" -> LoadQueued
                        [] OTHER -> state
          /\ UNCHANGED <<written, pending, host, transcript, age, retried,
                          submitted, wire, hostWires, connected>>
Echo == /\ connected /\ host = "accepted" /\ ~transcript
        /\ transcript' = TRUE /\ pending' = IF Reconciles THEN FALSE ELSE pending
        /\ UNCHANGED <<state, written, host, age, restarted, retried,
                        submitted, wire, hostWires, connected>>
NotSent == pending /\ CASE state = "not_sent" -> ShowNotSent
                          [] state = "delivered" -> ShowDelivered
                          [] OTHER -> age /\ ShowQueuedOld
Retry == /\ NotSent /\ ~retried /\ connected
         /\ retried' = TRUE
         /\ IF host = "accepted"
               THEN UNCHANGED <<state, written, submitted, wire, host>>
               ELSE /\ wire' = 2 /\ state' = "sending" /\ written' = TRUE
                    /\ submitted' = TRUE /\ host' = "empty"
         /\ UNCHANGED <<pending, transcript, age, restarted, hostWires, connected>>
Done == UNCHANGED vars
Next == Send \/ Submit \/ HostReceives \/ HostDispatch \/ HostAccepts \/ Receipt \/ Disconnect
        \/ Reconnect \/ Wait \/ Resume \/ Echo \/ Retry \/ Done
Spec == Init /\ [][Next]_vars
SingleVisibleCopy == state = "empty" \/ (IF pending THEN 1 ELSE 0) + (IF transcript THEN 1 ELSE 0) = 1
NoFalseNotSent == host # "accepted" \/ ~NotSent
=============================================================================
