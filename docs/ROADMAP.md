# NeXt: Roadmap

## Implemented development build

- First-person walking and ray combat, moving pirates/security, flight and local cruise autopilot.
- Deterministic galaxy addresses, distinct procedural celestial visuals, station hubs and colony surfaces.
- Modular ship assembly, live preview, generated walkable module interiors and compatible room/hull face refits.
- Planet survey records with proximity/speed requirements and one-time station payouts. Journal courses retain the selected planet through menu changes and jumps, with an explicit local surface-approach action. The active course is session-only.
- Commodities, shares, contracts, named crew and timed fleet orders, company treasury and station construction/upgrades.
- Insurance, recovery debt, persistent wreck cargo and one-time salvage.
- Player faction charters, treasury, station affiliations and stances affecting personal trade and police; dockable owned outpost decks.
- Versioned saves, persistent destruction, separate visitor finances and experimental ENet presence/travel.
- Host pirate/police ship snapshots and host-resolved visitor ship fire with attacker-only bounty/crime outcomes. NPC retaliation against visitors remains unfinished.
- Automated state, generation, actor, network, visitor and control checks; Windows export workflow.

These are bounded development systems. README lists their limits. Placeholder visuals do not yet meet the agreed art target.

## Next: continuous space and complete visits

- Origin rebasing and bounded local-scene culling are integrated. Add distant celestial LODs and populated sector streaming before increasing physical body scale.
- Expand the current same-scene manual landings on small spherical bodies into planet-scale terrain streaming, larger populated settlements, building interiors and manual hangar approaches. Compact continuous surface ports now exist.
- Move combat, property and economic decisions to host authority; implement owner permissions and extend the current ENet agreed flight PvP to complete shared combat.
- Add durable ship/cargo transfer transactions, reconnect recovery and duplicate prevention.
- Integrate and validate Steam friends, invitations and relay using configured Steamworks credentials.

## Deeper simulation

- Build canonical physical celestial data (mass, radius, luminosity, orbit and spin) separately from render coordinates; migrate current toy-scale body positions without silently invalidating saves.
- Integrate deterministic hosted-time orbital motion, binary systems, body-relative landing/station frames, gravity, temperature and tidal effects. Validate against reference cases and document model limits.
- Connect ship acceleration and g-forces to crew and flight-assist controls; add black-hole gravitational effects and lensing with explicit approximations. The current visuals do not establish physical simulation accuracy.

- Local gunner patrols now fly and fight in loaded space. Extend that integration to trader arrivals/docking, persistent fleet positions and physical disabled-ship salvage; add richer named crew behavior.
- Extend existing compatible room/panel refits to wall placement, equipment movement, doors and physically persistent ship interiors.
- Expand implemented rescue/insurance and wreck recovery into towing, repairable derelicts and NPC rescue encounters.
- Extend player factions into membership, territorial sovereignty, negotiated diplomacy and production chains; deepen law enforcement consequences.
- Populated cities with useful interiors and procedural variation tied to local industry and culture.

## Presentation and release

- Replace assets using the asset checklist; establish authored material and lighting references.
- Measure GPU/CPU budgets at 1440p, then validate high-end 60 FPS target under realistic loads.
- Validate Windows hardware and Proton separately; automate packaged smoke and save compatibility checks.
- Add controller accessibility and later VR input/comfort after desktop interaction is stable.

## Release gates

Do not claim seamless travel, Steam integration, authoritative co-op, secure transfers, complete NPC autonomy or near-photoreal art from the current build. Headless tests establish specific logic checks; short GPU/Proton smoke runs do not establish performance or full playability. Final acceptance includes owner art review and playtesting.
