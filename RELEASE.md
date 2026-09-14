# Maintainer release guide

Run this checklist for each release. Record version-specific results in the
GitHub release notes or a pull request, rather than editing this guide into a
verification log. A successful build assembles files; it does not run Roblox.

## Prepare

- Confirm `origin` is `https://github.com/LuauCommons/Prefs.git` and review the
  complete diff intended for release.
- Update the version in `wally.toml`, the changelog, and versioned installation
  examples together. Keep beta limitations explicit.
- Install the versions in `aftman.toml` with `aftman install`, or install those
  Rojo and Wally versions directly. Install the standalone Luau CLI version
  used by `.github/workflows/ci.yml`. Install the MkDocs Material dependency
  with `python -m pip install mkdocs-material`.

## Automated checks

Run from the repository root in PowerShell (PowerShell 7 also works on Linux):

```powershell
luau tests/run.luau
if ($LASTEXITCODE -ne 0) { throw 'Luau tests failed.' }

Get-ChildItem src, tests, examples -Recurse -Filter *.luau | ForEach-Object {
    luau-compile --only-parse $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "Syntax check failed: $($_.FullName)" }
}

python -m pip install mkdocs-material
if ($LASTEXITCODE -ne 0) { throw 'Documentation dependency installation failed.' }
python -m mkdocs build --strict
if ($LASTEXITCODE -ne 0) { throw 'Documentation build failed.' }

./scripts/build-release.ps1
./scripts/build-smoke.ps1
rojo build tests/studio/default.project.json -o dist/PrefsStudioTest.rbxlx
if ($LASTEXITCODE -ne 0) { throw 'Studio fixture build failed.' }
```

The build scripts accept `-Rojo` and, for `build-release.ps1`, `-Wally` if the
executables are not on PATH. All generated artifacts stay under ignored output
directories. Both CI workflows must be green for the release commit.

`build-release.ps1` produces `dist/Prefs.rbxm`, `dist/Prefs.rbxmx`, and
`dist/Prefs-<version>.zip`. It validates the Wally manifest, checks the production
XML hierarchy and source, checks the archive allowlist and source bytes, and
prints SHA-256 hashes. Wally's rewritten project name is checked separately
against the package name while preserving the production tree. The archive must
contain exactly:

```text
default.project.json
LICENSE
README.md
src/init.luau
src/Runtime.luau
src/Schema.luau
src/Store.luau
wally.toml
```

The production model must have one top-level `Prefs` ModuleScript with exactly
three direct ModuleScript children: `Runtime`, `Schema`, and `Store`. Tests,
examples, documentation, branding assets, and development tools are excluded.

## Test the exact artifacts in Studio

`build-smoke.ps1` builds `dist/PrefsReleaseSmoke.rbxlx` from the production
`Prefs.rbxm` and the canonical [Basic examples](examples/README.md). It compares
the installed module sources against `src/` and the production XML, and checks
every example/test script's source, class, and destination. It fails for stale
or structurally unexpected artifacts. README formatting is not an input.

- Open `dist/PrefsReleaseSmoke.rbxlx` in a fresh Studio session. Run Play and
  confirm the release server/client and runtime regression summaries report
  zero failures. Inspect Output for unexpected errors.
- Run Studio's Server & Clients mode with at least two players. Check the
  [integration fixture checklist](tests/studio/README.md), including isolation,
  adversarial requests, rate limiting, reconnect/detach behavior, and cleanup.
- In a separate empty place, insert the exact `dist/Prefs.rbxm` under
  `ReplicatedStorage.Packages`, copy the three Basic examples as documented, and
  confirm server and client observers run without creating remotes manually.
- Record the artifact SHA-256, Studio version, player count, and actual test
  results. Do not describe the smoke build as a passed Studio test. Rebuild and
  repeat the affected checks if any packaged file changes.

## Publish

Do not create the GitHub Release until every automated check is green and the
exact release model passes the Studio smoke test.

1. Commit the reviewed release contents and confirm CI passes for that commit.
2. Tag that commit `v<version>`. Create release notes from `CHANGELOG.md`, with
   tested installation methods, known limitations, and the artifact hashes.
   Mark pre-1.0 beta releases as prereleases.
3. Attach the verified `Prefs.rbxm`, `Prefs.rbxmx`, and versioned Wally archive.
4. Publish the same source snapshot using `wally publish` with an account that
   can publish under `luaucommons`. Never put registry credentials in the repo.
5. In an empty Wally project, add `Prefs = "luaucommons/prefs@<version>"`, run
   `wally install`, and verify the installed package through a consumer Rojo
   build. Confirm the GitHub model install still works without Rojo or Wally.
6. Check the live documentation and release download links. Report any remaining
   real-game validation needed before `1.0.0`; do not imply unrun checks passed.
