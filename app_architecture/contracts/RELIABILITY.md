# Session Reliability Contract

## Scope

This contract defines reliability invariants for the in-process `howl-session` runtime.
Reliability evidence demonstrates that contract-visible session state does not drift,
accumulate errors, or produce inconsistent snapshots across repeated operation cycles.
No PTY, SDL, host-UI, or renderer claims are made.

## Reliability Invariants

### R-1: Start/Stop Cycle Stability

After any number of valid start/stop cycles, session state must satisfy:
- `status == .stopped` after each completed cycle
- `cols`, `rows`, `pending_len`, `resize_count`, `last_control_signal` are unchanged between consecutive end-of-cycle checkpoints unless explicitly modified
- Transport delegation must not accumulate state if `stop()` is called after each `start()`

**Pass criterion**: checkpoint at end of cycle K equals checkpoint at end of cycle 1 for all stable fields.
**Stop condition**: any field drift not caused by the test fixture operations.

### R-2: Error-Path Retry Stability

After any number of failed `start()` attempts (transport always returns error), session state must satisfy:
- `status` remains at its pre-attempt value (`idle` or `stopped`) throughout
- All other fields remain unchanged

**Pass criterion**: checkpoint after attempt K equals checkpoint after attempt 1.
**Stop condition**: any state mutation caused by a failed start().

### R-3: Queue Pressure at Capacity

After N feed→apply cycles where each cycle fills the queue to capacity then drains it:
- `pending_len == 0` after each apply
- `pending_capacity` is unchanged
- Feed/apply cycle count does not affect `resize_count`, `last_control_signal`, `status`, `cols`, `rows`

**Pass criterion**: `pending_len == 0` after every apply; non-queue fields unchanged across cycles.
**Stop condition**: any queue state that does not return to zero after apply.

### R-4: Resize/Control Churn Stability

After N resize+control cycles starting from `resize_count == R` and last signal `S`:
- `resize_count == R + N` (wrapping)
- `last_control_signal == S` (last signal sent each cycle)
- `cols`, `rows` reflect the last resize applied
- `status`, `pending_len` unchanged

**Pass criterion**: `resize_count` advances by exactly 1 per cycle; all other non-advancing fields are stable.
**Stop condition**: `resize_count` deviates from `initial + N` (wrapping).

## Measurement Protocol

### Cycle Counts

| Test class | Cycles | Rationale |
| --- | --- | --- |
| R-1 start/stop | 1000 | exercises lifecycle code path at volume |
| R-2 error-path retry | 1000 | exercises failure path without state mutation |
| R-3 queue pressure | 1000 | exercises allocator under repeated capacity stress |
| R-4 resize/control churn | 1000 | exercises observability field correctness at volume |

Warmup: 10 cycles before checkpoint assertions begin.

### Determinism Requirement

All reliability tests must be:
- Input-deterministic: same byte payloads, signals, and dimensions every iteration
- Order-independent: each test is fully self-contained
- Timing-independent: pass/fail based on state values only, never on elapsed time

## Non-Goals

- No cross-session or concurrent session reliability claims
- No PTY/process spawn reliability claims
- No SDL event loop reliability claims
- No host-app memory ownership claims beyond what `deinit` already guarantees
