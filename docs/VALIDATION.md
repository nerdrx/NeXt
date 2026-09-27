# Development-build validation

Validated locally on 2026-09-27 with Godot 4.7.2.

- Headless editor import succeeded.
- Universe determinism, state/economy/save validation, actor lifetime, ENet host/two-client networking, visitor profile isolation and real player-control tests passed.
- Integrated gameplay check passed: commodity/share transactions, ship/station construction, persistent combat changes, save/load, hyperdrive, surface landing, walking through a generated ship interior and opening menus without unintended transactions.
- Crew orders, rescue/insurance, room/panel layouts, sector coordinates and the Steam adapter's fake transport tests passed. The real-scene operations test covers order progress, paused offline simulation, cargo recovery, duplicate salvage rejection and medical rescue. ENet tests include validated layout synchronization; visitor tests cover carrying layouts home.
- The expanded normal-entrypoint integration check passed both headlessly and in the exported Windows executable under Proton, including crew cargo purchases, insured ship destruction, wreck recovery, duplicate salvage rejection and saved recovery state. A separate attempt to launch the exported standalone test script did not complete; it is not counted as passing.
- Forward+ graphical integration completed under headless Gamescope; command, hangar, flight, shipyard, colony and interior screenshots were captured. Hull triangle winding was corrected after visual inspection.
- Windows release export completed. That executable completed the same integrated graphical check under Proton Experimental using an AMD Radeon RX 7900 XTX through Vulkan. Windows reported a nonfatal SDR white-level warning. The game emitted its completion marker and all six captures; the remaining Gamescope/Proton wrapper required the configured timeout to terminate. A clean wrapper exit is not established.

These are short automated checks, not extended playtesting, native Windows hardware coverage, a multiplayer security audit or a 1440p/60 FPS benchmark. Steam adapter code is present, but the standard export lacks the native GodotSteam runtime and no production AppID is configured; live Steam friend sessions remain unverified. The current visuals remain procedural placeholders below the final near-photoreal target.

The reported `network_session.gd` SceneTree/MainLoop alert results from launching a Node component as a standalone script. The configured main scene and `run-next.sh` launch successfully. Use F5 in the project editor, the launcher, or the exported executable.

See README for reproducible commands. Local detailed logs and captures are in the ignored build directory; CI repeats logic checks and creates Windows artifacts.

## Factions and owned docks

Faction domain and save-migration tests passed, including treasury conservation, duplicate-claim rejection, diplomatic trade terms and police hostility. The station gameplay test instantiates the actual main scene and verifies fast-docking rejection, slow docking, walking collision, fall recovery, departure at the same station and live police stance changes. The visitor test now checks faction/treasury isolation between home and visitor profiles. Existing state, crew, recovery, layout, controls and operations tests passed.

The loopback test previously allowed its host to exit before the remaining guest verified peer departure. It now requires that guest's reliable acknowledgment before reporting success; four repeated runs passed after the fix. A transient ENet shutdown warning occurred in one run; this is not live Steam coverage. The faction menu was visually inspected under hidden Gamescope; that short harness emitted resource-leak warnings during shutdown, so clean graphics teardown is not established by it.

The exported Windows build completed the expanded normal-entrypoint graphical integration under Proton, including faction save round trips and owned-outpost docking. The faction menu and owned-deck captures were inspected. The wrapper still requires timeout termination after the game's success marker. No full station interiors or host-authoritative faction simulation is established by these checks.

## Physical local patrol combat

The fleet gameplay test instantiates the main scene and verifies mutual pirate/patrol target acquisition, weapon-ray hull damage persisted to the fleet record, a single pirate bounty, and payroll without a second synthetic encounter. It also verifies an autonomous battle through the actual actor signals, disabled-hull save/reload, service repair and removal after canceling an order. Paused/unpaid patrols stop firing while remaining damageable. ShipActor checks cover living ship targets, flying pilots, finite damage and safe vertical aiming; crew tests cover local/remote simulation separation and wage resumption. Existing control, operations and main-entrypoint smoke checks passed.

Only gunner patrols have this local physical simulation. Trader voyages remain strategic, positions reset on system rebuild, and fleet disablement still uses service repairs rather than physical wreck salvage. This does not establish shared host-authoritative fleet combat.

