# ProfileStore

ProfileStore owns sessions and saving; Prefs owns preference validation and synchronization. After a profile is ready, attach its nested settings table:

```lua
if type(profile.Data.Settings) ~= "table" then
    profile.Data.Settings = {}
end
local ok, err = Preferences:Attach(player, profile.Data.Settings)
if not ok then
    warn(err)
    profile:EndSession()
    return
end
```

On `OnSessionEnd` and player leave, call `Preferences:Detach(player)` before ending the session. Do not replace `profile.Data.Settings` after attaching it.
