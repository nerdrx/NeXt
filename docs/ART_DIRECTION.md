# NeXt visual direction

The agreed reference is **Star Citizen's believable ships, materials and inhabited spaces**, combined with **Elite Dangerous's immense cosmic vistas**. The intended destination is near-photorealism. No screenshot of the current procedural assets is evidence that this target has been met.

## Scene requirements

- Correct human and equipment scale; a 1.8 m person must fit through doors and around consoles.
- Enclosed pressure vessels, plausible structural load paths, accessible maintenance panels, propulsion clearances and recognizable ship silhouettes.
- Grounded industrial design, with clean, worn and luxury variants appropriate to a region's wealth and function.
- Physically based paint, bare metal, rubber, glass, composites and fabric. Roughness and edge treatment carry more detail than saturated color.
- Restrained signal colors: cyan/blue for navigation and instrumentation, warm white/amber for work lights and cautions. Most of a scene should remain materially believable without emissive light.
- Distinct lighting zones, readable contact shadows, scale cues, controlled exposure and specular highlights. Avoid uniform ambient floodlight and colored wash on every surface.
- Procedural planets need coherent large landforms, smaller terrain variation, separate clouds, ocean response, atmospheric limb and a convincing day/night terminator.
- Vistas should provide a sense of distance and celestial scale. Avoid decorative spheres arranged like a showroom.
- Interfaces should resemble equipment used by people, with clear hierarchy and readable text. UI must not overwhelm the view.

## Placeholder acceptance

A placeholder can be lower detail than final art, but must establish the correct size, silhouette, material family, movement and interaction points. It must be replaceable without rewriting simulation rules. Do not label low-detail geometry "AAA" or use polished concept art as evidence of a functioning scene.

Current code-generated assets belong to `ShipVisual`, `ShipInterior`, `SpaceWorld`, `GroundActor`, `Pilot` and the shaders directory. Replacements need explicit units, pivots, collision shapes, LODs and material-slot conventions. The asset checklist tracks final authored replacements.

## Performance target

High-end PC, 1440p at 60 FPS. Budget for gameplay, cockpit/interiors, planets, city scenes and up to eight network players. Windows is the shipping target and Proton is the Linux play path. Measure representative scenes after shader warmup; a single screenshot or headless script is not a performance result.


## User-supplied ship references

The three supplied ship images establish a much higher model target than the current procedural blockouts. They guide original designs rather than exact reproductions:

- Industrial combat craft: broad angular armor surfaces, an inset mechanical spine, articulated panel boundaries and distinct engine housings. Large surfaces establish the silhouette; smaller mechanisms explain how it works.
- Civilian craft: a streamlined cockpit and continuous body, framed glazing, blended propulsion structures and a limited painted livery. A smooth silhouette still needs convincing hard-surface transitions.
- Utility craft: visible structural connections, separated nacelles, working equipment and layered mechanical depth. Exposed machinery must connect to the hull rather than float as decoration.

Reject rounded slab hulls with attached boxes, flat glowing discs presented as engine bells, arbitrary panel grids, or detail consisting mostly of emissive strips. Inspect a close three-quarter front view and rear view, then check the ship in gameplay lighting. Both the unlit silhouette and material separation must remain readable. Presentation renders must not substitute for integrated game geometry.

These images specify ship quality and form language. Station architecture and character appearance still await their own user references. The existing ship, station and character blockouts have not been accepted as meeting the target.

## Material review status

The fleet material draft separates dielectric paint, exposed metal and non-emissive livery, with subtle filtered roughness variation. Hard armor faces use flat normals; curved engine segments retain smoothing within each profile section. Navigation lamps and exhaust are the intentional emissive surfaces. The standalone capture uses a neutral studio reflection sky, so its glass response is not proof of the in-game space or hangar appearance.

The current fleet remains below the reference quality. The main gaps are integrated canopy/interior detail, believable panel construction, authored surface wear and material variation at appropriate scales. Small noise and post-processing cannot substitute for these. Verify front/rear studio captures and gameplay lighting before accepting the assets.

## Hull families and internal space

The user selected a hybrid foundation: a small library of designed hull families with configurable rooms and equipment. The current compact patrol/fighter is accepted as a starter placeholder with a seated cockpit, not a walkable cabin. It must not be scaled up and presented as a habitable vessel without an interior design.

Larger ships derive occupied cells, internal rooms and collision from a common metre-scale blueprint. The first Pathfinder and Merchant definitions are layout templates; they can be inspected and refitted from the shipyard, while their final exterior family styling remains incomplete. Existing custom modular construction remains supported. A 2.8 m cell pitch is distinct from the overlapping pressure envelope and collision bounds; the shell must contain real interior walls and headroom. Rooms remain limited to compatible module bays.

Do not create a separate cosmetic fleet catalogue that claims boarding support. Fleet ownership, purchased family identity and boarding must eventually use the same blueprint as the player vessel. Current FleetShipVisual silhouettes remain exterior-only placeholders.


Fleet commissioning can now choose the Pathfinder or Merchant blueprint. These purchased ships keep their selected family when orders change and render through `ShipVisual`; legacy utility vessels retain their existing exterior placeholders. This establishes shared family geometry for owned traffic, not fleet boarding or editable fleet rooms. Family definitions must retain stable capacity until a deliberate save migration exists.


The modular exterior roof now uses paired sealed cargo hatches, louvers, ventilation covers and a capped shield housing instead of glowing module symbols. Painted fittings use low metallic response, canopy trim is non-emissive, and armor faces use flat normals to avoid triangular highlight warping. Rear capture exposed an engine brace crossing each exhaust aperture; mounts now sit above the opening. These detail corrections do not resolve the larger hulls' rectangular blockout silhouettes.


Family material inspection uses a less intense, steeper key light plus restrained fill/ambient illumination. The prior capture placed a broad specular highlight across the roof: a native StandardMaterial3D comparison reproduced the washout, so it was not evidence of an albedo bug in the custom shader. Use `--standard-material` after the capture script's `--` to compare native PBR against the custom shell with matched paint, roughness, metalness and clearcoat; comparison files have a `standard-` prefix. This changes inspection lighting only, not gameplay lighting, and does not establish final material quality.


Pathfinder and Merchant outer hulls now use three profile sections around the unchanged pressure-room footprint. Their sides slope outward to a shoulder and back toward the keel; Pathfinder is proportionally broader. Generic rectangular side insets were removed from these families, and configurable armor/window/radiator fittings project onto the actual hull triangles. The cockpit glazing sits outside the new bow. The result remains a low-detail blockout: roof plan, propulsion integration, surface construction and stronger family differentiation still require substantial design work.


Family shell paint now has restrained recessed fasteners, seal dirt and a slightly smoother coating. Engine fairings carry framed service grilles and low-profile rails. The shipyard and family capture tool share a neutral studio reflection environment so reflective finishes can be reviewed against the solid background. This improves material inspection, not the in-world lighting or the unfinished family silhouettes; the procedural grid and repeated roof equipment still need authored design.
