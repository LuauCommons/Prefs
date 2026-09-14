# Prefs Studio integration fixture

This fixture runs the real Roblox server/client transport against the V1 package. It is intentionally a small `Rojo` project: the server script attaches a malformed saved-data table, checks reconciliation and preservation, and exercises server operations; the client script waits for the replicated snapshot, performs valid and malicious requests, verifies permissions and replication, and floods a volume slider to verify rate limiting.

The fixture's shared schema intentionally marks `SprintMode` as client-writable so the client test covers a valid enum write. `ServerFlag` remains server-only for permission checks.

## Run in Roblox Studio

1. Install [Rojo](https://rojo.space) and ensure the `rojo` command is on your path.
2. From the repository root, run:

   ```text
   rojo serve tests/studio/default.project.json
   ```

3. Open Roblox Studio, create/open an empty Baseplate, and connect the Rojo plugin to the running serve session. Alternatively build a place file with `rojo build tests/studio/default.project.json -o PrefsStudioFixture.rbxlx` and open it in Studio.
4. Start **Play** (use **Start Server** with one or more players for the clearest output). Inspect the **Server** and **Client** Developer Console logs for `[Prefs fixture] PASS` lines.
5. Stop the session to run `BindToClose` checks. To verify `PlayerRemoving` independently, use **Start Server**, start one player, then stop that player/client while leaving the server running; the server console should print the automatic detach and observer-cleanup PASS lines.

The fixture does not use ProfileStore; its `settings` table stands in for `profile.Data.Settings`. Replace that table with a ProfileStore-owned table when integrating into a game.

## Checks covered

- Shared module duplicate requires and duplicate `Request`/`Changed` remotes
- Independent secondary schema runtime (isolated data, remotes, serialization, and duplicate requires)
- Existing malformed values: out-of-range numbers, wrong types, and invalid enums reset to defaults
- Newly introduced defaults are added while unrelated attached fields remain unchanged
- Server `Get`, `Set`, `Toggle`, `Reset`, `ResetAll`, `Load`, `Serialize`, and `Observe`, plus automatic `PlayerRemoving` detach
- Client confirmation/replication and observer callbacks
- Observer callback errors are isolated from value commits
- Out-of-order stale revision packets are ignored by the client cache
- Acceptance of a client-writable enum and rejection of non-client-writable, unknown, malformed, and server-only requests
- Rejection of NaN, positive infinity, negative infinity, and out-of-range numbers
- Rate limiting for rapid number updates (volume-slider pattern)
- Player and observer cleanup
- Server detach/re-attach with client readiness recovery

The script summaries include `PASS_COUNT` and `FAIL_COUNT` so a run can be recorded precisely. Non-finite number checks require a successful RemoteFunction transport and the server's `expected finite number` validation response; a transport error is treated as a failed check.

Normalization is deterministic: a stored value is preserved only when it passes the current schema validator. Missing, wrong-type, invalid UTF-8 string, non-finite, out-of-range, or disallowed-enum values are replaced by that setting's declared default. Number values are never clamped. Keys outside the schema are left untouched on the attached table and are omitted from `Serialize` snapshots.
