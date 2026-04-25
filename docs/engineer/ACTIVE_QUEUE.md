# Howl Session Active Queue

## Current State

`M3` Lifecycle Safety execution complete. Queue open for `M4+` planning.

## Read Before Execution

- `app_architecture/authorities/SCOPE.md`
- `app_architecture/authorities/MILESTONE.md`
- `docs/architect/MILESTONE_PROGRESS.md`
- `app_architecture/contracts/API.md`

## M2 + M3 Closure Batches

### M2-R (Topology Refactor)
| Ticket | Status | Commit | Intent |
| --- | --- | --- | --- |
| `M2-R1` | done | `0cc48b4` | Transport Topology Split |
| `M2-R2` | done | `ada5d7f` | Session Topology Split |
| `M2-R3` | done | `9d0a463` | Root/API Integrity and Wiring |
| `M2-R4` | done | `8b16b01` | Queue Closeout (refactor batch) |

### M2-C (PTY Closure)
| Ticket | Status | Commit | Intent |
| --- | --- | --- | --- |
| `M2-C1` | done | `e4594f4` | Unix PTY Contract Closure |
| `M2-C2` | done | `e272829` | Unix PTY Evidence Hardening |
| `M2-C3` | done | `93b4461` | M2 Closeout and Queue Advance |

### M3-A (Lifecycle Safety)
| Ticket | Status | Commit | Intent |
| --- | --- | --- | --- |
| `M3-A1` | done | `5ff6ce7` | Lifecycle Contract Closure |
| `M3-A2` | done | `b8f4aff` | Lifecycle Enforcement (verified in-place) |
| `M3-A3` | done | `(this commit)` | Lifecycle Evidence Tests + Queue Closeout |

## M4 Planning (Resize and Control Flow)

Pending queue definition. Next session:
1. Scope resize/control path determinism and contract
2. Define error boundaries for resize/control operations
3. Plan enforcement and evidence strategy

Guardrail: One ticket per commit. Mandatory validation per ticket:
- `zig build`
- `zig build test`
- `rg -n "compat[^ib]|fallback|workaround|shim" --glob '*.zig' src`
- `test ! -f src/main.zig`
- `find src -maxdepth 1 -type f -name '*.zig' | rg -n 'src/(conformance|ops|perf|reliability|snapshot)\.zig' || true`
