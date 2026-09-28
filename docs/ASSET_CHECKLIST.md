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

- [ ] Ground crew suit meshes, flush helmet faceplates and role patches (`scripts/ground_actor.gd`, `scripts/crew_helmet.gd`): replace with rigged human models while preserving collision dimensions and attack origins.
- [ ] Lounge, medical and workshop fittings (`scripts/ship_interior.gd`): authored room kits within 2.8 m cells; keep doorway clearance. Medical bays now offer treatment from within the room; preserve the readable treatment terminal, central standing area and 1.35 m room interaction bounds.
- [ ] Preserve both doorway axes when replacing lounge furniture. Current corner seating and side table keep the central crossing clear; validate actual player walking and crew routes through the room, including Ranger's cockpit-to-aft route.
- [ ] Standard, armored and glazed face panels (`scripts/ship_visual.gd`): replace materials/meshes without changing exposed-face selection keys.
- [ ] Radiator module surface assemblies (`scripts/ship_visual.gd`): replace dark ribbed panels and coolant manifolds with authored heat-rejection hardware; preserve exposed-face selection, 2.8 m module bounds and panel compatibility.
- [ ] Damaged wreck visuals and recovery beacon (`scripts/main.gd`): replace current tilted hull presentation with broken hull sections and a restrained beacon.

## Owned outpost docking complex

- [ ] Replace `scripts/owned_station.gd` hull, industrial bays, radiator panels and communications mast with authored modular station assets.
- [ ] Replace dock markings, guide lights, canopy, service terminal and signs; retain the 76 x 80 metre collision-supported apron and unobstructed positive-Z approach.
- [ ] Preserve `dock_position`, `stand_position` and `launch_position` when swapping assets; rerun the station gameplay test to check standing collision, docking and departure.
- [ ] Expand the docking aprons and service concourse into inhabited station districts; the orbital rings are exterior structure with collision, not walkable habitat interiors.
- [ ] Replace the paired orbital hoops, radial supports, hub, rear spine and sealed freight-door placeholders with authored industrial station assemblies. Keep the ring openings physically open, collision aligned with the visible structure, and small/large docking approaches unobstructed. Current rings do not rotate or simulate artificial gravity.

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

- [ ] Replace `scripts/ship_crew.gd` inherited procedural humanoids with authored crew suits, faces, idle animations, walking cycles and turns while yielding in corridors. Preserve the 0.42 m radius / 1.75 m height collision capsule, local deck gravity and persistent crew identity. The current shared procedural fabric normal map, segmented helmet and rigid limb pivots are placeholders; replace these with authored textures and a skinned rig.
- [ ] Author diegetic name/role identification and duty indicators; the current compact billboard label sits 1.95 m above the feet, with roughly 4 cm glyph height.
- [ ] Add bridge, engineering and habitation workstations with authored standing/seated sockets. Current placement queries clear floor space, distributes bodies across rooms with role preferences, faces them inward and keeps module centers available for passage.

## Planet weather

- [ ] Replace or art-direct `shaders/planet_clouds.gdshader`: seeded drifting weather patterns on a separate transparent shell, with lit day and dark night sides. Keep clouds non-colliding and above the maximum terrain height.
- [ ] Replace the atmosphere limb approximation in `shaders/planet_atmosphere.gdshader` with calibrated scattering.
- [ ] Add volumetric depth and weather simulation. Current shells use matching analytic shadows on orbital and streamed ground materials; extend cloud shading to buildings and vessels. Streamed rocks now receive the same analytic weather and planetary eclipse shadows as terrain. Planet scale and streaming still need expansion.

- [ ] Local hired freighter variant (`scripts/ship_actor.gd`, `scripts/ship_visual.gd`): replace the cargo-wing procedural ship with authored civilian freight hulls, cargo-bay markings and docking lights; preserve local trade travel and collision behavior.

- [ ] Fleet freight cache (`scripts/main.gd`, `rebuild_wrecks`): replace the banded procedural container and cyan beacon with authored damaged cargo pods; keep its recovery address and visibility after rebasing. No hull salvage value is attached to these containers.


## Habitable family shells

