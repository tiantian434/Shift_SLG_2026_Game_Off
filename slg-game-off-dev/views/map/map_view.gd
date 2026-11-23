extends Control

const GameHUD := preload("res://views/hud/game_hud.gd")

@export var inner_background: Texture2D

@onready var _background: TextureRect = $Background
@onready var _surface_background: Texture2D = _background.texture
@onready var _hud: GameHUD = $GameHUD


func _ready() -> void:
	SceneRouter.world_changed.connect(_apply_world)
	_hud.shift_requested.connect(SceneRouter.shift_map_world)
	_apply_world(SceneRouter.current_world)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"shift_world"):
		get_viewport().set_input_as_handled()
		SceneRouter.shift_map_world()


func _apply_world(world: int) -> void:
	var inner := world == SceneRouter.World.INNER
	_background.texture = inner_background if inner else _surface_background
	_hud.set_location("空港聚落", inner, true)
	for hotspot in $Facilities.get_children():
		hotspot.show_world(inner)


func _on_facility_selected(facility_id: StringName, _display_name: String) -> void:
	SceneRouter.open_facility(facility_id)
