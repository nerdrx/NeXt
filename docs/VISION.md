# NeXt: Vision

A human space-age immersive sim about exploration, money, combat and building a faction. Players walk through their ships, stations and cities, fly manually, and use optional autopilot and convenient menus for services. Only ships and stations are craftable; hunger and thirst are excluded.

The visual destination combines Star Citizen’s believable interiors and materials with Elite Dangerous’s immense cosmic vistas. Near-photorealism is a production target. The current procedural assets are replaceable placeholders; the owner supplies final art and playtesting.

Windows is the shipping platform, with Linux play through Proton. The performance target is a high-end PC at 1440p/60 FPS, not an established benchmark. VR follows desktop controls and interaction design.

Local worlds pause without a host. Sessions target 2–8 friends, carrying ships and cargo between separate world economies. Property owners grant permissions; PvP requires agreement. Defeat should lead to rescue, insurance and recoverable wrecks with meaningful losses. Named hired crew should eventually fly, trade, fight and manage property independently.

Manual seamless planetary travel, editable ship rooms and hull panels, Steam sessions, NPC autonomy and complete multiplayer authority remain major engineering work. See [README](../README.md) for implemented behavior, [roadmap](ROADMAP.md) for remaining work and [confirmed decisions](DESIGN_QUESTIONS.md) for the owner’s answers.

## Astronomical simulation target

The owner requests Elite Dangerous-like astronomical simulation accuracy: stellar bodies and their interactions, black holes, temperature and g-forces. Build a physically coherent model with documented approximations, including consistent masses/radii, gravity, orbital motion, multiple-star systems, heating and tidal effects. Black holes require gravitational gameplay and optical treatment. Ship acceleration should produce meaningful crew loads while optional flight assists preserve accessible controls.

This is a target, not a description of the current build. Current small, fixed-position bodies and cosmetic stellar effects do not satisfy it. Physical units, astronomical scale, deterministic hosted-time ephemerides, reference-frame transitions and validated force/thermal models must precede a claim of accurate simulation. Existing saved locations and casual travel controls need an explicit migration and compatibility plan.

Feasible systems should interact with their surroundings through coherent simulation or documented approximation. See the [systemic simulation contract](SYSTEMIC_SIMULATION.md) for cross-system dependencies, local/distant detail and implementation priorities.
