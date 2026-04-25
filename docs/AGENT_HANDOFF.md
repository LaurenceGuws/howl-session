# Howl Session Agent Handoff

## Current Focus

Maintain a strict, unambiguous topology baseline while executing milestone work.
No scaffold residue, no mixed-purpose naming, and no test-support helpers in `src/` root.

## Read Order

1. `app_architecture/authorities/SCOPE.md`
2. `app_architecture/authorities/MILESTONE.md`
3. `app_architecture/authorities/BOUNDARIES.md`
4. `app_architecture/authorities/NON_GOALS.md`
5. `docs/architect/WORKFLOW.md`
6. `docs/engineer/ACTIVE_QUEUE.md`
7. `docs/engineer/REPORT_CHECKLIST.md`

## Hard Constraints

- `src/` root is for product-facing entry surfaces only.
- test-only helper modules live under `src/test_support/` only.
- no `src/main.zig` scaffold executable in this package.
- handovers and reviews must enforce topology and symbol-name clarity before accepting a batch.
