# Spatial location and streaming integration

`SectorPosition` stores a world address as signed 32-bit sector coordinates and
a `Vector3` offset in the half-open range `[-4096, 4096)` on each axis. A sector
is 8192 metres wide. Movement normalizes the local offset in one operation, so
crossing many sectors never constructs a large floating-point world coordinate.
`relative_to` also rejects requested radii above 1,000,000 metres.
The address is deterministic and serializes as a versioned dictionary of integer
sector coordinates and finite local coordinates.

## Integration plan

1. Keep `SectorPosition` as authoritative travel/save state. Convert the current
   system origin and ship/pilot offset into a `SectorPosition` at a system
   boundary; do not derive authority from `Node3D.global_position`.
2. Select a local origin near the player. For each streamed body's address,
   call `relative_to(origin, draw_distance)`. It returns a `Vector3` only when
   that body is inside the requested radius; a distant address never becomes a
   huge draw coordinate.
3. When the player leaves the local safety radius, choose a nearby origin and
   shift active local `Node3D` positions by the inverse origin movement in one
   frame. Recompute local positions from authoritative addresses after rebase,
   including physics bodies and cached target positions. Keep velocities,
   orientations, and sector addresses unchanged.
4. Stream cells around the current address using integer sector coordinates as
   stable cell keys. Seed procedural content from a stable hash of the sector
   address plus a generator version; iteration order must not affect results.
5. Persist addresses with `to_save()` and validate with `from_save()` before
   accepting state. Keep a system/planet-local frame identifier alongside the
   address when a location belongs to a moving or rotating body.

This adds an address representation and bounded conversion primitive. It does
not implement origin rebasing, cell streaming, moving reference frames, or
seamless planetary travel. Current `SpaceWorld` geometry and pilot movement still
use local `Vector3` coordinates; replace any 28 km travel clamp only after the
world-origin owner and physics/render rebase path are integrated together.
