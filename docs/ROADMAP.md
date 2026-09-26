# NeXt: Roadmap

## Current prototype

The prototype provides solo first-person movement and shooting, a small station and ship, practice and stationary pirate targets, deterministic system data, basic commodity trading, cargo refits, repairs, hyperdrive address changes, and local save/load. Graphics use code-built primitives. Black holes are generic colored spheres. There is no NPC combat AI, stock market, ship or station construction, multiplayer, Steam integration, or final authored art.

## 1. Strengthen the playable slice

- Improve walking and flight handling, interaction, onboarding, and combat feedback.
- Replace stationary target behavior with understandable pirate and police behavior.
- Expand the station into a useful hub while keeping scope small.
- Version local saves and test recovery and migration before changing save data.

## 2. Build the single-player simulation

- Add explorable stations, planetary surfaces, atmospheres, and cities.
- Give star types, nebulae, and black holes distinct environments and gameplay.
- Add factions, pirate and police behavior, trading companies, and stock markets.
- Add NPC hires and ship and station customization from craftable components.
- Keep galaxy generation deterministic and test stable results for saved addresses.

## 3. Prepare a Windows release

- Keep reproducible Windows exports and packaged-build checks in CI.
- Add Steamworks only when a real Steamworks application ID and integration are configured.
- Verify Steam features in packaged builds before claiming support.

## 4. Add multiplayer safely

- Establish an authoritative host for gameplay and economy state.
- Add Steam friend sessions and hyperdrive travel with friends.
- Prevent duplicated ships, items, and currency during reconnects, transfers, and host changes.
- Define ownership, transfer, and recovery rules before enabling persistent cross-session transfers.

## 5. Evaluate Linux and VR

- Test the Windows build under Proton before claiming Linux support.
- Consider a native Linux build if it is practical to maintain.
- Evaluate VR after desktop movement, interaction, performance, and comfort options are stable.

## Release gates

Do not claim Steam integration, multiplayer authority, anti-duplication, safe transfers, or save migration until their failure and reconnect cases are tested. Do not claim Proton or VR support from editor-only checks.
