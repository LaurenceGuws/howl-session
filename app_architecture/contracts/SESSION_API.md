# Session API Contract

## Scope

This contract defines lifecycle and ownership boundaries for `howl-session`.
It does not define SDL types, renderer types, or terminal semantics.

## Types

### `ControlSignal`

Typed enum of control signals routable to the transport layer:
- `hangup` — transport peer disconnect equivalent (SIGHUP)
- `interrupt` — interrupt signal equivalent (SIGINT)
- `terminate` — graceful termination equivalent (SIGTERM)
- `resize_notify` — window resize notification (SIGWINCH)

### `SessionStatus`

Typed enum of observable session states:
- `idle` — session initialized, no active transport
- `active` — transport running
- `stopped` — transport stopped; session awaiting deinit or restart

## Ownership Boundaries

- `howl-session` owns session lifecycle and transport orchestration.
- `howl-terminal` owns terminal semantics; session consumes its public API only.
- Host apps own SDL/window/input/renderer concerns; session is host-neutral.

## Config Fields

| Field | Type | Constraint | Meaning |
| --- | --- | --- | --- |
| `allocator` | `std.mem.Allocator` | required | Allocator for all session-owned memory |
| `cols` | `u16` | non-zero | Initial terminal width in columns |
| `rows` | `u16` | non-zero | Initial terminal height in rows |
| `pending_capacity` | `usize` | non-zero | Maximum byte capacity of the in-memory pending queue |

## State Machine

```
init
 │
 ▼
idle ──start()──► active ──stop()──► stopped
                              ▲          │
                              └─start()──┘
                              (restart)

Any state ──deinit()──► (destroyed)
```

### Allowed Transitions

| From | Event | To | Notes |
| --- | --- | --- | --- |
| `idle` | `start()` | `active` | normal activation |
| `active` | `start()` | `active` | returns `error.AlreadyStarted`; no state change |
| `active` | `stop()` | `stopped` | normal deactivation |
| `idle` | `stop()` | `stopped` | safe; transport not called |
| `stopped` | `stop()` | `stopped` | idempotent; transport not called |
| `stopped` | `start()` | `active` | restart; transport.start() is called |
| any | `deinit()` | (destroyed) | only on successfully initialized handle |

### Repeated Call Behavior

- `start()` from `active`: returns `error.AlreadyStarted`; transport is not called.
- `stop()` from `idle` or `stopped`: sets status to `stopped`; transport is not called.
- `start()` from `stopped`: restart path; transport.start() is called; transitions to `active` on success.
- `feed/apply/reset`: valid in any state between init and deinit; no status check.
- `control`: valid in any state between init and deinit; routes to transport if attached.

## Lifecycle Boundaries

### init

- Caller provides allocator and configuration (opaque to host toolkit).
- Returns a `Session` handle.
- Does not start PTY, transport, or terminal engine; init only allocates and validates config.
- Error on invalid config (`cols == 0`, `rows == 0`, or `pending_capacity == 0`); no partial-init state is observable.
- Post-condition: `status == .idle`.

### start

- Signature: `start() anyerror!void`
- From `idle` or `stopped`: activates session; delegates to `transport.start()` if attached.
- From `active`: returns `error.AlreadyStarted` immediately; transport is not called; status unchanged.
- On success, `status` transitions to `active`.
- If transport start fails, the error is propagated and `status` remains unchanged.

### stop

- Signature: `stop() void`
- From `active`: deactivates session; delegates to `transport.stop()`.
- From `idle` or `stopped`: transport is not called; `status` transitions to `stopped`.
- `status` always transitions to `stopped` on return.
- Idempotent when already `stopped`.

### deinit

- Releases all session-owned resources.
- Caller must only call deinit on a successfully initialized session handle.
- Must be called exactly once per successful init.
- No callbacks fire after deinit returns.

## Feed / Apply / Reset Boundaries

### feed

- Signature: `feed(bytes: []const u8) error{OutOfMemory, QueueFull}!void`
- Caller delivers raw input bytes into the session.
- Session appends bytes to the in-memory pending queue; no terminal semantic interpretation.
- Overflow check is atomic: if `pending.len + bytes.len > pending_capacity`, returns `error.QueueFull` and no bytes are written.
- Returns `error.OutOfMemory` if queue allocation fails; caller must handle.
- Call only valid between init and deinit; calling outside this window is a contract violation.

### apply

- Signature: `apply() usize`
- Drains the in-memory pending queue in full; no partial application.
- Returns count of bytes consumed; returns 0 if queue was empty.
- Caller drives apply; session does not self-trigger application.

### reset

- Signature: `reset() void`
- Clears the in-memory pending queue; no terminal engine state is modified.
- Safe to call at any point between init and deinit.

## Resize / Control Boundaries

### resize

- Signature: `resize(cols: u16, rows: u16) anyerror!void`
- Dimensions must be non-zero; zero-dimension resize returns `error.InvalidDimensions` and no state changes.

**Sequencing guarantee:**
1. `cols` and `rows` are updated on the session (authoritative).
2. `resize_count` is incremented (wrapping) to mark a new resize epoch.
3. Transport is notified via `transport.resize()` if attached.

- Steps 1 and 2 occur unconditionally for any valid (non-zero) resize call; transport failure does not roll them back.
- A resize to the same current dimensions still increments `resize_count` and notifies transport.
- Transport errors are propagated; the session dims and counter are already committed.

### control

- Signature: `control(signal: ControlSignal) void`
- Caller delivers a typed `ControlSignal` value.

**Sequencing guarantee:**
1. `last_control_signal` is updated on the session.
2. Transport is notified via `transport.control()` if attached.

- Step 1 always occurs; transport attachment is not required for the session to record the signal.
- Fire-and-forget: no error channel; transport.control() is void.
- No terminal semantic reinterpretation; signal semantics are transport-defined.

## Observability Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `resize_count` | `u32` | Increments (wrapping) on every valid resize call; zero at init |
| `last_control_signal` | `?ControlSignal` | Last control signal delivered to session; null at init |

## Error Boundaries

### start() transport failure

- If `transport.start()` returns an error, the error is propagated to the caller.
- `status` remains unchanged (does not transition to `active`).
- The session is left in a consistent state; retry via `start()` is valid.

### resize() transport failure

- If `transport.resize()` returns an error, the error is propagated to the caller.
- Session `cols` and `rows` are retained at the new values; session dims are authoritative regardless of transport outcome.
- Caller receives the transport error as evidence of notification failure, not a dimension rejection.

### read/write delegation (future)

- When session gains explicit read/write delegation, failure post-conditions will follow the same pattern: propagate error, leave session queue state unchanged.
- Placeholder: no session queue mutation occurs on a failed delegation.

## Stop Conditions

Engineer must stop and report if any API boundary requires:
- howl-terminal semantic changes to satisfy the session contract.
- SDL or renderer types to express any session API parameter or return value.
