extends SpriteHotspot

var _standing_pose: Dictionary
var _turn_poses: Array[Dictionary] = []
var _facing_poses: Array[Dictionary] = []
var _facing_side := -1
var _turn: Tween


func _ready() -> void:
	super._ready()
	var source := texture as AtlasTexture
	if source == null or not source.has_meta(&"facing_rows"):
		return

	_standing_pose = {"texture": texture, "outline": outline.texture}
	var rows: Vector2i = source.get_meta(&"facing_rows")
	for row in [rows.x, rows.y]:
		_turn_poses.append(_create_pose(source, Vector2i(0, row)))
		_facing_poses.append(_create_pose(source, Vector2i(1, row)))
	mouse_entered.connect(_face_pointer)
	mouse_exited.connect(_return_to_standing)
	visibility_changed.connect(_on_actor_visibility_changed)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not _facing_poses.is_empty():
		_face_pointer()
	super._gui_input(event)


func _create_pose(source: AtlasTexture, cell: Vector2i) -> Dictionary:
	var pose := AtlasTexture.new()
	pose.atlas = source.atlas
	pose.region = Rect2(Vector2(cell) * source.region.size, source.region.size)
	pose.filter_clip = true
	var mask := BitMap.new()
	mask.create_from_image_alpha(pose.get_image())
	return {"texture": pose, "outline": _make_outline(mask)}


func _face_pointer() -> void:
	var side := 0 if get_local_mouse_position().x < size.x * 0.5 else 1
	if _facing_side == side:
		return
	_facing_side = side
	if _turn != null:
		_turn.kill()
	_show_pose(_turn_poses[side])
	_turn = create_tween()
	_turn.tween_interval(0.11)
	_turn.tween_callback(_show_pose.bind(_facing_poses[side]))


func _return_to_standing() -> void:
	if _turn != null:
		_turn.kill()
		_turn = null
	_facing_side = -1
	_show_pose(_standing_pose)


func _on_actor_visibility_changed() -> void:
	if not is_visible_in_tree():
		_return_to_standing()


func _show_pose(pose: Dictionary) -> void:
	texture = pose["texture"]
	outline.texture = pose["outline"]
