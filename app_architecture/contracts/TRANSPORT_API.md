# Transport API Contract

## Scope

This contract defines the host-neutral transport seam consumed by `howl-session`.
It does not define platform specifics (PTY, pipes, sockets, or OS APIs).
It does not define terminal semantics or rendering concerns.

## Ownership Boundaries

- `howl-session` consumes the transport seam; it does not own transport implementations.
- Concrete transport adapters (PTY, in-memory, pipe) implement this seam and are owned by host or platform layers.
- Session is decoupled from all platform specifics via this seam.

## Interface

The transport seam is expressed as a vtable-backed interface type (`Transport`) with an opaque pointer to the concrete implementation.
Session holds an optional `?Transport`; a null transport means no transport is attached.

## Types

### `TransportError`

Error values that transport operations may return:
- `AlreadyStarted` — start called on an already-running transport
- `NotStarted` — write/read/resize called before start
- `WriteFailed` — write operation rejected by transport
- `ReadFailed` — read operation rejected by transport
- `ResizeFailed` — resize notification rejected by transport

## Transport Boundaries

### start

- Signature: `start() anyerror!void`
- Activates the transport; subsequent write/read/resize/control calls are valid.
- Returns `error.AlreadyStarted` if called on an active transport.

### stop

- Signature: `stop() void`
- Deactivates the transport; no write/read/resize/control calls valid after stop returns.
- Idempotent on an already-stopped transport.

### write

- Signature: `write(bytes: []const u8) anyerror!usize`
- Delivers bytes from session to the transport peer.
- Returns count of bytes accepted; a partial write is a valid result.
- Call only valid on a started transport.

### read

- Signature: `read(buf: []u8) anyerror!usize`
- Reads bytes available from the transport peer into `buf`.
- Returns count of bytes read; returns 0 if no bytes are available (non-blocking).
- Call only valid on a started transport.

### resize

- Signature: `resize(cols: u16, rows: u16) anyerror!void`
- Delivers a terminal dimension change notification to the transport peer.
- Call only valid on a started transport.

### control

- Signature: `control(signal: ControlSignal) void`
- Routes a typed control signal to the transport peer.
- No terminal semantic reinterpretation; signal semantics are transport-defined.
- Call only valid on a started transport.

## Stop Conditions

Engineer must stop and report if any transport boundary requires:
- SDL or renderer types to express any parameter or return value.
- howl-terminal semantic changes to satisfy the transport contract.
