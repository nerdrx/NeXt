# NeXt

A first-person space-age sandbox built in Godot. Explore, trade, fight, build ships and stations, and establish a life in a human galaxy.

**Active development.** This is a working development build, not a finished AAA game. The agreed visual target is Star Citizen's believable ships and inhabited spaces combined with Elite Dangerous's cosmic scale. Current assets are replaceable procedural placeholders, and do not meet the final near-photoreal target.

## Agreed direction

Windows is the shipping target; Linux play uses Proton. The performance target is a high-end PC at 1440p/60 FPS. Travel should eventually be seamless and manual, with optional autopilot. Worlds pause when nobody hosts. Friends bring their ship and cargo while keeping world economies separate. The initial session target is 2–8 people, with owner permissions and consensual PvP. Only ships and stations are craftable. No hunger or thirst chores.

The [design decisions and questionnaire](docs/DESIGN_QUESTIONS.md) records the owner's answers. The [art direction](docs/ART_DIRECTION.md) and [asset checklist](docs/ASSET_CHECKLIST.md) define what the placeholders must become.

## Running

Open `project.godot` in **Godot 4.7.2** and press F5 (Run Project). On a Linux development machine with Steam Godot installed, `./run-next.sh` starts the project and `./run-next.sh --editor` opens its editor. Do not launch component `.gd` files with `--script`: files such as `network_session.gd` extend Node and need the main scene. Windows build artifacts are available from successful GitHub Actions runs. Extract the entire archive and keep the executable with its `.pck` file. On Linux, add the Windows executable to Steam and select Proton. The project uses Forward+ and Vulkan; `--rendering-method gl_compatibility` is an optional fallback with reduced lighting features.

| Control | Action |
| --- | --- |
| WASD / mouse | Move / look |
| Shift | Sprint or flight boost |
| Space / Ctrl | Jump or vertical flight |
| Q / R | Roll left / right |
| E | Talk to nearby officer, board near ship, or dock near station |
| Left click | Fire |
| Tab / Escape | Command deck / return to world |
| J | Navigation |
| F5 / F9 | Save / load |
| Page Up / Page Down | Change decks while inside your ship |

Start in the orbital concourse. The ship is on the central pad. Approach it, press E, and launch. Use the command deck for navigation, trade, contracts, construction, hiring and company management. The calendar advances one day per 20 minutes of active world time, including menus; hyperdrive also advances one day. Daily salaries and company income follow this calendar, while assigned crew retain their operation timers. Closed worlds do not advance. Cruise autopilot handles local approaches, stops when its body sweep detects an obstruction, and cancels when you take manual control. Flight collision follows the occupied 2.8 m ship module cells. Fast collisions damage shields and hull; fatal impacts leave a recoverable wreck and trigger rescue. Planetary approaches account for hull size, and ships too wide for a surface port must use open ground. Planet orbit and ground elevation share a seeded height map; surface approaches seek clear dry ground and manual landing rejects submerged or rock-obstructed sites. Seeded boulders retain their positions across terrain patches, with collision on larger rocks.

The ship architect supports cell coordinates from −16 to +16 on all axes, with a 100-module limit. Pan the grid or enter X, Z and deck coordinates; install/remove controls sit beneath the live preview. Assembly edits update ship statistics immediately.

## Implemented systems

- Assisted first-person walking and ship flight, acceleration, boost, local cruise autopilot, cockpit and held weapon.
- Moving pirate/security ships, ground NPCs, patrol/pursuit/retreat behavior, physics-ray combat, shielding, hull damage and bounties. Destroyed actor IDs persist by location.
- Floating-origin orbital flight keeps the player near zero across sector boundaries; distant local geometry/physics is culled and restored on return. Orbital flight addresses and helm orientation survive saves; wrecks and peer positions use sector addresses.
- One billion deterministic system addresses, procedural celestial visuals, station geometry, planet surfaces and colony districts. The generator creates data on demand rather than allocating a billion scenes.
- Connected grid-based ship assembly with live 3D preview, power/attachment/cargo checks, calculated mass, speed, weapons, shields and crew capacity.
- Walkable ship rooms derived from the installed modules when a habitat and sufficient connected hull exist. Rooms have collision, equipment, connecting doors and a deck selector. Grid-selected refits change compatible room fittings and exposed standard/armored/window panels. Room footprints and corridor placement are still derived from the module grid; panel refits currently change appearance rather than combat statistics.
- Commodity buy/sell, cargo capacity, fuel, repairs, delivery/exploration/bounty contracts, shares, hiring/dismissal, company treasury/dividends and station construction/upgrades.
- Player-founded factions with treasuries, paid affiliation of owned stations and diplomatic stances. Friendly/hostile relations affect personal commodity quotes and police hostility; criminal wanted status remains separate.
- Owned outposts have collision-supported docking decks: use Station works to approach, slow below 35 m/s within 65 m and press E to dock. Walk through the covered bridge into 3–8 service rooms, press E at a room terminal (or Tab for the command deck), and return to your ship to depart. Station walking positions and docked ships resume after loading.
- Named crew with persistent orders: trader captains operate escrow-funded routes on purchased fleet vessels, gunners fly local patrol ships that engage pirates with weapon rays and persistent hull damage (distant patrols use strategic encounter simulation), and engineers manage owned-station stock production. Fleet cargo, ship condition, work progress and assignments survive saves. Cancelled routes retain cargo; idle cargo can be sold and station output collected through services.
- Fleet work advances only while its world profile is active. Trade routes use timed orders. Local patrol ships physically fight pirates; distant patrols use strategic encounters. Assigned personnel do not also grant passive aboard-ship bonuses.
- Insurance, meaningful deductibles and recovery debt, persistent cargo wrecks, proximity-limited partial cargo recovery and single-use hull salvage. Medical rescue preserves the docked ship. Salvage settles debt first; insured salvage cannot exceed the claim deductible.
- Versioned validated local saves, legacy migration, persistent world identities and separate visitor economy profiles. Your home finances are preserved when returning with your ship and cargo.
- Experimental ENet world visits: validated ship exchange, player presence/pose synchronization, host-controlled interstellar travel and mutually opted-in ship combat. Enable PvP in Settings; both pilots must opt in and be flying. Consent resets on system travel or leaving. [Multiplayer details and limits](docs/MULTIPLAYER.md).

