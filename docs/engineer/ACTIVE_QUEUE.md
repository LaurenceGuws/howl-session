# Howl Session Active Queue

## Current State

`M2` catch-up is active.

Queue is locked to `M2-*` execution only until PTY/process transport closure.

## Read Before Execution

- `app_architecture/authorities/SCOPE.md`
- `app_architecture/authorities/MILESTONE.md`
- `docs/architect/MILESTONE_PROGRESS.md`
- `app_architecture/contracts/TRANSPORT_API.md`
- `app_architecture/contracts/SESSION_API.md`

## Active Batch (M2-C)

| Ticket | Status | Commit | Intent |
| --- | --- | --- | --- |
| `M2-C1` | done | `0869a54` | Align M2 contract wording with actual seam-vs-PTY state. |
| `M2-C2` | done | `13b3cb4` | Implement Unix PTY/process transport adapter. |
| `M2-C3` | done | `1a01c2e` | Wire session lifecycle path required for PTY transport usage. |
| `M2-C4` | done | `a7e862a` | Add deterministic headless bash evidence tests (spawn/read/resize/stop). |
| `M2-C5` | done | `b79cdd6` | Publish M2 closeout evidence and queue update. |

## Guardrail

- No `M3+` commits until M2 catch-up is closed.
- One ticket per commit.
- Mandatory per-ticket validation:
  - `zig build`
  - `zig build test`
  - `rg -n "compat[^ib]|fallback|workaround|shim" --glob '*.zig' src`
