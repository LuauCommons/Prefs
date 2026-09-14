<p align="center">
  <img src="assets/PrefsLogo.png" alt="Prefs logo"/>
</p>

<h1 align="center">Prefs</h1>

<p align="center">A small, framework-independent Luau preferences layer for Roblox.</p>

<p align="center">
  <a href="https://luaucommons.github.io/Prefs/">Documentation</a>
  · <a href="https://github.com/LuauCommons/Prefs/releases">Releases</a>
  · <a href="https://github.com/LuauCommons/Prefs/issues">Issues</a>
</p>

Prefs lets a game define player settings once and reuse the same schema for defaults, validation, reconciliation, server-authoritative replication, and observers. It attaches to a player-data table you already own; it does not save data, generate UI, or replace ProfileStore.

## Features

- Boolean, finite number, UTF-8 string, and string enum preferences
- Inclusive number bounds and explicit enum validation
- In-place reconciliation that preserves unrelated saved fields
- Automatic RemoteFunction/RemoteEvent networking with server validation
- `Get`, `Set`, `Toggle`, `Reset`, `ResetAll`, `Observe`, `Attach`, `Detach`, `Serialize`, and `Load`
- Per-player cleanup and isolated named namespaces

## Quick start

Install one copy of Prefs under `ReplicatedStorage.Packages`, then create one shared ModuleScript:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Prefs = require(ReplicatedStorage.Packages.Prefs)

return Prefs.define({
    MusicVolume = Prefs.number(0.8, { min = 0, max = 1, clientWritable = true }),
    CameraShake = Prefs.boolean(true, { clientWritable = true }),
    SprintMode = Prefs.enum("Hold", { "Hold", "Toggle" }),
}, { name = "PlayerPreferences" })
```

On the server, attach the table owned by your data system:

```lua
local ok, err = Preferences:Attach(player, profile.Data.Settings)
if not ok then warn(err) end
```

On the client, wait for the initial snapshot before reading or writing:

```lua
local ready, err = Preferences:WaitForReady(10)
if ready then
    Preferences:Observe("MusicVolume", function(value) print(value) end)
    Preferences:Set("MusicVolume", 0.5)
end
```

See the [quick start](https://luaucommons.github.io/Prefs/getting-started/quick-start/) for complete server and client scripts.

## Installation

- **Roblox Studio:** download `Prefs.rbxm` from the [latest release](https://github.com/LuauCommons/Prefs/releases) and insert it under `ReplicatedStorage.Packages`.
- **Wally:** add `Prefs = "luaucommons/prefs@0.1.0"` to `wally.toml`, run `wally install`, and sync the generated `Packages` directory into `ReplicatedStorage`.
- **Source/Rojo:** clone this repository and map `src` using [default.project.json](default.project.json).
- **Creator Store:** publication is planned; use the release model until a Creator Store package is available.

No manually created remotes, framework, plugin, or data store is required.

## Documentation and development

Read the [technical documentation](https://luaucommons.github.io/Prefs/) for validation, reconciliation, networking, security, ProfileStore integration, namespaces, lifecycle, and the complete API. The source documentation lives in [`docs/`](docs/).

Run the dependency-free tests with `luau tests/run.luau`. Maintainers can use [`RELEASE.md`](RELEASE.md) and [`CONTRIBUTING.md`](CONTRIBUTING.md) for build and release checks. Studio integration instructions are in [`tests/studio/README.md`](tests/studio/README.md).

## Contributing and security

Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) before opening a pull request. Report vulnerabilities privately using [`SECURITY.md`](SECURITY.md), not a public issue.

## License

MIT. See [`LICENSE`](LICENSE).
