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
