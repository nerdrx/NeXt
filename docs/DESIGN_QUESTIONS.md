# NeXt — design decisions

Answer in any order; short answers and reference images are welcome. These questions decide implementation and art requirements. A blank answer is unresolved, not approval for a major choice.

## Already agreed

- First-person exploration and combat, accessible ship flight, substantial procedural galaxies.
- Windows is the shipping platform; Linux play through Proton.
- Local worlds, with friends arriving in their own ships; Steam is the intended social/transport integration.
- Planets, atmospheres, cities, enormous stations, factions, pirates, police, commodity markets, companies, shares and hireable NPCs.
- Only ships and stations are craftable. Other goods and equipment are purchased, found, traded or salvaged.
- Owned ships can have walkable interiors when their size/layout supports them.
- Broad freedom and interacting systems, without hunger or thirst chores.
- Grounded, eventually near-photoreal visuals. Attractive procedural placeholders must be replaceable with authored art.
- The developer handles implementation and automated checks; the owner handles final art and playtesting.
- VR controls are a later requirement, so first-person interactions should remain adaptable.

## Confirmed in the questionnaire

- Travel: manual seamless flight, with optional autopilot.
- Visits: ship and cargo travel with the visitor; world economies remain separate.
- Failure: rescue/insurance, recoverable wrecks and meaningful losses.
- Setting: human-only, grounded space-age civilization.
- Multiplayer permissions: property owners grant access; PvP requires agreement.
- Crew: named NPCs who can fly, trade, fight and manage property.
- Offline behavior: simulation pauses while nobody hosts the world.
- Convenience: cargo and maintenance primarily through menus and services.
- Construction: modular construction, with editable rooms and hull panels.
- Hosted sessions: 2–8 players initially.
- Art references: Star Citizen for ships/materials/inhabited spaces; Elite Dangerous for immense cosmic vistas.
- Performance target: high-end PC, 1440p at 60 FPS. This is a target, not a benchmark result.

## First decisions: architecture

1. **Travel:** seamless manual flight from space to ground and through hangar doors, assisted transitions, or both with optional autopilot? Should hyperdrive cross systems only, or also shorten trips within a system?
2. **Visiting friends:** does the visiting character bring ship, cargo, wallet, crew, and reputation? Which changes return home? Can you leave a ship behind in a friend's world?
3. **Hardware:** target GPU, resolution, frame rate, minimum hardware and acceptable install size? Is 60 FPS the normal target, with VR's higher budget handled separately?
4. **Session size:** 2–4 friends, 8–16, or more? Host must be playing, or optional dedicated server? Can guests keep playing when the host leaves?
5. **Persistence:** one commander across worlds or separate save slots? Manual saves, autosaves, cloud backup, difficulty-specific restrictions? What happens to a visitor if a host restores an older save?

## World and visual direction

6. **Art references:** choose a few specific games/films/screenshots for ships, station interiors, planets, clothing and interfaces. How clean, worn, luxurious or dangerous should each region feel?
7. **Science:** grounded physics with fictional FTL, or freer science fantasy? Alien civilizations, alien wildlife, ruins, artificial megastructures, wormholes? Which are essential?
8. **Planet scope:** rocky surfaces, oceans, swimming/submersibles, caves, wildlife, weather, gas-giant upper atmospheres? Which must be explorable on foot?
9. **Scale versus density:** relatively few dense inhabited worlds amid wilderness, or frequent cities and stations? How long should an ordinary station-to-planet journey take?
10. **City access:** every building enterable, selected meaningful interiors, or generated district interiors? What activities make a city worth visiting?

## Ships, stations and daily life

11. **Construction:** snapping functional modules, structural blocks plus equipment, or shaping hulls freely? Symmetry, saved blueprints, imported community designs, moving parts?
12. **Interiors:** automatic floor plans, fully editable rooms/corridors/decks, or automatic layouts with manual edits? Crew quarters, cargo holds, engineering, hangars, bridges and escape pods?
13. **Interactions:** rank salvage, repairs, refuelling, EVA, cargo handling, hacking, boarding, exploration/scanning, ship theft, passenger transport, rescue and NPC conversation.
14. **Crew:** named persistent people with relationships and schedules, functional specialists, or both? Can they fly, trade, fight and manage stations without you? Can they die or leave?
15. **Control:** keyboard/mouse first or equal gamepad support? First-person body/hands visible? Third-person ship camera? Keep flight assistance enabled by default?

## Economy, factions and consequences

16. **Business:** own a trading company, factories, shipping fleets, banks, stock exchanges, or all of these? Does the player personally manage operations or appoint NPC managers?
17. **Factions:** join existing factions, found a faction, recruit members, claim systems, diplomacy, taxation, war, elections? What does owning territory actually permit?
18. **Economy depth:** physically transported goods and production chains everywhere, simulated regional markets, or a mix? How persistent should shortages and player market influence be?
19. **Crime and law:** smuggling, contraband, theft, piracy, bounty hunting, bribery, arrest/prison, confiscation, impounding, faction-specific laws? Which consequences are fun rather than tedious?
20. **Failure:** insurance and rescue, permanent ship/cargo loss, optional permadeath, or difficulty presets? Can stations and cities be destroyed? Can players recover wrecks?
21. **Multiplayer rules:** cooperative only, optional consensual PvP, or open friendly fire? Can guests damage property, trade with each other, modify your stations or command your crew?
22. **Progression:** money, discoveries, reputation, equipment, crew skill and territory—or character levels too? Should every ship be obtainable through trade alone?

## Release priorities

23. **First three complete experiences:** rank deep-space exploration, trader/company life, pirate/police combat, ship/station engineering, faction empire building and life aboard a crewed ship.
24. **Explicit exclusions:** what should NeXt avoid besides hunger/thirst? Examples: repetitive mining, gear durability, inventory busywork, mandatory survival meters, procedural filler quests, grind gates or online-only play.
25. **Modding and distribution:** workshop blueprints/assets/mods? Paid game or free? Offline-first with optional Steam, or Steam required for multiplayer only? Licenses for community-created assets?

## Current implementation is not a final decision

The code currently uses assisted surface transitions, an ENet world-visit transport, grid ship assembly and regional economic simulation. These are implemented mechanics under development, not answers to the unresolved product questions above. Steam transport, seamless planetary streaming, complete multiplayer authority and near-photoreal art are not claimed complete.
