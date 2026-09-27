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

## Cockpit instruments

The procedural cockpit now has dark consoles, an open forward canopy and two
physical displays. The controls test verifies fuel/shield readouts use current
ship state and cruise indication follows engagement/manual cancellation. Existing
walking, flight, weapon occlusion and bounty checks pass. Main integrated smoke
and hidden Gamescope PvP checks pass. The rendered view was inspected and display
positions adjusted so console geometry does not hide the fuel or mode rows.
These are replaceable procedural primitives, not final photoreal cockpit art.

The cockpit-enabled Windows export reached the normal Proton integration success
marker. As before, the SDR warning remains and the wrapper needs timeout cleanup.


## Orbital planet appearance

The orbital material uses larger warped continents, narrower coast transitions,
subdued mineral palettes, dry airless worlds and reduced specular glare. Planet
and atmosphere meshes use 128 segments/64 rings; collision radius and saved
positions are unchanged. The additive atmosphere now uses outward-facing geometry,
world-space sunlight and a thin shell, fading on the night side. This is a limb
approximation, not physical atmospheric scattering. Shader transforms follow the
[Godot spatial shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html).

Native integrated smoke and hidden Gamescope gameplay checks pass. Day, night and
side-lit planet captures were inspected; the night side is dark and the rim follows
the directional light. A standalone capture run reported Godot texture RID leaks
on teardown. No frame-rate target is established. At this stage orbit appearance did not yet share coastlines with walking terrain;
the shared-height update below supersedes that limitation. Planetary scale, cloud
volumes and detailed surface assets remain unfinished.

The Windows export with these planet materials reached the normal integrated
smoke success marker under Proton. Live graphics/performance certification is
still pending; the usual SDR white-level warning remains.


## Owned station concourses and saves

Owned stations now connect their apron to a covered bridge, corridor and 3–8
service rooms depending on level. Windows use transparent collision-backed panes;
rooms have actual doorway openings and reachable service terminals. The physical
walking test follows every level-one route from apron to room and back at the
normal player speed with accelerated simulation. It opens each service, saves
inside a room, reloads both normally and after an origin shift, and checks the
ship remains at its owned dock. Capsule sweeps check every route in the level-100
layout. Unsupported saved positions fall back to the orbital dock.

Optional station location metadata is validated against the saved station list
and current system; fractional, out-of-range, nonexistent and contradictory
locations fail transactionally. Existing state, docking, departure, diplomacy and
integrated smoke checks pass. The walking test also runs in hidden Gamescope;
the initial room capture prompted brighter lighting and clearer glazing. This
is a connected single-level concourse, not a complete huge populated station.
Station staffing, access permissions and arbitrary interior construction remain
unfinished. Save bounds reject space beyond floors but are not a full capsule
collision validation for arbitrary edited saves.

The final native interior test also checks glazing collisions between window
posts. The Windows export completed the expanded normal Proton smoke, including
room services and interior save restoration. The full walking/capsule route checks
ran natively. The known SDR warning and post-success wrapper cleanup remain;
the hidden native render reported texture RID leaks at teardown.


## Active world calendar

Twenty minutes of active world time advances the simulation day, daily passive
payroll, station/company income, market dates and contract refresh. Assigned crew
keep their existing operation timers and are excluded from daily payroll.
Hyperdrive still advances one day and preserves partial-day progress. The clock
runs alongside crew timers while menus are open; HUD and command-deck clocks show
HH:MM. Open menus refresh on day rollover so displayed prices follow the new day.
No wall-clock timestamp is used and closed profiles receive no offline catch-up.

Calendar tests verify exact single settlements, assigned-worker payroll using an
actual station assignment, jump interactions, fractional save continuation,
legacy defaults and transactional invalid-field rejection. Main-scene tests
verify timed settlement without travel, live menu time and continued time outside
menus. Visit regressions verify home and visiting-world clocks remain separate;
crew and state tests pass. This does not synchronize a shared host-authoritative
calendar or economy between remote players; visiting economies remain local as
previously documented. Values over 24 hours of elapsed time in a single calendar
call are rejected to bound catch-up work.

