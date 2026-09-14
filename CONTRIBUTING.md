# Contributing to Prefs

Thanks for helping improve Prefs. Keep changes focused on the small, framework-independent preferences layer. New UI, keybind, migration, datastore, or additional Roblox datatype features belong in a separate proposal before implementation.

Before opening a pull request:

1. Run `powershell -ExecutionPolicy Bypass -File tests/run.ps1 -LuauPath .tools/luau/luau.exe` (or use `luau tests/run.luau` with Luau installed).
2. Build the production artifacts with `powershell -ExecutionPolicy Bypass -File scripts/build-release.ps1`.
3. Run the Studio fixture described in [`tests/studio/README.md`](tests/studio/README.md) when changing runtime or networking behavior.
4. Keep README examples synchronized with the public API and update `CHANGELOG.md` for user-visible fixes.

Pull requests should explain the behavior change, include focused tests for regressions, and avoid committing `dist/`, `.tools/`, or generated Roblox place files.
