extends SceneTree

func _initialize() -> void:
	var first := StandardMaterial3D.new()
	var second := StandardMaterial3D.new()
	var texture: ImageTexture = PlanetHeightField.texture_for(41)
	var lifetime: WeakRef = weakref(texture)
	first.albedo_texture = texture
	second.albedo_texture = PlanetHeightField.texture_for(41)
	assert(is_same(first.albedo_texture, second.albedo_texture))
	texture = null
	first = null
	assert(lifetime.get_ref() != null, "remaining material keeps shared texture alive")
	second = null
	assert(lifetime.get_ref() == null, "static cache does not keep GPU textures after last owner")
	var recreated: ImageTexture = PlanetHeightField.texture_for(41)
	assert(recreated != null and recreated.get_width() == PlanetHeightField.WIDTH)
	assert(recreated.get_image().get_pixel(100, 100) == PlanetHeightField.image_for(41).get_pixel(100, 100))
	recreated = null
	print("HEIGHT_TEXTURE_LIFETIME_OK: sharing, last-owner release and deterministic recreation")
	quit()
