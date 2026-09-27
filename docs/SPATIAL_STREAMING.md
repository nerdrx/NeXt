# Spatial location and streaming integration

`SectorPosition` stores hierarchical region and sector coordinates as signed 32-bit
integers, plus a `Vector3` local offset in `[-4096, 4096)` on each axis. A sector is
8192 metres wide. A region contains 2^30 sectors per axis; canonical within-region
sector coordinates lie in `[-2^29, 2^29)`. This extends the addressable range to
roughly two million light-years in either direction per axis while retaining
small local coordinates. This is address capacity, not generated content or
rendering distance.

Movement normalizes transactionally across sector and region boundaries.
`relative_to` rejects distant regions before constructing a floating-point vector,
and rejects requested radii above 1,000,000 metres. `clone` and `sector_origin`
retain the region when handing locations between flight, interiors, saves and
network endpoints. `direction_to` provides approximate remote guidance without
constructing an astronomical physics position.

Version-2 address dictionaries include region, sector and local arrays. Existing
version-1 sector-only saves are accepted and normalized without moving their
locations. New writes use version 2; older game binaries cannot read that format,
so multiplayer peers should use the same current build. Raw JSON integral floats
are validated before conversion, including the version field.

`from_meters` splits scalar-double astronomical coordinates before creating the
bounded `Vector3` residual. Its precision is limited by the incoming double at
large distances; use integer region/sector coordinates plus local offsets for
fine motion in remote regions. Celestial catalog samples now expose this shared
address alongside their orbital-plane coordinates. Their plane is mapped to XZ;
three-dimensional orbital orientation and moving body frames are still required.

## Current integration

Orbital flight uses `main.flight_origin` plus the pilot's bounded local position.
Crossing an 8192-metre sector rebases registered scene roots, the pilot, cruise
waypoints and AI patrol/safety references together without resetting velocity.
`FlightFrame` freezes and hides roots beyond 60 km, disables their collision
layers, and restores their recorded addresses, visibility and collision settings
when the player returns. WorldEnvironment remains in the tree. Remote ship poses
carry validated absolute sector addresses and are rendered relative to the local
origin only within 30 km.

Cruise destinations and planned waypoints retain absolute addresses across rebases.
A bounded spherical route planner inserts radial/arc detours around planets, rejects
below-clearance destinations and reports failure when a safe bounded route cannot
be found. Arrival advances the waypoint queue; manual input discards it. This
planner does not model ships, buildings or station geometry. Long approaches
use bounded forward waypoints until their target enters the local range. Orbital
saves persist location and helm orientation (also when saving from the interior),
and retain saved flight velocity; older saves without velocity resume at rest. Manual planetary ground saves retain the player address, radial
heading and a separate parked ship address. Legacy colony/dock saves use the orbital spawn. New wrecks store
absolute addresses; older system-local wreck records remain recoverable after a
rebase. Surface and interstellar transitions reset the local frame deliberately.

## Remaining work

The former 28 km flight snap-back is removed. Nearby spherical planets now generate
a curved collision patch that follows surface walking, with radial gravity and
atmosphere fog blending during approach. Landing and liftoff stay in the orbital
scene. Compact industrial ports now share that orbital scene and can be approached, docked at and explored on foot. This does not increase physical planet sizes; the old larger colony scene remains a legacy path.
Content remains the existing compact system;
there is no generated content in newly crossed empty sectors. Celestial LODs,
planet-scale terrain LOD, moving reference frames and physically based atmosphere
entry are still required. Local actors freeze when culled; distant fleet patrols
continue through the existing strategic simulation. Stationary scene roots can
contain children offset from their root, so the current 60 km culling radius is
chosen beyond the camera's 30 km draw distance and current content bounds.
