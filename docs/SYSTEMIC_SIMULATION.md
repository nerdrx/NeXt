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

## When a simulation is worth building

Include a system when it changes a player decision, another system's state, or an observable outcome. Choose the cheapest model that preserves those effects. Feasibility includes the high-end 1440p/60 FPS target and 2–8 player hosting; neither target is currently proven. Do not promise atom-by-atom simulation, full relativistic fluid dynamics or continuous processing of every inhabited system.

Examples of intended connected behavior, not current feature claims:

- Sustained thrust consumes fuel and produces waste heat; cooling capacity limits sustained output, while emitted heat affects detection.
- A hull breach connects a compartment to vacuum; gas escapes, doors isolate connected volumes, and crew respond to the remaining safe routes.
- An eclipse reduces incident stellar energy; thermal inertia delays cooling, and solar generation changes immediately with exposure.
- Destroyed freight removes actual goods from delivery; shortage affects prices, replacement jobs and the affected company's finances.
- Piracy leaves witnesses or sensor evidence; communication and jurisdiction determine police response rather than omniscient instant punishment.

Every new model must identify its inputs, units, state owner, outputs, update rate and known omissions. A downstream consumer must use those outputs before the interaction is described as implemented. Tests should cover one causal chain, its boundary conditions, and save/load or representation changes where applicable. Resource sources and sinks must be explicit, including deliberately abstract services such as emergency refueling. Never silently create replacement cargo, energy or work when changing simulation detail.

Transfers and settlements must apply each outcome once under one authority. Test repeated loads, jumps and reconnects, simultaneous claims, invalid quantities and permission failures. Approximation may reduce physical detail; it must not duplicate goods, replay income or bypass ownership.

Casual controls automate actions within these rules. Autopilot, hired crew and menu services should expose costs and consequences without demanding repetitive manual handling. Environmental complexity is a source of choices, not an excuse to add hunger, thirst or maintenance chores.

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

Module mass is interpreted as tonnes; each freight unit adds one tonne. Engine ratings provide 65,000 newtons per rating point. These are game tuning assumptions, not measured engine specifications. Translational acceleration uses thrust divided by loaded mass, capped at 3 standard g; boost uses reactor headroom to increase force by up to two times, with a 6 g cap. Manual flight, autopilot approach, obstacle braking and an occupied walkable ship share this limit. The shipyard displays loaded mass, thrust and acceleration.

Braking assumes equal thrust in every direction; rotation, fuel mass, inertia tensors and crew physiology do not yet constrain it; drive heat now limits available force as described below. Reactor headroom constrains boost as described below. Top speed retains the existing gameplay limit. Obstacle queries cap lookahead at 100 km for finite physics queries; this is not a guarantee of stopping from arbitrary externally restored velocities.

## Celestial catalog and scale migration

`CelestialSystem` now generates deterministic SI-unit body properties without consuming the existing world RNG. Stable body IDs combine the system address and planet index. `CelestialPhysics` calculates elliptic two-body positions and speeds, radiation flux, equilibrium temperature, surface gravity and non-rotating black-hole horizon radius. The Navigation physical survey samples these properties at a separately persisted physical epoch. Physical time advances one second per active simulation second; the economy calendar still settles a day per 1,200 seconds. Closed saves do not advance from wall-clock time. Saves without the physical epoch derive their previous survey instant from the old calendar once on load, then adopt physical time. Jump-driven economy settlements do not change the physical epoch.

The dependency chain is stellar radius/temperature → luminosity → orbital distance → received radiation → equilibrium temperature. Planet mass/radius determine surface gravity; combined star/planet mass and semimajor axis determine period. A nebula is treated as an environment containing a central star, not a point-mass star type. Inactive black holes emit no radiation in this approximation; accretion, background/internal heat, black-hole spin, relativity and companion stars remain absent. Generated stellar profiles and planet density ranges are game approximations, not a formation/evolution population synthesis. The original v1 orbits are coplanar, non-crossing at generation, and unperturbed; this is not proof of long-term multi-body stability. Giant classifications describe the physical catalog, not the existing landable geometry.

Catalog v2 adds seeded inclination, ascending node, periapsis orientation, axial tilt and spin phase using a separate random stream. The original masses, sizes, periods and terrain generation retain their values. Orbits now have distinct three-dimensional orientations; their radial bands still do not overlap. A supplied v1 catalog without orientation fields retains its original XZ orbital interpretation. Generated catalogs are derived data rather than relocated saved flight objects.