The calendar-enabled Windows build reached normal integrated Proton smoke success,
including the new calendar rollover assertion. The wrapper required its usual
post-success timeout cleanup. The native hidden menu render was inspected and
reported texture RID leaks during teardown. A subsequent autosave adjustment keeps
saving every minute in menus as well as in active play; its native gameplay check
loads the written save and verifies persisted clock/account values. The Windows
export was rebuilt after that adjustment.


## Shared orbital and ground elevation

A deterministic 512×256 single-channel floating-point height map now supplies
orbital displacement, land/ocean classification, local terrain mesh and collision,
and landing elevation queries. CPU bilinear sampling wraps longitude and clamps
latitude to pixel centres, matching the shader sampling convention. A bounded
16-entry cache shares maps and textures. Tests cover pixel centres, seam continuity,
poles, deterministic reuse and cache eviction; these are not a numerical GPU
readback comparison.

Surface autopilot surveys dry ground on ocean-bearing planets. Manual landing
rejects water beneath either the ship or the disembarkation point. Native
integration and hidden Gamescope planetary gameplay checks pass, including water
rejection, radial walking, terrain patch replacement, parked-ship saves and liftoff.
The orbital limb capture was inspected. Water remains a visual surface without
swimming or buoyancy. Compact planet sizes, coarse orbital geometry, simple
ground materials and atmospheric approximation remain development limitations.

The displaced coarse globe initially intersected the finer walking mesh. The
orbital shader now clips land inside the active terrain patch footprint, leaving
a one-cell border overlap and retaining ocean fragments. Patch cleanup disables
the clip. A second hidden gameplay run passed, and its surface capture confirms
the broad flat overlap patches are gone. This is a local mesh handoff, not a
general planetary LOD system.

The shared-height Windows export reached `NEXT_INTEGRATION_OK` through the normal
entrypoint under hidden Gamescope/Proton. The SDR white-level warning remains;
this is functional verification, not proof of 1440p/60 performance or final art.


## Procedural surface geology

Planet patches now include deterministic rock formations placed on global
latitude-band cells. Patch recentering selects the same planet-space candidates,
rather than reseeding scatter around the player. Four instanced mesh variants
share convex shapes for larger boulders; small pebbles remain visual. Ocean sites
and the current north-pole port footprint are excluded. Manual landing checks
the ship's horizontal bounds and disembarkation point for rock clearance, and
surface autopilot applies the same dry-ground and obstacle checks.

The ground material adds mineral layers and screen-space bump, attenuating fine
detail with pixel footprint. Hidden Gamescope gameplay passed with rock landing
rejection, walking across a streamed patch, interior return, surface save/load and
liftoff. Its capture was inspected. These are replaceable small-world geology
placeholders; they do not establish planetary LOD, ecosystem variety, final
asset quality or the target frame rate.

The geology check verifies radial alignment, conservative transformed-hull
clearance and physical ray hits. Hidden Vulkan additionally verifies that
MultiMesh instance transforms match their physics bodies; the dummy headless
renderer returns identity transforms from that GPU API, so it cannot establish
that visual match. Existing terrain and colony gameplay regressions also pass.

The Windows geology build reached `NEXT_INTEGRATION_OK` under hidden Proton.
The known SDR warning remains, and the wrapper required timeout termination
(exit 137) after the game's checks completed.


## Cruise obstacle stops and flight impacts

Active cruise sweeps the current pilot collision body along its projected flight
velocity, limited by the remaining waypoint distance. A detected obstruction
stops movement, clears the queued route and reports manual recovery. Planetary
detours remain the route planner; this local stop does not reroute around buildings
or predict moving traffic. The present flight collider is still the pilot capsule,
not the full custom ship hull.

