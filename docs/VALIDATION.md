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
