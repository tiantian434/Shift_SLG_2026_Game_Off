@tool
extends Control

signal back_requested
signal shift_requested

const TaskDrawer := preload("res://views/hud/task_drawer.gd")
const FEEDBACK_SECONDS := 3.4

static var _pending_ids: Dictionary = {}
static var _feedback_queue: Array[Dictionary] = []

var _show_weather := false
var _pending_entries: Array[Dictionary] = []
var _announcement_scheduled := false

@onready var _day_label: Label = %Day
@onready var _place_label: Label = %Place
@onready var _world_label: Label = %World
@onready var _weather_label: Label = %Weather
@onready var _gold_label: Label = %Gold
@onready var _quest_toggle: Button = %QuestToggle
@onready var _quest_drawer: TaskDrawer = %QuestDrawer
@onready var _pending_dot: Control = %TaskDot
@onready var _feedback: Button = %Feedback
@onready var _feedback_timer: Timer = %FeedbackTimer


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	add_to_group(&"game_hud")
	$PauseButton.pressed.connect(MenuSystem.open_pause)
	$ShiftButton.pressed.connect(_request_shift)
	$BackButton.pressed.connect(_request_back)
	$EndDay.pressed.connect(MenuSystem.open_day_end)
	_quest_toggle.pressed.connect(_toggle_tasks)
	_quest_drawer.visibility_changed.connect(_refresh_task_button)
	_quest_drawer.close_requested.connect(_close_tasks)
	_quest_drawer.task_selected.connect(_open_task)
	_feedback.pressed.connect(_open_tasks_from_feedback)
	_feedback_timer.timeout.connect(_finish_feedback)
	GameSession.state_changed.connect(_refresh_progress)
	SceneRouter.world_changed.connect(_on_world_changed)
	_refresh_progress()
	_display_first_feedback()
	_start_art_motion()


func _exit_tree() -> void:
	if not Engine.is_editor_hint() and is_instance_valid(_quest_drawer):
		_quest_drawer.close_drawer()


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _quest_drawer.visible or not _can_navigate():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_tasks()
	elif event.is_action_pressed(&"shift_world"):
		get_viewport().set_input_as_handled()
		_request_shift()


func set_location(place: String, inner: bool, show_weather := false) -> void:
	_place_label.text = place
	_world_label.text = "里世界" if inner else "表世界"
	_world_label.add_theme_color_override(&"font_color", Color("#ead9ff") if inner else Color("#fff0c3"))
	_show_weather = show_weather and not inner
	_refresh_weather()


func set_location_colors(title: Color, detail: Color) -> void:
	_place_label.add_theme_color_override(&"font_color", title)
	_weather_label.add_theme_color_override(&"font_color", detail)


func show_feedback(message: String, opens_tasks := false) -> void:
	if message.strip_edges().is_empty():
		return
	_feedback_queue.append({"message": message, "opens_tasks": opens_tasks})
	if _feedback_timer.is_stopped():
		_display_first_feedback()


func reset_for_new_run() -> void:
	_pending_ids.clear()
	_feedback_queue.clear()
	_feedback_timer.stop()
	_feedback.hide()
	_quest_drawer.reset_memory()


func _request_shift() -> void:
	if _can_navigate():
		_quest_drawer.close_drawer()
		shift_requested.emit()


func _request_back() -> void:
	if _can_navigate():
		back_requested.emit()


func _can_navigate() -> bool:
	return not UIManager.has_modal() and not SceneRouter.is_changing_scene()


func _open_tasks() -> void:
	if _can_navigate():
		_quest_drawer.open_drawer()


func _toggle_tasks() -> void:
	if not _can_navigate():
		return
	if _quest_drawer.visible:
		_close_tasks()
	else:
		_open_tasks()


func _close_tasks() -> void:
	_quest_drawer.close_drawer()
	_quest_toggle.grab_focus()


func _open_task(task_id: StringName) -> void:
	if not _can_navigate():
		return
	_quest_drawer.close_drawer()
	GameSession.open_task(task_id)


func _refresh_progress() -> void:
	_day_label.text = "第 %d 天" % GameSession.day_number()
	_gold_label.text = str(GameSession.gold_count())
	var entries: Array[Dictionary] = GameSession.task_entries()
	_quest_drawer.set_entries(entries)
	_pending_entries = entries.filter(
		func(entry: Dictionary) -> bool: return entry["group"] in ["offered", "event"]
	)
	_pending_dot.visible = not _pending_entries.is_empty()
	if not _announcement_scheduled:
		_announcement_scheduled = true
		_announce_new_work.call_deferred()
	_refresh_weather()


func _start_art_motion() -> void:
	var hand: TextureRect = $DayDial/DialHand
	var swing := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	swing.tween_property(hand, "rotation", -0.12, 1.2)
	swing.tween_property(hand, "rotation", 0.1, 2.4)
	swing.tween_property(hand, "rotation", 0.0, 1.2)

	var pulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_pending_dot, "modulate:a", 0.52, 0.66)
	pulse.tween_property(_pending_dot, "modulate:a", 1.0, 0.66)


func _refresh_task_button() -> void:
	var open := _quest_drawer.visible
	_quest_toggle.theme_type_variation = &"TaskBadgeOpen" if open else &"TaskBadge"
	_quest_toggle.tooltip_text = "关闭任务班表" if open else "查看任务班表"
	_feedback.visible = not open and not _feedback_queue.is_empty()


func _on_world_changed(_world: int) -> void:
	_refresh_progress()


func _refresh_weather() -> void:
	_weather_label.visible = _show_weather
	if _show_weather and not Engine.is_editor_hint():
		_weather_label.text = "晴朗" if GameSession.airport_weather() == "clear" else "强风"


func _announce_new_work() -> void:
	_announcement_scheduled = false
	var current_pending: Dictionary = {}
	var new_person := false
	var new_event := false
	for entry in _pending_entries:
		var key: StringName = StringName(entry["id"])
		current_pending[key] = true
		if _pending_ids.has(key):
			continue
		if entry["group"] == "event":
			new_event = true
		else:
			new_person = true
	_pending_ids = current_pending
	if new_person and new_event:
		show_feedback("有访客等候接待。\n也有新的事件可查看。", true)
	elif new_person:
		show_feedback("有访客等候接待。\n可查看任务班表。", true)
	elif new_event:
		show_feedback("有新的事件解锁了。", true)


func _display_first_feedback() -> void:
	_feedback.visible = not _quest_drawer.visible and not _feedback_queue.is_empty()
	if _feedback_queue.is_empty():
		return
	var first: Dictionary = _feedback_queue[0]
	var opens_tasks: bool = first["opens_tasks"]
	_feedback.text = first["message"]
	_feedback.tooltip_text = "查看任务班表" if opens_tasks else ""
	_feedback.mouse_filter = Control.MOUSE_FILTER_STOP if opens_tasks else Control.MOUSE_FILTER_IGNORE
	_feedback.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if opens_tasks else Control.CURSOR_ARROW
	_feedback_timer.start(FEEDBACK_SECONDS)


func _open_tasks_from_feedback() -> void:
	if _can_navigate():
		_open_tasks()
		_finish_feedback()


func _finish_feedback() -> void:
	_feedback_timer.stop()
	if not _feedback_queue.is_empty():
		_feedback_queue.pop_front()
	_display_first_feedback()
