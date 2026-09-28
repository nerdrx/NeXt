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


## Family material capture diagnosis — 2026-09-28

Confirmed the dark gray shell uniform and upward roof normals, then reproduced the roof washout using native StandardMaterial3D under the original lights. Adjusted only the family inspection light setup and added a reproducible `--standard-material` comparison mode with matched PBR properties. Both normal and comparison modes produced six captures each under hidden Gamescope without script errors; Pathfinder exterior comparisons were inspected. The reduced highlight reveals the current material and blockout geometry more clearly. No gameplay shader, geometry or lighting change is claimed by this diagnostic increment.


## Sloped family hull profiles — 2026-09-28

Added a flat-normal section-profile mesh builder and family-specific beam/length flare around unchanged pressure rooms. Optional fittings project to the nearest outward hull triangle. Family collision envelopes now include the armor in piloted, coasting and visitor hulls, navigation radius, landing/berth clearance and shipyard framing; arbitrary custom footprints retain their existing envelope. These remain conservative box approximations rather than exact profile collisions.

The blueprint regression checks real interior collision corners inside the closed rendered hull, shell vertices within collision envelopes, fittings outside the angled shell, piloted/coasting shape dimensions and custom-layout compatibility. It passed alongside family refit/save and fleet-family regressions. Existing flight collision, coasting collision and coasting navigation checks passed under hidden Gamescope. Six family captures completed and Pathfinder front/Merchant rear were inspected. Hidden Gamescope main gameplay smoke passed (`NEXT_INTEGRATION_OK`); Windows export succeeded. Art quality and Proton runtime remain unproven.


## Docked owned-fleet interior inspection — 2026-09-28

Crew Operations now exposes Inspect Docked Interior for local idle Pathfinder/Merchant vessels. Inspection builds the commissioned family rooms at a separate service berth and returns the player to the original concourse position/view without replacing their active ship or cargo. An ephemeral occupied-vessel lock prevents crew dispatch while inside. Missing, remote, destroyed, legacy, active-order/in-flight, planetary, flying and connected-visit cases reject entry. Fleet HUD shows the inspected vessel's health and hold, not the active ship's fuel/shields.

Entry faces an adjacent room, and bridge seats moved beside the center passage after the walking regression demonstrated an obstruction. The new regression drives the actual menu button, checks family layout, physical floor/doorway traversal, loadout preservation, atomic dispatch rejection, unlock/return and entry guards. Hidden Gamescope passed and `user://fleet-interior.png` was inspected. Existing anchored and crew/coasting interior tests passed; the anchored fixture now uses a unique save path before scene startup to avoid dependence on the user's commander save. Windows export succeeded. Moving fleet boarding, shared multiplayer interiors, and fleet helm transfer remain unfinished.


## Fleet room and hull refits — 2026-09-28

Commissioned family vessels now retain optional validated room/panel layouts. Crew Operations opens a read-only family deck preview with room and exposed-face panel refits using the existing ShipLayout compatibility rules and prices. Transactions reject invalid, unaffordable, remote, destroyed, occupied or assigned vessels before changing credits or layout; the scene also requires a docked commander outside a network visit. Old fleet saves without the optional layout use family defaults. Actor appearance/radiators and boarded interiors consume the stored layout.

These refits change room fittings and hull faces within the fixed family assembly. They do not yet replace fleet modules, transfer the player helm or enable shared multiplayer interiors.

The new integration test passed natively and under hidden Gamescope: actual menu callbacks, credit charges, save reload, boarded layout, additional actor armor meshes, atomic rejections and strict legacy/malformed-save handling. Existing fleet boarding, fleet families and player ShipLayout tests passed. The 1440x900 refit screenshot was inspected and controls condensed so the model/deck preview remains visible. Windows export passed; fresh Proton runtime remains unverified. The graphical test emits a seven-texture RID shutdown warning, so clean graphics-resource teardown is not established.


## Family hull strength and weapon damage — 2026-09-28

Family actors now derive maximum hull strength and weapon damage from their module stats. Actor hp remains a 0–100 condition value for saves, retreat decisions and repair; unabsorbed damage is converted to that percentage using the actual hull capacity. Legacy actors retain 100 hull points and 9 damage. The firing controller uses the actor damage rating for opposing fleet ships, piloted vessels and occupied coasting hulls. Existing base armament remains part of GameState stats; these hull families have no additional weapon modules. Fleet shields remain disabled by the existing spawn path pending durable shield state and recharge integration.

The focused family combat regression passed for both families, shield overflow, preloaded hull condition and legacy behavior. The fleet-family integration verifies damage is stored as 75% condition, survives save reload and respawns at the same condition. Fleet gameplay and aboard-combat regressions passed; the latter now verifies a changed actor damage rating reaches the occupied hull. Hidden Gamescope aboard combat passed and Windows export succeeded. No fresh Proton runtime result is claimed.


## Persistent local fleet shields — 2026-09-28

Loaded family actors now use module-derived shield capacity. Hits delay recharge for six seconds, then charge grows by five points per second up to capacity. Crossing the delay boundary grants only the remaining elapsed time. Charge and delay are captured on damage and during fleet/save synchronization, restored on actor spawn, and strictly validated as an optional family-only save record. Older records start empty. Legacy utility vessels retain their previous unshielded fleet behavior.

Recharge currently runs for active loaded actors; docked and remote fleet shield simulation remains incomplete. This does not claim power-aware shields or remote combat parity.

Shield capacity, delayed recharge, clamping, inactive/legacy behavior and malformed-save tests passed. Real fleet integration verifies charge and delay across damage, save reload and actor respawn. Fleet gameplay, layout and family-combat regressions passed; family-combat disables automatic physics to isolate damage assertions from the newly active recharge. Hidden Gamescope integration passed and the registry shield readout was visually inspected. The existing seven-texture shutdown warning remains. Windows export passed; fresh Proton runtime remains unverified.


## Hosted fleet shield simulation — 2026-09-28

Crew simulation now recharges every operational family vessel, including idle/docked and remote ships, from elapsed hosted time. Fleet actors mirror the authoritative charge/delay after each crew tick and skip their own recharge step. Non-fleet actors retain local recharge. Family combat stats are cached for immutable hull templates to avoid reconstructing a GameState per vessel per frame. Remote patrol encounters now consume shield charge before converting residual absolute damage to hull condition; legacy patrol damage remains unchanged.

Strategic patrols remain coarse encounter events, not continuous dogfights. A batched crew tick applies its recharge before the batch of encounter outcomes; large catch-up deltas are not claimed to reproduce finely stepped combat. Closed worlds accrue no elapsed time.

Hosted defense tests passed for idle/remote/local recharge, invalid or zero time, delay/capacity, disabled hulls, shield absorption and unshielded family hull scaling. The real-scene family integration verifies one hosted recharge step reaches the actor and subsequent actor physics adds no duplicate charge. Crew, operations gameplay, fleet gameplay and persistence regressions passed. Hidden Gamescope integration and Windows export passed; the existing seven-texture shutdown warning remains and fresh Proton runtime is unverified.


## Chronological patrol shield recovery — 2026-09-28

Crew ticks now advance each vessel's shields to its order event before resolving damage, then recharge the remaining elapsed time after the final event. This replaces the previous recharge-before-entire-batch approximation. Idle vessels still receive the full elapsed interval; local actor ownership stays unchanged. A vessel disabled during a batch stops completing further encounters. Existing overdue progress resolves overdue events at time zero rather than granting fictitious recharge intervals.

This is event-level patrol timing, not continuous remote flight/combat. World-day changes and competition between multiple orders for a shared treasury remain outside the single-patrol step-equivalence check.

The deterministic timing test passed a 1,204-second batch versus 1,204 one-second ticks with real hostile encounters, comparing hull, charge, delay, encounter count and credits. It also passed split-versus-batched encounter boundaries and verified a disabled vessel completes no further batch encounters. Existing crew, operations gameplay, family integration and hosted-defense tests passed. Windows export succeeded; this domain-only change does not establish new visual or Proton-runtime results.


## Fresh Windows/Proton runtime check — 2026-09-28

The current exported Windows normal entrypoint completed `NEXT_INTEGRATION_OK` twice under Proton Experimental and headless Gamescope on the RX 7900 XTX. The second run used the new `tools/test-proton.sh` end to end, including a fresh export, isolated Proton prefix, explicit Godot log and bounded wrapper. No script or shader errors appeared in the game log. The Windows SDR-white-level warning remains; Gamescope/Proton required timeout termination (wrapper exit 137) after the integration marker, so clean shutdown is not claimed.

The reusable command checks fresh per-run evidence, rejects missing success markers and Godot errors, and reports integration completion separately from wrapper exit status. Syntax and missing-runtime/invalid-timeout guards passed. Evidence for this run is in `build/proton-smoke.zISPNU/`; the Windows ZIP was rebuilt. These normal-entrypoint checks do not establish every standalone regression on Windows, Steam peer interoperability, visual acceptance, VR support or the 1440p/60 performance target.


## Hidden ship-preview rendering — 2026-09-28

ShipDesigner now disables its SubViewport rendering and stops model rotation while its parent UI is hidden; reopening resumes both. The focused visibility/lifetime regression passed headlessly and in hidden Gamescope, including repeated creation and teardown, without a texture RID warning. This verifies the rendering toggle, not a measured frame-rate gain.

The separate seven-texture shutdown warning remains unresolved. Adding a second teardown frame did not remove it, and a minimal main-scene probe still emitted it after eight cleanup frames without opening a ship editor. Disabling SSAO, SSR and glow in an isolated diagnostic run also did not remove it. Those diagnostic edits and unhelpful test delays were not retained; no visual-quality settings were reduced.

Windows export passed for the preview change. The earlier Proton normal-entrypoint pass predates this change; no new Proton run is claimed here.


## Configurable fleet equipment — 2026-09-28

Family fleet vessels now support persisted equipment substitutions within their designed occupied cells. Core, cockpit, original reactor and original engine cells remain structural; other bays accept cargo, weapons, shields, habitats, radiators or additional reactors. Refits require a local idle operational vessel and preserve a powered, walkable assembly with cargo capacity for its current load. Price is new equipment cost minus half the old equipment value weighted by hull condition; the menu shows the net amount. Hull condition is retained, reduced shield capacity clamps charge, and incompatible room overrides are pruned.

A shared vessel blueprint supplies the loadout to previews, flight actors, interiors, save validation and strategic combat/recharge. Custom combat-stat cache entries are bounded. Old family records still use their template; explicit equipment saves require a compatible layout, identical occupied cells, protected structural roles and matching capacity. This extends equipment within designed families, not arbitrary fleet hull reshaping or helm transfer.

Domain tests passed pricing, stats, power/habitat/structure/cargo/cash/occupied guards, shield clamping, save reload and atomic rejection of malformed equipment records. The actual menu callback installs a weapon, updates capacity and damage, survives reload, and feeds boarding/actor geometry and weapon stats. Hidden Gamescope passed that integration and the revised compact menu was visually inspected. Existing family, shield and patrol timing regressions passed. The full-scene seven-texture shutdown warning remains.

The integration also spawns the refitted vessel through the main fleet controller and confirms its weapon rating. Windows export passed. No fresh Proton runtime result is claimed for this equipment increment.

## Family hull surface paneling — 2026-09-28

Pathfinder and Merchant pressure shells opt into object-space panel seams, subtle per-panel paint variation, rougher grooves and shallow bump relief. The module-grid origin keeps roof seams between module centers. Seam relief fades with projected pixel footprint. Existing fleet materials retain their previous finish when panel strength is zero. Hull geometry, occupied room volume and collision are unchanged.

Hidden Gamescope completed six exterior, rear and cutaway captures with no shader or script errors. Exterior captures were visually inspected: seams add surface definition, but these remain visibly boxy pressure blockouts, below the requested cinematic target. The blueprint containment/collision regression and Windows export passed. No fresh Proton runtime check was performed for this material change. This check does not establish temporal stability at every distance, frame-rate performance or photorealism.

## Family propulsion fairings — 2026-09-28

Each family engine bay now has a tapered dorsal fairing above its twin nozzles, with a dark service strip. The first four-cover variant was visually rejected as cluttered and replaced with two longer fairings per ship. Existing nozzles and thrust remain; custom modular assemblies do not receive the family fittings.

The blueprint regression checks every added fairing/strip vertex against cabin roof clearance and the existing collision union, alongside the original closed-shell/interior checks. It also confirms custom assemblies do not receive these fittings. Native tests passed, and hidden Gamescope generated six captures without shader/script errors; the revised rear view was inspected. Windows export passed; no new Proton runtime result is claimed. This is a small propulsion-detail improvement, not a completed hull redesign or the requested cinematic visual quality.

## Dockside personal/fleet cargo transfers — 2026-09-28

Crew Operations now transfers selected commodity quantities between the personal ship and a local idle fleet vessel. Both holds retain their contents through normal saves. Transfers conserve commodities without changing credits or market stock. The domain rejects missing, remote, disabled, occupied, assigned or in-flight vessels, invalid quantities, insufficient source cargo and destination overflow before mutating either hold. Main additionally rejects world visits, flight, interiors and planetary locations; transfers require an orbital concourse.

The native domain regression passed conservation, both capacities, atomic rejection, unchanged money/market stock and save reload. A hidden Gamescope integration exercised both actual menu callbacks, refreshed totals, save reload and every scene gate. The 1440x900 capture was visually inspected. Existing fleet equipment regression and Windows export passed. No fresh Proton runtime check was performed for this increment. The full-scene seven-texture shutdown warning remains; the cargo UI test otherwise completed successfully. Fleet helm exchange and physical dockside loading remain unimplemented.

## Custom designs in the fleet — 2026-09-28

Crew Operations can commission a new copy of the personal ship's current design for the sum of its module costs. Copies retain independent module, room and panel data, start with full hull and empty cargo, and do not alter the original ship's condition or inventory. The existing fleet name, affordability and count guards apply. Custom designs must be bounded, connected, powered and contain required flight modules; walkability is not required for small ships.

Strict fleet loading now supports an explicit custom hull category with mandatory modules and layout. Cargo capacity and shield limits derive from the modules. Local crew-operated actors build the saved custom geometry, collision and combat/propulsion stats. Walkable copies support docked inspection. Custom equipment refits and fleet helm exchange remain unavailable; this preserves custom designs in fleet records as a prerequisite for future exchange, without claiming exchange is implemented.

The custom domain test passed purchase accounting, independent snapshots, rejection atomicity, save reload, malformed records and actor stats/geometry/collision. Existing family, equipment and fleet flight-save regressions passed. Native and hidden Gamescope scene tests exercised the commissioning button, boarding/exit, crew patrol spawning and persistence; a custom interior capture was visually inspected. Windows export passed. No fresh Proton runtime result is claimed. The known seven-texture shutdown warning appeared in the graphical integration run.

## Dockside helm exchange — 2026-09-28

The fleet registry can now promote a local idle family or custom vessel to the personal helm at an orbital concourse. The previous ship replaces its fleet slot, preserving ship identity/name, modules, layout, cargo, hull percentage, shield charge/recovery delay, fuel and drive temperature. No vessel is sold and cargo holds are not merged. The active ship gets the selected vessel's state; collision, visuals and flight stats rebuild. The exchange works at the fleet limit because it replaces a slot.

Unavailable, remote, disabled, occupied or assigned ships, active visits, flight, interiors and planetary locations are rejected. The destination must fit the existing global crew roster; ship-defense orders require a weapon. Commander finances, company and recovery insurance/debt remain commander properties. Utility vessels without saved designs cannot be piloted. This is dockside menu exchange, not boarding a moving ship to seize its helm.

Save data now persists active ship identity and optional fleet fuel. Old saves migrate; malformed identities/fuel and active/fleet ID collisions are rejected. Identity follows the carried ship into and out of visitor profiles through the shared copy routine. Stored fuel survives exchange, but autonomous fleet orders do not yet consume this fuel record. The active player's shield-delay timer remains runtime state, as before; stored fleet delays persist.

The domain regression passed two-way conservation, save/reload, full 50-slot fleet exchange, crew constraints, atomic rejection and old-save migration. Native and hidden Gamescope scene tests passed the actual command button, scene guards, collision/model rebuild and exchange back to the original custom ship. The fleet menu capture was inspected. Visitor-profile, GameState, crew and existing family/custom/flight-save regressions passed. Windows export passed. The known seven-texture shutdown warning remains in the graphical scene test. No fresh Proton runtime check is claimed for this increment.

## Clean Windows package and Proton refresh — 2026-09-28

Built published commit `9b84799` from an isolated clean worktree at `build/windows-validation-9b84799`, excluding the paused station/NPC drafts in the development checkout. Godot 4.7.2 Windows export ran under the installed Proton Experimental in hidden Gamescope and reached `NEXT_INTEGRATION_OK` with no script errors. Evidence is in `build/windows-validation-9b84799/build/proton-smoke.Jmy3YX/` (export/runtime/wrapper logs and binary hashes). The Windows SDR white-level warning remains. The wrapper did not terminate cleanly and was stopped by the bounded timeout with status 137; the game integration passed, but clean wrapper shutdown is not verified.

