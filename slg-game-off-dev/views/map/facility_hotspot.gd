extends SpriteHotspot

signal facility_selected(facility_id: StringName, display_name: String)

@export var facility_id: StringName
@export var inner_display_name: String
@export var inner_texture: Texture2D
@export var surface_rect: Rect2
@export var surface_ground_inset := 0.0

@onready var _surface_texture: Texture2D = texture
@onready var _inner_rect := Rect2(position, size)


func _ready() -> void:
	super._ready()
	activated.connect(_select_facility)


func show_world(inner: bool) -> void:
	var appearance := inner_texture if inner and inner_texture else _surface_texture
	var placement := _inner_rect if inner or not surface_rect.has_area() else surface_rect
	position = placement.position
	size = placement.size
	if texture != appearance:
		texture = appearance
		_rebuild_hotspot_mask()
	name_tag.text = inner_display_name if inner and not inner_display_name.is_empty() else display_name


func surface_ground_y() -> float:
	return position.y + size.y - surface_ground_inset


func _outline_padding(mask_size: Vector2i) -> Vector2i:
	if texture != _surface_texture or not surface_rect.has_area():
		return super._outline_padding(mask_size)
	return Vector2i((Vector2(mask_size) / surface_rect.size).round()).max(Vector2i.ONE)


func _select_facility() -> void:
	facility_selected.emit(facility_id, name_tag.text)
