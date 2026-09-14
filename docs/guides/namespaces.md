# Namespaces

Each definition has a namespace name. The default is `"Prefs"`; use a stable unique name for independent schemas:

```lua
local Audio = Prefs.define(audioSchema, { name = "AudioPreferences" })
local Gameplay = Prefs.define(gameplaySchema, { name = "GameplayPreferences" })
```

Every namespace has isolated remotes, state, observers, revisions, and rate limits. Require each shared module on both server and client. Defining the same name twice in one execution context is rejected.
