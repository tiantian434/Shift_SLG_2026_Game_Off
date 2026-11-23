extends Node

signal state_changed

const QuestSystem := preload("res://app/quests/quest_system.gd")
const SaveIO := preload("res://app/save_io.gd")
const ChapterTwo := preload("res://app/training/chapter_two.gd")
const TRAINING_PANEL_PATH := "res://views/training/training_panel.tscn"
const SAFE_FLIGHT := &"safe_flight"
const CHAPTER_ESCORT := &"chapter1_escort"
const CHAPTER_LOCATION := &"hub"
const SAVE_VERSION := 1
const WORLD_IDS := {
	SceneRouter.World.SURFACE: "surface",
	SceneRouter.World.INNER: "inner",
}
const INITIAL_STATE := {
	"day_id": "day_01",
	"facilities": {"surface": {"workshop": {"regulator_repaired": false}}},
	"environment": {"surface": {"airport": {"weather": "windy"}}},
	"quests": {"safe_flight": {"phase": "offered"}},
	"inventory": {"flight_token": 0},
	"gold": 0,
	"chapter1": {"phase": "offered"},
}

var _quest_system := QuestSystem.new()
var _state := INITIAL_STATE.duplicate(true)
var _opening_task := false
var _ending_save_error: Error = OK
var _training_panel: Control
var _training_room: Node


func _ready() -> void:
	_quest_system.load_quest(SAFE_FLIGHT)


func regulator_repaired() -> bool:
	return _state["facilities"]["surface"]["workshop"]["regulator_repaired"]


func airport_weather() -> String:
	return _state["environment"]["surface"]["airport"]["weather"]


func flight_token_count() -> int:
	return _state["inventory"]["flight_token"]


func day_number() -> int:
	return maxi(1, String(_state["day_id"]).trim_prefix("day_").to_int())


func gold_count() -> int:
	return _state["gold"]


func is_chapter_complete() -> bool:
	return _state["chapter1"]["phase"] == "succeeded"


func is_chapter_two() -> bool:
	return _state.has("chapter2")


func training_stage() -> StringName:
	return StringName(_state["chapter2"]["stage"]) if is_chapter_two() else &""


func is_game_complete() -> bool:
	return training_stage() == &"complete"


func is_training_solved(stage: StringName) -> bool:
	if not is_chapter_two() or stage not in ChapterTwo.EXERCISES:
		return false
	var current := training_stage()
	return ChapterTwo.ORDER.find(current) > ChapterTwo.ORDER.find(stage) or (
		current == stage and _state["chapter2"]["step"] == "debrief"
	)


func task_entries() -> Array[Dictionary]:
	var phase: String = _state["chapter1"]["phase"]
	var inner := SceneRouter.current_world == SceneRouter.World.INNER
	var tasks: Array[Dictionary] = [{
		"id": CHAPTER_ESCORT,
		"title": "接待押送者",
		"issuer": "侦探" if inner else "警察",
		"summary": "" if phase == "offered" else "了解年轻研究者正在进行的双界研究。",
		"group": "settled" if phase == "succeeded" else phase,
		"required": true,
		"available": phase != "succeeded",
	}]
	if is_chapter_two():
		tasks.append_array(ChapterTwo.task_entries(_state["chapter2"]))
	return tasks


func open_task(task_id: StringName) -> void:
	if _opening_task or is_game_complete():
		return
	if not SceneRouter.is_in_game() or SceneRouter.is_changing_scene() or UIManager.has_modal() or get_tree().paused:
		return

	_opening_task = true
	if is_chapter_two():
		var stage := training_stage()
		if task_id == StringName("ch2_" + String(stage)):
			await _open_training_task(stage)
		else:
			show_feedback("现在还不能这样做。", true)
	elif task_id == CHAPTER_ESCORT:
		await _open_escort()
	_opening_task = false


