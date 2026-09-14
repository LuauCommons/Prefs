# Runnable examples

Install the Prefs model under `ReplicatedStorage.Packages.Prefs` first. These
examples require no manually created remotes or additional Prefs setup.

## Basic

Copy the files into these Studio instances, preserving the contents:

| Source | Studio destination | Class |
| --- | --- | --- |
| `Basic/Preferences.luau` | `ReplicatedStorage.Packages.Preferences` | ModuleScript |
| `Basic/Server.server.luau` | `ServerScriptService.PreferencesServer` | Script |
| `Basic/Client.client.luau` | `StarterPlayer.StarterPlayerScripts.PreferencesClient` | LocalScript |

Press Play. The server attaches an empty settings table, and the client observes
the confirmed volume, sets it to `0.5`, and toggles camera shake. Watch Output
for the server and client observers. This example does not save data.

`tests/release/default.project.json` uses these same files with the production
model and test assertions. See [the release guide](../RELEASE.md).

## ProfileStore

Use `Basic/Preferences.luau` and `Basic/Client.client.luau`, but replace the Basic
server Script with `ProfileStore/Server.server.luau`. Install ProfileStore as
`ServerScriptService.ProfileStore`. Do not run both server examples together.

This example attaches `profile.Data.Settings`, detaches before the profile ends,
and leaves session management and saving to ProfileStore. Prefs does not require
ProfileStore when you use another persistence system.
