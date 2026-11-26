extends Control

const GameHUD := preload("res://views/hud/game_hud.gd")
const SurfacePort := preload("res://views/map/surface_port.gd")
const FacilityHotspot := preload("res://views/map/facility_hotspot.gd")
const PORT_COORDINATE_SCALE := 640.0 / 768.0
const MAX_ZOOM := 1.65
const ZOOM_STEP := 0.16
const DECK_LAYER := -2048
const GROUND_DEPTH_STEPS := 4.0

@export var inner_background: Texture2D

@onready var _background: TextureRect = $Background
@onready var _surface_background: Texture2D = _background.texture
@onready var _sky: VideoStreamPlayer = $SurfaceSky
@onready var _port: SurfacePort = $SurfacePort
@onready var _facilities: Control = $Facilities
@onready var _hud: GameHUD = $GameHUD
@onready var _walkers := _port.get_node("Pedestrians").get_children()
@onready var _hotspots := _facilities.get_children()

var _surface_active := false
var _surface_zoom := 1.0
var _zoom_goal := 1.0
var _surface_offset := Vector2.ZERO
var _zoom_tween: Tween


func _ready() -> void:
	_background.z_index = DECK_LAYER - 2
	_sky.z_index = DECK_LAYER - 1
	_port.z_index = DECK_LAYER
	_facilities.z_index = DECK_LAYER
	for prop: Sprite2D in _port.get_node("Dressing").get_children():
		prop.z_index = _ground_depth(_sprite_ground_y(prop))
	# Read each walker's updated transform after SurfacePort animates it.
	process_priority = 1
	SceneRouter.world_changed.connect(_apply_world)
	_hud.shift_requested.connect(SceneRouter.shift_map_world)
	_apply_world(SceneRouter.current_world)


func _process(_delta: float) -> void:
	for walker: Sprite2D in _walkers:
		walker.z_index = _ground_depth(_sprite_ground_y(walker))


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"shift_world"):
		get_viewport().set_input_as_handled()
		SceneRouter.shift_map_world()


func _input(event: InputEvent) -> void:
	if not _surface_active or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_WHEEL_UP and event.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return
	if UIManager.has_modal() or SceneRouter.is_changing_scene():
		return
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered and _hud.is_ancestor_of(hovered):
		return
	var cursor: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	if not Rect2(Vector2.ZERO, size).has_point(cursor):
		return
	get_viewport().set_input_as_handled()
	var step := ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else -ZOOM_STEP
	_zoom_at(clampf(_zoom_goal + step, 1.0, MAX_ZOOM), cursor)


func _apply_world(world: int) -> void:
	var inner := world == SceneRouter.World.INNER
	_surface_active = not inner
	set_process(_surface_active)
	_background.texture = inner_background if inner else _surface_background
	_sky.visible = _surface_active
	_port.set_active(_surface_active)
	if inner:
		if _zoom_tween:
			_zoom_tween.kill()
		_zoom_goal = _surface_zoom
		_sky.stop()
		_facilities.position = Vector2.ZERO
		_facilities.scale = Vector2.ONE
	else:
		_sky.play()
		_apply_surface_transform(Vector3(_surface_offset.x, _surface_offset.y, _surface_zoom))
	_hud.set_location("空港聚落", inner, true)
	for hotspot: FacilityHotspot in _hotspots:
		hotspot.show_world(inner)
		hotspot.z_index = 0 if inner else _ground_depth(hotspot.surface_ground_y() / PORT_COORDINATE_SCALE)
		# Keep the name above the depth-sorted art and below the HUD.
		hotspot.name_tag.z_as_relative = inner
		hotspot.name_tag.z_index = 1 if inner else -1
	_match_facility_input_order(inner)


func _match_facility_input_order(inner: bool) -> void:
	var back_to_front := _hotspots.duplicate()
	if not inner:
		# Controls use tree order for mouse picking, independently of z_index.
		back_to_front.sort_custom(func(a: FacilityHotspot, b: FacilityHotspot) -> bool:
			return a.z_index < b.z_index
		)
	for index in back_to_front.size():
		_facilities.move_child(back_to_front[index], index)


func _sprite_ground_y(sprite: Sprite2D) -> float:
	return sprite.position.y + sprite.get_rect().end.y * sprite.scale.y


func _ground_depth(ground_y: float) -> int:
	return roundi(ground_y * GROUND_DEPTH_STEPS)


func _zoom_at(target: float, cursor: Vector2) -> void:
	if is_equal_approx(target, _zoom_goal):
		return
	_zoom_goal = target
	if _zoom_tween:
		_zoom_tween.kill()
	var offset := cursor + (_surface_offset - cursor) * target / _surface_zoom
	offset = offset.clamp(size * (1.0 - target), Vector2.ZERO)
	_zoom_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var start := Vector3(_surface_offset.x, _surface_offset.y, _surface_zoom)
	var finish := Vector3(offset.x, offset.y, target)
	_zoom_tween.tween_method(_apply_surface_transform, start, finish, 0.18)


func _apply_surface_transform(view: Vector3) -> void:
	_surface_offset = Vector2(view.x, view.y)
	_surface_zoom = view.z
	_port.position = _surface_offset
	_port.scale = Vector2.ONE * PORT_COORDINATE_SCALE * _surface_zoom
	_facilities.position = _surface_offset
	_facilities.scale = Vector2.ONE * _surface_zoom


func _on_facility_selected(facility_id: StringName, _display_name: String) -> void:
	SceneRouter.open_facility(facility_id)
