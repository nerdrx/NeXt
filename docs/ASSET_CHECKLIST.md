# NeXt asset replacement checklist

Target: Star Citizen's material/ship/world credibility plus Elite Dangerous's vistas. All current visual and sound assets are code-generated placeholders. Final authored assets should replace them without changing simulation rules.

| Asset family | Current source | Replacement requirements |
| --- | --- | --- |
| [ ] Ship hull/module library | `scripts/ship_visual.gd` | Metre scale; grid attachment points; cockpit/engine/weapon/utility/habitat variants; closed pressure hulls; collisions; LODs |
| [ ] Ship interiors | `scripts/ship_interior.gd` | Deck height, door clearance, corridor/room sockets, props, crew spaces, airlocks, bridge; walkable collision |
| [ ] Cockpit and pilot hands/equipment | `scripts/pilot.gd` | View-space framing; hand/weapon animations; cockpit instruments; eventual VR reachability |
| [ ] Station exterior modules | `scripts/space_world.gd`, `scripts/main.gd` | Habitation rings, docking collars, radiators, freight modules, silhouette/scale cues |
| [ ] Station interiors | `scripts/space_world.gd` | Structural kit, floor/wall/ceiling panels, terminals, readable wayfinding, hangar doors, cargo props |
| [ ] Planet surface/orbit materials | `shaders/planet_surface.gdshader`, `planet_atmosphere.gdshader`, `scripts/planet_terrain.gd`, `shaders/terrain_rock.gdshader` | Coherent scale-dependent terrain, clouds, atmosphere, oceans, biome variants, matching ground appearance |
| [ ] Stars, nebulae, compact objects | `shaders/deep_space_sky.gdshader`, `star_surface.gdshader`, `SpaceWorld` | Distinct phenomena with controlled exposure and convincing scale; black-hole accretion/lensing effects |
| [ ] Colony/city kit | `scripts/space_world.gd` | Streets, service entrances, urban districts, architecture variants, interiors, vehicles, signs, LODs |
| [ ] Humans and clothing | `scripts/ground_actor.gd` | Human-only setting; named NPC variation, rigs, gait, interaction/combat animations, factions/jobs |
| [ ] Weapon/impact/jump effects | `scripts/main.gd`, `scripts/pilot.gd` | VFX tied to actual gameplay events; debris, shielding, propulsion, projectiles, recovery wrecks |
| [ ] Crew-operated weapon turrets | `scripts/ship_visual.gd`, `scripts/ship_defense.gd` | Authored gimballed mounts and muzzle effects; current dorsal fire origin is module center + local Y 1.6 m; retain occupied-hull and world-cover checks |
| [ ] Interface visual assets | `scripts/ui/` | Restrained iconography, fonts/license records, navigation/map symbols, accessibility and input glyphs |
| [ ] Audio | `scripts/soundscape.gd` | Engines, environmental ambience, weapons, impacts, ship/station machinery, interface cues and music |

## Asset handoff

- [ ] Keep editable source files and provenance/license records.
- [ ] Agree metres, axes, origins and named material/attachment slots before large batches.
- [ ] Supply PBR materials with appropriate roughness, metallic and normal maps.
- [ ] Provide collision separately from visual detail and validate doors/interactions with the player capsule.
- [ ] Provide LODs/instancing plans and realistic texture budgets for the 1440p/60 target.
- [ ] Preserve replaceable procedural fallbacks until authored content is validated.
- [ ] Validate lighting/exposure across space, interiors and surfaces, not only an asset-preview scene.
- [ ] No AI bitmap art, models or recorded voices are required by the current project.

## New replaceable procedural content

- [ ] Ground crew suit meshes and role patches (`scripts/ground_actor.gd`): replace with rigged human models while preserving collision dimensions and attack origins.
- [ ] Lounge, medical and workshop fittings (`scripts/ship_interior.gd`): authored room kits within 2.8 m cells; keep doorway clearance.
- [ ] Standard, armored and glazed face panels (`scripts/ship_visual.gd`): replace materials/meshes without changing exposed-face selection keys.
- [ ] Radiator module surface assemblies (`scripts/ship_visual.gd`): replace dark ribbed panels and coolant manifolds with authored heat-rejection hardware; preserve exposed-face selection, 2.8 m module bounds and panel compatibility.
- [ ] Damaged wreck visuals and recovery beacon (`scripts/main.gd`): replace current tilted hull presentation with broken hull sections and a restrained beacon.

## Owned outpost docking complex

