class_name CelestialFrame
extends RefCounted

# Celestial positions stay as scalar doubles until they are split into a
# SectorPosition. Orbital basis: local XY -> Godot XZ, then +Y periapsis,
# +X inclination, and +Y ascending-node rotations (right-handed).
static func oriented_orbit(orbit: Dictionary, inclination: float, node: float, periapsis: float) -> Dictionary:
	if not _finite(inclination) or not _finite(node) or not _finite(periapsis): return {}
	var values: Array = []
	for key: String in ["x_m", "y_m", "vx_mps", "vy_mps"]:
		var value: Variant = orbit.get(key)
		if not _number(value): return {}
		values.append(float(value))
	var position := _rotate_orbit(values[0], values[1], inclination, node, periapsis)
	var velocity := _rotate_orbit(values[2], values[3], inclination, node, periapsis)
	if not _finite(position[0]) or not _finite(position[1]) or not _finite(position[2]) or not _finite(velocity[0]) or not _finite(velocity[1]) or not _finite(velocity[2]): return {}
	return {"position_m": position, "velocity_mps": velocity}


static func surface_state(sample: Dictionary, body: Dictionary, local_point: Vector3, elapsed_seconds: float) -> Dictionary:
	# elapsed_seconds is physical ephemeris time, independent of game-time scaling.
	if not local_point.is_finite() or not _finite(elapsed_seconds): return {}
	var position: Variant = _vector_array(sample.get("position_m"))
	var velocity: Variant = _vector_array(sample.get("velocity_mps"))
	if position == null or velocity == null: return {}
	var period: Variant = body.get("rotation_seconds")
	var phase: Variant = body.get("spin_phase_at_epoch", 0.0)
	if not _number(period) or not _number(phase) or float(period) <= 0.0: return {}
	var inclination: Variant = body.get("inclination_rad", 0.0)
	var node: Variant = body.get("ascending_node_rad", 0.0)
	var tilt: Variant = body.get("axial_tilt_rad", 0.0)
	if not _number(inclination) or not _number(node) or not _number(tilt): return {}
	# Orbital XY maps to XZ, whose prograde angular momentum points along -Y.
	var spin: float = fposmod(fposmod(float(phase), TAU) - TAU * fposmod(elapsed_seconds, float(period)) / float(period), TAU)
	var tilt_in_orbit: float = float(inclination) + float(tilt)
	if not _finite(spin) or not _finite(tilt_in_orbit): return {}
	var orientation := Basis(Vector3.UP, float(node)) * Basis(Vector3.RIGHT, tilt_in_orbit) * Basis(Vector3.UP, spin)
	var rotated: Array[float] = _surface_offset(local_point.x, local_point.y, local_point.z, spin, tilt_in_orbit, float(node))
	var offset: Array[float] = [rotated[0], rotated[1], rotated[2]]
	var omega: float = -TAU / float(period)
	if not _finite(omega): return {}
	var omega_x: float = sin(float(node)) * sin(tilt_in_orbit) * omega
	var omega_y: float = cos(tilt_in_orbit) * omega
	var omega_z: float = cos(float(node)) * sin(tilt_in_orbit) * omega
	var spin_velocity: Array[float] = [omega_y * offset[2] - omega_z * offset[1], omega_z * offset[0] - omega_x * offset[2], omega_x * offset[1] - omega_y * offset[0]]
	var world_velocity: Array[float] = [velocity[0] + spin_velocity[0], velocity[1] + spin_velocity[1], velocity[2] + spin_velocity[2]]
	for component: float in offset + spin_velocity + world_velocity:
		if not _finite(component): return {}
	var world_position: Array[float] = [position[0] + offset[0], position[1] + offset[1], position[2] + offset[2]]
	for component: float in world_position:
		if not _finite(component): return {}
	var address: SectorPosition = SectorPosition.from_meters(world_position[0], world_position[1], world_position[2])
	if address == null: return {}
	return {"address": address.to_save(), "position_m": world_position, "velocity_mps": world_velocity, "orientation": orientation}


static func _rotate_orbit(x: float, y: float, inclination: float, node: float, periapsis: float) -> Array[float]:
	var px: float = x * cos(periapsis) + y * sin(periapsis)
	var pz: float = -x * sin(periapsis) + y * cos(periapsis)
	var iy: float = -pz * sin(inclination)
	var iz: float = pz * cos(inclination)
	var nx: float = px * cos(node) + iz * sin(node)
	var nz: float = -px * sin(node) + iz * cos(node)
	return [nx, iy, nz]


static func _surface_offset(x: float, y: float, z: float, spin: float, tilt: float, node: float) -> Array[float]:
	# Apply local +Y spin, then +X axial/orbital tilt, then +Y ascending node.
	var sx: float = x * cos(spin) + z * sin(spin)
	var sz: float = -x * sin(spin) + z * cos(spin)
	var ty: float = y * cos(tilt) - sz * sin(tilt)
	var tz: float = y * sin(tilt) + sz * cos(tilt)
	return [sx * cos(node) + tz * sin(node), ty, -sx * sin(node) + tz * cos(node)]


static func _vector_array(value: Variant) -> Variant:
	if not value is Array or value.size() != 3: return null
	var result: Array[float] = []
	for component: Variant in value:
		if not _number(component): return null
		result.append(float(component))
	return result


static func _number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and _finite(float(value))


static func _finite(value: float) -> bool:
	return is_finite(value)
