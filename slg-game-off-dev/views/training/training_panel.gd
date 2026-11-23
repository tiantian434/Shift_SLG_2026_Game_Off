extends Control

signal solved
signal exited
signal draft_changed(draft: Dictionary)

const Rules := preload("res://views/training/training_rules.gd")
const Instrument := preload("res://views/training/training_instrument.gd")
const GUIDE := {
	&"repair": "根据新的症状调整零件与工具，然后再次检修。",
	&"meal": "听听船员怎么说，根据他的反馈调整餐食。",
	&"ritual": "按空格或点击「引导符文」。错过时机可重试，已点亮的符文会保留。",
	&"alchemy": "更换材料时，观察光点向哪里移动。表之质也可以不添加。",
}

@onready var _title: Label = %TrainingTitle
@onready var _case_title: Label = %CaseTitle
@onready var _case_text: Label = %CaseText
@onready var _instrument: Instrument = %Instrument
@onready var _choices: VBoxContainer = %Choices
@onready var _guide: Label = %Guide
@onready var _feedback: Label = %TrainingFeedback
@onready var _primary: Button = %PrimaryAction
@onready var _inspect: Button = %Inspect
@onready var _exit_button: Button = %ExitTraining

var _exercise: StringName
var _lesson: Dictionary
var _draft: Dictionary
var _ritual_phase := 0.0
var _ritual_running := false
var _ritual_failed := false
var _done := false


func _ready() -> void:
	set_process(false)
	_primary.pressed.connect(_perform)
	_inspect.pressed.connect(_inspect_fan)
	_exit_button.pressed.connect(_leave)


func setup(exercise: StringName, draft: Dictionary) -> void:
	_exercise = exercise
	_lesson = Rules.LESSONS.get(exercise, {})
	_draft = {}
	_done = false
	_ritual_running = false
	_ritual_failed = false
	set_process(false)
	_primary.disabled = _lesson.is_empty()
	_exit_button.disabled = false
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	if _lesson.is_empty():
		_set_feedback("现在还不能这样做。", true)
		return

	_title.text = _lesson["title"]
	_case_title.text = _lesson["case"]
	_primary.text = _lesson["action"]
	_guide.text = GUIDE[exercise]
	_inspect.visible = exercise == &"repair"
	_inspect.text = "观察风机"
	_case_text.text = _lesson["brief"]
	_instrument.exercise = exercise
	_instrument.inspected = false
	if exercise == &"repair" and draft.get("inspected") == true:
		_draft["inspected"] = true
		_show_observation()
	if exercise == &"ritual":
		var progress := _valid_index(draft.get("ritual_hits"), Rules.RUNES)
		_draft["ritual_hits"] = maxi(0, progress)
	if exercise == &"alchemy":
		_draft["sample"] = 0
	for row: Dictionary in _lesson["options"]:
		var field: String = row["id"]
		var selected := _valid_index(draft.get(field), row["choices"].size())
		if selected >= 0:
			_draft[field] = selected
		_build_choice_row(row, _draft.get(field, -1))
	_refresh_instrument()
	_set_feedback("")
	if _inspect.visible and not _draft.has("inspected"):
		_inspect.grab_focus()
	else:
		var first_choice := _choices.find_child("Choice_*_0", true, false) as Button
		first_choice.grab_focus()


func handle_input(event: InputEvent) -> bool:
	if event.is_action(&"shift_world"):
		if event.is_action_pressed(&"shift_world"):
			_set_feedback("现在还不能这样做。请先暂离当前操作。", true)
		return true
	if _ritual_running and event.is_action(&"ui_accept"):
		if event.is_action_pressed(&"ui_accept"):
			_strike_rune()
		return true
	return false


func _process(delta: float) -> void:
	_ritual_phase += delta / Rules.RITUAL_PERIOD
	if _ritual_phase > _next_beat() + Rules.RITUAL_WINDOW:
		_miss_rune("光标已经掠过符文。")
	_refresh_instrument()


