# Session Snapshot/Restore Contract

## Scope

This contract defines the snapshot payload, restore semantics, and deterministic guarantees
for in-process state capture and replacement in `howl-session`. No persistence format,
file I/O, cross-version compatibility, or external system integration is defined here.

## Snapshot Payload

A `SessionSnapshot` captures the contract-visible scalar session state at a point in time.

### Captured Fields

| Field | Type | Source |
| --- | --- | --- |
| `cols` | `u16` | `session.cols` |
| `rows` | `u16` | `session.rows` |
| `status` | `SessionStatus` | `session.status` |
| `resize_count` | `u32` | `session.resize_count` |
| `last_control_signal` | `?ControlSignal` | `session.last_control_signal` |

### Excluded from Snapshot

| Excluded | Policy |
| --- | --- |
| Pending queue bytes | Not captured; restore always clears the queue |
| Transport attachment | Not captured; restore leaves transport unchanged |
| Operational counters (`ops`) | Not captured; restore leaves counters unchanged |
| `pending_capacity` | Not captured; capacity is an init-time config invariant |
| Allocator | Not captured; owned by the session for its lifetime |

`snapshot()` is non-mutating. Calling it does not change any session state.

## Restore Semantics

`restore(snapshot)` replaces session state with the snapshot payload, subject to the
rules below.

### Full-State Replacement Rules

On a valid restore, the following fields are replaced atomically:
- `cols` ← `snapshot.cols`
- `rows` ← `snapshot.rows`
- `resize_count` ← `snapshot.resize_count`
- `last_control_signal` ← `snapshot.last_control_signal`
- `status` ← see Status Mapping below
- Pending queue ← cleared (`clearRetainingCapacity`; capacity unchanged)

No other fields are modified.

### Status Mapping on Restore

| Snapshot status | Restored status | Rationale |
| --- | --- | --- |
| `.idle` | `.idle` | Safe; no transport state implied |
| `.stopped` | `.stopped` | Safe; no transport state implied |
| `.active` | `.stopped` | Transport not restarted by restore; restoring to `active` would create an inconsistent lifecycle state |

Callers who need an active session after restore must call `start()` explicitly.

### Transport Handling on Restore

Restore does not call `transport.stop()`, `transport.start()`, or any other transport
method. The transport attachment is completely unchanged. If transport is attached and
running, it continues running after restore; if detached, it remains detached.

### Counter Handling on Restore

Operational counters (`session.ops`) are not modified by restore. They continue to
accumulate across restore calls. Restore is not treated as a counter-reset event.

### Invalid Snapshot Rejection

A snapshot is invalid if `cols == 0` or `rows == 0`.

On an invalid snapshot:
- `restore()` returns `error.InvalidSnapshot`.
- No session field is mutated. Session state is identical before and after the call.
- The check precedes all mutations, guaranteeing atomic rejection.

## Deterministic Guarantees

- `snapshot()` is a pure read of session fields. Two snapshots captured at the same
  session state are identical.
- `restore()` applied to a valid snapshot produces a deterministic post-restore state.
- Round-trip identity: for any valid snapshot `sn` taken from session `S`, calling
  `S.restore(sn)` yields a session whose contract-visible scalar fields match `sn`,
  with pending queue cleared.
- Restore is idempotent: applying the same snapshot twice yields the same result.

## Breaking-Change Rules

The following changes are breaking:

- Removing or renaming any captured field from `SessionSnapshot`.
- Changing a field's type to an incompatible type.
- Changing restore to modify transport attachment or operational counters.
- Changing invalid snapshot rejection to allow partial mutation.

The following changes are NOT breaking:

- Adding new optional fields to `SessionSnapshot` with defined defaults.
- Widening a field type (e.g., `u32` → `u64`).
- Adding new invalid snapshot conditions (additional validation is additive).

## Non-Goals

- No serialization format or binary encoding.
- No file I/O or network transport of snapshots.
- No cross-version snapshot compatibility.
- No snapshot versioning or schema migration.
- No cross-session snapshot transfer.
- No host-app or platform-specific snapshot storage policy.
