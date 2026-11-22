
from __future__ import annotations

import argparse
import asyncio
import json
import re
import sys
import time
from collections.abc import Mapping, Sequence
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

def _number(value: Any) -> float | None:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return number if number == number else None


def _timestamp(data: Mapping[str, Any]) -> str | None:
    for key in ("reset_at", "resetAt", "reset_time", "resetTime"):
        value = data.get(key)
        if not value:
            continue
        try:
            normalized = str(value).replace("Z", "+00:00")
            parsed = datetime.fromisoformat(normalized)
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=UTC)
            return parsed.astimezone(UTC).isoformat().replace("+00:00", "Z")
        except ValueError:
            continue

    for key in ("reset_in", "resetIn", "ttl"):
        seconds = _number(data.get(key))
        if seconds is not None and seconds > 0:
            return (datetime.now(UTC) + timedelta(seconds=seconds)).isoformat().replace("+00:00", "Z")
    return None


def _limit_label(
    item: Mapping[str, Any],
    detail: Mapping[str, Any],
    window: Mapping[str, Any],
    index: int,
) -> str:
    for source in (detail, item, window):
        for key in ("name", "title", "label"):
            if source.get(key):
                return str(source[key])
    duration = _number(window.get("duration") or item.get("duration") or detail.get("duration"))
    unit = str(window.get("timeUnit") or item.get("timeUnit") or detail.get("timeUnit") or "").lower()
    if duration is not None and unit:
        return f"{duration:g}-{unit.lower()} limit"
    return f"Kimi limit {index + 1}"


def _window_minutes(
    item: Mapping[str, Any],
    detail: Mapping[str, Any],
    window: Mapping[str, Any],
    label: str,
) -> int | None:
    duration = _number(window.get("duration") or item.get("duration") or detail.get("duration"))
    unit = str(
        window.get("timeUnit") or item.get("timeUnit") or detail.get("timeUnit") or ""
    ).upper()
    if duration is not None and duration > 0:
        if "MINUTE" in unit:
            return round(duration)
        if "HOUR" in unit:
            return round(duration * 60)
        if "DAY" in unit:
            return round(duration * 1440)
        if "WEEK" in unit:
            return round(duration * 10080)
        if "MONTH" in unit:
            return round(duration * 43200)
        if unit in {"SECOND", "SECONDS", "S"}:
            return round(duration / 60)

    normalized = label.lower()
    if "month" in normalized:
        return 43200
    if "week" in normalized or "7-day" in normalized or "7 day" in normalized:
        return 10080
    hour_match = re.search(r"\b(\d+)\s*h(?:our)?", normalized)
    if hour_match:
        return int(hour_match.group(1)) * 60
    day_match = re.search(r"\b(\d+)\s*(?:d|day)", normalized)
    if day_match:
        return int(day_match.group(1)) * 1440
    return None


def _quota_row(
    data: Mapping[str, Any],
    *,
    label: str,
    item: Mapping[str, Any] | None = None,
    window: Mapping[str, Any] | None = None,
    index: int,
) -> dict[str, Any] | None:
    item = item or data
    window = window or {}
    limit = _number(data.get("limit"))
    used = _number(data.get("used"))
    remaining = _number(data.get("remaining"))
    if used is None and remaining is not None and limit is not None:
        used = limit - remaining
    if used is None and limit is None:
        return None
    used = used or 0
    used_percent = used / limit * 100 if limit and limit > 0 else 0
    return {
        "id": f"kimi-{index}",
        "label": str(data.get("name") or data.get("title") or label),
        "usedPercent": max(0, min(100, round(used_percent, 1))),
        "resetsAt": _timestamp(data) or _timestamp(item),
        "windowMinutes": _window_minutes(item, data, window, label),
    }


def normalize_payload(payload: Mapping[str, Any]) -> dict[str, Any]:
    quotas: list[dict[str, Any]] = []
    usage = payload.get("usage")
    if isinstance(usage, Mapping):
        row = _quota_row(usage, label="Weekly limit", index=0)
        if row:
            quotas.append(row)

    limits = payload.get("limits")
    if isinstance(limits, Sequence) and not isinstance(limits, (str, bytes)):
        for index, raw_item in enumerate(limits, start=1):
            if not isinstance(raw_item, Mapping):
                continue
            detail_value = raw_item.get("detail")
            detail = detail_value if isinstance(detail_value, Mapping) else raw_item
            window_value = raw_item.get("window")
            window = window_value if isinstance(window_value, Mapping) else {}
            label = _limit_label(raw_item, detail, window, index - 1)
            row = _quota_row(
                detail,
                label=label,
                item=raw_item,
                window=window,
                index=index,
            )
            if row:
                quotas.append(row)

    deduplicated: list[dict[str, Any]] = []
    seen: set[tuple[Any, ...]] = set()
    for row in quotas:
        identity = (
            row["label"].lower(),
            row["usedPercent"],
            row["resetsAt"],
            row["windowMinutes"],
        )
        if identity in seen:
            continue
        seen.add(identity)
        deduplicated.append(row)

    plan = payload.get("plan") or payload.get("membership") or payload.get("subscription")
    if isinstance(plan, Mapping):
        plan = plan.get("name") or plan.get("title") or plan.get("type")
    return {
        "plan": str(plan) if isinstance(plan, (str, int, float)) else "Kimi Membership",
        "quotas": deduplicated,
    }


async def read_usage(config_file: Path | None) -> dict[str, Any]:
    from kimi_cli.auth.oauth import OAuthError, load_tokens, refresh_token, save_tokens
    from kimi_cli.config import load_config
    from kimi_cli.ui.shell.usage import _fetch_usage, _usage_url

    config = load_config(config_file)
    model = config.models.get(config.default_model)
    if model is None:
        raise RuntimeError("No default Kimi model is configured. Run `kimi login`.")
    provider = config.providers.get(model.provider)
    if provider is None or provider.oauth is None:
        raise RuntimeError("Kimi Code OAuth is not configured. Run `kimi login`.")
    usage_url = _usage_url(model)
    if not usage_url:
        raise RuntimeError("The default Kimi model is not backed by a Kimi membership.")

    stored = load_tokens(provider.oauth)
    if stored is None:
        raise RuntimeError("Kimi login is missing. Run `kimi login`.")
    if stored.refresh_token and (
        not stored.expires_at or stored.expires_at <= time.time() + 120
    ):
        try:
            stored = await refresh_token(stored.refresh_token)
        except OAuthError as error:
            raise RuntimeError("Kimi login expired. Run `kimi login` again.") from error
        save_tokens(provider.oauth, stored)

    try:
        payload = await _fetch_usage(usage_url, stored.access_token)
    except Exception as error:
        status = getattr(error, "status", None)
        if status == 401:
            raise RuntimeError("Kimi login expired. Run `kimi login` again.") from error
        raise RuntimeError(f"Kimi usage request failed: {error}") from error
    return normalize_payload(payload)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config-file", type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(asyncio.run(read_usage(args.config_file)), separators=(",", ":")))
        return 0
    except Exception as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
