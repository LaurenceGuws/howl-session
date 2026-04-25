# Howl Session Active Queue

## Current State

`M2` refactor batch is complete.

Queue is open for `M3+` planning.

## Read Before Execution

- `app_architecture/authorities/SCOPE.md`
- `app_architecture/authorities/MILESTONE.md`
- `docs/architect/MILESTONE_PROGRESS.md`
- `app_architecture/contracts/TRANSPORT_API.md`
- `app_architecture/contracts/API.md`

## Completed Batch (M2-R)

| Ticket | Status | Commit | Intent |
| --- | --- | --- | --- |
| `M2-R1` | done | `0cc48b4` | Transport Topology Split: interface/mem/fail/unix_pty sub-modules under src/transport/. |
| `M2-R2` | done | `ada5d7f` | Session Topology Split: core/snapshot_restore/ops_counters sub-modules under src/session/. |
| `M2-R3` | done | `9d0a463` | Root/API Integrity and Wiring: facade wiring conformance tests added to root.zig. |
| `M2-R4` | done | `8b16b01` | Queue Closeout: hashes recorded, queue opened for M3+. |

## Guardrail

- One ticket per commit.
- Mandatory per-ticket validation:
  - `zig build`
  - `zig build test`
  - `rg -n "compat[^ib]|fallback|workaround|shim" --glob '*.zig' src`
  - `test ! -f src/main.zig`
  - `find src -maxdepth 1 -type f -name '*.zig' | rg -n 'src/(conformance|ops|perf|reliability|snapshot)\\.zig' || true`
