extends SpriteHotspot


func _rebuild_hotspot_mask() -> void:
	if texture == null:
		super._rebuild_hotspot_mask()
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		super._rebuild_hotspot_mask()
		return

	# Keep the outline one logical pixel wide on high-density room textures.
	var logical := Vector2i(size.round()).max(Vector2i.ONE)
	image.resize(logical.x, logical.y, Image.INTERPOLATE_LANCZOS)
	_hit_mask.create_from_image_alpha(image)
	outline.texture = _make_outline(_hit_mask)
	_update_outline_size()


func _make_outline(mask: BitMap) -> ImageTexture:
	var stencil := super._make_outline(mask).get_image()
	var bounds := mask.get_size()
	for y in bounds.y:
		for x in bounds.x:
			if mask.get_bit(x, y):
				stencil.set_pixel(x + 1, y + 1, Color.TRANSPARENT)
	return ImageTexture.create_from_image(stencil)
