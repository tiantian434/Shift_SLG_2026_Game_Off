extends RefCounted

const SETTINGS_PATH := "user://settings.cfg"
const MINIMUM_WINDOW_SIZE := Vector2i(640, 360)
const WINDOW_SIZES := [
	Vector2i(640, 360),
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

var master_volume := 100.0:
	set(value):
		master_volume = clampf(value, 0.0, 100.0)
		AudioServer.set_bus_volume_linear(0, master_volume / 100.0)
var _window: Window
var _windowed_size: Vector2i
var _window_decorations := Vector2i.ZERO
var _saved_fullscreen := false


func restore(window: Window) -> void:
	_window = window
	if can_change_display():
		_windowed_size = window.size.max(MINIMUM_WINDOW_SIZE)
		_window_decorations = (DisplayServer.window_get_size_with_decorations() - window.size).max(Vector2i.ZERO)
		window.min_size = MINIMUM_WINDOW_SIZE
	else:
		_windowed_size = Vector2i(
			ProjectSettings.get_setting("display/window/size/window_width_override"),
			ProjectSettings.get_setting("display/window/size/window_height_override")
		).max(MINIMUM_WINDOW_SIZE)

	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) != OK:
		return

	var volume: Variant = file.get_value("audio", "master_volume", 100.0)
	if (volume is float or volume is int) and is_finite(float(volume)):
		master_volume = float(volume)

	var display_mode: Variant = file.get_value("display", "fullscreen", false)
	if display_mode is bool:
		_saved_fullscreen = display_mode

	var size: Variant = file.get_value("display", "windowed_size", Vector2i.ZERO)
	var has_valid_size: bool = size is Vector2i and size.x >= MINIMUM_WINDOW_SIZE.x and size.y >= MINIMUM_WINDOW_SIZE.y
	if has_valid_size:
		_windowed_size = size

	if can_change_display():
		if _saved_fullscreen:
			_window.mode = Window.MODE_FULLSCREEN
		elif has_valid_size:
			set_windowed_size(_windowed_size)


func save() -> void:
	if can_change_display():
		_saved_fullscreen = is_fullscreen()
		_windowed_size = windowed_size()
	var file := ConfigFile.new()
	file.set_value("audio", "master_volume", master_volume)
	file.set_value("display", "fullscreen", _saved_fullscreen)
	file.set_value("display", "windowed_size", _windowed_size)
	var result := file.save(SETTINGS_PATH)
	if result != OK:
		push_warning("Could not save the settings: %s" % error_string(result))


func can_change_display() -> bool:
	return not Engine.is_embedded_in_editor() and DisplayServer.get_name() != "headless"


func is_fullscreen() -> bool:
	return _window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]


func windowed_size() -> Vector2i:
	if can_change_display() and _window.mode == Window.MODE_WINDOWED:
		return _window.size
	return _windowed_size


func supported_window_sizes() -> Array[Vector2i]:
	var available := _available_window_size()
	var sizes: Array[Vector2i] = []
	for size in WINDOW_SIZES:
		if size.x <= available.x and size.y <= available.y:
			sizes.append(size)
	return sizes


func set_fullscreen(enabled: bool) -> void:
	if not can_change_display() or enabled == is_fullscreen():
		return
	if enabled:
		_windowed_size = windowed_size()
		_window.mode = Window.MODE_FULLSCREEN
	else:
		set_windowed_size(_windowed_size)


func set_windowed_size(size: Vector2i) -> void:
	if not can_change_display():
		return
	var work_area := DisplayServer.screen_get_usable_rect(_window.current_screen)
	var available := _available_window_size()
	var scale := minf(1.0, minf(float(available.x) / size.x, float(available.y) / size.y))
	var target := Vector2i(Vector2(size) * scale).max(MINIMUM_WINDOW_SIZE)
	_window.mode = Window.MODE_WINDOWED
	_window.size = target
	_windowed_size = _window.size
	if work_area.has_area():
		_window.position = work_area.position + (work_area.size - _window.size) / 2


func _available_window_size() -> Vector2i:
	var work_area := DisplayServer.screen_get_usable_rect(_window.current_screen)
	return (work_area.size - _window_decorations).max(MINIMUM_WINDOW_SIZE)