This is the normal-entrypoint broad gameplay smoke. It exercises trading, construction, combat, persistence, travel, interiors, crew and generic fleet behavior. It does not invoke the newly added custom commissioning or helm-exchange callbacks; those retain their separate native/headless-Gamescope evidence above. It does not prove Steam networking, native Windows hardware compatibility or the 1440p/60 FPS target.

Refreshed local `build/NeXt-Windows.zip` (40,159,166 bytes), containing `NeXt.exe`, `NeXt.pck` and source/version/hash information. ZIP CRC and extracted member SHA-256 checks passed. Package SHA-256: `5ca917d78fc1d73fe3f939ab50226488fa291f0c6bc3b37a92be82bc3a8a26d1`. Executable SHA-256: `4a9eaded8955ef789ab02651ed9d2dde80328fbb342bd2a6db4db33e86305668`; PCK SHA-256: `4b68ebb486516c00dafd3f981ec34f6866d436478ae4f7db453aa9b8a90c6892`. This local development package is not a GitHub release asset.

## Persisted active shield recovery — 2026-09-28

The active ship's recharge delay now belongs to GameState, is saved as an optional validated 0..6 second value, and follows the ship through world visits and helm exchanges. This supersedes the runtime-only delay limitation noted above. Old saves default to zero; malformed values reject before loading state. Main's existing damage paths write this same state. A replacement ship after destruction starts without the destroyed hull's timer.

Recharge subtracts the delay first and grants 5 shield units per second only for the remaining elapsed time, rather than granting a full frame when the delay crosses zero. Delay stays nonnegative, shield charge is capped, invalid elapsed values are ignored, and destroyed hulls do not recharge. Existing menu/jump pause conditions remain.

Native tests passed split-step timing equivalence, recharge boundaries, invalid elapsed input, shield-delay save/reload and malformed/legacy saves. Main-scene tests verified a real damage call sets the stored timer, active delay survives a helm-exchange save, and visitor arrival retains it. Recovery, existing GameState checks and Windows export passed. This change has no new Proton runtime result; the clean ZIP described above still contains commit `9b84799`.

## Crew walking aboard ships — 2026-09-28

Unassigned engineers and traders walk between clear stops on their current deck, with staggered pauses. Gunners remain stationed. Private cabin-local navigation maps are baked lazily from the same colliding boxes used for floors, walls and furniture, so ship rotation and sector rebasing do not require rebaking. Rebuilding or leaving an interior disposes its maps. Unreachable destinations are retried on a bounded schedule; stalled walking stops and retries later. Menus and jump charging pause crew movement.

This is local room circulation, not a full work schedule: crew do not traverse lifts or avoid each other yet. Animation remains a replaceable procedural walk cycle.

Native checks passed cabin-local routing, deck/disconnected rejection, pitch/yaw/roll support, raised capsule wall-clearance probes, pause/resume, arrival and rebuild invalidation. Existing standing crew, placement, port navigation and glass collision regressions passed. The actual-main test passed headlessly and in hidden Gamescope at default walking speed, checking engineers/traders move while the cabin turns and remain stationary locally during a menu pause. The capture was inspected: crew are visible inside the cabin, but oversized labels overlap the HUD and the models remain rough placeholders. Windows export passed; this increment has no fresh Proton runtime result.

## Cabin identification scale — 2026-09-28

Crew identification now uses approximately 4 cm glyphs with a narrower outline, centered 1.95 m above the feet. Room signs use approximately 6 cm glyphs. This reduces the oversized text visible in the preceding crew capture without changing identity, duty or interaction behavior. The art checklist records the new label placement.

The actual-main crew regression passed in hidden Gamescope. Captures were inspected both with active notifications and after advancing the HUD notification timer to expiry: identification remains readable close up, while temporary banners can still obscure it. No whole-scene visual quality claim is made. Windows export passed with no script errors; the known seven-texture shutdown warning remains in the graphical run. No fresh Proton runtime check was performed.

## Procedural crew suit revision — 2026-09-28

Ground actors and shipboard crew now use a closed ellipsoid helmet with a flush curved faceplate, narrow brow/chin trims and side fittings. The former projecting oval visor is removed. Suits have a tapered torso, shorter arms, shoulder armor attached to animation pivots, chest harness details and flatter boots aligned with the floor. Cloth uses one shared procedural normal texture; armor and visor retain separate roughness/material responses. Physics capsules, damage handling, interaction identity and animation interfaces are unchanged. The asset checklist identifies the replaceable helmet, texture and rigid rig.

Studio and actual-cabin captures were inspected in hidden Gamescope. Early renders exposed reversed helmet winding and torso/armor intersections; those were corrected before final captures. The shapes still read as primitive-based, stylized placeholders and do not meet the requested near-photorealistic reference. The studio capture helper is reusable at `tests/capture_crew_models.gd`; it includes company, police and pirate material variants under neutral lighting.

Ground actor behavior, crew support, room roaming and actual-main crew integration checks passed. The graphical integration retains the known seven-texture shutdown warning; the isolated studio capture exits without that warning. Windows export passed with no script errors. This increment has no fresh Proton runtime result.

The new helmet regression checks 1,169 finite vertices across four surfaces, bounds, nondegenerate clockwise winding and a measured 3 mm faceplate offset. It passes headlessly without teardown warnings and runs in Windows CI. GPU inspection separately confirmed exterior faces render correctly.

## Crew yielding and cabin collisions — 2026-09-28

Shipboard crew now physically collide with one another and the aboard player. The player gains a dedicated occupant layer only inside a cabin, so crew exclude the enclosing coasting hull's layer. Exit removes the temporary player layer and crew collision mask. Placement queries also reject occupied spawn positions. Nearby people trigger cabin-local keep-right steering, slowdown and a Giving way duty label; the body turns toward its actual movement. Existing stuck-route handling pauses and retries passages that remain blocked.

The new regression passed a 2 m corridor with opposing crew, recording minimum separation 0.8696 m. Both reached opposite stops. It also covered a translated/tilted cabin, an enclosing-hull layer probe, a stationary occupant blocking a narrow passage without overlap, and resumed walking after the occupant moved. This is local yielding, not a general crowd planner: complex queues and lift traversal remain unfinished.

Existing crew identity/support, placement and room-roaming regressions passed. The actual-main integration passed natively and in hidden Gamescope, including coasting/turning support, menu pause and temporary player collision settings on entry/exit. Windows export passed with no script errors; the full-scene graphical run retains the known seven-texture shutdown warning. No fresh Proton runtime check was performed.

## Release-safe crew validation and Windows refresh — 2026-09-28

`tools/test-proton.sh --crew` now exercises the shipping Windows release through the game's opt-in `--crew-check` startup route. The native SceneTree wrapper and exported test scene share a Node-based runner. Its setup and failure gates use explicit checks, so release builds do not strip them along with `assert`. The startup route marks the test instance to prevent recursion, enables automation before loading state, and uses PID-scoped test saves rather than the normal commander save. Without the flag, normal startup is unchanged.

Stock release templates do not support the extended `--script` override. Initial attempts using it timed out without reaching the first test checkpoint; the explicit game entry route resolved this. See the [Godot command-line reference](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html). Both native entry routes passed before Windows validation.

A clean detached checkout at `e876ec9a610e7a5b5afb720144d361d4d18d24e8`, under `build/windows-validation-dd5c267`, excluded all paused local drafts. Windows release export passed. In hidden Gamescope, Proton Experimental reached `SHIP_CREW_GAMEPLAY_OK` in `build/proton-smoke.Y1UjRh/godot.log`, covering actual crew movement during turns, menu pause, interaction, casualty persistence and collision-rule cleanup. A separate normal-entry run reached `NEXT_INTEGRATION_OK` in `build/proton-smoke.szJGDN/godot.log`. Both runs used byte-identical executable/PCK pairs. The actual Windows crew capture was visually inspected.

Neither log contains Godot script/errors. Both contain the existing SDR-white-level warning. Both wrappers required timeout cleanup after the completion marker (exit 137), so clean shutdown remains unverified. These checks do not prove Steam multiplayer interoperability, native Windows-host behavior, or the 1440p/60 FPS target.

The local `build/NeXt-Windows.zip` was refreshed from that clean source commit. It contains `NeXt.exe`, `NeXt.pck` and `BUILD_INFO.txt`, with source and validation limitations recorded. ZIP CRC and member SHA-256 checks passed. Archive size: 40,194,301 bytes. Archive SHA-256: `66bbc419059b679699e086166a0020c330b0af3d6df87c256e0795860ffa614a`; executable SHA-256: `4a9eaded8955ef789ab02651ed9d2dde80328fbb342bd2a6db4db33e86305668`; PCK SHA-256: `7f97daff1d125345b331449ae923ebb7e83ffe648fe8678b2ee640f3e4856b24`. This is a local development package, not a GitHub release asset.

## Isolated Proton shutdown — 2026-09-28

Process inspection after the success marker showed NeXt and Proton had exited, while a Wine device helper kept Gamescope's reaper alive. The harness now waits for Proton, then invokes the selected Proton distribution's wineserver with `-k` and `-w`, scoped exclusively to the test's fresh prefix. Original Proton failures take precedence over cleanup failures. The harness also returns a nonzero wrapper status even when gameplay completed. A shell regression checks argument preservation, prefix isolation, cleanup on failure and error precedence; it runs in CI.

Clean checkout `2150a39fba14babb1972aa096aa99c6e985035fd` passed both Windows release runs in hidden Gamescope: crew evidence `build/proton-smoke.GgatTL` and normal-entry evidence `build/proton-smoke.L2WnnD`. Both reached their expected gameplay markers, with Proton exit 0, cleanup statuses 0/0 and wrapper exit 0. Neither Godot log contains script/errors; the SDR-white-level warning remains. This resolves the preceding test-wrapper timeout, not a general claim about every shutdown path.

Both runs exported byte-identical executable/PCK pairs. The local development ZIP was refreshed with that source and updated BUILD_INFO; member SHA-256 and ZIP CRC checks passed. Archive size: 40,194,183 bytes; SHA-256: `a3b4775e904e1b42afb971383c9edc588669bbe008013c7986eaccd9ca2f9cca`. Steam interoperability, Windows-host behavior and the performance target remain unverified.

## Cabin surface finish — 2026-09-28

Opaque ship interior boxes now reuse the existing fleet surface shader rather than a separate UV-noise shader. Panel coordinates use mesh metres plus cabin-local position, with 0.7 by 1.225 m pitch, shallow joint relief and derivative-filtered fine grain. Broad surfaces receive joints; small fittings retain plain paint. Lower metallic response and restrained coating represent painted surfaces. Glass, emissive strips, geometry and collision remain unchanged. The unused interior shader was removed.

The actual-main crew test passed in hidden Gamescope; its capture was inspected for the new joints and highlights. Cabin movement, turning, menu pause and exit checks passed, as did the headless interior-glass regression. No shader/script errors appeared; the existing seven-texture shutdown warning remains. The regular tile layout and primitive crew shapes are still placeholders, below the requested visual target.

Clean detached Windows release export at `b4ea5dc` also passed without script/export errors. This material increment has no fresh Proton runtime result; the existing ZIP still contains the prior validated build.

## Crew deck transfers — 2026-09-28

Unassigned roaming crew can plan through the existing abstract deck-transfer landings. They walk the approach, wait two seconds at the landing, transfer only when the destination capsule is clear, then follow its deck-local onward route. Inactivity pauses the wait; disabling roaming cancels the route. Blocked arrivals retry for up to ten seconds before abandoning the trip. Immediate sibling positions supplement physics queries so simultaneous arrivals cannot share an exit before broadphase synchronization. Being pushed away from the departure landing cancels the transfer.

Every clear deck landing is included in the main scene's roaming stops, even when the room-stop limit favours another deck. Floor markings identify multi-deck transfer points. This remains an assisted transfer, not a physical elevator shaft or animated elevator cabin. A first-module landing obstructed by furnishings is rejected; authored landing placement remains unfinished.

The furnished cargo-corridor regression exposed crates leaving only a 0.9 m aisle, smaller than the navigation agent's clearance. Corner placement now leaves 1.48 m through adjoining cargo rooms.

The new furnished two-deck cargo regression passed headlessly (16.9 s) and in hidden Gamescope: approach and onward travel, blocked exit, inactive/disabled pauses, immediate second-arrival rejection, transformed cabin and invalid/disconnected routes. The transfer marking capture was inspected. Same-deck roaming, crew placement and yielding regressions passed; actual-main crew gameplay passed in hidden Gamescope with the existing seven-texture teardown warning. The focused lift render had no script errors or teardown warnings.

Clean detached Windows release export at `b53b7f5` passed without script/export errors. No fresh Proton lift runtime check was performed; the ZIP remains the earlier validated development package.

## Player landing clearance — 2026-09-28

PageUp/PageDown deck transfers now validate the destination before teleporting or changing the selected deck. The shared lift clearance query uses the player's 0.38 m radius / 1.8 m height capsule in the cabin's rotated frame, excludes the player, and checks static geometry and occupants. A blocked destination reports that the landing needs clearance. The pilot transform is flushed after a successful transfer.

Transfers are rejected outside a cabin, during menus or jump charging, and for invalid directions/deck indices. Pressing past the first or last deck no longer teleports the player back to the same deck's landing or clears velocity. This retains the existing assisted-transfer control; it does not introduce a physical elevator.

The new actual-main regression passed headlessly (2.5 s) and in hidden Gamescope: crew/static obstruction, atomic rejection preserving velocity, later success after clearance, minimum-deck no-op, menu/jump guards and supported landings with tilted gravity. It uses isolated test saves and explicit failure exits. Crew deck-transfer regression also passed. The existing anchored-interior regression passed both natively and graphically; its graphical run retains the seven-texture teardown warning. The focused player-lift run reported no script errors or teardown warnings.

Clean detached Windows release export at `142bc17` passed without script/export errors. No fresh Proton runtime result is claimed for this change; the ZIP remains the earlier validated package.

## Resource-backed engineer repairs — 2026-09-28

The Enterprise repair policy explicitly authorizes cargo-alloy consumption and persists as an optional, strictly validated boolean. It defaults off for new and older saves. Paid unassigned engineers replace the former free daily heal with up to one alloy each for eight hull points, capped at missing hull; partial final repairs consume a full unit. Full/dead ships, unpaid or assigned engineers and missing stock do not consume supplies. Station service repairs remain separate.

Domain checks passed default-off behavior, multiple engineers, scarce supplies, partial repairs, full/dead hulls, absent/unpaid/assigned engineers, wages/trader income, save roundtrip, legacy defaults, atomic malformed-save rejection and split-time equivalence. Actual-main Enterprise interaction passed in hidden Gamescope: checkbox persistence, daily repair, menu refresh and disabling without consuming trade cargo. The screenshot was inspected; explanatory text and control are readable. Existing crew, calendar and GameState regressions passed after updating the old free-heal expectation. The graphical UI run retains the known seven-texture shutdown warning.

Native main smoke also passed. Clean detached Windows release at `f14d996b18d872d1c2df46ec74feba2c5e242142` passed normal gameplay integration under Proton Experimental in hidden Gamescope (`build/proton-smoke.0tSSgd`), with wrapper exit 0 and no Godot script errors. The SDR-white-level warning remains. These Windows checks are general smoke coverage, not dedicated Windows field-repair/lift coverage or Steam/performance proof. The development ZIP was refreshed from that source; ZIP CRC and member SHA-256 checks passed. Size: 40,217,072 bytes; archive SHA-256: `c6d40534738965b90548576d718f25164a215b6d2442c6f6c93ae332f7a2e08a`.

## Fleet fuel use and service — 2026-09-28

Owned fleet actors now debit their saved tank for actual impulse, limit thrust/braking when depleted, and retain residual momentum. Remote order events account for hyperdrive and approximated same-system travel, with no extra same-system estimate on materialized ships. Fuel shortages pause before wages or cargo transfer and report only once. Fleet fuel service consumes credits and fuel stock at the vessel's market; unavailable stock cannot create fuel.

The new actual-main propellant test passed natively and in hidden Gamescope: partial braking, empty coasting, invalid command rejection, service money/stock conservation, insufficient money/stock, actor callback binding, UI refill, save persistence and immediate use of the refill. The graphical run retains the known seven-texture teardown warning. Remote-order tests passed pre-wage/market pause atomicity, single pause notice, resumption, local/remote costs, represented hyperdrive cost, blocked storage and split-time equivalence. Existing patrol timing, fleet gameplay, trade cost basis, local trade and NPC thermal checks passed. Main-entry native smoke passed. Service logistics and remote two-unit fuel usage are approximations, not physical delivery or orbit simulation.

Clean detached Windows release export at `1bba137` passed without script/export errors. This increment has no fresh Proton runtime result; the ZIP remains the preceding validated build.

## Fleet route running-cost quotes — 2026-09-28

Route quotes preserve gross cargo margin and escrow, and now separately estimate two trader wages plus replacement fuel for two hyperdrive jumps. Fuel is quoted as two commodity units (20 tank units) at current origin prices. Unavailable origin fuel produces an unavailable operating estimate rather than zero fuel cost. The menu explicitly excludes local thrust, waiting wages and repairs; actual returns also depend on later prices. Quoting does not buy/reserve supplies or mutate a vessel.

