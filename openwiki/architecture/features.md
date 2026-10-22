---
type: Architecture
title: Design, footprint and features
description: Design goals, memory targets and feature behavior.
tags:
  - architecture
  - features
updated: 2026-10-16
---

# Design, footprint and features

## What Is This

A super-lean Windows workspace for prompting, monitoring, and coordinating multiple AI agents at once, written in Zig. It uses vertical session tabs and real native shells instead of rendering a terminal itself.

## Why

Windows Terminal adds ~30-50 MB overhead per instance. Raw cmd.exe is ~2-3 MB. When many AI-agent shells are open, that overhead adds up. multiprompt is a thin organizer around native console windows — it doesn't render terminal output; each shell does that itself.

## Core Design

```
┌──────────────┬─────────────────────────────────────────┐
│  Tab Sidebar │                                         │
│  (Zig Win32) │         cmd.exe window                  │
│              │         (reparented into right pane)     │
│ [> VPS SSH ] │                                         │
│ [ Claude    ]│  C:\Users\user\Documents\GitHub>_      │
│ [ Build     ]│                                         │
│ [ Tests     ]│                                         │
│              │                                         │
│  [+ New Tab] │                                         │
└──────────────┴─────────────────────────────────────────┘
```

### Architecture

- **Zig Win32 app** — one native window split into left sidebar + right content area
- **Left sidebar** — custom-drawn tab list with double-height rows for readable titles
- **Right pane** — hosts an actual cmd.exe window via Win32 `SetParent()` + `MoveWindow()`
- **No terminal rendering** — cmd.exe draws its own text natively, zero rendering code
- **Drag to reorder** — tabs can be moved up/down like browser tabs
- **Each tab click** — shows/hides the corresponding cmd.exe window

### Target Footprint

| Component | RAM |
|-----------|-----|
| multiprompt harness | ~500 KB - 1 MB |
| Per cmd.exe shell | ~2-3 MB (native) |
| 10 shells total | ~25-30 MB |
| vs Windows Terminal (10 tabs) | ~300-500 MB |

## Features

- **Sidebar mini-inbox** (v0.28.226): tab rows show the agent glyph (✳ Claude / ⬡ Codex / π Pi) left of the name, and by default auto-sort like the inbox — unread (blue dot) first, then actively-working, then recency = max(agent activity, YOUR last view of the tab) (v0.28.242 — switching to a tab bumps it within its tier, MRU-style, by user decision); groups move as blocks ranked by their most-urgent member. Dragging a tab or Ctrl+Shift+Up/Down materializes the displayed order and switches to Manual; Ctrl+K "Tab Order: Auto" / "Tab Order: Manual" toggles it (persisted as `tab_sort_auto`; the active mode is tagged `current` in the palette — v0.28.251 renamed "Inbox"->"Auto" for consistent naming).
- **Tmux adoption** (v0.28.236): start or attach tmux inside a plain VPS ssh tab and ~60s later the tab becomes a real tmux tab (session name + host adopted) — it restores as `tmux attach` after restarts and receives watcher notify events. Detach back to the plain prompt and the tab reverts to plain ssh ~90s later. Born-tmux tabs unaffected.
- **Dynamic tab naming**: Tabs auto-update names every 5s based on console title (Claude Code session names, running commands) or CWD. Manual renames (F2 or double-click) are sticky and override auto-detection; clear name to re-enable. PRECEDENCE (v0.28.250): manual (F2) renames are STICKY — Claude's DYNAMIC terminal auto-title (broadcast as TITLE: by the VPS watcher) refreshes the tab subject only on .default/.semantic tabs and NEVER clobbers a manual name. Hierarchy now: manual > dynamic auto-title (TITLE:) > ZigShell auto-name (cwd/console). The .247 flip that let TITLE: override manual was reverted (it wrongly treated Claude's evolving auto-title as an explicit /rename); explicit-/rename-overrides-manual via a transcript-customTitle RENAME: signal is a planned follow-up.
- **Activity spinner**: Green spinning indicator (◐◓◑◒) on tabs with active console output, detected via console screen buffer hashing (+ title change fallback).
- **Needs-input dot**: Blue dot appears on inactive tabs 10s after activity stops — means "this session likely needs your input." Not shown on the active tab. Cleared on tab switch.
- **Notifications**: TCP notifications on port 19547 also trigger attention state.
- **Multi-instance**: Run multiple ZigShell windows with `--name <instance>`. Each instance saves to its own session file (`session-{name}.json`). Default instance (no `--name` flag) uses `session.json` for backward compatibility. Instance name shown in title bar.
- **Auto-close tabs**: When a shell process exits (e.g. `exit` command), its tab is automatically removed.
- **Cross-workspace Inbox** (Ctrl+Shift+I): Superhuman-style triage view of every shell across all running ZigShell windows. Top tabs filter by workspace (`ALL` + one per window, each showing its needs-reply count); rows sort in 3 tiers (v0.28.227): unread (blue dot) first, then actively-working (spinner), then read/idle — recency within each tier, flat across workspaces; every row has a last-active timestamp (stamped at spawn, persisted per-tab as "la" in the session file) (splits filter by workspace; no grouping in ALL); stable ws/sid tiebreak prevents live-refresh jitter. `j`/`k` move, `Enter` jumps to the shell (focusing its own window cross-process), `h`/`l` switch workspace tab, `1-9` jump to a row, `Esc` closes. Each window publishes its shells to `%APPDATA%\ZigShell\inbox-<id>.json` (one file per window, no merge races) on every state change + a 30s heartbeat, deleted on clean exit; the inbox aggregates these files and drops any whose owning window is no longer alive. Cross-window jump uses `WM_APP_FOCUS_SHELL` (wParam = shell_id) + `AllowSetForegroundWindow`.

Favorites (Alt+1) has its own session groups using the existing group actions, independently of each session’s home workspace group.

## Future Features

- Bookmarkable shell configs (like `?cwd=&cmd=` URLs)
- Tray icon for background operation