CelestialFrame carries position and analytical velocity through scalar-double rotations before constructing SectorPosition addresses. Positive orbital phase maps X toward Z, with angular momentum along -Y; positive rotation periods use prograde spin about that same axis. Surface-point velocity includes both orbital translation and angular velocity crossed with the rotated offset, consistent with [JPL's state transformation treatment](https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/req/rotation.html). Axial tilt is measured relative to the orbital plane with a fixed node-aligned tilt direction; precession is absent. Returned Basis values are for local directions, not astronomical translation.

The survey shows a reference site's direct illumination at equator/longitude zero. Planetary rotation, tilt, orbital position and stellar luminosity determine its day/night state and cosine-weighted flux. This is point-source illumination above atmospheric absorption, with no clouds, eclipses, scattering, surface temperature integration or terrain horizon. It does not change the compact flight scene's lighting. Ephemeris velocities are metres per physical second; the dedicated physical clock now uses the same second scale as flight. Moving geometry still requires body-relative location, rendering and collision migration. Local surface coordinates still enter as Vector3, so callers must not assume sub-metre precision for arbitrary planet-radius input components.

Nominal stellar/planetary constants follow [IAU 2015 B3](https://iauarchive.eso.org/static/resolutions/IAU2015_English.pdf). The full-redistribution blackbody estimate follows the [NASA-hosted habitable-zone tutorial](https://science.nasa.gov/wp-content/uploads/2023/09/Habitable_Zone.pdf). Equilibrium temperature is not surface temperature: greenhouse warming and thermal inertia are not included.

### Required runtime migration

The current flight scene still places fixed planets of radius 850 m or less within kilometres of the dock. Applying catalog gravity at those compressed distances would be physically false. The survey explicitly labels the separation; it does not claim force, thermal damage or orbital motion in the flight scene.

1. Version physical locations as system/body ID plus body-relative sector address and velocity. Preserve existing legacy layouts during migration and convert landed ships, commanders, colonies and wrecks together. An old arbitrary orbital position cannot be scaled by one universal factor; relocate it to a documented safe parking orbit around its associated body, with a migration receipt and recoverable original save.
2. Evaluate the catalog at authoritative host time; extend to oriented three-dimensional orbits and rotating reference frames. Project only bounded camera-relative positions into Godot Vector3. Keep astronomical positions as scalar doubles/sector addresses and account for frame velocity when transferring ships or projectiles.
3. Replace compact spheres with planet-scale horizon/terrain LOD and collision patches before enabling real radii. Separate distant apparent-size rendering from nearby collision geometry. Stream surface ports in their body frame; preserve their local layout coordinates.
4. Connect gravity and radiation to ships, ground bodies and thermal state using those same positions. Add bounded integration, orbital/coasting flight and assisted hover; validate circular orbits, energy drift, reference-frame transfers, eclipses and save/host continuity.
5. Retire compressed flight geometry only after landing, navigation, multiplayer positions, saves and wreck recovery pass at physical scale. Do not silently mix catalog metres with old display coordinates.

## Physical clock persistence

`ephemeris_seconds` is an optional extension to the existing v3 save schema, required in new writes. Existing v2/v3 saves derive `(day + day_progress / 1200) * 86400` once; v1 derives its default calendar epoch. Invalid or non-finite epochs are rejected transactionally. The capacity is 10^12 seconds (about 31,000 years), keeping double time resolution below one millisecond; an overflowing tick is rejected before either clock changes. Older binaries may reject the new save field, so retain backups and use matching builds.

## Reactor reserve and boosted thrust

Module power values are abstract capacity ratings, not watts. All nominal loads are reserved continuously, including weapons and shields while idle. Remaining generation can serve additional engine demand: the thrust multiplier is `clamp(1 + surplus / engine_demand, 1, 2)`. Boost acceleration uses that force divided by loaded mass before the 6 g cap; it does not multiply an already-capped normal acceleration. Normal thrust retains the 3 g comfort cap. The boost speed target scales from normal to the existing three-times target as reserve rises; this remains a flight-assist tuning limit rather than a physical speed limit.

Adding powered modules can reduce boost reserve. Adding a reactor restores capacity but also adds mass, so acceleration remains mass-dependent. Shipyard stats expose demand/generation, normal and boost acceleration, and extra thrust percentage. This model does not yet redistribute idle power, simulate batteries or reactor damage; the drive has a separate thermal approximation below. Propellant expenditure uses the impulse approximation below. Shields and weapons retain their reserved nominal supply; dynamic engineering priorities remain unfinished.

## Propellant and momentum

Manual flight, boost, assisted braking and autopilot share the saved fuel tank with hyperdrive. Applied translational impulse consumes `loaded_mass_kg * |delta_velocity| / 5,000,000` tank units. The impulse-per-unit constant is gameplay tuning, not an engine specification. Partial fuel permits only the affordable velocity change; an empty tank removes thrust without deleting momentum. Arrival requires an actual stop after this limit. Collision impulses do not spend propellant, and an unbraked walkable hull coasts without fuel use. Rotation still has no propellant cost.

The current mass estimate excludes fuel mass, so this is a constant-loaded-mass impulse budget, not a rocket-equation simulation. Fuel also retains the existing fixed hyperdrive cost. Refueling remains a menu service. An empty tank can receive 20 units through Rescue & Recovery for `max(500, 4 * local_fuel_price)` credits; unpaid fees become existing rescue debt. This is an immediate abstract delivery service, not a simulated tanker or conserved supplier inventory. It preserves a recovery path for empty, cashless ships.

## Flight assist and inertial controls

Flight assist remains enabled by default and matches a commanded speed, braking when input is released. The Flight Settings toggle can select inertial control: thrust changes velocity along the camera axes, other velocity components persist, and released controls spend no propulsion fuel. Inertial manual flight has no artificial target-speed cap. Normal/boost acceleration, reactor reserve, fuel limits and swept collision still apply. Autopilot uses its existing guidance in either mode.

B and the Flight Settings brake action command a fuel-limited stop at the helm or aboard. Movement input cancels manual braking, retaining the existing override behavior. The HUD distinguishes inertial flight from assisted flight and braking. The preference persists in settings.cfg; older settings default to assisted flight. Relativistic motion, flight-envelope limits and rotational fuel use remain unimplemented.

## Drive thermal loop

Applied propulsion fuel produces 50 MJ of waste heat per tank unit in a shared drive loop with heat capacity 2.5 MJ/K. This raises its temperature by 20 K per unit. Available force falls linearly from full output at 500 K to zero at 700 K, before the existing acceleration caps. The impulse budget also limits fuel expenditure to the remaining thermal capacity, so reaching the ceiling cannot delete momentum or overrun the temperature limit. Braking and boost use the same loop; coasting produces no drive heat.

Cooling uses `0.8 * sigma * radiator_area_m2 * (T^4 - 300^4)` watts and the loop heat capacity, with bounded physics steps of at most one second. The 300 K floor represents a regulated loop, not ambient space. Radiator emission and thermal balance follow the physical concepts in [NASA's thermal-control overview](https://www.nasa.gov/smallsat-institute/sst-soa/thermal-control/); the chosen capacity, area, waste heat and protection thresholds are gameplay assumptions. This loop has fixed heat capacity, so refitting cannot erase stored thermal energy. Radiator area is now layout-dependent as described below. Stellar heating, atmospheric convection, hull/cabin temperatures, reactor heat and thermal damage remain unfinished. Thermal target detection is described below.

The HUD shows drive temperature and available force percentage. Cooling automatically restores thrust. Temperature persists as an optional v3 save field, defaults to 300 K for older saves, and follows the carried ship during visits and return travel. Invalid temperatures outside 300–700 K are rejected. Rescue supplies a cooled replacement drive; ordinary refueling does not cool the existing drive. Closed worlds do not cool from wall-clock time.

## Modular radiators and exposure

Radiator modules cost 900 credits and add two tonnes. They use passive thermal transport in this approximation, with no extra power draw. The existing abstract 40 m² cooling area remains; each radiator adds 5 m² per exposed face. Any directly adjacent module or an armored/window panel on that face blocks its contribution. Restoring a standard panel or removing the adjacent module restores it. Rendering and thermal calculations share the same face-selection rule; exposed faces have ribbed cooling panels, and the shipyard reports effective area and temperature.

The 5 m² per-face rating is a tuned effective area rather than a mesh-area measurement. This is local face occlusion, not a radiative view-factor solver: distant hull geometry, self-radiation, orientation toward stars, module damage and environmental exposure are absent. The baseline 40 m² is not individually placed or occluded. Adding a radiator increases cooling without increasing the shared loop's heat capacity; added module mass still changes propulsion requirements. Temperature persists through construction and layout changes. New radiator-equipped designs require matching builds for saves and multiplayer.

## Thermal detection and combat contacts

Drive-loop radiation now feeds NPC target acquisition and NPC contact markers/radar. Gross emission is `0.8 * sigma * exposed_area * temperature^4`, using the same radiation helper as net cooling. The regulated 300 K floor still emits; a drive that has stopped producing new waste heat is not invisible. Sensor range scales with the square root of emitted power, tuned to 800 m for 40 m² at 300 K and capped at 6 km. A 600 K drive at that area has a nominal 3.2 km range. The HUD shows the player's nominal thermal visibility, not a guarantee that any observer has a clear view.

Pirates, police and hired fleet ships select only detectable targets. A ray against world collision geometry blocks acquisition through planets, stations and other opaque static cover. Returning inside range or removing cover permits reacquisition; losing detection clears the current target. Existing hostility, safe zones, weapon range and ownership/PvP rules remain separate. The same test filters player HUD contacts for NPC ships. Navigation beacons and friend labels remain explicit markers, not covert thermal contacts.

More exposed radiator area increases emission at a fixed temperature but cools the loop faster. Coasting permits cooling without new propulsion heat, reducing subsequent visibility. Radiator layout, drive temperature, motion and enemy acquisition therefore share a causal chain. NPC propulsion still uses a fixed 450 K / 40 m² signature (1.8 km nominal range); autonomous NPC heat budgets remain unfinished.

This is isotropic threshold detection with immediate acquisition/loss, not a telescope or radar simulation. Radiator direction, spectral bands, background clutter, atmosphere, active scanning, sensor damage, scan delays, contact memory and search behavior are absent. World collision geometry is the occluder; other moving ships do not occlude the thermal ray. Friend thermal state is not replicated for PvP stealth, and player-client NPC simulation is not yet host-authoritative. No claim of secure shared multiplayer stealth is made.
