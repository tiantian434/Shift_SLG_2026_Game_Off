extends Node

const DialogueSession := preload("res://app/dialogue/dialogue_session.gd")
const DialogueData := preload("res://app/dialogue/dialogue_data.gd")
const DialogueBox := preload("res://views/dialogue/dialogue_box.gd")
const BOX_SCENE := preload("res://views/dialogue/dialogue_box.tscn")

var _session: DialogueSession
var _box: DialogueBox
var _facility_id: StringName
var _world: int
var _dialogue_id: StringName
var _facts: Dictionary
var _locale: String
var _on_finished: Callable
var _shift_ends_dialogue := false


func start(
	dialogue_id: StringName, facility_id: StringName, world: int,
	facts: Dictionary = {}, on_finished := Callable(), shift_ends_dialogue := false,
) -> bool:
	if UIManager.has_modal() or SceneRouter.is_changing_scene():
		return false

	var locale := TranslationServer.get_locale()
	var session := DialogueData.load_session(dialogue_id, world, facts, locale)
	if session == null:
		return false

	_session = session
	_facility_id = facility_id
	_world = world
	_dialogue_id = dialogue_id
	_facts = facts.duplicate(true)
	_locale = locale
	_on_finished = on_finished
	_shift_ends_dialogue = shift_ends_dialogue
	_box = BOX_SCENE.instantiate() as DialogueBox
	_box.advance_requested.connect(_advance)
	_box.choice_selected.connect(_choose)
	_box.shift_confirmed.connect(_shift_during_dialogue)
	_box.close_requested.connect(close)
	UIManager.mount_modal(_box, _handle_modal_input)
	_box.set_shift_ends_dialogue(_shift_ends_dialogue)
	_show_line()
	return true


func is_open() -> bool:
	return _box != null


func close() -> void:
	if not is_open():
		return

	var box := _box
	_box = null
	_session = null
	_facts = {}
	_on_finished = Callable()
	UIManager.unmount_modal(box)
	box.queue_free()


func _show_line(refresh_current := false) -> void:
	_box.set_speaker(_session.current_speaker_name())
	_box.set_portrait(_session.portrait_for(_world))
	_box.show_line(
		_session.current_text(),
		_session.is_player_line(),
		_session.option_labels(),
		_session.has_next_line(),
		[],
		refresh_current,
	)


func _advance() -> void:
	if _session.advance():
		_show_line()
	else:
		var finished := _on_finished
		close()
		if finished.is_valid():
			finished.call()


func _choose(index: int) -> void:
	_session.choose(index)
	_show_line()


func _handle_modal_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_cancel"):
		return _box.dismiss_overlay()
	if event.is_action_pressed(&"ui_accept"):
		var focus := _box.get_viewport().gui_get_focus_owner()
		if focus is BaseButton and _box.is_ancestor_of(focus) and not focus.disabled:
			return false
		return _box.request_advance()
	if not event.is_action(&"shift_world"):
		return false

	if event.is_action_pressed(&"shift_world") and not SceneRouter.is_changing_scene():
		_box.show_shift_prompt()
	return true


func _shift_during_dialogue() -> void:
	var box := _box
	await SceneRouter.shift_facility(_facility_id, _world)
	# A scene change can outlive the dialogue that requested it.
	if is_open() and _box == box:
		if _shift_ends_dialogue and SceneRouter.current_world != _world:
			close()
			return
		_box.dismiss_shift_prompt()
		_refresh_world(SceneRouter.current_world)


func _refresh_world(world: int) -> void:
	if _world == world:
		return
	_world = world
	if _session.parallel_world_text:
		var next := DialogueData.load_session(_dialogue_id, world, _facts, _locale)
		if next != null:
			next.resume_at(_session)
			_session = next
			_show_line(true)
			return
	_box.set_portrait(_session.portrait_for(world))
