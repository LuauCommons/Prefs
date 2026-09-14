# Reconciliation

`Attach` reconciles an existing mutable table in place. Valid schema values are preserved, missing or invalid values receive defaults, and unrelated keys stay untouched.

```lua
local settings = { MusicVolume = 0.4, LegacyFlag = true }
Preferences:Attach(player, settings)
-- MusicVolume remains 0.4; new schema keys are added; LegacyFlag remains.
```

`Load` treats its input as a full schema snapshot. Missing preference keys reset to defaults, while unrelated fields on an already attached table remain unchanged.
