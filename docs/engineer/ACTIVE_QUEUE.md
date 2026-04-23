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

## M2-B Batch — DONE

| Ticket | Status | Commit |
| --- | --- | --- |
| M2-B1: Session lifecycle transport hooks (start/stop) | done | f71f9af |
| M2-B2: Wire resize and control through transport | done | a271282 |
| M2-B3: Integration tests and queue closeout | done | (this commit) |

## Outstanding

Awaiting architect publication of next batch.

Candidate next scope (not started, not decided):
- M3: Lifecycle Safety — startup/shutdown/restart/error boundaries explicit and tested.