The new domain/menu regression passed in hidden Gamescope, including a vessel whose origin differs from the player system, gross-versus-operating accounting, unavailable fuel, no purchase side effects and actual quote-button output. Its screenshot was inspected: running costs and caveats are readable. Existing crew and trade cost-basis regressions passed. The graphical run retains the known seven-texture teardown warning.

The final quote regression also passed headlessly. Clean detached Windows release export at `fd8ae24` passed without script/export errors. No new Proton runtime result or ZIP refresh is claimed for this change.


## Patrol flight persistence — 2026-09-28

Owned patrols now save system-space position, velocity, patrol center and course clock. Capture and restore account for floating-origin changes and culled actors retaining an older local frame. Patrol order identity prevents a cancelled actor from seeding a replacement order; cancellation and system relocation clear the previous flight. Save loading validates the patrol record and its assigned order atomically, while accepting older saves without flight state.

The actual-main regression passed headlessly and in hidden Gamescope for rebased reload, independent patrol center, course clock, empty-fuel coasting, culled rebuild, invalid records, legacy saves and immediate cancellation/reassignment. Additional headless checks passed relocation cleanup, existing trader flight saves, fleet order fuel and patrol timing. The deliberate infinite-value fixture emits Godot's `Exponent too high` warning and is rejected without state mutation. This Gamescope run showed no texture teardown warning. CI includes the new regression. Remote patrol movement remains an abstract encounter simulation; this preserves the last materialized course, not combat targets or continuous distant trajectories.

A clean Windows release export at `d52fd9f` passed with no script/export errors. No fresh Proton runtime check or development ZIP refresh is claimed for this increment.


## Family material and preview inspection — 2026-09-28

Family pressure shells opt into filtered procedural fastener recesses and seal dirt, with smoother coated paint. Fairings now have framed grilles and low rails. ShipDesigner and the family capture tool share a neutral reflection sky behind their solid backdrop; gameplay retains its existing world lighting. Exterior and rear captures were inspected in hidden Gamescope: service detail is clearer, but the flat roof plan, repeated fittings and coarse silhouette remain below the requested cinematic target.

Blueprint room/outer-hull containment regression passed. ShipDesigner interaction regression, family exterior/rear/cutaway captures and radiator capture passed in hidden Gamescope with no Godot script or shader errors. An initial incorrect reflection enum was fixed using the installed engine's ClassDB constants. A radiator capture mistakenly attempted on the dummy headless renderer failed and timed out; its subsequent hidden graphical run passed. These checks do not establish performance, photorealism or final authored asset quality.

Clean Windows release export at `7282af9` passed without script/export errors. No fresh Proton runtime or updated development ZIP is claimed.


## Fleet surface distance filtering — 2026-09-28

The shared hull/cabin shader now fades low-frequency paint noise, seal dirt and panel color variation when their projected detail becomes too small. Fasteners use their own smaller fade range and symmetric edge filtering; narrow groove opacity scales down with screen footprint rather than growing into a dark pixel-wide grid.

Added `tests/capture_surface_distance.gd`, a repeatable GPU review fixture with close, mid, far, distant and grazing views. Hidden Gamescope produced all five images without script or shader errors; close fasteners and distant detail fade were visually inspected. Existing family exterior/rear/cutaway capture also passed. These static captures verify rendering and the sampled appearances, not temporal stability under all motion, every material/lighting condition or a performance target.

Clean Windows release export at `0df2816` passed without script/export errors. No fresh Proton runtime or development ZIP refresh is claimed.


## Partial fleet fuel service — 2026-09-28

Fleet refuelling now supports partial commodity quantities while retaining the default full-tank service. Requests are bounded to zero (fill) or one through ten units and capped at the tank's remaining requirement. The fleet menu offers a ten-fuel delivery whenever more than one commodity unit is needed; it remains usable when market stock cannot fill the tank.

The domain regression verifies exact credit/stock settlement, unavailable full refills, affordable smaller purchases, atomic quantity/credit failures, capped top-offs and save persistence. The existing actual-main propellant test now exercises the small-delivery button with one unit left in stock, confirms the full-refill button is disabled and reloads the ten-fuel result. Native and hidden Gamescope integration passed, as did existing fuel-order timing checks. The graphical integration retains the known seven-texture teardown warning. Delivery travel remains abstract; this change does not add physical tankers or automatic crew fuel purchasing.

Clean Windows release export at `65b0142` passed without script/export errors. No fresh Proton runtime check or development ZIP refresh is claimed.


## Assigned crew fuel allowances — 2026-09-28

Registered fleet vessels now have an opt-in remaining fuel budget, capped at 1,000,000 credits. Assigned living crews buy one local-market fuel commodity below ten tank units, only within the remaining allowance and while preserving their next wage. Purchases reduce both treasury and allowance. The check runs before local arrival gates and at remote event boundaries; missing stock, insufficient funds/budget and disabled defaults do not mutate fuel or money. The command menu sets the remaining cap without reserving cash.

Domain checks passed purchase accounting, threshold/default/no-order/zero-time gates, blocked purchases, batch-versus-split patrol fuel/budget, save roundtrip, malformed allowance atomic rejection and legacy default. The actual-main UI check passed natively and in hidden Gamescope: setting/saving a cap, purchasing while a trader has not arrived, deducting the remaining budget and reloading the result. Existing fleet propellant/manual-delivery and fuel-order regressions passed. The focused allowance graphical run had no texture teardown warning. Delivery remains abstract, and reserving one member's next wage is not a guarantee of payroll for the whole fleet.

Clean Windows release export and isolated hidden-Proton normal integration smoke at `2efb886` passed. Evidence: `build/proton-smoke.m5uKx1`; Godot reported `NEXT_INTEGRATION_OK`, Proton and wrapper exited zero, and prefix cleanup succeeded. Windows reported the existing SDR-white-level warning. The normal smoke covers its established gameplay path, not every new allowance edge case or Steam interoperability. No development ZIP refresh is claimed.


## Powered systems and radiator balance — 2026-09-28

Powered non-engine loads now feed the existing thermal loop with a documented gameplay conversion, bounded by generated power. Player and materialized NPC ships share a finite, bounded temperature step; family actors derive heat from module stats and generic NPCs use a 6 kW default. Disabled player systems stop adding heat. Propulsion heat remains separate and electrical heat does not spend thruster propellant. The shipyard reports powered-system heat in kW.

New domain checks passed source heating, radiation equilibrium, area-dependent cooling, invalid inputs, actual NPC physics with unavailable thrust, player fuel preservation and disabled-system behavior. Updated actual-main heat checks passed natively and in hidden Gamescope: idle warming leaves fuel/momentum unchanged and the shipyard exposes the source, while hot propulsion, recovery through cooling, carried temperature and aboard controls remain valid. Existing NPC thermal and radiator tests passed. The radiator test now compares radiation after accounting for concurrent source heat instead of equating net cooling to radiation. No shader/script errors appeared in the graphical gameplay run. Remote thermal integration, stellar input and physical-scale flight gravity remain unfinished.

Clean Windows release export at `5a9e327` passed without script/export errors. No fresh Proton runtime check or development ZIP refresh is claimed for this thermal increment.


## Commander main power shutdown — 2026-09-28

Added an optional persisted `systems_online` flag with strict boolean load validation and online legacy default. Flight Settings exposes shutdown/restart, and the flight HUD identifies coasting with systems off. Both propulsion limits and the shared impulse debit reject powered corrections while offline. Local ship/crew weapon paths and hyperdrive are gated; suit weapons remain independent. Shield recharge stops without deleting existing charge. Carried-ship copies preserve the flag; service-berth helm exchanges start the replacement vessel.

Domain power checks passed state behavior, save roundtrip, malformed-load atomicity and legacy defaults. Actual-main integration passed headlessly and in hidden Gamescope for menu/save/restart, assist unable to brake, weapon suppression/resumption, independent suit weapon, hyperdrive charge rejection and carried state. Existing crew-defense gameplay now verifies shutdown/restart against a real target, then passes its payroll/cover/neutral/bounty checks. General state and visit regressions passed. These checks do not establish replicated/host-enforced power controls or Steam interoperability.

Clean Windows release export at `3ac8a25` passed without script/export errors. No fresh Proton runtime check or development ZIP refresh is claimed for this power-control increment.


## Replicated ship power — 2026-09-28

Ship power now has a reliable owner-to-host-to-peers stream, independent of unreliable movement snapshots. Host shot validation rejects reported-offline attackers without granting offline targets immunity. Repeated local physics updates do not resend unchanged state. Travel resends the current mode in the new epoch, including a toggle crossing the transition; reconnect retains the local choice. Power arriving before a new peer's first pose is retained in a bounded pending map. The multiplayer list displays systems status.

Real ENet loopback checks passed offline raw-RPC attack rejection, target vulnerability, restart, stale pose and reliable echo handling, idempotence, sender impersonation and stale-epoch rejection, power-before-pose ordering, simultaneous travel/toggle and reconnect. Existing network and PvP transport regressions passed. The actual-main shutdown menu/gameplay regression passed in hidden Gamescope. These checks cover reported state; they do not establish client anti-cheat, authoritative remote electrical simulation or live Steam interoperability.

Clean Windows release export at `4c63820` passed without script/export errors. No fresh Proton runtime check or development ZIP refresh is claimed for this replication increment.


## Family hull paint blocking — 2026-09-28

Added optional hull-local painted shoulder and flank bands to the shared surface shader; only family exterior hulls opt in. Pathfinder uses grey-green identification paint and Merchant uses ochre. Paint retains panel joints, dirt and physical surface response. Geometry, pressure rooms and collisions are unchanged.

The six existing family capture views completed under hidden Gamescope; Pathfinder exterior and Merchant rear were visually inspected after reducing initially excessive stripe contrast and width. Shader compilation succeeded. The silhouettes and repeated roof fittings remain blockout quality, well below the requested cinematic reference. Moving-camera aliasing and final art acceptance remain open.


## Power-aware engine appearance — 2026-09-28

Local and visiting ShipVisual exhaust now darkens when reported systems are offline, and restores on restart. Rebuilding a visual preserves its power mode. Exhaust uses a separate material from navigation lights and weapon fittings; thrust no longer changes those lights through a shared material. NPC thrust still controls online exhaust intensity. This is an engine visual approximation, not per-room lighting or a simulated exhaust plume.

Actual-main gameplay passed in hidden Gamescope for local shutdown/restart and visiting visual shutdown, rebuild and restart. The final headless extension also passed immediate local rebuild preservation and independent navigation-light brightness. No live Steam, fresh Proton or refreshed development ZIP is claimed.


## Windows package refresh — 2026-09-28

Clean source `25b48c346963397cdee0c76238307d8873a88450` exported and passed the normal-entrypoint integration under Proton Experimental in hidden Gamescope (`NEXT_INTEGRATION_OK`). Wrapper exit, Proton exit and isolated wineserver cleanup all returned 0. Evidence: `build/windows-validation-dd5c267/build/proton-smoke.u5rYQq`. The Windows SDR white-level warning and Gamescope window/Wayland shutdown messages remain; no script errors appeared. This smoke covers existing integrated gameplay, not all focused network-power assertions, real Steam interoperability, native Windows-host behavior or the target frame rate.

Refreshed local `build/NeXt-Windows.zip` from the exact tested executable/PCK pair. Contains `NeXt.exe`, `NeXt.pck` and `BUILD_INFO.txt`; ZIP CRC and byte-for-byte member checks passed. Archive size: 40,273,887 bytes. SHA-256: `1e2df58920fc4144704c7c3290794a764ca27f6714edb2032cf2e8cb4759afa6`. Executable SHA-256: `4a9eaded8955ef789ab02651ed9d2dde80328fbb342bd2a6db4db33e86305668`. PCK SHA-256: `2203a65cddc0704bc861c5e10b3befa5aefbefab2a58056e397b4d4b37b32ad6`. This local development package is not a GitHub release asset.


## Physical recovery obstacles — 2026-09-28

Wreck hulls now carry conservative module-box collision on the world obstacle layer, matching their visual scale and tilt. Freight caches have box collision. Hull salvage replaces the hull with a cache while cargo remains; completed recovery removes the collision with the visual. Wreck exhaust stays unpowered.

Actual-main checks passed headlessly and in hidden Gamescope: world rays hit wreck/cache colliders, a player movement sweep hits the wreck, engines are dark, salvage removes the hull while preserving recoverable freight, and final recovery removes stale collision. Existing recovery domain checks passed. This adds static obstacles, not towing, debris dynamics, walkable derelicts or repairable wrecks. The existing center-distance recovery interaction remains unchanged.


## Wreck surface recovery range — 2026-09-28

Recovery now measures distance to the nearest conservative wreck collision box, accounting for tilt, scale and absolute address. Menu availability and domain actions use the same calculation. Shared geometry drives collision and range, so salvaging switches both to the smaller freight cache. Cruise approach targets use wreck bounding radius plus player hull radius and 12 m clearance rather than a fixed 25 m center offset.

Recovery tests passed the 7.9 m/8.1 m walking boundary beside a large tilted Merchant hull, including origin rebasing and non-finite position rejection. Actual-main wreck physics passed headlessly and in hidden Gamescope; an additional headless check verifies the requested approach target clearance. Conservative boxes are not exact damaged-mesh surfaces; route-wide avoidance of all wrecks, towing and derelict repair remain open.


## Cruise wreck avoidance — 2026-09-28

Cruise route planning includes active local wrecks and freight caches as conservative spheres expanded by the player hull radius. Completed recovery records and other locations are excluded. Recovery approach destinations now include the planner clearance plus 5 m, avoiding a destination inside the safety margin. Failed-route feedback refers to nearby obstacles instead of only planets.

Actual-main checks passed headlessly and in hidden Gamescope: a direct course through a wreck produces a detour, every generated segment clears the expanded obstacle, a destination inside the wreck is refused, the dedicated recovery approach retains clearance, and complete recovery restores the direct route. Existing route geometry and cruise gameplay regressions passed. This verifies route construction and existing cruise behavior, not dynamic replanning for newly created wrecks during a leg or complete avoidance of stations and moving ships.


## Replan cruise after recovery obstacles change — 2026-09-28

Rebuilding wrecks now compares their active absolute records and collision geometry. A change replans an active cruise from its current helm position; an unchanged rebuild preserves the route. If a new obstacle makes the destination unsafe, the route is cleared and braking is requested on the piloted or aboard hull. Braking still requires available thrust and propellant.

Actual-main tests passed headlessly and in hidden Gamescope for a newly created wreck interrupting a direct route, preservation of route objects on an unchanged rebuild, and cancellation/brake request when another wreck appears at the destination. Existing physical wreck/recovery assertions and the aboard-cruise regression passed. This is event-driven recovery-obstacle replanning, not continuous avoidance of all moving actors.


## NPC combat debris — 2026-09-28

Destroyed non-owned ShipActors in local space now leave recoverable alloy caches using the existing persistent recovery registry, physical cache geometry and cruise obstacle updates. Yield is a bounded gameplay approximation: floor(dry mass / 10,000 kg), clamped to 1–8 alloy units. No original freight manifest is invented. Owned fleet destruction retains its existing disabled-vessel and actual-cargo rules. Registry failure does not prevent combat death; a notification reports the missing beacon. Repeated callbacks for an already eliminated actor cannot duplicate debris or bounty.

Actual-main tests passed natively and in hidden Gamescope for a real pirate destruction, four-unit cache from its 40-tonne dry mass, duplicate callback rejection, save/load of both debris and eliminated actor ID, one-time collection, and existing wreck geometry/replanning checks. Domain validation rejects invalid masses without mutation and bounds large yields. Existing fleet-cargo recovery and crew-defense gameplay regressions passed. This does not implement repairable NPC hulls, realistic material composition, theft/legal ownership of salvage or shared multiplayer loot.


## Immediate combat outcome saves — 2026-09-28

Non-owned NPC destruction now invokes the existing commander save after updating eliminated actor IDs, bounty/law consequences and debris. These fields enter the same atomic-replacement world save instead of waiting for the periodic autosave. Failure explicitly reports NOT SAVED and retains live state for a retry. Visitor home-file synchronization remains a separate write; this is not a cross-file transaction or host-authoritative multiplayer loot.

Actual-main hidden Gamescope checks passed automatic save creation after NPC destruction, reload of debris and eliminated actor together, duplicate callback rejection, an empty-path save failure with visible feedback, and successful manual retry. Crew-defense gameplay passed with the additional combat save. Disk-power-loss durability and the latency of large-world saves during combat are not established by these checks.


## Selective cargo recovery — 2026-09-28

Recovery caches now list each remaining commodity with TAKE 1 and TAKE UP TO available-capacity controls. Recover Cargo still collects all available goods in the existing order. Optional commodity and quantity arguments share the existing distance, capacity and one-time recovery rules; invalid selections and unavailable goods return errors before mutation. Full holds disable recovery controls.

