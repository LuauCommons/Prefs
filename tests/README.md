# Verification

From the repository root, run the dependency-free suite with the standalone
[Luau CLI](https://github.com/luau-lang/luau/releases):

```sh
luau tests/run.luau
```

On Windows, the helper works from any directory and returns the CLI exit code:

```powershell
powershell -ExecutionPolicy Bypass -File tests/run.ps1
# Or supply an explicit executable:
powershell -ExecutionPolicy Bypass -File tests/run.ps1 -LuauPath C:\tools\luau.exe
```

Every case prints `PASS` or `FAIL`. Any failure ends with an uncaught error and a
nonzero process exit code. A missing CLI exits with code 127 and explicitly says
that tests were not executed. Lua and LuaJIT are not substitutes for Luau.

The pure suite covers schema construction, validation boundaries, UTF-8,
defaults, mutation, saved-data normalization, attached-table identity and
unrelated fields, observer ordering and cleanup, permissions, and store lifetime.
It does not exercise Roblox networking or the task scheduler.

Run the [Studio fixture](studio/README.md) for actual RemoteFunction/RemoteEvent
creation, client/server requests, malicious payloads, replication, rate limiting,
duplicate requires, and player departure. A successful Rojo build verifies place
assembly only; it does not mean either test suite has run.

For the release installation smoke, run `scripts/build-release.ps1`, then
`scripts/build-smoke.ps1` (both accept `-Rojo`; the release script also accepts
`-Wally`). Open `dist/PrefsReleaseSmoke.rbxlx` in Studio and press Play. This
separate, clean place embeds the exact production model and canonical scripts
from `examples/Basic/`. Expect `Prefs release server:
8 passed, 0 failed`, `Prefs release client: 9 passed, 0 failed`, and
`Prefs runtime regressions: 7 passed, 0 failed` in Output. The verification
scripts are not shipped in the production model or Wally package.

`tests/runtime.spec.luau` uses deterministic transport stubs to test response
ordering, readiness, and cleanup. It runs automatically in the release smoke
place. To run it in another Studio fixture, import it as a ModuleScript and
call `require(testModule)(game.ReplicatedStorage.Packages.Prefs)` from a server
Script during Play. This suite requires Roblox; `tests/run.luau` is the
standalone CLI suite.
