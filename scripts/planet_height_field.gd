class_name PlanetHeightField
extends RefCounted

const WIDTH: int = 512
const HEIGHT: int = 256
const HEIGHT_SCALE: float = 12.0
const SEA_LEVEL: float = 6.0
const CACHE_LIMIT: int = 16

static var _cache: Dictionary = {}


static func image_for(seed: int) -> Image:
	if not _cache.has(seed):
		var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RF)
		var noise := _noise(seed)
		for y: int in HEIGHT:
			var theta: float = (float(y) + 0.5) / HEIGHT * PI
			for x: int in WIDTH:
				var phi: float = ((float(x) + 0.5) / WIDTH - 0.5) * TAU
				var direction := Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
				var height: float = clampf((noise.get_noise_3dv(direction * 80.0) * 0.5 + 0.5), 0.0, 1.0)
				image.set_pixel(x, y, Color(height, 0.0, 0.0, 1.0))
		_cache[seed] = {"image": image, "texture": null}
		if _cache.size() > CACHE_LIMIT:
			_cache.erase(_cache.keys()[0])
	return _cache[seed]["image"]


static func texture_for(seed: int) -> ImageTexture:
	var image := image_for(seed)
	var entry: Dictionary = _cache[seed]
	var texture: ImageTexture = entry["texture"].get_ref() if entry["texture"] != null else null
	if texture == null:
		texture = ImageTexture.create_from_image(image)
		# Materials own GPU textures; the static CPU cache must not outlive their renderer.
		entry["texture"] = weakref(texture)
		_cache[seed] = entry
	return texture


static func surface_height(direction: Vector3, seed: int) -> float:
	if not direction.is_finite() or direction.length_squared() <= 0.000001:
		return 0.0
	var unit: Vector3 = direction.normalized()
	var u: float = atan2(unit.z, unit.x) / TAU + 0.5
	var v: float = acos(clampf(unit.y, -1.0, 1.0)) / PI
	var px: float = u * WIDTH - 0.5
	var py: float = clampf(v * HEIGHT - 0.5, 0.0, HEIGHT - 1.0)
	var x0: int = floori(px)
	var y0: int = floori(py)
	var x1: int = posmod(x0 + 1, WIDTH)
	var y1: int = mini(y0 + 1, HEIGHT - 1)
	var fx: float = px - floorf(px)
	var fy: float = py - floorf(py)
	var image := image_for(seed)
	var north: float = lerpf(image.get_pixel(posmod(x0, WIDTH), y0).r, image.get_pixel(x1, y0).r, fx)
	var south: float = lerpf(image.get_pixel(posmod(x0, WIDTH), y1).r, image.get_pixel(x1, y1).r, fx)
	return lerpf(north, south, fy) * HEIGHT_SCALE


static func _noise(seed: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.035
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.48
	return noise
