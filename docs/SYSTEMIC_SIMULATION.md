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

Cooling uses `0.8 * sigma * radiator_area_m2 * (T^4 - 300^4)` watts and the loop heat capacity, with bounded physics steps of at most one second. The 300 K floor represents a regulated loop, not ambient space. Radiator emission and thermal balance follow the physical concepts in [NASA's thermal-control overview](https://www.nasa.gov/smallsat-institute/sst-soa/thermal-control/); the chosen capacity, area, waste heat and protection thresholds are gameplay assumptions. This loop has fixed heat capacity, so refitting cannot erase stored thermal energy. Radiator area is now layout-dependent as described below. Powered-system waste heat now enters this loop as described below. Stellar heating, atmospheric convection, separate hull/cabin temperatures, reactor thermodynamics and thermal damage remain unfinished. Thermal target detection is described below.

The HUD shows drive temperature and available force percentage. Cooling automatically restores thrust. Temperature persists as an optional v3 save field, defaults to 300 K for older saves, and follows the carried ship during visits and return travel. Invalid temperatures outside 300–700 K are rejected. Rescue supplies a cooled replacement drive; ordinary refueling does not cool the existing drive. Closed worlds do not cool from wall-clock time.

## Modular radiators and exposure

Radiator modules cost 900 credits and add two tonnes. They use passive thermal transport in this approximation, with no extra power draw. The existing abstract 40 m² cooling area remains; each radiator adds 5 m² per exposed face. Any directly adjacent module or an armored/window panel on that face blocks its contribution. Restoring a standard panel or removing the adjacent module restores it. Rendering and thermal calculations share the same face-selection rule; exposed faces have ribbed cooling panels, and the shipyard reports effective area and temperature.

The 5 m² per-face rating is a tuned effective area rather than a mesh-area measurement. This is local face occlusion, not a radiative view-factor solver: distant hull geometry, self-radiation, orientation toward stars, module damage and environmental exposure are absent. The baseline 40 m² is not individually placed or occluded. Adding a radiator increases cooling without increasing the shared loop's heat capacity; added module mass still changes propulsion requirements. Temperature persists through construction and layout changes. New radiator-equipped designs require matching builds for saves and multiplayer.

## Thermal detection and combat contacts

Drive-loop radiation now feeds NPC target acquisition and NPC contact markers/radar. Gross emission is `0.8 * sigma * exposed_area * temperature^4`, using the same radiation helper as net cooling. The regulated 300 K floor still emits; a drive that has stopped producing new waste heat is not invisible. Sensor range scales with the square root of emitted power, tuned to 800 m for 40 m² at 300 K and capped at 6 km. A 600 K drive at that area has a nominal 3.2 km range. The HUD shows the player's nominal thermal visibility, not a guarantee that any observer has a clear view.

Pirates, police and hired fleet ships select only detectable targets. A ray against world collision geometry blocks acquisition through planets, stations and other opaque static cover. Returning inside range or removing cover permits reacquisition; losing detection clears the firing target and starts the bounded search described below. Existing hostility, safe zones, weapon range and ownership/PvP rules remain separate. The same test filters player HUD contacts for NPC ships. Navigation beacons and friend labels remain explicit markers, not covert thermal contacts.

More exposed radiator area increases emission at a fixed temperature but cools the loop faster. Coasting permits cooling without new propulsion heat, reducing subsequent visibility. Radiator layout, drive temperature, motion and enemy acquisition therefore share a causal chain. NPC propulsion now drives a local thermal budget and changing detection range, as described below.

This is isotropic threshold detection with immediate acquisition/loss, not a telescope or radar simulation. Radiator direction, spectral bands, background clutter, atmosphere, active scanning, sensor damage, scan delays and tactical search planning are absent. World collision geometry is the occluder; other moving ships do not occlude the thermal ray. Friend thermal state is not replicated for PvP stealth, and player-client NPC simulation is not yet host-authoritative. No claim of secure shared multiplayer stealth is made.

## Last-contact search

Hostile NPC ships retain only the last position observed by target acquisition. Losing detection clears the firing target and permits a 15-second search toward that point, followed by a small local sweep on arrival. Hidden target movement does not update the point. Reacquisition supplies a new observed position and resets the search allowance. Expiry restores the existing home patrol. Searching alone never permits firing.

Inactive actors pause their search clock. Passive police and paused/unpaid patrol orders clear the search allowance. A world-origin shift transforms the remembered position with the actor's home and safety coordinates. Search state is local transient AI state and is not saved; reloading or rebuilding the system discards it. Local obstacle steering applies during search as described below. Global route planning, velocity prediction, shared reports and coordinated search patterns remain unfinished.

## Local NPC obstacle steering

NPC patrol, pursuit, retreat and last-contact search commands now sweep a 2.6 m sphere against world collision geometry before choosing a velocity. Lookahead is two seconds at the requested speed, with a 16 m minimum. A blocked direct path samples horizontal and vertical alternatives at 45, 75 and 90 degrees. Forward progress and continuity with the previous avoidance direction select among clear candidates. A clear direct path restores normal steering; a fully blocked fan commands braking through the existing velocity smoothing. The rendered hull turns toward actual velocity.

This is bounded local avoidance, not a global route solver or a collision-free trajectory guarantee. Ship collision remains the final barrier, including during braking. Concave obstacles, tunnels, moving traffic and already-overlapping spawns can still stop an actor. The fixed radius matches the current NPC collider rather than arbitrary custom ships; acceleration, fuel and drive heat remain separate NPC-model work. Candidate sweeps run only when the direct sweep is blocked. Performance with many simultaneously obstructed NPCs is not yet benchmarked.

## Local hired trade voyages

Assigned traders in the player's represented system now materialize as passive fleet ships with named crew and a cargo-module visual variant. Outbound ships fly from the local freight berth toward a departure point; inbound ships fly from that point toward the berth. They use exact travel targets and the NPC obstacle steering rather than patrol orbiting. Pirates can select them and damage persists to the fleet record. Disabled vessels cannot advance orders.

The existing 600-second trade-leg timer remains the minimum settlement time. A represented trader must also arrive within 15 m of its target and slow to 5 m/s or less. Until then, progress waits at 600 seconds without charging wages or buying/selling goods. Readiness permits exactly one settlement; the same observation cannot pay for or settle another leg. Actors are resynchronized immediately after reports so departing ships no longer remain damageable in their old system. Existing escrow, cargo and wage accounting remains shared with distant strategic voyages.

This is physical local travel around an abstract freight terminal. Purchases still finalize at the outbound leg's departure transition; sales finalize at the inbound berth transition. Inter-system travel and loading services remain abstract. Market inventories now track actual traded units as described below. Traders outside local representation, including spatially culled actors, continue strategic progression. Local trader position and velocity persist alongside order progress and inventory, as described below. Patrol position, momentum and course now persist as described under Patrol flight persistence. Closed worlds do not advance. Shared host-authoritative fleet logistics remains unfinished.


## Local trader flight continuity

Fleet records may carry a trade-phase flight snapshot: a system-space sector address in metres and velocity in metres per second. Saving and leaving local representation preserve the snapshot. Restoring a trader uses the saved motion while recomputing its berth/departure endpoint from the current route phase. Changing the camera origin must not move that endpoint relative to the system. The current compact-system snapshot is limited to 1,000 km from the system origin and finite velocity of at most 1,000 m/s. This bound is separate from the galaxy address capacity; migrating fleet routes to physical planetary scales will require expanding this representation. Culled actors retain their last absolute address until strategic work changes their route phase.

A completed trade leg or cancelled/reassigned order discards the old snapshot. Distant strategic work still changes systems through the existing abstract leg transitions; it does not integrate an unseen trajectory. Closed worlds remain paused. This preserves local approaches across saves without claiming physical inter-system freight travel or shared multiplayer fleet authority.


## Finite exchange supply and freight deliveries

Each system/good starts with a deterministic inventory of 200–600 commodity units. Reads do not allocate records. Player purchases and hired freighter purchases remove units from the same market; sales and delivered freight add units. Only changed stocks are persisted, with a maximum of 10,000 changed systems and 100,000 units per commodity. Reaching the record cap rejects a new market mutation rather than forgetting an existing shortage. Saves without inventories start at the deterministic initial supply; no retroactive transaction history is inferred.

The seeded daily base price now receives a supply multiplier: `clamp(((initial + 1) / (stock + 1))^0.35, 0.5, 3.0)`. This is a gameplay demand approximation, not a forecast model. Scarcity increases price and oversupply reduces it. Each unit in a batch uses its marginal stock level. Selling reverses the corresponding inventory step before the existing sale spread and player modifiers, avoiding a bulk-purchase/instant-resale price exploit. Exchange buttons show the entire quoted order cost, and execution recomputes it against current authoritative state.

Traders reserve an exact current purchase quote, buy only available and affordable quantities, and retain their cargo when the destination has no receiving space. They retry on later work cycles; normal wages still apply. Cancelled-route cargo sold through fleet services also enters market stock. Cash, escrow and cargo use exact transaction totals. New purchases retain their actual cost for later sale-margin calculations, as described below.

This adds a connected supply/transport/price loop. It does not add automatic replenishment, background consumption, input-conserving factories, shared multiplayer market authority or population demand. Initial inventory is an explicit seeded resource source. Raw station extraction/farming and mission/refueling services retain their abstract sources/sinks; selling their produced cargo into an exchange does affect its supply. A closed world does not refill stock. World inventories remain separate from carried visitor cargo.


## Supplied station manufacturing

Assigned engineers now manufacture alloys, medicine, electronics and luxuries from station inventory. Each alloy unit consumes two ore and one fuel; medicine consumes one food and one fuel; electronics consumes one alloy and one fuel; luxuries consume one electronic and one alloy. These are commodity recipes for gameplay, not chemically or thermodynamically balanced processes. Consumed fuel and processing losses are abstract sinks; waste handling, reactor load and industrial heat are not simulated yet.

The existing 900-second hosted work cycle produces at most the station level in units, further limited by every input and available output storage. Missing inputs produce no goods; a full output store consumes no inputs. Partial batches consume only their actual requirements. Engineers remain paid on work cycles while waiting for supplies. Existing stock, produced totals and work progress remain saved without a new schema. Older manufactured stock is retained, but subsequent work needs supplies.

Station Works shows its output, per-unit inputs and stored amounts. While docked at that owned station, commanders can transfer 1 or 10 input units from their hold through its cargo service. Collection requires the same destination-specific docking check and loads only the amount that fits the remaining hold. Transfers reject insufficient cargo, full storage, remote or other stations, flight and aboard-interior use; they never purchase or generate supplies automatically. Collected manufactured output can be sold into the finite exchange inventory, linking market supply, transport, production and resale. Hired supply routes can now deliver purchased inputs directly to owned stations (see below).

Ore, food and fuel output still represents primary extraction/farming with abstract environmental reserves. Industry type remains fixed by system address, and every owned station in that system shares the type. This is not a player commodity-crafting system: hired engineers operate the facility. Configurable industries, finite resource deposits, farm requirements and broader production chains remain future work.


## Recorded fleet purchase costs

Trade orders now optionally save `purchase_cost` in credits for their current cargo. New empty-hold routes start at zero; successful market purchases add the exact marginal batch total paid from escrow. Price changes, scarcity changes and save/load do not revalue this cost. A successful sale reports revenue minus that recorded cost as gross margin before wages and resets the current cargo basis to zero. Full destinations leave both cargo and its recorded cost intact.

Carried cargo with no acquisition history and older inbound saves use an unknown cost marker (`-1`). Their sale still transfers goods and settles the exact proceeds, but reports an unknown margin rather than fabricating historical prices. Reassigning retained cargo after cancelling a route also loses route-local acquisition history and marks the new combined cargo cost unknown. An older empty outbound route starts recording its next purchase normally.

The fleet menu shows current cargo purchase cost, and completed-sale notifications show the recorded gross margin or state that cost is unknown. Existing cumulative `earned` history is retained; old totals may include the former estimates, and unknown-basis sales do not add an invented margin. This is a current-cargo cost record, not a complete invoice archive, weighted multi-route ledger or net-profit report. Wages remain separate, and cash/escrow settlement is unchanged.


## Automated station supply

Fleet orders can assign a trader and ship to repeatedly buy a selected commodity at its starting system and deliver it to an owned station, including within the same system. Each pickup reserves commander credits up to the initial route budget, pays the actual marginal market price, and removes finite market stock. Normal crew wages also apply. Delivery transfers cargo into station storage without generating sale income or profit. Full storage keeps the entire shipment aboard until it fits. Cancellation refunds unused escrow and retains cargo.

Each leg takes at least 600 active simulation seconds. Nearby ships must also reach their endpoint within 15 metres at 5 m/s or less before the leg settles. Same-system supply ships retain position and velocity when switching between market pickup and the station freight approach. Saves preserve the station destination, cargo, invoice and local flight state, including after coordinate rebasing. Remote and inter-system travel remains a strategic approximation; loading is instantaneous.

Delivered inputs feed the existing factory recipes. Automatic selection of inputs, station output distribution, physical cargo handling and multiplayer economy authority remain unfinished. Routes do not increase their original purchase budget automatically when prices rise.


## Combat interrupts freight

A disabled local fleet ship transfers its carried goods into a recoverable freight cache at the combat address. The route retains no cargo or acquisition cost, so repairs cannot complete the lost delivery. The existing recovery service requires proximity and free hold space, supports partial recovery, and prevents collecting the same goods twice. A freight cache has no hull salvage payout: the fleet hull remains separately repairable. Goods remain removed from the origin market until someone returns them through an actual sale.

Cargo and its cache persist together. Invalid locations or a full recovery registry leave goods aboard and report the limitation instead of deleting inventory. Crew rescue, hull repair, stationary cache motion and remote combat remain approximations. This does not add remote trader ambushes, pirate looting or fleet insurance. Existing player wrecks retain their hull salvage and insurance behavior.


## Local NPC drive heat

Local ships start with a nominal 450 K drive loop and 40 square metres of radiator area. Commanded velocity changes use a nominal 40,000 kg ship mass and the same impulse-to-waste-heat approximation as the player: mass times velocity change divided by 5,000,000 gives an equivalent propellant amount, with 20 K of loop heating per unit. This is a thermal accounting model; NPC fuel inventory is not yet simulated.

Acceleration is capped at 30 m/s² below 500 K and reduces linearly toward zero at 700 K. Available thermal headroom also caps the applied impulse. Radiators cool toward the regulated 300 K baseline using the existing emission model and 2.5 MJ/K heat capacity. Coasting does not add propulsion heat. Collision impulses are not treated as engine work. Actual thermal emission determines sensor range, so repeated manoeuvres affect detection and eventual manoeuvrability. Exhaust intensity follows commanded thrust rather than speed.

Fleet drive temperatures are saved and restored independently of their route or flight snapshot. Older records start at 450 K. Temperature is frozen outside local simulation; generic regenerated NPCs start fresh. Detailed remote thermal simulation, NPC fuel, reactor and weapon heating, stellar heating and ship-specific mass/radiator layouts remain unfinished. These constants are gameplay tuning, not a measured spacecraft design.


## Local commissioned-family propulsion

Local Pathfinder and Merchant actors derive dry mass, thrust, cruise command speed and radiator area from their shared module blueprint. Each cargo unit adds 1,000 kg, matching player-ship mass accounting. The local drive applies thrust divided by loaded mass, the existing thermal derating and a 3 g acceleration cap; accumulated heat follows actual impulse. Approach speed uses available braking acceleration. Cargo changes refresh the existing actor as well as newly spawned actors. Distant fleet travel still uses the strategic voyage clock; hull damage/shields and weapons still need family-specific integration.


Local AI obstacle sweeps now extend to the greater of the existing two-second horizon and estimated braking distance plus 0.25 seconds of travel. A separate sweep follows current velocity, so a clear requested turn cannot hide an imminent collision along the inertial path. This remains local heuristic steering with conservative hull bounds, not a global route planner or a guarantee under changing thrust/obstacles.

## Resource-backed field repairs

Passive engineer payroll no longer generates free hull points. An explicit, saved Enterprise policy permits paid, unassigned engineers to consume cargo alloys: at most one unit per engineer per day, up to eight hull points per unit, bounded by missing hull and available stock. A partial final repair consumes a whole unit. Full or destroyed hulls, unpaid crews and assigned engineers do not consume supplies. This is a daily material/labour approximation, not localized damage, animated repair work or component replacement. The policy defaults off, including older saves, so trade cargo is not silently allocated to maintenance.

## Fleet propellant

Materialized owned fleet actors use the player propulsion impulse conversion (5,000,000 N s per fuel unit), with actual dry plus cargo mass. A propulsion callback debits the authoritative vessel record and limits velocity change to available fuel; heating uses the resulting impulse. Empty ships coast rather than receiving free braking. Saves and refuelling use the same record, avoiding actor/record tank divergence. Unowned NPC fuel inventories remain unmodelled.

At remote order events, intersystem transfers cost 10 units for hyperdrive, matching player jumps. That jump cost also applies after represented local departure/berth flight; it is separate from thruster propellant. Remote same-system patrol/trade legs cost two units as a gameplay approximation; materialized same-system legs pay only actual thrust. Insufficient reserves pause before wages and market mutations. Failed stock/storage attempts do not debit travel fuel. Paid fleet fuel service consumes finite market stock at the vessel's system; delivery vehicles and arrival delay remain abstract.


### Patrol flight persistence

Materialized owned patrol ships retain position, velocity, patrol center and course clock in local saves. The center is stored in system coordinates independently of the vessel position, including when a distant actor is culled or the player changes the floating origin. Restoring an empty tank preserves coasting momentum. Cancelling or replacing an order discards its saved flight; changing patrol systems discards the previous system's flight.

Remote patrols still use strategic encounter events. Saved local flight is the last materialized state, not a continuously integrated remote trajectory. Patrol course persistence does not preserve a combat target, contact-search timer or weapon cooldown.


### Partial fleet fuel deliveries

Fleet services can sell a single commodity unit (10 tank fuel) as well as filling the tank. A full refill may be unavailable while a small delivery remains affordable and in stock. The domain operation accepts up to ten commodity units and caps the purchase at the remaining tank capacity; credits and market inventory are charged only for units supplied. The command menu exposes a ten-fuel delivery when more than one unit is needed. Delivery travel remains abstract.


### Crew fuel allowances

Each registered vessel can have an optional remaining fuel allowance from zero to 1,000,000 credits. Zero disables automatic purchases; changing the cap does not reserve treasury funds. A living ship with an assigned crew order buys one commodity unit (10 fuel) when its tank falls below ten, provided local stock, the remaining allowance and treasury permit it. The crew preserves enough money for its own next wage. Each successful purchase deducts its actual local-market cost from both treasury and allowance.

Hosted crew ticks check before local arrival gates and at remote order boundaries, allowing a stranded local trader to buy fuel before reaching its departure point. Idle vessels and closed worlds do not buy fuel. Manual deliveries remain available and do not consume the automatic spending allowance. This is abstract service delivery, not a tanker simulation; allowances are not a shared treasury reservation or guarantee that every crew member will be paid.


### Powered-system heat

Materialized ships now feed waste heat from powered non-engine systems into the same regulated radiator loop used by propulsion. The gameplay conversion is 1,500 W per supplied non-engine power rating, bounded by available generation. Power ratings are abstract capacities: this is a tunable heat-source approximation, not a reactor efficiency or electrical load simulation. Engine impulse heat remains separately tied to actual propellant use.

Player and family NPC vessels derive the source from their module stats; legacy generic NPC ships use a 6 kW default. A shared bounded step applies source heat minus radiation above the 300 K regulated baseline to the 2.5 MJ/K loop, constrained to 300–700 K. More exposed radiator area rejects more heat. Temperature already feeds thrust derating and emitted-power detection, so powered idle vessels no longer cool all the way to the regulated floor. This does not consume engine propellant or integrate remote crew-vessel temperature; separate reactor fuel, power switching and thermal damage remain unfinished.


### Main systems shutdown

Flight Settings can shut down or restart the commander's main ship systems. Shutdown stops powered-system waste heat, thrust (including braking/autopilot corrections), ship weapons, crew-operated defensive weapons, hyperdrive and shield recharge. Momentum and temperature remain intact; the existing radiator loop continues cooling toward its regulated baseline. Residual shield charge remains available, and suit weapons, walking, menus and emergency controls remain independent. Switching during hyperdrive charging or while inspecting a different fleet interior is rejected.

The mode persists in local saves and carried-ship copies; legacy saves default online. Taking command of another vessel at a service berth starts that replacement's systems. There is no startup timer, electrical bus simulation, per-room lighting shutdown or independently configurable remote-fleet power policy. Stored heat still contributes to detection, so shutdown is not instant invisibility. Multiplayer carries the reported power mode over a reliable, sender-checked stream. The host rejects ship shots from reported-offline attackers while leaving consenting offline targets vulnerable. Movement snapshots cannot overwrite this mode; reconnect and travel resynchronize it. The peer list exposes the mode. This is not authoritative electrical simulation or protection against clients falsely reporting their power state; live Steam interoperability remains unverified.


### Local stellar exposure

Materialized player and NPC ships absorb direct stellar heat into the existing 300–700 K thermal loop. Exposure persists with main power off, increases emitted thermal visibility and can derate propulsion. Moving away or entering a planet's point-source shadow reduces the heat input. Projected hull bounding-box area and orientation determine absorption at a fixed 0.35 absorptivity; this conservatively fills hull cavities and does not resolve individual materials or radiator orientation.

The compact playable map is not the SI orbital catalog. Its local exposure mapping assigns 4,500 local metres to `sqrt(L/Lsun)` AU, floored at eight catalog stellar radii. Inverse-square flux uses that mapped distance, a 250-local-metre proximity floor and a physical stellar-radius floor. Consequently local station-region flux is broadly comparable across luminous star types; this is explicit gameplay distance compression, not correct angular stellar size or full-scale flight. Planet spheres produce hard eclipses, without penumbrae or atmospheric scattering. A nonluminous black hole has no direct stellar source; accretion/jet heating is unfinished.

Moving-cabin exposure follows the hull rather than the walking passenger. Manually landed ships and owned outdoor docks sample their displayed hull; public-hangar and legacy surface-transition parking remain sheltered abstractions. Culled distant systems and abstract remote fleet orders do not integrate this local field. Local fleet temperatures use the existing persistence path. Thermal damage, stellar surface collision, material-dependent absorption and exposure replicated for remote visitors remain unfinished.
