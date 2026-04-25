# Session Conformance Protocol

## Purpose

This contract defines the equivalence checkpoints and fixture classes that constitute
reproducible conformance evidence for `howl-session`. Conformance evidence demonstrates
that session behavior is deterministic, contract-bounded, and stable across runs.

## Checkpoint Definition

A conformance checkpoint is a deterministic snapshot of all contract-visible session state
captured at a defined moment. Two checkpoint captures from equivalent operations must
produce identical values.

### `Checkpoint` Fields

| Field | Type | Source |
| --- | --- | --- |
| `status` | `SessionStatus` | `session.status` |
| `cols` | `u16` | `session.cols` |
| `rows` | `u16` | `session.rows` |
| `resize_count` | `u32` | `session.resize_count` |
| `last_control_signal` | `?ControlSignal` | `session.last_control_signal` |
| `pending_len` | `usize` | `session.pending.items.len` (non-draining) |

`pending_len` is observed directly from the queue without consuming bytes.
`apply()` is reserved for behavioral tests; conformance capture does not drain.

## Checkpoint Timings

A fixture must capture a checkpoint:
- After `init` (baseline)
- After each operation under test
- After any error-path operation

Two runs of the same fixture with the same inputs must produce identical checkpoint sequences.

## Fixture Classes

### FC-1: Lifecycle Transitions

Covers: `init → start → stop → start (restart) → deinit`

Required checkpoints:
- After init: `status=idle, resize_count=0, last_control_signal=null`
- After start: `status=active`
- After stop: `status=stopped`
- After restart (start from stopped): `status=active`
- After failed start (AlreadyStarted): `status=active, unchanged`

### FC-2: Queue Capacity and Overflow

Covers: `feed (accumulate) → apply (drain) → reset → overflow`

Required checkpoints:
- After each feed: `pending_len` accumulates
- After apply: `pending_len=0`
- After reset: `pending_len=0`
- After overflow attempt: `pending_len` unchanged (atomic rejection)
- After exact-capacity feed: `pending_len == pending_capacity`

### FC-3: Resize and Control Sequencing

Covers: `resize (valid, repeated, same-dims, invalid) → control (all signals)`

Required checkpoints:
- After each valid resize: `cols`, `rows`, `resize_count` all advance
- After invalid resize: all three unchanged
- After failed resize (transport): `cols`, `rows`, `resize_count` advanced; error propagated
- After each control: `last_control_signal` updated

### FC-4: Failure-Boundary Behavior

Covers: transport failure on start and resize with `FailTransport`

Required checkpoints:
- After failed start: `status` unchanged from pre-call value
- After failed resize: `cols`, `rows`, `resize_count` committed; error returned
- After repeated failures: checkpoint sequence is deterministic across calls

### FC-5: Null vs Attached Transport Equivalence

Covers: session-state equivalence when transport is null vs attached

Required checkpoints:
- After start (null transport): `status=active`
- After start (MemTransport): `status=active`
- Session-side state must be identical; transport-side effects are additive only.

## Reproducibility Requirement

A conformance fixture is evidence only if:
1. It can be re-run and produce the same checkpoint sequence every time.
2. It uses only contract-visible fields (no internal queue pointers, vtable state, etc.).
3. It is not order-dependent on other fixtures (each fixture is self-contained).
