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

Start in the orbital concourse. The ship is on the central pad. Approach it, press E, and launch. Use the command deck for navigation, trade, contracts, construction, hiring and company management. Crew salaries and production settle on simulation-day advances from interstellar travel. Cruise autopilot handles local approaches and cancels when you take manual control.

## Implemented systems

- Assisted first-person walking and ship flight, acceleration, boost, local cruise autopilot, cockpit and held weapon.
- Moving pirate/security ships, ground NPCs, patrol/pursuit/retreat behavior, physics-ray combat, shielding, hull damage and bounties. Destroyed actor IDs persist by location.
- One billion deterministic system addresses, procedural celestial visuals, station geometry, planet surfaces and colony districts. The generator creates data on demand rather than allocating a billion scenes.
- Connected grid-based ship assembly with live 3D preview, power/attachment/cargo checks, calculated mass, speed, weapons, shields and crew capacity.
- Walkable ship rooms derived from the installed modules when a habitat and sufficient connected hull exist. Rooms have collision, equipment, connecting doors and a deck selector. Grid-selected refits change compatible room fittings and exposed standard/armored/window panels. Room footprints and corridor placement are still derived from the module grid; panel refits currently change appearance rather than combat statistics.
- Commodity buy/sell, cargo capacity, fuel, repairs, delivery/exploration/bounty contracts, shares, hiring/dismissal, company treasury/dividends and station construction/upgrades.
- Player-founded factions with treasuries, paid affiliation of owned stations and diplomatic stances. Friendly/hostile relations affect personal commodity quotes and police hostility; criminal wanted status remains separate.
- Owned outposts have collision-supported docking decks: use Station works to approach, slow below 35 m/s within 65 m and press E to dock. Walk the deck, use Tab for services, and press E near your ship to depart.
- Named crew with persistent orders: trader captains operate escrow-funded routes on purchased fleet vessels, gunners patrol with wages, bounties and hull risk, and engineers manage owned-station stock production. Fleet cargo, ship condition, work progress and assignments survive saves. Cancelled routes retain cargo; idle cargo can be sold and station output collected through services.
- Fleet work advances only while its world profile is active. These are strategic, timed orders with simulated encounters; individual fleet ships do not yet physically fly through local combat scenes. Assigned personnel do not also grant passive aboard-ship bonuses.
- Insurance, meaningful deductibles and recovery debt, persistent cargo wrecks, proximity-limited partial cargo recovery and single-use hull salvage. Medical rescue preserves the docked ship. Salvage settles debt first; insured salvage cannot exceed the claim deductible.
- Versioned validated local saves, legacy migration, persistent world identities and separate visitor economy profiles. Your home finances are preserved when returning with your ship and cargo.
- Experimental ENet world visits: validated ship exchange, player presence/pose synchronization and host-controlled interstellar travel. [Multiplayer details and limits](docs/MULTIPLAYER.md).

## Boundaries that still matter

The complete target is substantially larger than the implemented systems above:

- Planet landing currently changes to a generated surface scene. Continuous planet-scale terrain streaming and seamless surface/orbit travel are **not implemented**.
- Steam lobby adapter code and lifecycle tests are present, but native Steam build configuration and a production AppID are still required. Real invites/relay, shared authoritative combat/economy, property permissions, consensual PvP and durable transfer transactions are **not verified or complete**. ENet visits are an explicitly limited development feature, not finished Steam co-op.
- Freeform hull shaping, movable interior walls/furniture, locally simulated autonomous fleet combat and territorial sovereignty/negotiated diplomacy remain unimplemented. Current room and panel refits are bounded grid choices.
- Cities are generated colony districts; they are not complete populated urban simulations. Ship interiors currently pause local threats after requiring a safe flight zone. They do not simulate unattended ships under attack.
- A system uses compact local coordinates and a 28 km safety boundary. Celestial sizes are presentation scale. This is not a physically scaled or fully streamed galaxy.
- Menus pause local AI in solo play. Combat/economy state is currently simulated independently during network visits. Saving resumes at the saved system's orbital station, not the exact player position.
- Current crew, police and company systems provide defined gameplay rules, not unrestricted human behavior. There is no claim that "everything" is implemented.

## Development checks

```sh
godot --headless --path . --editor --quit
godot --headless --path . -s tests/test_universe.gd
godot --headless --path . -s tests/test_state.gd
godot --headless --path . -s tests/test_actors.gd
godot --headless --path . -s tests/test_network.gd
godot --headless --path . -s tests/test_visit.gd -- --capture-only
godot --headless --path . -s tests/test_controls.gd -- --capture-only
godot --headless --path . -s tests/test_steam_session.gd
godot --headless --path . -s tests/test_faction.gd
godot --headless --path . -s tests/test_station_gameplay.gd -- --capture-only
godot --headless --path . -s tests/test_crew.gd
godot --headless --path . -s tests/test_recovery.gd
godot --headless --path . -s tests/test_ship_layout.gd
godot --headless --path . -s tests/test_sector_position.gd
godot --headless --path . -s tests/test_operations_gameplay.gd -- --capture-only
godot --headless --path . -- --smoke
godot --headless --path . --export-release "Windows Desktop" build/windows/NeXt.exe
```

Smoke checks use isolated disposable saves. Graphical `--visual-tour` additionally captures command, hangar, flight, shipyard, colony and interior frames in `build/` (or `user://` in exports). Visual tests run inside a hidden gamescope instance during Linux development. A passing headless check is not a graphics or performance verdict. Exporting requires matching Godot templates; see [Godot's command-line documentation](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html).

Saves normally live at `%APPDATA%/Godot/app_userdata/NeXt/` on Windows. `commander.json` is the home world; `visits/<world-id>.json` stores foreign-world finances. Steam Cloud is not configured.

## Code and art ownership

`GameState` owns validated simulation and persistence. `SpaceWorld` generates environments. `Pilot`, `ShipActor` and `GroundActor` control movement/combat. `ShipVisual` and `ShipInterior` render ships. `NetworkSession` handles the current visit transport. `scripts/ui/` provides the command deck, map, construction editor and HUD. `main.gd` joins the systems.

No generated bitmap artwork is used. Procedural meshes, shaders and synthesized audio are placeholders implemented in code. Final authored replacements should preserve units, collision boundaries, pivots and functional attachment points.