## Boundaries that still matter

The complete target is substantially larger than the implemented systems above:

- Manual landing on the existing small spherical planets now stays in the orbital scene: approach the surface, slow below 20 m/s, press E within 35 m, walk with radial gravity, and return to the ship to lift off. Navigation offers a surface approach autopilot. Ground saves preserve your walking position and parked ship separately. Cruise autopilot plans deterministic detours around planetary spheres, follows sector-addressed waypoints and returns control on manual input. It does not yet avoid buildings, ships or other traffic. Navigation now also offers colony approach to compact procedural surface ports in the same scene, with physical streets, ramps, a service terminal and docking. The older colony scene remains in code for compatibility; realistic planet-scale streaming, extensive cities, civilian schedules and manual hangar flight remain unfinished. Four port ground floors can now be entered directly to access trade, crew, ship services and contracts; upper floors remain closed. Each port has four named clerks and two security officers. Clerks remain at their posts, local guards respond to wanted status/diplomacy and follow baked routes through rooms, and casualties persist; distant staff simulation sleeps.
- Steam lobby adapter code and lifecycle tests are present, but native Steam build configuration and a production AppID are still required. Real invites/relay, shared authoritative combat/economy, property permissions and durable transfer transactions are **not verified or complete**. Mutually opted-in flight PvP now passes ENet loopback checks; it is not yet verified over live Steam. ENet visits are an explicitly limited development feature, not finished Steam co-op.
- Freeform hull shaping, movable interior walls/furniture, physical trade routes, fleet wreck salvage and territorial sovereignty/negotiated diplomacy remain unimplemented. Current room and panel refits are bounded grid choices.
- Cities are generated colony districts; they are not complete populated urban simulations. Ship interiors currently pause local threats after requiring a safe flight zone. They do not simulate unattended ships under attack.
- Orbital flight rebases across sectors without the former 28 km snap-back. Existing celestial bodies remain compact and presentation-scale; newly crossed space has no generated content yet. This is not a physically scaled or fully streamed galaxy.
- Local patrol positions reset when rebuilding a system; hull damage and orders persist. Disabled fleet ships are service-repaired, not yet salvageable wrecks.
- Menus pause local AI in solo play. NPC combat and economies remain independent during visits. Opted-in ship hits are host-validated, while target health and rescue remain local. Orbital flight saves resume their sector location at rest; manual planet/port saves preserve ground positions, while legacy colony saves resume at the station.
- Current crew, police and company systems provide defined gameplay rules, not unrestricted human behavior. There is no claim that "everything" is implemented.

## Development checks

```sh
godot --headless --path . --editor --quit
godot --headless --path . -s tests/test_universe.gd
godot --headless --path . -s tests/test_state.gd
godot --headless --path . -s tests/test_calendar.gd
godot --headless --path . -s tests/test_calendar_gameplay.gd -- --capture-only
godot --headless --path . -s tests/test_actors.gd
godot --headless --path . -s tests/test_network.gd
godot --headless --path . -s tests/test_visit.gd -- --capture-only
godot --headless --path . -s tests/test_controls.gd -- --capture-only
godot --headless --path . -s tests/test_steam_session.gd
godot --headless --path . -s tests/test_faction.gd
godot --headless --path . -s tests/test_station_gameplay.gd -- --capture-only
godot --headless --path . -s tests/test_station_interior.gd -- --capture-only
godot --headless --path . -s tests/test_fleet_gameplay.gd -- --capture-only
godot --headless --path . -s tests/test_crew.gd
godot --headless --path . -s tests/test_recovery.gd
godot --headless --path . -s tests/test_ship_layout.gd
godot --headless --path . -s tests/test_sector_position.gd
godot --headless --path . -s tests/test_flight_frame.gd
godot --headless --path . -s tests/test_spatial_gameplay.gd -- --capture-only
godot --headless --path . -s tests/test_operations_gameplay.gd -- --capture-only
godot --headless --path . -- --smoke
godot --headless --path . --export-release "Windows Desktop" build/windows/NeXt.exe
```

Smoke checks use isolated disposable saves. Graphical `--visual-tour` additionally captures command, hangar, flight, shipyard, colony and interior frames in `build/` (or `user://` in exports). Visual tests run inside a hidden gamescope instance during Linux development. A passing headless check is not a graphics or performance verdict. Exporting requires matching Godot templates; see [Godot's command-line documentation](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html).

Saves normally live at `%APPDATA%/Godot/app_userdata/NeXt/` on Windows. `commander.json` is the home world; `visits/<world-id>.json` stores foreign-world finances. Steam Cloud is not configured.

## Code and art ownership

`GameState` owns validated simulation and persistence. `SpaceWorld` generates environments. `Pilot`, `ShipActor` and `GroundActor` control movement/combat. `ShipVisual` and `ShipInterior` render ships. `NetworkSession` handles the current visit transport. `scripts/ui/` provides the command deck, map, construction editor and HUD. `main.gd` joins the systems.

No generated bitmap artwork is used. Procedural meshes, shaders and synthesized audio are placeholders implemented in code. Final authored replacements should preserve units, collision boundaries, pivots and functional attachment points.
