extends Control

signal advance_requested
signal choice_selected(index: int)
signal player_reply_finished
signal shift_confirmed
signal close_requested

const PlayerReply := preload("res://views/dialogue/player_reply.gd")
const CONTINUE_ARROW := preload("res://views/dialogue/continue_arrow.tres")
const CHARACTERS_PER_SECOND := 40.0

var _npc_name: String
var _focus_before_overlay: Control
var _typing: Tween
var _player_line := false
var _has_choices := false
var _recorded_line_variants: Array[String] = []

@onready var _speaker: Label = %Speaker
@onready var _portrait: TextureRect = %Portrait
@onready var _line: Label = %Line
@onready var _line_scroll: ScrollContainer = %LineScroll
@onready var _player_reply: PlayerReply = $PlayerReply
@onready var _action_scroll: ScrollContainer = %ActionScroll
@onready var _actions: VBoxContainer = %Actions
@onready var _history_button: Button = %OpenHistory
@onready var _close_button: Button = %CloseDialogue
@onready var _history_panel: Control = %HistoryPanel
@onready var _history_log: RichTextLabel = %HistoryLog
@onready var _history_close: Button = %CloseHistory
@onready var _shift_button: Button = %ShiftDialogue
@onready var _shift_prompt: Control = %ShiftPrompt
@onready var _cancel_shift: Button = %CancelShift
@onready var _confirm_shift: Button = %ConfirmShift
@onready var _exit_prompt: Control = %ExitPrompt
@onready var _cancel_exit: Button = %CancelExit
@onready var _confirm_exit: Button = %ConfirmExit


func _ready() -> void:
	_player_reply.finished.connect(player_reply_finished.emit)
	_history_button.pressed.connect(_show_history)
	_history_close.pressed.connect(_hide_history)
	_close_button.pressed.connect(_show_exit_prompt)
	_shift_button.pressed.connect(show_shift_prompt)
	_cancel_shift.pressed.connect(dismiss_shift_prompt)
	_confirm_shift.pressed.connect(_confirm_world_shift)
	_cancel_exit.pressed.connect(_hide_exit_prompt)
	_confirm_exit.pressed.connect(close_requested.emit)
	$Panel.gui_input.connect(_on_text_input)
	_line_scroll.gui_input.connect(_on_text_input)


func set_speaker(display_name: String) -> void:
	_npc_name = display_name
	_speaker.text = display_name


func set_portrait(portrait: Texture2D) -> void:
	_portrait.texture = portrait
	var is_small_sprite := portrait != null and portrait.get_width() <= 64 and portrait.get_height() <= 64
	_portrait.texture_filter = (
		Control.TEXTURE_FILTER_NEAREST if is_small_sprite else Control.TEXTURE_FILTER_LINEAR
	)


func set_shift_ends_dialogue(ends_dialogue: bool) -> void:
	if ends_dialogue:
		%ShiftMessage.text += "\n这段对话会中断，回到原处后可重新开始。"


func show_line(
	text: String,
	player_line: bool,
	choices: Array[String],
	_has_next: bool,
	refusal_indices: Array[int] = [],
	refresh_current := false,
) -> void:
	if _typing != null:
		_typing.kill()
	_player_line = player_line
	_has_choices = not choices.is_empty()
	if not refresh_current:
		_recorded_line_variants.clear()
	_speaker.text = "我" if player_line else _npc_name
	_player_reply.dismiss()
	_line.text = text
	_line.visible_characters = 0
	_line_scroll.scroll_vertical = 0

	for action in _actions.get_children():
		_actions.remove_child(action)
		action.queue_free()

	_layout_actions(_has_choices)
	if choices.is_empty():
		_add_action("继续", request_advance)
	else:
		for index in choices.size():
			_add_action(choices[index], _select_choice.bind(index, choices[index]), index in refusal_indices)
	_action_scroll.visible = not _has_choices
	_set_controls_disabled(_overlay_open())
	_focus_first_action()
	_typing = create_tween()
	_typing.tween_property(_line, "visible_ratio", 1.0, maxf(0.05, text.length() / CHARACTERS_PER_SECOND))
	_typing.finished.connect(_complete_typewriter)
	if _overlay_open():
		_typing.pause()


func request_advance() -> bool:
	if _overlay_open():
		return false
	if _typing != null:
		_typing.kill()
		_complete_typewriter()
		return true
	if _has_choices:
		return false
	advance_requested.emit()
	return true