- [ ] Replace `scripts/owned_station.gd` hull, industrial bays, radiator panels and communications mast with authored modular station assets.
- [ ] Replace dock markings, guide lights, canopy, service terminal and signs; retain the 76 x 80 metre collision-supported apron and unobstructed positive-Z approach.
- [ ] Preserve `dock_position`, `stand_position` and `launch_position` when swapping assets; rerun the station gameplay test to check standing collision, docking and departure.
- [ ] Add inhabited interiors beyond the current open docking deck; the present outpost is not a complete city or station interior.

## Local crew patrols

- [ ] Replace the procedural fleet patrol exterior and floating ship/captain labels with authored patrol ship variants and diegetic identification. Preserve the ShipActor damage/fire signals and fleet ID metadata when changing the visual scene.
- [ ] Replace/refine the native procedural trade freighter and patrol hulls (`scripts/fleet_ship_visual.gd`): use metre-scale full vessels with the forward axis at -Z; preserve `_visual.set_thrust`, fitted convex collision and separate cargo/weapon silhouettes. Replace the procedural service stencils, optical housings and finish shader with authored equivalents.
- [ ] Author fleet disabled-ship and recovery assets when physical fleet salvage replaces the present service-repair flow.

- [ ] Replace `scripts/surface_colony.gd` industrial port buildings, landing lights, pylons, service kiosk and signs with authored modular city assets. Preserve landing_position, stand_position, service_position, deck collision and terrain ramp interfaces.

- [ ] Replace surface-port room walls, counters, chairs and service signs with authored interior kits; retain clear 3.2 m doorways and physical service access. Upper floors remain sealed.

- [ ] Replace port clerk/security procedural humanoids with authored characters, clothing variants and idle/patrol animations. Keep stable actor IDs, service metadata and collision/weapon interfaces.

- [ ] Keep authored port collision geometry represented in navigation bake input; verify doorway width, counter clearance and continuous street floors with the capsule-sweep tests.

- [ ] Replace confirmed PvP tracer/impact primitives and gold hit marker (`main.gd::_receive_pvp_hit`, `FlightHUD`) with authored VFX/UI. Preserve host-confirmed event timing, sector coordinates and separation from damage.

- [ ] Replace graphite cockpit shell in `Pilot._make_cockpit` with authored geometry. Keep `LeftDisplay` and `RightDisplay` anchors (local +Z faces pilot) or remap `CockpitInstruments`; current displays show live vitals, speed and cruise state. Avoid emissive full-panel surfaces obscuring dark vistas.

- [ ] Replace/refine orbital terrain, cloud and atmosphere appearance (`planet_surface.gdshader`, `planet_atmosphere.gdshader`). Current deterministic mineral palette separates dry worlds from ocean-bearing atmospheric worlds. Preserve local-coordinate sampling for origin shifts. The thin sunlit limb is an approximation; physical scattering and volumetric clouds remain open. Orbital land/ocean classification and ground elevation now use the same seeded height map; preserve that shared sampling when replacing materials.

- [ ] Replace owned-station bridge, concourse, room shells, glazing, fixtures and furniture (`OwnedStation`). Retain door clearances, floor support, collision-backed windows, `interior_services` and save-position bounds. Current rooms are procedural placeholders; huge multi-deck populated stations remain open.

- [ ] Replace the four procedural boulder meshes in `scripts/planet_geology.gd` with authored rock variants and matching convex hulls. Preserve stable placement IDs, radial transforms, clearance bounds, north-port reserve and ocean filtering. Small pebbles have no collision; larger boulders do.
- [ ] Replace/refine `shaders/terrain_rock.gdshader` mineral layers and grain with authored biome material sets. Preserve per-frequency bounded noise origins, planet-local sampling and distance filtering so large-radius coordinates and origin shifts do not move or quantize the surface pattern.

- [ ] Keep replacement ship assets aligned to the 2.8 m module grid and centred module bounds. Player flight now uses one box collider per occupied module; decorative panels/engines outside those cells need authored collision extensions when their final geometry is available. Walking retains a separate capsule.

- [ ] Replace ship architect grid initials with authored module glyphs/thumbnails where they improve selection. Preserve readable coordinate, deck, count and occupied-cell states in `scripts/ui/ship_designer.gd`.

- [ ] Replace large owned-station berth plates, edge lamps, service-lane marking and boarding signage with authored industrial assets; preserve the 120 m deck, clear hull envelope and continuous pedestrian connector.

- [ ] Replace public large-berth deck, connector, markings, boarding kiosk and directional signs with authored station assets; preserve the maximum hull clearance and continuous walkway around approach spars.

- [ ] Author station service-room kits and numbered wayfinding for market, company, shipyard, contracts, faction and construction rooms; retain shared doorway dimensions, corridor connectivity and service interaction points.