func _open_escort() -> void:
	var world := SceneRouter.current_world
	if not SceneRouter.is_in_facility(CHAPTER_LOCATION, world):
		await SceneRouter.open_facility(CHAPTER_LOCATION)
	if not SceneRouter.is_in_facility(CHAPTER_LOCATION, world):
		return
	if DialogueSystem.start(CHAPTER_ESCORT, CHAPTER_LOCATION, world, {}, _finish_escort):
		_state["chapter1"]["phase"] = "active"
		state_changed.emit()


func chapter_save_error() -> Error:
	return _ending_save_error


func retry_chapter_save() -> Error:
	if is_game_complete() and SceneRouter.is_on_chapter_ending():
		_ending_save_error = _write_snapshot()
	return _ending_save_error


func _finish_escort() -> void:
	if is_chapter_complete():
		return
	_state["chapter1"]["phase"] = "succeeded"
	_state["chapter2"] = ChapterTwo.initial_state()
	_state["day_id"] = "day_02"
	_state["environment"]["surface"]["airport"]["weather"] = "clear"
	await SceneRouter.return_to_map(SceneRouter.World.SURFACE)
	var checkpoint := _write_snapshot()
	await MenuSystem.show_day_titles(["第 1 天结束", "第 2 天开始"])
	state_changed.emit()
	if checkpoint != OK:
		show_feedback("自动保存失败，可在聚落地图的暂停菜单手动保存。")


func show_feedback(message: String, opens_tasks := false) -> void:
	get_tree().call_group(&"game_hud", &"show_feedback", message, opens_tasks)


func _open_training_task(stage: StringName) -> void:
	var lesson: Array = ChapterTwo.LESSONS[stage]
	var facility: StringName = lesson[0]
	var world: int = lesson[1]
	if not SceneRouter.is_in_facility(facility, world):
		await SceneRouter.open_facility(facility, world)
	if not SceneRouter.is_in_facility(facility, world):
		return

	var progress: Dictionary = _state["chapter2"]
	var step: String = progress["step"]
	if step == "exercise":
		_open_training_panel(stage)
	else:
		var dialogue_id := "ch2_" + String(stage)
		if stage in ChapterTwo.EXERCISES:
			dialogue_id += "_" + step
		if not DialogueSystem.start(StringName(dialogue_id), facility, world, {}, _finish_training_part.bind(stage, step), true):
			return
	progress["started"] = true
	state_changed.emit()


func _finish_training_part(stage: StringName, step: String) -> void:
	if training_stage() != stage or _state["chapter2"]["step"] != step:
		return
	if stage in ChapterTwo.EXERCISES and step == "intro":
		_state["chapter2"]["step"] = "exercise"
		_open_training_panel(stage)
		return
	var next: StringName = ChapterTwo.ORDER[ChapterTwo.ORDER.find(stage) + 1]
	_state["chapter2"] = {"stage": String(next), "step": "intro", "draft": {}, "started": false}
	state_changed.emit()
	if next == &"complete":
		_ending_save_error = _write_snapshot()
		await MenuSystem.show_day_titles(["第 2 天结束"])
		await SceneRouter.open_chapter_ending(SceneRouter.current_world)


func _open_training_panel(stage: StringName) -> void:
	if UIManager.has_modal() or is_instance_valid(_training_panel):
		return
	var scene := load(TRAINING_PANEL_PATH) as PackedScene
	if scene == null:
		return
	var panel := scene.instantiate() as Control
	_training_panel = panel
	_training_room = get_tree().current_scene
	_training_room.tree_exiting.connect(_close_training_panel)
	panel.connect(&"exited", _close_training_panel)
	panel.connect(&"solved", _training_solved.bind(stage))
	panel.connect(&"draft_changed", _keep_training_draft)
	UIManager.mount_modal(panel, Callable(panel, &"handle_input"))
	panel.call(&"setup", stage, _state["chapter2"]["draft"].duplicate(true))


func _keep_training_draft(draft: Dictionary) -> void:
	_state["chapter2"]["draft"] = draft.duplicate(true)


