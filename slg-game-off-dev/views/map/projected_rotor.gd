extends Node2D

@export_range(-90.0, 90.0) var axis_tilt_degrees := -70.0
@export_range(0.1, 1.0) var plane_ratio := 0.84
@export var turns_per_minute := 6.0

@onready var _face: Sprite2D = $Face
@onready var _rest_transform := _face.transform

var _plane: Transform2D
var _inverse_plane: Transform2D
var _angle := 0.0


func _ready() -> void:
	var major_axis := Vector2.RIGHT.rotated(deg_to_rad(axis_tilt_degrees))
	var minor_axis := major_axis.rotated(PI / 2.0) * plane_ratio
	_plane = Transform2D(major_axis, minor_axis, Vector2.ZERO)
	_inverse_plane = _plane.affine_inverse()


func _process(delta: float) -> void:
	_angle = fposmod(_angle + turns_per_minute * TAU / 60.0 * delta, TAU)
	# Rotate in the wheel's own plane and project back into the scene.
	var rotation_in_plane := Transform2D(_angle, Vector2.ZERO)
	_face.transform = _plane * rotation_in_plane * _inverse_plane * _rest_transform
