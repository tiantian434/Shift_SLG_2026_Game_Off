extends Node

const PAUSE_MENU := preload("res://views/menus/pause_menu.tscn")
const SETTINGS_MENU := preload("res://views/menus/settings_menu.tscn")
const DAY_TITLE := preload("res://views/menus/day_title.tscn")
const SHIFT_THEME := preload("res://views/hud/shift_theme.tres")
const GameSettings := preload("res://app/game_settings.gd")
const SettingsMenu := preload("res://views/menus/settings_menu.gd")

var _pause_menu: Control
var _settings_menu: SettingsMenu
var _menu_before_settings: Control
var _focus_before_pause: Control
var _focus_before_settings: Control
var _returning_home := false
var _day_title: Control
var _day_end_confirmation: ConfirmationDialog
var _settings := GameSettings.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_settings.restore(get_tree().root)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and DisplayServer.get_name() != "headless":
		_settings.save()


func open_settings(source_menu: Control) -> void:
	if _settings_menu != null or _returning_home:
		return

	_focus_before_settings = get_viewport().gui_get_focus_owner()
	_menu_before_settings = source_menu
	source_menu.hide()
	_settings_menu = SETTINGS_MENU.instantiate() as SettingsMenu
	_settings_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	_settings_menu.closed.connect(_close_settings)
	UIManager.mount_modal(_settings_menu, Callable())
	_settings_menu.setup(_settings)


func open_pause() -> void:
	if _pause_menu != null or _settings_menu != null:
		return
	if not get_tree().paused and SceneRouter.is_in_game() and not SceneRouter.is_changing_scene():
		_open_pause_menu()


func open_day_end() -> void:
	if get_tree().paused or UIManager.has_modal() or SceneRouter.is_changing_scene() or not SceneRouter.is_in_game():
		return
	if GameSession.training_stage() != &"return":
		GameSession.show_feedback("今天的站务还没有全部收尾。请先安排妥当，再结束今天吧。", true)
		return

	if _day_end_confirmation == null:
		_day_end_confirmation = ConfirmationDialog.new()
		_day_end_confirmation.name = "DayEndConfirmation"
		_day_end_confirmation.title = "结束当天"
		_day_end_confirmation.theme = SHIFT_THEME
		_day_end_confirmation.dialog_text = "确定要结束今天吗？\n确认后回空港站房复命。"
		_day_end_confirmation.ok_button_text = "回站房复命"
		_day_end_confirmation.cancel_button_text = "返回处理"
		_day_end_confirmation.confirmed.connect(GameSession.open_task.bind(&"ch2_return"))
		add_child(_day_end_confirmation)
	_day_end_confirmation.popup_centered(Vector2i(310, 116))


func show_day_titles(titles: Array[String]) -> void:
	_day_title = DAY_TITLE.instantiate() as Control
	UIManager.mount_modal(_day_title, func(_event: InputEvent) -> bool: return true)
	var heading: Label = _day_title.get_node("%DayHeading")
	for title in titles:
		heading.text = title
		await get_tree().create_timer(0.95).timeout
	UIManager.unmount_modal(_day_title)
	_day_title.queue_free()
	_day_title = null


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return

	if _returning_home or SceneRouter.is_changing_scene() or _day_title != null:
		get_viewport().set_input_as_handled()
	elif is_instance_valid(_day_end_confirmation) and _day_end_confirmation.visible:
		get_viewport().set_input_as_handled()
		_day_end_confirmation.hide()
	elif _settings_menu != null:
		get_viewport().set_input_as_handled()
		if not _settings_menu.close_resolution_list():
			_close_settings()
	elif _pause_menu != null:
		var confirm_home: ConfirmationDialog = _pause_menu.get_node("%ConfirmHome")
		if confirm_home.visible:
			get_viewport().set_input_as_handled()
			confirm_home.hide()
			_pause_menu.get_node("%ReturnHome").grab_focus()
			return
		get_viewport().set_input_as_handled()
		_resume_game()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not get_tree().paused and SceneRouter.is_in_game():
		get_viewport().set_input_as_handled()
		open_pause()


func _open_pause_menu() -> void:
	_focus_before_pause = get_viewport().gui_get_focus_owner()
	get_tree().paused = true
	_pause_menu = PAUSE_MENU.instantiate() as Control
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	var resume_button: Button = _pause_menu.get_node("%ResumeGame")
	var settings_button: Button = _pause_menu.get_node("%Settings")
	var home_button: Button = _pause_menu.get_node("%ReturnHome")
	var save_button: Button = _pause_menu.get_node("%SaveButton")
	var load_button: Button = _pause_menu.get_node("%LoadButton")
	var can_access_save := SceneRouter.is_on_map() and not UIManager.has_modal()
	save_button.disabled = not can_access_save
	load_button.disabled = not can_access_save
	if not can_access_save:
		_show_save_status("请回到聚落地图存读档" if not SceneRouter.is_on_map() else "请先关闭当前窗口")
	resume_button.pressed.connect(_resume_game)
	settings_button.pressed.connect(open_settings.bind(_pause_menu))
	save_button.pressed.connect(_save_game)
	load_button.pressed.connect(_load_game)
	var confirm_home: ConfirmationDialog = _pause_menu.get_node("%ConfirmHome")
	home_button.pressed.connect(_request_return_home)
	confirm_home.confirmed.connect(_return_to_home)
	UIManager.mount_modal(_pause_menu, Callable())
	resume_button.grab_focus()


func _save_game() -> void:
	var result := GameSession.save_game(_pause_menu)
	_show_save_status("已保存进度" if result == OK else "当前无法保存进度")


func _load_game() -> void:
	var result := GameSession.load_game(_pause_menu)
	if result["ok"]:
		if result["game_complete"]:
			_close_pause_menu()
			_focus_before_pause = null
			return
		_show_save_status("已读取备份存档" if result["used_backup"] else "已读取进度")
		return

	match result["reason"]:
		&"missing_save":
			_show_save_status("还没有存档")
		&"invalid_save":
			_show_save_status("存档损坏或版本不兼容")
		_:
			_show_save_status("当前无法读取进度")


func _show_save_status(message: String) -> void:
	var status: Label = _pause_menu.get_node("%SaveStatus")
	status.text = message
	status.show()


func _resume_game() -> void:
	if not _returning_home:
		_close_pause_menu()
		_restore_focus(_focus_before_pause)
		_focus_before_pause = null


func _close_pause_menu() -> void:
	UIManager.unmount_modal(_pause_menu)
	_pause_menu.queue_free()
	_pause_menu = null
	get_tree().paused = false


func _request_return_home() -> void:
	if _returning_home:
		return
	if GameSession.is_current_progress_saved():
		_return_to_home()
	else:
		var confirm_home: ConfirmationDialog = _pause_menu.get_node("%ConfirmHome")
		confirm_home.popup_centered(Vector2i(332, 120))


func _return_to_home() -> void:
	if _returning_home:
		return

	_returning_home = true
	if await SceneRouter.open_home():
		DialogueSystem.close()
		_close_pause_menu()
		_focus_before_pause = null
	else:
		_pause_menu.get_node("%ReturnError").show()
	_returning_home = false


func _close_settings() -> void:
	_settings.save()
	UIManager.unmount_modal(_settings_menu)
	_settings_menu.queue_free()
	_settings_menu = null
	_menu_before_settings.show()
	_menu_before_settings = null
	_restore_focus(_focus_before_settings)
	_focus_before_settings = null


func _restore_focus(control: Control) -> void:
	if is_instance_valid(control) and control.is_visible_in_tree():
		control.grab_focus()
