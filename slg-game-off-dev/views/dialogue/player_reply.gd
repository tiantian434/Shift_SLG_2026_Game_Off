extends Control

signal finished

# Positions relative to the bottom-left of the dialogue viewport.
const PEEK_SPOTS: Array[Vector2] = [Vector2(5, -122), Vector2(118, -73), Vector2(57, -174)]

@onready var _face: Control = $Face
@onready var _bubble: Control = $Bubble
@onready var _text: Label = $Bubble/Text

var _animation: Tween


func present(line: String) -> void:
	dismiss()
	var spot: Vector2 = PEEK_SPOTS.pick_random()
	var swing := -1.0 if spot.x < 100.0 else 1.0
	var approach := Vector2(swing * 34.0, 43.0)
	_text.text = line
	_face.position = spot + approach
	_face.rotation = deg_to_rad(swing * 25.0)
	_face.modulate.a = 0.0
	var font := _text.get_theme_font(&"font")
	var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, _text.get_theme_font_size(&"font_size")).x
	_bubble.size.x = clampf(width + 28.0, 88.0, 216.0)
	_text.size.x = _bubble.size.x - 24.0
	_bubble.size.y = clampf(_text.get_minimum_size().y + 12.0, 46.0, 108.0)
	var bubble_top := minf(spot.y - 24.0, -_bubble.size.y - 12.0)
	_bubble.position = Vector2(spot.x + 68.0, bubble_top)
	_bubble.rotation = deg_to_rad(swing * 3.0)
	_bubble.scale = Vector2(0.64, 0.64)
	_bubble.modulate.a = 0.0
	show()
	_animation = create_tween()
	_animation.tween_property(_face, "position", spot, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_animation.parallel().tween_property(_face, "rotation", deg_to_rad(swing * 9.0), 0.22)
	_animation.parallel().tween_property(_face, "modulate:a", 1.0, 0.09)
	_animation.tween_property(_bubble, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_animation.parallel().tween_property(_bubble, "modulate:a", 1.0, 0.10)
	_animation.tween_interval(clampf(0.9 + line.length() * 0.09, 1.8, 4.0))
	_animation.tween_property(_bubble, "modulate:a", 0.0, 0.12)
	_animation.parallel().tween_property(_face, "position", spot + approach, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_animation.parallel().tween_property(_face, "modulate:a", 0.0, 0.20)
	_animation.tween_callback(_finish)


func dismiss() -> void:
	if _animation:
		_animation.kill()
		_animation = null
	hide()


func set_suspended(suspended: bool) -> void:
	if _animation:
		if suspended:
			_animation.pause()
		else:
			_animation.play()


func _finish() -> void:
	_animation = null
	hide()
	finished.emit()
