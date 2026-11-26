extends Node2D

const AIRFLOW_FPS := 20.0

@onready var _airship: Node2D = $Airship
@onready var _airflow: Sprite2D = $Airship/Airflow
@onready var _far_wing: ShaderMaterial = $Airship/FarWing/Art.material
@onready var _near_wing: ShaderMaterial = $Airship/NearWing/Art.material
@onready var _airship_origin := _airship.position

var _elapsed := 0.0
var _pedestrians: Array[Sprite2D] = []
var _walk_origins: Array[Vector2] = []


func _ready() -> void:
	for person: Sprite2D in $Pedestrians.get_children():
		_pedestrians.append(person)
		_walk_origins.append(person.position)


func set_active(active: bool) -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	_elapsed += delta
	for index in _pedestrians.size():
		var person := _pedestrians[index]
		var phase := _elapsed * (0.46 + index * 0.015) + index * 1.46
		var distance: float = person.get_meta(&"walk_distance")
		person.position = _walk_origins[index] + Vector2(sin(phase) * distance, absf(sin(phase * 18.0)) * -1.2)
		person.flip_h = cos(phase) < 0.0
	_airship.position = _airship_origin + Vector2(2.0 * sin(_elapsed * 0.72), 5.0 * sin(_elapsed * 1.06))
	_airflow.frame = int(_elapsed * AIRFLOW_FPS) % (_airflow.hframes * _airflow.vframes)
	var flap := sin(_elapsed * 2.4)
	_far_wing.set_shader_parameter(&"flap", 0.050 * flap)
	_near_wing.set_shader_parameter(&"flap", -0.058 * flap)
