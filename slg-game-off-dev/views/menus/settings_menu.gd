extends Control

signal closed

const GameSettings := preload("res://app/game_settings.gd")

var _settings: GameSettings

@onready var _volume: HSlider = %MasterVolume
@onready var _volume_value: Label = %VolumeValue
@onready var _fullscreen: CheckButton = %Fullscreen
@onready var _resolution: OptionButton = %WindowResolution
@onready var _output: Label = %OutputResolution
@onready var _display_hint: Label = %DisplayHint
@onready var _back: Button = %Back


func setup(settings: GameSettings) -> void:
	_settings = settings
	_volume.set_value_no_signal(_settings.master_volume)
	_update_volume_label(_settings.master_volume)
	_fullscreen.disabled = not _settings.can_change_display()
	_display_hint.visible = Engine.is_embedded_in_editor()
	_refresh_display()
	_volume.value_changed.connect(_apply_volume)
	_fullscreen.toggled.connect(_apply_fullscreen)
	_resolution.item_selected.connect(_apply_resolution)
	get_window().size_changed.connect(_refresh_display)
	_back.pressed.connect(closed.emit)
	_volume.grab_focus()


func close_resolution_list() -> bool:
	var popup := _resolution.get_popup()
	if not popup.visible:
		return false
	popup.hide()
	_resolution.grab_focus()
	return true


func _apply_volume(value: float) -> void:
	_settings.master_volume = value
	_update_volume_label(value)


func _update_volume_label(value: float) -> void:
	_volume_value.text = "%d%%" % roundi(value)


func _apply_fullscreen(enabled: bool) -> void:
	_settings.set_fullscreen(enabled)
	_refresh_display()


func _apply_resolution(index: int) -> void:
	_settings.set_windowed_size(_resolution.get_item_metadata(index) as Vector2i)
	_refresh_display()


func _refresh_display() -> void:
	var fullscreen := _settings.is_fullscreen()
	var managed := _settings.can_change_display()
	_fullscreen.set_pressed_no_signal(fullscreen)
	_resolution.disabled = not managed or fullscreen
	_resolution.clear()

	var current := _settings.windowed_size() if managed else get_window().size
	var sizes: Array[Vector2i] = [current]
	if managed:
		sizes = _settings.supported_window_sizes()
	var selected := sizes.find(current)
	for size: Vector2i in sizes:
		_add_resolution(size)
	if selected < 0:
		selected = _resolution.item_count
		_add_resolution(current)
	_resolution.select(selected)

	var pixels := get_window().size
	_output.text = "当前窗口  %d × %d" % [pixels.x, pixels.y]


func _add_resolution(size: Vector2i) -> void:
	_resolution.add_item("%d × %d" % [size.x, size.y])
	_resolution.set_item_metadata(_resolution.item_count - 1, size)
