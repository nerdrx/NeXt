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
- [ ] Damaged wreck visuals and recovery beacon (`scripts/main.gd`): replace current tilted hull presentation with broken hull sections and a restrained beacon.

## Owned outpost docking complex

- [ ] Replace `scripts/owned_station.gd` hull, industrial bays, radiator panels and communications mast with authored modular station assets.
- [ ] Replace dock markings, guide lights, canopy, service terminal and signs; retain the 76 x 80 metre collision-supported apron and unobstructed positive-Z approach.
- [ ] Preserve `dock_position`, `stand_position` and `launch_position` when swapping assets; rerun the station gameplay test to check standing collision, docking and departure.
- [ ] Add inhabited interiors beyond the current open docking deck; the present outpost is not a complete city or station interior.

## Local crew patrols

- [ ] Replace the cyan fleet patrol exterior and floating ship/captain labels with authored patrol ship variants and diegetic identification. Preserve the ShipActor damage/fire signals and fleet ID metadata when changing the visual scene.
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
- [ ] Replace/refine `shaders/terrain_rock.gdshader` mineral layers and grain with authored biome material sets. Preserve planet-local sampling and distance filtering so streamed patches and origin shifts do not move the surface pattern.

- [ ] Keep replacement ship assets aligned to the 2.8 m module grid and centred module bounds. Player flight now uses one box collider per occupied module; decorative panels/engines outside those cells need authored collision extensions when their final geometry is available. Walking retains a separate capsule.

- [ ] Replace ship architect grid initials with authored module glyphs/thumbnails where they improve selection. Preserve readable coordinate, deck, count and occupied-cell states in `scripts/ui/ship_designer.gd`.

- [ ] Replace large owned-station berth plates, edge lamps, service-lane marking and boarding signage with authored industrial assets; preserve the 120 m deck, clear hull envelope and continuous pedestrian connector.

- [ ] Replace public large-berth deck, connector, markings, boarding kiosk and directional signs with authored station assets; preserve the maximum hull clearance and continuous walkway around approach spars.

- [ ] Author station service-room kits and numbered wayfinding for market, company, shipyard, contracts, faction and construction rooms; retain shared doorway dimensions, corridor connectivity and service interaction points.