Manual impacts above 25 m/s of incoming normal velocity emit a collision event,
with a 0.7-second contact cooldown. The main scene applies shield-first damage,
a recharge delay and impact feedback. Fatal collisions use existing insurance,
rescue and saved wreck recovery. Slow bumps and fast tangential contact do not
receive the same damage as a direct high-speed impact.

Physical-wall tests cover obstacle stopping without false arrival, impact
thresholds, repeated-contact cooldown and walking exclusion. The main-scene
check also confirms full-route cancellation without damage, shield/hull depletion,
fatal collision rescue and persisted wrecks; it passes in hidden Gamescope/Vulkan.
Actual planetary cruise regression passes with 39.07 m minimum body clearance,
port docking and sector rebasing. The existing ENet PvP gameplay check passes
after sharing ship damage handling with collision feedback.

The Windows export containing flight safety completed normal-entrypoint Proton
smoke (`NEXT_INTEGRATION_OK`). The specific physical crash/rescue check was run
natively, including hidden Vulkan; the normal Proton tour is regression coverage.
The known SDR warning remains.


## Modular player flight collision

Configured player ships now use a box per occupied 2.8 m module cell, centred with
the same bounds as ShipVisual. Gaps are preserved. Collision orientation follows
the flight camera's pitch and roll under the pilot's yaw; camera translation and
shake do not move the hull. Walking switches back to the capsule. Geometry rebuilds
only when module cells change, and physics-callback changes are deferred while
movement waits for the new shapes. This supersedes the capsule-only limitation
for configured ships in the preceding flight safety update.

Planetary route obstacles include the conservative hull radius. Surface approach
and liftoff heights grow for larger ships, as does the disembarkation offset.
The current surface port rejects module spans above 42 m in either horizontal
axis. Builder edits and saved-design loading rebuild the actual collision geometry.
The large-design test uses valid save-supported cells beyond the current builder
UI's smaller grid; the UI construction limits have not changed in this increment.

Main-scene checks pass for geometry save/restore, higher large-ship approach, port
size rejection and disembark clearance. Existing controls, crash/rescue, ENet PvP
and planetary cruise checks pass (39.00 m minimum planet clearance in the cruise
fixture). Hidden Gamescope/Vulkan planetary walking, interior return and surface
save/load pass after flight/walk collision switching.

The colliders approximate module volumes rather than final decorative geometry.
Rotation is updated discretely, without a continuous rotational sweep. Existing
collision masks still govern contact: this does not add authoritative multiplayer
ramming or NPC ship-to-ship rigid-body physics. Station docking for arbitrary
capital-ship sizes and final performance targets remain unfinished.

The physical shape test passes for a wing contacting a wall outside the old
capsule, roll-dependent wall contact, preserved centre gaps, removed-wing
clearance, walking through a narrow doorway and cruise's modular-body sweep.
The Windows export reached `NEXT_INTEGRATION_OK` under hidden Proton; the known
SDR warning remains.
The Proton/Gamescope wrapper again required timeout cleanup (exit 137) after the
game checks completed.


## Larger ship construction in the menu

Construction now accepts the same −16 through +16 coordinates on all three axes
as saved ship data. The 100-module cap, attachment, essential-system, cargo, power
and transaction rules remain. The readable 9×9 grid pans across the larger domain;
X/Z/deck controls select cells directly, out-of-bounds clicks do nothing, and
panning moves the highlighted selection. The non-installable core option is no
longer offered. Preview framing adapts to hull size, and assembly edits refresh
ship statistics without reopening the page. This supersedes the previous smaller
builder UI limitation.

The focused UI check drives grid clicks, coordinate controls, pan buttons and
installation signals at the limits. The main-scene check uses the actual menu
buttons to construct a 53-module ship across both X edges and deck 16, protects a
structural connection, removes/refunds an outer module, reinstalls it and validates
the saved design. It also checks live statistics, physical bounds and camera range.
The hidden Vulkan capture was inspected; install/remove controls were moved below
the preview after the first render revealed they were below the visible area. The
final 1440×900 capture keeps those actions visible. Godot reported seven texture
RID leaks on graphical teardown; exit is not resource-clean.

