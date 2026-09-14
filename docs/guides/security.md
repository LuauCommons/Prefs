# Security

The server is the source of truth. A client cannot choose a player, attach data, load data, detach a player, or destroy a runtime. Every client request checks the operation, setting name, `clientWritable`, type, finite number bounds, and enum membership.

Requests use a per-player, per-namespace token bucket with a burst of 30 and replenishment of 15 requests per second. For sliders, send around 10 updates per second and retry the final value after a rate-limit response. Do not put secrets in preference schemas: owner-only replication is not access control for server data.