Domain checks passed selected medicine recovery without touching ore, requested-quantity and remaining-capacity limits, and invalid selection rejection. Hidden Gamescope actual-menu checks passed the one-unit button, immediate save of commander cargo plus remaining cache quantity, and subsequent completion. The scrolled controls were visually inspected. Existing wreck physics, NPC debris, failure/retry and route checks also passed. Seven Texture RID shutdown warnings remain in this graphical harness.


## Combined combat/recovery Windows validation — 2026-09-28

The initial Windows smoke at `c06cda5` failed its obsolete assertion that insured rescue creates the world's only wreck. Earlier pirate combat now leaves debris. The integration check now requires pirate debris creation, measures the rescue's added record, verifies prior records remain unchanged and recovers the new rescue wreck by its index. Native full integration passed.

Clean Windows source `ab92e4d69052794a70a559fe6748035a8e83bae4` then passed `NEXT_INTEGRATION_OK` under hidden Gamescope/Proton Experimental. Wrapper, Proton and isolated-prefix cleanup returned 0. Evidence: `build/windows-validation-dd5c267/build/proton-smoke.BXFDRV`. SDR white-level and Gamescope teardown warnings remain; no script errors appeared. This does not establish live Steam interoperability, native Windows-host behavior or target performance.

Refreshed local development `build/NeXt-Windows.zip` from that tested EXE/PCK pair, with BUILD_INFO. ZIP CRC and exact member-byte verification passed. Size 40,287,489 bytes; SHA-256 `ef9085dfb5f93762a90dc48ebcd02fc1b2967393a23a495398bc8a83f97f733a`. EXE SHA-256 `4a9eaded8955ef789ab02651ed9d2dde80328fbb342bd2a6db4db33e86305668`; PCK SHA-256 `967b1ae000a8f9ab935f69e6c51d58012224772df8be2a4efedd9ec569184259`. Not a GitHub release asset.


## Surveyable procedural derelicts — 2026-09-28

Recovery now offers SCAN SALVAGE SIGNALS during powered solo space flight. A deterministic system seed gives roughly one third of systems one derelict in an outer local-space band about 18 km away, beyond current compact planets. A Pathfinder or Merchant hull carries a small fuel/electronics cache and hull-salvage value. Scanning records the existing persistent wreck and a world discovery flag; repeated scans, completed salvage and save/reload cannot regenerate it. Existing physical collision, approach routing and selective recovery apply.

Domain checks passed deterministic generation, valid saved structure and duplicate/completed-reward rejection. Actual-main checks passed headlessly and in hidden Gamescope for the real scan menu, offline rejection, immediate discovery persistence, duplicate rejection after load and physical materialization at the recorded location. Existing recovery, combat and cruise checks in the harness passed. This is an instant system-wide beacon survey approximation: range-dependent scanning, authored debris, boarding, NPC survivors, repairable hulls and shared multiplayer salvage remain unfinished.


## Recovery flight contacts — 2026-09-28

The flight HUD now shows up to eight nearest active local recovery beacons as gold screen markers and outlined radar diamonds, with a salvage legend. Distant contacts use kilometres; close contacts use metres. Contacts derive from recorded absolute wreck positions, exclude completed/other-location records and distinguish hulls from freight caches. Nearby 3D beacon labels have an 800 m visibility range configured.

Actual-main hidden Gamescope checks passed a discovered derelict entering the contact list, nearest-eight ordering, exclusion of completed and remote records, and all existing recovery/survey assertions. The 18.1 km HUD marker and radar legend were visually inspected in a flight capture. Recorded beacon navigation is not a physical sensor-detection model or a selected-target/offscreen-arrow system. Existing placeholder cockpit and background art remain below target quality.


## Manual recovery beacon tracking — 2026-09-28

Recovery rows expose TRACK/UNTRACK, returning to manual flight without starting cruise. Approach also selects its beacon. The tracked local contact takes priority within the eight-contact HUD limit and receives a labelled offscreen direction indicator, including a BEHIND cue. A small angular dead zone stabilizes directly-behind targets; indicator margins keep its label away from screen edges and the radar. Tracking is transient and clears when rebuilding a system; completed records no longer draw.

Actual-main hidden Gamescope tests passed the real tracking button, no-autopilot behavior, toggle-off, and retention of a tracked contact outside the nearest-eight set. Front and behind captures were inspected; an initial behind-label overlap was corrected and recaptured. Existing survey/recovery checks passed. This uses the local recovery-contact range, not galaxy-wide target tracking. Dense unselected marker overlap remains an interface limitation.


## Flight marker label spacing — 2026-09-28

Screen-marker labels now use measured text bounds and bounded vertical placement to avoid each other, remain inside the flight HUD area and leave the radar clear. Displaced labels draw a guide line to their original brackets. When all nearby label slots are occupied, the bracket remains but its text is omitted. Tracked recovery contacts are processed first, and their offscreen annotation reserves space for following labels.

The existing actual-main recovery/tracking harness passed under hidden Gamescope, and a capture with three tightly grouped recovery beacons was visually inspected: previously overlapping labels became separate readable rows. This is simple per-frame placement; camera-motion stability and large mixed-contact stress testing remain open.

## Ranger walkable hull family — 2026-09-28

Added a third commissioned/refittable family: Ranger, a 25-cell single-deck exploration layout with a long bow, broad aft bays, five radiator modules and three habitat modules. Default fittings include quarters, lounge, medical and a cargo-bay workshop. It uses the existing equipment, cargo, crew, power and saved-family contracts, with silver/copper placeholder paint. Hull selection now describes each family's role.

Headless blueprint checks passed connected rooms, closed pressure skin, interior-corner containment and flight/coasting collision bounds for all three families. Initial origin-scaled Ranger profiles cut into concave room corners; its current pressure skin uses an unscaled extrusion. Fleet commission, save roundtrip and actor materialization checks passed. The real shipyard selector/refit action and saved Ranger assembly passed under hidden Gamescope. Seven Texture RID shutdown warnings remain in that harness.

Exterior, rear and interior-cutaway captures were generated; exterior and cutaway were visually inspected. The longer bow and wider aft plan distinguish Ranger, but the repeated fittings, blocky shell and materials remain far below the intended art target. Medical/workshop room fittings do not establish new medical or crafting gameplay. Ranger-specific moving boarding, berth clearance and target performance remain unverified.

Clean Windows release export at `a779d64` passed with no script/parse errors. This increment has not received a new Proton runtime smoke; the last full Proton integration evidence above remains `ab92e4d`.

## Ranger outward armor and fitted glazing — 2026-09-28

Ranger now uses outward polygon-offset rings instead of a vertical shell: 0.12 m at the keel, 0.6 m at the belt and 0.03 m at the roof. Collinear merge vertices are removed before matching rings; unsupported topology falls back to an unscaled shell. The original module collision bounds and room layout are unchanged. Family cockpit glass and frames now project onto the actual armor surface instead of using a fixed forward displacement.

An initial implementation silently fell back to the vertical shell. Visual inspection exposed it; a regression now requires sloped Ranger side normals as well as the existing closed-mesh, full interior containment and collision checks. After correcting vertex correspondence and float precision at the offset limit, these checks passed. New checks also require every cockpit glass vertex to remain outside all three family shells. Hidden Gamescope captures passed without script errors; Ranger's sloped outline and fitted glazing were visually inspected. This is a geometry improvement, not final-quality ship art or a performance result.

Clean Windows source `1bd35f52dc24a35f8e23b7728b967fc81616af53` passed release export and the full `NEXT_INTEGRATION_OK` smoke under hidden Gamescope/Proton Experimental. Evidence: `build/windows-validation-dd5c267/build/proton-smoke.2UOImS`. Wrapper, Proton and isolated-prefix cleanup returned 0. Known SDR white-level and Gamescope teardown messages remain; no Godot script errors occurred. The smoke exercises the existing broad gameplay sequence, not Ranger-specific boarding or live Steam multiplayer. The previously packaged ZIP has not been refreshed by this check.

## Ranger passage and crew navigation — 2026-09-28

Actual-main walking exposed a lounge table blocking Ranger's central passage: available side gaps were narrower than the player capsule. Lounge seating and the table now occupy corners, leaving both doorway axes clear. The 0.25 m port navigation bake also disconnected the physically passable cockpit/lounge doorway. Ship interiors now use 0.1 m navigation cells; open ports retain 0.25 m and the crew clearance radius stays 0.5 m.

Extended coasting and crew-roaming checks accept `--ranger` and are registered in Windows CI. Native headless and hidden Gamescope checks passed boarding a pitched/rolled Ranger coasting at 180 m/s, walking from its bow through the lounge/radiator bay into the main deck, origin rebasing, saving/loading moving hull state, helm return, collision damage and insured rescue. The moving-interior capture was inspected. The walk ends in the central deck; an earlier longer probe reached the aft wall and sampled a transient false floor flag despite remaining at deck height. Wall-contact floor-flag stability is not established here.

Ranger crew checks passed a cockpit-to-aft-outboard route over six cells in direct span, movement after cabin translation/rotation, capsule clearance during the tilted segment, pause/resume and arrival. Merchant roaming, custom coasting, crew lift transfer, crew yielding and shared blueprint containment regressions passed. Seven Texture RID teardown warnings remain in the actual-main graphical harness. Live multiplayer interiors and performance targets remain unverified.

Clean Windows release export at `a60f2f6` passed without script or parse errors. The last full Proton runtime smoke remains `1bd35f5`; this passage fix was exercised natively under hidden Gamescope.

## Ship doorway destination signs — 2026-09-28

Every connected horizontal cabin doorway now carries a destination-room label on each approach side. Names derive from the validated saved room layout, so lounge/medical/workshop refits change the signs. Labels face the source room, suppress mirrored back faces and follow the cabin transform. Existing room-identity labels only remain on closed forward walls, avoiding contradictory names on doorway headers. Signs add no collision geometry.

The new `test_ship_wayfinding.gd`, registered in Windows CI, passed exact directed-link coverage, destination names, orientation, header placement, transformed placement, refit updates and rebuild cleanup. Hidden Gamescope Ranger moving-interior checks passed; doorway text was visually inspected in the walking capture. Seven Texture RID shutdown warnings remain in that harness. These are local room identifiers, not a full deck map or route-to-destination navigation system.

Clean Windows release export at `266ae8d` passed without script or parse errors. No new Proton runtime check was run for this cosmetic change.

## Owned station orbital frame — 2026-09-28

Integrated the unfinished station exterior draft with paired vertical hoops, freight-door detailing, a central hub and rear spine. Corrected the draft's horizontal spokes to match the hoops' vertical plane, added axial braces between hoops and connected the rear spine to the keel at low station levels. The hoops use static concave mesh collision, preserving their openings; major girders, braces and spine use aligned box collision. Dock, launch and service interfaces are unchanged.

Station gameplay passed docking speed rejection, pad support, launch and faction/police interactions. Station interior checks passed physical walks to every service room and back, service use and saved-position recovery. The new superstructure test checks level 1 and 100 on a translated/rotated station: ring collision, a clear gap between supports, collision-free small/large +Z approach sweeps, initial-overlap rejection and rebuild cleanup. It is registered in Windows CI. Hidden Gamescope front/rear captures were generated and visually inspected; the replacement checklist was updated.

This remains an exterior blockout: the hoops do not rotate, contain walkable districts or simulate artificial gravity. Collision and approach checks do not establish automatic routing from every direction, arbitrary vessel clearance or target performance. Existing station service interiors remain separate from the new exterior frame.

Clean Windows release export at `89fec51` passed without script or parse errors. A new Proton runtime smoke was not run for this increment.

## Crew identity finishes — 2026-09-28

Helmeted actors now derive suit and armor colors from their actor identity while retaining faction tints and role patches. Named hired crew already save their identity, so this adds appearance continuity without changing the save format. Actors without persistent IDs use their existing instance-ID fallback; their colors are not guaranteed across sessions.

`test_crew_appearance.gd` passed a hired-crew save/reload round trip, palette variation, live rig material checks and unchanged movement capsule dimensions. It is registered in Windows CI. `capture_crew_palettes.gd` rendered four crew roles under hidden Gamescope and the image was inspected. The existing faction model capture remains available. These are color variations on the current placeholder rig, not human face/body customization or a player character creator.

Clean Windows release export at `bfc646e` passed without script or parse errors. No new Proton runtime check was run for this cosmetic change. The initial crew gameplay invocation omitted `-- --capture-only` and loaded an existing commander save with a different deck layout. Re-running the established CI command with that isolation flag passed named bodies, engineer/trader roaming, rotating-cabin support, menu pause, interaction, casualty persistence and exit cleanup. Ranger crew roaming also passed with the isolated fixture. Temporary navigation experiments were reverted; this investigation did not establish a navigation regression. The palette test alone does not establish cabin navigation correctness.

## Commander suit locker — 2026-09-28

Commander now links to a suit locker with a dedicated 3D preview, six fabric colors, four armor finishes and turn controls. Edits remain local to the preview until Apply; leaving discards them. Applying updates saved commander appearance and the first-person sleeve/cuff. Hidden previews stop rendering. The local carried-ship transfer also copies the commander appearance, keeping the record independent between home and visit states; remote player-body appearance replication is not implemented.

New persistence checks passed round-trip, missing-record defaults for current/version-2 saves, integral JSON normalization, setter bounds and transactional rejection of malformed records. The gameplay check passed actual menu navigation, preview color, rotation, discard, apply/save, sleeve/cuff colors, independent carried-state copies and hidden viewport behavior. Both checks are registered in Windows CI. The gameplay check also passed in hidden Gamescope; its 1440×900 capture was inspected. This is a usable suit-color customization step, not the full face/body character creator.

The existing state regression suite also passed. The graphical harness reported seven Texture RID shutdown warnings, as in earlier main-scene captures; no script errors were logged.

Clean Windows release export and full Proton integration smoke passed at `a1399fc` (`NEXT_INTEGRATION_OK`, wrapper exit 0). Evidence is in `build/windows-validation-dd5c267/build/proton-smoke.GXFd0m`. The smoke exercises existing integration flows and serialization; the new locker UI was exercised natively under hidden Gamescope. The known SDR white-level warning remains. This does not prove live Steam interoperability or the 1440p/60 performance target.

## Local stellar heating — 2026-09-28

Direct stellar exposure now feeds player and local NPC thermal loops, including powered-off player ships. A shared point-source helper uses catalog luminosity with an explicit compressed-distance mapping, hard planet shadows and orientation-dependent hull bounding-box absorption. Existing temperature derating and detection respond to this additional heat. The HUD reports absorbed stellar kW. The systemic-simulation document records the approximation and unimplemented surface, atmosphere, damage, remote-fleet and visitor behavior.

Pure checks passed inverse-square falloff, solar reference, proximity/radius floors, planet segment/tangent/inside/beyond-source cases, projected orientation and area scaling, and invalid values. Gameplay passed unpowered absorption, sustained near-star thrust derating, retreat cooling, eclipse, NPC wiring/heat, moving-cabin passenger independence, floating-origin invariance and saved temperature. Existing drive-heat gameplay and NPC thermal suites passed. The gameplay check passed under hidden Gamescope and its HUD capture was inspected. Both new tests are registered in Windows CI.

Clean Windows export and full Proton integration smoke passed at `559c087` (`NEXT_INTEGRATION_OK`, wrapper exit 0). Evidence is in `build/windows-validation-dd5c267/build/proton-smoke.fkuroT`. The dedicated stellar gameplay checks ran natively, including hidden Gamescope. The smoke does not establish live Steam interoperability, scientific full-scale flight or target frame rate.

## Stellar surface appearance — 2026-09-28

Replaced the large purple noise patches with finer filtered granulation, restrained convection, spot cores/penumbrae, slow surface motion and limb darkening. The shader now uses pure emission with disabled ambient/specular lighting; tuning keeps close surface detail visible instead of clipping to white. Increased primary sphere tessellation and added a soft, camera-facing additive corona with regular depth testing and conservative bounds. The corona is a visual approximation, not volumetric plasma.

Primary and direct-light colors follow a small artistic temperature ramp. Nebula systems use their physical catalog's Yellow Star kind rather than the purple nebula category for the primary. Universe seeds, generated data, black-hole disk/horizon and heat calculations are unchanged. The ramp is not spectral rendering; the global directional light is still approximate.

`test_stellar_appearance.gd` passed finite/bounded ramp, warm/cool colors and actual nebula material/light integration, and is registered in Windows CI. Hidden Gamescope near, distant and fully eclipsed captures were inspected; the opaque planet hides the star and corona. No shader/script errors were logged. Shader filtering fades unresolved granules, but temporal shimmer and target performance have not been benchmarked.

Clean Windows release export at `852f639` passed without script or parse errors. Shader rendering was checked natively under hidden Gamescope; the last full Proton smoke remains `559c087`.

## Planetary sun alignment — 2026-09-28

Orbital globe surfaces now derive the primary direction per fragment from a planet-local stellar position rather than a fixed scene-wide direction. Cloud/atmosphere illumination and weather directions follow each body's center-to-primary direction. Surface weather-shadow rays use the fragment-to-primary vector. The globe light function retains diffuse and rough specular response without adding more scene lights. The scene directional light now aims from the primary toward the origin.

