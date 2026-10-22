# AGENTS.md

Guidance for coding agents working on WhisperLatch. Read `README.md` first.

## Invariants (never break)

- The solution/secret of a puzzle lives only in server memory (`Puzzle.secret`).
  It must never reach the Tinkerer, a replicated instance, a `ReplicatedStorage`
  module, a Value object or a broadcast. Only `RoleViewFactory.seerView` may
  derive client data from it, and that view goes to the Seer only.
- `src/server/rooms` is server-only. Never map it into a replicated container.
- Server -> client traffic uses `FireClient` with role-specific views only;
  never `FireAllClients`.
- Every client request is untrusted: parse it in `ActionGateway`, then let
  `SessionManager` check membership, role, room, status, revision and cooldown.
- Only the Tinkerer may change controls. Hints are generic text and never
  contain parts of a solution.
- No free-text chat systems, no voice requirements, no timed death traps.

## Layout

```text
src/shared   ReplicatedStorage.Shared    protocol types, glyphs, pings, world names
src/server   ServerScriptService.Server  Main.server, logic/, rooms/, services/
src/client   StarterPlayerScripts.Client Main.client, Net, ui/, world/
tests        Lune specs (*.spec.luau) and helpers
scripts      Lune runners: test.luau, smoke.luau, lib/FakeTree.luau
```

Pure modules (`logic/`, `rooms/`, `SessionManager`, `RoleViewFactory`,
`PairingService`, `ActionGateway`, `HintService`, `ProgressService`) must not use
Roblox APIs or yield; time, randomness, transport and world effects are
injected. Roblox-specific code lives in `Main.server.luau`, `ChamberService`
and the client.

## Commands

```sh
stylua --check src tests scripts
selene src tests
lune run scripts/test.luau       # unit + contract tests (optional filter arg)
lune run scripts/smoke.luau      # builds world + UI with Lune's Roblox instances
rojo build default.project.json --output build/whisperlatch.rbxlx
```

All five must pass before committing.

## Adding a room

1. Create `src/server/rooms/<Name>.luau` returning a `PuzzleTypes.RoomDefinition`
   (`create`, `seerClue`, `evaluate`, hints, texts). Keep state small and finite.
2. Add it to `src/server/rooms/init.luau`.
3. Add a case to `tests/helpers/Solver.luau`. The generic tests then check that
   fresh puzzles are unsolved, the solution is accepted, and the Tinkerer view
   is independent of the secret.
4. If it needs a new control layout, extend `client/ui/ControlPanel.luau`; for
   a new clue shape, extend `Types.SeerClue` and `client/ui/CluePanel.luau`.

## Style

Strict Luau (`--!strict`), tabs, StyLua formatting, `require(script.Parent.X)`
instance requires. Code and comments in English, player-facing text in German.