func _training_solved(stage: StringName) -> void:
	_close_training_panel()
	_state["chapter2"]["step"] = "debrief"
	_state["chapter2"]["draft"] = {}
	show_feedback("操作成功。")
	if stage == &"ritual":
		show_feedback("周围的环境，似乎发生了一些变化。")
	elif stage == &"alchemy":
		show_feedback("周围的环境已恢复如常。")
	_open_training_task(stage)


func _close_training_panel() -> void:
	if not is_instance_valid(_training_panel):
		return
	if is_instance_valid(_training_room):
		_training_room.tree_exiting.disconnect(_close_training_panel)
	_training_room = null
	UIManager.unmount_modal(_training_panel)
	_training_panel.queue_free()
	_training_panel = null


func submit_action(action_id: StringName) -> bool:
	if SceneRouter.is_changing_scene():
		return false

	match action_id:
		&"repair_regulator":
			if not SceneRouter.is_in_facility(&"workshop", SceneRouter.World.SURFACE) or regulator_repaired():
				return false
			_state["facilities"]["surface"]["workshop"]["regulator_repaired"] = true
		&"clear_airport_weather", &"release_airport_weather":
			if UIManager.has_modal() or not SceneRouter.is_in_facility(&"workshop", SceneRouter.World.INNER):
				return false
			var weather := "clear" if action_id == &"clear_airport_weather" else "windy"
			if airport_weather() == weather:
				return false
			_state["environment"]["surface"]["airport"]["weather"] = weather
		_:
			return false

	state_changed.emit()
	return true


func quest_view(quest_id: StringName) -> Dictionary:
	return _quest_system.get_view(quest_id, _state, TranslationServer.get_locale())


func accept_quest(quest_id: StringName, issuer: StringName) -> Dictionary:
	if SceneRouter.is_changing_scene():
		return {"ok": false, "reason": &"busy"}

	var world: String = WORLD_IDS[SceneRouter.current_world]
	var result := _quest_system.evaluate_accept(quest_id, _state, world, issuer)
	if result["ok"]:
		_state["quests"][String(quest_id)] = {"phase": "accepted"}
		state_changed.emit()
	return result


func turn_in_quest(quest_id: StringName, issuer: StringName) -> Dictionary:
	if SceneRouter.is_changing_scene():
		return {"ok": false, "reason": &"busy"}

	var world: String = WORLD_IDS[SceneRouter.current_world]
	var result := _quest_system.evaluate_turn_in(quest_id, _state, world, issuer)
	if result["ok"]:
		_state["quests"][String(quest_id)] = {
			"phase": "succeeded",
			"settled_route": result["route_id"],
		}
		_state["inventory"]["flight_token"] += result["reward_tokens"]
		state_changed.emit()
	return result


func has_save() -> bool:
	return SaveIO.load_snapshot(_valid_snapshot)["ok"]


func is_current_progress_saved() -> bool:
	var result := SaveIO.load_snapshot(_valid_snapshot)
	if not result["ok"]:
		return false
	var snapshot: Dictionary = result["snapshot"]
	return (
		_snapshot_world(snapshot) == SceneRouter.current_world
		and _state_from_snapshot(snapshot) == _state
	)


func start_new_game() -> void:
	if not SceneRouter.is_on_home() or SceneRouter.is_changing_scene() or UIManager.has_modal():
		return
	_state = INITIAL_STATE.duplicate(true)
	_ending_save_error = OK
	await SceneRouter.return_to_map(SceneRouter.World.SURFACE)
	get_tree().call_group(&"game_hud", &"reset_for_new_run")
	state_changed.emit()
	await MenuSystem.show_day_titles(["第 1 天开始"])


func save_game(pause_menu: Control = null) -> Error:
	if not _can_access_save(pause_menu):
		return ERR_BUSY
	return _write_snapshot()


func _write_snapshot() -> Error:
	var snapshot := _state.duplicate(true)
	snapshot["schema_version"] = SAVE_VERSION
	snapshot["current_world"] = WORLD_IDS[SceneRouter.current_world]
	return SaveIO.save_snapshot(snapshot, _valid_snapshot)