The global directional shadow map does not describe the globe's corrected finite-source vector, so the globe's primary-light pass does not consume it. Other local lights retain attenuation. This fixes orbital phases, not all lighting: visual eclipses cast by other planets, near-surface terrain lighting, colony shadows and intensity falloff remain approximate. The thermal field and astronomical catalog are unchanged. Implementation uses Godot's [spatial light built-ins](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html#light-built-ins).

`test_planet_sun_alignment.gd` passed material vectors, primary-light orientation, invalid indices and translated-world invariance, and is registered in Windows CI. Hidden Gamescope day/crescent/night captures passed a day-to-night central brightness comparison and were visually inspected; the eclipsing globe no longer faces daylight away from the star. The weather capture fixture now positions cameras relative to the actual primary and retains its cloud-shadow brightness assertion; that graphical regression passed. Seven Texture RID shutdown warnings remain in these harnesses; no script/shader errors were logged.

Clean Windows release export and full Proton integration smoke passed at `e1cf3da` (`NEXT_INTEGRATION_OK`, wrapper exit 0). Evidence is in `build/windows-validation-dd5c267/build/proton-smoke.2NjSW7`. Dedicated phase/brightness checks ran natively under hidden Gamescope; no live Steam or frame-rate target claim follows from these checks.

## Orbital planetary eclipses — 2026-09-28

Orbital surfaces, clouds and atmosphere now share a target-relative sphere-occlusion shader. The primary-light contribution dims when another planet intersects its ray to the primary; local surface lights retain their normal attenuation. Buffers exclude the target, cap at eight occluders and remain independent of world translation. Current catalog systems contain at most eight planets. This is a point-source geometric approximation with screen-space edge antialiasing, not finite-star penumbrae or physical atmospheric scattering. Streamed terrain and colony lighting remain separate work.

The headless material-buffer test passed, including self exclusion, invalid requests and translated-world invariance. Hidden Gamescope captures passed central brightness comparisons for clear, eclipsed and beyond-primary positions; clear/shadow captures were visually inspected. The fixture adds an occluder between the primary and target, behind the camera. The render shows a dark central footprint with a lit rim. No script/shader errors were logged; the known seven Texture RID shutdown warnings remain. The new headless check is registered in Windows CI.

The buffer test also exercised more than eight synthetic candidates to verify truncation. A separate review found no concrete correctness defects. Clean Windows release export at `525cdac` passed without script, parse or shader errors. Dedicated eclipse rendering ran natively in hidden Gamescope; the last full Proton integration smoke remains `e1cf3da`. No target-frame-rate or live Steam claim follows from this validation.

## Streamed ground primary lighting — 2026-09-28

Streamed terrain now reconstructs planet-local fragment positions from its patch anchor, using the same primary-relative direct-light function and eclipse buffer as the orbital globe. Weather shadow rays also follow the fragment-to-primary direction. A shared shader include keeps the rough direct-light response consistent. Ambient ground fill remains; rock props, buildings, vessels and legacy surface scenes still use their existing lighting. This is not physical atmospheric light transport or a complete scene-lighting migration.

The new terrain alignment check passed real generated material comparisons, patch-anchor rebuild and world translation, and is registered in Windows CI. Hidden Gamescope captures passed ground brightness comparisons for clear, eclipsed, beyond-primary and opposite-primary conditions. Clear/shadow images were inspected. Existing terrain and weather checks and orbital day/crescent/night rendering passed with no script/shader errors. The ground capture deliberately hides separately lit geology and cloud geometry to isolate the material under test.

Clean Windows release export and full Proton integration smoke passed at `e4134e9` (`NEXT_INTEGRATION_OK`, wrapper exit 0). Evidence: `build/windows-validation-dd5c267/build/proton-smoke.Zjs3dp`. Dedicated ground-light render comparisons ran natively under hidden Gamescope. Live Steam interoperability and target performance remain unverified.

## Streamed rock lighting — 2026-09-28

Generated geology now shares one shader material across its rock variants. Each MultiMesh instance carries its patch-local translation in custom data; the shader combines this with the anchor and rotated/scaled vertex to evaluate the same primary direction, cloud shadow and planetary eclipse as streamed ground. Production terrain creation configures both materials. Mineral variation, filtered grain and small normal relief improve the replaceable placeholder surface without changing rock positions, geometry or colliders. Nearby-object cast shadows, building/vessel lighting and physical sky illumination remain unfinished.

The new geology check passed per-instance custom coordinates, shared material, globe-aligned light/shadow uniforms and translated-world invariance. It is registered in Windows CI. Existing geology collision/placement and large-radius placement checks passed. Hidden Gamescope rock captures passed eclipse, restored sunlight and opposite-primary brightness checks; clear/shadow captures were inspected, with no script/shader errors logged. The capture hides ground and the globe to isolate rock rendering; it does not validate building or vessel lighting or target frame rate.

Clean Windows release export at `e3ca1f6` passed with no script, parse or shader errors. Native graphical validation used hidden Gamescope; the last full Proton integration smoke remains `e4134e9`.

## Thermal overflow consequences — 2026-09-28

Excess thermal energy above the regulated loop ceiling now damages player/NPC hull without consuming shields. Energy first fills available temperature storage, then uses an explicit 25 MJ per hull-point gameplay conversion. Fatal exposure follows existing rescue, saved wreck, NPC debris and fleet damage paths. Recovery now also handles a destroyed parked hull using ship position when the commander is on foot. The HUD warns at the thermal ceiling.

Pure checks passed normal loads, cooling, radiator scaling, time-step composition at the ceiling, invalid values, shield bypass and nonnegative hull. Gameplay passed offline stellar damage, NPC damage/debris with no unassisted kill credit, player rescue/cooling, saved wrecks and parked-hull recovery coordinates. The gameplay test also passed in hidden Gamescope. Existing stellar heating, drive heat and NPC thermal suites passed. New checks are registered in Windows CI. This is local gameplay thermal failure, not component/material simulation or authoritative remote visitor damage.

Clean Windows export and full Proton integration smoke passed at `daa7f3f` (`NEXT_INTEGRATION_OK`, wrapper exit 0). Evidence: `build/windows-validation-dd5c267/build/proton-smoke.xXLELy`. Dedicated overflow gameplay checks ran natively, including hidden Gamescope. Live Steam interoperability and target performance remain unverified.

## Local NPC heat retreat — 2026-09-28

Local ship AI now temporarily replaces its course with a cooler sampled direction when stellar heating threatens an already hot loop. The search evaluates six axis directions at most once per second, keeps travel orders intact, and retains existing acceleration, fuel and obstacle constraints. Retreat suspends firing; a 550 K entry/500 K exit hysteresis avoids temperature-threshold chatter. Loss of stellar exposure clears it. The HUD labels detected retreating contacts.

A bounded hidden Gamescope check passed cooler-direction selection against the ordered destination, actual steering, preserved orders, firing suspension/recovery, thresholds, zero-heat and missing-source release, invalid/flat fields and bounded probe count. Existing NPC thermal and overflow/wreck gameplay regressions passed. The new test is registered in Windows CI. This is a reactive six-direction local search, not predictive safe routing or guaranteed survival, and does not affect remote abstract crew orders or player controls.

Clean Windows release export and full Proton integration smoke passed at `fd3c819` (`NEXT_INTEGRATION_OK`, wrapper exit 0). Evidence: `build/windows-validation-dd5c267/build/proton-smoke.aTqtHd`. Dedicated retreat behavior checks ran natively; no live Steam or target-performance claim follows from these results.

## Planet surveys and station sale — 2026-09-28

Added a world-local survey archive, proximity/speed/power-gated Navigation action and one-time orbital-station sale. Reward traits share the rendered ocean rule. The optional save field validates canonical system/planet keys, existing bodies, record limits and pending/sold states before applying loaded state. Carried-ship copies do not transfer the archive.

State tests passed record/dedup, invalid indices, reward accounting, repeat-sale rejection, save/load, missing-field compatibility and transactional malformed-record rejection. Gameplay passed distance, flight speed, offline systems, actual menu scan/sale actions and saves, duplicate prevention, station restrictions and separate-world archive behavior. The gameplay check ran under hidden Gamescope and the scrolled survey controls were visually inspected. Existing GameState regressions passed. New checks are registered in Windows CI. Multiplayer survey transactions remain disabled; this does not prove Steam economy authority or full exploration completion.

Clean Windows release export and full Proton integration smoke passed at `219a682` (`NEXT_INTEGRATION_OK`, wrapper exit 0). Evidence: `build/windows-validation-dd5c267/build/proton-smoke.N3vOme`. Dedicated survey UI and persistence checks ran natively, including hidden Gamescope. No live Steam economy or target-performance claim follows from these checks.

## Survey journal — 2026-09-28

Navigation now opens a browsable world-local survey journal. Records show planet/system names, atmosphere/ocean traits, system address and sold/unsold status. Numeric sorting, a pending-data filter and twenty-record pages keep UI construction bounded. Set Course synchronizes Navigation's selected address, chart destination and address input without initiating travel. Ordinary chart selections now also synchronize that address input.

Domain checks passed numeric order, non-overlapping pages, filtering, empty and out-of-range pages, and archive immutability. Hidden Gamescope gameplay passed empty state, actual paging/filter buttons, course selection and unchanged location/credits/archive while browsing. The journal capture was visually inspected. The scan/sale persistence regression also passed. Both new tests are registered in Windows CI. Known Texture RID shutdown warnings remain in the journal harness; no script/shader errors were logged.

Clean Windows release export at `c54a87c` passed without script or parse errors. Dedicated journal rendering ran natively under hidden Gamescope; the last full Proton integration smoke remains `219a682`.

## Host visitor admission and removal — 2026-09-28

Connected hosts can close/reopen new visitor admission and remove an admitted guest from Settings. Existing guests remain when admission closes. The transport gate is backed by the validated join-request gate, including already-connected pending arrivals. Reliable rejection gets a brief flush window before transport cleanup. Forced removal explicitly clears presence and broadcasts departure to remaining guests, excluding the removed peer. Settings refreshes when session membership/consent/power status changes. These are per-session controls, not persistent identity bans or property access permissions.

Real loopback ENet checks passed established-guest retention, locked admission, transport-connected late-join rejection, reopening, removal/client disconnect, remaining-peer presence cleanup and host/guest role restrictions. Existing multi-process network/layout/travel/departure regression passed. Hidden Gamescope menu checks passed host-only visibility, actual toggle wiring, live refresh and leave reset; the capture was inspected. Both new tests are registered in Windows CI. Known Texture RID shutdown warnings remain in the UI harness.