- [ ] Replace the Pathfinder, Merchant and Ranger pressure blockouts with designed outer armor, propulsion housings, service access and restrained materials. Preserve the shared room envelope and boarding/collision contract; do not shrink usable interior volume to fit a cosmetic silhouette.
- [ ] Refine Ranger's long bow and broad aft shoulders into an exploration vessel. Preserve its connected single deck, lounge, medical room, workshop and radiator bays. Current silver/copper livery and offset-ring armor are blockouts; preserve outward offsets rather than origin scaling, which can cut into concave cabin corners. Forward glazing now projects onto each family hull surface.
- [ ] Replace the procedural family shell's regular panel grid with authored seam placement and material masks. Current object-space seams, shallow bump relief and panel paint variation are placeholders; sidewall projection does not follow every sloped armor edge. Preserve distance filtering and inspect moving ships for aliasing.
- [ ] Replace roof module indicators and rectangular inset panels with functional equipment details. The current connected shell and exposed fittings are construction references, not final art.
- [ ] Inspect replacement families in exterior, rear, cutaway and aboard views using `tests/capture_hull_families.gd` plus gameplay captures.

- [ ] Inspect commissioned Pathfinder/Merchant traffic at gameplay distance and under thrust; they now reuse the same family pressure geometry as the shipyard. Add final family identification markings while retaining persistent registry identity.

- [ ] Replace the new mechanical roof placeholders (sealed cargo leaves, heat-exchanger louvers, ventilation and shield cover) with authored serviceable assemblies. Preserve exposed exhaust openings and flat armor normals; family silhouettes still need a complete design pass.
- [ ] Replace the tapered dorsal engine fairings with authored propulsion assemblies and service markings. Fairings sit above the pressure roof; twin nozzles attach at the aft end of each occupied engine column. Retain cabin clearance, thrust visuals and the flight collision envelope.

- [ ] Refine the sloped family hull profiles into distinctive designed ships, preserving room containment and the common collision envelope. Current collision uses conservative per-cell boxes; final profile changes need renewed flight, coast, visitor, landing and berth clearance checks.


## Docked fleet inspection

- [ ] Author a visible fleet service berth and boarding route; the current menu opens a separate local inspection interior using the real family rooms.
- [ ] Replace bridge seats/consoles while keeping the center passage wide enough for the walking capsule. Add legible room signs viewed from both travel directions.
- [ ] Replace procedural doorway destination lettering with authored ship signage. Each side names the adjoining room from the saved layout, updates after refits and remains attached to the moving cabin; retain source-facing text and avoid mirrored back faces. Current signs identify adjacent rooms, not routes through the whole ship.

- [ ] Replace fleet room-refit fixtures and hull-panel placeholders with authored variants. Preserve saved room/panel choices, usable walkways and exposed-face radiator behavior.

- [ ] Replace fleet equipment variants (weapons, cargo, habitats, shields, radiators and extra reactors) with coherent authored fittings. Preserve module coordinates, clear interior passages and loadout-driven exterior/thermal behavior.

- [ ] Inspect custom fleet copies with asymmetric and multi-deck designs. They reuse modular player visuals and fittings; authored replacements must preserve the saved modules, interior walkways and generated collision.

- [ ] Replace ship cabin procedural panel finish with authored material masks and purposeful seam placement. `ShipInterior._box` now shares `shaders/fleet_surface.gdshader`: metre-scaled joints, shallow relief, filtered grain and low-metallic painted surfaces. Keep cabin-local alignment during turns/rebasing; glass and emissive fixtures retain separate materials. The regular grid remains placeholder art.
- [ ] Replace multi-deck floor transfer markings with authored lift landings and a physical shaft/cabin system. Crew currently walk to the existing abstract deck-transfer landing, wait and transfer to a clear destination. Preserve approach/onward routing, occupant clearance, pause behavior and moving-cabin coordinates.

- [ ] Replace procedural family fastener rings, seal dirt and fairing grilles with authored construction detail. Keep distance filtering and cabin clearance. Shipyard previews now use a neutral reflection sky shared with family review captures; approve final materials under actual hangar, sunlight and planetary conditions as well.

