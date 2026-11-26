extends "res://views/facilities/facility_room.gd"

@export var training_stage: StringName

@onready var _actors: Control = $Interface/TrainingActors
@onready var _device := get_node_or_null("Interface/TrainingDevice") as Control
@onready var _repair_motion := get_node_or_null("RepairMotion") as AnimationPlayer


func _ready() -> void:
	super._ready()
	for actor: SpriteHotspot in _actors.get_children():
		actor.activated.connect(_open_training)
	if _device is SpriteHotspot:
		_device.activated.connect(_open_training)
	elif _device is BaseButton:
		_device.pressed.connect(_open_training)
	GameSession.state_changed.connect(_refresh_training)
	_refresh_training()


func _open_training() -> void:
	GameSession.open_task(StringName("ch2_" + String(training_stage)))


func _refresh_training() -> void:
	var stage := GameSession.training_stage()
	var training_available := GameSession.is_chapter_two() and stage != &"complete"
	_actors.visible = training_available and stage == training_stage
	var solved := GameSession.is_training_solved(training_stage)
	if _device != null:
		_device.visible = training_available
	_refresh_device(solved)


func _refresh_device(solved: bool) -> void:
	if not solved or _device == null:
		return
	match training_stage:
		&"repair":
			_device.tooltip_text = "通风机运转正常"
			if _device is SpriteHotspot:
				_device.display_name = "通风机 · 已修好"
			if _repair_motion != null and not _repair_motion.is_playing():
				_repair_motion.play(&"running")
		&"ritual":
			_device.tooltip_text = "止风术式已生效"
			_device.get_node("CalmRune").show()
		&"alchemy":
			_device.tooltip_text = "叶片已恢复绿色"
			_device.get_node("Workbench/RustLeaves").color = Color("#72a466")
			_device.get_node("Workbench/Solution").color = Color("#9ed0bd")
