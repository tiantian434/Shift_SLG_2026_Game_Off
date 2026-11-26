extends Node2D

@export var blade: Texture2D
@export var hub: Texture2D
@export var hub_size := Vector2(15.0, 15.0)
@export var hub_offset := Vector2(-2.0, 0.0)
@export var radius := 59.0
@export_range(0.1, 1.0) var plane_ratio := 0.75
@export_range(-45.0, 45.0) var plane_tilt := 12.0
@export var turns_per_minute := 24.0
@export var start_degrees := 45.0

const BLADE_COUNT := 4
const BLADE_PITCH := 0.18

var _phase := 0.0


func _ready() -> void:
	_phase = deg_to_rad(start_degrees)


func _process(delta: float) -> void:
	_phase = fposmod(_phase + turns_per_minute * TAU / 60.0 * delta, TAU)
	queue_redraw()


func _draw() -> void:
	if blade == null or hub == null:
		return
	var up := Vector2.UP.rotated(deg_to_rad(plane_tilt))
	var across := up.rotated(PI * 0.5)
	var blade_scale := radius / blade.get_width()
	var texture_origin := Vector2(0.0, -blade.get_height() * 0.5)
	for index in BLADE_COUNT:
		var angle := _phase + index * TAU / BLADE_COUNT
		var sine := sin(angle)
		var cosine := cos(angle)
		var span := up * cosine + across * (sine * plane_ratio)
		var chord := -up * sine + across * (cosine * plane_ratio + BLADE_PITCH)
		# The span follows the propeller disk. The pitch adds chord in the direction of the shaft.
		draw_set_transform_matrix(Transform2D(span * blade_scale, chord * blade_scale, Vector2.ZERO))
		var shade := 0.96 + 0.04 * cosine
		draw_texture(blade, texture_origin, Color(shade, shade, shade))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_texture_rect(hub, Rect2(hub_offset - hub_size * 0.5, hub_size), false)
