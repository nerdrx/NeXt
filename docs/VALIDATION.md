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

## Named gunner ship defense

A named gunner can take a persistent `defend` order on the commander's ship. The
domain rejects the wrong role, busy crew, missing weapons and duplicate defense
assignments. Existing operation payroll pays every 300 hosted seconds; insufficient
credits pause firing and restored wages resume it. This follows the existing
operation model, including the initial work interval before the first wage is due.
The save loader validates order shape, gunner role and uniqueness transactionally.
An existing order may remain during a weapon refit; no weapon means no fire.

The gunner searches active hostile NPC ships within 720 m for a clear mounted shot.
Weapon origins use the modular hull bounds and a local dorsal offset of 1.6 m.
Occupied hull boxes are tested even though the player's physics body is excluded
from the world ray. External cover and other vessels still block fire; the gunner
can choose another visible hostile instead of repeatedly selecting a covered one.
The same shield/hull damage and bounty path used by player weapons applies, at a
0.75-second firing interval. Neutral and remote player ships are not targets.

The Crew Operations menu exposes assignment and cancellation. Integration testing
also found a pre-existing callback lifetime bug: bound methods referred to temporary
RefCounted order controllers that had been freed. The main scene now retains the
controller for its current GameState and replaces it when visiting/returning worlds.
Keyboard focus follows the command-deck scroll area. The new control was inspected
in a 1440x900 hidden Gamescope capture.

Focused domain and fire-solution tests passed. The full gameplay test passed under
hidden Gamescope, exercising the real menu, persisted assignment, mounted firing
while aboard, wage pause/resume, cover, neutral safety, one bounty and persisted
cancellation. Existing crew, operations, fleet and visit regressions passed. The
release-safe native smoke hires a gunner and observes actual damage while coasting.

This does not add a physical crew character or animated turret gimbal, NPC boarding,
or PvP automation. Existing procedural beams and weapon shapes remain placeholders;
the asset checklist records the turret attachment requirement. Menus retain the
existing combat pause. Crew piloting and authored crew/turret assets remain work.

Windows export and ZIP packaging completed. The release reported
`NEXT_INTEGRATION_OK` under Proton in hidden Gamescope, including observed gunner
damage while aboard. The existing SDR warning remains; these checks do not establish
the target frame rate or remove previously documented renderer warnings.

## Physical named crew aboard

Crew bodies are children of the moving interior, with gravity along the local deck normal. Deterministic capsule clearance selects standing positions through furnished, rotated, multi-deck layouts, up to 12 bodies. Unassigned crew and ship-defense gunners appear aboard; crew assigned to remote operations do not. F opens Crew Operations with the nearby visible crew member selected. Menu actions rebuild the roster representation. Fatal body damage cancels the order, dismisses the named crew member and saves the loss. Exit invalidates delayed spawning.

`test_ship_crew`, `test_crew_positions` and `test_ship_crew_gameplay` pass headlessly. The gameplay test also passes in hidden Gamescope, covering named identity, floor support during coasting/turning/rebasing, interaction, defense status, saved casualty and rapid exit cleanup. The earlier interaction assertion stood nearer another crew member; the corrected placement verifies the intended nearest character. Ship-defense gameplay regression and normal-entrypoint smoke pass. The normal-entrypoint check now also requires a hired gunner to stand on the moving deck. These checks are included in Windows CI.

Crew currently remain at their posts. This does not implement crew piloting, work schedules, shared boarding or authored character art. Nonfatal character health is not persisted between interior visits. The existing seven Texture RID warnings still appear during graphical shutdown.

The Windows release export succeeded. Its normal-entrypoint integration check reached `NEXT_INTEGRATION_OK` under Proton Experimental in hidden Gamescope, including the new moving-deck crew assertion. The SDR white-level warning remains. This is functional evidence, not proof of target frame rate or live Steam multiplayer.

## Crew room placement

Crew standing positions now prefer unoccupied modules before sharing a room. Within that constraint, gunners prefer weapon modules then bridges, engineers prefer engineering/workshops, and traders prefer cargo then bridges. Other clear rooms are valid fallbacks. Existing capsule clearance, spacing, deterministic ordering and the 12-body limit remain. Bodies face their room center.

The rotating/coasting gameplay test passes headlessly and in hidden Gamescope after this change. The Windows release export and its normal-entrypoint integration check pass under Proton Experimental in hidden Gamescope. The existing SDR and graphical shutdown Texture RID warnings remain; no new graphics-performance claim is made.

The placement test validates its room layout before building, then covers role preferences, repeated-role distribution and fallback when preferred rooms do not exist, alongside real floor support and spacing. The corrected fixture passes in hidden Gamescope. CI for the preceding physical-crew commit `93a2d3c` completed successfully.

## Planet cloud shells and atmospheric limb

Atmospheric ocean worlds now render separate transparent cloud shells above the maximum height field. Seeded multi-scale noise produces drifting weather patterns, with day-side illumination and dark night-side clouds. This replaces the old cloud tint painted directly into terrain albedo. The atmosphere shell encloses the clouds and uses a softer limb and twilight color approximation. No weather bodies or collision shapes are created.

`test_planet_weather` validates shell eligibility, altitude and absence of collision children, and captures orbital, night-side and below-cloud views in hidden Gamescope. All three captures were inspected; the initial flat white patches were replaced with softer multi-scale patterns. The same-scene planetary landing/save/return regression passes. Windows export succeeds. These are cosmetic shells, not volumetric clouds, physical scattering, terrain shadows or a climate simulation. No frame-rate guarantee is inferred from these captures. The art checklist identifies replacement points.

The exported Windows build reached `NEXT_INTEGRATION_OK` through its normal entrypoint under Proton Experimental in hidden Gamescope. The shader logs show no compilation errors. The existing SDR white-level warning remains. The captured orbital view is published in `docs/planet-weather.png`.

