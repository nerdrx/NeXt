# LAN multiplayer

`NetworkSession` provides ENet host/join, player presence, validated ship-design
exchange, shared system travel, and rate-limited position/rotation updates. It
does not yet synchronize combat, economy, cargo, or mission state. Each peer still
simulates those systems locally, so this is a co-op presence foundation rather
than authoritative multiplayer.

## Integration

Add a `NetworkSession` node at the same scene path on every peer; Godot RPCs
require matching node paths. Before `host()` or `join()`, set `ship_modules` and
`display_name`. The host calls `host(port)`. A guest calls `join(address, port)`;
the method returns immediately while ENet connects. Observe `connected`,
`session_message`, and `world_joined` for completion and errors.

`presence` maps ENet peer IDs to dictionaries containing `position`, `rotation`,
`ship_modules`, and `name`. Call `publish_pose(position, rotation)` while the
player moves; calls faster than 20 Hz are dropped. Hosts call `travel(index)`
after approving a destination. Guests receive `world_joined(index)` with the
matching `world_seed`; the seed matches `Universe.system_data(index).station_seed`.
Call `leave()` when leaving the session.

The session supports at most 8 players total, including the host. Join designs
accept at most 100 modules. Each module must be a unique grid cell with a known
`kind` and finite integer `x`, `y`, and `z` coordinates in `-16..16`.
Names are reduced to 20 ASCII letters, digits, spaces, underscores, or hyphens.
The host is the source of truth for system travel and relays client poses under
the ENet sender ID; clients cannot choose another peer's ID. Pose coordinates
are limited to 30,000 m and rotations must be finite. A guest departing is
removed from presence without disconnecting other guests; host departure ends
each guest session. Hosts provide a stable 32-character lowercase hexadecimal
`world_id` during the welcome handshake; guests adopt it, and travel retains it.
Use it as the key for per-world economy data.

`GameState.dismiss_crew(index)` removes a crew member and ends the current
payroll status until the next travel settlement. `withdraw_company(amount)`
moves earned company balance into personal credits; it rejects nonpositive and
unavailable amounts.

## Scope and reachability

This currently uses Godot's built-in ENet transport. A LAN host is reachable
only when the guest can route to its address and UDP port (default `27840`);
internet play may require router port forwarding. A dynamic GodotSteam lobby adapter now uses the same validated game protocol.
It supports friend-only eight-member lobby creation, joining accepted invitations,
overlay invitation UI and launch invitations. The standard export still uses vanilla
Godot, so native Steam support and a production AppID are not configured. Real
Steam connectivity and relay have not been tested; fake-facade tests establish
callback/lifecycle behavior only. Reliable combat/economy authority remains work
in progress.

## Visitor finances

The game saves the home profile before visiting. A separate `visits/<world-id>.json`
profile holds credits, shares, crew, company and reputation for the visited world.
Only ship modules, cargo and their hull/shield/fuel condition carry between profiles.
The host identity selects that profile; home finances remain unchanged on return.
Saving while visiting also records the carried ship in the home save. This is local
profile isolation, not an authoritative or tamper-proof asset transfer protocol.

## Loopback check

Run `godot --headless --path . -s res://tests/test_network.gd`. The script starts
a host and two guest processes, joins over loopback, checks the welcome
system/seed/world ID and player design, publishes a pose, tests host-controlled
travel, then confirms one guest can leave while the other stays connected.

## Steam build configuration

`steam/app_id` in project.godot is intentionally zero until a NeXt Steamworks AppID
is configured. The adapter rejects missing IDs and never silently uses Spacewar.
Use a GodotSteam build containing the `Steam` singleton and `SteamMultiplayerPeer`;
vanilla Godot remains supported for editing and LAN testing. The official
[GodotSteam v4.22.1 release](https://codeberg.org/godotsteam/godotsteam/releases/tag/v4.22.1)
lists Godot 4.7.2 variants and matching export templates.

`NetworkSession.enable_steam(app_id)` starts the application-wide invite listener.
`host_steam(app_id)` and `join_steam(app_id, lobby_id)` establish the transport;
`invite_steam_friends()` opens the overlay. Leaving a lobby preserves the listener;
application exit shuts it down. Invitations are shown for the player to accept,
so an incoming invite cannot silently replace the active world.

`tests/test_steam_session.gd` checks explicit IDs, the eight-person limit, both host
callback orders, canceled/failed/timed-out joins, late callbacks, idle invitations
and clean shutdown using a fake Steam facade. It does not prove real Steamworks
API success, ownership, NAT traversal, overlay support or cross-machine play.
