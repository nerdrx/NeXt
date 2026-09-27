extends SceneTree

const HeightField = preload("res://scripts/planet_height_field.gd")
const Terrain = preload("res://scripts/planet_terrain.gd")


func _initialize() -> void:
	var seed := 341
	var image: Image = HeightField.image_for(seed)
	assert(image.get_format() == Image.FORMAT_RF and image.get_width() == HeightField.WIDTH and image.get_height() == HeightField.HEIGHT)
	var repeat: Image = HeightField.image_for(seed)
	assert(image == repeat, "same seed reuses deterministic image")
	for pixel: Vector2i in [Vector2i(0, 0), Vector2i(173, 64), Vector2i(511, 255)]:
		var theta: float = (float(pixel.y) + 0.5) / HeightField.HEIGHT * PI
		var phi: float = ((float(pixel.x) + 0.5) / HeightField.WIDTH - 0.5) * TAU
		var direction := Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
		assert(absf(HeightField.surface_height(direction, seed) - image.get_pixelv(pixel).r * HeightField.HEIGHT_SCALE) < 0.001, "pixel center query matches stored height")
	var seam_left := Vector3(cos(PI - 0.00001), 0.0, sin(PI - 0.00001))
	var seam_right := Vector3(cos(-PI + 0.00001), 0.0, sin(-PI + 0.00001))
	assert(absf(HeightField.surface_height(seam_left, seed) - HeightField.surface_height(seam_right, seed)) < 0.01, "longitude wraps at seam")
	assert(is_finite(HeightField.surface_height(Vector3.UP, seed)) and is_finite(HeightField.surface_height(Vector3.DOWN, seed)))
	assert(HeightField.surface_height(Vector3.ZERO, seed) == 0.0)
	assert(is_equal_approx(Terrain.surface_height(Vector3.RIGHT, seed), HeightField.surface_height(Vector3.RIGHT, seed)))
	for next_seed: int in range(1000, 1000 + HeightField.CACHE_LIMIT + 1):
		HeightField.image_for(next_seed)
	assert(HeightField._cache.size() <= HeightField.CACHE_LIMIT, "seed cache stays bounded")
	print("Planet height field tests passed")
	quit()