## Cloud shadows on orbital and streamed ground

A shared shader include now provides cloud coverage to both the visible shell and ground shaders. Ground shading traces the sun direction to the cloud shell and samples that same seeded, animated pattern, with attenuation near the night side. SpaceWorld configures matching seeds, shell radius and sun direction on the globe and each streamed terrain patch. The model modulates ground albedo; it is not volumetric shadow transport and does not shade rocks, buildings or vessels.

The hidden-Gamescope weather test hides cloud geometry and compares the rendered ground with shadowing enabled/disabled, requiring a measurable brightness reduction. It also checks that streamed terrain receives the globe weather parameters. Import and shader compilation pass. Astronomical simulation accuracy is now an explicit separate target in VISION and ROADMAP; this cosmetic weather model does not satisfy the new gravity, thermal or orbital requirements.

A Windows shader compile caught a helper argument that reused the cloud shader uniform name `sun_direction`; the argument is now `sun_vector`. After correction, headless weather and landing tests, the hidden-Gamescope rendered brightness comparison, and the exported Windows normal-entrypoint integration check pass. The final shader logs contain no compilation errors. The bounded Proton wrapper exits 137 after the integration marker; this is not a clean-wrapper-exit claim. Shader uniform-list checks now cover all three weather consumers.

## Bounded thruster acceleration

