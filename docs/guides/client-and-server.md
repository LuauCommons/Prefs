# Client and server

The same shared definition selects the correct runtime automatically. The server creates networking and owns attached data. The client waits for a snapshot, sends requests, and stores confirmed values locally.

Client mutators omit the `Player` argument:

```lua
Preferences:Set("MusicVolume", 0.5)
Preferences:Toggle("CameraShake")
```

Each request returns only after server validation. Accepted state is replicated back to that player and observers run from the confirmed snapshot.