Large-ship terrain landing clearance now checks occupied module footprints against
rocks rather than a filled circular hull envelope, preserving usable open sites
for wide sparse designs. Disembarkation retains its separate clearance check. The
large-hull scene test finds a dry site through this path; planetary gameplay and
state validation regressions pass. This update does not remove the module cap,
validate arbitrary capital-ship station docking, or prove target performance.

The Windows export completed and its normal entry point reached
`NEXT_INTEGRATION_OK` under Proton Experimental with hidden Gamescope/Vulkan.
The SDR white-level warning remains. The Proton/Gamescope wrapper remained alive
after game completion and was terminated by the 55-second timeout (exit 137);
this is not a clean wrapper exit. The Windows executable and pack were repackaged
in `build/NeXt-Windows.zip`.

## Large owned-station berths

Owned stations choose a separate 120 m square open berth when module bounds exceed
32 m in X/Z or 12 m in Y. The berth has a pedestrian connector to the existing
apron and service concourse, a boarding point outside the maximum 92.4 m hull
width and a launch position 112 m above the deck. The same selection drives
approach, display placement, interaction prompts, departure and fall recovery.
Saved station walking positions restore the selected berth from the saved hull;
no additional save field is needed. Approach now uses the current rebase-aware
station position instead of treating station-local coordinates as system space.

`test_large_berth.gd` builds a wide, tall 53-module vessel through the state API,
checks the speed guard, docks it, verifies deck support, walks the connector into
the old apron using player controls, saves/restores, boards at the service lane
and checks launch collision clearance. The hidden 1440x900 Vulkan test passed and
its capture was inspected. Existing station gameplay and the main integration
smoke passed. Seven texture RID leaks still appear during graphical teardown.

This is an open static berth with assisted docking/boarding transitions. It does
not implement moving airlocks, shared occupancy reservations, custom station
blueprints or large-ship facilities at every public orbital hangar. Those remain
separate requirements; this result is specific to owned stations.

## Public orbital large berths

Public orbital stations now select an exterior 120 m berth using the same hull
bounds as owned stations. The selected position drives ship display, default
commander spawn/reload, boarding range and prompt, fall recovery, cruise target,
docking and departure, and hyperdrive arrival. Public docking gains the existing
35 m/s owned-station speed guard. Cruise resolves the berth in the current spatial
frame, including after origin rebasing. Existing compact-hull positions remain.

The public berth has a collision-backed walking connector through the hangar
mouth, passing beyond the approach spars. The kiosk was moved outside the maximum
hull envelope and duplicated seam geometry removed during review. This supersedes
the previous limitation that public orbital hangars have no large-ship facility.
Docking still uses assisted placement, not physical airlock alignment or shared
berth occupancy. Public-station reload still uses the selected berth's default
boarding position, rather than preserving an arbitrary position in the hangar.

The focused gameplay check constructs a wide/tall hull, checks docking speed,
walks from the berth to the hangar with normal movement controls, reloads its save,
boards and checks physical launch clearance, then validates the cruise destination
after a spatial rebase and clearance after hyperdrive arrival. The main integration
smoke passed. The user-facing maximum 100-module count remains unchanged.

The final public-berth route passed in hidden Gamescope/Vulkan at 1440x900;
the exterior capture was inspected. Seven texture RID leaks remain at teardown.
The Windows executable and pack exported successfully and were repackaged.

The exported Windows build reached `NEXT_INTEGRATION_OK` under Proton Experimental
and hidden Gamescope/Vulkan. The SDR white-level warning persists. The wrapper
remained alive after game completion and ended on the timeout with exit 143;
this is not a clean wrapper exit or a dedicated Windows berth test.

## Editable station service concourses

