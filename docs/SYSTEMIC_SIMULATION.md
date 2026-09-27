# Systemic simulation contract

The owner requests that any feasible system which interacts with its surroundings be simulated or meaningfully approximated. This is a design requirement, not a claim about current implementation.

## Connected causes and consequences

A system should consume shared world state and produce consequences other systems can use. A decorative number or an isolated timer does not establish the promised interaction. Prefer a coherent approximation with documented limits over disconnected detail.

| System | Inputs and interactions | Required consequences |
| --- | --- | --- |
| Celestial dynamics | Mass, radius, orbital state, spin, multiple bodies | Gravity, orbital motion, tides, eclipses and reference frames |
| Radiation and heat | Stellar luminosity, distance, exposure, atmosphere, equipment waste heat | Surface and ship temperatures, cooling load, damage and sensor visibility |
| Ship engineering | Power generation/storage, demand, fuel, heat, module connections and failures | Available thrust, shields, weapons, life support and repair priorities |
| Motion and crew loads | Forces, mass distribution, acceleration and flight assists | Trajectories, fuel expenditure, crew g-forces and equipment loads |
| Atmospheres and compartments | Gas amount, volume, temperature, connected doors and hull openings | Pressure, leakage, breathable conditions and environmental hazards |
| Damage and salvage | Local impacts, module condition, cargo and nearby hazards | Disabled systems, repair requirements, recoverable wrecks and rescue |
| Resources and industry | Inventories, extraction, production inputs, transport and demand | Scarcity, prices, jobs, company finances and faction dependencies |
| NPC decisions and law | Needs relevant to work, skills, resources, danger, relationships and permissions | Observable work/travel, emergency responses, piracy, police and reputation |

No hunger or thirst chores are introduced. Environmental life-support consequences and crew rescue remain compatible with the owner's convenience preferences.

## Simulation resolution

Use detailed local simulation where players can observe or interact. Use cheaper strategic approximations for distant systems, with explicit transitions between representations. Preserve identity, inventory, condition and consequences when entities cross those boundaries. Avoid counting both detailed and strategic outcomes for the same entity.

The hosted world owns authoritative simulation state. A closed world pauses. Deterministic seeds and hosted simulation time support reproducibility; rendered animation time must not drive authoritative forces or economies. Saved physical data needs explicit units and versioned migration. Visiting ships and cargo must obey the separate-world economy and owner-permission rules.

## Implementation order

1. Establish canonical physical body properties, units and deterministic orbital state; plan scale and save migration before moving current locations.
2. Connect gravity, radiation/temperature and acceleration to ship motion and accessible flight assists.
3. Connect module power, heat, damage and repair; extend to compartment pressure and emergency crew behavior.
4. Tie local and distant NPC work to conserved resources, logistics, industry and economic consequences.
5. Extend faction, police and social decisions using the same persisted events and ownership rules.

Order can change when dependencies or evidence justify it. Validate interactions, conservation or bounded approximations, save/load continuity, authority and transitions; do not use visual captures alone as proof of physical accuracy. Record omitted effects and numerical limits beside each model.