Pilot and CoastingHull share FlightDynamics velocity commands, capped at 3 standard g for normal thrust and 6 for manual boost. The unit reference is 9.80665 m/s² ([NIST](https://physics.nist.gov/cgi-bin/cuu/Value?gn)); these flight limits are game tuning, not biological tolerance claims. Cruise speed is constrained by remaining braking distance and arrival waits until the final velocity can be stopped within the thrust budget. The HUD shows commanded translational thruster load, excluding collisions, gravity and rotational loads. Existing emergency/menu stop behavior is still instantaneous and remains a physical approximation to replace.

Focused checks cover physics-step independence, thrust/boost/braking limits, stopping distance and invalid inputs. The actual-scene check covers keyboard thrust/boost/braking, cruise with a walking passenger and zero-thrust coasting; it passed in hidden Gamescope and the HUD capture was inspected. Coasting-navigation, aboard-route and control regressions pass. The old nearby-arrival test assumed an instantaneous stop; it now verifies bounded braking before arrival. Existing texture shutdown warnings remain.

Flight-safety, impact/rescue, coasting-interior and saved-velocity regressions pass. The exported Windows normal-entrypoint integration reached `NEXT_INTEGRATION_OK` under hidden Gamescope/Proton, including an explicit cruising-hull thrust-limit assertion. The bounded wrapper ended 137 after that marker; SDR and texture warnings remain known. These fixed acceleration caps do not yet derive thrust from engine power, propellant flow or ship mass, and do not model crew physiology.

## Physical cruise cancellation and obstacle braking

Cruise stop requests now preserve velocity and brake at the normal thruster limit. Pilot braking continues with menus open while ignoring movement/fire input. Aboard braking persists through return to helm and departure from helm. Cruise obstacle lookahead uses stopping distance plus a frame-travel margin; a blocked route cancels guidance and begins braking rather than zeroing momentum. Swept collision and existing impact damage still handle unavoidable contact. This does not guarantee avoidance of moving obstacles or model collision/rotational crew loads.

The physical braking test measures stopping time, distance and acceleration from 100 m/s, menu-disabled braking, moving-hull braking and an actual autopilot approach to a wall. The gameplay test verifies stop-command momentum, aboard braking, helm handoff and menu input isolation. Existing safety, coasting-navigation, aboard-route, crew, spatial and long cruise checks pass. CI for the preceding acceleration commit failed an old 0.35-second sector-crossing assumption; the test now waits up to 120 physics frames for the physical crossing and passes locally.

The normal-entrypoint integration now explicitly verifies preserved momentum on Stop Cruise and decreasing speed while the menu remains open. It passes natively and in the exported Windows executable under hidden Gamescope/Proton, reaching `NEXT_INTEGRATION_OK`. The main gameplay menu/handoff check also passes in hidden Gamescope. Existing SDR and texture shutdown warnings remain.

## Cargo mass and engine force

Ship acceleration now derives from engine thrust divided by dry module mass plus cargo mass, retaining the 3 g normal / 6 g boost limits. Pilot and walkable-hull controllers use it for acceleration, cruise approach and obstacle stopping distance. Shipyard stats show loaded tonnes, thrust and available acceleration. The tuning assumptions and omissions are documented in SYSTEMIC_SIMULATION.md.

Focused checks pass for commodity buy/sell mass changes, engine and cargo-module additions, save/load derived stats, bounded acceleration and braking-distance calculations. The actual-scene test also passes headlessly and in hidden Gamescope: loaded cargo lowers measured thrust load, aboard braking uses the same limit, and adding an engine updates both controllers through helm handoff. Braking, coasting-navigation, aboard-cruise and sector-rebasing regressions pass. Native and exported Windows/Proton integration reach NEXT_INTEGRATION_OK. Existing texture shutdown and Windows SDR warnings remain. These checks do not establish real-world propulsion accuracy or target frame rate.

The previous CI run also exposed an outdated case-sensitive obstruction-message assertion. Its corrected check waits for completed braking, route cancellation and unchanged hull/shields; collision damage and rescue checks remain.

The bounded Proton wrapper ended with status 137 after the integration marker; this is not a clean-wrapper-exit claim. No script or shader compilation errors appeared in this run.

## Celestial catalog and physical survey

CelestialPhysics reference checks cover Earth surface gravity, the Sun–Earth orbital period and received radiation, equilibrium temperature, solar effective temperature, Schwarzschild radius, periapsis/apoapsis, orbital closure and invalid inputs. Scalar formulas use logarithmic arithmetic to avoid intermediate overflow; tests include finite extreme values whose direct intermediate products overflow. Generated systems use scalar doubles, not astronomical-scale Vector3 coordinates.

Catalog tests cover all existing stellar categories over 100 seeded systems, deterministic regeneration, non-crossing initial radial orbit bands, and radiation/temperature changes caused by the same changing orbital distance. Four pre-change legacy catalog hashes remain identical. Persisted calendar save/load restores the sampled orbital/thermal state. The Navigation survey test checks selection, live calendar refresh and page cleanup; it passes headlessly and in hidden Gamescope, and the rendered capture was inspected for readability.

These are a physical data foundation and survey, not implemented physical-scale flight. The current collision/rendering bodies remain compressed and fixed, as the survey explicitly states. Planetary force integration, greenhouse warming, thermal inertia, accretion, relativistic trajectories, tidal effects and multi-body perturbations remain unimplemented. The migration requirements are recorded in SYSTEMIC_SIMULATION.md.

The exported Windows normal-entrypoint check opens the physical survey and verifies a populated label and positive home-system radiation sample using release-safe checks. The final Windows build reached NEXT_INTEGRATION_OK under hidden Gamescope/Proton with no script or shader compilation errors. The native full integration also passed. Existing SDR and texture shutdown warnings remain.

The final bounded Proton wrapper ended 137 after the integration marker; wrapper shutdown is not claimed clean.

## Region-aware astronomical addresses

SectorPosition version 2 adds regions of 2^30 sectors while preserving the existing 8192 m local sector size. Tests cover positive/negative region boundaries, transactional capacity overflow, far-direction queries, scalar-double conversion at multiple AU and 10,000 AU, metre offsets, JSON round trips, and normalization of version-1 extreme sector values. The JSON test caught strict int/float membership in the version guard; explicit validated integer comparison fixes raw JSON loading.

Actual-scene tests restore a ship in region (5000, -3000, 0), cross the adjacent region boundary, cruise locally, save/reload, render another ship with a 0.25 m relative offset, and recover a wreck only at the correct remote address. The same check passes in hidden Gamescope. Loopback PvP now exercises nonzero regions for normal host/client shots, retaining consent, freshness, occlusion, cooldown and authority checks. Standard network, saved-flight, spatial gameplay and coasting-interior regressions pass.

This removes an address-range blocker; it does not move rendered planets into their catalog orbits or generate objects in empty remote regions. Physics positions remain bounded and the current culling distance is unchanged.

Native and exported Windows normal-entrypoint integration now explicitly restore region 5001, save/reload it, and check bounded player coordinates and retained velocity. Both reach NEXT_INTEGRATION_OK; the Windows run uses hidden Gamescope/Proton. No script or shader compilation errors appeared in that run. Existing SDR/shutdown warnings are not considered fixed.

The bounded Proton wrapper ended 137 after the integration marker; clean wrapper shutdown is not claimed.

Final review also found that remote cruise directions omitted within-sector offsets beyond the relative-position cap. The shared direction helper now includes them; a regression checks the transverse offset just beyond 1,000 km. The corrected helper and far-region gameplay tests pass.

## Large-radius terrain precision

The new terrain test builds an Earth-radius patch in a local surface frame and checks finite bounded vertices, sub-millimetre centre height, a double-normalized anchor on the sphere, outward collision and a resting walking capsule. It also checks the curvature formula with a small elevation at a 38,000 km radius. Seven material noise origins remain bounded below 256 lattice cells. The test passes in hidden Gamescope; its ground capture was inspected. This is a renderer/collision preparation check, not evidence that the main flight scene now uses physical planet sizes or meets the frame-rate target.

Existing compact-planet terrain and landing/liftoff tests pass with the new geometry formula. Procedural rocks and materials remain placeholders listed in ASSET_CHECKLIST.md.

Large-radius geology checks cover the longitude seam, north and south poles, a near-pole patch, repeatability and shared rock positions across recentering within 1 mm. An initial local run measured 1–36 ms. Tightening large-world candidate selection reduced the slow 38,000 km near-pole query from 36 ms to 2 ms in the next run; the first query, including height-field initialization, remained 31 ms and subsequent queries took 1–5 ms. These are individual placement-query timings, not frame-rate measurements. Compact-world visual/collision transforms retain the original path and the existing geology regression passes.

The native integration and final exported Windows executable both reach NEXT_INTEGRATION_OK, including a release-safe Earth-radius patch check. The Windows run used hidden Gamescope/Proton; its logs contain no script or shader compilation errors. The bounded wrapper ended 137 after the marker, so clean wrapper shutdown is not claimed. The Windows ZIP was rebuilt from this export. The weather shadow render comparison also passes with the bounded material coordinates; existing SDR and texture shutdown warnings remain.

## Oriented celestial and rotating surface frames

Celestial catalog v2 adds independent seeded orbit orientations, axial tilt and spin phase. The frame tests check quarter-orbit coordinates, analytical velocity against numerical position derivatives on an eccentric tilted orbit, prograde equatorial speed, pole invariance, spin closure, and a tilted Earth-radius surface's velocity at an AU-scale offset. A 0.25 m displacement at 1 AU survives SectorPosition conversion within 1 mm. Invalid inputs and missing v1 orientation fields are covered.

The system regression also checks combined orbital and surface velocity against a numerical derivative, day/night direct illumination from rotation, deterministic catalog generation, legacy world hashes and saved calendar continuity. Physics reference tests pass. The survey test passes in hidden Gamescope, and its capture was inspected: spin, tilt, inclination and reference-site daylight remain readable in the scrolling planet list. Native normal-entrypoint integration reaches NEXT_INTEGRATION_OK with a release-safe check for the new daylight display.

These checks validate a sampled ephemeris and illumination model, not moving runtime planets, flight gravity or ship thermal consequences. The compact scene remains stationary. Returned velocities use physical seconds, while the survey's ephemeris uses the accelerated calendar; runtime time/frame migration remains necessary. Surface input vectors and local orientation Basis values retain Godot's float precision, as documented in SYSTEMIC_SIMULATION.md.

The final Windows export reaches NEXT_INTEGRATION_OK under hidden Gamescope/Proton, including the new daylight display check. No script or shader compilation errors appear in its logs. The bounded wrapper ends 137 after the marker; existing SDR and texture shutdown warnings remain. The Windows ZIP was rebuilt from that export.

## Physical time independent of economy settlement

GameState now persists a physical epoch that advances one second per active second. The economy retains its 1,200-second days and jump settlements. Missing epochs derive the former survey instant once on load; invalid epochs reject transactionally. Checks cover v1/v2/v3 migration, split time steps, no offline advancement, jump invariance, capacity rejection, and orbital velocity against position change per physical second. Existing calendar, full state and celestial system tests pass.

The real main-scene visitor regression confirms adoption of the host's epoch, periodic updates affecting only visiting state, paused home time on return, and replacement of an old visit epoch on rejoin. The native normal-entrypoint check explicitly verifies that crossing an economic day boundary advances physical time by the frame duration. The survey also passes in hidden Gamescope. Host snapshots use no latency compensation and do not establish synchronized moving-body collision or shared economy authority.

The clock loopback test passes under hidden Gamescope, covering welcome, periodic and travel snapshots, invalid values and an unauthorized guest clock RPC. Godot emits the expected authority-rejection error for that deliberate request; both peers complete acknowledged checks. The existing network regression also passes. The final exported Windows executable reaches NEXT_INTEGRATION_OK under hidden Gamescope/Proton with no script or shader compilation errors. Its bounded wrapper ends 137 after the marker; existing shutdown/SDR warnings remain. The Windows ZIP was rebuilt from this export.

## Reactor-limited boost

GameState derives generation, nominal demand and engine power demand from installed modules. Spare power limits extra engine thrust. Tests cover valid refits reducing reserve, reactor additions restoring reserve, cargo mass reducing boosted acceleration, and a no-engine fallback. Derived values remain outside save data. FlightDynamics checks the explicit boost acceleration budget, invalid inputs and the 6 g cap.

The main-scene test runs the actual Pilot physics callback with forward/boost input for equal fixed steps. Two shield additions consume the starter ship's spare power; Shift then produces the same acceleration as ordinary thrust for that build. An additional reactor restores a measurable boost. This passes in hidden Gamescope, and the captured shipyard shows readable generation/demand, boost acceleration and extra-thrust information. Existing cargo-mass, flight-load and shipyard regressions pass. Native integration reaches NEXT_INTEGRATION_OK with a release-safe check that the boost budget reaches Pilot.

Power ratings are abstract and nominal demand is always reserved. These checks do not establish dynamic batteries, damaged reactors, heat, propellant flow or power redistribution. Boost target speed remains a flight-assist tuning limit.

The final Windows export reaches NEXT_INTEGRATION_OK under hidden Gamescope/Proton. No script or shader compilation errors appear in the run. The bounded wrapper ends 137 after the integration marker, so clean wrapper shutdown is not claimed; known SDR and texture shutdown warnings remain. The Windows ZIP was rebuilt from the validated export.

## Impulse-based propulsion fuel

The shared GameState limiter spends fuel on applied translational delta-v times loaded mass. Tests verify impulse cost, cargo mass, split/lumped commands, partial-budget residual velocity, invalid commands, save/load continuity, and emergency delivery with debt and repeat rejection. Main-scene checks pass in hidden Gamescope for a free-coasting walkable hull, fueled braking, a fuel-limited arrival, return-to-helm momentum and the pilot's own empty-tank arrival guard. Both controllers defer arrival until the limited velocity actually stops. Collision velocity changes bypass the fuel limiter.

Existing hull, navigation, braking, flight-load, reactor-boost and coasting-interior regressions pass. Native normal-entrypoint integration reaches NEXT_INTEGRATION_OK, including a release-safe partial-fuel momentum check. The Windows recovery-page capture was inspected for the emergency fuel action and its fee/debt explanation. The delivery remains an immediate menu abstraction; fuel mass, rotational propellant, tank capacity by module and supplier logistics remain absent.

The final exported Windows executable reaches NEXT_INTEGRATION_OK under hidden Gamescope/Proton, with no script or shader compilation errors in the run. Its bounded wrapper ends 137 after the marker; known SDR and texture shutdown warnings remain. The Windows ZIP was rebuilt from this export.

## Optional inertial flight

The main-scene inertial-flight test passes in hidden Gamescope. It checks default assisted braking with fuel use, momentum and fuel preservation with input disabled, camera-axis thrust that preserves transverse velocity, travel beyond the assisted speed target, explicit braking, B-key routing, empty-tank drift and autopilot guidance. Temporary settings files verify preference persistence and the assisted default for older settings. The rendered Flight Settings page was inspected for readable toggle, explanation and brake action.

The shared acceleration helper retains the previous acceleration/boost validation tests. Native normal-entrypoint integration reaches NEXT_INTEGRATION_OK. Inertial mode changes translational control only; angular momentum, rotational propellant, relativistic effects and physical-scale planetary motion remain unfinished.

The final native and exported Windows normal-entrypoint checks explicitly disable assist and input, then verify preserved velocity and fuel in inertial flight. Both reach NEXT_INTEGRATION_OK. The Windows run used hidden Gamescope/Proton with no script or shader compilation errors; its bounded wrapper ended 124 after the marker. Clean wrapper shutdown is not claimed. The Windows ZIP was rebuilt from this export.

## Drive heat and cooling

Drive thermal domain checks passed for heat per consumed fuel, partial impulse at the thermal ceiling, preserved momentum/fuel at cutoff, cooling and restored acceleration, invalid time steps, refit continuity and transactional save validation. The actual main-scene test passed under hidden Gamescope and headlessly: a hot drive produces less helm acceleration, physics ticks restore available thrust, carried ships retain temperature and walkable hulls use the same limiter. The 600 K HUD capture was inspected and shows 50% available thrust without overlap.

Existing fuel, reactor reserve and visitor-isolation regressions passed. The native main-entrypoint integration and exported Windows executable under Proton both emitted NEXT_INTEGRATION_OK, including release-safe thermal cutoff and cooling checks. No script/shader errors were found in those logs. Windows export succeeded; the Gamescope/Proton wrapper required timeout termination (exit 137) after the success marker. The Windows ZIP was rebuilt. CI includes both new tests. These checks establish the tuned drive-loop interaction, not environmental heating, full thermal engineering or a performance target.

## Modular radiator construction

Radiator domain checks pass for installation/removal, effective exposed area, cooling proportional to area, mass-dependent acceleration, adjacent-module and armor/window occlusion, fully enclosed modules, refit temperature continuity, saved designs and accepted network module kinds. Existing drive-heat and ship-layout regressions pass. The native integration includes a release-safe module installation and increased-cooling assertion. The radiator visual fixture ran in hidden Gamescope; its capture was inspected for visible ribbed faces and module bounds. The shipyard displays effective area, and the authored-asset replacement task is recorded.

This validates immediate-neighbor and panel occlusion only. It does not establish a full radiation view-factor model, performance with a radiator-heavy maximum-size ship, or live Steam interoperability. Matching client builds are required for the new module kind.

The final radiator Windows export succeeded and its Proton run emitted NEXT_INTEGRATION_OK with the new radiator cooling assertion. No script/shader errors were found; the Gamescope/Proton wrapper timed out after completion (exit 137). The Windows ZIP was rebuilt. Both CI runs for the preceding drive-heat commit 43b4d66 completed successfully; radiator CI is pending publication.

## Thermal signature and target acquisition

Thermal signature tests passed for temperature-to-the-fourth emission, area scaling, inverse-square detection range, the range cap and invalid inputs. The actual scene test passed under hidden Gamescope and headlessly: at 1.5 km a pirate ignores a 300 K player ship and acquires a 600 K ship; cooling below the threshold removes its target. World cover blocks acquisition, removal restores it, an occupied walkable hull retains the same signature, and police hostility is unchanged. Reciprocal NPC detection passes inside 1.8 km and fails beyond that range. The HUD capture was inspected and shows nominal 3.2 km visibility at 600 K.

Existing fleet combat, aboard combat, drive thermal and radiator regressions passed. Native integration and the Windows export under Proton emitted NEXT_INTEGRATION_OK, including a release-safe thermal-range check. The export completed without script/shader errors; this is not a benchmark or multiplayer stealth validation. NPC signatures remain fixed approximations and contacts have no search memory.

The thermal-signature Proton wrapper required timeout termination after the success marker (exit 137). The Windows ZIP was rebuilt. Both new thermal tests are included in CI.

## Lost-contact search behavior

The actual-scene contact-search test passes for hot acquisition, cold loss, remembered-point pursuit while the hidden player moves in the opposite direction, no firing without a current contact, reacquisition, paused clocks, invalid time steps, origin shifts, expiry toward home patrol and passive-state clearing. Actors, fleet combat, thermal detection and aboard combat regressions also pass. The new search test is included in CI.

Native integration and the exported Windows executable under Proton emitted NEXT_INTEGRATION_OK, including a release-safe observed-position check. Windows export succeeded and the ZIP was rebuilt. These checks do not establish obstacle-aware route planning, coordinated search or persisted NPC knowledge; search memory is transient local simulation state.

The search-build Proton wrapper required timeout cleanup after the success marker (exit 137); no script/shader errors were found. The preceding radiator commit f4791e9 passed both CI runs.

## Local NPC obstacle avoidance

The NPC movement fixture passes with a wall wider than the normal patrol wander: a blocked direct command selects a lateral route, the ship clears the wall and continues toward its destination. The enclosed-room check returns a zero velocity command. An earlier graphical fixture passed in hidden Gamescope; the strengthened wide-wall fixture passes headlessly. Actor targeting, fleet combat, aboard combat and last-contact search regressions pass.

Native main-entrypoint integration and the Windows export under Proton emitted NEXT_INTEGRATION_OK, including a release-safe sphere-sweep detour check against a real StaticBody3D. Export succeeded and the Windows ZIP was rebuilt. This validates a finite-wall case and bounded local steering, not global navigation, dense-traffic avoidance or a many-NPC performance target. Thermal detection commit 68dd785 passed both CI runs.

The avoidance-build Gamescope/Proton wrapper required timeout cleanup after success (exit 137). No script/shader errors were found in the integration/export logs.

## Local hired traders

Local trade checks pass for arrival-gated settlement, unchanged wages/cargo while waiting, one leg per readiness observation, distant two-leg progression, save/load at the waiting boundary, passive actor materialization, acceleration toward a travel target, sector-relative destinations, persistent damage, disabled actor removal, same-frame trade-to-patrol reassignment and cancellation. Existing crew, fleet combat and contact-search regressions pass. The local freighter/captain capture was inspected under hidden Gamescope; the art checklist includes its replacement assets.

The main-entrypoint integration now verifies a local trader cannot settle from its timer alone and retires from the old scene on departure. Its first attempt incorrectly ran this space-only fixture from a surface instance; the next exposed an untyped empty array at the scripted call site. The fixture now returns to space and supplies an explicit Array[String]; the native integration passes. These fixes change the validation setup, not trade accounting.

This increment does not establish seamless NPC hyperdrive, physical loading, saved NPC flight positions, conserved supplier markets or shared multiplayer logistics. The previous obstacle-avoidance and contact-search commits passed both CI runs.

The final local-trader Windows export and Proton integration passed, with NEXT_INTEGRATION_OK and no script/shader errors. The wrapper required timeout cleanup after completion (exit 137). The Windows ZIP was rebuilt.


## Local trader flight persistence

Local trader snapshots preserve system-space position, velocity and trade phase. Native main-entrypoint integration passes with restoration of a displaced, moving trader and its unchanged endpoint. Existing local-trade, fleet-combat, crew-order and separate-world visit checks pass. The preceding local-trader commit also completed both public CI runs successfully.

Snapshots are optional for older saves. Current local snapshots are bounded to 1,000 km from the system origin and 1,000 m/s; this does not establish astronomical fleet trajectories. Patrol motion and distant voyages remain approximations. No art assets changed.

The Windows export completed and its main-entrypoint integration emitted NEXT_INTEGRATION_OK under Proton in hidden Gamescope. No script/shader errors appeared. The usual SDR warning remained and the wrapper required timeout cleanup after completion (exit 137). The Windows ZIP was rebuilt; this is not a performance benchmark.

The focused FLEET_FLIGHT_SAVE_OK check passes for moving-trader save/load, a different nonzero camera origin, fixed endpoint continuity, first-step momentum, cull/address preservation, legacy saves, malformed snapshots, route/phase mismatches and same-frame trade reassignment. Invalid loads preserve the existing state. The deliberately non-finite JSON fixture emits an expected exponent warning. This test is registered in CI.


## Finite market supply

MARKET_INVENTORY_OK verifies deterministic non-mutating stock reads, player purchase/sale conservation, exact batch settlement, no instant roundtrip profit, scarcity pricing, empty/full market rejection, sparse save/load, legacy defaults, invalid stock records rejected without changing state, separate world inventories, market-record capacity without eviction, and no automatic day-driven restocking. Fleet checks cover stock-limited purchases, cargo retained at a full destination, and a later delivery increasing destination inventory. The capacity test initially assumed an empty cargo dictionary; default cargo contains zero-valued commodity keys, so the assertion now checks cargo_total() == 0.

State, crew, faction pricing, local traders and visit regressions passed. Native integration passed with release-safe checks for player supply conservation and hired traders taking cargo from the same inventory. The earlier fleet-flight-persistence commit completed both public CI runs successfully.

Windows export completed and the main-entrypoint integration passed under Proton in hidden Gamescope. The new market-supply capture was inspected: available stock and whole-order prices fit the exchange layout. No script/shader errors appeared; the usual SDR white-level warning remains. This is not a performance benchmark or proof of shared multiplayer exchange authority. No art assets changed.

The Proton wrapper required timeout cleanup after NEXT_INTEGRATION_OK (exit 137), and the Windows ZIP was rebuilt.


## Supplied station industry

STATION_INDUSTRY_OK covers missing-input stalls, input-limited partial batches, every manufactured recipe, exact input depletion, full-output rejection without consumption, saved work resumed at its remaining second, output entering finite exchange supply, invalid/remote/full-storage delivery rejection, and a saturating production counter. The save fixture initially changed the system without recording a visit; using normal jump travel corrected the fixture. Existing raw-material station production and station docking regressions pass.

Review identified destination access and counter-overflow gaps. Supply and collection now require the exact owned-station dock, including the UI disabled state. The actual-scene check rejects a public concourse and flight/interior access, docks through the normal interaction, supplies inventory and presses the collection button. Collection fills remaining hold capacity even when the station stockpile is larger. The focused check passes headlessly and under hidden Gamescope; its station-industry capture is inspected. An earlier graphical teardown reported seven Texture RIDs; the final focused graphical run exited without that warning, with no script/shader failure; this is not a leak-free soak claim.

Native main-entrypoint integration passes with release-safe foundry shortage, input delivery and one-time consumption checks. No new save schema or art assets were introduced. Raw extraction/farming reserves, industry energy/heat and automated factory freight remain approximations or unfinished.

The final Windows export passed its Proton main-entrypoint integration in hidden Gamescope without script/shader errors. The usual SDR warning remained and the wrapper required timeout cleanup after NEXT_INTEGRATION_OK (exit 137). The Windows ZIP was rebuilt. The preceding finite-market commit completed both public CI runs successfully.


## Fleet purchase-cost records

TRADE_COST_BASIS_OK covers exact batch acquisition cost, inbound save/load, a depleted origin and changed day, a full destination delaying sale without changing cargo or cost, and eventual revenue minus the original cost. Its fixture explicitly proves that a current-origin-price estimate differs, so the previous calculation fails this regression. Older 13-field outbound orders establish cost on their next purchase; older inbound and carried/reassigned cargo report unknown cost and no fabricated margin. Negative-beyond-sentinel, fractional, string and excessive costs are rejected transactionally.

Crew, finite-market and local-trader regressions pass. Native and Windows/Proton main-entrypoint integrations pass with a release-safe purchase-invoice and changed-price sale check. The exported fleet capture was inspected and shows the current cargo purchase cost without clipping. No script/shader errors appeared. The usual SDR warning remains; the Proton wrapper required timeout cleanup after NEXT_INTEGRATION_OK (exit 137). The Windows ZIP was rebuilt. This is gross margin before wages, not a complete historical invoice ledger; older cumulative margin estimates remain preserved. No art assets changed.


## Automated station supply

STATION_SUPPLY_OK covers finite market purchases, recurring commander-funded escrow, no delivery sales income, full-storage waits, cancellation refunds, factory consumption of delivered ore, insufficient funding and recovery, remote routes, and transactional rejection of malformed station destinations. The actual scene check verifies local endpoint arrival, continuous position across phase changes, and saved flight restored after coordinate rebasing. Crew, purchase-cost, fleet-flight-save and station-gameplay regressions pass.

The focused hidden Gamescope run passed; its station-supply menu capture was inspected. Native and exported Windows/Proton main-entrypoint checks passed with release-safe station pickup/delivery assertions. No script errors appeared. Proton reported the usual SDR white-level warning and Gamescope reported a teardown window warning; its wrapper required timeout cleanup after NEXT_INTEGRATION_OK (exit 137). The Windows ZIP was rebuilt. These checks do not establish performance at the target resolution or multiplayer authority. No art assets changed.


## Fleet freight recovery

The focused fleet cargo recovery test covers atomic cargo transfer, disabled/local-vessel requirements, malformed positions, coordinate rebasing, partial and complete recovery, replay rejection, no salvage payout, save/load, invalid empty-blueprint salvage records, full registry rejection and completed-slot recycling. Repairing a courier after abandonment cannot deliver its missing cargo. Player recovery and station supply regressions pass.

Native main-entrypoint integration passes through actual ShipActor damage, cargo cache creation, save/load and recovery near the combat site. The first run exposed runtime StringName cargo keys from dotted assignment; normalization at the helper boundary fixed that case while preserving strict saved-data validation. The new procedural cache is listed in the asset replacement checklist. Cargo containers are stationary approximations; remote ambushes and pirate looting are not implemented by this change.

The final exported Windows build passed its main-entrypoint integration under Proton in hidden Gamescope. The corrected freight-cache capture was inspected: container and beacon are visible ahead of the cockpit. The usual SDR warning remained; wrapper timeout cleanup followed successful integration. No script/shader failures appeared. The Windows ZIP was rebuilt. Both public CI runs for the preceding station-supply commit completed successfully.


## NPC drive thermal interaction

The focused NPC thermal check uses live actors to verify thrust heating, coasting cooling without deleting momentum, heat-limited acceleration, varying emission, inactive simulation pause, and bounded temperatures. Fleet temperature save/load, missing-field compatibility and transactional rejection of 299 K, 701 K and string values pass. Scene detection explicitly loses a cooled NPC and reacquires the heated same ship at the same distance.

Station supply arrival, local trade, fleet flight persistence, contact search, thermal detection and obstacle avoidance regressions pass. Contact search previously assumed near-instant reversal after expiry; the updated check requires acceleration toward home followed by reversal after braking. Native main-entrypoint integration verifies captured and restored fleet temperature alongside its physical damage check. Distant NPC thermal state is frozen and generic scene regeneration still resets unowned ships.

Windows/Proton main-entrypoint integration passed under hidden Gamescope. The exported fleet screen was inspected and the drive-temperature line fits. The usual SDR warning remained; the wrapper needed timeout cleanup after NEXT_INTEGRATION_OK (exit 137). No script/shader failures appeared. The Windows ZIP was rebuilt. No art assets changed.


## Session loadout authority

The existing multi-process network test now verifies that the joined panel layout remains unchanged across host travel; it still checks normal pose relay, world identity and departures. PvP transport and actual-scene gameplay regressions pass, including consent, occlusion, shield/hull effects and hit feedback. This is a protocol boundary for joined designs, not authoritative health or ownership verification. The preceding freight-recovery commit completed both public CI runs successfully.

NETWORK_LOADOUT_OK verifies separate module-only and layout-only mutation attempts through both normal publishing and forged ENet RPCs, unchanged host timestamps on rejection, harmless module reordering, subsequent normal pose relay, bilateral PvP and fresh-design negotiation after reconnect. All pass natively. Windows export succeeds, but direct exported-script Proton attempts did not reach a test marker before their bounded timeout; Windows protocol execution remains unverified for this increment. Visual drafts are separate uncommitted work and were not accepted by the owner.


## Fleet material and geometry draft — 2026-09-27

Fleet actors now use separate procedural patrol/freight models and a convex exterior collision proxy fitted to their meshes. Dielectric paint and exposed metal use distinct roughness/metalness values; painted trim does not emit light. Armor and engine normals, concave panel triangulation, structural bevels and canopy placement were corrected during front/rear capture review.

Native Godot checks passed: main integration smoke, NPC thermal behavior, obstacle avoidance, and the new fleet geometry/collision regression. The regression checks closed bevel topology, outward normals, concave panel area, wing ray hits, exterior misses and rotated collision. Hidden Gamescope captured both models from front/rear plus patrol materials under the actual game hangar environment without script or shader errors. The Windows export succeeded; this pass has no fresh Windows/Proton runtime or frame-rate result.

These are work-in-progress procedural assets, still below the supplied reference quality. Studio reflection lighting is deliberately separate from the gameplay hangar capture. Detailed wear, integrated equipment design, interiors visible through glazing and final authored art remain incomplete. Station and character drafts are not part of this ship increment.


## Hybrid ship blueprint foundation — 2026-09-27

The user accepted the compact fighter as a starter placeholder and selected designed hull families with configurable rooms/equipment for larger ships. `ShipBlueprint` now centralizes cell pitch, pressure-shell dimensions, floor/headroom datum, collision dimensions and centering. Pathfinder and Merchant are initial connected layout definitions, not yet purchasable or styled final hull families. Existing custom ship construction remains intact.

The former interior walls exceeded the exterior pressure shell. Modular shell width and small chamfers now enclose them, and flight/coasting/remote collision, landing clearance and preview framing account for the expanded envelope. The blueprint regression builds real exterior/interior meshes for both families, verifies interior collision corners against the convex chamfer faces, validates room compatibility and walkability, and checks coasting collision placement. Native main smoke, anchored interior, interior glass, flight collision, coasting collision and coasting navigation checks passed. Windows export succeeded; no fresh Proton runtime result is claimed.

The preceding cosmetic draft is included: small armor bevels with topology-safe fallback, sensor housings, shaded service stencils, restrained bloom and localized hangar ambient fill. Focused bevel tests preserve rectangle/concave footprints on both upper and lower surfaces; hidden Gamescope front/rear/detail/hangar captures were inspected. Fleet silhouettes remain exterior-only and are not claimed to contain these interiors. Family shipyard selection, persisted family identity, coherent family exterior generation and fleet boarding integration remain outstanding.

The native graphical main-entrypoint integration also passed under hidden Gamescope (`build/blueprint-visual-smoke.log`, `NEXT_INTEGRATION_OK`). The captured aboard view was inspected; floor, doorway and ceiling remain visible and traversable in the integration flow. This does not validate final family styling or Proton rendering.


## Shipyard hull-layout refits — 2026-09-28

Ship architect now opens a family-layout comparison page with a read-only rotating model/deck-plan preview, selected room role, capacity-compatible refit action and explicit gross price/trade-in/net due or refund. Refitting replaces the current module assembly and room/panel layout with family defaults; cargo and crew are preserved, hull/shield fractions carry over, and fuel/heat remain unchanged. Trade-in is 50% of module cost weighted by current hull condition. The existing module/layout save format remains the source of truth; no unsaved family metadata is introduced.

The transaction rejects unknown or already-installed layouts, inadequate cash, cargo/crew overflow and destroyed ships before mutation. The controller blocks refits during flight, aboard an interior or connected to a visit. Focused tests passed for exact pricing, refunds, damage/resource/crew preservation, atomic rejection, save reload and the actual guarded UI action. Existing shipyard gameplay passed. The new page/refit was exercised under hidden Gamescope and its screenshot inspected; price and action remain above the model preview. Windows export succeeded. No fresh Proton runtime result or final family-art quality is claimed.


## Connected family pressure skins — 2026-09-28

Pathfinder and Merchant now generate one connected pressure-shell mesh from their occupied room cells. Deterministic polygon union preserves concave footprints; custom footprints retain modular shells. Fleet armor and family hulls share the existing bevel-safe prism builder. Surface panels, radiators, roof fittings and engine outlets follow the enlarged pressure envelope instead of remaining buried in it.

Native blueprint tests passed for room/collision containment, reordered modules and exposed fittings on all six faces. Fleet geometry/collision and hull refit/save/UI regressions passed. The refit test also passed under hidden Gamescope; four actual family exterior/cutaway captures were produced with `tests/capture_hull_families.gd`, and the Pathfinder exterior was inspected for roof intersections. Windows export succeeded. These are structural blockouts, not accepted final ship art; fresh Proton runtime remains unverified.


## Commissioned fleet hull families — 2026-09-28

Crew Operations can commission a legacy utility vessel, Pathfinder or Merchant. Family costs sum blueprint module prices, cargo capacity derives from the same module statistics, and the registry saves a validated family identifier. Local family actors now use the corresponding ShipVisual pressure hull independent of their current order; legacy utility behavior remains compatible. Family capacity mismatches and unknown identifiers reject atomically on load. Definitions require deliberate save migration if their capacities change later.

The new fleet-family regression passed purchase pricing/deductions, rejected transactions, save roundtrip, malformed records, legacy records, family actor meshes and actual main-scene trader respawn. Existing crew, fleet combat, fleet-flight save and fleet collision regressions also passed. Hidden Gamescope passed the new integration and produced `user://fleet-families.png`; the commissioning controls and registry were visually inspected at 1440x900. Windows export succeeded. Fleet boarding, custom fleet rooms and family-specific combat/drive statistics remain incomplete; no fresh Proton runtime result is claimed.


## Fleet family mass and propulsion — 2026-09-28

Commissioned local hulls now derive drive statistics from their blueprint, add physical cargo mass, use loaded thrust-to-mass acceleration and charge drive heat from actual impulse. Their approach command accounts for available braking acceleration. Existing actors refresh cargo mass when fleet state changes.

The fleet-family regression passed blueprint drive values, actual one-step motion for empty versus 160 t loaded Merchants, radiator cooling plus impulse heating, loaded near-target braking and spawn/sync/respawn mass propagation. Its fixture disables automatic physics after tree entry so the manual tick is isolated. Headless and hidden Gamescope runs passed; existing fleet gameplay, flight-save and NPC thermal tests passed. Windows export succeeded. This does not establish distant strategic physical flight, family-specific damage/shields/weapons or Proton runtime validation.


## Braking-aware fleet obstacle sweeps — 2026-09-28

AI steering now uses available acceleration for its obstacle horizon and separately checks the ship's current inertial stopping path. Regression tests place a real wall 400 m ahead: weak braking detects it both while coasting toward it with a sideways command and while planning from rest; stronger braking preserves clear commands when the wall remains outside its stopping horizon. Existing finite-wall progress, direct-path recovery and enclosed-stop cases still pass. Native headless and hidden Gamescope avoidance checks passed, alongside fleet family, thermal and fleet combat regressions. Windows export succeeded. Local heuristic avoidance is not global pathfinding or a general collision-free guarantee.


## Modular roof equipment and armor shading — 2026-09-28

Replaced emissive roof symbols with mechanical service covers, vents and paired cargo hatches; lowered painted fitting metalness and removed canopy/trim emission. Flat armor normals fix warped triangular highlights, and engine braces no longer obscure the exhaust disks. The family capture now includes rear views as well as exterior/cutaway views.

Blueprint containment and new flat-normal regression passed; fleet-family integration passed. Six actual renderer captures completed under hidden Gamescope, and Pathfinder front/rear views were inspected during correction. The silhouettes remain rectangular pressure blockouts, not accepted ship art. Windows export succeeded; Proton runtime remains unverified.