- [ ] Review replacement hull/cabin materials at close, mid, far and grazing views using `tests/capture_surface_distance.gd`. Preserve screen-footprint filtering: small fasteners disappear before wider panel joints; seal dirt and paint noise must not remain as subpixel speckles. Add moving-camera review before final acceptance.

- [ ] Replace the family shader shoulder/flank paint bands with authored livery masks and registration graphics. Current Pathfinder grey-green and Merchant ochre paint stays hull-local and uses filtered edges; this is only a color-blocking pass, not final hull art.

- [ ] Replace procedural flared engine bells, recessed luminous throats and radial ribs with authored propulsion assemblies and exhaust effects. Preserve external aft outlets for covered engine cells; this visual routing does not simulate internal exhaust ducts. Preserve `ShipVisual.set_systems_online` and `set_thrust`: shutdown darkens exhaust without changing independent navigation-light materials, including visitor ships and rebuilt hulls.

- [ ] Replace conservative wreck module-box and freight-cache collision with authored damaged-hull collision. Retain obstacle layer 1, visual transform alignment, unpowered exhaust and hull-to-cache transition when salvage precedes cargo recovery.

- [ ] Give NPC combat alloy debris a distinct damaged-material cache visual. It currently reuses the freight-cache placeholder and beacon; preserve saved recovery records, collision, range and one-time collection.

- [ ] Author abandoned Pathfinder/Merchant damage variants for procedural salvage surveys. Preserve the shared module collision envelope and deterministic discovery record; current derelicts use tilted, unpowered intact placeholder hulls.

- [ ] Replace helmeted crew placeholder suits and armor with authored human characters. Preserve identity-derived suit/armor colors across saved crew reloads, role patches, gait pivots and the 0.42 m radius / 1.75 m height movement capsule. Review variations with `tests/capture_crew_palettes.gd`; player character creation and face/body customization remain unfinished.

- [ ] Replace the commander suit-locker preview rig and first-person sleeve/cuff with authored matching character assets. Preserve selectable fabric/armor finishes, saved palette indices, role-independent player styling and preview rotation. The locker currently offers six fabric and four armor colors; it does not provide face, body, hair or equipment customization.

- [ ] Replace stellar placeholder surfaces/corona with temperature-appropriate authored or procedural materials. Keep the shared primary center and exposure readout aligned; current heat uses an explicitly compressed inverse-square field, hard planet eclipses and a hull bounding-box absorption proxy. The primary now uses an artistic temperature color ramp, filtered granulation, spots, limb darkening and a depth-tested corona. Improve prominence structure, spectral color/exposure response and directional illumination; the current global light remains a parallel-light approximation.

- [ ] Refine orbital planet light response while preserving primary-relative day/night alignment across surface, cloud and atmosphere layers. Current globes use a per-fragment primary vector and an approximate rough specular lobe; retain the day/crescent/night capture checks. Streamed ground now shares the globe direct-light and eclipse calculation. Buildings and vessels still need matching scene lighting; finite-star penumbrae remain unfinished. Orbital surface, cloud and atmosphere layers now share planet-sphere point-source eclipse shadows; preserve the eclipse capture checks when replacing these materials.

- [ ] Refine `shaders/planet_rock.gdshader` and boulder silhouettes. The placeholder now adds mineral variation, filtered grain and small normal relief, plus primary-relative sunlight, cloud shadows and planetary eclipses. Preserve per-instance custom coordinates and the shared geology material so origin shifts do not move shadows. Near-object cast shadows and physical sky illumination remain open.

- [ ] Add restrained thermal-damage effects and warning audio. Capped-loop overflow now damages hull and uses the existing flash/explosion/recovery presentation; keep the temperature warning readable and avoid obscuring piloting controls.

- [ ] Add survey scanner presentation and recorded-data icons. Current Navigation controls and text use the shared interface theme; retain clear range/speed requirements, pending payout and surveyed status when replacing the presentation.

