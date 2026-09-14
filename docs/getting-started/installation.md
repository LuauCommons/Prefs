# Installation

Prefs has no required dependencies. Choose the distribution path that fits your project.

## Studio model

Download `Prefs.rbxm` from a GitHub release. In Studio, create `ReplicatedStorage/Packages`, then use **Insert from File** on that folder. Keep the `Prefs` ModuleScript and its `Runtime`, `Schema`, and `Store` children together. Require the same shared definition from server and client code.

## GitHub source

Clone or download the repository and use the runtime modules under `src`. Rojo users can use the included `default.project.json`; a production build contains only the package modules.

## Wally

After publication to the public registry:

```toml
[dependencies]
Prefs = "luaucommons/prefs@0.1.0"
```

Run `wally install` and map the entire generated `Packages` directory into `ReplicatedStorage.Packages`. The package alias needs its `_Index` directory.

See [GitHub releases](https://github.com/LuauCommons/Prefs/releases) for downloadable models and packages.
