# Security policy

## Reporting a vulnerability

Please do not disclose an unpatched security issue in a public issue. Report it privately to the LuauCommons maintainers through the repository's GitHub security advisory workflow:

<https://github.com/LuauCommons/Prefs/security/advisories/new>

Include the affected version, a minimal reproduction, Roblox server/client context, and the expected versus observed behavior. Do not include real player data, secrets, or live production remotes.

Prefs treats the server as authoritative. Client requests are untrusted and must pass schema, permission, type, range, enum, and rate-limit checks. Applications should still avoid putting secrets in preference defaults or schemas.
