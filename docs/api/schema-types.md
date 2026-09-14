# Schema types

```lua
Prefs.boolean(default, options?)
Prefs.number(default, { min?, max?, clientWritable? })
Prefs.string(default, options?)
Prefs.enum(default, { "ValueA", "ValueB" }, options?)
```

Boolean, number, and string defaults must match their type. Number bounds and defaults are finite. Strings and enum values are valid UTF-8 and at most 4096 bytes. Enum defaults must be in the allowed list.
