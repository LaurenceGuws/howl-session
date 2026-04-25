# Session Performance Contract

## Scope

This contract defines performance operation classes, the deterministic measurement
protocol, gate format, and allocation discipline for `howl-session`.
It covers only the in-process session runtime — no SDL, renderer, PTY, or host UI assumptions.

## Operation Classes

### Class A — Allocation-Eligible

Operations that may allocate on the first call or when the internal buffer grows:

| Operation | Allocation trigger |
| --- | --- |
| `init` | Baseline struct; pending queue starts empty (no allocation at init) |
| `feed(bytes)` | ArrayList growth when `pending.len + bytes.len` exceeds current capacity |

### Class B — Steady-State (Allocation-Free)

Operations that must not allocate once the session is warm (queue at stable capacity):

| Operation | Why allocation-free |
| --- | --- |
| `apply` | Clears queue in place (`clearRetainingCapacity`); no free or alloc |
| `reset` | Same as apply |
| `resize` | Pure field update + counter increment |
| `control` | Pure field update |
| `start` (null transport) | Pure field write |
| `stop` | Pure field write |

Class B operations must remain allocation-free across all contract-visible paths.
A Class B operation that allocates is a contract violation.

## Measurement Protocol

### Fixture Definition

Each performance fixture must specify:
- `pending_capacity`: fixed value (default 4096 bytes for queue fixtures)
- `payload_size`: fixed byte count for `feed` fixtures (default 64 bytes)
- `warmup_iters`: number of warm-up iterations before timing begins (default 10)
- `measure_iters`: number of timed iterations (default 100)

### Timing Unit

All measurements are in nanoseconds. Wall-clock monotonic timer (`CLOCK_MONOTONIC`).
Timer resolution is platform-dependent; ns granularity is assumed but not guaranteed.

### Sample Statistics

From `measure_iters` samples, report:
- `min_ns`: minimum observed nanoseconds
- `median_ns`: median (p50) observed nanoseconds
- `max_ns`: maximum observed nanoseconds

Median is the primary evidence metric. Min eliminates scheduling noise for best-case evidence.

### Gate Format

Gates are expressed as:
```
<operation> median_ns <= <threshold_ns>  // absolute gate
<operation> median_ns <= baseline * <factor>  // baseline-relative gate
```

M7 evidence tests enforce provisional absolute safety gates.
Frozen absolute gates are designated in a future milestone when reference hardware is selected.

The current M7 gate is:
- All Class B operations: `median_ns > 0` (measurement infrastructure works)
- All Class B operations: `median_ns < 1_000_000` (1ms; proves no hang or runaway)
- `feed(64 bytes)` steady-state: same bounds

## Allocation Discipline

- Class A operations: allocation is permitted; OOM must be surfaced as an error, not a panic.
- Class B operations: must not allocate in steady-state (warm queue, no capacity growth).
  - M7 evidence exercises Class B operations in steady-state loops.
  - M7 does not include explicit allocation-count assertions; this remains a contract requirement and is a target for stricter allocation instrumentation in a future milestone.
- No session operation may call `free` on data that is still reachable from the Session struct.

## Non-Goals

- No SDL/window/renderer latency claims.
- No PTY process spawn or I/O throughput claims.
- No cross-platform absolute timing guarantees.
- No host-app frame-budget claims.
- No claims about `howl-terminal` rendering performance.