The normal-entrypoint Windows export also passed under Proton with local patrol creation, physical damage and saved fleet hull checks. Its local-patrol capture was inspected. The usual SDR warning and timeout-terminated wrapper remain; this is not a performance benchmark or full-session soak test.

## Floating-origin flight

The real-scene spatial gameplay test crosses a sector boundary using manual flight input, preserves velocity/cruise targets and AI patrol references during rebasing, traverses over 800 km with bounded player coordinates, restores culled geometry on return, and saves/reloads the remote flight address. It verifies helm orientation across interior entry/save/exit, peer-address rendering, remote wreck range rejection and recovery, and orbital launch coordinates after a surface visit. Focused FlightFrame tests check visibility and collision-layer restoration. Existing network, visitor, station, fleet, control and operations tests passed.

The normal-entrypoint Windows export completed its expanded rebasing/save/restore check under Proton and the rebase-flight capture was inspected. The SDR warning and timeout-terminated wrapper remain. This establishes bounded-origin travel through existing space, not planetary terrain streaming, physical celestial scale, moving reference frames or a performance benchmark.

## Manual surface landing checks

The real-scene planetary test lands on the side of a spherical planet, rejects excessive landing speed, checks physical floor contact and walking with radial gravity, and lifts off without rebuilding the world. Grounded save/load restores player heading and a separate parked ship address. An out-of-range saved ship address is rejected before changing the world origin. Terrain mesh normals and outward ray collision, radial pilot movement, GameState saves and the existing integrated smoke check pass. This covers the current small bodies; it does not establish planet-scale terrain, seamless colonies, multiplayer surface visits or final art quality.

Hidden Gamescope/Vulkan rendered the planetary walking test and its capture was inspected. The flat initial material was replaced with procedural rock variation. The test passed, but Godot reported two ObjectDB instances leaked at exit; teardown is not clean. These remain temporary ground materials, not final-quality terrain art.

The normal Windows entrypoint now exercises same-scene planetary landing, radial floor contact, grounded save/load and liftoff. Its exported executable completed these checks under hidden Gamescope/Proton with `NEXT_INTEGRATION_OK`; the manual surface capture was inspected. The SDR warning remains; the wrapper required timeout termination (exit 137) after game checks finished. Additional native testing walks over 70 m across terrain patch replacement and returns from a ship interior without losing radial position, heading or ground contact. These checks do not establish long-session stability or target frame rate.

A CI patrol test intermittently expected combat after a quiet transit had already arrived and become locally simulated. The corrected deterministic fixture checks quiet arrival, the switch to local wages, and remote encounter damage/reward separately; six fresh process runs passed. Production patrol behavior was unchanged.

## Continuous surface ports

SurfaceColony geometry checks cover apron, ramps and building collisions on radius 170 and 850 bodies, including a sideways transform. A main-scene colony test passes approach targeting, landing speed rejection, physical deck walking, service-terminal interaction, grounded save/load preserving the parked ship, and departure without scene replacement. The hidden Gamescope capture shows the generated industrial port and was inspected; these buildings are placeholders and have no inhabitable interiors yet. The graphical test reports seven texture RIDs at teardown.

The normal-entrypoint Windows export also passed port docking, physical deck contact, terminal access, save/load of the port ship anchor and departure under Proton. Its surface-city capture was inspected. As before, the game completed its checks before the wrapper was timeout-terminated (137); the SDR warning remains.

## Port ground-floor interiors

Four ground-floor rooms now have physical door openings, walls, floors, counters and local service interactions. Geometry checks cover both current planet sizes. Main-scene tests physically walk through each doorway, open its correct service page, reject distant/occluded service access, save/load within a room, and depart from the original ship pad. A temporary collision obstruction proves service line-of-sight rejection and restored access after removal. Native headless and hidden Gamescope tests pass. The screenshot exposed an oversized counter; it was lowered and the refreshed capture inspected. The graphical teardown texture warning remains.

The exported Windows normal-entrypoint check also entered a port room, verified its floor and service page, captured the interior and completed under Proton. The capture was inspected. Wrapper cleanup still required timeout termination (137), with the same SDR warning.

## Planetary cruise routing