func _build_choice_row(row: Dictionary, selected: int) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 3)
	var label := Label.new()
	label.text = row["label"]
	label.add_theme_font_size_override(&"font_size", 12)
	column.add_child(label)

	var field: String = row["id"]
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 4)
	var group := ButtonGroup.new()
	for index in row["choices"].size():
		var button := Button.new()
		button.name = "Choice_%s_%d" % [field, index]
		button.text = row["choices"][index]
		button.custom_minimum_size.y = 28.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = group
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.set_pressed_no_signal(index == selected)
		button.pressed.connect(_select.bind(field, index))
		buttons.add_child(button)
	column.add_child(buttons)
	_choices.add_child(column)


func _select(field: String, index: int) -> void:
	if _draft.get(field) == index:
		return
	_draft[field] = index
	_publish_draft()
	_refresh_instrument()
	if not _ritual_running:
		_set_feedback("")


func _inspect_fan() -> void:
	_draft["inspected"] = true
	_show_observation()
	_publish_draft()
	_refresh_instrument()
	_set_feedback("")


func _show_observation() -> void:
	_case_text.text = _lesson["inspect"]
	_inspect.text = "查看故障"
	_instrument.inspected = true


func _perform() -> void:
	if _done:
		return
	if _exercise == &"repair" and not _draft.get("inspected", false):
		_set_feedback("现在还不能这样做。请先观察设备的故障症状。", true)
		return
	for row: Dictionary in _lesson["options"]:
		if not _draft.has(row["id"]):
			_set_feedback("现在还不能这样做。请选择%s。" % row["label"], true)
			return
	if _exercise == &"ritual":
		if _ritual_running:
			_strike_rune()
		else:
			_start_ritual()
		return
	var problem := Rules.evaluate(_exercise, _draft)
	if problem.is_empty():
		_complete()
	else:
		_set_feedback(problem, true)


func _start_ritual() -> void:
	_ritual_running = true
	_ritual_failed = false
	_ritual_phase = _next_beat() - Rules.RITUAL_LEAD
	_primary.text = "引导符文"
	_set_feedback("光标进入标亮的弧段时引导魔力。")
	_refresh_instrument()
	set_process(true)


func _strike_rune() -> void:
	if absf(_ritual_phase - _next_beat()) > Rules.RITUAL_WINDOW:
		_miss_rune("魔力没有对准符文。")
		return
	_draft["ritual_hits"] += 1
	_publish_draft()
	if _ritual_hits() == Rules.RUNES:
		_ritual_running = false
		set_process(false)
		_refresh_instrument()
		_complete()
	else:
		_set_feedback("符文已点亮。跟随光标移向下一枚。")
		_refresh_instrument()


func _miss_rune(message: String) -> void:
	_ritual_running = false
	_ritual_failed = true
	set_process(false)
	_primary.text = "重新引导"
	_set_feedback(message + " 可以重试。", true)
	_refresh_instrument()


func _next_beat() -> float:
	return float(_ritual_hits()) / Rules.RUNES


func _ritual_hits() -> int:
	return _draft.get("ritual_hits", 0)


func _refresh_instrument() -> void:
	if _exercise == &"alchemy":
		_instrument.spectrum = Rules.spectrum(_draft)
	elif _exercise == &"ritual":
		_instrument.ritual_progress = _ritual_hits()
		_instrument.ritual_phase = _ritual_phase
		_instrument.ritual_running = _ritual_running
		_instrument.ritual_failed = _ritual_failed
	_instrument.queue_redraw()


func _set_feedback(message: String, warning := false) -> void:
	_feedback.text = message
	_feedback.add_theme_color_override(&"font_color", Color("#f0b18d") if warning else Color("#f9e4bc"))


func _publish_draft() -> void:
	draft_changed.emit(_draft.duplicate())


func _leave() -> void:
	if _done:
		return
	set_process(false)
	_ritual_running = false
	_publish_draft()
	exited.emit()


func _complete() -> void:
	_done = true
	_primary.disabled = true
	_exit_button.disabled = true
	_set_feedback("操作成功。")
	solved.emit()


func _valid_index(value: Variant, count: int) -> int:
	if value is int or value is float:
		if value >= 0 and value < count and value == floor(value):
			return int(value)
	return -1