Owned station records may now store a validated room-purpose sequence. Older
saves keep their procedural 3–8-room layout until the first edit; explicit layouts
survive station-level upgrades. The Station Works menu adds rooms for 1,000 CR
and five alloys, refits a room for 250 CR, and salvages the last room for 500 CR.
The limit is 16 connected rooms and the minimum is one. Selecting an unchanged
purpose does not charge credits. Unknown/oversized/empty saved room sequences are
rejected before commander state is committed.

Room choices determine actual scene services and numbered signs. Construction is
blocked during multiplayer visits, in other systems, or while walking inside the
edited station. The gameplay test exercises the real menu buttons through 16
rooms, refit/removal/refund, save persistence and the occupied-station guard. It
then walks through the bridge and expanded corridor to room 16, opens its chosen
faction service and restores a save made there. This passed in hidden Gamescope
with Vulkan; the 1440x900 menu capture was inspected. General state tests and the
main integration smoke also passed. Seven texture RID leaks remain on graphical
teardown.

This adds editable room purposes and linear expansion. It does not yet provide
free placement of station modules, editable hull panels, multiple floors or
fully simulated room-specific businesses. Station-level income remains separate.

Automated graphical checks must use hidden Gamescope; this is now recorded in
AGENTS.md. Unwrapped agent test instances discovered during this work were stopped.

The focused domain suite passed under a bounded headless process, including real
save roundtrip, corrupt-room rejection without state mutation, and legacy saves.
The Windows executable/pack were exported and the ZIP rebuilt; this increment
was not separately run under Proton.

## Ship interiors at the hull position

Ship interiors now use the parked ship display transform or the stationary flight
hull transform, including pitch and roll, instead of the unrelated (0,6000,0)
location. Interior module spacing matches the exterior at 2.8 m on all axes.
Floors anchor 1.23 m below each module center; room height is 2.45 m with thin
floor/ceiling slabs. Door headers, window frames and lights were adjusted for the
lower ceiling. Interior spawns and lifts transform through the hull basis, and
walking gravity follows the deck. Falling below the interior uses deck-local up
for recovery. The parked exterior display is hidden while aboard and restored
on exit; the interior supplies the visible room shell.

Leaving the helm during cruise or above 1 m/s is rejected. This prevents boarding
from silently stopping a moving ship, but is not a moving reference-frame system.
Ship motion while walking, freely crossing a physical airlock, and multiplayer
boarding remain unfinished. Room windows now share the real-world anchor;
floor/ceiling window materials still do not constitute transparent apertures.

The focused test verifies parked-hull proximity, exact rotated module-floor
alignment, gravity, walking through a connected doorway, deck lift support,
cruise/speed guards, saving the helm address and restoring position/orientation
on exit. It passed headless and in hidden Gamescope/Vulkan at 1440x900; its image
was inspected. ShipLayout tests and the main integration smoke passed. The main
smoke now checks floor support near the parked ship instead of the old 6 km test
location. Seven texture RID leaks remain on graphical teardown.

The Windows export completed and the packaged build reached
`NEXT_INTEGRATION_OK` under Proton Experimental in hidden Gamescope/Vulkan,
including the revised parked-ship interior check. The SDR white-level warning
persists; the ZIP contains the rebuilt executable and pack.
The Proton/Gamescope wrapper remained alive after game completion and was
terminated by the 55-second timeout (exit 137), not a clean wrapper exit.

## Horizontal interior glazing and texture ownership

Floor/ceiling window overrides now hide the opaque backing mesh while retaining
its complete collision barrier. Four opaque rim sections surround a 1.85 m glass
aperture. Floor trim and the central ceiling light are omitted for their respective
window panels. This supersedes the earlier floor/ceiling decorative-pane limitation.

