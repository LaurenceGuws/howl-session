# Howl Session Active Queue

## M1-A Batch — DONE (accepted after review)

| Ticket | Status | Commit |
| --- | --- | --- |
| M1-A1: Session API contract baseline | done | 8ee1a34 |
| M1-A2: Minimal session surface scaffold | done | 51988ee |
| M1-A3: Baseline tests + queue closeout | done | 426e897 |
| M1-A review fix | done | f3d065a |

## M1-B Batch — DONE (accepted after review)

| Ticket | Status | Commit |
| --- | --- | --- |
| M1-B1: Typed ControlSignal and SessionStatus primitives | done | dc94764 |
| M1-B2: In-memory pending queue for feed/apply | done | 59af601 |
| M1-B3: Contract tests for queue/reset/resize/control | done | b01833a |
| M1-B review fix | done | e4493be |

## M1-C Batch — DONE (accepted after review)

| Ticket | Status | Commit |
| --- | --- | --- |
| M1-C1: Queue capacity contract and config field spec | done | 3a363b9 |
| M1-C2: Bounded queue enforcement with QueueFull | done | 0b6a98b |
| M1-C3: Capacity tests + queue closeout | done | 20ae2e9 |
| M1-C review fix | done | b851cba |

## M2-A Batch — DONE (accepted after review)

| Ticket | Status | Commit |
| --- | --- | --- |
| M2-A1: Transport contract baseline | done | 2c7b098 |
| M2-A2: In-memory transport adapter scaffold | done | eb483b1 |
| M2-A3: Transport boundary tests + queue closeout | done | 6cb9455 |
| M2-A review fix | done | 695b496 |

## M2-B Batch — DONE (accepted after review)

| Ticket | Status | Commit |
| --- | --- | --- |
| M2-B1: Session lifecycle transport hooks (start/stop) | done | f71f9af |
| M2-B2: Wire resize and control through transport | done | a271282 |
| M2-B3: Integration tests and queue closeout | done | a0c0bd5 |
| M2-B review fix | done | 4adb009 |

## M3-A Batch — DONE (accepted, no review fix)

| Ticket | Status | Commit |
| --- | --- | --- |
| M3-A1: Lifecycle safety contract closure with state machine | done | 23ab51a |
| M3-A2: Enforce lifecycle state transitions | done | deb1ebd |
| M3-A3: Lifecycle transition tests + queue closeout | done | 57769a7 |

## M3-B Batch — DONE (accepted, no review fix)

| Ticket | Status | Commit |
| --- | --- | --- |
| M3-B1: Session error-boundary contract closure | done | 10b311f |
| M3-B2: Add FailTransport adapter for error-boundary enforcement | done | eafa3b2 |
| M3-B3: Failure-path tests + queue closeout | done | fb4a368 |

## M4-A Batch — DONE (accepted, no review fix)

| Ticket | Status | Commit |
| --- | --- | --- |
| M4-A1: Resize/control contract closure with sequencing guarantees | done | 6c61d64 |
| M4-A2: Add resize_count and last_control_signal observability fields | done | 0ac0824 |
| M4-A3: Resize/control observability integration tests + queue closeout | done | 22ec4e6 |

## M5-A Batch — DONE (accepted, no review fix)

| Ticket | Status | Commit |
| --- | --- | --- |
| M5-A1: Host-facing API freeze contract | done | ef4e4e4 |
| M5-A2: Root API conformance checks | done | b2dca6e |
| M5-A3: Readiness matrix + queue closeout | done | 143c317 |

## M6-A Batch — DONE (accepted after review fix)

| Ticket | Status | Commit |
| --- | --- | --- |
| M6-A1: Conformance protocol contract | done | a794a95 |
| M6-A2: Conformance checkpoint helper (test-only) | done | 676bdf0 |
| M6-A3: Fixture-class evidence tests + queue closeout | done | d4035df |
| M6-A review fix | done | 9666e2a |

## M7-A Batch — DONE

| Ticket | Status | Commit |
| --- | --- | --- |
| M7-A1: Session performance contract authority | done | cec30a3 |
| M7-A2: Test-only performance harness | done | 522dd4e |
| M7-A3: Baseline evidence tests + queue closeout | done | 93ef7f4 |

## M8-A Batch — DONE

| Ticket | Status | Commit |
| --- | --- | --- |
| M8-A1: Session reliability contract authority | done | cae661c |
| M8-A2: Test-only reliability harness | done | 3bb33e8 |
| M8-A3: Reliability evidence tests + queue closeout | done | 6f95b4f |

## Outstanding

Awaiting architect publication of next batch.

Candidate next scope (not started, not decided):
- M9: Operational Surface — observability hooks, metrics emission, or structured event logging for production runtime visibility.