Transport behavior follows the documented [MultiplayerPeer admission and disconnect APIs](https://docs.godotengine.org/en/4.7/classes/class_multiplayerpeer.html). Steam transport extension behavior, live invites/relay, property replication and authoritative shared economics remain unverified or unfinished.

Clean Windows release export and full Proton integration smoke passed at `39001dd` (`NEXT_INTEGRATION_OK`, wrapper exit 0). Evidence: `build/windows-validation-dd5c267/build/proton-smoke.HNUh37`. Dedicated host controls used native loopback ENet and hidden Gamescope UI checks. The smoke does not establish live Steam moderation behavior or target frame rate.

### Ship equipment material separation

Opaque ship fittings reuse the fleet surface shader with per-material roughness and metalness. Three-family front, rear and cutaway captures completed under hidden Gamescope without script or shader errors; Ranger front view was visually inspected. The change is subtle at full-ship distance and does not establish cinematic quality. Windows Desktop export completed. A radiator capture mistakenly run with the dummy headless renderer failed because viewport textures are unavailable there; the corrected hidden-Gamescope run completed with RADIATOR_VISUAL_CAPTURE_OK and no script or shader errors. The resulting radiator capture was visually inspected.

### Survey planet courses

`test_survey_route_gameplay.gd` runs the journal button, retains a second-planet destination across menu changes and an actual `request_jump`/`_complete_jump` transition, then verifies that its explicit approach targets that planet. It checks remote, docked, aboard and surface guards, clearing, manual star selection and removal of stale survey records. Hidden Gamescope passed with `SURVEY_ROUTE_GAMEPLAY_OK` and no script/shader errors; the arrival menu capture was inspected. Existing journal unit and gameplay checks passed. The route is session-only and does not automatically jump or land.

Windows/Proton smoke at `1587af3` passed from the clean validation checkout: `build/proton-smoke.ZFa8Ru`, `NEXT_INTEGRATION_OK`, wrapper exit 0 and no script/runtime errors. The new route gameplay test also passed in native headless mode. The packaged smoke covers the general gameplay loop; exact survey-route assertions run in the native tests, not the packaged Windows executable.

### Atmospheric drag

`test_atmospheric_flight.gd` checks the analytic drag update, mass/area/orientation response, equal split steps, monotonic density taper and invalid-input handling. `test_atmospheric_drag_gameplay.gd` passed under hidden Gamescope with no script/shader errors: world density and rebasing, airless/vacuum momentum, unpowered and fuel-empty player flight, exactly one coasting drag step, real moving-interior field wiring and loaded NPC drag. The HUD capture was inspected; it shows separate air-drag and zero-thrust readings, but the dark surface view is not a visual-quality acceptance image.

Existing inertial-flight and coasting-navigation checks passed. The actor regression initially failed its timer-based firing assertion both here and on unchanged `1587af3`; replacing elapsed-time waits with actual physics-frame waits fixes the harness without changing combat behavior.

Atmospheric-drag build `97a4c5e` passed clean Windows export and Proton smoke (`build/proton-smoke.5SDqfV` in the Windows validation checkout): `NEXT_INTEGRATION_OK`, wrapper exit 0 and no script/runtime errors. The final atmospheric gameplay test also passed headless for CI. This does not establish aerodynamic realism, frame-rate targets or multiplayer interoperability.

### Drag energy and ship heat

`test_aerodynamic_heat.gd` checks the kinetic-energy fraction, split-loss conservation, finite-input guards, heat capacity and capped-store overflow. `test_aerodynamic_heat_gameplay.gd` passes headless and under hidden Gamescope: real pilot/coasting drag heats the shared ship state immediately, temperature survives save/load, vacuum adds none, NPC excess heat bypasses shields and creates debris without a free player kill, and fatal player exposure triggers deferred rescue. The AIR HEAT/AIR DRAG HUD capture was inspected; it is a telemetry check, not an art acceptance image.

GameState, atmospheric-drag gameplay, thermal-overflow unit and thermal-overflow gameplay regressions passed. The heat partition is a fixed 10% gameplay approximation, not validation of real re-entry temperatures or material failure.

Clean Windows export and Proton smoke passed at `542ae8b`: validation checkout evidence `build/proton-smoke.SAbkD8`, `NEXT_INTEGRATION_OK`, wrapper exit 0 and no script/runtime errors. Exact drag-heating assertions run in the native tests; the Windows smoke covers the general gameplay loop.

### Open engine bells and aft outlets

ShipVisual now uses shared lathed geometry for thick flared mouths, dark interior liners and recessed luminous throats. Engines in one contiguous module column share an external aft outlet pair, including the starter engine ahead of its cargo room. Power and thrust still control the recessed glow. This is visual outlet routing, not simulated duct clearance or damage; cosmetic nozzle extensions do not add separate collision shapes.

Native geometry and outlet checks passed, including surface normals, invalid profiles, FleetShipVisual placement, shared outlets, starter exhaust and shutdown. The existing ship-power gameplay regression passed. Three-family captures completed under hidden Gamescope; front views and the Ranger engine close-up were inspected. The hulls remain blocky placeholders and do not meet the cinematic visual target. Both new tests are registered in Windows CI.

Clean Windows export and hidden-Gamescope Proton smoke passed at `92160f6`: `build/proton-smoke.6Y9LyF` in the validation checkout, `NEXT_INTEGRATION_OK` and wrapper exit 0. Exact nozzle assertions run in native tests; the Windows smoke covers the general gameplay loop. A platform SDR-white-level warning remains; no script/runtime errors were logged.

### Hull service detail and coating seams

Exposed family flanks now carry compact four-mesh service strips on the upper armor slope. Occupied neighbor faces, cockpits, configured panels and exposed radiator faces are skipped. The shared surface shader staggers alternate panel rows and adds narrow filtered coating wear. It derives panel footprints before staggering, avoiding derivative spikes at row boundaries. Pressure volumes are unchanged.

The first graphical run exposed an inferred typed-array mismatch in the optional radiator-face list; an explicit typed empty array fixes it. Subsequent three-family hidden-Gamescope captures completed without script/shader errors. Pathfinder exterior and Merchant rear were inspected; the detail breaks up blank flanks but remains repetitive placeholder art. Existing radiator and hull-family refit checks passed; the final refit rerun had no script errors.

Clean Windows release export at `e2d6424` passed without script/export errors (`build/hull-flanks-export.log` in the validation checkout). This visual increment was rendered natively under hidden Gamescope; the last full Proton smoke remains `92160f6`.

### Parked ship landing gear

The parked display now creates four broad pads with piston struts, sleeves and hull collars instead of two skids beneath every bottom-deck module. Support positions use extreme occupied bottom cells with in-cell offsets. Their contact plane preserves the existing parked height and surface-normal orientation. Flight visuals do not deploy gear. These are visual supports, not suspension, load-bearing physics or terrain-adaptive feet; boarding remains the existing transition.

`test_landing_gear.gd` passes for all three families and a multi-deck layout: opt-in deployment, four finite supports, feet on the lowest contact plane and placement within occupied bottom-cell footprints. The anchored-interior regression passes parked/rotated hulls and return placement. Final import passes without script errors after restoring a peer-collision center declaration accidentally removed during the edit. Three-family landed captures passed under hidden Gamescope; Merchant landed view was inspected. The new test is registered in Windows CI.

Clean Windows export and hidden-Gamescope Proton smoke passed at `514a0f1`: `build/proton-smoke.RY5fs1` in the validation checkout, `NEXT_INTEGRATION_OK`, wrapper exit 0 and no script/runtime errors. Exact gear geometry checks are native; the Windows smoke validates the general gameplay loop.

### On-foot parked boarding

F now enters a nearby parked walkable ship without opening the command deck; E retains launch behavior. Boarding rejects distant pilots, flight, open UI, charging jumps, connected visits, non-walkable hulls and repeated entry. Parked interior hints and entry notifications now say Return outside rather than Return to helm. The existing menu convenience and moving-interior entry remain available. This still uses the existing boarding zone and interior transition; it does not add a physical airlock or ramp.

The new fixture checks guard conditions, actual F entry into a supported walking interior, context hints, E exit and retained E launch. A graphical run initially showed that a post-frame return-position assertion included subsequent capsule motion; the final check measures restoration immediately before another physics step, at 1 mm tolerance. Final hidden-Gamescope run passed with PARKED_BOARDING_OK and no script/shader errors, and its interior screenshot was inspected. The anchored-interior regression passed. The fixture is registered in Windows CI; README and in-game controls were updated.

Clean Windows release export at `bb69fd8` passed without script/export errors (`build/parked-boarding-export.log` in the validation checkout). Boarding interaction checks ran natively under hidden Gamescope; the last full Proton smoke remains `514a0f1`.

### Partial fleet market sales

Inbound traders now sell the quantity a destination market can receive, retaining remaining cargo and purchase basis at that destination. Each partial sale allocates an integer share of the original invoice; rounding stays in the remaining basis, so the final sale accounts for the exact full cost. Legacy cargo with unknown basis does not invent realized profit. Revenue replenishes route escrow before crediting the commander. Reports include remaining units. Station supply delivery behavior is unchanged.

Partial unloading requires no return-jump fuel and does not change the ship's system, flight record or inbound phase. It still requires local-arrival readiness when represented and pays the normal attempt wage. The final unload/return remains coupled to the existing fuel gate; decoupled unloading and departure, alternate market selection and predictive route planning remain unfinished.

`test_partial_trade.gd` passes headless and under hidden Gamescope: zero-fuel partial unloading, unavailable-local-actor gating, full-market waits, stock/credit/escrow conservation, exact invoice allocation through save/load and final sale, and unknown legacy basis. Existing cost-basis, local-trade and station-supply regressions pass without script errors. The new check is registered in Windows CI.

Clean Windows export and hidden-Gamescope Proton smoke passed at `d34c454`: `build/proton-smoke.63udzG` in the validation checkout, `NEXT_INTEGRATION_OK`, wrapper exit 0 and no script/runtime errors. Exact partial-sale assertions are native; the packaged smoke covers the general gameplay loop.

### Fleet route discovery

Fleet operations can scan 32 consecutive system addresses from the selected destination, across all commodities at the requested quantity. Up to five positive operating estimates are sorted by margin, with deterministic destination/commodity tie breaks. Eligibility requires an idle healthy vessel, empty hold, cargo capacity, origin stock, receiving capacity, a replacement-fuel quote and enough credits for escrow plus estimated wages/fuel. The empty-hold restriction avoids ranking unknown carried inventory costs. Discovery is read-only; choosing a result fills the existing order form and does not reserve prices or assets. This is bounded route discovery, not automatic rerouting or a galaxy-wide optimum.

Domain tests pass ordering, quote parity, address bounds, eligibility, market limits, budget and no mutation. UI tests pass real discovery/selection, unchanged state before assignment and actual order fields after assignment, including selecting the last result to check callback binding. Native headless and hidden-Gamescope runs pass without script/shader errors; the menu screenshot was inspected. Existing running-cost quote/UI checks pass. Both new fixtures are registered in Windows CI.

Clean Windows release export at `cb3b25b` passed without script/export errors (`build/route-discovery-export.log` in the validation checkout). Exact discovery/UI checks ran natively; the last full Proton smoke remains `d34c454`.

### Adaptive trader destinations

An opt-in Adaptive Trade order fixes the commodity, quantity, origin and 32-address search range, then selects the best current positive operating estimate before each empty outbound purchase. It spends only the original route escrow, never replenishing cargo capital from commander credits. Normal wages and separately configured fuel allowances retain their existing behavior. No viable or affordable route produces a waiting report without a purchase, movement or jump-fuel deduction. Inbound cargo continues to its chosen buyer, including partial sales.

The optional validated `search_start` save field retains this policy; fixed-route and station-supply saves retain their prior form. Adaptive destinations must remain in the saved range, and adaptive station supply is rejected. Tests passed live destination switching after a market fills, wage-only waiting, capital limits, inbound save/load, malformed-save rejection without state mutation, and escrow refund on cancellation. Discovery and partial-sale regressions pass. Hidden-Gamescope UI checks assigned an adaptive order through its actual button after ordinary route selection/assignment checks. Import and all final logs were free of script errors. This is bounded destination selection, not commodity switching, predictive trading or a guarantee of profit after transit.

The final adaptive fixture starts with exactly the quoted purchase, two wages and replacement-fuel budget. Adaptive selection accounts for the departure wage already paid by `tick`, avoiding a duplicate budget requirement. That exact-budget case and the later waiting/cancellation checks pass.

Clean Windows export and hidden-Gamescope Proton smoke passed at final code `d1bb1a7`: `build/proton-smoke.h3b2qu` in the validation checkout, `NEXT_INTEGRATION_OK`, wrapper exit 0 and no script/runtime errors. Dedicated adaptive assertions ran natively; the Windows smoke covers the general gameplay loop.

### Fine settlement and repeat assaults

Successful fine payment clears prior assault-report markers on surviving local actors, so a new attack on the same victim creates a new criminal alert. Police hostility updates immediately; ship police also clear their pursuit memory when criminal settlement makes them neutral. Diplomatic hostility remains independent, and the payment notification explicitly explains it. The UI shows the amount and shares flight/interior/funds/no-fines guards with the action. Failed saving is reported rather than presenting the payment as durably saved. Existing on-foot settlement access remains unchanged; this does not implement surrender, arrest or local criminal jurisdictions.

The hidden-Gamescope fixture used actual weapon rays against a surviving guard, paid and reloaded the fine result, then hit the same guard again. It passed immediate ground/ship police de-escalation, pursuit clearing, repeat-incident reporting, no double charge, insufficient-funds/flight/interior rejection and preserved diplomatic hostility. Menu amount/disabled states passed and the screenshot was inspected. The new fixture is registered in Windows CI.

The same fine-settlement fixture also passed headless, as did the faction regression. Clean Windows release export at `cdf5e0b` passed without script/export errors (`build/fine-settlement-export.log` in the validation checkout). The last full Proton smoke remains `d1bb1a7`.

### Peaceful patrol fine settlement

Allegiances & Law now offers an in-flight payment through a living, unculled police ship within 350 m and an unobstructed physics ray. The player must be at the flight controls, below 5 m/s, not charging hyperdrive, have sufficient credits and have no hostile local diplomatic stance. Multiplayer visits reject this local-only action. The transaction shares normal fine settlement, stops autopilot, preserves cargo/position/ship and saves the cleared wanted status. This is a peaceful payment interaction, not arrest, impoundment or a modeled inspection sequence.

The hidden-Gamescope test passed missing/distant/culled/destroyed patrols, speed, funds, charging and visit guards, diplomatic hostility, a real blocking StaticBody, actual menu activation, unchanged cargo/location, exact payment, saved state and repeat-charge rejection. Its menu screenshot was inspected. Native headless patrol checks and the prior fine-settlement regression also passed. The new test is registered in Windows CI.

Clean Windows export and hidden-Gamescope Proton smoke passed at `a2ef101`: `build/proton-smoke.obTYIT` in the validation checkout, `NEXT_INTEGRATION_OK`, wrapper exit 0 and no script/runtime errors. Patrol-settlement assertions run natively; the packaged smoke covers the general gameplay loop.


### Parked crew access ramps (2026-09-28)

- `d07c440`: `test_parked_boarding.gd` passes headless and under hidden
  Gamescope, including capsule support on the slope, outward surface normals,
  collision disable/restore on visibility, and existing F entry/E return/launch.
- All three family captures complete under hidden Gamescope; Merchant landed
  capture visually inspected after correcting the ramp triangle winding.
- Clean Windows export and hidden-Gamescope Proton integration pass on `d07c440`:
  evidence `build/windows-validation-dd5c267/build/proton-smoke.IG1r9J`, wrapper
  exit 0 and `NEXT_INTEGRATION_OK`. General packaged smoke does not exercise
  every dedicated ramp assertion. An SDR white-level warning remains.
- Earlier hull/material changes also passed Windows/Proton on `40ec67f`
  (`proton-smoke.A5Kvi3`).
- No claim of seamless boarding, terrain adaptation, moving airlocks or final art.


### Hatch-aligned parked entry (2026-09-28)

Parked F boarding uses the exterior access assembly's selected module coordinate
and faces inward. The optional entry is accepted only for a present interior cell,
on the player's parked ship; menu, fleet and coasting entry keep their prior spawn.
`test_parked_boarding.gd` passes with supported arrival in the adjoining room for
Pathfinder, Merchant and Ranger. The Pathfinder arrival render was inspected.
The hidden-Gamescope run exits 0 but reports seven leaked Texture RIDs at renderer
shutdown; this cleanup warning is unresolved. Anchored and coasting interior
regressions pass headless. No seamless door traversal is claimed.


### Automatic interior bulkheads (2026-09-28)

- Four telescoping panels form one door at each shared boundary between different
  room roles. Collision follows the panels, opening takes 0.4 s, and departure
  starts a 0.8 s hold before closing. Occupants keep it open from either side.
- `test_ship_bulkhead.gd` verifies closed collision, capsule passage, occupancy
  hold, two-sided triggering, exactly one door per boundary and a crew route
  through the closed automatic door. A layer-2 enclosing ship cannot trigger it;
  only crew and aboard-player layers are sensed. Registered in Windows CI.
- Blueprint containment, crew roaming and coasting-interior regressions pass.
  Parked boarding passes under hidden Gamescope; the cabin render was inspected.
- These are automatic physical doors, not pressure compartments. Power failure,
  locking/access permissions, atmosphere exchange and breach damage remain absent.
- Final Windows export and hidden-Gamescope Proton integration pass at `070a303`:
  `build/windows-validation-dd5c267/build/proton-smoke.QKnjQG`, wrapper exit 0,
  `NEXT_INTEGRATION_OK`. Dedicated door assertions run natively; packaged smoke
  is general integration coverage. Earlier `6dcbfaf` also passed before the
  enclosing-hull sensor correction (`proton-smoke.9Pfngb`).


### Paired visitor save recovery (2026-09-28)

`38172a7` passes `test_visit_journal.gd` (ordinary pair, interruption after visitor
replacement, replay after completed replacement, malformed snapshot/no writes,
canonical visitor destination and actual failed-home-write retry). `test_visit.gd`
passes separate economies and carried ship persistence, plus retaining the live
visitor profile when return saving fails and refusing a destructive reload.
`test_state.gd` passes after extracting validated dictionary loading.

Clean Windows export and hidden-Gamescope Proton smoke pass at `38172a7`:
`build/windows-validation-dd5c267/build/proton-smoke.bET0er`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated journal failure injection was native; the packaged
run is general integration coverage. Filesystem power-loss durability, simultaneous
process access and live Steam transfer authority are not established. The user
confirmed no NeXt Steamworks AppID exists yet; native Steam setup remains pending.


### Multiplayer protocol admission (2026-09-28)

`589bc0e` passes the real ENet-scope `test_network_protocol.gd`: different and
missing join versions are rejected before admission; a missing welcome version
leaves world identity unchanged; normal versioned joins succeed; client handshake
timeout clears transport; the host removes silent peers and preserves admitted
ones. Deadline callbacks are accelerated in this fixture. Existing multi-process
network travel/presence and negotiated-loadout/PvP regressions also pass. The new
fixture is registered in CI. This is protocol validation, not a live Steam test or
proof of interoperability with every historical binary.

Clean Windows export and hidden-Gamescope Proton integration pass at `589bc0e`:
`build/windows-validation-dd5c267/build/proton-smoke.sWvWbf`, wrapper exit 0,
`NEXT_INTEGRATION_OK`. Packaged smoke is general integration; the ENet protocol
assertions above ran natively.


### Combined flight acceleration (2026-09-28)

Pilot and coasting-hull telemetry now retain the world-space vector sum of
applied propulsion and atmospheric drag. The HUD displays its magnitude as
NET ACCEL in standard g; opposing thrust and drag cancel. Teleports, collision
impulses, rotation and gravitational acceleration are excluded, so this is not a
crew physiological load model. Flight forces themselves are unchanged.

`test_acceleration_vector.gd` passes signed-vector and finite-input checks, actual
hull braking, thrust/drag cancellation, zero-step reset and collision separation;
it is registered in CI. Flight-dynamics, coasting-hull and coasting-navigation
regressions pass. The atmospheric gameplay test passes under hidden Gamescope
with additional player-vector assertions. Its HUD capture was inspected for
readable, nonoverlapping telemetry; the dark test scene is not art acceptance.

Clean Windows export and hidden-Gamescope Proton integration pass at `eadc098`:
`build/windows-validation-dd5c267/build/proton-smoke.M8oHak`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Packaged smoke covers general gameplay; the dedicated
acceleration assertions above ran natively. No performance or Steam claim follows.


### Functional ship medical bays (2026-09-28)

A configured medical room now restores the commander's existing session health
to 100 using one medicine cargo unit. Treatment requires standing inside the
room aboard the active ship, online systems and a living commander; fleet
inspection, world visits and charging hyperdrive cannot use it. F prioritizes
the medical terminal while inside the bay; the overview menu provides the same
action, health, stock and disabled-reason tooltip. Full health consumes nothing.
The medical cabinet has a replaceable treatment sign. This adds neither hunger
nor thirst, a crafting recipe, crew injury simulation nor a persistent injury model.

`test_medical_bay.gd` passes under hidden Gamescope: supply/power/rescue/fleet
guards, adjacent-room and other-deck rejection, translated/rotated room bounds,
keyboard and menu actions, repeated-use rejection and saved cargo debit. The
treatment overview capture was inspected. Existing anchored-interior walking,
rotated gravity, doorway, lift and saved-position regression also passes.

The final medical fixture also passes headless with explicit visit and hyperdrive
guards. Clean Windows export and hidden-Gamescope Proton integration pass at
`07df9f8`: `build/windows-validation-dd5c267/build/proton-smoke.51qmpz`, wrapper
exit 0 and `NEXT_INTEGRATION_OK`. Dedicated treatment assertions were native;
the packaged smoke covers the general gameplay loop.


### Persistent commander health (2026-09-28)

Commander health is now a validated optional save field, defaulting to 100 for
older saves. The existing suit-health property reads and writes that state,
including clamping fatal damage to zero. Landing no longer restores health.
Visits carry current commander health in both directions, including replacing
stale visitor health on a later arrival. This supersedes the session-only health
limitation in the preceding medical-bay entry; crew injuries remain unimplemented.

`test_commander_health.gd` passes file roundtrip, missing-field compatibility,
atomic rejection of invalid/nonfinite/type-confused values, real-scene reload,
landing without healing, and loading a zero-health save through the existing
250-credit medical rescue exactly once. `test_visit.gd` now checks incoming,
returning and revisiting health. Medical-bay tests confirm restored health is
saved together with the medicine debit. GameState and paired-visit journal
regressions pass. The new fixture is registered in CI.

Clean Windows export and hidden-Gamescope Proton integration pass at `dc3b9da`:
`build/windows-validation-dd5c267/build/proton-smoke.enTAep`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Health-specific assertions ran natively; the packaged
smoke covers the general gameplay loop, not live Steam authority.


### Background market supply and demand (2026-09-28)

Each modified system/commodity inventory now moves toward its deterministic
nominal stock by at most 10% of that stock per simulation day. Shortages receive
background supply; surplus is consumed. Settlement uses the existing active-time
and jump-driven economic day, never wall-clock load time. Balanced records are
removed, and untouched markets stay sparse. Exchange rows show the next daily
flow. This approximates outside logistics and demand; no factory inputs, physical
background haulers, or material conservation for that outside economy are claimed.

`test_market_flow.gd` passes bounded flow, read-only quotes, fractional-day save
continuation, no loading restock, fixed-day scarcity-price response, remote full
markets, separate-world isolation, batched/split steps and sparse equilibrium.
`test_market_inventory.gd` now verifies resupply at the 10,000-market record cap
and an actual waiting crew trade unloading after daily demand frees capacity.
Calendar, adaptive trade and partial delivery regressions pass. Hidden Gamescope
passes the flow fixture, and its exchange screenshot was inspected for readable
flow labels and order buttons. The flow fixture is registered in CI.

Clean Windows export and hidden-Gamescope Proton integration pass at `f61dd11`:
`build/windows-validation-dd5c267/build/proton-smoke.iTL5wN`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Market-flow assertions were native; the packaged run
covers general integration, not shared market authority or frame-rate targets.


### Station output exports (2026-09-28)

`test_station_export.gd` passes native and hidden-Gamescope checks: no purchase
escrow, empty-storage waiting, finite station-to-hold transfers, unchanged source
market inventory, save/load of loaded cargo and source station, atomic rejection
of malformed/mismatched source references and conflicting route modes, full-market
waiting, partial revenue without invented manufacturing profit, and cancellation
retaining cargo. A real scene checks the station pickup target, local position
continuity, arrival-gated selling and return target. Crew Operations exposes the
export action; its rendered controls were inspected. The GPU run reported the
known seven Texture RID cleanup warning at shutdown.

Station-supply, adaptive-trade and partial-sale regressions pass. The new fixture
is registered in CI. This does not validate live Steam logistics, physical remote
transit, production invoice accounting or performance targets.

The final native fixture also verifies a remote exporter returns to its station
system before loading. Clean Windows export and hidden-Gamescope Proton
integration pass at `06beb81`: `build/windows-validation-dd5c267/build/proton-smoke.e8atmy`,
wrapper exit 0 and `NEXT_INTEGRATION_OK`. Export-specific assertions ran natively;
the packaged smoke covers general integration.


### Planetary flight gravity (2026-09-28)

`test_planet_gravity.gd` passes surface and doubled-radius field samples, bounded
interior/center behavior, rebasing, hidden/surface-world exclusion, constant-field
free fall, powered coasting navigation, powerless guidance, real pilot hover fuel
consumption, inertial/empty-tank falling and powerless NPC acceleration without
false drag heat. Flight-safety, acceleration-vector, flight-dynamics and coasting
navigation regressions pass. Moving-interior save/return checks now compare the
actual gravity-modified velocity. The isolated inertial-control test disables its
external field; actual gravity interaction is asserted in the new fixture.

The atmospheric gameplay test passes under hidden Gamescope with vacuum and
airless expectations including gravity but no drag. Its HUD capture was inspected:
gravity and net acceleration are readable and separate. Coasting-interior and
inertial-control regressions pass. NET ACCEL now includes gravity, superseding
the earlier thrust/drag-only telemetry scope; it is not physiological g-load.

Packaged smoke initially exposed two obsolete constant-velocity assertions. It
now checks actual gravity-modified helm/save momentum and the predicted gravity
step during unpowered inertial flight. Clean Windows export and hidden-Gamescope
Proton integration pass at `9b32428`: `build/windows-validation-dd5c267/build/proton-smoke.lRuzyW`,
wrapper exit 0 and `NEXT_INTEGRATION_OK`. This verifies the packaged gameplay
loop with local gravity, not astronomical accuracy, long-term orbital stability
or performance targets.


### Planet-dependent walking gravity (2026-09-28)

`test_walking_gravity.gd` passes integrated planet/altitude and rebasing samples,
ship/station artificial-gravity overrides, separate-colony gravity and invalid
field fallback. Actual collision-floor jumps using the same 6 m/s impulse peak
within 5.5–6.5 m at 3 m/s² and 1.2–1.8 m at 12 m/s². Input and movement run
across real physics frames, not multiple input steps in one frame.

Parked-boarding and anchored-interior regressions pass. The latter now checks
the current gravity-displaced hull position at save and helm return rather than
an obsolete stationary anchor. The walking fixture is registered in CI.

The walking fixture also passes under hidden Gamescope. The colony HUD capture
shows 1.22 g for the fixture's 12 m/s² planet, with readable telemetry. The foot
mode caption now says ON FOOT rather than implying an implemented magnetic-boot
system. This is a mechanics check, not visual-quality acceptance.

Clean Windows export and hidden-Gamescope Proton integration pass at `e87a866`:
`build/windows-validation-dd5c267/build/proton-smoke.oty9HI`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated jump-height assertions ran natively; packaged
smoke covers general gameplay, including planetary walking and interior support.


### First-person landing injuries (2026-09-28)

`test_landing_injury.gd` uses actual collision-floor drops. Short descent and
tangential motion remain harmless; a 5 m fall injures the commander without
altering ship hull/shields, and health survives file roundtrip within JSON float
precision. Invalid/safe speeds and flight-mode calls are rejected. A 20 m fall
triggers deferred medical rescue, applies the 250-credit fee, persists restored
health and creates no ship wreck. The fixture is registered in CI.

Walking-gravity jump measurements and medical-bay treatment regressions pass.
The impact threshold/damage curve is gameplay tuning; EVA, biomechanics, ground
NPC injuries and impact sound/animation work remain open.

Clean Windows export and hidden-Gamescope Proton integration pass at `9308cd1`:
`build/windows-validation-dd5c267/build/proton-smoke.U7YYHJ`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated drop/injury assertions ran natively; packaged
smoke covers general gameplay.


### Ground combat contact memory (2026-09-28)

`test_ground_contact.gd` passes real collision-ray acquisition and a wall hiding
a moving target. A navigation probe confirms pursuit retains the last visible
position. Covered targets receive no further fire; six-second expiry returns
the actor to patrol, removing cover reacquires the moved target, switching to
a distant target clears old contact, and peaceful status clears tracking.
`test_ground_actor_behavior.gd` still passes post holding, friendly following,
patrol radius and pursuit leash behavior. The contact fixture is registered in CI.

Clean Windows export and hidden-Gamescope Proton integration pass at `53980de`:
`build/windows-validation-dd5c267/build/proton-smoke.7Wkn0U`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated contact assertions ran natively; packaged smoke
covers general gameplay. The earlier interrupted `proton-smoke.ZDEDAo` run
produced no completion marker and is not counted as a pass.

Follow-up review found remembered pursuit bypassed the immediate home-return
order when a previously acquired target crossed the pursuit radius. Chasing
now retains the leash condition; the contact fixture passes an additional
acquire-then-leave-radius assertion.

The corrected code at `5d7d653` passes both native ground fixtures and a fresh
Windows/Proton integration run under hidden Gamescope:
`build/windows-validation-dd5c267/build/proton-smoke.CgmFH5`, wrapper exit 0,
`NEXT_INTEGRATION_OK`.

### Ground NPC gravity (2026-09-28)

`test_ground_gravity.gd` passes live port-resident bindings, all four flat-colony
residents and five outlaw bindings, independence from player boarding/docking
and selected planet, artificial-deck fallback, measured 3 and 12 m/s² airborne
velocity changes, zero-gravity drift and invalid callback fallback. The test
is included in Windows CI's native fixture stage. Ground contact and actor
behavior regressions pass.

The shared player walking-gravity fixture also passes after extracting the
planet sampling helper. The NPC fixture additionally verifies actual ShipCrew
acceleration along a rotated cabin's up vector, matching artificial deck gravity.

Crew roaming regression passes, including moving cabins and unreachable routes.
Clean Windows export and hidden-Gamescope Proton integration pass at `784f6f6`:
`build/windows-validation-dd5c267/build/proton-smoke.7AlPTZ`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated NPC gravity assertions ran natively; packaged
smoke verifies general gameplay, not arbitrary planetary NPC navigation.

### Directional ground awareness (2026-09-28)

The contact fixture now begins with the guard facing away: no sight acquisition
or shot occurs. A finite impact-origin event turns the guard toward the attacker
and allows subsequent unobstructed acquisition; invalid origins are ignored.
A simulated impact behind cover records only its supplied origin, without
shooting through the wall or revealing the target's changed location. Existing
expiry, reacquisition, target isolation, peace and pursuit-leash assertions pass.
The post-guard fixture explicitly faces its target and still verifies holding,
shooting and damage. Attack awareness is wired into the player's ground-hit path.

The contact fixture also checks 59-degree acceptance and 61-degree rejection
around the 60-degree half-angle. Clean Windows export and hidden-Gamescope
Proton integration pass at `b61f836`:
`build/windows-validation-dd5c267/build/proton-smoke.sCcJgx`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Directional-awareness assertions ran natively; the Windows
run covers general gameplay.

Review caught a first-hit ordering issue: newly assaulted police were still
neutral when receiving the impact event. The player-hit path now updates police
hostility before delivering that event. `test_ground_attack.gd` fires a real
player ray into a neutral guard's back and verifies damage, assault reporting,
immediate hostile contact and facing toward the origin. This fixture passes
and is registered in CI.

Corrected first-hit integration at `0b8f33a` also passes clean Windows export
and hidden-Gamescope Proton smoke: `proton-smoke.Xn2OzU` under the same validation
build directory, wrapper exit 0 and `NEXT_INTEGRATION_OK`.

### Local ground radio (2026-09-28)

`test_ground_radio.gd` verifies live resident signal wiring, actual visual
acquisition by a source, a nearby ally behind a collision wall receiving the
observed position, and exclusion of neutral, inactive, different-faction, distant
and other-colony actors. Reports are rate limited. A blocked recipient neither
fires nor rebroadcasts and cannot track hidden movement; its memory expires
without another sighting. Contact, first-assault and ground behavior regressions
pass. The radio fixture is registered in CI.

Clean Windows export and hidden-Gamescope Proton integration pass at `b2e5453`:
`build/windows-validation-dd5c267/build/proton-smoke.GLmZYc`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated radio assertions ran natively; packaged smoke
covers general gameplay. Read-only parallel review found no further defect.

### Hull finish and capture visibility (2026-09-28)

The shared hull material adds restrained coating chips near plate seams, a
primer transition and low-frequency maintenance staining. Exposed metal changes
roughness/metalness and removes clearcoat; wear fades with projected pixel size.
The family capture runner now includes a close surface view of each actual hull.
Initial bright repetitive wear was reduced after inspecting GPU captures. This
is a material-detail increment, not photorealistic ship art.

Capturing cutaways exposed bulkheads querying Area3D overlaps while deferred
visibility changes had monitoring disabled. The physics callback now waits
until monitoring is enabled. The subsequent hidden-Gamescope three-family
capture run has no engine errors; `test_ship_bulkhead.gd` passes closed collision,
two-sided approach, capsule clearance and occupancy hold.

Final close-detail captures for all three families complete without engine
errors. Read-only review found no concrete material or sensor-guard defect.
Clean Windows export and hidden-Gamescope Proton integration pass at `bef0056`:
`build/windows-validation-dd5c267/build/proton-smoke.yZMumT`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Screenshots were visually inspected; neither these images
nor the smoke test establishes cinematic quality or the 1440p/60 target.

### Exterior identification stencils (2026-09-28)

Family and role designations are placed on exposed core roofs; cargo leaves
carry bay indices and lifting cues, and reactor covers carry heat warnings.
Labels use shaded, non-billboarded text without outlines. Hidden-Gamescope
captures of all three families complete without engine errors. Visual review
found the initial text direction faced aft; the labels now face the bow.
These add scale and identification, not unique registrations or finished art.

Corrected close-up was visually inspected; all three capture sets are free of
engine errors. Parallel placement review found no overlap/orientation defect.
Clean Windows export and hidden-Gamescope Proton integration pass at `e68982e`:
`build/windows-validation-dd5c267/build/proton-smoke.CYa4qH`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Distant legibility and overall art quality remain limited
by the placeholder assets.

### Visible family hull damage (2026-09-28)

`test_hull_damage_visual.gd` passes saved actor condition at spawn, shield-only
hits leaving finish unchanged, hull damage updating scorch, repaired condition
clearing it, finite/clamped shader inputs, and the player parked display using
absolute hull divided by maximum hull. Startup initially encountered an empty
statistics cache; rebuilding now reads current ship stats and the test runs
without script errors. The fixture is registered in CI. Family combat and fleet
family regressions pass.

Scorch is deterministic local-space material feedback on family pressure shells.
It is not projectile-location damage, mesh deformation or persistent scars;
legacy FleetShipVisual hulls, remote visitors and equipment meshes do not yet
receive this effect. Player display updates on rebuild and live state changes;
family NPC/fleet visuals update on normalized hull assignments, including repair.

Final damaged captures for all three families complete without engine errors;
the Pathfinder close-up was inspected. The procedural soot remains placeholder
art and does not establish photorealism. Clean Windows export and hidden-Gamescope
Proton integration pass at `4a4d17c`:
`build/windows-validation-dd5c267/build/proton-smoke.BRJltJ`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated material-state assertions ran natively.

### System survey completion (2026-09-28)

`test_survey_completion.gd` passes incomplete progress, partial sale followed by
final completion, one-time bonus payout, pending and sold save/load, separate
world archives, invalid system indices, empty systems and another system's
pending data not reactivating an already sold bonus. Native base survey, journal
and gameplay regressions pass. The completion fixture is registered in CI.

The journal gameplay test passes under hidden Gamescope and checks displayed
current-system progress alongside paging/filter/course controls. Its screenshot
was visually inspected: progress and reward text fit within the scrolling page.

Clean Windows export and hidden-Gamescope Proton integration pass at `e3077d9`:
`build/windows-validation-dd5c267/build/proton-smoke.Lhb1fF`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated bonus/persistence assertions ran natively; the
packaged check covers general gameplay.

### Next survey cruise (2026-09-28)

`test_survey_cruise.gd` passes nearest-surface selection, a real journal button
starting autopilot at a 600 m destination, no automatic scan/payment, skipping
pending records, aboard/offline/jump guards and disabled completed-system UI.
It is registered in CI. Existing journal jump/approach retention tests pass.
The journal UI regression passes under hidden Gamescope; its screenshot was
visually inspected. Parallel review found no coordinate-frame or gating defect.

Clean Windows export and hidden-Gamescope Proton integration pass at `1c886b1`:
`build/windows-validation-dd5c267/build/proton-smoke.LPwnIb`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated survey-cruise assertions ran natively; the
packaged smoke checks general gameplay.

### Station production choice (2026-09-28)

`test_station_production_choice.gd` passes legacy defaults, same-recipe no-op,
changed-recipe cycle reset, finite ore/fuel consumption into alloys after a full
cycle, atomic invalid requests, saved selection, transactional malformed-save
rejection and real Station Works dropdown/apply controls. The fixture is in CI.
Supply and export logistics regressions pass. Hidden-Gamescope UI execution
passes without engine errors; the resulting electronics configuration screenshot
was inspected. Parallel review found no save-schema or economic defect.

Clean Windows export and hidden-Gamescope Proton integration pass at `7826d19`:
`build/windows-validation-dd5c267/build/proton-smoke.xd8vqH`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated production/save assertions ran natively; the
packaged smoke checks general gameplay.

### Station-to-station hauling (2026-09-28)

`test_station_transfer.gd` passes finite pickup, full-storage waits, empty-source
waits, zero market transaction, zero purchase escrow, saved station references,
transactional malformed-save rejection, cross-system reposition/load/delivery,
same-system physical arrival and flight continuity, and the real assignment
button. It is registered in CI. Existing supply/export regressions and the
headless editor import pass. Parallel review found no substantive logistics or
save-validation defect; changing the source now moves a conflicting destination
selection to another station.

Hidden-Gamescope execution also passes; the transfer controls and assignment
confirmation were visually inspected at 1440×900. No script errors were logged.
Renderer shutdown reported seven leaked texture RIDs; this check does not
establish leak-free rendering.

Clean Windows export and hidden-Gamescope Proton integration pass at `372b5c7`:
`build/windows-validation-dd5c267/build/proton-smoke.Ya4itK`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated transfer/persistence assertions ran natively;
the packaged smoke checks general gameplay.

### Partial station deliveries (2026-09-28)

`test_partial_station_delivery.gd` verifies physical arrival gating, unloading
only available storage, zero-fuel partial delivery and full-storage waiting,
exact invoice conservation, saved remainder, return fuel gating, unknown
production cost and cancellation retaining cargo. It is registered in CI.
Existing partial market trade, station supply, station transfer and export
regressions pass, together with the headless editor import.

Parallel review confirmed invoice/phase conservation and the documented final
return-fuel requirement. Invalid runtime station indices report missing stations;
save validation rejects such indices before orders are installed.

Clean Windows export and hidden-Gamescope Proton integration pass at `e8817f4`:
`build/windows-validation-dd5c267/build/proton-smoke.uiLXI0`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated partial-delivery assertions ran natively; the
packaged smoke checks general gameplay.

### Local stellar gravity (2026-09-28)

`test_stellar_gravity.gd` verifies solar-AU acceleration, inverse-square falloff,
ten-solar-mass dark attraction, linear bounded core, invalid input rejection,
rotated/rebased world coordinates, addition to planetary gravity, hidden and
surface guards, and live player free fall through the existing field binding.
The fixture is registered in CI. Stellar exposure, planetary flight gravity and
stellar heat gameplay regressions pass natively. The exposure fixture now checks
the shared one-AU minimum reference for dim stars. Parallel review found no
scale/vector blocker. An initial fixture cleared planets still referenced by
the HUD; the final fixture keeps the scene intact and zeros planetary gravity
when isolating the primary.
Headless editor import and hidden-Gamescope stellar-gravity execution pass
without script/engine errors.

Clean Windows export and hidden-Gamescope Proton integration pass at `0a13586`:
`build/windows-validation-dd5c267/build/proton-smoke.pcFOwu`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated field and live free-fall assertions ran natively;
the packaged smoke checks general gameplay, not relativistic accuracy or FPS.

### Primary core contact (2026-09-28)

`test_primary_contact.gd` checks shared black-hole bounds, origin rebasing,
invalid/hidden/surface guards, real cruise target rejection and detouring,
shield bypass, NPC debris without free kill credit, player rescue and save
persistence, and coasting hull contact while aboard. The fixture is in CI.
Native and hidden-Gamescope execution pass without script/engine errors.
Stellar gravity, stellar heat, thermal overflow and survey-cruise regressions
pass, together with headless editor import.
Parallel review confirmed visual/contact radius consistency, aboard wreck
location, actor bindings and cruise coordinate-frame alignment.

Clean Windows export and hidden-Gamescope Proton integration pass at `1005713`:
`build/windows-validation-dd5c267/build/proton-smoke.IovcX2`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated primary-contact assertions ran natively and in
hidden Gamescope; packaged smoke checks general gameplay.

### Primary approach warning (2026-09-28)

`test_primary_warning.gd` checks time to contact, tangencies, misses, stationary
and receding motion, inside-core contact, invalid input, transformed origin,
hidden/surface guards, and helm/coasting/menu/on-foot HUD selection. Native and
hidden-Gamescope runs pass without script errors. The 1440×900 screenshot
`primary-warning.png` was inspected: the urgent banner and estimate label fit
above the reticle without overlapping radar or existing flight telemetry.
Primary-contact and stellar-gravity regressions plus editor import pass. The
fixture is registered in CI.
Parallel review found no actionable issue in the approach math, coordinate
frames or HUD selection/thresholds.

Clean Windows export and hidden-Gamescope Proton integration pass at `7867752`:
`build/windows-validation-dd5c267/build/proton-smoke.10bfhV`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated approach/HUD assertions ran natively and under
hidden Gamescope; the packaged smoke checks general gameplay.

### Hull finish and preview reflections (2026-09-28)

Hidden-Gamescope capture passes for Pathfinder, Merchant and Ranger, including
close coating, damaged hull, distant, engine and interior views. Pathfinder
exterior/close finish, Merchant exterior and Ranger engine captures were visually
inspected. The finish now separates lighter painted shells from dark housings;
stencils were darkened for contrast after the paint change. Coarse staining and
roughness mottling were reduced rather than adding more high-contrast noise.
A procedural softbox sky supplies reflections in shared shipyard/wardrobe preview
environments; it does not change the world sky. Native ship-blueprint containment
and hull-damage material tests pass. Hidden-Gamescope wardrobe tests and visual
inspection pass, as does editor import. Shader review found no numerical or
filtering blocker. These captures do not establish near-photorealism or FPS.

Clean Windows export and hidden-Gamescope Proton integration pass at `734a85b`:
`build/windows-validation-dd5c267/build/proton-smoke.qPbGmF`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Material comparisons used native hidden-Gamescope captures;
the packaged smoke checks general gameplay and does not establish art quality.

### Engine service hardware (2026-09-28)

Family fairings now carry connected coolant runs, mounting clamps and a marked
service cover. Exhaust throats use 32 radial segments instead of twelve; the
existing bell, glow material, thrust and power behavior remain intact. Native
ship-nozzle, blueprint containment and hull-damage checks pass. Initial hidden
Gamescope captures were inspected for Pathfinder exterior and Ranger engine
detail; the pipe ends were then connected into the fairing. This is decorative
hardware, not a simulated independent coolant system.
Final three-family hidden-Gamescope capture and editor import pass without
script/shader errors. The final Ranger engine view was visually inspected.

Parallel review confirmed the fittings remain above the pressure roof and clear
of the outlets, without changing shared exhaust emission state.
Clean Windows export and hidden-Gamescope Proton integration pass at `d10ac65`:
`build/windows-validation-dd5c267/build/proton-smoke.KRT76z`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Art comparisons used native hidden-Gamescope captures;
the packaged smoke checks general gameplay, not rendering performance.

### NPC primary navigation (2026-09-28)

Native and hidden-Gamescope navigation tests pass: cached routes, safe chords,
floating-origin rebasing, actual CharacterBody arrival around a 245 m core,
preserved crew destination, unsafe-goal braking and hidden-world bypass.
The physical fixture reached its destination with minimum center clearance
radius 328.884 m; it isolates steering without a gravity field. Primary-contact
and thermal-retreat regression checks pass. Parallel review found no blocker
in coordinate frames, rebasing or integration with existing propulsion; changed
goals and speeds can remain cached for up to one second.
Station-transfer regression, live NPC callback binding and editor import also pass.

Clean Windows export and hidden-Gamescope Proton integration pass at `300eafc`:
`build/windows-validation-dd5c267/build/proton-smoke.7mDhba`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated navigation assertions ran natively and under
hidden Gamescope; packaged smoke checks general gameplay, not multiplayer or FPS.

### Local NPC planetary navigation (2026-09-28)

Native planetary navigation checks pass: a translated world supplies global
planet centers, includes the 12 m terrain envelope, remains unchanged by routing
inflation, and a physical CharacterBody completes a crossing around the planet.
Minimum distance from its center was 353.370 m for the 262 m terrain envelope.
This isolates steering without gravity or collision geometry. Existing primary
navigation, primary-contact/rescue and physical station-transfer checks pass,
as does editor import.
Hidden-Gamescope planetary navigation also passes. Parallel review confirmed
coordinate frames, terrain bounds and obstacle immutability.

Clean Windows export and hidden-Gamescope Proton integration pass at `f8a52cd`:
`build/windows-validation-dd5c267/build/proton-smoke.37rMau`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated detour checks ran natively and under hidden
Gamescope; the packaged smoke covers general gameplay, not FPS or co-op.

### Cabin maneuver load (2026-09-28)

Native and hidden-Gamescope cabin-load checks pass: zero proper load in free
fall, nonzero hover support, retained cruise thrust, atmospheric drag, zero-step
telemetry reset, 25% walking speed at 3 g and crew bracing hysteresis. Native
crew-roaming checks verify route preservation and resumed physical movement.
Coasting navigation and the live aboard-cruise integration pass, including load
binding and reset on helm handoff. The earlier aboard fixture assumed a fixed
rebase time and spawned a wall near the hull; it now waits for the crossing and
uses a non-overlapping turning-sphere obstacle with gravity disabled only for
that isolated final check. The published baseline also failed its fixed-time
rebase assertion. Parallel review found no actionable cabin-load defect.
Hidden-Gamescope aboard-cruise also passes. The captured cabin HUD was inspected
with 3 g maneuver load and bracing status visible. Editor import passes.

Clean Windows export and hidden-Gamescope Proton integration pass at `23e0649`:
`build/windows-validation-dd5c267/build/proton-smoke.tHyVSB`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Cabin-load assertions and the HUD capture ran natively
under hidden Gamescope; packaged smoke covers general gameplay, not FPS or co-op.

### Articulated crew bracing (2026-09-28)

The procedural character rig now has elbow and knee pivots with unchanged rest
mesh positions. Ship crew blend into a widened, bent-knee stance with raised
forearms while bracing, then restore the walking pose. Native crew-roaming tests
verify blend completion, joint release, route preservation and resumed movement;
identity-palette and collision-capsule checks pass. Hidden-Gamescope side-by-side
reference capture (`build/crew-bracing.png`) was visually inspected. This remains
a simple procedural placeholder, not a finished character or handhold animation.
Parallel review confirmed joint-local coordinate conversions and pose reset.

Ranger long-cabin roaming and brace/release checks also pass. Clean Windows
export and hidden-Gamescope Proton integration pass at `e73c75d`:
`build/windows-validation-dd5c267/build/proton-smoke.SAo0Jr`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Pose checks and comparisons were native; packaged smoke
checks general gameplay and does not establish art quality or performance.

### Wreck reclamation service (2026-09-28)

Native and hidden-Gamescope reclaim tests pass: range/funds failures leave state
unchanged, one damaged unfueled vessel is created, cargo stays at the wreck,
repeat reclaim/scrap is rejected, save/load preserves the design and condition,
and existing fleet repair accepts it. The actual recovery-menu button invokes
the transaction, and its price/availability were visually inspected. Native
recovery, fleet cargo recovery and solid-wreck regression checks pass. Parallel
review found no transaction or save-format blocker.
A discovered procedural derelict also passes reclaim and save/load checks.
Editor import passes.

Clean Windows export and hidden-Gamescope Proton integration pass at `84be04d`:
`build/windows-validation-dd5c267/build/proton-smoke.M98C7U`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated reclaim tests ran natively and under hidden
Gamescope; packaged smoke covers general gameplay, not complete co-op or FPS.

### Wreck layout preservation (2026-09-28)

Native reclaim tests now customize a Merchant medical room and cockpit window,
then verify independent wreck snapshots, reclaimed fleet layout, JSON reload,
and helm exchange all retain those edits. Discovered derelict rooms and legacy
layout-free reclamation pass. Malformed modules and out-of-hull layouts reject
cleanly. Recovery and fleet-layout regression checks pass. JSON-decoded module
coordinates are canonicalized after blueprint validation for layout checks;
wreck/fleet layout versions normalize to integers as player layouts already do.
Initial round-trip failures exposed both issues and were fixed before publishing.

Clean Windows export and hidden-Gamescope Proton integration pass at `1776ed4`:
`build/windows-validation-dd5c267/build/proton-smoke.71tB5B`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated layout round-trip assertions ran natively;
packaged smoke covers general gameplay, not complete co-op or performance.

### Repair supply chains (2026-09-28)

Native repair-supply tests pass for exact marginal pricing, finite component
consumption, resupply enabling repair, atomic stock/funds/record-limit failures,
actual fleet hull scaling, remote-system inventory and save/load. The live
Exchange repair button restores hull and consumes the quoted alloys. State,
crew orders, fleet cargo recovery, wreck reclamation and hull-family refit
regressions pass. Initial checks caught legacy fleet stats without max_hull and
a UI type-inference error; both were fixed before publication. Parallel review
found no remaining transaction or system-market issue.
Hidden-Gamescope repair-menu execution passes and its quote was visually inspected.
Shutdown reported seven texture RID leaks; no script error occurred. Editor import
passes after the explicit UI Dictionary annotation.

Clean Windows export and hidden-Gamescope Proton integration pass at `53fe6eb`:
`build/windows-validation-dd5c267/build/proton-smoke.mMXYGw`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`. Dedicated repair-supply assertions ran natively and under
hidden Gamescope; packaged smoke covers general gameplay, not co-op or FPS.


### Host NPC ship replication (2026-09-28)

Protocol snapshots pass native ENet loopback checks for host-only publication,
10 Hz rate limiting, travel epochs, full-batch validation and empty snapshots.
Protocol compatibility, host controls and PvP transport regressions pass.
PvP gameplay passes both headless and hidden Gamescope. Its old cube-dimension
assertion also failed on published `53fe6eb`; the fixture now checks the actual
legacy hull collision dimensions (3.0 x 2.8 x 3.0 metres).

These checks do not establish shared NPC attacks, visitor PvE damage, shared
rewards or Steam interoperability. Those remain unfinished.

Clean Windows export and hidden-Gamescope Proton smoke pass at `83bd733`:
`build/windows-validation-dd5c267/build/proton-smoke.bgBGhX`, wrapper exit 0 and
`NEXT_INTEGRATION_OK`, without logged script errors. The packaged smoke covers
general gameplay; the dedicated replication protocol assertions ran natively.

The scene fixture passes headless and hidden Gamescope: exactly seven host IDs,
no duplicate guest patrols, inactive replicas after a real Main update, direct
and ray-hit damage suppression, an 8192-metre origin shift, distance culling and
empty-snapshot removal. Hidden Gamescope reported texture RID leaks during
shutdown after the success marker; no script error was reported.


### Visitor ship fire against host NPCs (2026-09-28)

Editor import, NPC snapshot transport and scene lifecycle regressions pass.
Existing PvP transport and gameplay checks also pass after adding the visitor
NPC firing path. The protocol version is now 3 because older visitors do not
support these host-confirmed combat outcomes.

The dedicated scene test passes natively and under hidden Gamescope, checking
physical wall/range obstruction, shields before hull, player/fleet immunity,
real ENet outcome delivery, host bounty suppression, host world elimination,
per-visitor police assault deduplication and saved visitor bounty/crime state.
The fixture calls the host shot resolver directly; the separate protocol test
covers incoming visitor request validation. Graphics shutdown reports seven
texture RID leaks after the success marker.

Clean Windows export and hidden-Gamescope Proton smoke pass at `95c0462`:
`build/windows-validation-dd5c267/build/proton-smoke.wKT8CS`, wrapper exit 0,
`NEXT_INTEGRATION_OK` and no logged script errors. This packaged smoke covers
general gameplay, not complete multiplayer or Steam interoperability.

The new protocol loopback passes visitor authorization, design-derived damage,
cooldown, travel epochs, grounded/offline/stale-pose rejection and target-only
outcome delivery. Protocol compatibility, network power, locked loadout and
NPC replication regressions also pass. No runtime changes followed the Windows
smoke commit.


### Host NPC retaliation against visitors (2026-09-28)

Protocol 4 loopback passes target-only damage delivery, fresh flying eligibility,
grounded/stale rejection, offline-ship vulnerability, travel epochs and finite
bounded damage checks. An intentional forged client RPC produces Godot's
expected authority rejection; the test verifies no damage delivery and exits 0.
Join, power, visitor-fire and consensual PvP transport regressions pass. Editor
import and the existing visitor-fire scene checks also pass.

Clean Windows export and hidden-Gamescope Proton smoke pass at `ba7334d`:
`build/windows-validation-dd5c267/build/proton-smoke.fML2ZV`, wrapper exit 0,
`NEXT_INTEGRATION_OK` and no logged script errors. This packaged smoke checks
general gameplay, not complete co-op, native Steam transport or frame-rate goals.

The retaliation scene passes headless and hidden Gamescope with two actual ENet
visitors. Checks cover pirate selection, peaceful-versus-attacking police
selection, stale/grounded exclusion, wall occlusion, weapon ray collision,
damage only to the struck visitor and shield-before-hull application. Graphics
shutdown retains the known seven texture RID leak warning after the success
marker. Dedicated scene/protocol checks ran natively; the Windows smoke is a
separate general-gameplay check.


### Own-ship interiors during multiplayer (2026-09-28)

Protocol 5 loopback passes exterior coasting address/rotation/flight-state
round-trip, NPC damage delivery, grounded revocation and travel reset. Join,
NPC damage and visitor-fire protocol regressions pass. Native parked boarding,
aboard combat and PvP gameplay regressions pass after enabling connected entry.

The new aboard scene passes headless and hidden Gamescope: connected F entry,
exterior pose independent of the passenger, origin rebasing, actual target-hull
versus external-wall occlusion, NPC/PvP shield and hull damage, parked exclusion,
helm momentum continuity and lethal rescue with a persisted wreck. This scene
reported no Godot errors or texture cleanup warnings. It does not establish
shared cabin occupancy or anti-cheat enforcement of helm ownership.

Clean Windows export and hidden-Gamescope Proton smoke pass at `a946267`:
`build/windows-validation-dd5c267/build/proton-smoke.xOu1Bu`, wrapper exit 0,
`NEXT_INTEGRATION_OK` and no logged script errors. The packaged smoke covers
general gameplay; dedicated aboard multiplayer assertions ran natively and in
hidden Gamescope. This does not establish complete Steam or shared-cabin play.


### Shared NPC weapon beams (2026-09-28)

Protocol 6 loopback passes broadcast to two visitors, authority-only publication,
identity/address/length validation, stale epochs and the rolling 64-event budget
with travel/leave resets. The initial import caught a missing explicit float
annotation in the validator; fixed before passing import and regression checks.

The beam scene passes headless and hidden Gamescope: actual host ray to ENet
event, wall and miss endpoints, correctly rebased orange beam geometry, distant
culling, unchanged health and tween cleanup. The GPU run retains the known seven
texture RID cleanup warning. Retaliation and aboard multiplayer scene regressions
pass. The visual signal intentionally carries no gameplay damage.

Clean Windows export and hidden-Gamescope Proton smoke pass at `25c015d`:
`build/windows-validation-dd5c267/build/proton-smoke.Ycdb3k`, wrapper exit 0,
`NEXT_INTEGRATION_OK` and no logged script errors. Dedicated beam assertions ran
natively and in hidden Gamescope; packaged smoke covers general gameplay.