A focused fixture verifies visible alpha panes, hidden backing meshes, floor and
ceiling ray hits, capsule support, and a jumping capsule stopped by the ceiling.
Hidden Gamescope/Vulkan renders also verify an exterior red target through the
floor and a blue target through the ceiling. Initial center-pixel checks sampled
the lamp's specular reflection; inspected captures showed the correct target, so
the final check averages four points around the central glint. Both color checks
passed and both captures were inspected. The anchored ship interior regression
also passed in hidden Gamescope.

PlanetHeightField now keeps weak references to GPU textures while retaining its
bounded CPU image cache. Live materials share a texture; after the last owner
releases it, a future request recreates the deterministic texture from the cached
image. A focused lifetime check verifies sharing, last-owner release and identical
pixel recreation. This does not fix the observed seven texture RID warnings:
the full main-scene graphical regression still reports them, so cache retention
was not sufficient to explain that warning. Further renderer-lifetime work remains.

The headless glazing and planet-height regression checks passed. Windows export
and ZIP packaging completed; this increment was not separately run under Proton.

## Coasting while walking aboard

Leaving the helm with cruise off now transfers the ship's stored flight velocity
to a separate swept modular hull. The hull keeps its world velocity while the
passenger walks. Interior geometry and the passenger translate together before
the passenger physics step. Static deck transforms are explicitly flushed: the
first integration check exposed a one-step lag that otherwise let the passenger
fall through a fast-moving floor. Internal deck bodies are excluded from the
outer hull's collision query; its occupied module boxes still hit world geometry.

