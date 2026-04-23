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

## Lifecycle Boundaries

### init

- Caller provides allocator and configuration (opaque to host toolkit).
- Returns a `Session` handle.
- Does not start PTY, transport, or terminal engine; init only allocates and validates config.
- Error on invalid config; no partial-init state is observable.

### deinit

- Releases all session-owned resources.
- Caller must only call deinit on a successfully initialized session handle.
- Must be called exactly once per successful init.
- No callbacks fire after deinit returns.

## Feed / Apply / Reset Boundaries

### feed

- Signature: `feed(bytes: []const u8) error{OutOfMemory}!void`
- Caller delivers raw input bytes into the session.
- Session appends bytes to the in-memory pending queue; no terminal semantic interpretation.
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

- Caller delivers new terminal dimensions (columns × rows).
- Session propagates resize to transport and terminal engine.
- Dimensions must be non-zero; zero-dimension resize is a contract violation.
- Idempotent: resize to current dimensions is a no-op.

### control

- Signature: `control(signal: ControlSignal) void`
- Caller delivers a typed `ControlSignal` value.
- Session routes the signal to the transport layer only.
- No terminal semantic reinterpretation; signal semantics are transport-defined.
- Call only valid between init and deinit.

## Stop Conditions

Engineer must stop and report if any API boundary requires:
- howl-terminal semantic changes to satisfy the session contract.
- SDL or renderer types to express any session API parameter or return value.
