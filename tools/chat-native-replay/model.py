"""Native transcript facts only; never authorizes a desktop delivery or resend."""
from collections import Counter, defaultdict
from copy import deepcopy


def empty_snapshot():
    return {"sources": {}}


def append(snapshot, source, events):
    """Append physical source positions; identical rereads are idempotent."""
    rows = snapshot["sources"].setdefault(source, [])
    for event in events:
        position = event["position"]
        if position < len(rows):
            if rows[position] != event:
                raise ValueError("source occurrence changed")
        elif position == len(rows):
            rows.append(deepcopy(event))
        else:
            raise ValueError("source occurrence gap")
    return snapshot


def classify(snapshot):
    """Classify every observed occurrence without matching text or timestamps."""
    results = {}
    for source, rows in snapshot["sources"].items():
        removes, attachments = defaultdict(list), defaultdict(list)
        for event in rows:
            ids = event.get("ids", {})
            pair = None
            if event["kind"] == "remove":
                pair = (ids.get("commandUuid"), ids.get("deliveryId"))
                if all(pair):
                    removes[pair].append(event["position"])
            elif event["kind"] == "attachment":
                pair = (ids.get("attachment.source_uuid"), ids.get("attachment.delivery_id"))
                if all(pair):
                    attachments[pair].append(event["position"])

        for event in rows:
            kind = event["kind"]
            ids = event.get("ids", {})
            flags = event.get("flags", {})
            occurrence = (source, event["position"])
            result = {"occurrence": occurrence, "desktop_binding": None}
            if event.get("incomplete"):
                result["class"] = "incomplete"
            elif any(flags.get(k) for k in ("isSidechain", "isMeta", "isCompactSummary", "isVisibleInTranscriptOnly")):
                result["class"] = "excluded"
            elif kind in ("enqueue", "dequeue", "remove", "popAll"):
                result["class"] = "queue_fact"
                if kind == "remove":
                    pair = (ids.get("commandUuid"), ids.get("deliveryId"))
                    matches = attachments.get(pair, []) if all(pair) else []
                    if len(removes.get(pair, [])) == 1 and len(matches) == 1:
                        target = rows[matches[0]]
                        if not any(target.get("flags", {}).get(k) for k in ("isSidechain", "isMeta", "isCompactSummary", "isVisibleInTranscriptOnly")):
                            result["native_alias"] = (source, matches[0])
                    elif matches:
                        result["alias_ambiguous"] = True
            elif kind in ("user", "attachment"):
                # Extracted metadata does not universally distinguish user input
                # from tool results, notifications, or other non-deliveries.
                eligibility = event.get("eligible")
                result["class"] = "native_acceptance" if eligibility is True else "excluded" if eligibility is False else "ambiguous"
                if kind == "attachment":
                    pair = (ids.get("attachment.source_uuid"), ids.get("attachment.delivery_id"))
                    matches = removes.get(pair, []) if all(pair) else []
                    if len(matches) > 1 or (all(pair) and len(attachments[pair]) > 1):
                        result["alias_ambiguous"] = True
                    elif len(matches) == 1:
                        target = rows[matches[0]]
                        if not any(target.get("flags", {}).get(k) for k in ("isSidechain", "isMeta", "isCompactSummary", "isVisibleInTranscriptOnly")):
                            result["native_alias"] = (source, matches[0])
            else:
                result["class"] = "ignored"
            results[occurrence] = result
    return results


def counts(results):
    return dict(sorted(Counter(row["class"] for row in results.values()).items()))
