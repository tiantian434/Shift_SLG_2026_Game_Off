extends Control

const Rules := preload("res://views/training/training_rules.gd")
const INK := Color("#654a34")
const BRASS := Color("#a2774b")
const VELLUM := Color("#e7d1a7")
const COPPER := Color("#ad6647")
const WHITE := Color("#fff1cd")

var exercise: StringName
var inspected := false
var spectrum := Vector2.ZERO
var ritual_progress := 0
var ritual_phase := 0.0
var ritual_running := false
var ritual_failed := false


func _draw() -> void:
	match exercise:
		&"repair":
			_draw_fan()
		&"meal":
			_draw_meal()
		&"alchemy":
			_draw_spectrum()
		&"ritual":
			_draw_ritual()


func _draw_fan() -> void:
	var center := size * 0.5
	var radius := minf(size.y * 0.38, 62.0)
	var rim := Rect2(center - Vector2.ONE * (radius + 11.0), Vector2.ONE * ((radius + 11.0) * 2.0))
	draw_rect(rim, BRASS, false, 2.0)
	draw_circle(center, radius, Color("#d6b98a"))
	draw_arc(center, radius, 0.0, TAU, 48, INK, 2.0, true)
	draw_arc(center, radius - 5.0, 0.0, TAU, 48, BRASS, 1.0, true)
	for index in range(4):
		var angle := TAU * index / 4.0
		var outer := Vector2.from_angle(angle)
		var across := outer.orthogonal()
		var toe := center + outer * radius * 0.82
		var edge := toe + across * 9.0
		if index == 1:
			edge -= outer * 13.0
		var blade := PackedVector2Array([
			center + outer * 7.0,
			center + outer * radius * 0.55 - across * 10.0,
			toe,
			edge,
			center + outer * radius * 0.3 + across * 11.0,
		])
		draw_colored_polygon(blade, COPPER if inspected and index == 1 else INK)
		if inspected and index == 1:
			draw_line(edge, toe, Color("#8c3927"), 3.0, true)
	draw_circle(center, 8.0, BRASS)
	draw_circle(center, 3.0, WHITE)
	for corner in [Vector2(5, 5), Vector2(rim.size.x - 5.0, 5), rim.size - Vector2(5, 5), Vector2(5, rim.size.y - 5.0)]:
		draw_circle(rim.position + corner, 2.0, INK)


func _draw_meal() -> void:
	var center := size * 0.5 + Vector2(0, 18)
	draw_line(center + Vector2(-69, 41), center + Vector2(69, 41), BRASS, 1.0)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-61, -12),
		center + Vector2(61, -12),
		center + Vector2(50, 12),
		center + Vector2(33, 28),
		center + Vector2(-33, 28),
		center + Vector2(-50, 12),
	]), COPPER)
	draw_rect(Rect2(center + Vector2(-28, 28), Vector2(56, 5)), INK)
	draw_rect(Rect2(center + Vector2(-65, -17), Vector2(130, 7)), INK)
	draw_line(center + Vector2(-54, -5), center + Vector2(54, -5), BRASS)
	for x_offset in [-28.0, 0.0, 28.0]:
		var start := center + Vector2(x_offset, -24)
		var steam := PackedVector2Array([start, start + Vector2(6, -8), start + Vector2(6, -15), start + Vector2(-1, -22), start + Vector2(-1, -30)])
		draw_polyline(steam, BRASS, 2.0, true)


func _draw_spectrum() -> void:
	var plot := Rect2(Vector2(16, 19), size - Vector2(28, 42))
	if plot.size.x <= 0.0 or plot.size.y <= 0.0:
		return
	draw_rect(plot, Color("#dcc294"))
	for index in range(1, 8):
		var offset := float(index) / 8.0
		var x := plot.position.x + plot.size.x * offset
		var y := plot.position.y + plot.size.y * offset
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), Color("#bea273"))
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color("#bea273"))
	var target_top_left := _plot_position(plot, Vector2(Rules.SPECTRUM_MIN.x, Rules.SPECTRUM_MAX.y))
	var target_bottom_right := _plot_position(plot, Vector2(Rules.SPECTRUM_MAX.x, Rules.SPECTRUM_MIN.y))
	var target := Rect2(target_top_left, target_bottom_right - target_top_left)
	draw_rect(target, Color("#adc693"))
	draw_rect(target, Color("#536c43"), false, 1.0)
	var origin := _plot_position(plot, Vector2.ZERO)
	draw_line(Vector2(plot.position.x, origin.y), Vector2(plot.end.x, origin.y), BRASS)
	draw_line(Vector2(origin.x, plot.position.y), Vector2(origin.x, plot.end.y), BRASS)
	draw_rect(plot, INK, false, 1.0)
	var raw_position := _plot_position(plot, spectrum)
	var point := raw_position.clamp(plot.position + Vector2(4, 4), plot.end - Vector2(4, 4))
	draw_circle(point, 5.0, INK)
	draw_circle(point, 3.0, WHITE)
	var font := get_theme_default_font()
	draw_string(font, Vector2(15, 14), "↑ 调和度", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, INK)
	draw_string(font, Vector2(plot.end.x - 39.0, plot.end.y + 15.0), "活性 →", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, INK)


func _plot_position(plot: Rect2, point: Vector2) -> Vector2:
	return plot.position + (point * Vector2(0.5, -0.5) + Vector2(0.5, 0.5)) * plot.size


func _draw_ritual() -> void:
	var center := size * 0.5
	var radius := minf(size.y * 0.36, 65.0)
	draw_circle(center, radius + 10.0, Color("#3c3443"))
	draw_arc(center, radius + 8.0, 0.0, TAU, 64, BRASS, 2.0, true)
	draw_arc(center, radius, 0.0, TAU, 48, Color("#a78aab"), 2.0, true)
	draw_arc(center, radius - 9.0, 0.0, TAU, 48, Color("#716479"), 1.0, true)

	if ritual_progress < Rules.RUNES:
		var target := TAU * float(ritual_progress) / Rules.RUNES - PI / 2.0
		var window := TAU * Rules.RITUAL_WINDOW
		var guide_color := Color("#c9816f") if ritual_failed else Color("#e0c08a")
		draw_arc(center, radius, target - window, target + window, 22, guide_color, 4.0, true)

	for index in range(Rules.RUNES):
		var direction := _phase_direction(float(index) / Rules.RUNES)
		var rune_position := center + direction * radius
		var active_color := WHITE
		if index < ritual_progress:
			active_color = Color("#93ceae")
		elif index == ritual_progress and ritual_failed:
			active_color = Color("#db8d7a")
		elif index > ritual_progress:
			active_color = Color("#77657c")
		_draw_rune(rune_position, active_color)

	if ritual_running:
		var pointer := center + _phase_direction(ritual_phase) * radius
		draw_circle(pointer, 4.5, WHITE)
		draw_circle(pointer, 2.0, Color("#9fe9ee"))

	var font := get_theme_default_font()
	var progress_text := "%d / %d" % [ritual_progress, Rules.RUNES]
	var progress_width := font.get_string_size(progress_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, center + Vector2(-progress_width * 0.5, 4), progress_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, VELLUM)


func _phase_direction(phase: float) -> Vector2:
	return Vector2.from_angle(TAU * phase - PI / 2.0)


func _draw_rune(at: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-7, 0),
		at + Vector2(0, -8),
		at + Vector2(7, 0),
		at + Vector2(0, 8),
	]), color)
	draw_circle(at, 2.0, Color("#3c3443"))
