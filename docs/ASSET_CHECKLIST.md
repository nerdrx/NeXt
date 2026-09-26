# NeXt asset replacement checklist

Target: Star Citizen's material/ship/world credibility plus Elite Dangerous's vistas. All current visual and sound assets are code-generated placeholders. Final authored assets should replace them without changing simulation rules.

| Asset family | Current source | Replacement requirements |
| --- | --- | --- |
| [ ] Ship hull/module library | `scripts/ship_visual.gd` | Metre scale; grid attachment points; cockpit/engine/weapon/utility/habitat variants; closed pressure hulls; collisions; LODs |
| [ ] Ship interiors | `scripts/ship_interior.gd` | Deck height, door clearance, corridor/room sockets, props, crew spaces, airlocks, bridge; walkable collision |
| [ ] Cockpit and pilot hands/equipment | `scripts/pilot.gd` | View-space framing; hand/weapon animations; cockpit instruments; eventual VR reachability |
| [ ] Station exterior modules | `scripts/space_world.gd`, `scripts/main.gd` | Habitation rings, docking collars, radiators, freight modules, silhouette/scale cues |
| [ ] Station interiors | `scripts/space_world.gd` | Structural kit, floor/wall/ceiling panels, terminals, readable wayfinding, hangar doors, cargo props |
| [ ] Planet surface/orbit materials | `shaders/planet_surface.gdshader`, `planet_atmosphere.gdshader` | Coherent scale-dependent terrain, clouds, atmosphere, oceans, biome variants, matching ground appearance |
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