func dismiss_overlay() -> bool:
	if _exit_prompt.visible:
		_hide_exit_prompt()
	elif _history_panel.visible:
		_hide_history()
	elif _shift_prompt.visible:
		if not _confirm_shift.disabled:
			dismiss_shift_prompt()
	else:
		return false
	return true


func _on_text_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		request_advance()


func _complete_typewriter() -> void:
	_typing = null
	_line.visible_characters = -1
	if _player_line:
		_player_reply.present(_line.text)
	if _line.text not in _recorded_line_variants:
		_append_history(_speaker.text, _line.text)
		_recorded_line_variants.append(_line.text)
	_action_scroll.show()
	if not _overlay_open():
		_focus_first_action()


func _select_choice(index: int, caption: String) -> void:
	_append_history("我", caption)
	choice_selected.emit(index)


func show_shift_prompt() -> void:
	if _overlay_open():
		return

	_begin_overlay()
	_shift_prompt.show()
	_cancel_shift.grab_focus()


func dismiss_shift_prompt() -> void:
	_shift_prompt.hide()
	_confirm_shift.disabled = false
	_cancel_shift.disabled = false
	_end_overlay()


func _confirm_world_shift() -> void:
	_confirm_shift.disabled = true
	_cancel_shift.disabled = true
	shift_confirmed.emit()


func _show_history() -> void:
	_begin_overlay()
	%EmptyHistory.visible = _history_log.get_total_character_count() == 0
	_history_panel.show()
	_history_log.scroll_to_line.call_deferred(maxi(0, _history_log.get_line_count() - 1))
	_history_close.grab_focus()


func _hide_history() -> void:
	_history_panel.hide()
	_end_overlay()


func _show_exit_prompt() -> void:
	_begin_overlay()
	_exit_prompt.show()
	_cancel_exit.grab_focus()


func _hide_exit_prompt() -> void:
	_exit_prompt.hide()
	_end_overlay()


func _overlay_open() -> bool:
	return _history_panel.visible or _shift_prompt.visible or _exit_prompt.visible


func _begin_overlay() -> void:
	_focus_before_overlay = get_viewport().gui_get_focus_owner()
	if _typing != null:
		_typing.pause()
	_player_reply.set_suspended(true)
	_set_controls_disabled(true)


func _end_overlay() -> void:
	_set_controls_disabled(false)
	_player_reply.set_suspended(false)
	if _typing != null:
		_typing.play()
	if is_instance_valid(_focus_before_overlay) and _focus_before_overlay.is_visible_in_tree():
		_focus_before_overlay.grab_focus()
	else:
		_focus_first_action()
	_focus_before_overlay = null


func _set_controls_disabled(disabled: bool) -> void:
	_shift_button.disabled = disabled
	_history_button.disabled = disabled
	_close_button.disabled = disabled
	for action: Button in _actions.get_children():
		action.disabled = disabled


func _append_history(speaker_name: String, text: String) -> void:
	if _history_log.get_total_character_count() > 0:
		_history_log.add_text("\n\n")
	_history_log.push_color(Color("#825223"))
	_history_log.add_text(speaker_name)
	_history_log.pop()
	_history_log.add_text("\n" + text)


func _layout_actions(has_choices: bool) -> void:
	_action_scroll.offset_left = 252.0 if has_choices else 371.0
	_action_scroll.offset_top = -296.0 if has_choices else -45.0
	_action_scroll.offset_bottom = -195.0 if has_choices else -17.0
	_line_scroll.offset_bottom = -20.0 if has_choices else -38.0
	_action_scroll.scroll_vertical = 0


func _add_action(caption: String, callback: Callable, refusal := false) -> void:
	var button := Button.new()
	button.text = caption
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 27.0
	button.theme_type_variation = &"DialogueAction"
	if not _has_choices:
		button.icon = CONTINUE_ARROW
		button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if refusal:
		button.add_theme_color_override(&"font_color", Color("#9f3029"))
		button.add_theme_color_override(&"font_hover_color", Color("#ffb6a2"))
		button.add_theme_color_override(&"font_focus_color", Color("#9f3029"))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	_actions.add_child(button)


func _focus_first_action() -> void:
	if _action_scroll.visible and not _overlay_open():
		_actions.get_child(0).grab_focus()
