# NeXt: Roadmap

## Implemented development build

- First-person walking and ray combat, moving pirates/security, flight and local cruise autopilot.
- Deterministic galaxy addresses, distinct procedural celestial visuals, station hubs and colony surfaces.
- Modular ship assembly, live preview and generated walkable module interiors.
- Commodities, shares, contracts, crew role effects, company treasury and station construction/upgrades.
- Versioned saves, persistent destruction, separate visitor finances and experimental ENet presence/travel.
- Automated state, generation, actor, network, visitor and control checks; Windows export workflow.

These are bounded development systems. README lists their limits. Placeholder visuals do not yet meet the agreed art target.

## Next: continuous space and complete visits

- Introduce origin rebasing and streamed spatial sectors before increasing physical scale.
- Replace surface scene transitions with planetary terrain streaming, atmosphere descent and manual hangar approaches.
- Move combat, property and economic decisions to host authority; implement owner permissions and agreed PvP.
- Add durable ship/cargo transfer transactions, reconnect recovery and duplicate prevention.
- Integrate and validate Steam friends, invitations and relay using configured Steamworks credentials.

## Deeper simulation

- Named persistent crew with orders, independent piloting/trading/combat and property management.
- Editable rooms, hull panels, doors, equipment and physically persistent ship interiors.
- Rescue/insurance, recoverable wrecks, salvage and meaningful loss rules.
- Player factions, sovereignty, diplomacy, production chains and law enforcement consequences.
- Populated cities with useful interiors and procedural variation tied to local industry and culture.

## Presentation and release

- Replace assets using the asset checklist; establish authored material and lighting references.
- Measure GPU/CPU budgets at 1440p, then validate high-end 60 FPS target under realistic loads.
- Validate Windows hardware and Proton separately; automate packaged smoke and save compatibility checks.
- Add controller accessibility and later VR input/comfort after desktop interaction is stable.

## Release gates

Do not claim seamless travel, Steam integration, authoritative co-op, secure transfers, NPC autonomy or near-photoreal art from the current build. Headless tests establish specific logic checks; short GPU/Proton smoke runs do not establish performance or full playability. Final acceptance includes owner art review and playtesting.
