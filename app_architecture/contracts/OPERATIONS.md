# Session Operations Contract

## Scope

This contract defines the operational observability surface for `howl-session`.
It covers in-process, host-neutral counters only. No external telemetry backend,
async pipeline, logging framework, or host-app policy is defined here.

## Counter Taxonomy

Operational counters are grouped by operation class. All counters are unsigned integers
initialized to zero at `init()` and accumulated monotonically until `deinit()`.

### Lifecycle Counters

| Counter | Type | Meaning |
| --- | --- | --- |
| `start_attempts` | `u32` | Incremented at every `start()` call entry, regardless of outcome |
| `start_successes` | `u32` | Incremented when `start()` transitions session to `active` |
| `start_failures` | `u32` | Incremented when `start()` propagates a transport error |
| `stop_calls` | `u32` | Incremented at every `stop()` call entry, regardless of prior state |

Note: `start_attempts - start_successes - start_failures` equals the count of
`AlreadyStarted` rejections (calls to `start()` from `active` state).

### Queue Counters

| Counter | Type | Meaning |
| --- | --- | --- |
| `feed_accepted` | `u32` | Incremented when `feed()` successfully appends bytes |
| `feed_rejected` | `u32` | Incremented when `feed()` returns `QueueFull` |
| `bytes_fed` | `u64` | Cumulative byte count accepted across all successful `feed()` calls |
| `bytes_applied` | `u64` | Cumulative byte count consumed across all `apply()` calls |
| `apply_calls` | `u32` | Incremented at every `apply()` call entry, including empty-queue calls |
| `reset_calls` | `u32` | Incremented at every `reset()` call entry |

Note: `feed()` returning `OutOfMemory` is an allocator failure; it does not
increment `feed_rejected` (which is reserved for capacity-overflow rejections).

### Resize/Control Counters

| Counter | Type | Meaning |
| --- | --- | --- |
| `resize_valid_calls` | `u32` | Incremented after `resize()` commits valid dimensions and increments `resize_count` |
| `resize_invalid_calls` | `u32` | Incremented when `resize()` returns `InvalidDimensions` (zero-dimension rejection) |
| `resize_transport_errors` | `u32` | Incremented when `resize()` propagates a transport error (dims already committed) |
| `control_calls` | `u32` | Incremented at every `control()` call entry |

## Increment Semantics

Each counter increment is deterministic given the same operation sequence:

- `start_attempts`: increments unconditionally at `start()` entry (before any branch).
- `start_successes`: increments after status is set to `active` (success path only).
- `start_failures`: increments after a transport error is propagated (not for `AlreadyStarted`).
- `stop_calls`: increments unconditionally at `stop()` entry.
- `feed_accepted`: increments after bytes are appended; `bytes_fed` increases by `bytes.len`.
- `feed_rejected`: increments on `QueueFull` return; no bytes are written.
- `apply_calls`: increments at `apply()` entry; `bytes_applied` increases by the drain count.
- `reset_calls`: increments at `reset()` entry.
- `resize_valid_calls`: increments after `cols`, `rows`, and `resize_count` are committed.
- `resize_invalid_calls`: increments on `InvalidDimensions` return; no session state changes.
- `resize_transport_errors`: increments after transport error is propagated; dims already committed.
- `control_calls`: increments unconditionally at `control()` entry.

## Reset Semantics

Operational counters are:
- **Zeroed** at `init()`.
- **Accumulated** monotonically across all lifecycle transitions (`start`, `stop`, restart).
- **Not reset** by `stop()`, `reset()`, `apply()`, or any transport failure.
- **Released** (no longer accessible) after `deinit()`.

There is no explicit counter-reset operation. Counters represent session lifetime totals.

## Breaking-Change Rules

The following changes to the operational surface are breaking:

- Removing or renaming any counter field from `SessionOps`.
- Changing a counter's type to a narrower type (e.g., `u64` → `u32`).
- Changing when a counter increments in a way that invalidates prior accounting.
- Moving counters out of `Session.ops` into a separate allocation.

The following changes are NOT breaking:

- Adding new counter fields to `SessionOps`.
- Widening a counter's type (e.g., `u32` → `u64`).
- Adding new operation classes to this contract.

## Non-Goals

- No external telemetry backends (no Prometheus, StatsD, OpenTelemetry, etc.).
- No async counter emission or observer callbacks.
- No host-logger coupling; counters are readable fields only.
- No per-transport or per-session aggregation across multiple sessions.
- No PTY, SDL, renderer, or host-app timing counters.
- No explicit counter-reset operation on live sessions.
