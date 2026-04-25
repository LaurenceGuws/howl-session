# Howl Session Boundary Authority

## Hard Boundaries

- Owns session lifecycle and transport orchestration only.
- Must expose host-neutral APIs (no SDL/window/renderer types).
- Consumes the terminal-core public API only; does not reach internals.

## Forbidden Coupling

- No rendering concerns in session runtime.
- No window/input toolkit ownership.
- No backend semantic rewrites for transport convenience.
