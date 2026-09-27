# Spatial location and streaming integration

`SectorPosition` stores a world address as signed 32-bit sector coordinates and
a `Vector3` offset in the half-open range `[-4096, 4096)` on each axis. A sector
is 8192 metres wide. Movement normalizes the local offset in one operation, so
crossing many sectors never constructs a large floating-point world coordinate.
`relative_to` also rejects requested radii above 1,000,000 metres.
The address is deterministic and serializes as a versioned dictionary of integer
sector coordinates and finite local coordinates.

## Current integration

Orbital flight uses `main.flight_origin` plus the pilot's bounded local position.
Crossing an 8192-metre sector rebases registered scene roots, the pilot, cruise
waypoints and AI patrol/safety references together without resetting velocity.
`FlightFrame` freezes and hides roots beyond 60 km, disables their collision
layers, and restores their recorded addresses, visibility and collision settings
when the player returns. WorldEnvironment remains in the tree. Remote ship poses
carry validated absolute sector addresses and are rendered relative to the local
origin only within 30 km.

Cruise destinations retain absolute addresses across rebases. Long approaches
use bounded forward waypoints until their target enters the local range. Orbital
saves persist location and helm orientation (also when saving from the interior),
and resume at rest. Manual planetary ground saves retain the player address, radial
heading and a separate parked ship address. Legacy colony/dock saves use the orbital spawn. New wrecks store
absolute addresses; older system-local wreck records remain recoverable after a
rebase. Surface and interstellar transitions reset the local frame deliberately.

## Remaining work

The former 28 km flight snap-back is removed. Nearby spherical planets now generate
a curved collision patch that follows surface walking, with radial gravity and
atmosphere fog blending during approach. Landing and liftoff stay in the orbital
scene. This does not increase physical planet sizes or connect colony scenes.
Content remains the existing compact system;
there is no generated content in newly crossed empty sectors. Celestial LODs,
planet-scale terrain LOD, moving reference frames and physically based atmosphere
entry are still required. Local actors freeze when culled; distant fleet patrols
continue through the existing strategic simulation. Stationary scene roots can
contain children offset from their root, so the current 60 km culling radius is
chosen beyond the camera's 30 km draw distance and current content bounds.