The route planner checks direct, antipodal, polar, multiple-obstacle, invalid-input and million-metre-radius cases, independently verifying segment clearance. A real Pilot flight test travels from the opposite side of planet zero to its colony approach, docks, launches, crosses 9 km and a floating-origin boundary, then verifies manual cancellation clears the queue. The observed minimum clearance in that flight was 39.07 m. Simulation runs at 5x time with 300 physics ticks/s to retain a 1/60 s simulation step; this is functional evidence, not a performance measurement. Controls, spatial gameplay, colony gameplay and integrated smoke regressions pass. Collision avoidance covers planetary spheres only; station/building/traffic avoidance remains unfinished.

## Port staff and security

A real-scene staff test checks six residents per port, four grounded stationary clerks, named service interactions, stable identities across rebuild/load and distant simulation suspension. Actual player weapon rays verify nonlethal assault raises wanted status, local police become hostile, lethal damage persists the casualty and surviving identities do not change after loading. A separate actor test covers stationary duty, disabled friendly following and pursuit limits. Native headless and hidden Gamescope tests pass; the named clerk capture was inspected. Existing actor and integrated smoke checks pass. This does not implement full civilian schedules, navigation meshes or staffed upper floors.

The staff-enabled Windows export completed its normal integrated smoke under Proton. As in earlier runs, the wrapper required timeout cleanup after the success marker; the SDR warning persists. Staff assault and identity checks were exercised by the native dedicated test, not the Windows smoke.

## Port pedestrian navigation

Port collision boxes feed a lazy native Godot navigation bake in a private local map. It uses 0.25 m cells, 0.5 m agent radius and 1.8 m height, excluding upper roofs. Capsule sweeps verify all four room paths at both current planet sizes, including paths behind counters. Translation/rotation preserve local paths; off-deck, elevated and disconnected destinations are rejected. Maps and regions are freed on rebuild/exit.

The actual GroundActor pursuit test traverses all four rooms at normal movement speed, stays supported, obtains firing line of sight, handles an origin shift during pursuit and stops for an unreachable target. It runs accelerated simulation, not a performance benchmark. Existing actor, staff and integrated smoke checks pass. Pedestrian navigation covers static port geometry, not moving-crowd avoidance or general planetary terrain. The bake uses the [official NavigationServer3D source-geometry workflow](https://docs.godotengine.org/en/latest/classes/class_navigationserver3d.html).

The navigation-enabled Windows export completed the normal Proton smoke. Dedicated guard pursuit was verified in the native test. The known SDR warning and post-success wrapper timeout cleanup remain.

## Consensual flight PvP

PvPHits unit checks cover centered modular/rotated hulls, nearest protected blockers, range, distant sector precision, invalid directions and module-derived damage. Real ENet transport checks cover bilateral consent, targeted damage delivery, firing limits, fresh flight poses, revocation and travel epochs. A main-scene host with an ENet guest verifies physical wall occlusion, shield then hull damage, revocation and remote collider culling. Existing network, visit, spatial, Steam-facade and integrated smoke regressions pass. These establish host-validated hits, not host authority over movement, target health, economies or NPC simulation. Live Steam remains untested.

Adversarial transport checks capture and verify Godot authority rejection of client-forged damage RPCs to the host and another client; a positive control confirms authorized delivery. Zero/NaN directions and stale travel-epoch shots are rejected. The main ENet gameplay test also runs under hidden Gamescope. The Windows export completes normal Proton smoke; dedicated multiplayer checks ran natively, not over live Steam or cross-machine Windows. The known SDR warning and post-success wrapper timeout remain.


## Replicated hit feedback

The ENet transport test verifies confirmed events reach host, target and spectator,
while occluded and unconsented shots produce none. Forged damage and cosmetic RPCs
are rejected by Godot authority checks with complete valid argument lists.
Receiver checks reject stale epochs, unknown/self peers, malformed or nonfinite
addresses, excessive range and disconnected sessions. Main-scene gameplay checks
verify beam/impact creation, shooter-only marker expiry, no duplicate shooter beam,
no cosmetic damage and rejection of far-away visual endpoints. Native headless and
hidden Gamescope runs pass. This covers accepted PvP hits only; missed shots and
NPC fire are not replicated by this event.

The feedback-enabled Windows export completed normal integrated smoke under
Proton. Dedicated feedback/authority tests ran natively. The known SDR warning
and post-success wrapper timeout remain. The gold marker capture was inspected.