func load_game(pause_menu: Control = null) -> Dictionary:
	var on_home := SceneRouter.is_on_home() and not SceneRouter.is_changing_scene() and not UIManager.has_modal()
	if not on_home and not _can_access_save(pause_menu):
		return {"ok": false, "reason": &"busy"}

	var result := SaveIO.load_snapshot(_valid_snapshot)
	if not result["ok"]:
		return result

	var snapshot: Dictionary = result["snapshot"]
	var world := _snapshot_world(snapshot)
	_state = _state_from_snapshot(snapshot)
	_ending_save_error = OK
	if is_game_complete():
		SceneRouter.open_chapter_ending(world)
	else:
		SceneRouter.return_to_map(world)
	state_changed.emit()
	return {"ok": true, "used_backup": result["used_backup"], "game_complete": is_game_complete()}


func _snapshot_world(snapshot: Dictionary) -> int:
	if snapshot.get("chapter1", {}).get("phase") == "succeeded" and not snapshot.has("chapter2"):
		return SceneRouter.World.SURFACE
	return WORLD_IDS.find_key(snapshot["current_world"])


func _state_from_snapshot(snapshot: Dictionary) -> Dictionary:
	var state := snapshot.duplicate(true)
	state.erase("schema_version")
	state.erase("current_world")
	state["inventory"]["flight_token"] = int(state["inventory"]["flight_token"])
	state["gold"] = int(state.get("gold", 0))
	if not state.has("chapter1"):
		state["chapter1"] = {"phase": "offered"}
	if state["chapter1"]["phase"] == "succeeded" and not state.has("chapter2"):
		state["chapter2"] = ChapterTwo.initial_state()
		state["day_id"] = "day_02"
		state["environment"]["surface"]["airport"]["weather"] = "clear"
	if state.has("chapter2"):
		ChapterTwo.restore_progress(state["chapter2"])
	return state


func _can_access_save(pause_menu: Control) -> bool:
	return SceneRouter.is_on_map() and not SceneRouter.is_changing_scene() and not UIManager.has_modal(pause_menu)


func _valid_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.get("schema_version") != SAVE_VERSION or snapshot.get("current_world") not in WORLD_IDS.values():
		return false
	var day: Variant = snapshot.get("day_id")
	if not day is String or day.is_empty():
		return false
	var chapter: Variant = snapshot.get("chapter1", {"phase": "offered"})
	if not chapter is Dictionary or chapter.get("phase") not in ["offered", "active", "succeeded"]:
		return false
	if snapshot.has("chapter2") and (chapter["phase"] != "succeeded" or not ChapterTwo.is_valid(snapshot["chapter2"])):
		return false
	var gold: Variant = snapshot.get("gold", 0)
	if not (gold is int or gold is float) or gold < 0 or gold > 2147483647 or gold != floor(gold):
		return false
	var repaired: Variant = QuestSystem.fact_value(snapshot, "facilities.surface.workshop.regulator_repaired")
	var weather: Variant = QuestSystem.fact_value(snapshot, "environment.surface.airport.weather")
	if not repaired is bool or weather not in ["windy", "clear"]:
		return false
	var tokens: Variant = QuestSystem.fact_value(snapshot, "inventory.flight_token")
	if not (tokens is int or tokens is float) or tokens < 0 or tokens > 2147483647 or tokens != floor(tokens):
		return false
	var quest: Variant = QuestSystem.fact_value(snapshot, "quests.safe_flight")
	if not quest is Dictionary or quest.get("phase") not in ["offered", "accepted", "succeeded"]:
		return false
	var day_ended: Variant = snapshot.get("day_ended", false)
	if not day_ended is bool or (day_ended and quest["phase"] != "succeeded"):
		return false
	if quest["phase"] != "succeeded":
		return not quest.has("settled_route")
	var route: Variant = quest.get("settled_route")
	return route is String and _quest_system.has_route(SAFE_FLIGHT, route)
