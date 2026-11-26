@tool
class_name FacilityHUD
extends "res://views/hud/game_hud.gd"

@export var facility_title := "设施":
	set(value):
		facility_title = value
		if is_node_ready():
			set_location(facility_title, _inner_world)

@export var title_color := Color.WHITE:
	set(value):
		title_color = value
		if is_node_ready():
			set_location_colors(title_color, detail_color)

@export var detail_color := Color(0.76, 0.72, 0.66):
	set(value):
		detail_color = value
		if is_node_ready():
			set_location_colors(title_color, detail_color)

var _inner_world := false


func _ready() -> void:
	super._ready()
	$BackButton.show()
	$EndDay.offset_top = -96.0
	$EndDay.offset_bottom = -44.0
	%QuestDrawer.offset_bottom = 257.0
	%Feedback.anchor_left = 1.0
	%Feedback.anchor_right = 1.0
	%Feedback.offset_left = -218.0
	%Feedback.offset_top = 78.0
	%Feedback.offset_right = -10.0
	%Feedback.offset_bottom = 125.0
	set_location(facility_title, _inner_world)
	set_location_colors(title_color, detail_color)


func set_inner_world(is_inner_world: bool) -> void:
	_inner_world = is_inner_world
	set_location(facility_title, _inner_world)
