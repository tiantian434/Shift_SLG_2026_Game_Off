extends "res://views/facilities/art/room_art_hotspot.gd"

@onready var _motion: AnimatedSprite2D = $Motion


func _ready() -> void:
	super._ready()
	activated.connect(_ring)
	_motion.animation_finished.connect(_settle)


func _ring() -> void:
	if UIManager.has_modal() or SceneRouter.is_changing_scene() or _motion.is_playing():
		return
	self_modulate.a = 0.0
	_motion.show()
	_motion.play(&"ring")


func _settle() -> void:
	_motion.hide()
	self_modulate.a = 1.0
