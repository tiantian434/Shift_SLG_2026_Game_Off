class_name SpriteHotspot
extends TextureRect

signal activated

@export var display_name: String:
	set(value):
		display_name = value
		if is_node_ready():
			name_tag.text = value

@onready var outline: TextureRect = $Outline
@onready var name_tag: Label = $NameTag

var _hit_mask := BitMap.new()
var _hovered := false
var _clickable := true


func _ready() -> void:
	name_tag.text = display_name
	_rebuild_hotspot_mask()

	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(_update_highlight)
	focus_exited.connect(_update_highlight)
	resized.connect(_update_outline_size)
	visibility_changed.connect(_on_visibility_changed)


func _rebuild_hotspot_mask() -> void:
	var sprite_image := texture.get_image() if texture else null
	if sprite_image == null or sprite_image.is_empty():
		_hit_mask = BitMap.new()
		outline.texture = null
		push_warning("Sprite hotspot '%s' needs a readable texture." % name)
		return

	_hit_mask.create_from_image_alpha(sprite_image)
	outline.texture = _make_outline(_hit_mask)
	_update_outline_size()


func set_clickable(clickable: bool) -> void:
	_clickable = clickable
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if clickable else CURSOR_ARROW
	if not clickable:
		release_focus()


func _has_point(point: Vector2) -> bool:
	var mask_size := _hit_mask.get_size()
	if mask_size == Vector2i.ZERO or not Rect2(Vector2.ZERO, size).has_point(point):
		return false

	# Convert the scaled local point into the texture's original pixel grid.
	var pixel := Vector2i(point / size * Vector2(mask_size))
	return _hit_mask.get_bitv(pixel)


func _gui_input(event: InputEvent) -> void:
	if not _clickable:
		return
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed or not _has_point(event.position):
			return
	elif not event.is_action_pressed(&"ui_accept"):
		return

	accept_event()
	activated.emit()


func _make_outline(mask: BitMap) -> ImageTexture:
	var mask_size := mask.get_size()
	var padding := _outline_padding(mask_size)
	var image_size := mask_size + padding * 2
	var image := Image.create_empty(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	var stamp := padding * 2 + Vector2i.ONE
	# Draw the selected border width behind the original sprite.
	for y in range(mask_size.y):
		for x in range(mask_size.x):
			if mask.get_bit(x, y):
				image.fill_rect(Rect2i(Vector2i(x, y), stamp), Color.WHITE)
	return ImageTexture.create_from_image(image)


func _outline_padding(_mask_size: Vector2i) -> Vector2i:
	return Vector2i.ONE


func _update_outline_size() -> void:
	var mask_size := _hit_mask.get_size()
	if mask_size == Vector2i.ZERO:
		return
	var border := size / Vector2(mask_size) * Vector2(_outline_padding(mask_size))
	outline.position = -border
	outline.size = size + border * 2.0


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	_update_highlight()


func _update_highlight() -> void:
	var highlighted := is_visible_in_tree() and (_hovered or has_focus())
	outline.visible = highlighted
	name_tag.visible = highlighted


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_set_hovered(false)
