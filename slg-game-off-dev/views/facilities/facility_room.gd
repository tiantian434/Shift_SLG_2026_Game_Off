extends Node2D

@export var facility_id: StringName
@export_enum("Surface", "Inner") var world: int = 0

@onready var _hud: FacilityHUD = $Interface/FacilityHUD


func _ready() -> void:
	_hud.set_inner_world(world == SceneRouter.World.INNER)
	_hud.back_requested.connect(_return_to_map)
	_hud.shift_requested.connect(_shift_world)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"shift_world"):
		get_viewport().set_input_as_handled()
		_shift_world()


func _shift_world() -> void:
	SceneRouter.shift_facility(facility_id, world)


func _return_to_map() -> void:
	if not UIManager.has_modal():
		SceneRouter.return_to_map(world)
