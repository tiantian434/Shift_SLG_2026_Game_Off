extends "res://views/facilities/facility_room.gd"

@onready var _researcher: SpriteHotspot = %Researcher
@onready var _escort: SpriteHotspot = %Escort
@onready var _mechanical_maiden := get_node_or_null("%MechanicalMaiden") as SpriteHotspot


func _ready() -> void:
	super._ready()
	_researcher.activated.connect(_open_escort)
	_escort.activated.connect(_open_escort)
	if _mechanical_maiden != null:
		_mechanical_maiden.activated.connect(_open_training)
	GameSession.state_changed.connect(_refresh_actors)
	_refresh_actors()


func _open_escort() -> void:
	GameSession.open_task(&"chapter1_escort")


func _open_training() -> void:
	var task := &"ch2_return" if GameSession.training_stage() == &"return" else &"ch2_briefing"
	GameSession.open_task(task)


func _refresh_actors() -> void:
	var present := not GameSession.is_chapter_two() and not GameSession.is_chapter_complete()
	_researcher.visible = present
	_escort.visible = present
	if _mechanical_maiden != null:
		_mechanical_maiden.visible = GameSession.is_chapter_two() and GameSession.training_stage() in [&"briefing", &"return"]
