# Howl Session Active Queue

## Current State

`M3` entry and planning phase is active.

## Read Before Execution

- `app_architecture/authorities/SCOPE.md`
- `app_architecture/authorities/MILESTONE.md`
- `docs/architect/MILESTONE_PROGRESS.md`
- `app_architecture/contracts/TRANSPORT_API.md`
- `app_architecture/contracts/API.md`

## M2 Closure Batch (M2-R + M2-C)

| Ticket | Status | Commit | Intent |
| --- | --- | --- | --- |
| `M2-R1` | done | `0cc48b4` | Transport Topology Split |
| `M2-R2` | done | `ada5d7f` | Session Topology Split |
| `M2-R3` | done | `9d0a463` | Root/API Integrity and Wiring |
| `M2-R4` | done | `8b16b01` | Queue Closeout (refactor batch) |
| `M2-C1` | done | `e4594f4` | Unix PTY Contract Closure |
| `M2-C2` | done | `e272829` | Unix PTY Evidence Hardening |
| `M2-C3` | done | `(this commit)` | M2 Closeout and Queue Advance |

## M3 Entry (Lifecycle Safety)

| Ticket | Status | Intent |
| --- | --- | --- |
| `M3-P1` | pending | Planning: Startup/shutdown/restart/error boundary scope definition |
| `M3-P2` | pending | Planning: Explicit lifecycle state machine contract documentation |
| `M3-P3` | pending | Planning: Error-path recovery and failure mode boundaries |

Guardrail: One ticket per commit. Mandatory validation per ticket:
- `zig build`
- `zig build test`
- `rg -n "compat[^ib]|fallback|workaround|shim" --glob '*.zig' src`
- `test ! -f src/main.zig`
- `find src -maxdepth 1 -type f -name '*.zig' | rg -n 'src/(conformance|ops|perf|reliability|snapshot)\.zig' || true`
