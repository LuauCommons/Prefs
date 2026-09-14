# Validation

Definitions are checked when `Prefs.define` runs. Runtime writes return `false, errorMessage` and do not change data when invalid.

Numbers must be finite and can have inclusive `min` and `max` bounds. Strings must be valid UTF-8 and no longer than 4096 bytes. Enums accept only their explicit non-empty values. `clientWritable` defaults to `false`.

Normalization is deterministic: missing values, wrong types, invalid strings, non-finite numbers, out-of-range numbers, and invalid enum values are replaced by the setting default. Values are never clamped.
