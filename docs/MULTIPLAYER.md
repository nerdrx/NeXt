# LAN multiplayer

`NetworkSession` provides ENet host/join, player presence, validated ship-design
exchange, shared system travel, and rate-limited position/rotation updates. It
now validates opted-in ship hits on the host. NPC combat, economy, cargo and
mission state still simulate locally. Target ship health and rescue also remain
local, so this is not fully authoritative multiplayer.

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

## Agreed flight PvP

Settings offers an explicit opt-in for combat with other opted-in pilots. Both
participants must be flying, opted in and have a pose no older than one second.
Consent resets on leaving, reconnecting or system travel. The game gives every
session node the stable `NetworkSession` name required by RPC routing.

The host attributes requests to the ENet sender, caps shots at one per 180 ms,
traces centered 2.8 m module boxes within 2200 m and checks its physical world for
occlusion. Damage comes from the validated attacker's modules, never a client
amount. The nearest protected/docked ship blocks the shot. Host-only reliable
RPCs deliver damage to the target, whose immediate local consent and flight state
are checked again. Travel epochs reject delayed messages from previous systems.

`publish_pose(position, rotation, origin_data, flying)` supplies flight presence;
`set_pvp_allowed(bool)` changes consent and `request_pvp_shot(direction)` requests
a shot. Hosts must supply `pvp_occlusion_check`; absent callbacks reject all hits.
`pvp_damage_received(attacker, damage)` applies shields, hull and normal rescue in
the game. Remote module colliders also stop ordinary local weapon rays and are
disabled outside the rendering range.

Loopback checks cover protocol consent, target-only delivery, cooldown, freshness,
grounded protection and travel resets. A main-scene ENet guest fires through an
actual wall test, then depletes host shields/hull; revocation prevents more damage.
Live Steam, latency compensation, authoritative movement/health, on-foot PvP and
shared NPC/world damage are not established by these checks. Client-authored
movement and local saves are not an anti-cheat boundary.

Confirmed hits also broadcast an authority-only `pvp_hit_confirmed` event with
absolute sector addresses. Other pilots see a short orange tracer and impact;
the shooter gets an impact and a brief gold crosshair marker, reusing its local
predicted beam. The event is cosmetic and cannot apply damage. It means the host
validated a hull hit, not that the target acknowledged damage. Misses and
protected/occluded shots currently have no replicated tracer. Stale travel epochs,
unknown peers, malformed addresses and over-range events are discarded.

Physical ephemeris time is now supplied by the host on welcome and travel, with
authority-only reliable snapshots at most once per second. Guests predict time
locally between snapshots and adopt the received epoch; they cannot publish a
clock to the host. Snapshot delay is not compensated, so this is shared survey
time rather than precision synchronization for moving-body collision. A visitor
adopts the host's current epoch even when its local visit save is older; the
home world's epoch remains paused and is restored on return. Economy calendars
and the existing isolated visitor finances remain local. Both peers need the
same build for the extended RPC payloads.


## Joined ship designs

The host fixes each participant's normalized module grid and room/hull layout at join. Pose packets may update position, orientation and flight status but cannot replace that design, even while grounded or opted out of PvP. A packet attempting a different design is rejected before changing presence or refreshing its timestamp. The host's own publication path follows the same rule. System travel does not unlock refits; leave, refit and reconnect to negotiate a new design. This matches the existing ship architect restriction during visits.

This closes mid-session weapon and hitbox replacement through pose messages. It does not prove ownership of a joining design, validate movement authority or make health and rescue authoritative. Those require additional host-owned state and services.


## Recoverable visitor saves

Saving during a visit writes a journal beside the home save containing validated
home and visitor snapshots, then replaces both profiles and removes the journal.
Startup and commander reload replay a pending journal before loading home. Recovery
is idempotent; malformed snapshots leave both profiles untouched and retain the
journal for repair. The visitor destination is derived from a validated world ID,
not an arbitrary path supplied by journal data.

If saving fails while returning home, the visitor profile stays in memory and the
return waits for a successful save/retry. Loading or quitting cannot silently discard
that pending return. Startup recovery failures disable saves until recovery succeeds
through commander reload. This protects against interrupted application writes;
it does not establish power-loss durability on every filesystem, cross-process
locking, host authority or tamper-proof ship ownership. Steam credentials and native
transport configuration remain separate unfinished requirements.