Origin rebasing follows the moving hull and shifts the passenger/interior in the
same frame. Saving records the current hull address. Returning to the helm restores
position, orientation and stored velocity, including when boarding through the
menu (which temporarily zeros the pilot body's visible velocity). Contact stops
the hull and returns the commander to the helm; normal collision damage and fatal
insured wreck recovery then apply. The interior interaction hint shows coast speed.

The focused hull test checks occupied-wing sweep collision and actual passage of
an obstacle through an unoccupied module gap. The full-scene test boards through
the real menu, crosses an origin boundary at 180 m/s, checks an idle passenger's
relative position, walks through a doorway, saves the moving address, returns with
momentum, and exercises both nonfatal and fatal impacts. The physical scenario
passed in hidden Gamescope/Vulkan; the final menu-path check passed headless.
Anchored interior and general gameplay regressions passed. The packaged smoke now
also enters a coasting interior, checks floor support and returns with momentum.

This superseded the stationary-only interior restriction with straight coasting.
The later aboard-cruise increment below adds autopilot and angular frame motion.
Crew steering, shared multiplayer boarding and movement through physical airlocks
remain unfinished. At this increment, flight saves did not serialize momentum; the next
increment below adds it. NPC combat was still paused while aboard at this stage. No target
frame-rate claim is made for large interiors. Texture teardown warnings remain.

The final menu-driven coasting test also passed under hidden Gamescope. The rebuilt
Windows release emitted `NEXT_INTEGRATION_OK` under Proton/hidden Gamescope,
including the release-safe coasting checks. The wrapper required timeout cleanup
(exit 137); this is not a clean wrapper-exit claim. The spatial gameplay check that
failed on the previous commit now passes with the moving-interior implementation.
The planetary regression's former world-UP expectation was updated to the parked
hull's deck normal, with an additional physical floor-support check.

## Persisted flight momentum

Flight locations now include an optional world-space velocity vector. Saving while
aboard takes the moving hull velocity; saving at the helm takes stored flight
velocity, which survives a menu temporarily zeroing the public physics velocity.
Loading restores momentum after teleporting and resumes at the helm. No elapsed
offline travel is simulated. Legacy saves without this field start at rest.

The optional field accepts only three finite numbers with each component bounded
to 100000 m/s, and is rejected on non-flying locations. Normalization uses floats;
the existing transactional load boundary protects state from malformed saves.
The coasting gameplay check now loads while aboard, verifies helm momentum, saves
again through the menu and exercises legacy fallback. These checks passed native
headless and hidden Gamescope; the release-safe main smoke also checks momentum
roundtrip. Existing texture teardown warnings remain.

The focused save-schema test and existing state, spatial and planet gameplay
regressions passed. Windows export and ZIP packaging completed; the release
reported `NEXT_INTEGRATION_OK` under Proton in hidden Gamescope, including momentum
roundtrip. Wrapper cleanup again reached its timeout (exit 137). The Windows SDR
white-level warning remains. This is functional validation, not a 60 FPS benchmark.

## Cruise while walking aboard

An active route transfers from the pilot to the occupied modular hull on entering
the interior, and back on returning to the helm. Route waypoints and long-distance
leg planning use the hull's position while aboard. Walking and looking around do
not cancel the ship's route. Arrival stops the hull; the command deck provides a
Stop Cruise button. Plot new routes from the helm. Routes themselves are not
serialized: loading restores position and momentum at the helm with cruise off.

The hull turns toward its target. Each physics step applies its full transform
change to the interior, passenger, walking velocity and gravity, then flushes deck
collider transforms before passenger physics. Returning restores the actual hull
attitude and momentum. Rebasing shifts the hull, cabin, passenger and active target
together. Turning clearance uses a conservative hull-enclosing sphere; translation
uses the existing occupied module shapes and lookahead. This can stop cruise in
tight spaces where manual flight fits. Internal deck colliders are excluded from
both queries. Blocked routes stop safely with the passenger aboard.

Focused navigation tests cover movement, attitude, arrival, invalid inputs, forward
obstacles, blocked turns and internal collision exceptions. The full-scene test
passed in hidden Gamescope: an idle passenger stays on a turning deck, walks without
cancelling cruise, crosses a sector boundary, returns to the turned helm, traverses
two waypoints to arrival, stops via the real menu button and handles a blocked route.
Existing anchored/coasting interiors and planetary cruise regression tests passed.
The main release-safe integration smoke now also checks cruise and helm handoff.
NPC combat was still paused while aboard at this stage; the next increment removes
that restriction. Crew piloting/shared boarding remain separate unfinished work.
No large-interior frame-rate target is established.

Windows export and ZIP packaging completed. The Windows release emitted
`NEXT_INTEGRATION_OK` under Proton/hidden Gamescope with the new cruise-passenger
and helm-handoff smoke checks. The existing SDR warning remains; native graphical
teardown still reports seven texture RIDs. These warnings are not claimed fixed.

## Space combat with an occupied interior

Ship actors remain active while the commander walks aboard. Pirates choose between
the occupied hull and nearby fleet targets; hostile police target the hull too.
The hull exposes its occupied module shapes on the player collision layer. Ship
weapon rays exclude cabin geometry and the passenger capsule, but still respect
external world cover. They damage ship shields/hull, not suit health. Enemy aim
uses an occupied module center because custom multi-deck or sparse ships can have
empty space at the overall bounding-box center.

The former nearby-hostile entry restriction is removed. Fatal ship damage first
returns control from the interior, then uses existing ship destruction, rescue,
losses and persistent wreck creation at the current hull address. Docked interior
visits do not create an orbital target. Existing menu combat pauses remain; this
does not implement NPC boarding, ship interior damage or multiplayer boarding.

The full-scene headless and hidden Gamescope tests verify real pirate firing while
coasting through an origin rebase, shield damage with intact suit health, external
cover blocking a shot, and fatal rescue with a saved wreck at the hull address.
Actor tests cover occupied-module aim on a sparse hull and reject deleted targets.
Cruise, coasting, fleet combat and the native integrated smoke passed. The smoke
also ray-fires on its multi-deck occupied ship; these are physical ray tests rather
than direct damage-only calls.

The rebuilt Windows release emitted `NEXT_INTEGRATION_OK` under Proton in hidden
Gamescope, including the occupied-hull weapon ray. Windows ZIP packaging completed.
The SDR white-level warning persists; no renderer-warning fix or frame-rate target
is claimed by this increment.