- [ ] Replace ship interior kits within the exterior-compatible 2.8 m cell spacing and 2.45 m room height; preserve capsule clearance, deck-up orientation, window apertures and floor anchors 1.23 m below each module center.

- [ ] Author horizontal ship-window frames and glass shading around the 1.85 m clear aperture, preserving floor/ceiling collision and removing opaque backing from the visible opening.

## Named crew aboard

- [ ] Replace `scripts/ship_crew.gd` inherited procedural humanoids with authored crew suits, faces and idle animations. Preserve the 0.42 m radius / 1.75 m height collision capsule, local deck gravity and persistent crew identity.
- [ ] Author diegetic name/role identification and duty indicators; the current billboard label sits 2.1 m above the feet.
- [ ] Add bridge, engineering and habitation workstations with authored standing/seated sockets. Current placement queries clear floor space, distributes bodies across rooms with role preferences, faces them inward and keeps module centers available for passage.

## Planet weather

- [ ] Replace or art-direct `shaders/planet_clouds.gdshader`: seeded drifting weather patterns on a separate transparent shell, with lit day and dark night sides. Keep clouds non-colliding and above the maximum terrain height.
- [ ] Replace the atmosphere limb approximation in `shaders/planet_atmosphere.gdshader` with calibrated scattering.
- [ ] Add volumetric depth and weather simulation. Current shells use matching analytic shadows on orbital and streamed ground materials; extend cloud shading to buildings, vessels and rocks. Planet scale and streaming still need expansion.

- [ ] Local hired freighter variant (`scripts/ship_actor.gd`, `scripts/ship_visual.gd`): replace the cargo-wing procedural ship with authored civilian freight hulls, cargo-bay markings and docking lights; preserve local trade travel and collision behavior.

- [ ] Fleet freight cache (`scripts/main.gd`, `rebuild_wrecks`): replace the banded procedural container and cyan beacon with authored damaged cargo pods; keep its recovery address and visibility after rebasing. No hull salvage value is attached to these containers.


## Habitable family shells

- [ ] Replace the Pathfinder and Merchant pressure blockouts with designed outer armor, propulsion housings, service access and restrained materials. Preserve the shared room envelope and boarding/collision contract; do not shrink usable interior volume to fit a cosmetic silhouette.
- [ ] Replace the procedural family shell's regular panel grid with authored seam placement and material masks. Current object-space seams, shallow bump relief and panel paint variation are placeholders; sidewall projection does not follow every sloped armor edge. Preserve distance filtering and inspect moving ships for aliasing.
- [ ] Replace roof module indicators and rectangular inset panels with functional equipment details. The current connected shell and exposed fittings are construction references, not final art.
- [ ] Inspect replacement families in exterior, rear, cutaway and aboard views using `tests/capture_hull_families.gd` plus gameplay captures.

- [ ] Inspect commissioned Pathfinder/Merchant traffic at gameplay distance and under thrust; they now reuse the same family pressure geometry as the shipyard. Add final family identification markings while retaining persistent registry identity.

- [ ] Replace the new mechanical roof placeholders (sealed cargo leaves, heat-exchanger louvers, ventilation and shield cover) with authored serviceable assemblies. Preserve exposed exhaust openings and flat armor normals; family silhouettes still need a complete design pass.
- [ ] Replace the tapered dorsal engine fairings with authored propulsion assemblies and service markings. Each fairing covers a twin-nozzle bay above the pressure roof; retain cabin clearance, thrust visuals and the flight collision envelope.

- [ ] Refine the sloped family hull profiles into distinctive designed ships, preserving room containment and the common collision envelope. Current collision uses conservative per-cell boxes; final profile changes need renewed flight, coast, visitor, landing and berth clearance checks.


## Docked fleet inspection

- [ ] Author a visible fleet service berth and boarding route; the current menu opens a separate local inspection interior using the real family rooms.
- [ ] Replace bridge seats/consoles while keeping the center passage wide enough for the walking capsule. Add legible room signs viewed from both travel directions.

- [ ] Replace fleet room-refit fixtures and hull-panel placeholders with authored variants. Preserve saved room/panel choices, usable walkways and exposed-face radiator behavior.

- [ ] Replace fleet equipment variants (weapons, cargo, habitats, shields, radiators and extra reactors) with coherent authored fittings. Preserve module coordinates, clear interior passages and loadout-driven exterior/thermal behavior.

- [ ] Inspect custom fleet copies with asymmetric and multi-deck designs. They reuse modular player visuals and fittings; authored replacements must preserve the saved modules, interior walkways and generated collision.