- [ ] Refine survey journal presentation: current text rows show planet/system names, atmospheric traits, sold status and course actions, with an unsold filter and twenty records per page. Preserve keyboard controls and bounded list construction when adding thumbnails or discovery imagery. Navigation now carries the selected survey planet through jumps; keep its name, arrival guidance, explicit approach action and clear-course control readable.

- [ ] Refine host session controls and peer-list presentation. Preserve clear admission state, host-only removal actions, departure refresh and the distinction between removing a visitor and preventing rejoining.

- [ ] Replace shared procedural equipment finishes with authored material maps. Ship covers now share the filtered hull finish shader; canopy trim and radiator fins use exposed-metal response, while painted covers remain dielectric. Preserve exhaust emission and transparent glazing. This material pass does not resolve blocky hull silhouettes or establish reference-quality art.

- [ ] Add atmospheric flight audio and restrained airflow cues. The flight HUD reports AIR DRAG in g and AIR HEAT in kW separately from thrust. Use the actual energy-based heating signal for restrained thermal cues; plasma and material-specific re-entry effects are not simulated. Preserve readability.

- [ ] Replace procedural flank service strips and staggered coating seams with authored hull access panels, maintenance markings and material maps. Preserve exposed-face placement, configured windows/armor and radiator clearance; these details do not change pressure-room geometry.

- [ ] Replace parked-ship four-point gear (pads, pistons, sleeves and collars) with authored retractable assemblies. Preserve the lowest occupied deck support plane and surface-normal orientation. Current gear is visual only: no suspension, terrain-adaptive leg extension, retraction animation or physical boarding ramp.

- [ ] Replace the family hull's repeating procedural panel finish with authored,
  construction-aware paint, roughness and normal maps. Preserve metre-scale seams
  and distance filtering; review close, distant and moving gameplay views.

- [ ] Replace parked family crew-access hatch, ramp and handrails with authored
  deployable access equipment; preserve walking collision and add opening/closing
  animation when exterior and interior doors share a continuous passage.

- [ ] Replace interior telescoping bulkhead panels with authored door leaves,
  recessed handles and actuator audio. Preserve the open capsule clearance,
  proximity hold and moving-hull collision behavior.

- [ ] Hull coating wear (`shaders/fleet_surface.gdshader`): replace procedural
  edge chips, exposed primer and maintenance staining with authored material
  masks. Preserve separate paint/bare-metal roughness and clearcoat response,
  metre-scale wear and distance filtering. Current result remains placeholder
  quality; material noise does not replace hull design, bevels or authored detail.

- [ ] Exterior hull stencils (`scripts/ship_visual.gd`, `_add_stencil`): replace
  procedural shaded text with authored typography/decal atlases. Preserve family
  designation, role, cargo-bay index, lifting cues and reactor heat warnings;
  markings belong to panel surfaces and must not billboard or glow. These are
  family/bay identifiers, not unique vessel registration numbers.

- [ ] Hull-condition scorch (`shaders/fleet_surface.gdshader`,
  `ShipVisual.set_hull_integrity`): replace procedural soot with authored damage
  masks/VFX. Current family pressure shells darken and lose clearcoat as hull
  condition falls; repairs clear the effect. This is aggregate hull condition,
  not hit-position decals, deformation, equipment damage or persistent scars.

- [ ] Preview reflection lighting (`shaders/ship_studio_sky.gdshader`): replace
  procedural softbox cards with authored studio/HDR lighting as desired. Shared
  ship-designer and wardrobe previews use this isolated environment; the world
  sky remains separate. Family hulls now use lighter neutral paint, darker
  livery/stencils, reduced cloudy staining and filtered coating bump. These are
  replaceable material placeholders, not reference-quality hull design or art.

- [ ] Engine service hardware (`ShipVisual._add_family_engine_housing`): replace
  procedural coolant runs, elbows, clamps and service cover with authored
  machinery. These sit above the pressure roof and remain visual-only; they do
  not implement separate coolant circuits or component damage. Preserve nozzle
  throat power/thrust behavior when replacing the higher-resolution throat mesh.

### Cabin maneuver response

- [ ] Replace stationary crew bracing placeholder with handhold/stance animations
  matched to cabin load, retaining the route-pause behavior and 1.5/1.0 g hysteresis.
