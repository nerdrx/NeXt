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

## Current ship force approximation

Module mass is interpreted as tonnes; each freight unit adds one tonne. Engine ratings provide 65,000 newtons per rating point. These are game tuning assumptions, not measured engine specifications. Translational acceleration uses thrust divided by loaded mass, capped at 3 standard g; boost doubles available force with a 6 g cap. Manual flight, autopilot approach, obstacle braking and an occupied walkable ship share this limit. The shipyard displays loaded mass, thrust and acceleration.

Braking assumes equal thrust in every direction; rotation, fuel mass, inertia tensors, crew physiology, reactor power and heat do not yet constrain it. Top speed retains the existing gameplay limit. Obstacle queries cap lookahead at 100 km for finite physics queries; this is not a guarantee of stopping from arbitrary externally restored velocities.

## Celestial catalog and scale migration

`CelestialSystem` now generates deterministic SI-unit body properties without consuming the existing world RNG. Stable body IDs combine the system address and planet index. `CelestialPhysics` calculates elliptic two-body positions and speeds, radiation flux, equilibrium temperature, surface gravity and non-rotating black-hole horizon radius. The Navigation physical survey samples these properties at the persisted calendar epoch. One game calendar day maps to 86,400 astronomical seconds; the existing calendar advances one day per 1,200 hosted seconds. Closed saves do not advance from wall-clock time.

The dependency chain is stellar radius/temperature → luminosity → orbital distance → received radiation → equilibrium temperature. Planet mass/radius determine surface gravity; combined star/planet mass and semimajor axis determine period. A nebula is treated as an environment containing a central star, not a point-mass star type. Inactive black holes emit no radiation in this approximation; accretion, background/internal heat, black-hole spin, relativity and companion stars remain absent. Generated stellar profiles and planet density ranges are game approximations, not a formation/evolution population synthesis. The original v1 orbits are coplanar, non-crossing at generation, and unperturbed; this is not proof of long-term multi-body stability. Giant classifications describe the physical catalog, not the existing landable geometry.

Catalog v2 adds seeded inclination, ascending node, periapsis orientation, axial tilt and spin phase using a separate random stream. The original masses, sizes, periods and terrain generation retain their values. Orbits now have distinct three-dimensional orientations; their radial bands still do not overlap. A supplied v1 catalog without orientation fields retains its original XZ orbital interpretation. Generated catalogs are derived data rather than relocated saved flight objects.

CelestialFrame carries position and analytical velocity through scalar-double rotations before constructing SectorPosition addresses. Positive orbital phase maps X toward Z, with angular momentum along -Y; positive rotation periods use prograde spin about that same axis. Surface-point velocity includes both orbital translation and angular velocity crossed with the rotated offset, consistent with [JPL's state transformation treatment](https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/req/rotation.html). Axial tilt is measured relative to the orbital plane with a fixed node-aligned tilt direction; precession is absent. Returned Basis values are for local directions, not astronomical translation.

The survey shows a reference site's direct illumination at equator/longitude zero. Planetary rotation, tilt, orbital position and stellar luminosity determine its day/night state and cosine-weighted flux. This is point-source illumination above atmospheric absorption, with no clouds, eclipses, scattering, surface temperature integration or terrain horizon. It does not change the compact flight scene's lighting. Ephemeris velocities are metres per physical second; the accelerated calendar must be reconciled with flight time before these frames drive moving runtime geometry. Local surface coordinates still enter as Vector3, so callers must not assume sub-metre precision for arbitrary planet-radius input components.

Nominal stellar/planetary constants follow [IAU 2015 B3](https://iauarchive.eso.org/static/resolutions/IAU2015_English.pdf). The full-redistribution blackbody estimate follows the [NASA-hosted habitable-zone tutorial](https://science.nasa.gov/wp-content/uploads/2023/09/Habitable_Zone.pdf). Equilibrium temperature is not surface temperature: greenhouse warming and thermal inertia are not included.

### Required runtime migration

The current flight scene still places fixed planets of radius 850 m or less within kilometres of the dock. Applying catalog gravity at those compressed distances would be physically false. The survey explicitly labels the separation; it does not claim force, thermal damage or orbital motion in the flight scene.

1. Version physical locations as system/body ID plus body-relative sector address and velocity. Preserve existing legacy layouts during migration and convert landed ships, commanders, colonies and wrecks together. An old arbitrary orbital position cannot be scaled by one universal factor; relocate it to a documented safe parking orbit around its associated body, with a migration receipt and recoverable original save.
2. Evaluate the catalog at authoritative host time; extend to oriented three-dimensional orbits and rotating reference frames. Project only bounded camera-relative positions into Godot Vector3. Keep astronomical positions as scalar doubles/sector addresses and account for frame velocity when transferring ships or projectiles.
3. Replace compact spheres with planet-scale horizon/terrain LOD and collision patches before enabling real radii. Separate distant apparent-size rendering from nearby collision geometry. Stream surface ports in their body frame; preserve their local layout coordinates.
4. Connect gravity and radiation to ships, ground bodies and thermal state using those same positions. Add bounded integration, orbital/coasting flight and assisted hover; validate circular orbits, energy drift, reference-frame transfers, eclipses and save/host continuity.
5. Retire compressed flight geometry only after landing, navigation, multiplayer positions, saves and wreck recovery pass at physical scale. Do not silently mix catalog metres with old display coordinates.
